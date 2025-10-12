<a id="top"></a>
# 🚀 Software Deployment Tool

_A Windows PowerShell + WinForms utility to deploy or uninstall MSI/EXE packages across one or many machines, with real-time logs, a styled HTML report + CSV, and optional email notifications._

![PowerShell](https://img.shields.io/badge/PowerShell-0078D4?logo=powershell&logoColor=white)
![HTML Report](https://img.shields.io/badge/HTML%20Report-FF6F61?logo=html5&logoColor=white)
![GUI App](https://img.shields.io/badge/GUI-Windows%20Forms-blue)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](#license)

---

### 🔗 Quick Navigation
[Overview](#overview) • [Features](#features) • [Tech Stack](#tech-stack) • [Getting Started](#getting-started) • [Run the GUI](#run-the-gui) • [CLI Usage](#cli-usage) • [Demo Video](#demo-video) • [Screenshots](#screenshots) • [Descriptions](#screenshot-descriptions) • [Planned Enhancements](#planned-enhancements) • [Developer](#developer) • [License](#license)

---

<a name="overview"></a>
## 🧠 Overview

**Software Deployment Tool** simplifies software rollouts and removals for IT administrators.  
Choose **Install** to silently deploy `.msi` / `.exe` installers, or **Uninstall** to remove software by **product name**.  

Each run automatically generates a **timestamped HTML report** and a **CSV log**, and can optionally send an **email notification** with both files attached.  

> 💡 Ideal for repeatable, auditable deployments with both a friendly GUI and scriptable CLI options.

---

<a name="features"></a>
## ✨ Features

- ✅ **Install / Uninstall** with silent switches (`/qn`, `/S`, etc.)
- ✅ **Multi-target** support via `computers.txt` (e.g. multiple PCs or servers)
- ✅ **Smart HTML report** (color-coded and formatted for clarity)
- ✅ **CSV log** (with machine, product, installer, status, time, user)
- ✅ **Detection logic** for “Already Installed / Not Installed”
- ✅ **Uninstall by Product Name** (no file required)
- ✅ **Exit-code tracking** for MSI/EXE (handles 0, 3010, 1605, etc.)
- ✅ **Optional Email notification** (with attachments)
- ✅ **.gitignore** ready (to exclude logs, reports, and personal data)

---

<a name="tech-stack"></a>
## 💻 Tech Stack

| Layer | Technology |
|------:|------------|
| Scripting | PowerShell 5+ |
| UI | Windows Forms (.NET) |
| Reporting | HTML + CSS |
| Email | SMTP |
| Logging | CSV + HTML (auto timestamped) |

---

<a name="getting-started"></a>
## ⚙️ Getting Started

### 1️⃣ Clone Repository
~~~bash
git clone https://github.com/MoustafaObari/SoftwareDeploymentTool.git
cd SoftwareDeploymentTool
~~~

### 2️⃣ (Optional) Configure Email
Open `SendDeploymentEmail.ps1` and update the SMTP configuration:  
Use a Gmail App Password or your internal SMTP server credentials.

> ⚠️ Avoid storing real credentials in public repositories.

### 3️⃣ Define Targets
Edit `computers.txt` and list your target machines (or `localhost`):
~~~
localhost
PC-01
ServerA
~~~

---

<a name="run-the-gui"></a>
## 🪟 Run the GUI

~~~powershell
# From the repository root
powershell -ExecutionPolicy Bypass -File .\DeploymentToolGUI.ps1
~~~

**Mode Options:**
- **Install** → select one or more `.msi` / `.exe` files  
- **Uninstall** → enter one or more product names (e.g., `VLC;Google Chrome`)  
- **Email** → optional recipient for automated notifications  
- **Targets** → read from `computers.txt` or input manually  

When you click **Start Deployment**, the script executes your action, generates reports under:
- 📂 `HTML reports\`
- 📂 `logs\`

---

<a name="cli-usage"></a>
## 🧰 CLI Usage

> You can run the same functionality without the GUI for automation or scheduling.

**Install Example**
~~~powershell
.\DeploySoftware.ps1 -Mode Install `
  -InstallerPaths "C:\Apps\Google Chrome.msi;C:\Apps\VLC.msi" `
  -Computers localhost
~~~

**Uninstall Example**
~~~powershell
.\DeploySoftware.ps1 -Mode Uninstall `
  -InstallerPaths "VLC;Google Chrome" `
  -Computers "PC-01;localhost"
~~~

**Generate HTML Report Only**
~~~powershell
.\GenerateReport.ps1
~~~

**Send Latest Report via Email**
~~~powershell
.\SendDeploymentEmail.ps1 -RecipientEmail you@example.com
~~~

---

<a name="demo-video"></a>
## 🎥 Demo Video

🎬 **Watch the full walkthrough:**  
👉 [Click to Watch the Demo on GitHub](https://github.com/MoustafaObari/SoftwareDeploymentTool/blob/main/Software%20deployment%20tool%20demo.mp4)  

> Demonstrates install, uninstall, and email reporting in a real PowerShell session.

---

<a name="screenshots"></a>
## 🖼️ Screenshots

| Folder Structure | Launch GUI | Select Installers |
|---|---|---|
| ![01](Screenshots/01_Folder-Structure.png) | ![02](Screenshots/02_Launch-GUI.png) | ![03](Screenshots/03_Select-Installers.png) |

| Ready (Email filled) | Start Deployment | Install – Run & Success |
|---|---|---|
| ![04](Screenshots/04_Ready-With-Email.png) | ![05](Screenshots/05_Start-Deployment.png) | ![06](Screenshots/06_Install-Run-And-Success.png) |

| Uninstall – Run & Success | CSV Log | HTML Report (Install) |
|---|---|---|
| ![07](Screenshots/07_Uninstall-Run-And-Success.png) | ![08](Screenshots/08_DeployLog-CSV.png) | ![09](Screenshots/09_HTML-Report-Install.png) |

| HTML Report (Uninstall) | Email Notification |
|---|---|
| ![10](Screenshots/10_HTML-Report-Uninstall.png) | ![11](Screenshots/11_Email-Notification.png) |

---

<a name="screenshot-descriptions"></a>
## 📘 Screenshot Descriptions

| # | File | Description |
|--:|---|---|
| 1 | `01_Folder-Structure.png` | Project layout showing scripts, logs, reports, and screenshots |
| 2 | `02_Launch-GUI.png` | WinForms interface with inputs for mode, files, targets, and email |
| 3 | `03_Select-Installers.png` | Multiple installers selected for deployment |
| 4 | `04_Ready-With-Email.png` | Email recipient entered and ready to deploy |
| 5 | `05_Start-Deployment.png` | Deployment process running in real-time |
| 6 | `06_Install-Run-And-Success.png` | Successful install summary |
| 7 | `07_Uninstall-Run-And-Success.png` | Successful uninstall confirmation |
| 8 | `08_DeployLog-CSV.png` | CSV log showing timestamps, results, and targets |
| 9 | `09_HTML-Report-Install.png` | HTML report of installed applications |
| 10 | `10_HTML-Report-Uninstall.png` | HTML report of uninstalled applications |
| 11 | `11_Email-Notification.png` | Email notification with attached logs and reports |

---

<a name="planned-enhancements"></a>
## 🧩 Planned Enhancements

- 🚀 Add **parallel remote execution** for faster deployments  
- 🧱 Support **Teams/Slack notifications** post-run  
- 📈 Add **visual status charts** in HTML reports  
- 🧰 Introduce **dry-run mode** (preview before execution)  
- 🗂️ Publish future demo assets via **GitHub Releases / LFS**  

---

<a name="developer"></a>
## 👨‍💻 Developer

**Moustafa Obari**  
Software Engineer • Cloud & Automation Enthusiast  

🔗 [GitHub Profile](https://github.com/MoustafaObari)  
🔗 [LinkedIn Profile](https://www.linkedin.com/in/moustafaobari)

---

<a name="license"></a>
## 📄 License (MIT)

~~~text
MIT License

Copyright (c) 2025 Moustafa Obari

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights  
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell  
copies of the Software, and to permit persons to whom the Software is  
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all  
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR  
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,  
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE  
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER  
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,  
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE  
SOFTWARE.
~~~

---

> 💬 “Shipping software to many machines shouldn’t be scary — with this tool, it’s clear, auditable, and fast.”

[⬆ Back to Top](#top)
