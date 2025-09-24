<#
README: Manual Removal of Stale Devices (Delegated Permissions)
================================================================

Overview
--------
This PowerShell script finds and removes Microsoft Entra ID / Azure AD devices
with no sign-in activity for N days (default 90). It’s intended for **manual
execution** with **delegated** permissions.

Safety Threshold (Optional)
---------------------------
- By default, the script **won’t delete** if stale count >= **Threshold** (default 20).
- To disable the threshold entirely, pass **-NoThreshold** OR set **-Threshold -1**.

What the script does
--------------------
- Interactive Graph login (delegated).
- Queries devices with ApproximateLastSignInDateTime <= Now - DaysInactive.
- Optional threshold guard (skip deletes if count is large).
- Removes devices with progress + summary.

Requirements
------------
1) PowerShell 7+
2) Microsoft Graph PowerShell SDK:
   Install-Module Microsoft.Graph -Scope AllUsers
3) Delegated permissions for your account:
   "Device.ReadWrite.All", "Directory.AccessAsUser.All" (admin consent may be required)

How to run
----------
Connect-MgGraph -Scopes "Device.ReadWrite.All", "Directory.AccessAsUser.All"

# Dry run (no deletes), with threshold 20
.\Remove-StaleDevices-Manual.ps1 -DaysInactive 90 -Threshold 20 -WhatIf

# Actually delete with threshold 20
.\Remove-StaleDevices-Manual.ps1 -DaysInactive 90 -Threshold 20

# Disable threshold completely
.\Remove-StaleDevices-Manual.ps1 -DaysInactive 90 -NoThreshold
# or
.\Remove-StaleDevices-Manual.ps1 -DaysInactive 90 -Threshold -1
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [int]$DaysInactive = 90,

    # >=0 applies safety gate; -1 disables it
    [int]$Threshold    = 20,

    # Convenience switch to disable the safety gate
    [switch]$NoThreshold,

    [switch]$WhatIf
)

# --- Minimal inline progress helper ---
if (-not $script:ProgressStartTimes) { $script:ProgressStartTimes = @{} }
if (-not $script:ProgressIndices)    { $script:ProgressIndices    = @{} }
if (-not $script:ProgressTotals)     { $script:ProgressTotals     = @{} }

# Helper function for progress bar, estimated time remaining, etc
function Write-ProgressHelper {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][int]$Total,
    [int]$Index,
    [string]$Activity = 'Processing',
    [string]$Operation,
    [int]$Id = 1,
    [switch]$Completed
  )
  if ($ProgressPreference -eq 'SilentlyContinue') { $ProgressPreference = 'Continue' }
  if (-not $script:ProgressStartTimes.ContainsKey($Id)) { $script:ProgressStartTimes[$Id] = Get-Date }
  if (-not $script:ProgressIndices.ContainsKey($Id))    { $script:ProgressIndices[$Id]    = 0 }
  if (-not $script:ProgressTotals.ContainsKey($Id))     { $script:ProgressTotals[$Id]     = $Total }

  if ($script:ProgressTotals[$Id] -ne $Total) {
    $script:ProgressStartTimes[$Id] = Get-Date
    $script:ProgressIndices[$Id]    = 0
    $script:ProgressTotals[$Id]     = $Total
  }

  if (-not $PSBoundParameters.ContainsKey('Index')) {
    $script:ProgressIndices[$Id]++
    $Index = $script:ProgressIndices[$Id]
  } else {
    $script:ProgressIndices[$Id] = $Index
  }

  $elapsed = (Get-Date) - $script:ProgressStartTimes[$Id]
  if ($Total -gt 0) {
    if     ($Index -lt 0)      { $Index = 0 }
    elseif ($Index -gt $Total) { $Index = $Total }
  }
  $percent = if ($Total -gt 0) {
    $raw = ($Index / $Total) * 100
    [math]::Round([math]::Min(100,[math]::Max(0,$raw)), 2)
  } else { $null }

  $etaSec = if ($Index -gt 0 -and $Total -ge $Index) {
    $rate = $elapsed.TotalSeconds / $Index
    [int][math]::Max(0, [math]::Round($rate * ($Total - $Index)))
  } else { $null }

  $status = if ($Total -gt 0) { "[${Index}/${Total}] $($elapsed.ToString('hh\:mm\:ss')) elapsed" }
            else              { "$($elapsed.ToString('hh\:mm\:ss')) elapsed" }

  $splat = @{ Activity=$Activity; Status=$status; Id=$Id }
  if ($percent -ne $null) { $splat.PercentComplete  = $percent }
  if ($etaSec   -ne $null){ $splat.SecondsRemaining = $etaSec }
  if ($Operation)         { $splat.CurrentOperation = $Operation }

  Write-Progress @splat

  if ($Completed.IsPresent) {
    $splat.Completed = $true
    Write-Progress @splat
    $script:ProgressStartTimes.Remove($Id) | Out-Null
    $script:ProgressIndices.Remove($Id)    | Out-Null
    $script:ProgressTotals.Remove($Id)     | Out-Null
  }
}

# --- Main (manual / delegated) ---
$ErrorActionPreference = 'Stop'
$overallStart = Get-Date

# Ensure Graph connection
try {
  $ctx = Get-MgContext -ErrorAction Stop
  if (-not $ctx) { throw "No Graph context" }
  Write-Host "[INFO] Using existing Microsoft Graph connection (Tenant $($ctx.TenantId))." -ForegroundColor DarkCyan
} catch {
  Write-Host "[INFO] Connecting to Microsoft Graph (delegated)..." -ForegroundColor Cyan
  Connect-MgGraph -Scopes "Device.ReadWrite.All Directory.Read.All"
}

# Build UTC cutoff
$cutoff = (Get-Date).AddDays(-1 * $DaysInactive).ToUniversalTime().ToString('s') + 'Z'
Write-Host "[INFO] Querying devices with ApproximateLastSignInDateTime <= $cutoff" -ForegroundColor Cyan

$devices = Get-MgDevice -All -Filter "approximateLastSignInDateTime le $cutoff"

if (-not $devices -or $devices.Count -eq 0) {
  Write-Host "[INFO] No stale devices found." -ForegroundColor Green
  return
}

# Threshold logic
$thresholdDisabled = $NoThreshold.IsPresent -or ($Threshold -lt 0)
if ($thresholdDisabled) {
  Write-Host "[INFO] Threshold disabled. Proceeding to delete all $($devices.Count) stale device(s)." -ForegroundColor Yellow
} else {
  Write-Host "[INFO] Threshold enabled (< $Threshold). Stale found: $($devices.Count)." -ForegroundColor Yellow
  if ($devices.Count -ge $Threshold) {
    Write-Warning "Delete threshold reached ($($devices.Count) >= $Threshold). Aborting cleanup."
    return
  }
}

$success = 0; $fail = 0; $total = $devices.Count
try {
  foreach ($dev in $devices) {
    Write-ProgressHelper -Total $total -Activity 'Removing stale devices' -Operation $dev.DisplayName
    if ($PSCmdlet.ShouldProcess("$($dev.DisplayName) [$($dev.Id)]", "Remove-MgDevice", "Microsoft Graph")) {
      try {
        if ($WhatIf.IsPresent) {
          Write-Host "[WHATIF] Would remove: $($dev.DisplayName) ($($dev.Id))" -ForegroundColor DarkYellow
        } else {
          Remove-MgDevice -DeviceId $dev.Id -ErrorAction Stop -Confirm:$false
          Write-Host "[OK] Removed: $($dev.DisplayName) ($($dev.Id))" -ForegroundColor Green
        }
        $success++
      } catch {
        if ($_.ErrorDetails.Message -like "*does not exist or one of its queried reference-property objects are not present*") {
          Write-Host "[SKIP] Not found: $($dev.DisplayName) ($($dev.Id))" -ForegroundColor Yellow
        } else {
          Write-Host "[ERR]  Failed to remove: $($dev.DisplayName) ($($dev.Id)) -> $($_.Exception.Message)" -ForegroundColor Red
          $fail++
        }
      }
    }
  }
}
finally {
  Write-ProgressHelper -Total $total -Activity 'Removing stale devices' -Completed
  $elapsed = (Get-Date) - $overallStart
  Write-Host "[SUMMARY] Removed: $success; Failed: $fail; Considered: $total; Elapsed: $($elapsed.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan
}
