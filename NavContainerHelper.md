# NavContainerHelper

# <a name="toc"></a>Table of content

1. [What are Containers? What is Docker?](#WhatAreContainers)
1. [Get started - Install Docker](#GetStarted)
1. [Get Started - Install NavContainerHelper](#GetStartedHelper)
1. [Get started - Run your first NAV container](#GetStartedRun)
1. [NAV container image tags](#ImageTags)
1. [Scenarios using the NavContainerHelper](#Scenarios)
    1. [Use SSL with a self-signed certificate](#SSLSelfSigned)
    1. [Use SSL with a LetsEncrypt certificate](#SSLLetsEncrypt)
    1. [Use a certificate, issued by a trusted authority](#SSLTrusted)
    1. [Specify username and password for your NAV SUPER user](#UserPassword)
    1. [Setup Windows Authentication with the Windows User on the host computer](#WinAuth)
    1. [Publishing ports on the host and specifying a hostname using NAT network settings](#PublishPorts)
    1. [Make CSIDE and Windows Client available on the host computer](#WinClients)
    1. [Make CSIDE and Windows Client available through ClickOnce](#ClickOnce)
    1. [Use your own license file in a container](#License)
    1. [Suppress deployment of the WebClient and/or Http site when running a container](#NoWeb)
    1. [Publish an extension to a NAV container](#Extension)
    1. [Import and compile objects in a NAV container](#ImportCompile)
    1. [Export objects from a NAV container](#export)
    1. [Specify your own Database backup file to use with a NAV container](#bak)
    1. [Start a NAV container and place the database files on a file share on the host computer](#DbShare)
    1. [Create a SQL Server container with the CRONUS database from a NAV container image](#SqlCronus)
    1. [Create a SQL Server container and restore a .bak file](#SqlBak)
    1. [Use an external SQL Server as database connection in a NAV container](#ExternalSql)
    1. [Connect to the NAV container and develop using Visual Studio Code](#VsCode)
1. [Scripts](#Scripts)

# <a name="WhatAreContainers"></a>What are Containers? What is Docker?

If you are new to Docker and Containers, please read [this document](https://docs.microsoft.com/en-us/virtualization/windowscontainers/about/), which describes what Containers are and what Docker is.

If you want more info, there are a lot of [Channel9 videos on Containers as well](https://channel9.msdn.com/Search?term=containers#ch9Search&amp;lang-en=en&amp;pubDate=year)

If you have problems with Docker (not NAV related), the [Windows Containers Docker forum](https://social.msdn.microsoft.com/Forums/en-US/home?forum=windowscontainers) is the place you can ask questions (read the readme first):

[Back to TOC](#toc)

# <a name="GetStarted"></a>Get started – Install Docker

In order to run a NAV container, you need a computer with Docker installed, this will become your Docker host. Docker runs on Windows Server 2016 (or later) or Windows 10 Pro.

When using Windows 10, Containers are always using Hyper-V isolation with Windows Server Core. When using Windows Server 2016, you can choose between Hyper-V isolation or Process isolation. Read more about this [here](https://docs.microsoft.com/en-us/virtualization/windowscontainers/about/).

I will describe 3 ways to get started with Containers. If you have a computer running Windows Server 2016 or Windows 10 – you can use this computer. If not, you can deploy a Windows Server 2016 with Containers on Azure, which will give you everything to get started.

## Windows Server 2016 with Containers on Azure

In the Azure Gallery, you will find an image with Windows Server 2016 and Docker installed and pre-configured. You can deploy this image by clicking [this link](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FMicrosoft%2FVirtualization-Documentation%2Flive%2Fwindows-server-container-tools%2Fcontainers-azure-template%2Fazuredeploy.json).

**Note**, do not select Standard_D1 (simply not powerful enough) – use at least Standard_D2 or Standard_D3.

In this VM, you can now run all the docker commands, described in this document.

## Windows Server 2016

Follow [these steps](https://docs.microsoft.com/en-us/virtualization/windowscontainers/quick-start/quick-start-windows-server) to install Docker on a machine with Windows Server 2016.

## Windows 10

Follow [these steps](https://docs.microsoft.com/en-us/virtualization/windowscontainers/quick-start/quick-start-windows-10) to install Docker on Windows 10.

[Back to TOC](#toc)

# <a name="GetStartedHelper"></a>Get Started - Install NavContainerHelper

NavContainerHelper is a PowerShell module from the PowerShell Gallery, you can read more information about it [here](https://www.powershellgallery.com/packages/navcontainerhelper).

The module contains a number of PowerShell functions, which helps running and interacting with NAV containers.

On your Docker host, start PowerShell ISE and run:

    install-module navcontainerhelper -force

Use

    get-command -Module navcontainerhelper

to list all functions available in the module. Use

    Write-NavContainerHelperWelcomeText

in order to list the functions in the module grouped into areas.

[Back to TOC](#toc)

# <a name="GetStartedRun"></a>Get started – run your first NAV container

Start PowerShell ISE and run this command:

    New-NavContainer -accept_eula -containerName "test" -auth NavUserPassword -imageName "microsoft/dynamics-nav"

to run your first NAV container using NavUserPassword authentication. PowerShell will pop up a dialog and require you to enter a username and a password to use for the container.

New-NavContainer will remove existing containers with the same name before starting a new container. The container will be started as a process and the output of the function will be displayed in the PowerShell output window.

    PS C:\Users\freddyk> New-NavContainer -accept_eula -containerName "test" -auth NavUserPassword -imageName "microsoft/dynamics-nav"
    Creating Nav container test
    Using image microsoft/dynamics-nav
    NAV Version: 11.0.20783.0-w1
    Generic Tag: 0.0.5.3
    Creating container test from image microsoft/dynamics-nav
    Waiting for container test to be ready
    Initializing...
    Starting Container
    Hostname is test
    PublicDnsName is test
    Using NavUserPassword Authentication
    Starting Local SQL Server
    Starting Internet Information Server
    Creating Self Signed Certificate
    Self Signed Certificate Thumbprint 0A4F70380C95876A708018EA6883CA3A1F7FF72D
    Modifying NAV Service Tier Config File with Instance Specific Settings
    Starting NAV Service Tier
    Creating DotNetCore NAV Web Server Instance
    Creating http download site
    Creating Windows user admin
    Setting SA Password and enabling SA
    Creating admin as SQL User and add to sysadmin
    Creating NAV user
    Container IP Address: 172.19.144.74
    Container Hostname  : test
    Container Dns Name  : test
    Web Client          : http://test/NAV/
    Dev. Server         : http://test
    Dev. ServerInstance : NAV

    Files:
    http://test:8080/al-0.12.17720.vsix

    Initialization took 59 seconds
    Ready for connections!
    Reading CustomSettings.config from test
    Creating Desktop Shortcuts for test
    NAV container test successfully created

The New-NavContainer will use the docker command to run the container, and will be building up the needed parameters for docker run dynamically, based on the parameters you specify to New-NavContainer.

You can also use docker run to run a container yourself

    docker run -e ACCEPT_EULA=Y microsoft/dynamics-nav

**Note**, if you are running *Windows 10* , you will have to add *--memory 4G* as an extra parameter to the docker run command above (and in all docker run commands in this doc.)

This will start a container with a random name, a random password, using SSL with a self-signed certificate and using admin as the username. The prompt in which you are running the command will be attached to the container and the output will be displayed. You can add a number of extra parameters to specify password, database connection, license file, configurations, etc. etc.

The docker run command created by the New-NavContainer call above will be something like:

    docker run --name test `
               --hostname test `
               --env auth=NavUserPassword `
               --env username="admin" `
               --env ExitOnError=N `
               --env locale=en-US `
               --env licenseFile="" `
               --env databaseServer="" `
               --env databaseInstance="" `
               --volume "C:\ProgramData\NavContainerHelper:C:\ProgramData\NavContainerHelper" `
               --volume "C:\ProgramData\NavContainerHelper\Extensions\test\my:C:\Run\my" `
               --restart unless-stopped `
               --env useSSL=N `
               --env securePassword=<encryptedpasword> `
               --env passwordKeyFile="c:\run\my\aes.key" `
               --env removePasswordKeyFile=Y `
               --env accept_eula=Y `
               --detach `
               microsoft/dynamics-nav

**Note**, if you are running **Windows 10**, New-NavContainer will automatically add --memory 4G to the docker run command.

all parameters starting with --env means that docker is going to set an environment variable in the container. This is the way to transfer parameters to the NAV container. All the --env parameters will be used by the PowerShell scripts inside the container. All the non --env parameters will be used by the docker run command.

The --name parameter specifies the name of the container and the --hostname specifies the hostname of the contianer.

--volume parameters shared folders from the docker host to the container and --detach means that the container process will be detached from the process starting it.

The NAV container images supports a number of parameters and some of them are used in the above output. All of these parameters can be omitted and the NAV container image has a default behavior for them.

As you might have noticed, the New-NavContainer transfers the password to the container as an encrypted string and the key to decrypt the password is shared in a file and deleted afterwards. This allows you to use Windows Authentication with your domain credentials in a secure way.

[Back to TOC](#toc)

# <a name="ImageTags"></a>NAV container image tags

Public NAV container images resides in the public Docker hub and can be viewed [here](https://hub.docker.com/r/microsoft/dynamics-nav/).

In the public docker hub you will find both the generic NAV container image and the specific NAV container images.

The generic NAV container image is the foundation of all the specific NAV container images and can be used for running any version of NAV since NAV 2013, if the NAV DVD is shared with it. The specific images have a version of NAV pre-installed and pre-configured, ready to configure and run.

The way, the image is architected, you should not need to build your own image, you can use and run the images as they are. If you for some reason need to, you can also build your own images based on the generic or specific images.

## microsoft/dynamics-nav:generic

The latest generic image is tagged with *generic*. Furthermore, all generic images are also tagged with *generic-\<genericversion\>*.

## microsoft/dynamics-nav:navversion-cu-localization

Docker images in the public Docker hub are tagged with a combination of the version of NAV, the Cumulative update number and the localization installed. All the parts in the tag can be omitted and will default to the latest version of NAV, the latest cumulative update and W1 as the default localization.

All images are also tagged with the build number of NAV followed by the localization.

Example:

- **microsoft/dynamics-nav** will give you the latest cumulative update of the latest version of NAV with W1 localization.
- **microsoft/dynamics-nav:2017** will give you the latest NAV 2017, W1 version.
- **microsoft/dynamics-nav:2018-cu1** will give you NAV 2018 CU1, W1 version.
- **microsoft/dynamics-nav:2017-dk** will give you the latest NAV 2017, DK version.
- **microsoft/dynamics-nav:2017-rtm-na** will give you the RTM version of NAV 2017, NA version.
- **microsoft/dynamics-nav:2016-cu22-dk** will give you NAV 2016 CU22, DK version.
- **microsoft/dynamics-nav:10.0.17501.0** will give you a specific build of NAV (in this case, NAV 2017 CU8 W1).
- **microsoft/dynamics-nav:10.0.17501.0-dk** will give you a specific DK build of NAV (in this case, NAV 2017 CU8 DK).

With this pattern, you can specify any version of NAV since NAV 2016 RTM.
**Note**, image names and tags are case sensitive – everything must be specified in lower case.

[Back to TOC](#toc)

# <a name="Scenarios"></a>Scenarios using the NavContainerHelper

In the following, I will go through some scenarios, you might find useful when running NAV containers. Most of the scenarios can be combined, but in some cases, it doesn't make sense to combine them.

## <a name="SSLSelfSigned"></a>Use SSL with a self-signed certificate

I you want to add a certificate to a container started by New-NavContainer, you can use the parameter:

    -useSSL

Example:

    New-NavContainer -accept_eula `
                     -useSSL `
                     -containerName "test" `
                     -auth NavUserPassword `
                     -imageName "microsoft/dynamics-nav"

You will notice, that the output section looks slightly different:

    Container IP Address: 172.19.145.168
    Container Hostname  : test
    Container Dns Name  : test
    Web Client          : https://test/NAV/
    Dev. Server         : https://test
    Dev. ServerInstance : NAV

    Files:
    http://test:8080/al-0.12.17720.vsix
    http://test:8080/certificate.cer

The Web Client and Dev. Server are both secured with a self-signed certificate (https) and the link to download and trust this certificate on your computer is displayed underneath.

**Note**, The -useSSL parameter causes a New-NavContainer to add *--env useSSL=Y* to the docker run command.

**Note**, if you are planning to expose your container outside the boundaries of your own machine, you should always use SSL.

[Back to TOC](#toc)

## <a name="SSLLetsEncrypt"></a>Use SSL with a LetsEncrypt certificate

LetsEncrypt is a certificate provider which issues free SSL certificates for services. Furthermore, there is a PowerShell module, which enables you to do this automatically.

This PowerShell module is being used in the NAV ARM Templates (like http://aka.ms/getnav) and the code can be found [here](https://github.com/Microsoft/nav-arm-templates/blob/master/initialize.ps1) (search for LetsEncrypt).

The code to import and use the certificate is the same as you use when using a certificate issued by a trusted authority.

[Back to TOC](#toc)

## <a name="SSLTrusted"></a>Use a certificate, issued by a trusted authority

There are no parameters in which you can specify a certificate directly. Instead, you will have to override the SetupCertificate script in the Docker image.

Overriding scripts is done by specifying adding a parameter called

    -myScripts @(file1, file2)

The files specified in myScripts will be copied to a folder, which is shared to the container as c:\run\my. You can see more about overriding scripts laer in this document.

Create a script file called SetupCertificate.ps1 with this content:

    $certPfxFile = Join-Path $PSScriptRoot "navdemo.net.pfx"
    $certPfxPassword = "Password"
    $dnsidentity = "navdemo.net"
    $publicDnsname = "${hostname}.${dnsidentity}"

    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList $certPfxFile,$certPfxPassword
    $certificateThumbprint = $cert.Thumbprint

    Write-Host "Certificate File Thumbprint $certificateThumbprint"
    if (!(Get-Item "Cert:\LocalMachine\my\$certificateThumbprint" -ErrorAction SilentlyContinue)) {
        Write-Host "Import Certificate to LocalMachine\my"
        $certPfxSecurePassword = ConvertTo-SecureString -String $certPfxPassword -AsPlainText -Force
        Import-PfxCertificate -FilePath $certPfxFile -CertStoreLocation "cert:\localmachine\my" -Password $certPfxSecurePassword | Out-Null
    }

If the certificate you use isn't issued by an authority, which is in the Trusted Root Certification Authorities, then you will have to import the pfx file to LocalMachine\root as well as LocalMachine\my, using this line:

    Import-PfxCertificate -FilePath $certPfxFile -CertStoreLocation "cert:\localmachine\root" -Password $certPfxSecurePassword | Out-Null

Example:

    New-NavContainer -accept_eula `
                     -useSSL `
                     -myscripts @("c:\temp\SetupCertificate.ps1", "C:\temp\navdemo.net.pfx") `
                     -containerName "test" `
                     -auth NavUserPassword `
                     -imageName "microsoft/dynamics-nav"

**Note**, for this to work, the publicdnsname (here test.navdemo.net) specified in the script needs to exist in the DNS and point to the host computer, typically this is done by creating a CNAME record.

**Note**, New-NavContainer creates a folder for the files specified in -myscripts and shares this folder to the c:\run\my folder in a container using *--volume \<hostfolder\>:c:\run\my*.

[Back to TOC](#toc)

## <a name="UserPassword"></a>Specify username and password for your NAV SUPER user

The parameter needed to specify username and password for your NAV Super user is

    -credential $credential

The credentials are of type System.Management.Automation.PSCredential and can be created like this

    $securePassword = ConvertTo-SecureString -String "P@ssword1" -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential -argumentList "admin", $securePassword

or, if you want to ask the user to enter the credentials in a dialog

    $credential = get-credential

The Nav-ContainerHelper transfers the password to the container as an encrypted string and the key to decrypt the password is shared in a file and deleted afterwards. This allows you to use Windows Authentication with your domain credentials in a secure way.

Example:

    if ($credential -eq $null -or $credential -eq [System.Management.Automation.PSCredential]::Empty) {
        $credential = get-credential -UserName "admin" -Message "Enter NAV Super User Credentials"
    }
    New-NavContainer -accept_eula `
                     -containerName "test" `
                     -auth NavUserPassword `
                     -imageName "microsoft/dynamics-nav" `
                     -Credential $credential

**Note**, if you use docker run to run your container, you will transfer credentials in clear text to the container and can be retrieved by a simple docker inspect on the host. If you want to transfer the password securely, you need to encrypt the password and transfer a file containing the encryption key to the container using the two environment variables securepassword, passwordkeyfile and removepasswordkeyfile, this is what the NavContainerHelper is doing.

[Back to TOC](#toc)

## <a name="WinAuth"></a>Setup Windows Authentication with the Windows User on the host computer

The parameter used to specify that you want to use Windows Authentication is

    -auth Windows

Which also is the default if you do not specify -auth.
A container doesn't have its own Active Directory and cannot be joined into an AD, but you can still setup Windows Authentication by sharing your domain credentials to the container.

Example:

    New-NavContainer -accept_eula `
                     -containerName "test" `
                     -auth Windows `
                     -imageName "microsoft/dynamics-nav" `
                     -Credential $credential

**Note**, if the host computer cannot access the domain controller, Windows authentication might not work properly.

[Back to TOC](#toc)

## <a name="PublishPorts"></a>Publishing ports on the host and specifying a hostname using NAT network settings

Network settings on Docker can be setup in a lot of different ways. Please consult the Docker documentation or [this blog post](https://docs.microsoft.com/en-us/virtualization/windowscontainers/manage-containers/container-networking).

to learn more about container networking. When installing Docker, by default it creates a NAT network. This scenario explains how to publish ports using NAT network settings only. Publishing ports enables you to access the Container from outside the host computer.

The New-NavContainer doesn't have any parameters for publishing ports, you have to add the native docker run parameters to publish ports. In order to specify native docker run parameters to New-NavContainer you can use:

    -additionalParameters @(parameter1, parameter2)

The parameters used for publishing ports on the host and specifying a hostname are not specific to the NAV container image, but are generic Docker parameters:

    --publish <PortOnHost>:<PortInContainer>

In order for a port to be published on the host, the port needs to be exposed in the container. By default, the NAV container image exposes the following ports:

    8080   file share
      80   http
     443   https
    1433   sql
    7045   management
    7046   client
    7047   soap
    7048   odata
    7049   development

If you want to publish all exposed ports on the host, you can use: --publish-all or -P (capital P).

**Note**, publishing port 1433 on an internet host might cause your computer to be vulnerable for attacks.

Example:

    $additionalParameters = @("--publish 8080:8080",
                              "--publish 443:443", 
                              "--publish 7046-7049:7046-7049")
    New-NavContainer -accept_eula `
                     -containerName "test" `
                     -useSSL `
                     -auth NavUserPassword `
                     -imageName "microsoft/dynamics-nav" `
                     -additionalParameters $additionalParameters

In this example, the ports 8080, 443, 7045, 7046, 7047, 7048 and 7049 are all published on host computer and you can use your host computers public ip address followed by the port number to connect.

**Note**, you cannot use localhost to connect to your container from the host, you need to use the public/external ip address.

[Back to TOC](#toc)

## <a name="WinClients"></a>Make CSIDE and Windows Client available on the host computer

New-NavContainer supports sharing the Classic Development Environment and the Windows Client from the container to the host. The parameter you need to use is:

    -includeCSIDE

This will cause New-NavContainer to share **C:\ProgramData\NavContainerHelper\Extensions\containername\Program Files** with the container and also share a script, which will copy the files from the Windows Client folder to this folder. New-NavContainer will also place a ClientUserSettings.config file in the same folder and create shortcuts on the desktop for CSIDE and for the Windows Client.

Specifying -includeCSIDE also causes the New-NavContainer to export the baseline objects to a folder if this hasn't already been done. These baseline objects are used by the other functions in the navcontainerhelper to generate deltas of changes in the app. You need to specify a licensefile for this to work or you can disable this behavior by adding another parameter:

    -doNotExportObjectsToText

Example:

    New-NavContainer -accept_eula `
                     -containerName "test" `
                     -auth NavUserPassword `
                     -imageName "microsoft/dynamics-nav" `
                     -includeCSIDE `
                     -doNotExportObjectsToText

**Note**, running CSIDE on the host requires installation of two pre-requisites on the host [vcredist_x86](https://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x86.exe) and [sqlncli](https://download.microsoft.com/download/3/A/6/3A632674-A016-4E31-A675-94BE390EA739/ENU/x64/sqlncli.msi).

**Note**, when using the classic development environment (CSIDE) you won't be able to modify and compile table schemas unless you are using Windows Authentication.

[Back to TOC](#toc)

## <a name="ClickOnce"></a>Make CSIDE and Windows Client available through ClickOnce

The New-NavContainer doesn't have a parameter to enable clickonce

The NAV containers supports ClickOnce, but The New-NavContainer doesn't have a parameter to enable clickonce, so you have to add this to additionalParameters:

    --env clickonce=Y

Example:

    $additionalParameters = @("--env clickonce=Y")
    New-NavContainer -accept_eula `
                     -containerName "test" `
                     -auth NavUserPassword `
                     -imageName "microsoft/dynamics-nav" `
                     -additionalParameters $additionalParameters

You will notice, that the output section has a few extra lines:

    Creating ClickOnce Manifest
    Container IP Address: 172.19.158.132
    Container Hostname  : test
    Container Dns Name  : test
    Web Client          : http://test/NAV/
    Dev. Server         : http://test
    Dev. ServerInstance : NAV
    ClickOnce Manifest  : http://test:8080/NAV

    Files:
    http://test:8080/al-0.12.17720.vsix
    http://test:8080/certificate.cer

Open the ClickOnce Manifest in Internet Explorer og Microsoft Edge, download and start the Windows Client.

**Note**, when using Google Chrome for downloading you might get an error stating: Cannot start Application. The underlying error is "Deployment and application do not have matching security zones." and I have been unable to find a workaround (except for using IE or Edge).

**Note**, when using the classic development environment (CSIDE) you won't be able to modify and compile table schemas unless you are using Windows Authentication.

[Back to TOC](#toc)

## <a name="License"></a>Use your own license file in a container

By default the NAV containers are using the CRONUS demo database and the CRONUS demo license file is already imported in that. If you want to use you own licensefile, you have a few options on how to do this.

### Specify a database which already contains a license file

If you are connecting to a foreign database server or you have specified a database backup which already contains a license file, then there is no need to specify a lciens

### Specify a secure Url to a license file

If you have a secure Url from which you can download your license file, you can specify this Url as a parameter

    -licenseFile "<secure license file Url>"

The secure license file Url needs to start with http or https, in which case, the script will proceed to download the license file and import it into the NAV Database. Information on how to create a secure url can be found [here](https://blogs.msdn.microsoft.com/freddyk/2017/02/26/create-a-secure-url-to-a-file/).

Example:

    New-NavContainer -accept_eula `
                     -containerName "test" `
                     -auth NavUserPassword `
                     -imageName "microsoft/dynamics-nav" `
                     -Credential $credential `
                     -licensefile "https://www.dropbox.com/s/abcdefghijkl/mylicense.flf?dl=1"

**Note**, when you specify a licensefile to New-NavContainer, it will always import that license file, also if you are specifying a foreign database server or your own bak file.

### Specify the path of a license file

If the license file is accessible from the container through a path, you can specify this path as a parameter

    -licenseFile "<path to license file>"

Example:

    $additionalParameters = @("-v c:\temp:c:\temp")
    New-NavContainer -accept_eula `
                     -containerName "test" `
                     -auth NavUserPassword `
                     -imageName "microsoft/dynamics-nav" `
                     -Credential $credential `
                     -additionalParameters $additionalParameters `
                     -licensefile "c:\temp\mylicense.flf"

in this sample, the host c:\temp folder is shared to the container as c:\temp and the mylicense file from this folder is used.

**Note**, when you specify a licensefile to New-NavContainer, it will always import that license file, also if you are specifying a foreign database server or your own bak file.

### Override the SetupLicense script

You can also choose to override the script, which imports the license file and take all in your own hands.

The SetupLicense script is executed as the first thing after the Service Tier has started and it is invoked always. This means that you need to determine whether or not you need to install a license file. If you add a file called SetupLicense.ps1 to -myScripts, then this script will be executed instead of the default script.

Please inspect the file c:\run\SetupLicense.ps1 in the container for the default behavior and see Appendix 1 – Scripts for information about how to override scripts.

Example:

    $setupLicenseScript = @'
    if ($restartingInstance) {
        # Nothing to do
    } else {
        Import-NAVServerLicense -ServerInstance $ServerInstance -LicenseFile "c:\run\my\my.flf" -Database NavDatabase -WarningAction SilentlyContinue
    }
    '@

    New-NavContainer -accept_eula `
                     -containerName "test" `
                     -auth NavUserPassword `
                     -imageName "microsoft/dynamics-nav" `
                     -myScripts @("https://www.dropbox.com/s/abcdefghijkl/my.flf?dl=1", @{"SetupLicense.ps1" = $setupLicenseScript})

This script will download the my.flf file and place it in the c:\run\my folder and place the script above in the SetupLicense.ps1 file. The same syntax can be used with a file on the host computer.

**Note**, if you specify a .zip file in myscripts, it will be extracted into the c:\run\my folder in the container.

### Use Import-NavContainerLicense on a running container

If you want to import a license to an already running container, you can use the Import-NavContainerLicense function from the navcontainerhelper.

Example:
    Import-NavContainerLicense -containerName test -licenseFile "https://www.dropbox.com/s/abcdefghijkl/mylicense.flf?dl=1"

The license file parameter can be a file on the host or a secure url.

[Back to TOC](#toc)

## <a name="NoWeb"></a>Suppress deployment of the WebClient and/or Http site when running a container

If you need to run a container in order to perform a task (like running tests, reports, conversions or other things), there might not be any reason to deploy the Web Client (takes ~10-20 seconds). If you specify the parameter *WebClient=N* to the NAV container image, then the WebClient will not be deployed. When using NavContainerHelper, this parameter goes in additionalParameters.

    $additionalParameters = @("--env WebClient=N")

If you suppress WebClient, you might also want to suppress the deployment of the http site for file downloads. If both gets suppressed, then the IIS is never started in the container. This saves both memory and time.

    $additionalParameters += @("--env httpsite=N")

Example:

    New-NavContainer -accept_eula `
                     -containerName "test" `
                     -auth NavUserPassword `
                     -imageName "microsoft/dynamics-nav" `
                     -additionalParameters @("--env WebClient=N", "--env httpsite=N")

[Back to TOC](#toc)

## <a name="Extension"></a>Publish an extension to a NAV container

When you have a running NAV container, you can publish an app using a function in the NavContainerHelper. The below script will publish, sync and install the app in c:\temp\my.app in the NAV container called test.

Example:

    Publish-NavContainerApp -containerName "test" -appFile "c:\temp\my.app" -skipVerification -sync -install

If you only publish the app, you can use *Sync-NavContainerApp* and *Install-NavContainerApp* to sync and install the app later.

Subsequently you also have functions to uninstall and unpublish apps from a container. The Unpublish-NavContainerApp also have a switch to uninstall the app.

If you are curious to see what happens inside this function, you can find the source [here](https://github.com/Microsoft/navcontainerhelper/blob/master/AppHandling/Publish-NavContainerApp.ps1).

[Back to TOC](#toc)

## <a name="ImportCompile"></a>Import and compile objects in a NAV container

When you have a running NAV container, you can import objects using a function in the NavContainerHelper.

Example:

    Import-ObjectsToNavContainer -containerName "test" -objectsFile "C:\temp\mysolution.fob" -sqlCredential $databaseCredential

You can also import a .txt file, simply by specifying a .txt file. This will leave the objects uncompiled. If you are curious to see what happens inside this function, you can find the source [here](https://github.com/Microsoft/navcontainerhelper/blob/master/ObjectHandling/Import-ObjectsToNavContainer.ps1).

You can also import a folder with .delta files using the *Import-DeltasToNavContainer* function. 

Example:

    $oldDeltaFolder = "C:\ProgramData\NavContainerHelper\Extensions\old\deltas"
    Import-DeltasToNavContainer -containerName "test" -deltaFolder $deltaFolder

you can find the source [here](https://github.com/Microsoft/navcontainerhelper/blob/master/ObjectHandling/Import-DeltasToNavContainer.ps1).

You can use *Compile-ObjectsInNavContainer* to compile objects in the NavContainer.

Example:

    Compile-ObjectsInNavContainer -containerName "test" -sqlCredential $databaseCredential

will compile all uncompiled objects in the NAV container test. You can also add a filter in order to compile a specific set of objects.

Example:

    Compile-ObjectsInNavContainer -containerName "test" -filter "modified=1" -sqlCredential $databaseCredential

If you are curious to see what happens inside this function, you can find the source [here](https://github.com/Microsoft/navcontainerhelper/blob/master/ObjectHandling/Compile-ObjectsInNavContainer.ps1).

[Back to TOC](#toc)

## <a name="export"></a>Export objects from a NAV container

With a running NAV container, you can export objects using a function in the NavContainerHelper.

Example:

    Export-ModifiedObjectsAsDeltas -containerName $oldcontainer -openFolder


[Back to TOC](#toc)

## <a name="bak"></a>Specify your own Database backup file to use with a NAV container

If you have a database backup file (.bak), you can specify that as parameter to the container. You can specify the bakfile using a secure URL. Read [this](https://blogs.msdn.microsoft.com/freddyk/2017/02/26/create-a-secure-url-to-a-file/) for information about how to create a secure url for a file.

    $imageName = "microsoft/dynamics-nav:2018-rtm"
    $navcredential = New-Object System.Management.Automation.PSCredential -argumentList "admin", (ConvertTo-SecureString -String "P@ssword1" -AsPlainText -Force)
    New-NavContainer -accept_eula `
                     -containerName "test" `
                     -Auth NavUserPassword `
                     -imageName $imageName `
                     -Credential $navcredential `
                     -licenseFile "https://www.dropbox.com/s/abcdefghijkl/my.flf?dl=1" `
                     -additionalParameters @('--env bakfile="https://www.dropbox.com/s/abcdefghijkl/Demo%20Database%20NAV%20%2811-0%29.bak?dl=1"')

A second option is to place the .bak file in a folder, which you share to the container and then specify the container file path to the bakfile parameter in additionalParameters, like this:

    $imageName = "microsoft/dynamics-nav:2018-rtm"
    $navcredential = New-Object System.Management.Automation.PSCredential -argumentList "admin", (ConvertTo-SecureString -String "P@ssword1" -AsPlainText -Force)
    New-NavContainer -accept_eula `
                     -containerName "test" `
                     -Auth NavUserPassword `
                     -imageName $imageName `
                     -Credential $navcredential `
                     -licenseFile "https://www.dropbox.com/s/abcdefghijkl/my.flf?dl=1" `
                     -additionalParameters @('--volume c:\temp\navdbfiles:c:\temp', '--env bakfile="c:\temp\Demo Database NAV (11-0).bak"')

A third optiopn is to specify the .bak file to the myscripts parameter and specify the path to the bakfile to be c:\run\my. All files specified in the myscripts parameter will be copied to the c:\run\my folder upon start of the container.

    $imageName = "microsoft/dynamics-nav:2018-rtm"
    $navcredential = New-Object System.Management.Automation.PSCredential -argumentList "admin", (ConvertTo-SecureString -String "P@ssword1" -AsPlainText -Force)
    New-NavContainer -accept_eula `
                     -containerName "test" `
                     -Auth NavUserPassword `
                     -imageName $imageName `
                     -Credential $navcredential `
                     -licenseFile "https://www.dropbox.com/s/abcdefghijkl/my.flf?dl=1" `
                     -myScripts @("c:\temp\navdbfiles\Demo Database NAV (11-0).bak") `
                     -additionalParameters @('--env bakfile="c:\run\my\Demo Database NAV (11-0).bak"')

**Note**, when specifying a .bak file, the normal container initialization is still continuing and the NAV Super user will be created if it doesn't already exist. This is not happening if you manually restore the .bak file to a SQL server and point out an external SQL Server database.
**Note also**, if using Windows Authentication it only compares the user name - it does not take the domain name into account.

[Back to TOC](#toc)

## <a name="DbShare"></a>Start a NAV container and place the database files on a file share on the host computer

The database files are placed inside the container by default. If you want to copy the database to a share on the Docker host, you can override the SetupDatabase.ps1 script by creating a file called SetupDatabase.ps1, specify that in myScripts.ps1 to New-NavContainer and share a folder on the host, which can host the DB files.

Example:

    $SetupDatabaseScript = @'
    if ($restartingInstance) {
        # Do nothing on restart
    } else {
        $databaseFolder = "c:\navdbfiles"
        Write-Host "Using $databaseFolder as new location for database files"

        $mdfName = Join-Path $databaseFolder "$DatabaseName.mdf"
        $ldfName = Join-Path $databaseFolder "$DatabaseName.ldf"
        $filesExists = (Test-Path $mdfName -PathType Leaf) -and (Test-Path $ldfName -PathType Leaf)

        Write-Host "Take database [$DatabaseName] offline"
        Invoke-SqlCmd -Query "ALTER DATABASE [$DatabaseName] SET OFFLINE WITH ROLLBACK IMMEDIATE"

        if ($filesExists) {
            Write-Host "Database files for [$DatabaseName] already exists"
        } else {
            Write-Host "Move database files for [$DatabaseName]"
            (Invoke-SqlCmd -Query "SELECT Physical_Name as filename FROM sys.master_files WHERE DB_NAME(database_id) = '$DatabaseName'").filename | ForEach-Object {
                $FileInfo = Get-Item -Path $_
                $DestinationFile = "{0}\{1}{2}" -f $databaseFolder, $DatabaseName, $FileInfo.Extension
                if (($DestinationFile -ne $mdfName) -and ($destinationFile -ne $ldfName)) { throw "Unexpected filename: $DestinationFile" }
                Copy-Item -Path $FileInfo.FullName -Destination $DestinationFile -Force
            }
        }

        Write-Host "Drop database [$DatabaseName]"
        Invoke-SqlCmd -Query "DROP DATABASE [$DatabaseName]"

        $Files = "(FILENAME = N'$mdfName'), (FILENAME = N'$ldfName')"
        Write-Host "Attach files as new Database [$DatabaseName]"
        Invoke-SqlCmd -Query "CREATE DATABASE [$DatabaseName] ON (FILENAME = N'$mdfName'), (FILENAME = N'$ldfName') FOR ATTACH"
    }
    '@

    $additionalParameters = @("-v c:\temp\navdbfiles:c:\navdbfiles")
    New-NavContainer -accept_eula `
                     -containerName "test" `
                     -auth NavUserPassword `
                     -imageName "microsoft/dynamics-nav" `
                     -additionalParameters $additionalParameters `
                     -myScripts @{"SetupDatabase.ps1" = $SetupDatabaseScript }

The SetupDatabase.ps1 script above will check whether the database files already exists and attach/reuse them if this is the case. If the databases files doesn't exist, they will be copied to the specified folder and attached.

The additionalParameter sets up a shared folder. The local folder c:\temp\navdbfiles as c:\navdbfiles in the container and shares the SetupDatabase.ps1 script from above.

[Back to TOC](#toc)

## <a name="SqlCronus"></a>Create a SQL Server container with the CRONUS database from a NAV container image

The NAV container images contains SQL Express with the CRONUS Demo Database. If we want to get a copy of the databases from a NAV container image, we can override the navstart.ps1 script with a script, which basically just starts the SQL Server, takes the database offline and copies the database files to a folder.

Example:

    $navstartScript = @'
    Write-Host "Extracting databases..."
    $startTime = [DateTime]::Now

    . "c:\run\HelperFunctions.ps1"
    . "c:\run\SetupVariables.ps1"

    # start the SQL Server
    Write-Host "Starting Local SQL Server"
    Start-Service -Name $SqlServiceName -ErrorAction Ignore -WarningAction Ignore

    Write-Host "Take database [$DatabaseName] offline"
    Invoke-SqlCmd -Query "ALTER DATABASE [$DatabaseName] SET OFFLINE WITH ROLLBACK IMMEDIATE"

    $databaseFolder = "c:\navdbfiles"
    Write-Host "Using $databaseFolder as new location for database files"

    $mdfName = Join-Path $databaseFolder "$DatabaseName.mdf"
    $ldfName = Join-Path $databaseFolder "$DatabaseName.ldf"

    (Invoke-SqlCmd -Query "SELECT Physical_Name as filename FROM sys.master_files WHERE DB_NAME(database_id) = '$DatabaseName'").filename | ForEach-Object {
        $FileInfo = Get-Item -Path $_
        $DestinationFile = "{0}\{1}{2}" -f $databaseFolder, $DatabaseName, $FileInfo.Extension
        if (($DestinationFile -ne $mdfName) -and ($destinationFile -ne $ldfName)) { throw "Unexpected filename: $DestinationFile" }
        Write-Host $DestinationFile
        Copy-Item -Path $FileInfo.FullName -Destination $DestinationFile -Force
    }
    $timespend = [Math]::Round([DateTime]::Now.Subtract($startTime).Totalseconds)
    Write-Host "Extracting databases took $timespend seconds"
    Write-Host "Ready for connections!"
    '@

    $hostFolder = "c:\temp\navdbfiles"
    $imageName = "microsoft/dynamics-nav"

    $additionalParameters = @("-v ${hostFolder}:c:\navdbfiles")
    $tempcredential = New-Object System.Management.Automation.PSCredential -argumentList "admin", (ConvertTo-SecureString -String "P@ssword1" -AsPlainText -Force)
    New-NavContainer -accept_eula `
                     -containerName "temp" `
                     -imageName $imageName `
                     -Credential $tempcredential `
                     -memoryLimit "1g" `
                     -shortcuts None `
                     -additionalParameters $additionalParameters `
                     -myScripts @{"navstart.ps1" = $navstartScript}
    Remove-NavContainer -containerName "temp"

The navstart script above will work with all standard NAV container images to extract the database files to a folder, which is shared as c:\navdbfiles. Below is the script, which will start the container, get the database files and remove the container again. On my Windows 2016 laptop, this takes ~20 seconds.

In this example, it gets the .mdf and .ldf files from the latest cumulative update of the latest released version of NAV with W1 localization. Adding the lines below will spin up a SQL Server Developer container and attach the database files extracted by the lines above.

    $databaseCredential = New-Object System.Management.Automation.PSCredential -argumentList "sa", (ConvertTo-SecureString -String "P@ssword1" -AsPlainText -Force)
    $databaseName = "CRONUS"
    $attach_dbs = (ConvertTo-Json -Compress -Depth 99 @(@{"dbName" = "$databaseName"; "dbFiles" = @("c:\temp\${databaseName}.mdf", "c:\temp\${databaseName}.ldf") })).replace('"',"'")
    $dbPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($databaseCredential.Password))
    $dbserverid = docker run -d -e sa_password="$dbPassword" -e ACCEPT_EULA=Y -v "${hostFolder}:C:/temp" -e attach_dbs="$attach_dbs" microsoft/mssql-server-windows-developer
    $databaseServer = $dbserverid.SubString(0,12)
    $databaseInstance = ""

After this you have a SQL Server Container with your NAV database.
Variables $databaseServer, $databaseInstance, $databaseName and $databaseCredential are the parameters used to start up a NAV Container to use this new database server.

[Back to TOC](#toc)

## <a name="SqlBak"></a>Create a SQL Server container and restore a .bak file

The following script sample, will create a new SQL Server container and restore a NAV 2018 database backup file (Demo Database NAV (11-0).bak) placed on the host in a folder called c:\temp\navdbfiles. The folder c:\temp\navdbfiles on the host is shared as c:\temp inside the container.

    $hostFolder = "c:\temp\navdbfiles"
    $databaseCredential = New-Object System.Management.Automation.PSCredential -argumentList "sa", (ConvertTo-SecureString -String "P@ssword1" -AsPlainText -Force)
    $dbPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($databaseCredential.Password))
    $dbserverid = docker run -d -e sa_password="$dbPassword" -e ACCEPT_EULA=Y -v "${hostFolder}:C:/temp" microsoft/mssql-server-windows-express
    $databaseServer = $dbserverid.SubString(0,12)
    $databaseInstance = ""

    $databaseName = "Demo Database NAV (11-0)"
    $databaseServerInstance = @{ $true = "$databaseServer\$databaseInstance"; $false = "$databaseServer"}["$databaseInstance" -ne ""]
    $RelocateData = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile("${databaseName}_Data", "c:\temp\${databaseName}_Data.mdf")
    $RelocateLog = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile("${databaseName}_Log", "c:\temp\${databaseName}_Log.ldf")
    Restore-SqlDatabase -ServerInstance $databaseServerInstance -Database $databaseName -BackupFile "C:\temp\$databaseName.bak" -Credential $databaseCredential -RelocateFile @($RelocateData,$RelocateLog)

After this, the SQL Server is ready to use from a NAV container and the variables $databaseServer, $databaseInstance, $databaseName and $databaseCredential are the parameters used to start up a NAV container to use this new database server.

[Back to TOC](#toc)

## <a name="ExternalSql"></a>Use an external SQL Server as database connection in a NAV container

If you have a created a SQL Server container using one of the methods described any of the sections:

- Create a SQL Server container with the CRONUS database from a NAV container image
- Create a SQL Server container and restore a .bak file

Then you will have the variables $databaseServer, $databaseInstance, $databaseName and $databaseCredential pointing to a database you can use to start up a NAV container. These parameters can be given directly to New-NavContainer.

If you have created your external database through other means, please set these variables in PowerShell. Please try the following script to see whether a docker container can connect to your database:

    $dbPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($databaseCredential.Password))
    $databaseServerInstance = @{ $true = "$databaseServer\$databaseInstance"; $false = "$databaseServer"}["$databaseInstance" -ne ""]
    docker run -it --name sqlconnectiontest microsoft/mssql-server-windows-developer powershell -command "Invoke-Sqlcmd -ServerInstance '$databaseServerInstance' -Username '$($databaseCredential.Username)' -Password '$dbPassword' -Database '$databaseName' -Query 'SELECT COUNT(*) FROM [dbo].[User]'"

If the above script fails, you will not succeed starting a NAV container with these credentials, before your connection test succeeds.

Please remove your connection test container using: 

    docker rm sqlconnectiontest -f

When you successfully have conducted the connection test above, you can start a NAV container using this script:

    $navcredential = New-Object System.Management.Automation.PSCredential -argumentList "admin", (ConvertTo-SecureString -String "P@ssword1" -AsPlainText -Force)
    New-NavContainer -accept_eula `
                     -containerName "test" `
                     -Auth NavUserPassword `
                     -imageName $imageName `
                     -Credential $navcredential `
                     -databaseServer $databaseServer `
                     -databaseInstance $databaseInstance `
                     -databaseName $databaseName `
                     -databaseCredential $databaseCredential

If your database doesn't have a license file, you can upload a license file using:

    Import-NavContainerLicense -containerName test -licenseFile "https://www.dropbox.com/s/abcdefghijkl/my.flf?dl=1"

If you do not import a license file, you are likely to get errors like this when trying to access the NAV container.

    The following SQL error was unexpected:
    Invalid object name 'master.dbo.$ndo$srvproperty'.

You can add users to the database using:

    New-NavContainerNavUser -containerName test -Credential $navcredential

[Back to TOC](#toc)

## <a name="VsCode"></a>Connect to the NAV container and develop using Visual Studio Code

Visual Studio Code can NOT connect to NAV 2017 or earlier versions – you need to use a NAV container post NAV 2017, f.ex. NAV 2018 or the NAV Developer Preview.

When you deploy a version of NAV, which can be used with Visual Studio Code, you will see some extra info. (Dev. Server, Dev. ServerInstance and the url of a .vsix file).

    Container IP Address: 172.19.144.73
    Container Hostname  : test
    Container Dns Name  : test
    Web Client          : http://test/NAV/
    Dev. Server         : http://test
    Dev. ServerInstance : NAV

    Files:
    http://test:8080/al-0.12.17720.vsix

    Initialization took 90 seconds
    Ready for connections!

The name of .vsix file reveals the version of the AL Language extension needed by this server. If you do not have this version already installed in Visual Studio Code, then copy the URL for the .vsix file and download the file. Start Visual Studio Code, uninstall prior versions of the AL Language extension (.vsix) and install the newly downloaded version.

Press Ctrl+Shift+P, select AL: Go!

Select Local Server and modify the Server and the ServerInstance settings in launch.json to match the Dev. Server and Dev. ServerInstance info from the container.

In launch.json, also change the authentication setting to the setting used by the Container: Windows or UserPassword.

[Back to TOC](#toc)

# <a name="Scripts"></a>Scripts

When building, running or restarting the NAV container, the c:\run\start.ps1 script is being run. This script will launch navstart.ps1, which will launch a number of other scripts (listed below in the order in which they are called from navstart.ps1). Each of these scripts exists in the c:\run folder. If a folder called c:\run\my exists and a script with the same name is found in that folder, then **that** script will be executed **instead** of the script in c:\run (called overriding scripts).

Overriding scripts id done by specifying the scripts you want to override in the myscripts parameter. The myScripts parameter is an array and every item can be one of the following:

- A filename on the host. This file will be copied to the container's c:\run\my folder with the same name. If the file is a .zip file, it will be extracted to the c:\run\my folder.
- A secure URL to a file. This file will be downloaded to the container's c:\run\my folder with the same name. If the file is a .zip file, it will be extracted to the c:\run\my folder.
- A folder name on the host. The content of this folder is copied to the c:\run\my folder. .zip files in the folder will not be extracted.
- A hashtable with the filename and content of files to be written in the c:\run\my folder.

Example (filename):

    New-NavContainer -accept_eula `
                     -containerName test `
                     -imageName microsoft/dynamics-nav `
                     -auth NavUserPassword `
                     -myScripts @("c:\temp\AdditionalOutput.ps1")

Example (secure url):

    New-NavContainer -accept_eula `
                     -containerName test `
                     -imageName microsoft/dynamics-nav `
                     -auth NavUserPassword `
                     -myScripts @("https://www.dropbox.com/s/yokximlfz2vws2i/additionalOutput.ps1?dl=1")

Example (.zip file):

    New-NavContainer -accept_eula `
                     -containerName test `
                     -imageName microsoft/dynamics-nav `
                     -auth NavUserPassword `
                     -myScripts @("https://www.dropbox.com/s/y3na6vxxjlg2xig/myoverrides.zip?dl=1")

Example (hashtable):

    $additionalOutputScript = @"
    Write-Host "--------------------"
    Write-Host "| AdditionalOutput |"
    Write-Host "--------------------"
    "@

    New-NavContainer -accept_eula `
                     -containerName test `
                     -imageName microsoft/dynamics-nav `
                     -auth NavUserPassword `
                     -myScripts @{"AdditionalOutput.ps1" = $additionalOutputScript} 

The output of the container should be something like:

    ...
    Container IP Address: 172.19.155.150
    Container Hostname  : test
    Container Dns Name  : test
    Web Client          : http://test/NAV/
    Dev. Server         : http://test
    Dev. ServerInstance : NAV
    --------------------
    | AdditionalOutput |
    --------------------

    Files:
    http://test:8080/al-0.12.17720.vsix


The list below is all the overridable scripts in the c:\run folder, a link to the source code and a description of their responsibility.

1. [navstart.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/navstart.ps1) - navstart is the very first script to run and is responsible for running the following scripts.
2. [Helperfunctions.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/HelperFunctions.ps1) - set of helper functions.
3. [SetupVariables.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/SetupVariables.ps1) - read environment variables and set PowerShell variables.
4. [SetupDatabase.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/SetupDatabase.ps1) - setup the database used for this container.
5. [SetupCertificate.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/SetupCertificate.ps1) - setup certificate to use.
6. [SetupConfiguration.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/SetupConfiguration.ps1) - setup configuration for service tier.
7. [SetupAddIns.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/SetupAddIns.ps1) - setup addins in service tier and roletailored client folders.
8. [SetupLicense.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/SetupLicense.ps1) - setup license to use.
9. [SetupTenant.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/SetupTenant.ps1) - setup tenant (if multitenancy).
10. [SetupWebClient.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/110/SetupWebClient.ps1) - setup Web Client (this script is different for different versions of NAV).
11. [SetupWebConfiguration.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/SetupWebConfiguration.ps1) - setup Web Client configuration (default file is empty).
12. [SetupFileShare.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/SetupFileShare.ps1) - setup file share with certificate, vsix file and more.
13. [SetupWindowsUsers.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/SetupWindowsUsers.ps1) - setup Windows users.
14. [SetupSqlUsers.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/SetupSqlUsers.ps1) - setup SQL users.
15. [SetupNavUsers.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/SetupNavUsers.ps1) - setup NAV users.
16. [SetupClickOnce.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/110/SetupClickOnce.ps1) - setup ClickOnce deployed Windows Client (this script is different for different versions of NAV).
17. [SetupClickOnceDirectory.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/110/SetupClickOnceDirectory.ps1) - setup ClickOnce directory with the necessary files for Windows Client deployment.
18. [AdditionalSetup.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/AdditionalSetup.ps1) - additional setup script (default file is empty).
19. [AdditionalOutput.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/AdditionalOutput.ps1) - additional output script (default file is empty).
20. [MainLoop.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/MainLoop.ps1) - NAV container main loop, exiting the main loop will terminate the container.

When overriding scripts, you need to determine whether or not you are going to invoke the default behavior. Some script overrides (like SetupCertificate.ps1) will typically not invoke the default script, others (like SetupConfiguration.ps1) typically will invoke the default behavior.

Insert this line in your script to invoke the default behavior of the script:

    . (Join-Path $runPath $MyInvocation.MyCommand.Name)

Furthermore, within your scripts there are a number of variables you can/should use. The $restartingInstance is important to consider as this determines whether the container is restarting or starting for the first time. A number of things are NOT needed to be done again on restart.

- *$restartingInstance* – this variable is true when the script is being run as a result of a restart of the docker instance.

The following variables are used to indicate locations of stuff in the image:

- *$runPath* – this variable points to the location of the run folder (C:\RUN)
- *$myPath* – this variable points to the location of my scripts (C:\RUN\MY)
- *$NavDvdPath* – this variable points to the location of the NAV DVD (C:\NAVDVD)

The following variables are parameters, which are defined when running the image:

- *$Auth* – this variable is set to the NAV authentication mechanism based on the environment variable of the same name. Supported values at this time is Windows and NavUserPassword.
- *$serviceTierFolder* – this variable is set to the folder in which the Service Tier is installed.
- *$WebClientFolder* – this variable is set to the folder in which the Web Client binaries are present.
- *$roleTailoredClientFolder* – this variable is set to the folder in which the RoleTailored Client files are present.

Please go through the navstart.ps1 script to understand how this works and how the overridable scripts are launched.

## [navstart.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/navstart.ps1)

navstart.ps1 is the main script runner, which will invoke all the other scripts.

### Default behavior

Invoke scripts in the order mentioned above.

### Reasons to override

- If you want to change behavior of the NAV container totally, then this can be done by specifying another navstart.ps1.

## [Helperfunctions.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/HelperFunctions.ps1)

HelperFunctions is a library of helper functions, used by the scripts.

### Default behavior

You should always invoke the default helperfunctions script.

### Reasons to override

- Override functions in helperfunctions.

## [SetupVariables.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/SetupVariables.ps1)

When running the NAV container image, most parameters are specified by using -e parameter=value. This will actually set the environment variable parameter to value and in the SetupVariables script, these environment variables are transferred to PowerShell variables.

### Default behavior

The script will transfer all known parameters from environment variables to PowerShell variables, and make sure that default values are correct.

### Reasons to override

- Hardcode variables

## [SetupDatabase.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/SetupDatabase.ps1)

The responsibility of SetupDatabase is to make sure that a database is ready for the NAV Service Tier to open. The script will not be executed if a $databaseServer and $databaseName parameter is specified as environment variables.

### Default behavior

The script will be executed when running the generic or a specific image, and it will be executed when the container is being restarted. The default implementation of the script will perform these checks:

1. If the container is being restarted, do nothing.
2. If an environment variable called bakfile is specified (either path+filename or http/https) that bakfile will be restored and used as the NAV Database.
3. If an environment variables called appBacpac and tenantBacpac are specified (either path+filename or http/https) they will be restored and used as the NAV Database.
4. If database credentials are specified, then the script will setup connection to an external SQL Server and setup key for encryption.
5. If multitenant switch is specified, the NAV container will switch to multi-tenancy mode.

### Reasons to override

- Place your database file on a file share on the Docker host
- Connect to a SQL Azure Database or another SQL Server

## [SetupCertificate.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/SetupCertificate.ps1)

The responsibility of the SetupCertificate script is to make sure that a certificate for secure communication is in place. The certificate will be used for the communication between Client and Server (if necessary) and for securing communication to the Web Client and to Web Services (unless UseSSL has been set to N).

The script will only be executed during run (not build or restart) and the script will not be executed if you run Windows Authentication unless you set UseSSL to Y and you would typically not need to call the default SetupCertificate.ps1 script from your script.

The script will need to set 3 variables, which are used by navstart.ps1 afterwards.

- $certificateCerFile (if self signed)
- $certificateThumbprint
- $dnsIdentity

### Default behavior

The default script will create a self-signed certificate, and use this for securing access to NAV.

**Note**, services like PowerBI and the Office Excel Add-in will not be able to trust your self signed certificate, meaning that 

### Reasons to override

- Using a certificate issues by a trusted authority.

## [SetupConfiguration.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/SetupConfiguration.ps1)

The SetupConfiguration script will setup the NAV Service Tier configuration file. The script also adds port reservations if the configuration is setup for SSL.

### Default behavior

Configure the NAV Service Tier with all instance specific settings. Hostname, Authentication, Database, SSL Certificate and other things, which changes per instance of the NAV container.

### Reasons to override

- Changes needed to the settings for the NAV Service Tier (although this can also be done by specifying the CustomNavSettings environment variable in the container)

Example:

    # Invoke default behavior
    . (Join-Path $runPath $MyInvocation.MyCommand.Name)
    $CustomConfigFile = Join-Path $ServiceTierFolder "CustomSettings.config"
    $CustomConfig = [xml](Get-Content $CustomConfigFile)
    $customConfig.SelectSingleNode("//appSettings/add[@key='MaxConcurrentCalls']").Value = "10"
    $CustomConfig.Save($CustomConfigFile)

## [SetupAddIns.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/SetupAddIns.ps1)

SetupAddIns must make sure that custom add-ins are available to the Service Tier and in the RoleTailored Client folder.

### Default Behavior

Copy the content of the C:\Run\Add-ins folder (if it exists) to the Add-ins folder under the Service Tier and the RoleTailored Client folder.

If you override this script, you should execute the default behavior before doing what you need to do. In your script you should use the $serviceTierFolder and $roleTailoredClientFolder variables to determine the location of the folders.

**Note**, you can also share a folder with Add-Ins directly to the ServiceTier Add-Ins folder and avoid copying stuff around altogether.

### Reasons to override

- Copy Add-Ins from a network location

## [SetupLicense.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/SetupLicense.ps1)

The responsibility of the SetupLicense script is to ensure that a license is available for the NAV Service Tier.

### Default Behavior

The default behavior of the setupLicense script does nothing during restart of the Docker instance.

Else, the default behavior will check whether the LicenseFile parameter is set (either to a path on a share or a http download location). If the licenseFile parameter is specified, this license will be used. If no licenseFile is specified, then the CRONUS Demo license is used. 

In all specific NAV container images, the license is already imported. If you are running the generic image, the license will be imported.

### Reasons to override

- If you have moved the database or you are using a different database
- Import the license to a different location (default is NavDatabase)

## [SetupTenant.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/SetupTenant.ps1)

This script will create a tenant database as a copy of the tenant template database.

### Default behavior

Copy the tenant template database and mount it as a new tenant.

### Reasons to override

- Use a different tenant template.
- Initialize tenant after mount.

## [SetupWebClient.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/110/SetupWebClient.ps1)

This script is used to setup the WebClient. This script is different for different versions of NAV.

### Default behavior

Setup the WebClient under IIS.

### Reasons to override

- If you want to setup the WebClient as a service and not under IIS.

## [SetupWebConfiguration.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/SetupWebConfiguration.ps1)

The responsibility of the SetupWebConfiguration is to do final configuration changes to Web config.

### Default Behavior

The default script is left empty, base Web Configuration is done in SetupWebClient.ps1.

### Reasons to override

- Change things in the Web configuration, which isn't supported by parameters already.

## [SetupFileShare.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/SetupFileShare.ps1)

The SetupFileShare script needs to copy files, which you want to be available to the user to the file share folder.

### Default Behavior

- Copy .vsix file (NAV new Development Environment add-in) if it exists to file share folder.
- Copy self-signed certificate (if you are using SSL) to file share folder.

You should always invoke the default behavior if you override this script (unless the intention is to not have the file share).

### Reasons to override

- Add additional files to the file share (Copy files need to $httpPath)

## [SetupWindowsUsers.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/SetupWindowsUsers.ps1)

This script will create the user specified as a Windows user in the container in order to allow Windows authentication to work.

### Default behavior

Create the Windows user.

### Reasons to override

- avoid creating the Windows user.

## [SetupSqlUsers.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/SetupSqlUsers.ps1)

The SetupSqlUsers script must make sure that the necessary users are created in the SQL Server.

### Default Behavior

- If the databaseServer is not localhost, then the default behavior does nothing, else…
- If a password is specified, then set the SA password and enable the SA user for classic development access.
- If you are using NavUserPassword authentication, then add the user to the SQL Database as a sysadmin.
- If you are using windows authentication and gMSA, then add the user to the SQL Database as a sysadmin.

**Note**, using NavContainerHelper, you will not be able to avoid specifying a username and password.

If you override this script, you might or might not need to invoke the default behavior.

### Reasons to override

- Change configurations to SQL Server

## [SetupNavUsers.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/SetupNavUsers.ps1)

The responsibility of the SetupNavUsers script is to setup users in NAV.

### Default Behavior

If the container is running *Windows Authentication*, then this script will create the current Windows User as a SUPER user in NAV. This script will also create the LocalUser if necessary you have specified username and password (i.e. if you are NOT using gMSA). If the user already exists in the database, no action is taken.

If the container is running *NavUserPassword authentication*, then this script will create a new SUPER user in NAV. If Username and Password are specified, then they are used, else a user named **admin** with a random password is created. If the user already exists in the database, no action is taken.

**Note**, using NavContainerHelper, you will not be able to avoid specifying a username and password.

If you override this script, you might or might not need to invoke the default behavior.

### Reasons to override

- Create multiple users in NAV for demo purposes

## [SetupClickOnce.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/110/SetupClickOnce.ps1)

The SetupClickOnce script will setup a ClickOnce manifest in the download area.

### Default Behavior

Create a ClickOnce manifest of the Windows Client

### Reasons to override

- This script is rarely overridden, but If you want to create an additional ClickOnce manifest, this is where you would do it.

## [SetupClickOnceDirectory.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/110/SetupClickOnceDirectory.ps1)

The responsibility of the SetupClickOnceDirectory script is to copy the files needed for the ClickOnce manifest from the RoleTailored Client directory to the ClickOnce ApplicationFiles directory.

### Default behavior

Copy all files needed for a standard installation, including the Add-ins folder.

If you override this script, you would probably always call the default behavior and then perform whatever changes you need to do afterwards. The location of the Windows Client binaries is given by _$roleTailoredClientFolder_ and the location to which you need to copy the files is _$ClickOnceApplicationFilesDirectory_.

### Reasons to override

- Changes to ClientUserSettings.config
- Copy additional files. If you need to copy additional files, invoke the default behavior and perform copy-item cmdlets like:

Example:

    Copy-Item "$roleTailoredClientFolder\Newtonsoft.Json.dll" -Destination "$ClickOnceApplicationFilesDirectory"

## [AdditionalSetup.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/AdditionalSetup.ps1)

This script is added to allow you to add additional setup to your Docker container, which gets run after everything else is setup. You will see, that in the scenarios, the AdditionalSetup script is frequently overridden to achieve things.

### Default Behavior

The default script is empty and does nothing. If you override this script there is no need to call the default behavior.

This script is the last script, which gets executed before the output section and the main loop.

### Reasons to override

 - If you need to perform additional setup when running the docker container

## [AdditionalOutput.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/AdditionalOutput.ps1)

This script is added to allow you to add additional output to your Docker container.

### Default Behavior

The default script is empty and does nothing.

If you override this script there is no need to call the default behavior.

### Reasons to override

If you need to output information to the user running the Docker Container, you can write stuff to the host in this script and it will be visible to the user running the container.

## [MainLoop.ps1](https://github.com/Microsoft/nav-docker/blob/master/generic/Run/MainLoop.ps1)

The responsibility of the MainLoop script is to make sure that the container doesn't exit. If no "message" loop is running, the container will stop running and be marked as Exited.

### Default Behavior

Default behavior of the MainLoop is, to display Application event log entries concerning Dynamics products.

If you override the MainLoop, you would rarely invoke the default behavior.

### Reasons to override

- Avoid printing out event log entries
- Override the MainLoop and sleep for a 100 years😊

[Back to TOC](#toc)


