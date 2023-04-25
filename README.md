# BcContainerHelper

This repository contains a module, which makes it easier to work with Business Central and NAV Containers on Docker.
The module is work in progress and feel free to submit pull requests and contribute with good ideas.
Documentation will be on the wiki.

# Getting Started

## VM on Azure
- Follow the steps on https://aka.ms/getbc

## Local Installation on Windows or Windows Server
This would be the Steps to install Docker and BCContainerHelper on Windows 11 or Windows Server 2022:

### 1. Install Windows Containers Feature
Run PowerShell as Admin:
```PowerShell
Install-WindowsFeature Containers -Restart
```
Computer restarts.

### 2.a. Download and Install Docker Desktop from docker.com
**NOTE:** You need either Docker Desktop or Docker Engine to run Docker on your computer - not both.

Follow the process here: https://docs.docker.com/desktop/install/windows-install

**NOTE** Docker Desktop might require a license, please consult the licensing rules before installing

### 2.b. Install Docker Engine using PowerShell
**NOTE:** You need either Docker Desktop or Docker Engine to run Docker on your computer - not both.

Run PowerShell as Admin:
```PowerShell
Invoke-WebRequest -UseBasicParsing -uri 'https://raw.githubusercontent.com/microsoft/nav-arm-templates/master/InstallOrUpdateDockerEngine.ps1' -OutFile (Join-Path $ENV:TEMP 'installorUpdateDocker.ps1')
. (Join-Path $ENV:TEMP 'installorUpdateDocker.ps1')
```

### 3. Install BcContainerHelper
Run PowerShell as Admin:
```PowerShell
Install-PackageProvider -Name NuGet -force
Install-Module BcContainerHelper -force
```

### 4. Create you first container
Run PowerShell as Admin:
```PowerShell
$url = Get-BCArtifactUrl -select Latest -type OnPrem -country w1
$cred = Get-Credential
New-BcContainer -accept_eula -artifactUrl $url -Credential $cred -auth UserPassword
```

# Branches

**NavContainerHelper** is the main repo for the NavContainerHelper PowerShell module on PowerShell Gallery. **NavContainerHelper** will as of August 1st 2020 only receive bug fixes.

**master** is the main repo for the BcContainerHelper PowerShell module on PowerShell Gallery. **BcContainerHelper** will from August 1st 2020 ship as release and pre-release.

Please report issues in the issues list.

# Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.microsoft.com.

When you submit a pull request, a CLA-bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., label, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
