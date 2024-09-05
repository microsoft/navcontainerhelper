# BcContainerHelper

BcContainerHelper is a PowerShell module designed to simplify the management of Business Central and Dynamics NAV containers on Docker. As a work-in-progress project, it welcomes contributions through pull requests and ideas. Comprehensive documentation is available in the [NavContainerHelper.md](NavContainerHelper.md).

# Getting Started

There are two primary methods for running these Docker containers: as a [VM on Azure](#vm-on-azure) or [locally](#local-installation).

Using a **VM on Azure** provides a ready-to-go environment within approximately 30 minutes, eliminating the need for manual installation. If you have Azure credits as part of a Visual Studio subscription, you can use them for these VMs, making it a cost-effective option.

While **local installation** requires more initial setup, it offers a fully configured local environment where you can work with Business Central containers even offline.

## VM on Azure

To set up a VM on Azure, follow the steps provided at [aka.ms/getbc](https://aka.ms/getbc).

## Local Installation

Local installation depends on whether you use [Windows 10 or 11](#local-installation-on-windows-10-or-11) or [Windows Server](#local-installation-on-windows-server).

You can choose between Hyper-V isolation or Process isolation:

| Feature                        | Hyper-V Isolation                                                      | Process Isolation                                             |
|--------------------------------|------------------------------------------------------------------------|----------------------------------------------------------------|
| **Isolation Level**            | High: Uses a separate hypervisor-based virtual machine                 | Moderate: Uses namespace and resource control to isolate containers within the same OS instance |
| **Performance**                | Lower: Due to the overhead of running a full VM                        | Higher: Less overhead, as it runs directly on the host OS kernel  |
| **Compatibility**              | Can run different OS versions from the host                            | Limited to running containers that share the same OS and kernel version as the host |
| **Resource Requirements**      | Higher: Requires more CPU and memory due to full VM overhead           | Lower: More efficient use of CPU and memory resources           |
| **Startup Time**               | Slower: Takes longer to start due to VM initialization                 | Faster: Quick startup as it leverages the host OS directly      |
| **Host OS Requirements**       | Requires Windows or Windows Server with Hyper-V enabled                | Requires Windows or Windows Server with container support enabled |

If you can use Process isolation, choose Hyper-V only if necessary due to compatibility issues like using Windows 10.

For more details on setting up your environment, visit the [official documentation](https://learn.microsoft.com/en-us/virtualization/windowscontainers/quick-start/set-up-environment).

### Local Installation on Windows 10 or 11

You can choose between Docker Desktop and installing the Docker Engine via PowerShell.

Before installing Docker, ensure your system meets the following requirements:
- Windows 11 Pro, Enterprise, or Education edition.
- Recommended minimum of 16 GB memory (more is better for running multiple containers simultaneously).

For Hyper-V:
- More memory is recommended as the whole OS runs inside the Docker container VMs.
- A 64-bit processor with Second Level Address Translation (SLAT).
- CPU support for VM Monitor Mode Extension (VT-c on Intel CPUs). Enable hardware virtualization support in the BIOS settings.

#### 1.a Install Docker Desktop

**Note:** Docker Desktop may require a license. Please review the licensing rules before installing and also check out the [System Requirements](https://docs.docker.com/desktop/install/windows-install/#system-requirements).

Download and install Docker Desktop from [docker.com](https://docs.docker.com/desktop/install/windows-install). It will install the Windows Features Containers and Hyper-V.

By default, the Windows Subsystem for Linux (WSL) is enabled, which runs Linux instead of Windows containers.

During installation, set the default container type to Windows containers. To switch after installation, open the system tray, right-click on the Docker icon, and select **Switch to Windows containers...**.

For more details, visit this [Microsoft guide](https://learn.microsoft.com/en-us/virtualization/windowscontainers/quick-start/set-up-environment?tabs=dockerce#windows-10-and-11-1).

#### 1.b Alternative: Install Docker Engine using PowerShell

Install the Windows Feature Containers and optionally Hyper-V.

1. **Open Control Panel:**
   - Press `Win + R` to open the Run dialog box.
   - Type `Control Panel` and press `Enter`.

2. **Navigate to Programs and Features:**
   - In the Control Panel, click on `Programs`.
   - Under `Programs and Features`, click `Turn Windows features on or off`.

3. **Enable Containers:**
   - In the Windows Features dialog, scroll down and locate `Containers`.
   - Check the box next to `Containers` to enable it.

3. **(Optionally) Enable Hyper-V:** 
   - In the Windows Features dialog, scroll down and locate `Hyper-V`.
   - Check the box next to `Hyper-V` to enable it.

4. **Apply Changes and Restart:**
   - Click `OK` to apply the changes.
   - Windows will begin installing Containers and Hyper-V, which might take a few minutes.
   - After the installation is complete, you will be prompted to restart your computer. Click `Restart now` to complete the installation.

Your computer will restart.

Run PowerShell as an administrator:
```PowerShell
Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/microsoft/nav-arm-templates/master/InstallOrUpdateDockerEngine.ps1' -OutFile (Join-Path $ENV:TEMP 'installOrUpdateDocker.ps1')
. (Join-Path $ENV:TEMP 'installOrUpdateDocker.ps1')
```

#### 2. Install BcContainerHelper

Run PowerShell as an administrator:
```PowerShell
Install-PackageProvider -Name NuGet -Force
Install-Module BcContainerHelper -Force
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned
```
**Note:** On Windows 11, you also need to allow running modules with `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned`. For more details, see [this link](https://go.microsoft.com/fwlink/?LinkID=135170).

#### 3. Create Your First Container

Run PowerShell as an administrator:
```PowerShell
$url = Get-BCArtifactUrl -Select Latest -Type OnPrem -Country w1
$cred = Get-Credential
New-BcContainer -accept_eula -artifactUrl $url -Credential $cred -auth UserPassword
```

With these steps, you should be able to set up your environment and start using BcContainerHelper to create and manage Business Central containers on Docker.

### Local Installation on Windows Server

#### 1. Install Docker

Before installing Docker, ensure your system meets the following requirements:
- Windows Server 2016, 2019, or 2022 Standard or Datacenter Edition.
- Recommended minimum of 16 GB memory (more is better for running multiple containers simultaneously).

For Hyper-V:
- More memory is recommended as the whole OS runs inside the VM.
- A 64-bit processor with Second Level Address Translation (SLAT).
- CPU support for VM Monitor Mode Extension (VT-c on Intel CPUs). Enable hardware virtualization support in the BIOS settings.

Run PowerShell as an administrator:
```PowerShell
Install-WindowsFeature Containers -Restart
```
If you want to use Hyper-V, run `Install-WindowsFeature Hyper-V, Containers -Restart` instead. More details on using Hyper-V can be found in the [Business Central Generic Images](#business-central-generic-images) section.

Your computer will restart.

Run PowerShell as an administrator:
```PowerShell
Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/microsoft/nav-arm-templates/master/InstallOrUpdateDockerEngine.ps1' -OutFile (Join-Path $ENV:TEMP 'installOrUpdateDocker.ps1')
. (Join-Path $ENV:TEMP 'installOrUpdateDocker.ps1')
```

#### 2. Install BcContainerHelper

Run PowerShell as an administrator:
```PowerShell
Install-PackageProvider -Name NuGet -Force
Install-Module BcContainerHelper -Force
```

#### 3. Create Your First Container

Run PowerShell as an administrator:
```PowerShell
$url = Get-BCArtifactUrl -Select Latest -Type OnPrem -Country w1
$cred = Get-Credential
New-BcContainer -accept_eula -artifactUrl $url -Credential $cred -auth UserPassword
```

With these steps, you should be able to set up your environment and start using BcContainerHelper to create and manage Business Central containers on Docker.

### Business Central Generic Images

Business Central Generic images are named `mcr.microsoft.com/businesscentral:osversion`, where `osversion` is the version of the Operating System.

BcContainerHelper attempts to find the best matching generic image for your OS. A new generic image is created monthly for all supported long-term servicing channels (LTSC). Currently, this includes three images:
- `mcr.microsoft.com/businesscentral:ltsc2016`
- `mcr.microsoft.com/businesscentral:ltsc2019`
- `mcr.microsoft.com/businesscentral:ltsc2022`

These images will also be tagged with the `osversion`, but BcContainerHelper's `Get-BestGenericImage` will (by default) always return one of the three images above.
- Windows 10 will always get `ltsc2019` and will need Hyper-V isolation to run these.
- Windows 11 will always get `ltsc2022` and can still run process isolation.
- Windows Server 2019 can run process isolation with a matching image.
- Windows Server 2022 can run process isolation with the latest image
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
