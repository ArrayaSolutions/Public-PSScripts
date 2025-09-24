# Public-PSScripts
Public Facing Portal to Share PowerShell Scripts (In-Progress)

# PowerShell Scripts for Microsoft 365 & Entra ID

## Overview
This repository contains a curated collection of PowerShell scripts that I use in day-to-day work with **Microsoft 365**, **Entra ID (Azure AD)**, **Exchange Online**, and related services.  
Each script is designed to solve a specific operational or administrative need, with an emphasis on:
- **Automation** of common tasks
- **Safe defaults** (dry-run options, thresholds)
- **Clarity** through inline documentation
- **Reusability** for other admins and engineers

---

## Repository Contents
Scripts are organized into folders by category. Current and planned categories include:

- **Device Management**  
  Scripts for cleaning up stale Entra ID devices, bulk removals, and reporting.

- **Exchange Online**  
  Mailbox migrations, shared mailbox operations, and clean-up jobs.

- **SharePoint & OneDrive**  
  Permissions, reporting, and bulk operations.

- **Graph API Examples**  
  Connecting with delegated permissions and managed identities, pulling reports, and running automated jobs.

- **Utilities**  
  Reusable helpers such as progress tracking (`Write-ProgressHelper`).

---

How to Use
1. Clone the repository or download individual scripts. 
2.Review each script’s README block at the top. Every script includes:
- Purpose and expected outcome
- Requirements (modules, permissions, PowerShell version)
- Usage examples (including dry-run options if applicable)

3. Test in a non-production environment whenever possible. Many scripts include safety features (e.g., thresholds, -WhatIf), but responsibility for usage remains with you.

Requirements
- PowerShell 5.1+, 7+ (unless otherwise noted)
- Microsoft Graph PowerShell SDK (Install-Module Microsoft.Graph)
- Appropriate delegated or application/managed identity permissions in Entra ID, depending on the script

Each script specifies the exact scopes or application roles needed.

Safety First
- Many scripts include a -WhatIf switch for dry runs. Always start with -WhatIf before enabling destructive operations.
- Some scripts include thresholds (e.g., delete only if < 20 objects). You can disable these when you’re confident, but they’re there to prevent accidents.
- Review the code and adjust for your own environment before running in production.

Contributing
- Contributions are welcome! If you have improvements, bug fixes, or new scripts that may help others:
- Fork the repo
- Submit a pull request

Or open an issue for discussion

Disclaimer
These scripts are provided as-is with no warranties. Use at your own risk. Always test thoroughly before using in production environments.

License
MIT License — you are free to use, modify, and distribute these scripts with proper attribution.

Contact
For questions, suggestions, or feedback, feel free to open an issue in the repo or reach out via GitHub.

---

Would you like me to also generate a **`CONTRIBUTING.md`** template (guidelines for pull requests and s
