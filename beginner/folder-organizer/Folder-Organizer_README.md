# Advanced File Organizer

This PowerShell script automates file organization and supports
email notifications and optional desktop notifications.

⚠️ **Important:**  
Sensitive configuration files are intentionally **NOT included**
in this repository. You must create them manually before running
the script.

---

## 📂 Expected Folder Structure
``` text
folder-organizer/
├── Advanced-File-Organizer.ps1
├── README.md
├── config.json ← REQUIRED (you create this)
└── gmail-cred.xml ← REQUIRED for email notifications

```
---

## ⚠️ Configuration Required (READ FIRST)

Before running the script, create **both** configuration files
in this folder.

---

## 1️⃣ Create `config.json`

This file controls:
- Email notification settings
- Popup notifications

### 📄 Copy & Paste Template

```json
{
  "Email": {
    "Enable": true,
    "To": "your-email@gmail.com",
    "From": "File Organizer Bot",
    "SMTPServer": "smtp.gmail.com",
    "Port": 587,
    "UseSSL": true,
    "Subject": "File Organizer Report"
  },
  "Notification": {
    "ShowPopup": false

```
🔧 Notes

Set "Enable": false to disable email notifications

Gmail requires TLS (Port 587) and App Passwords

"ShowPopup" controls local desktop notifications

2️⃣ Create gmail-cred.xml

This file stores email credentials securely using
PowerShell’s PSCredential format.

🛠 How to Generate gmail-cred.xml

Run this command ONCE in PowerShell:
```
Get-Credential | Export-Clixml gmail-cred.xml
```

When prompted:

Username: your Gmail address
Password: your Google App Password (NOT your real password)

This creates an encrypted credential file usable only on your machine.
