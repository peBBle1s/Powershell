[![Latest Release](https://img.shields.io/github/v/release/peBBle1s/Powershell?style=for-the-badge&label=Download%20Latest%20Version&color=2ea44f)](https://github.com/peBBle1s/Powershell/releases/latest)

# PowerShell Automation Suite

A curated collection of PowerShell scripts designed to automate development workflows, organize files, and perform system maintenance.

## 📂 Repository Structure

-Getting Started
-Clone the repository

-Set Execution Policy: You may need to allow script execution on your machine:
  (PowerShell only)
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

Navigate and Run: Go to the specific folder of the script you want to use and follow the specific README.md instructions in that folder.

```text

┌────────────────────────────────────────┐
│                STRUCTURE               │
└────────────────────────────────────────┘


Powershell
│   .gitignore
│   androidstudio-vscode-sync.ps1
│   try.ps1
│
└───beginner
    ├───disk-cleanup
    │       disk_cleanup.ps1
    │
    └───folder-organizer
            Advanced-File-Organizer.ps1
            (Config files required - see documentation)
