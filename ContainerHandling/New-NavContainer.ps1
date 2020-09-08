<# 
 .Synopsis
  Create or refresh a NAV/BC Container
 .Description
  Creates a new Container based on a Docker Image
  Adds shortcut on the desktop for Web Client and Container PowerShell prompt
 .Parameter accept_eula
  Switch, which you need to specify if you accept the eula for running NAV or Business Central on Docker containers (See https://go.microsoft.com/fwlink/?linkid=861843)
 .Parameter accept_outdated
  Specify accept_outdated to ignore error when running containers which are older than 90 days
 .Parameter containerName
  Name of the new Container (if the container already exists it will be replaced)
 .Parameter imageName
  Name of the image you want to use for your Container
 .Parameter artifactUrl
  Url for application artifact to use. If you also specify an ImageName, an image will be build (if it doesn't exist) using these artifacts and that will be run.
 .Parameter dvdPath
  When you are spinning up a Generic image, you need to specify the DVD path
 .Parameter dvdCountry
  When you are spinning up a Generic image, you need to specify the country version (w1, dk, etc.) (default is w1)
 .Parameter dvdVersion
  When you are spinning up a Generic image, you can specify the version (default is the version of the executables)
 .Parameter dvdPlatform
  When you are spinning up a Generic image, you can specify the platform version (default is the version of the executables)
 .Parameter locale
  Optional locale for the container. Default is to deduct the locale from the country version of the container.
 .Parameter licenseFile
  Path or Secure Url of the licenseFile you want to use
 .Parameter credential
  Username and Password for the Container
 .Parameter AuthenticationEmail
  AuthenticationEmail of the admin user
 .Parameter memoryLimit
  Memory limit for the container (default is unlimited for Windows Server host else 4G)
 .Parameter sqlMemoryLimit
  Memory limit for the SQL inside the container (default is no limit)
  Value can be specified as 50%, 1.5G, 1500M
 .Parameter isolation
  Isolation mode for the container (default is process for Windows Server host else hyperv)
 .Parameter databaseServer
  Name of database server when using external SQL Server (omit if using database inside the container)
 .Parameter databaseInstance
  Name of database instance when using external SQL Server (omit if using database inside the container)
 .Parameter databaseName
  Name of database to connect to when using external SQL Server (omit if using database inside the container)
 .Parameter bakFile
  Path or Secure Url of a bakFile if you want to restore a database in the container
 .Parameter bakFolder
  A folder in which a backup of the database(s) will be placed after the container has been created and initialized
  If the folder already exists, then the database(s) in this folder will be restored and used.
 .Parameter databaseCredential
  Credentials for the database connection when using external SQL Server (omit if using database inside the container)
 .Parameter shortcuts
  Location where the Shortcuts will be placed. Can be either None, Desktop or StartMenu
 .Parameter updateHosts
  Include this switch if you want to update the hosts file with the IP address of the container
 .Parameter useSSL
  Include this switch if you want to use SSL (https) with a self-signed certificate
 .Parameter installCertificateOnHost
  Include this switch if you want to use SSL (https) with a self-signed certificate
 .Parameter includeCSide
  Include this switch if you want to have Windows Client and CSide development environment available on the host. This switch will also export all objects as txt for object handling functions unless doNotExportObjectsAsText is set.
 .Parameter includeAL
  Include this switch if you want to have all objects exported as al for code merging and comparing functions unless doNotExportObjectsAsText is set.
 .Parameter enableSymbolLoading
  Include this switch if you want to do development in both CSide and VS Code to have symbols automatically generated for your changes in CSide
 .Parameter enableTaskScheduler
  Include this switch if you want to do Enable the Task Scheduler
 .Parameter doNotExportObjectsToText
  Avoid exporting objects for baseline from the container (Saves time, but you will not be able to use the object handling functions without the baseline)
 .Parameter alwaysPull
  Always pull latest version of the docker image
 .Parameter forceRebuild
  Force a rebuild of the cached image even if the generic image or os hasn't changed
 .Parameter useBestContainerOS
  Use the best Container OS based on the Host OS. If the OS doesn't match, a better public generic image is selected.
 .Parameter useGenericImage
  Specify a private (or special) generic image to use for the Container OS.
 .Parameter assignPremiumPlan
  Assign Premium plan to admin user
 .Parameter multitenant
  Setup container for multitenancy by adding this switch
 .Parameter addFontsFromPath
  Enumerate all fonts from this path and install them in the container
 .Parameter featureKeys
  Optional hashtable of featureKeys, which can be applied to the container database
 .Parameter clickonce
  Specify the clickonce switch if you want to have a clickonce version of the Windows Client created
 .Parameter includeTestToolkit
  Specify this parameter to add the test toolkit and the standard tests to the container
 .Parameter includeTestLibrariesOnly
  Specify this parameter to avoid including the standard tests when adding includeTestToolkit
 .Parameter includeTestFrameworkOnly
  Only import TestFramework (do not import Test Codeunits nor TestLibraries)
 .Parameter includePerformanceToolkit
  Include the performance toolkit app (only 17.x and later)
 .Parameter restart
  Define the restart option for the container
 .Parameter auth
  Set auth to Windows, NavUserPassword or AAD depending on which authentication mechanism your container should use
 .Parameter timeout
  Specify the number of seconds to wait for activity. Default is 1800 (30 min.). -1 means wait forever.
 .Parameter additionalParameters
  This allows you to transfer an additional number of parameters to the docker run
 .Parameter myscripts
  This allows you to specify a number of scripts you want to copy to the c:\run\my folder in the container (override functionality)
 .Parameter TimeZoneId
  This parameter specifies the timezone in which you want to start the Container.
 .Parameter WebClientPort
  Use this parameter to specify which port to use for the WebClient. Default is 80 if http and 443 if https.
 .Parameter FileSharePort
  Use this parameter to specify which port to use for the File Share. Default is 8080.
 .Parameter ManagementServicesPort
  Use this parameter to specify which port to use for Management Services. Default is 7045.
 .Parameter ClientServicesPort
  Use this parameter to specify which port to use for Client Services. Default is 7046.
 .Parameter SoapServicesPort
  Use this parameter to specify which port to use for Soap Web Services. Default is 7047.
 .Parameter ODataServicesPort
  Use this parameter to specify which port to use for OData Web Services. Default is 7048.
 .Parameter DeveloperServicesPort
  Use this parameter to specify which port to use for Developer Services. Default is 7049.
 .Parameter PublishPorts
  Use this parameter to specify the ports you want to publish on the host. Default is to NOT publish any ports.
  This parameter is necessary if you want to be able to connect to the container from outside the host.
 .Parameter PublicDnsName
  Use this parameter to specify which public dns name is pointing to this container.
  This parameter is necessary if you want to be able to connect to the container from outside the host.
 .Parameter dns
  Use this parameter to override the default dns settings in the container (corresponds to --dns on docker run)
 .Parameter runTxt2AlInContainer
  Specify a foreign container in which you want to run the txt2al tool when using -includeAL
 .Parameter useTraefik
  Set the necessary options to make the container work behind a traefik proxy as explained here https://www.axians-infoma.com/techblog/running-multiple-nav-bc-containers-on-an-azure-vm/
 .Parameter useCleanDatabase
  Add this switch if you want to uninstall all extensions and remove the base app from the container
 .Parameter useNewDatabase
  Add this switch if you want to create a new and empty database in the container
 .Parameter doNotCopyEntitlements
  Specify this parameter to avoid copying entitlements when using -useNewDatabase
 .Parameter copyTables
  Array if table names to copy from original database when using -useNewDatabase
 .Parameter dumpEventLog
  Add this switch if you want the container to dump new entries in the eventlog to the output (docker logs) every 2 seconds
 .Parameter doNotCheckHealth
  Add this switch if you want to avoid CPU usage on health check.
 .Parameter doNotUseRuntimePackages
  Include the doNotUseRuntimePackages switch if you do not want to cache and use the test apps as runtime packages (only 15.x containers)
 .Parameter finalizeDatabasesScriptBlock
  In this scriptblock you can install additional apps or import additional objects in your container.
  These apps/objects will be included in the backup if you specify bakFolder and this script will NOT run if a backup already exists in bakFolder.
 .Parameter vsixFile
  Specify a URL or path to a .vsix file in order to override the .vsix file in the image with this
 .Example
  New-BcContainer -accept_eula -containerName test
 .Example
  New-BcContainer -accept_eula -containerName test -multitenant
 .Example
  New-BcContainer -accept_eula -containerName test -memoryLimit 3G -imageName "mcr.microsoft.com/dynamicsnav:2017" -updateHosts -useBestContainerOS
 .Example
  New-BcContainer -accept_eula -containerName test -imageName "mcr.microsoft.com/businesscentral/onprem:dk" -myScripts @("c:\temp\AdditionalSetup.ps1") -AdditionalParameters @("-v c:\hostfolder:c:\containerfolder")
 .Example
  New-BcContainer -accept_eula -containerName test -credential (get-credential -credential $env:USERNAME) -licenseFile "https://www.dropbox.com/s/fhwfwjfjwhff/license.flf?dl=1" -imageName "mcr.microsoft.com/businesscentral/onprem:de"
#>
function New-BcContainer {
    Param (
        [switch] $accept_eula,
        [switch] $accept_outdated = $true,
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [string] $imageName = "", 
        [string] $artifactUrl = "", 
        [Alias('navDvdPath')]
        [string] $dvdPath = "", 
        [Alias('navDvdCountry')]
        [string] $dvdCountry = "",
        [Alias('navDvdVersion')]
        [string] $dvdVersion = "",
        [Alias('navDvdPlatform')]
        [string] $dvdPlatform = "",
        [string] $locale = "",
        [string] $licenseFile = "",
        [PSCredential] $Credential = $null,
        [string] $authenticationEMail = "",
        [string] $memoryLimit = "",
        [string] $sqlMemoryLimit = "",
        [ValidateSet('','process','hyperv')]
        [string] $isolation = "",
        [string] $databaseServer = "",
        [string] $databaseInstance = "",
        [string] $databaseName = "",
        [string] $bakFile = "",
        [string] $bakFolder = "",
        [PSCredential] $databaseCredential = $null,
        [ValidateSet('None','Desktop','StartMenu','CommonStartMenu','CommonDesktop','DesktopFolder','CommonDesktopFolder')]
        [string] $shortcuts='Desktop',
        [switch] $updateHosts,
        [switch] $useSSL,
        [switch] $installCertificateOnHost,
        [switch] $includeAL,
        [string] $runTxt2AlInContainer = $containerName,
        [switch] $includeCSide,
        [switch] $enableSymbolLoading,
        [switch] $enableTaskScheduler,
        [switch] $doNotExportObjectsToText,
        [switch] $alwaysPull,
        [switch] $forceRebuild,
        [switch] $useBestContainerOS,
        [string] $useGenericImage,
        [switch] $assignPremiumPlan,
        [switch] $multitenant,
        [string] $addFontsFromPath = "",
        [hashtable] $featureKeys = $null,
        [switch] $clickonce,
        [switch] $includeTestToolkit,
        [switch] $includeTestLibrariesOnly,
        [switch] $includeTestFrameworkOnly,
        [switch] $includePerformanceToolkit,
        [ValidateSet('no','on-failure','unless-stopped','always')]
        [string] $restart='unless-stopped',
        [ValidateSet('Windows','NavUserPassword','UserPassword','AAD')]
        [string] $auth='Windows',
        [int] $timeout = 1800,
        [string[]] $additionalParameters = @(),
        $myScripts = @(),
        [string] $TimeZoneId = $null,
        [int] $WebClientPort,
        [int] $FileSharePort,
        [int] $ManagementServicesPort,
        [int] $ClientServicesPort,
        [int] $SoapServicesPort,
        [int] $ODataServicesPort,
        [int] $DeveloperServicesPort,
        [int[]] $PublishPorts = @(),
        [string] $PublicDnsName,
        [string] $dns,
        [switch] $useTraefik,
        [switch] $useCleanDatabase,
        [switch] $useNewDatabase,
        [switch] $doNotCopyEntitlements,
        [string[]] $copyTables = @(),
        [switch] $dumpEventLog,
        [switch] $doNotCheckHealth,
        [switch] $doNotUseRuntimePackages = $true,
        [string] $vsixFile = "",
        [scriptblock] $finalizeDatabasesScriptBlock
    )

    (Get-ContainerHelperConfig).defaultNewContainerParameters.GetEnumerator() | % {
        if (!($PSBoundParameters.ContainsKey($_.Name))) {
            Write-Host "Default parameter $($_.Name) = $($_.Value)"
            Set-Variable -name $_.Name -Value $_.Value
        }        
    }

    if (!$accept_eula) {
        throw "You have to accept the eula (See https://go.microsoft.com/fwlink/?linkid=861843) by specifying the -accept_eula switch to the function"
    }

    Check-BcContainerName -ContainerName $containerName

    if ($imageName.StartsWith('microsoft/dynamics-nav','InvariantCultureIgnoreCase')) {
        Write-Host 'WARNING: using old docker hub name for NAV image. Replacing with mcr.microsoft.com/dynamicsnav'
        $imageName = "mcr.microsoft.com/dynamicsnav$($imageName.Substring('microsoft/dynamics-nav'.Length))"
    }

    if ($Credential -eq $null -or $credential -eq [System.Management.Automation.PSCredential]::Empty) {
        if ($auth -eq "Windows") {
            $credential = get-credential -UserName $env:USERNAME -Message "Using Windows Authentication. Please enter your Windows credentials."
        } else {
            $credential = get-credential -Message "Using $auth Authentication. Please enter username/password for the Containter."
        }
        if ($Credential -eq $null -or $credential -eq [System.Management.Automation.PSCredential]::Empty) {
            throw "You have to specify credentials for your Container"
        }
    }

    if ($auth -eq "Windows") {
        if ($credential.Username.Contains('@')) {
            throw "You cannot use a Microsoft account, you need to use a local Windows user account (like $env:USERNAME)"
        }
        if ($credential.Username.Contains('\')) {
            throw "The username cannot contain domain information, you need to use a local Windows user account (like $env:USERNAME)"
        }
    }
    if ($auth -eq "AAD") {
        if ("$authenticationEMail" -eq "") {
            throw "When using AAD authentication, you have to specify AuthenticationEMail for the user: $($credential.UserName)"
        }
    }

    if ($auth -eq "UserPassword") {
        $auth = "NavUserPassword"
    }

    $myScripts | ForEach-Object {
        if ($_ -is [string]) {
            if ($_.StartsWith("https://", "OrdinalIgnoreCase") -or $_.StartsWith("http://", "OrdinalIgnoreCase")) {
            } elseif (!(Test-Path $_)) {
                throw "Script directory or file $_ does not exist"
            }
        } elseif ($_ -isnot [Hashtable]) {
            throw "Illegal value in myScripts"
        }
    }

    $os = (Get-CimInstance Win32_OperatingSystem)
    if ($os.OSType -ne 18 -or !$os.Version.StartsWith("10.0.")) {
        throw "Unknown Host Operating System"
    }

    $UBR = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name UBR).UBR
    
    $hostOsVersion = [System.Version]::Parse("$($os.Version).$UBR")
    $hostOs = "Unknown/Insider build"
    $bestGenericImageName = Get-BestGenericImageName -onlyMatchingBuilds

    if ($os.BuildNumber -eq 19041) { 
        $hostOs = "2004"
    }
    elseif ($os.BuildNumber -eq 18363) { 
        $hostOs = "1909"
    }
    elseif ($os.BuildNumber -eq 18362) { 
        $hostOs = "1903"
    }
    elseif ($os.BuildNumber -eq 17763) { 
        $hostOs = "ltsc2019"
    }
    elseif ($os.BuildNumber -eq 17134) { 
        $hostOs = "1803"
    }
    elseif ($os.BuildNumber -eq 16299) { 
        $hostOs = "1709"
    }
    elseif ($os.BuildNumber -eq 15063) {
        $hostOs = "1703"
    }
    elseif ($os.BuildNumber -eq 14393) {
        $hostOs = "ltsc2016"
    }
    
    Write-Host "BcContainerHelper is version $BcContainerHelperVersion"
    if ($isAdministrator) {
        Write-Host "BcContainerHelper is running as administrator"
    }
    else {
        Write-Host "BcContainerHelper is not running as administrator"
    }

    $isServerHost = $os.ProductType -eq 3
    Write-Host "Host is $($os.Caption) - $hostOs"

    $dockerService = (Get-Service docker -ErrorAction Ignore)
    if (!($dockerService)) {
        throw "Docker Service not found. Docker is not started, not installed or not running Windows Containers."
    }

    if ($dockerService.Status -ne "Running") {
        throw "Docker Service is $($dockerService.Status) (Needs to be running)"
    }

    $dockerVersion = docker version -f "{{.Server.Os}}/{{.Client.Version}}/{{.Server.Version}}"
    $dockerOS = $dockerVersion.Split('/')[0]
    $dockerClientVersion = $dockerVersion.Split('/')[1]
    $dockerServerVersion = $dockerVersion.Split('/')[2]

    if ($dockerOS -ne "Windows") {
        throw "Docker is running $dockerOS containers, you need to switch to Windows containers."
   	}
    Write-Host "Docker Client Version is $dockerClientVersion"

    $myClientVersion = [System.Version]"0.0.0"
    if (!(([System.Version]::TryParse($dockerClientVersion, [ref]$myClientVersion)) -and ($myClientVersion -ge ([System.Version]"18.03.0")))) {
        Write-Host -ForegroundColor Red "WARNING: Microsoft container registries will switch to TLS v1.2 very soon and your version of Docker does not support this. You should install a new version of docker asap (version 18.03.0 or later)"
    }

    Write-Host "Docker Server Version is $dockerServerVersion"

    $doNotGetBestImageName = $false
    $skipDatabase = $false
    if ($bakFile -ne "" -or $databaseServer -ne "" -or $databaseInstance -ne "" -or $databaseName -ne "") {
        $skipDatabase = $true
    }

    # Remove if it already exists
    Remove-BcContainer $containerName

    if ($artifactUrl) {
        # When using artifacts, you always use best container os - no need to replatform
        $useBestContainerOS = $false
    }

    if ($imageName -eq "") {
        Write-Host "Fetching all docker images"
        $allImages = @(docker images --format "{{.Repository}}:{{.Tag}}")
    }
    else {
        if ($artifactUrl -eq "") {

            Write-Host "Fetching all docker images"
            $allImages = @(docker images --format "{{.Repository}}:{{.Tag}}")

            if ($imageName -like "mcr.microsoft.com/*") {
                Write-Host -ForegroundColor Red "WARNING: You are running specific Docker images from mcr.microsoft.com. These images will no longer be updated, you should switch to user Docker artifacts. See https://freddysblog.com/2020/07/05/july-updates-are-out-they-are-the-last-on-premises-docker-images/"
            }
            if ($imageName -like "bcinsider.azurecr.io/*") {
                Write-Host -ForegroundColor Red "WARNING: You are running specific Docker images from bcinsider.azurecr.io. These images will no longer be updated, you should switch to user Docker artifacts. See https://freddysblog.com/2020/07/05/july-updates-are-out-they-are-the-last-on-premises-docker-images/"
            }
        }
        else {
            $autotag = $false
            Write-Host "ArtifactUrl and ImageName specified"
            if (!$imageName.Contains(':')) {
                $appUri = [Uri]::new($artifactUrl)
                $imageName += ":$($appUri.AbsolutePath.Replace('/','-').TrimStart('-'))"
                $autotag = $true
            }

            $buildMutexName = "img-$imageName"
            $buildMutex = New-Object System.Threading.Mutex($false, $buildMutexName)
            try {
                try {
                    if (!$buildMutex.WaitOne(1000)) {
                        Write-Host "Waiting for other process building image $imageName"
                        $buildMutex.WaitOne() | Out-Null
                        Write-Host "Other process completed download"
                    }
                }
                catch [System.Threading.AbandonedMutexException] {
                   Write-Host "Other process terminated abnormally"
                }
    
                Write-Host "Fetching all docker images"
                $allImages = @(docker images --format "{{.Repository}}:{{.Tag}}")

                $appArtifactPath = Download-Artifacts -artifactUrl $artifactUrl -forceRedirection:$alwaysPull
                $appManifestPath = Join-Path $appArtifactPath "manifest.json"
                $appManifest = Get-Content $appManifestPath | ConvertFrom-Json

                if ($appManifest.PSObject.Properties.name -eq "isBcSandbox") {
                    if ($appManifest.isBcSandbox) {
                        if (!($PSBoundParameters.ContainsKey('multitenant')) -and !$skipDatabase) {
                            $multitenant = $bcContainerHelperConfig.sandboxContainersAreMultitenantByDefault
                        }
                    }
                }
                $mtImage = $multitenant
                if ($useNewDatabase -or $useCleanDatabase) {
                    $mtImage = $false
                }

                $dbstr = ""
                if ($skipDatabase) {
                    if ($autotag) { $imageName += "-nodb" }
                    $dbstr = " without database"
                }
                $mtstr = ""
                if ($mtImage) {
                    if ($autotag) { $imageName += "-mt" }
                    $mtstr = " multitenant"
                }

                if ($allImages | Where-Object { $_ -eq $imageName }) {
                    try {
                        Write-Host "Image $imageName already exists"
                        $inspect = docker inspect $imageName | ConvertFrom-Json
            
                        if ($useGenericImage -eq "") {
                            $useGenericImage = Get-BestGenericImageName
                        }
            
                        $labels = Get-BcContainerImageLabels -imageName $useGenericImage
            
                        $imageArtifactUrl = ($inspect.config.env | ? { $_ -like "artifactUrl=*" }).SubString(12).Split('?')[0]
                        if ($imageArtifactUrl -ne $artifactUrl.Split('?')[0]) {
                            Write-Host "Image $imageName was build with artifactUrl $imageArtifactUrl, should be $($artifactUrl.Split('?')[0])"
                            $forceRebuild = $true
                        }
                        if ($inspect.Config.Labels.version -ne $appManifest.Version) {
                            Write-Host "Image $imageName was build with version $($inspect.Config.Labels.version), should be $($appManifest.Version)"
                            $forceRebuild = $true
                        }
                        elseif ($inspect.Config.Labels.Country -ne $appManifest.Country) {
                            Write-Host "Image $imageName was build with version $($inspect.Config.Labels.version), should be $($appManifest.Version)"
                            $forceRebuild = $true
                        }
                        elseif ($inspect.Config.Labels.osversion -ne $labels.osversion) {
                            Write-Host "Image $imageName was build for OS Version $($inspect.Config.Labels.osversion), should be $($labels.osversion)"
                            $forceRebuild = $true
                        }
                        elseif ($inspect.Config.Labels.tag -ne $labels.tag) {
                            Write-Host "Image $imageName has generic Tag $($inspect.Config.Labels.tag), should be $($labels.tag)"
                            $forceRebuild = $true
                        }
                       
                        if (($inspect.Config.Labels.PSObject.Properties.Name -eq "Multitenant") -and ($inspect.Config.Labels.Multitenant -eq "Y")) {
                            if (!$mtImage) {
                                Write-Host "Image $imageName was build multi tenant, should have been single tenant"
                                $forceRebuild = $true
                            }
                        }
                        else {
                            if ($mtImage) {
                                Write-Host "Image $imageName was build single tenant, should have been multi tenant"
                                $forceRebuild = $true
                            }
                        }
             
                        if (($inspect.Config.Labels.PSObject.Properties.Name -eq "SkipDatabase") -and ($inspect.Config.Labels.SkipDatabase -eq "Y")) {
                            if (!$skipdatabase) {
                                Write-Host "Image $imageName was build without a database, should have a database"
                                $forceRebuild = $true
                            }
                        }
                        else {
                            # Do not rebuild if database is there, just don't use it
                        }
                    }
                    catch {
                        $forceRebuild = $true
                    }
                }
                else {
                    Write-Host "Image $imageName doesn't exist"
                    $forceRebuild = $true
                }
                if ($forceRebuild) {
                    Write-Host "Building$mtstr image $imageName based on $($artifactUrl.Split('?')[0])$dbstr"
                    $startTime = [DateTime]::Now
                    New-Bcimage `
                        -artifactUrl $artifactUrl `
                        -imageName $imagename `
                        -isolation $isolation `
                        -baseImage $useGenericImage `
                        -memory $memoryLimit `
                        -skipDatabase:$skipDatabase `
                        -multitenant:$mtImage `
                        -addFontsFromPath $addFontsFromPath `
                        -licenseFile $licensefile `
                        -includeTestToolkit:$includeTestToolkit `
                        -includeTestFrameworkOnly:$includeTestFrameworkOnly `
                        -includeTestLibrariesOnly:$includeTestLibrariesOnly `
                        -includePerformanceToolkit:$includePerformanceToolkit

                    $timespend = [Math]::Round([DateTime]::Now.Subtract($startTime).Totalseconds)
                    Write-Host "Building image took $timespend seconds"
                    if (-not ($allImages | Where-Object { $_ -eq $imageName })) {
                        $allImages += $imageName
                    }
                }
                $artifactUrl = ""
                $alwaysPull = $false
                $useGenericImage = ""
                $doNotGetBestImageName = $true
            }
            finally {
                $buildMutex.ReleaseMutex()
            }
        }
    }

    if (!($PSBoundParameters.ContainsKey('useTraefik'))) {
        $traefikForBcBasePath = "c:\programdata\bccontainerhelper\traefikforbc"
        if (Test-Path -Path (Join-Path $traefikForBcBasePath "traefik.txt") -PathType Leaf) {
            Write-Host "WARNING: useTraefik not specified, but Traefik container was initialized, using Traefik. Specify -useTraefik:`$false if you do NOT want to use Traefik."
            $useTraefik = $true
        }
    }

    if ($useTraefik) {
        $traefikForBcBasePath = "c:\programdata\bccontainerhelper\traefikforbc"
        if (-not (Test-Path -Path (Join-Path $traefikForBcBasePath "traefik.txt") -PathType Leaf)) {
            throw "Traefik container was not initialized. Please call Setup-TraefikContainerForBcContainers before using -useTraefik"
        }
        
        $forceHttpWithTraefik = $false
        if ((Get-Content (Join-Path $traefikForBcBasePath "config\traefik.toml") | Foreach-Object { $_ -match "^insecureSkipVerify = true$" } ) -notcontains $true) {
            $forceHttpWithTraefik = $true
        }

        if ($PublishPorts.Count -gt 0 -or
            $WebClientPort -or $FileSharePort -or $ManagementServicesPort -or $ClientServicesPort -or 
            $SoapServicesPort -or $ODataServicesPort -or $DeveloperServicesPort) {
            throw "When using Traefik, all external communication comes in through port 443, so you can't change the ports"
        }

        if ($forceHttpWithTraefik) {
            Write-Host "Disabling SSL on the container as you have configured -forceHttpWithTraefik"
            $useSSL = $false
        } else {
            Write-Host "Enabling SSL as otherwise all clients will see mixed HTTP / HTTPS request, which will cause problems e.g. on the mobile and modern windows clients"
            $useSSL = $true
        }

        if ((Test-Path "C:\inetpub\wwwroot\hostname.txt") -and -not $PublicDnsName) {
            $PublicDnsName = Get-Content -Path "C:\inetpub\wwwroot\hostname.txt" 
        }
        if (-not $PublicDnsName) {
            throw "Using Traefik only makes sense if you allow external access, so you have to provide the public DNS name (param -PublicDnsName)"
        }
    }

    $parameters = @()
    $customNavSettings = @()

    $devCountry = $dvdCountry
    $navVersion = $dvdVersion
    $bcStyle = "onprem"

    $downloadsPath = (Get-ContainerHelperConfig).bcartifactsCacheFolder
    if (!(Test-Path $downloadsPath)) {
        New-Item $downloadsPath -ItemType Directory | Out-Null
    }

    if ($imageName -eq "") {
        if ($artifactUrl) {
            if ($useGenericImage) {
                $imageName = $useGenericImage
            }
            else {
                $imageName = Get-BestGenericImageName
            }
        }
        elseif ("$dvdPath" -ne "") {
            if ($useGenericImage) {
                $imageName = $useGenericImage
            }
            else {
                $imageName = Get-BestGenericImageName
            }
        } elseif (Test-BcContainer -containerName $bcContainerHelperConfig.defaultContainerName) {
            $artifactUrl = Get-BcContainerArtifactUrl -containerName $bcContainerHelperConfig.defaultContainerName
            if ($artifactUrl) {
                if ($useGenericImage) {
                    $imageName = $useGenericImage
                }
                else {
                    $imageName = Get-BestGenericImageName
                }
            }
            else {
                $imageName = Get-BcContainerImageName -containerName $bcContainerHelperConfig.defaultContainerName
            }
        } else {
            throw "You have to specify artifactUrl or imageName when creating a new container."            
        }
        $bestImageName = $imageName
    }
    elseif ($doNotGetBestImageName) {
        $bestImageName = $imageName
    }
    else {
        if (!$imageName.Contains(':')) {
            $imageName += ":latest"
        }
    
        # Determine best container ImageName (append -ltsc2016 or -ltsc2019)
        $bestImageName = Get-BestBcContainerImageName -imageName $imageName
    
        if ($useBestContainerOS) {
            $imageName = $bestImageName
        }
    }
    
    $pullit = $alwaysPull
    if (!$alwaysPull) {

        $imageExists = $false
        $bestImageExists = $false
        $allImages | ForEach-Object {
            if ("$_" -eq "$imageName" -or "$_" -eq "$($imageName):latest") { $imageExists = $true }
            if ("$_" -eq "$bestImageName") { $bestImageExists = $true }
        }

        if ($bestImageExists) {
            $imageName = $bestImageName
            if ($artifactUrl) {
                $genericTagVersion = [Version](Get-BcContainerGenericTag -containerOrImageName $imageName)
                if ($genericTagVersion -lt [Version]"0.1.0.16") {
                    Write-Host "Generic image is version $genericTagVersion - pulling a newer image"
                    $pullit = $true
                }
            }
        } elseif ($imageExists) {
            Write-Host "NOTE: Add -alwaysPull or -useBestContainerOS if you want to use $bestImageName instead of $imageName."
        } else {
            $pullit = $true
        }
    }

    if ($pullit) {
        try {
            Write-Host "Pulling image $bestImageName"
            DockerDo -command pull -imageName $bestImageName | Out-Null
            $imageName = $bestImageName
        } catch {
            if ($imageName -eq $bestImageName) {
                throw
            }
            Write-Host "Pulling image $imageName"
            DockerDo -command pull -imageName $imageName | Out-Null
        }
    }

    Write-Host "Using image $imageName"
    $inspect = docker inspect $imageName | ConvertFrom-Json

    if ($clickonce) {
        $parameters += "--env clickonce=Y"
    }

    if ($WebClientPort) {
        $parameters += "--env WebClientPort=$WebClientPort"
    }

    if ($FileSharePort) {
        $parameters += "--env FileSharePort=$FileSharePort"
    }

    if ($ManagementServicesPort) {
        $parameters += "--env ManagementServicesPort=$ManagementServicesPort"
    }

    if ($ClientServicesPort) {
        $parameters += "--env ClientServicesPort=$ClientServicesPort"
    }

    if ($SoapServicesPort) {
        $parameters += "--env SoapServicesPort=$SoapServicesPort"
    }

    if ($ODataServicesPort) {
        $parameters += "--env ODataServicesPort=$ODataServicesPort"
    }

    if ($DeveloperServicesPort) {
        $parameters += "--env DeveloperServicesPort=$DeveloperServicesPort"
    }

    if ($dns) {
        $parameters += "--dns $dns"
    }

    $publishPorts | ForEach-Object {
        Write-Host "Publishing port $_"
        $parameters += "--publish $($_):$($_)"
    }

    if ($publicDnsName) {
        Write-Host "PublicDnsName is $publicDnsName"
        $parameters += "--env PublicDnsName=$PublicDnsName"
    }

    if ($doNotCheckHealth) {
        Write-Host "Disabling Health Check (always report healthy)"
        $parameters += '--no-healthcheck'
    }

    $containerFolder = Join-Path $ExtensionsFolder $containerName
    Remove-Item -Path $containerFolder -Force -Recurse -ErrorAction Ignore
    New-Item -Path $containerFolder -ItemType Directory -ErrorAction Ignore | Out-Null

    if ($dvdPath.StartsWith("http://", [StringComparison]::OrdinalIgnoreCase) -or $dvdPath.StartsWith("https://", [StringComparison]::OrdinalIgnoreCase)) {
        $tempFolder = Join-Path $containerFolder "DVD"
        new-item -type directory -Path $tempFolder | Out-Null
        $tempFile = "$tempFolder.zip"
        Download-File -sourceUrl $dvdPath -destinationFile $tempFile
        Write-Host "Extracting DVD .zip file " -NoNewline
        Expand-7zipArchive -Path $tempFile -DestinationPath $tempFolder
        Remove-Item -Path $tempFile
        $dvdPath = $tempFolder
    }
    elseif ($dvdPath.EndsWith(".zip", [StringComparison]::OrdinalIgnoreCase)) {
        $temp = Join-Path $containerFolder "NAVDVD"
        new-item -type directory -Path $temp | Out-Null
        Write-Host "Extracting DVD .zip file " -NoNewline
        Expand-7zipArchive -Path $dvdPath -DestinationPath $temp
        $dvdPath = $temp
    }

    if ($artifactUrl) {

        $parameters += "--volume $($downloadsPath):c:\dl"

        $artifactPaths = Download-Artifacts -artifactUrl $artifactUrl -includePlatform -forceRedirection:$alwaysPull
        $appArtifactPath = $artifactPaths[0]
        $platformArtifactPath = $artifactPaths[1]

        $appManifestPath = Join-Path $appArtifactPath "manifest.json"
        $appManifest = Get-Content $appManifestPath | ConvertFrom-Json

        $bcstyle = "onprem"
        if ($appManifest.PSObject.Properties.name -eq "isBcSandbox") {
            if ($appManifest.isBcSandbox) {
                $bcstyle = "sandbox"
                if (!($PSBoundParameters.ContainsKey('multitenant')) -and !$skipDatabase) {
                    $multitenant = $bcContainerHelperConfig.sandboxContainersAreMultitenantByDefault
                }
            }
        }

        if ($appManifest.PSObject.Properties.name -eq "Nav") {
            $parameters += @("--label nav=$($appManifest.Nav)")
        }
        else {
            $parameters += @("--label nav=")
        }
        if ($appManifest.PSObject.Properties.name -eq "Cu") {
            $parameters += @("--label cu=$($appManifest.Cu)")
        }
        if ($bcStyle -eq "sandbox") {
            $parameters += @("--env isBcSandbox=Y")
        }

        $dvdVersion = $appmanifest.Version
        $dvdCountry = $appManifest.Country
        $dvdPlatform = $appManifest.Platform

        $devCountry = $dvdCountry
        $navVersion = "$dvdVersion-$dvdCountry"

        $parameters += @(
                       "--label version=$dvdVersion"
                       "--label platform=$dvdPlatform"
                       "--label country=$dvdCountry"
                       "--env artifactUrl=$artifactUrl"
                       )
    }
    elseif ("$dvdPath" -ne "") {
        if ("$dvdVersion" -eq "" -and (Test-Path "$dvdPath\version.txt")) {
            $dvdVersion = Get-Content "$dvdPath\version.txt"
        }
        if ("$dvdPlatform" -eq "" -and (Test-Path "$dvdPath\platform.txt")) {
            $dvdPlatform = Get-Content "$dvdPath\platform.txt"
        }
        if ("$dvdCountry" -eq "" -and (Test-Path "$dvdPath\country.txt")) {
            $dvdCountry = Get-Content "$dvdPath\country.txt"
        }
        if ($dvdVersion) {
            $navVersion = $dvdVersion
        }
        else {
            $navversion = (Get-Item -Path "$dvdPath\ServiceTier\program files\Microsoft Dynamics NAV\*\Service\Microsoft.Dynamics.Nav.Server.exe").VersionInfo.FileVersion
        }
        $navtag = Get-NavVersionFromVersionInfo -VersionInfo $navversion
        if ("$navtag" -eq "" -and "$dvdPlatform" -eq "") {
            $dvdPlatform = $navversion
        }
        if ($dvdCountry) {
            $devCountry = $dvdCountry
        }
        else {
            $devCountry = "w1"
        }

        $parameters += @(
                       "--label nav=$navtag",
                       "--label version=$navversion",
                       "--label country=$devCountry",
                       "--label cu="
                       )

        if ($dvdPlatform) {
            $parameters += @( "--label platform=$dvdPlatform" )
        }

        $navVersion += "-$devCountry"

    } elseif ($devCountry -eq "") {
        $devCountry = $inspect.Config.Labels.country
    }

    Write-Host "Creating Container $containerName"
    
    if ($navVersion -eq "") {
        if ($inspect.Config.Labels.psobject.Properties.Match('maintainer').Count -eq 0 -or $inspect.Config.Labels.maintainer -ne "Dynamics SMB") {
            throw "Container $imageName is not a NAV/BC container"
        }
        $navversion = "$($inspect.Config.Labels.version)-$($inspect.Config.Labels.country)"
        if ($inspect.Config.Env | Where-Object { $_ -eq "IsBcSandbox=Y" }) {
            $bcStyle = "sandbox"
        }
    }

    Write-Host "Version: $navversion"
    Write-Host "Style: $bcStyle"
    if ($multitenant) {
        Write-Host "Multitenant: Yes"
    }
    else {
        Write-Host "Multitenant: No"
    }

    $version = [System.Version]($navversion.split('-')[0])
    if ($dvdPlatform) {
        $platformVersion = $dvdPlatform
    }
    else {
        if ($inspect.Config.Labels.psobject.Properties.Name -eq 'platform') {
            $platformVersion = $inspect.Config.Labels.platform
        } else {
            $platformVersion = ""
        }
    }
    if ($platformversion) {
        Write-Host "Platform: $platformversion"
    }

    $genericTag = $inspect.Config.Labels.tag
    Write-Host "Generic Tag: $genericTag"

    $containerOsVersion = [Version]"$($inspect.Config.Labels.osversion)"
    if ("$containerOsVersion".StartsWith('10.0.14393.')) {
        $containerOs = "ltsc2016"
        if (!$useBestContainerOS -and $TimeZoneId -eq $null) {
            $timeZoneId = (Get-TimeZone).Id
        }
    }
    elseif ("$containerOsVersion".StartsWith('10.0.15063.')) {
        $containerOs = "1703"
    }
    elseif ("$containerOsVersion".StartsWith('10.0.16299.')) {
        $containerOs = "1709"
    }
    elseif ("$containerOsVersion".StartsWith('10.0.17134.')) {
        $containerOs = "1803"
    }
    elseif ("$containerOsVersion".StartsWith('10.0.17763.')) {
        $containerOs = "ltsc2019"
    }
    elseif ("$containerOsVersion".StartsWith('10.0.18362.')) {
        $containerOs = "1903"
    }
    elseif ("$containerOsVersion".StartsWith('10.0.18363.')) {
        $containerOs = "1909"
    }
    elseif ("$containerOsVersion".StartsWith('10.0.19041.')) {
        $containerOs = "2004"
    }
    else {
        $containerOs = "unknown"
    }
    Write-Host "Container OS Version: $containerOsVersion ($containerOs)"
    Write-Host "Host OS Version: $hostOsVersion ($hostOs)"

    if (($hostOsVersion.Major -lt $containerOsversion.Major) -or 
        ($hostOsVersion.Major -eq $containerOsversion.Major -and $hostOsVersion.Minor -lt $containerOsversion.Minor) -or 
        ($hostOsVersion.Major -eq $containerOsversion.Major -and $hostOsVersion.Minor -eq $containerOsversion.Minor -and $hostOsVersion.Build -lt $containerOsversion.Build)) {

        throw "The container operating system is newer than the host operating system, cannot use image"
    
    } elseif ("$useGenericImage" -eq "" -and
              ($hostOsVersion.Major -ne $containerOsversion.Major -or 
               $hostOsVersion.Minor -ne $containerOsversion.Minor -or 
               $hostOsVersion.Build -ne $containerOsversion.Build -or 
               $hostOsVersion.Revision -ne $containerOsversion.Revision)) {

        if ("$dvdPath" -eq "" -and $useBestContainerOS -and "$bestGenericImageName" -ne "") {
            
            # There is a generic image, which is better than the selected image
            Write-Host "A better Generic Container OS exists for your host ($bestGenericImageName)"
            $useGenericImage = $bestGenericImageName

        }
    }

    if ($useGenericImage -and $useGenericImage -ne $imageName) {

        if ("$dvdPath" -eq "" -and "$artifactUrl" -eq "") {
            # Extract files from image if not already done
            $dvdPath = Join-Path $containerHelperFolder "$($NavVersion)-Files"

            if (!(Test-Path "$dvdPath\allextracted")) {
                Extract-FilesFromBcContainerImage -imageName $imageName -path $dvdPath -force
                if (!(Test-Path "$dvdPath\allextracted")) {
                    throw "Couldn't extract content from image $image"
                }
            }

            $parameters += @(
                           "--label nav=$($inspect.Config.Labels.nav)",
                           "--label version=$($inspect.Config.Labels.version)",
                           "--label country=$($inspect.Config.Labels.country)",
                           "--label cu=$($inspect.Config.Labels.cu)"
                           )

            if ($inspect.Config.Labels.psobject.Properties.Name -eq 'platform') {
                $parameters += @( "--label platform=$($inspect.Config.Labels.platform)" )
            }
            if ($inspect.Config.Env | Where-Object { $_ -eq "IsBcSandbox=Y" }) {
                $parameters += @(" --env IsBcSandbox=Y" )
            }
        }

        $imageName = $useGenericImage
        Write-Host "Using generic image $imageName"

        if (!$alwaysPull) {
            $alwaysPull = $true
            $allImages | ForEach-Object {
                if ("$_" -eq "$imageName" -or "$_" -eq "$($imageName):latest") { $alwaysPull = $false }
            }
        }

        if ($alwaysPull) {
            Write-Host "Pulling image $imageName"
            DockerDo -command pull -imageName $imageName | Out-Null
        }

        $inspect = docker inspect $imageName | ConvertFrom-Json
        $useGenericImageTagVersion = [System.Version]"$($inspect.Config.Labels.tag)"

        if ($artifactUrl) {
            if ($useGenericImageTagVersion -lt [System.Version]"0.0.9.103") {
                Write-Host "Generic Tag is $useGenericImageTagVersion - pulling updated generic image to use artifacts"
                DockerDo -command pull -imageName $imageName | Out-Null
            }
        }

        if (($version.Major -eq 13 -or $version.Major -eq 14) -and $useGenericImageTagVersion -le [System.Version]"0.0.9.99") {
            Write-Host "Patching navinstall.ps1 for 13.x and 14.x (issue #907)"
            $myscripts += @("https://bcdocker.blob.core.windows.net/public/130-patch/navinstall.ps1")
        }
        elseif ($useGenericImageTagVersion -le [System.Version]"0.0.9.99") {
            Write-Host "Patching navinstall.ps1 to stop the Service Tier for reconfiguration"
            $myscripts += @( @{ "navinstall.ps1" = '. "c:\run\navinstall.ps1"; Stop-Service -Name $NavServiceName -WarningAction Ignore' } )
        }

        $containerOsVersion = [Version]"$($inspect.Config.Labels.osversion)"
    
        if ("$containerOsVersion".StartsWith('10.0.14393.')) {
            $containerOs = "ltsc2016"
        }
        elseif ("$containerOsVersion".StartsWith('10.0.15063.')) {
            $containerOs = "1703"
        }
        elseif ("$containerOsVersion".StartsWith('10.0.16299.')) {
            $containerOs = "1709"
        }
        elseif ("$containerOsVersion".StartsWith('10.0.17134.')) {
            $containerOs = "1803"
        }
        elseif ("$containerOsVersion".StartsWith('10.0.17763.')) {
            $containerOs = "ltsc2019"
        }
        elseif ("$containerOsVersion".StartsWith('10.0.18362.')) {
            $containerOs = "1903"
        }
        elseif ("$containerOsVersion".StartsWith('10.0.18363.')) {
            $containerOs = "1909"
        }
        elseif ("$containerOsVersion".StartsWith('10.0.19041.')) {
            $containerOs = "2004"
        }
        else {
            $containerOs = "unknown"
        }
    
        Write-Host "Generic Container OS Version: $containerOsVersion ($containerOs)"

        $genericTagVersion = [Version]"$($inspect.Config.Labels.tag)"
        Write-Host "Generic Tag of better generic: $genericTagVersion"
    }

    if ($hostOsVersion -eq $containerOsVersion) {
        if ($isolation -eq "") {
            $isolation = "process"
        }
    }
    else {
        if ($isolation -eq "") {
            if ($isAdministrator) {
                if (Get-HypervState -ne "Disabled") {
                    $isolation = "hyperv"
                }
                else {
                    $isolation = "process"
                    Write-Host "WARNING: Host OS and Base Image Container OS doesn't match and Hyper-V is not installed. If you encounter issues, you could try to install Hyper-V."
                }
            }
            else {
                $isolation = "hyperv"
                Write-Host "WARNING: Host OS and Base Image Container OS doesn't match, defaulting to hyperv. If you do not have Hyper-V installed or you encounter issues, you could try to specify -isolation process"
            }

        }
        elseif ($isolation -eq "process") {
            Write-Host "WARNING: Host OS and Base Image Container OS doesn't match and process isolation is specified. If you encounter issues, you could try to specify -isolation hyperv"
        }
    }
    Write-Host "Using $isolation isolation"

    if ("$locale" -eq "") {
        $locale = Get-LocaleFromCountry $devCountry
    }
    Write-Host "Using locale $locale"

    if ((!$doNotExportObjectsToText) -and ($version -lt [System.Version]"8.0.0.0")) {
        throw "PowerShell Cmdlets to export objects as text are not included before NAV 2015, please specify -doNotExportObjectsToText."
    }

    if ($multitenant -and ($version -lt [System.Version]"7.1.0.0")) {
        throw "Multitenancy is not supported in NAV 2013"
    }

    if ($includeAL -and ($version.Major -lt 14)) {
        throw "IncludeAL is supported from Dynamics 365 Business Central Spring 2019 release (1904 / 14.x)"
    }

    if ($includeCSide -and ($version.Major -ge 15)) {
        throw "IncludeCSide is no longer supported in Dynamics 365 Business Central 2019 wave 2 release (1910 / 15.x)"
    }

    if ($enableSymbolLoading -and ($version.Major -ge 15)) {
        throw "EnableSymbolLoading is no longer needed in Dynamics 365 Business Central 2019 wave 2 release (1910 / 15.x)"
    }

    if ($multitenant -and [System.Version]$genericTag -lt [System.Version]"0.0.4.5") {
        throw "Multitenancy is not supported by images with generic tag prior to 0.0.4.5"
    }

    if (($WebClientPort -or $FileSharePort -or $ManagementServicesPort -or $ClientServicesPort -or $SoapServicesPort -or $ODataServicesPort -or $DeveloperServicesPort) -and [System.Version]$genericTag -lt [System.Version]"0.0.6.5") {
        throw "Changing endpoint ports is not supported by images with generic tag prior to 0.0.6.5"
    }

    if ($auth -eq "AAD" -and [System.Version]$genericTag -lt [System.Version]"0.0.5.0") {
        throw "AAD authentication is not supported by images with generic tag prior to 0.0.5.0"
    }

    $myFolder = Join-Path $containerFolder "my"
    New-Item -Path $myFolder -ItemType Directory -ErrorAction Ignore | Out-Null

    if ($useTraefik) {
        Write-Host "Adding special CheckHealth.ps1 to enable Traefik support"
        $myscripts += (Join-Path $traefikForBcBasePath "my\CheckHealth.ps1")
    }

    if (-not $dumpEventLog) {
        Write-Host "Disabling the standard eventlog dump to container log every 2 seconds (use -dumpEventLog to enable)"
        Set-Content -Path (Join-Path $myFolder "MainLoop.ps1") -Value 'while ($true) { start-sleep -seconds 1 }'
    }

    $myScripts | ForEach-Object {
        if ($_ -is [string]) {
            if ($_.StartsWith("https://", "OrdinalIgnoreCase") -or $_.StartsWith("http://", "OrdinalIgnoreCase")) {
                $uri = [System.Uri]::new($_)
                $filename = [System.Uri]::UnescapeDataString($uri.Segments[$uri.Segments.Count-1])
                $destinationFile = Join-Path $myFolder $filename
                Download-File -sourceUrl $_ -destinationFile $destinationFile
                if ($destinationFile.EndsWith(".zip", "OrdinalIgnoreCase")) {
                    Write-Host "Extracting .zip file " -NoNewline
                    Expand-7zipArchive -Path $destinationFile -DestinationPath $myFolder
                    Remove-Item -Path $destinationFile -Force
                }
            } elseif (Test-Path $_ -PathType Container) {
                Copy-Item -Path "$_\*" -Destination $myFolder -Recurse -Force
            } else {
                if ($_.EndsWith(".zip", "OrdinalIgnoreCase")) {
                    Write-Host "Extracting .zip file " -NoNewline
                    Expand-7zipArchive -Path $_ -DestinationPath $myFolder
                } else {
                    Copy-Item -Path $_ -Destination $myFolder -Force
                }
            }
        } else {
            $hashtable = $_
            $hashtable.Keys | ForEach-Object {
                Set-Content -Path (Join-Path $myFolder $_) -Value $hashtable[$_]
            }
        }
    }
    
    $restoreBakFolder = $false
    if ($bakFolder) {
        if (!$bakFolder.Contains('\')) {
            $bakFolder = Join-Path $containerHelperFolder "$bcStyle-$($NavVersion)-bakFolders\$bakFolder"
        }
        if (Test-Path (Join-Path $bakFolder "*.bak")) {
            $restoreBakFolder = $true
            if (!$multitenant) {
                $bakFile = Join-Path $bakFolder "database.bak"
                $parameters += "--env bakfile=$bakFile"
            }
        }
    }

    if ($multitenant -and !($usecleandatabase -or $useNewDatabase -or $restoreBakFolder)) {
        $parameters += "--env multitenant=Y"
    }

    if ($bakFile -and !$restoreBakFolder) {
        if ($bakFile.StartsWith("http://", [StringComparison]::OrdinalIgnoreCase) -or $bakFile.StartsWith("https://", [StringComparison]::OrdinalIgnoreCase)) {
            $temp = Join-Path $containerFolder "database.bak"
            Download-File -sourceUrl $bakFile -destinationFile $temp
            $bakFile = $temp
        }
        if (!(Test-Path $bakFile)) {
            throw "Database backup $bakFile doesn't exist"
        }
        
        if (-not $bakFile.StartsWith($hostHelperFolder, [StringComparison]::OrdinalIgnoreCase)) {
            $containerBakFile = Join-Path $containerFolder "database.bak"
            Copy-Item -Path $bakFile -Destination $containerBakFile
            $bakFile = $containerBakFile
        }
        $parameters += "--env bakfile=$bakFile"
    }

    if ($vsixFile) {
        if ($vsixFile.StartsWith("https://", "OrdinalIgnoreCase") -or $vsixFile.StartsWith("http://", "OrdinalIgnoreCase")) {
            $uri = [Uri]::new($vsixFile)
            Download-File -sourceUrl $vsixFile -destinationFile "$containerFolder\$($uri.Segments[$uri.Segments.Count-1]).vsix"
        }
        elseif (Test-Path $vsixFile -PathType Leaf) {
            Copy-Item -Path $vsixFile -Destination $containerFolder
        }
        else {
            throw "Unable to locate vsix file ($vsixFile)"
        }
    }

    if (!$restoreBakFolder) {
        if ("$licensefile" -eq "") {
            if ($includeCSide -and !$doNotExportObjectsToText) {
                throw "You must specify a license file when creating a CSide Development container or use -doNotExportObjectsToText to avoid baseline generation."
            }
            if ($includeAL -and ($version.Major -eq 14)) {
                throw "You must specify a license file when creating a AL Development container with this version."
            }
            $containerlicenseFile = ""
        } elseif ($licensefile.StartsWith("https://", "OrdinalIgnoreCase") -or $licensefile.StartsWith("http://", "OrdinalIgnoreCase")) {
            Write-Host "Using license file $licenseFile"
            $licensefileUri = $licensefile
            $licenseFile = "$myFolder\license.flf"
            Download-File -sourceUrl $licenseFileUri -destinationFile $licenseFile
            $bytes = [System.IO.File]::ReadAllBytes($licenseFile)
            $text = [System.Text.Encoding]::ASCII.GetString($bytes, 0, 100)
            if (!($text.StartsWith("Microsoft Software License Information"))) {
                Remove-Item -Path $licenseFile -Force
                throw "Specified license file Uri isn't a direct download Uri"
            }
            $containerLicenseFile = "c:\run\my\license.flf"
        } else {
            Write-Host "Using license file $licenseFile"
            Copy-Item -Path $licenseFile -Destination "$myFolder\license.flf" -Force
            $containerLicenseFile = "c:\run\my\license.flf"
        }
        $parameters += @( "--env licenseFile=""$containerLicenseFile""" )
    }


    $parameters += @(
                    "--name $containerName",
                    "--hostname $containerName",
                    "--env auth=$auth"
                    "--env username=""$($credential.UserName)""",
                    "--env ExitOnError=N",
                    "--env locale=$locale",
                    "--env databaseServer=""$databaseServer""",
                    "--env databaseInstance=""$databaseInstance""",
                    "--volume ""$($hostHelperFolder):$containerHelperFolder""",
                    "--volume ""$($myFolder):C:\Run\my""",
                    "--isolation $isolation",
                    "--restart $restart"
                   )

    if ("$memoryLimit" -eq "" -and $isolation -eq "hyperv") {
        $memoryLimit = "4G"
    }

    $SqlServerMemoryLimit = 0
    if ($SqlMemoryLimit) {
        if ($SqlMemoryLimit.EndsWith('%')) {
            if ($memoryLimit -ne "") {
                if ($memoryLimit -like '*M') {
                    $mbytes = [int]($memoryLimit.TrimEnd('mM'))
                }
                else {
                    $mbytes = [int](1024*([double]($memoryLimit.TrimEnd('gG'))))
                }
                $sqlServerMemoryLimit = [int]($mbytes * ([int]$SqlMemoryLimit.TrimEnd('%')) / 100)
            }
        }
        else {
            if ($SqlMemoryLimit -like '*M') {
                $SqlServerMemoryLimit = [int]($SqlMemoryLimit.TrimEnd('mM'))
            }
            else {
                $SqlServerMemoryLimit = [int](1024*([double]($SqlMemoryLimit.TrimEnd('gG'))))
            }
        }
    }

    if ($memoryLimit) {
        $parameters += "--memory $memoryLimit"
    }

    if ($version.Major -gt 11) {
        $parameters += "--env enableApiServices=Y"
    }

    if ("$databaseName" -ne "") {
        $parameters += "--env databaseName=""$databaseName"""
    }

    if ("$authenticationEMail" -ne "") {
        $parameters += "--env authenticationEMail=""$authenticationEMail"""
    }

    if ($PSBoundParameters.ContainsKey('enableTaskScheduler')) {
        $customNavSettings += @("EnableTaskScheduler=$enableTaskScheduler")
    }

    if ($enableSymbolLoading -and $version.Major -ge 11 -and $version.Major -lt 15) {
        $parameters += "--env enableSymbolLoading=Y"
    }
    else {
        $enableSymbolLoading = $false
    }

    if ($includeCSide) {
        $programFilesFolder = Join-Path $containerFolder "Program Files"
        New-Item -Path $programFilesFolder -ItemType Directory -ErrorAction Ignore | Out-Null

        # Clear modified flag on all objects
        ('
if ($restartingInstance -eq $false -and $databaseServer -eq "localhost" -and $databaseInstance -eq "SQLEXPRESS") {
    sqlcmd -S ''localhost\SQLEXPRESS'' -d $DatabaseName -Q "update [dbo].[Object] SET [Modified] = 0" | Out-Null
}
') | Add-Content -Path "$myfolder\AdditionalSetup.ps1"

        if (Test-Path $programFilesFolder) {
            Remove-Item $programFilesFolder -Force -Recurse -ErrorAction Ignore
        }
        New-Item $programFilesFolder -ItemType Directory -ErrorAction Ignore | Out-Null
        
        if ($useTraefik) {
            $winclientServer = $containerName
        }
        else {
            $winclientServer = '$PublicDnsName'
        }

        ('
if (!(Test-Path "c:\navpfiles\*")) {
    Copy-Item -Path "C:\Program Files (x86)\Microsoft Dynamics NAV\*" -Destination "c:\navpfiles" -Recurse -Force -ErrorAction Ignore
    $destFolder = (Get-Item "c:\navpfiles\*\RoleTailored Client").FullName
    $ClientUserSettingsFileName = "$runPath\ClientUserSettings.config"
    [xml]$ClientUserSettings = Get-Content $clientUserSettingsFileName
    $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""Server""]").value = "'+$winclientServer+'"
    $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""ServerInstance""]").value=$ServerInstance
    if ($multitenant) {
        $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""TenantId""]").value="$TenantId"
    }
    if ($clientUserSettings.SelectSingleNode("//appSettings/add[@key=""ServicesCertificateValidationEnabled""]") -ne $null) {
        $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""ServicesCertificateValidationEnabled""]").value="false"
    }
    if ($clientUserSettings.SelectSingleNode("//appSettings/add[@key=""ClientServicesCertificateValidationEnabled""]") -ne $null) {
        $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""ClientServicesCertificateValidationEnabled""]").value="false"
    }
    $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""ClientServicesPort""]").value="$publicWinClientPort"
    $acsUri = "$federationLoginEndpoint"
    if ($acsUri -ne "") {
        if (!($acsUri.ToLowerInvariant().Contains("%26wreply="))) {
            $acsUri += "%26wreply=$publicWebBaseUrl"
        }
    }
    $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""ACSUri""]").value = "$acsUri"
    $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""DnsIdentity""]").value = "$dnsIdentity"
    $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""ClientServicesCredentialType""]").value = "$Auth"
    $clientUserSettings.Save("$destFolder\ClientUserSettings.config")
}
') | Add-Content -Path "$myfolder\AdditionalSetup.ps1"
    }

    if ([System.Version]$genericTag -le [System.Version]"0.0.9.5") {

        $setupWebClientFile = "$myfolder\SetupWebClient.ps1"
        $setupWebClientContent = '. "C:\Run\SetupWebClient.ps1"'
        if (Test-Path $setupWebClientFile) {
            $setupWebClientContent = Get-Content -path $setupWebClientFile -raw
        }

        $setupWebClientContent = 'Write-Host "Registering event sources"
"MicrosoftDynamicsNAVClientWebClient","MicrosoftDynamicsNAVClientClientService" | % {
    if (-not [System.Diagnostics.EventLog]::SourceExists($_)) {
        $frameworkDir = (Get-Item "HKLM:\SOFTWARE\Microsoft\.NETFramework").GetValue("InstallRoot")
        New-EventLog -LogName Application -Source $_ -MessageResourceFile (get-item (Join-Path $frameworkDir "*\EventLogMessages.dll")).FullName
    }
}
'+$setupWebClientContent

        $setupWebClientContent | Set-Content -path $setupWebClientFile
    }
    elseif ([System.Version]$genericTag -le [System.Version]"0.0.9.96") {
        $setupWebClientFile = "$myfolder\SetupWebClient.ps1"
        if (!(Test-Path $SetupWebClientFile)) {
            'try {
    . "c:\run\setupWebClient.ps1"
}
catch {
    Write-Host "WARNING: SetupWebClient failed, retrying in 10 seconds"
    Start-Sleep -seconds 10
    . "c:\run\setupWebClient.ps1"
}
' | Set-Content -path $setupWebClientFile
        }

    }

    if ($assignPremiumPlan -and !$restoreBakFolder) {
        if (!(Test-Path -Path "$myfolder\SetupNavUsers.ps1")) {
            ('# Invoke default behavior
              . (Join-Path $runPath $MyInvocation.MyCommand.Name)
            ') | Set-Content -Path "$myfolder\SetupNavUsers.ps1"
        }
     
        if ($version.Major -ge 15) {
            $userPlanTableName = 'User Plan$63ca2fa4-4f03-4f2b-a480-172fef340d3f'
        }
        else {
            $userPlanTableName = 'User Plan'
        }
        ('
Get-NavServerUser -serverInstance $ServerInstance -tenant default |? LicenseType -eq "FullUser" | ForEach-Object {
    $UserId = $_.UserSecurityId
    Write-Host "Assign Premium plan for $($_.Username)"
    $dbName = $DatabaseName
    if ($multitenant) {
        $dbName = $TenantId
    }
    $userPlanTableName = '''+$userPlanTableName+'''
    Invoke-Sqlcmd -ErrorAction Ignore -ServerInstance ''localhost\SQLEXPRESS'' -Query "USE [$DbName]
    INSERT INTO [dbo].[$userPlanTableName] ([Plan ID],[User Security ID]) VALUES (''{8e9002c0-a1d8-4465-b952-817d2948e6e2}'',''$userId'')"
}
') | Add-Content -Path "$myfolder\SetupNavUsers.ps1"
    }

    if ($useSSL) {
        $parameters += "--env useSSL=Y"
    } else {
        $parameters += "--env useSSL=N"
    }

    if ($includeCSide) {
        $parameters += "--volume ""$($programFilesFolder):C:\navpfiles"""
    }

    if ("$dvdPath" -ne "") {
        $parameters += "--volume ""$($dvdPath):c:\NAVDVD"""
    }

    if (!(Test-Path -Path "$myfolder\SetupVariables.ps1")) {
        ('# Invoke default behavior
          . (Join-Path $runPath $MyInvocation.MyCommand.Name)
        ') | Set-Content -Path "$myfolder\SetupVariables.ps1"
    }

    if ($updateHosts) {
        Copy-Item -Path (Join-Path $PSScriptRoot "updatehosts.ps1") -Destination (Join-Path $myfolder "updatehosts.ps1") -Force
        $parameters += "--volume ""c:\windows\system32\drivers\etc:C:\driversetc"""
        ('
. (Join-Path $PSScriptRoot "updatehosts.ps1") -hostsFile "c:\driversetc\hosts" -theHostname "$hostname" -theIpAddress $ip
if ($multitenant) {
    $dotidx = $hostname.indexOf(".")
    if ($dotidx -eq -1) { $dotidx = $hostname.Length }
    Get-NavTenant -serverInstance $serverInstance | % {
        $tenantHostname = $hostname.insert($dotidx,"-$($_.Id)")
        . (Join-Path $PSScriptRoot "updatehosts.ps1") -hostsFile "c:\driversetc\hosts" -theHostname $tenantHostname -theIpAddress $ip
    }
}
') | Add-Content -Path "$myfolder\AdditionalOutput.ps1"

    ('
. (Join-Path $PSScriptRoot "updatehosts.ps1") -hostsFile "c:\driversetc\hosts"
') | Add-Content -Path "$myfolder\SetupVariables.ps1"

    }
    else {

        Copy-Item -Path (Join-Path $PSScriptRoot "updatehosts.ps1") -Destination (Join-Path $myfolder "updatecontainerhosts.ps1") -Force
    ('
. (Join-Path $PSScriptRoot "updatecontainerhosts.ps1")
') | Add-Content -Path "$myfolder\SetupVariables.ps1"

    }

    if ($useTraefik) {
        $restPart = "/${containerName}rest" 
        $soapPart = "/${containerName}soap"
        $devPart = "/${containerName}dev"
        $dlPart = "/${containerName}dl"
        $webclientPart = "/$containerName"

        $baseUrl = "https://$publicDnsName"
        $restUrl = $baseUrl + $restPart
        $soapUrl = $baseUrl + $soapPart
        $webclientUrl = $baseUrl + $webclientPart
        $devUrl = $baseUrl + $devPart
        $dlUrl = $baseUrl + $dlPart

        $customNavSettings += @("PublicODataBaseUrl=$restUrl/odata","PublicSOAPBaseUrl=$soapUrl/ws","PublicWebBaseUrl=$webclientUrl")

        if ($version.Major -ge 15) {
            $ServerInstance = "BC"
        }
        else {
            $ServerInstance = "NAV"
        }

        $webclientRule="PathPrefix:$webclientPart"
        $soapRule="PathPrefix:${soapPart};ReplacePathRegex: ^${soapPart}(.*) /$ServerInstance`$1"
        $restRule="PathPrefix:${restPart};ReplacePathRegex: ^${restPart}(.*) /$ServerInstance`$1"
        $devRule="PathPrefix:${devPart};ReplacePathRegex: ^${devPart}(.*) /$ServerInstance`$1"
        $dlRule="PathPrefixStrip:${dlPart}"

        $traefikHostname = $publicDnsName.Split(".")[0]

        $webPort = "443"
        if ($forceHttpWithTraefik) {
            $webPort = "80"
        }
        $traefikProtocol = "https"
        if ($forceHttpWithTraefik) {
            $traefikProtocol = "http"
        }

        $additionalParameters += @("--hostname $traefikHostname",
                                   "-e webserverinstance=$containerName",
                                   "-e publicdnsname=$publicDnsName", 
                                   "-l `"traefik.protocol=$traefikProtocol`"",
                                   "-l `"traefik.web.frontend.rule=$webclientRule`"", 
                                   "-l `"traefik.web.port=$webPort`"",
                                   "-l `"traefik.soap.frontend.rule=$soapRule`"", 
                                   "-l `"traefik.soap.port=7047`"",
                                   "-l `"traefik.rest.frontend.rule=$restRule`"", 
                                   "-l `"traefik.rest.port=7048`"",
                                   "-l `"traefik.dev.frontend.rule=$devRule`"", 
                                   "-l `"traefik.dev.port=7049`"",
                                   "-l `"traefik.dl.frontend.rule=$dlRule`"", 
                                   "-l `"traefik.dl.port=8080`"",
                                   "-l `"traefik.dl.protocol=http`"",
                                   "-l `"traefik.enable=true`"",
                                   "-l `"traefik.frontend.entryPoints=https`""
        )

        ("
if (-not `$restartingInstance) {
    Add-Content -Path 'c:\run\ServiceSettings.ps1' -Value '`$WebServerInstance = ""$containerName""'
}
") | Add-Content -Path "$myfolder\AdditionalOutput.ps1"
    }

    $containerContainerFolder = Join-Path $containerHelperFolder "Extensions\$containerName"

    ("
if (-not `$restartingInstance) {
    if (Test-Path -Path ""$containerContainerFolder\*.vsix"") {
        Remove-Item -Path 'C:\Run\*.vsix'
        Copy-Item -Path ""$containerContainerFolder\*.vsix"" -Destination 'C:\Run' -force
        if (Test-Path 'C:\inetpub\wwwroot\http' -PathType Container) {
            Remove-Item -Path 'C:\inetpub\wwwroot\http\*.vsix'
            Copy-Item -Path ""$containerContainerFolder\*.vsix"" -Destination 'C:\inetpub\wwwroot\http' -force
        }
    }
    else {
        Copy-Item -Path 'C:\Run\*.vsix' -Destination ""$containerContainerFolder"" -force
    }
    Copy-Item -Path 'C:\Run\*.cer' -Destination ""$containerContainerFolder"" -force
}
") | Add-Content -Path "$myfolder\AdditionalOutput.ps1"

    if ($customNavSettings) {
        $customNavSettingsAdded = $false
        $cnt = $additionalParameters.Count-1
        if ($cnt -ge 0) {
            0..$cnt | % {
                $idx = $additionalParameters[$_].ToLowerInvariant().IndexOf('customnavsettings=')
                if ($idx -gt 0) {
                    $additionalParameters[$_] = "$($additionalParameters[$_]),$([string]::Join(',',$customNavSettings))"
                    $customNavSettingsAdded = $true
                }
            }
        }
        if (-not $customNavSettingsAdded) {
            $additionalParameters += @("--env customNavSettings=$([string]::Join(',',$customNavSettings))")
        }
    }

    if ($additionalParameters) {
        Write-Host "Additional Parameters:"
        $additionalParameters | % { if ($_) { Write-Host "$_" } }
    }

    Write-Host "Files in $($myfolder):"
    get-childitem -Path $myfolder | % { Write-Host "- $($_.Name)" }

    Write-Host "Creating container $containerName from image $imageName"

    if ([System.Version]$genericTag -ge [System.Version]"0.0.3.0") {
        $passwordKeyFile = "$myfolder\aes.key"
        $passwordKey = New-Object Byte[] 16
        [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($passwordKey)
        $containerPasswordKeyFile = "c:\run\my\aes.key"
        try {
            Set-Content -Path $passwordKeyFile -Value $passwordKey
            $encPassword = ConvertFrom-SecureString -SecureString $credential.Password -Key $passwordKey
            
            $parameters += @(
                             "--env securePassword=$encPassword",
                             "--env passwordKeyFile=""$containerPasswordKeyFile""",
                             "--env removePasswordKeyFile=Y"
                            )

            if ($databaseCredential -ne $null -and $databaseCredential -ne [System.Management.Automation.PSCredential]::Empty) {

                $encDatabasePassword = ConvertFrom-SecureString -SecureString $databaseCredential.Password -Key $passwordKey
                $parameters += @(
                                 "--env databaseUsername=$($databaseCredential.UserName)",
                                 "--env databaseSecurePassword=$encDatabasePassword"
                                 "--env encryptionSecurePassword=$encDatabasePassword"
                                )
            }
            
            $parameters += $additionalParameters
        
            if (!(DockerDo -accept_eula -accept_outdated:$accept_outdated -detach -imageName $imageName -parameters $parameters)) {
                return
            }
            Wait-BcContainerReady $containerName -timeout $timeout
        } finally {
            Remove-Item -Path $passwordKeyFile -Force -ErrorAction Ignore
        }
    } else {
        $plainPassword = ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($credential.Password)))
        $parameters += "--env password=""$plainPassword"""
        $parameters += $additionalParameters
        if (!(DockerDo -accept_eula -accept_outdated:$accept_outdated -detach -imageName $imageName -parameters $parameters)) {
            return
        }
        Wait-BcContainerReady $containerName -timeout $timeout
    }

    Write-Host "Reading CustomSettings.config from $containerName"
    $customConfig = Get-BcContainerServerConfiguration -ContainerName $containerName

    if ($SqlServerMemoryLimit -and $customConfig.databaseServer -eq "localhost" -and $customConfig.databaseInstance -eq "SQLEXPRESS") {
        Write-Host "Set SQL Server memory limit to $SqlServerMemoryLimit MB"
        Invoke-ScriptInBCContainer -containerName $containerName -scriptblock { Param($SqlServerMemoryLimit)
            Invoke-Sqlcmd -ServerInstance 'localhost\SQLEXPRESS' -Query "USE master EXEC sp_configure 'show advanced options', 1 RECONFIGURE WITH OVERRIDE;"
            Invoke-Sqlcmd -ServerInstance 'localhost\SQLEXPRESS' -Query "USE master EXEC sp_configure 'max server memory', $SqlServerMemoryLimit RECONFIGURE WITH OVERRIDE;"
            Invoke-Sqlcmd -ServerInstance 'localhost\SQLEXPRESS' -Query "USE master EXEC sp_configure 'show advanced options', 0 RECONFIGURE WITH OVERRIDE;"
        } -argumentList ($SqlServerMemoryLimit)
    }

    if ($addFontsFromPath) {
        Add-FontsToBcContainer -containerName $containerName -path $addFontsFromPath
    }

    if ($featureKeys) {
        Set-BcContainerFeatureKeys -containerName $containerName -featureKeys $featureKeys
    }

    if ("$TimeZoneId" -ne "") {
        Write-Host "Set TimeZone in Container to $TimeZoneId"
        Invoke-ScriptInBcContainer -containerName $containerName -scriptblock { Param($TimeZoneId)
            $OldTimeZoneId = (Get-TimeZone).Id
            try { 
                if ($OldTimeZoneId -ne $TimeZoneId) { 
                    Set-TimeZone -ID $TimeZoneId
                }
            }
            catch {
                Write-Host "WARNING: Unable to set TimeZone to $TimeZoneId, TimeZone is $OldTimeZoneId"
            }
        } -argumentList $TimeZoneId
    }

    if ($useSSL -and $installCertificateOnHost) {
        $certPath = Join-Path $containerFolder "certificate.cer"
        if (Test-Path $certPath) {
            $cert = Import-Certificate -FilePath $certPath -CertStoreLocation "cert:\localMachine\Root"
            if ($cert) {
                Write-Host "Certificate with thumbprint $($cert.Thumbprint) imported successfully"
                Set-Content -Path (Join-Path $containerFolder "thumbprint.txt") -Value "$($cert.Thumbprint)"
            }
        }
    }

    if ($shortcuts -ne "None") {
        Write-Host "Creating Desktop Shortcuts for $containerName"
        if (-not [string]::IsNullOrEmpty($customConfig.PublicWebBaseUrl)) {
            $webClientUrl = $customConfig.PublicWebBaseUrl
            if ($multitenant) {
                $webClientUrl += "?tenant=default"
            }
            New-DesktopShortcut -Name "$containerName Web Client" -TargetPath "$webClientUrl" -IconLocation "C:\Program Files\Internet Explorer\iexplore.exe, 3" -Shortcuts $shortcuts
            if ($includeTestToolkit) {
                if ($version -ge [Version]("15.0.35528.0")) {
                    $pageno = 130451
                }
                else {
                    $pageno = 130401
                }

                if ($webClientUrl.Contains('?')) {
                    $webClientUrl += "&page="
                } else {
                    $webClientUrl += "?page="
                }
                New-DesktopShortcut -Name "$containerName Test Tool" -TargetPath "$webClientUrl$pageno" -IconLocation "C:\Program Files\Internet Explorer\iexplore.exe, 3" -Shortcuts $shortcuts
                if ($includePerformanceToolkit) {
                    New-DesktopShortcut -Name "$containerName Performance Tool" -TargetPath "$($webClientUrl)149000" -IconLocation "C:\Program Files\Internet Explorer\iexplore.exe, 3" -Shortcuts $shortcuts
                }
            }
            
        }
        
        New-DesktopShortcut -Name "$containerName Command Prompt" -TargetPath "CMD.EXE" -Arguments "/C docker.exe exec -it $containerName cmd" -Shortcuts $shortcuts
        New-DesktopShortcut -Name "$containerName PowerShell Prompt" -TargetPath "CMD.EXE" -Arguments "/C docker.exe exec -it $containerName powershell -noexit c:\run\prompt.ps1" -Shortcuts $shortcuts
    }

    if ([System.Version]$genericTag -lt [System.Version]"0.0.4.4") {
        if (Test-Path -Path "C:\windows\System32\t2embed.dll" -PathType Leaf) {
            Copy-FileToBcContainer -containerName $containerName -localPath "C:\windows\System32\t2embed.dll" -containerPath "C:\Windows\System32\t2embed.dll"
        }
    }

    if ($auth -eq "AAD" -and [System.Version]$genericTag -le [System.Version]"0.0.9.2") {
        Write-Host "Using AAD authentication, Microsoft.IdentityModel.dll is missing, download and copy"
        $wifdll = Join-Path $containerFolder "Microsoft.IdentityModel.dll"
        Download-File -sourceUrl 'https://bcdocker.blob.core.windows.net/public/Microsoft.IdentityModel.dll' -destinationFile $wifdll
        $ps = 'Join-Path (Get-Item ''C:\Program Files\Microsoft Dynamics NAV\*\Service'').FullName "Microsoft.IdentityModel.dll"'
        $containerWifDll = docker exec $containerName powershell $ps
        Copy-FileToBcContainer -containerName $containerName -localPath $wifdll -containerPath $containerWifDll
    }

    if ($version -eq [System.Version]"14.10.40471.0") {
        Write-Host "Patching Microsoft.Dynamics.Nav.Ide.psm1 in container due to issue #859"
        $idepsm = Join-Path $containerFolder "14.10.40471.0-Patch-Microsoft.Dynamics.Nav.Ide.psm1"
        Download-File -sourceUrl 'https://bcdocker.blob.core.windows.net/public/14.10.40471.0-Patch-Microsoft.Dynamics.Nav.Ide.psm1' -destinationFile $idepsm
        Invoke-ScriptInBcContainer -containerName $containerName -scriptblock { Param($idepsm)
            Copy-Item -Path $idepsm -Destination 'C:\Program Files (x86)\Microsoft Dynamics NAV\140\RoleTailored Client\Microsoft.Dynamics.Nav.Ide.psm1' -Force
        } -argumentList $idepsm
        Remove-BcContainerSession -containerName $containerName
    }

    if ((($version -eq [System.Version]"16.0.11240.12076") -or ($version -eq [System.Version]"16.0.11240.12085")) -and $devCountry -ne "W1") {
        $url = "https://bcdocker.blob.core.windows.net/public/12076-patch/$($devCountry.ToUpper()).zip"
        Write-Host "Downloading new test apps for this version from $url"
        $zipName = Join-Path $containerFolder "16.0.11240.12076-$devCountry-Tests-Patch"
        Download-File -sourceUrl $url -destinationFile "$zipName.zip"
        Write-Host "Extracting new test apps for this version " -NoNewline
        Expand-7zipArchive -Path "$zipName.zip" -DestinationPath $zipname
        Write-Host "Patching .app files in C:\Applications\BaseApp\Test due to issue #925"
        Invoke-ScriptInBcContainer -containerName $containerName -scriptblock { Param($zipName, $devCountry)
            Copy-Item -Path (Join-Path $zipName "$devCountry\*.app") -Destination "c:\Applications\BaseApp\Test" -Force
        } -argumentList $zipName, $devcountry
    }

    $sqlCredential = $databaseCredential
    if ($sqlCredential -eq $null -and $auth -eq "NavUserPassword") {
        $sqlCredential = New-Object System.Management.Automation.PSCredential ('sa', $credential.Password)
    }

    if ($restoreBakFolder) {
        if ($multitenant) {
            $dbs = Get-ChildItem -Path $bakFolder -Filter "*.bak"
            $tenants = $dbs | Where-Object { $_.Name -ne "app.bak" } | % { $_.BaseName }
            Invoke-ScriptInBcContainer -containerName $containerName -scriptblock {
                Set-NAVServerConfiguration -ServerInstance $ServerInstance -KeyName "Multitenant" -KeyValue "true" -ApplyTo ConfigFile
            }
            Restore-DatabasesInBcContainer -containerName $containerName -bakFolder $bakFolder -tenant $tenants
        }
    }
    else {
        if ($enableSymbolLoading) {
            # Unpublish symbols when running hybrid development
            Invoke-ScriptInBcContainer -containerName $containerName -scriptblock {
                # Unpublish only, when Apps when present
                # Due to bug in 14.x - do NOT remove application symbols - they are used by some system functionality
                #Get-NavAppInfo -ServerInstance $ServerInstance -Name "Application" -Publisher "Microsoft" -SymbolsOnly | Unpublish-NavApp
                Get-NavAppInfo -ServerInstance $ServerInstance -Name "Test" -Publisher "Microsoft" -SymbolsOnly | Unpublish-NavApp
            }
        }
    
        if ($includeTestToolkit) {
            Import-TestToolkitToBcContainer `
                -containerName $containerName `
                -sqlCredential $sqlCredential `
                -includeTestLibrariesOnly:$includeTestLibrariesOnly `
                -includeTestFrameworkOnly:$includeTestFrameworkOnly `
                -includePerformanceToolkit:$includePerformanceToolkit `
                -doNotUseRuntimePackages:$doNotUseRuntimePackages
        }
    }

    if ($includeCSide) {
        $winClientFolder = (Get-Item "$programFilesFolder\*\RoleTailored Client").FullName
        New-DesktopShortcut -Name "$containerName Windows Client" -TargetPath "$WinClientFolder\Microsoft.Dynamics.Nav.Client.exe" -Arguments "-settings:ClientUserSettings.config" -Shortcuts $shortcuts
        New-DesktopShortcut -Name "$containerName WinClient Debugger" -TargetPath "$WinClientFolder\Microsoft.Dynamics.Nav.Client.exe" -Arguments "-settings:ClientUserSettings.config ""DynamicsNAV:////debug""" -Shortcuts $shortcuts

        $databaseInstance = $customConfig.DatabaseInstance
        $databaseName = $customConfig.DatabaseName
        $databaseServer = $customConfig.DatabaseServer
        if ($databaseServer -eq "localhost") {
            $databaseServer = "$containerName"
            if (("$databaseInstance" -ne "") -and ("$databaseInstance" -ne "SQLEXPRESS")) {
                $databaseServer += "\$databaseInstance"
            }
        }
        else {
            if ($databaseInstance) {
                $databaseServer += "\$databaseInstance"
            }
        }

        if ($auth -eq "Windows") {
            $ntauth="1"
        } else {
            $ntauth="0"
        }
        $csideParameters = "servername=$databaseServer, Database=$databaseName, ntauthentication=$ntauth, ID=$containerName"

        if ($enableSymbolLoading) {
            $csideParameters += ",generatesymbolreference=1"
        }

        New-DesktopShortcut -Name "$containerName CSIDE" -TargetPath "$WinClientFolder\finsql.exe" -Arguments "$csideParameters" -Shortcuts $shortcuts
    }

    if (($includeCSide -or $includeAL) -and !$doNotExportObjectsToText) {

        # Include oldsyntax only if IncludeCSide is specified
        # Include newsyntax if NAV Version is greater than NAV 2017

        if ($includeCSide) {
            $originalFolder = Join-Path $ExtensionsFolder "Original-$navversion"
            if (!(Test-Path $originalFolder)) {
                # Export base objects
                Export-NavContainerObjects -containerName $containerName `
                                           -objectsFolder $originalFolder `
                                           -filter "" `
                                           -sqlCredential $sqlCredential `
                                           -ExportTo 'txt folder'
            }
        }

        if ($version.Major -ge 15) {
            $alFolder = Join-Path $ExtensionsFolder "Original-$navversion-al"
            if (!(Test-Path $alFolder) -or (Get-ChildItem -Path $alFolder -Recurse | Measure-Object).Count -eq 0) {
                if (!(Test-Path $alFolder)) {
                    New-Item $alFolder -ItemType Directory | Out-Null
                }
                if ($version -ge [Version]("15.0.35528.0")) {
                    Invoke-ScriptInBcContainer -containerName $containerName -scriptBlock { Param($alFolder, $country)
                        [Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.Filesystem") | Out-Null
                        if (Test-Path "C:\Applications.$country") {
                            $baseAppSource = @(get-childitem -Path "C:\Applications.*\*.*" -recurse -filter "Base Application.Source.zip")
                        }
                        else {
                            $baseAppSource = @(get-childitem -Path "C:\Applications\*.*" -recurse -filter "Base Application.Source.zip")
                        }
                        if ($baseAppSource.Count -ne 1) {
                            throw "Unable to locate Base Application.Source.zip"
                        }
                        Write-Host "Extracting $($baseAppSource[0].FullName)"
                        [System.IO.Compression.ZipFile]::ExtractToDirectory($baseAppSource[0].FullName, $alFolder)
                    } -argumentList (Get-BCContainerPath -containerName $containerName -path $alFolder), $devCountry
                }
                else {
                    $appFile = Join-Path $ExtensionsFolder "BaseApp-$navVersion.app"
                    $appName = "Base Application"
                    if ($version -lt [Version]("15.0.35659.0")) {
                        $appName = "BaseApp"
                    }
                    Get-BcContainerApp -containerName $containerName `
                                        -publisher Microsoft `
                                        -appName $appName `
                                        -appFile $appFile `
                                        -credential $credential
    
                    $appFolder = Join-Path $ExtensionsFolder "BaseApp-$navVersion"
                    Extract-AppFileToFolder -appFilename $appFile -appFolder $appFolder
    
                    'layout','src','translations' | ForEach-Object {
                        if (Test-Path (Join-Path $appFolder $_)) {
                            Copy-Item -Path (Join-Path $appFolder $_) -Destination $alFolder -Recurse -Force
                        }
                    }
    
                    Remove-Item -Path $appFolder -Recurse -Force
                    Remove-Item -Path $appFile -Force
                }
            }
        }
        elseif ($version.Major -gt 10) {
            $originalFolder = Join-Path $ExtensionsFolder "Original-$navversion-newsyntax"
            if (!(Test-Path $originalFolder)) {
                # Export base objects as new syntax
                Export-NavContainerObjects -containerName $containerName `
                                           -objectsFolder $originalFolder `
                                           -filter "" `
                                           -sqlCredential $sqlCredential `
                                           -ExportTo 'txt folder (new syntax)'
            }
            if ($version.Major -ge 14 -and $includeAL) {
                $alFolder = Join-Path $ExtensionsFolder "Original-$navversion-al"
                if ($runTxt2AlInContainer -ne $containerName) {
                    Write-Host "Using container $runTxt2AlInContainer to convert .txt to .al"
                    if (Test-Path $alFolder) {
                        Write-Host "Removing existing AL folder $alFolder"
                        Remove-Item -Path $alFolder -Recurse -Force
                    }
                }
                if (!(Test-Path $alFolder)) {
                    $dotNetAddInsPackage = Join-Path $ExtensionsFolder "$containerName\coredotnetaddins.al"
                    Copy-Item -Path (Join-Path $PSScriptRoot "..\ObjectHandling\coredotnetaddins.al") -Destination $dotNetAddInsPackage -Force
                    if ($runTxt2AlInContainer -ne $containerName) {
                        Write-Host "Using container $runTxt2AlInContainer to convert .txt to .al"
                    }
                    Convert-Txt2Al -containerName $runTxt2AlInContainer -myDeltaFolder $originalFolder -myAlFolder $alFolder -startId 50100 -dotNetAddInsPackage $dotNetAddInsPackage
                }
            }
        }
    }

    if ($includeAL) {
        $dotnetAssembliesFolder = Join-Path $containerFolder ".netPackages"
        New-Item -Path $dotnetAssembliesFolder -ItemType Directory -ErrorAction Ignore | Out-Null

        Write-Host "Creating .net Assembly Reference Folder for VS Code"
        Invoke-ScriptInBcContainer -containerName $containerName -scriptblock { Param($dotnetAssembliesFolder)

            $serviceTierFolder = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName

            $paths = @("C:\Windows\assembly", $serviceTierFolder)

            $rtcFolder = "C:\Program Files (x86)\Microsoft Dynamics NAV\*\RoleTailored Client"
            if (Test-Path $rtcFolder -PathType Container) {
                $paths += (Get-Item $rtcFolder).FullName
            }
            $mockAssembliesPath = "C:\Test Assemblies\Mock Assemblies"
            if (Test-Path $mockAssembliesPath -PathType Container) {
                $paths += $mockAssembliesPath
            }
            $paths += "C:\Program Files (x86)\Open XML SDK"

            $paths | % {
                Write-Host "Copying DLLs from $_ to assemblyProbingPath"
                Copy-Item -Path $_ -Destination $dotnetAssembliesFolder -Force -Recurse -Filter "*.dll"
            }

            $serviceTierAddInsFolder = Join-Path $serviceTierFolder "Add-ins"
            if (!(Test-Path (Join-Path $serviceTierAddInsFolder "RTC"))) {
                if (Test-Path $RtcFolder -PathType Container) {
                    new-item -itemtype symboliclink -path $ServiceTierAddInsFolder -name "RTC" -value (Get-Item $RtcFolder).FullName | Out-Null
                }
            }
        } -argumentList $dotnetAssembliesFolder
    }

    if (($useCleanDatabase -or $useNewDatabase) -and !$restoreBakFolder) {
        Clean-BcContainerDatabase -containerName $containerName -useNewDatabase:$useNewDatabase -credential $credential -doNotCopyEntitlements:$doNotCopyEntitlements -copyTables $copyTables
        if ($multitenant) {
            Write-Host "Switching to multitenant"
            
            Invoke-ScriptInBCContainer -containerName $containerName -scriptblock {
            
                $customConfigFile = Join-Path (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName "CustomSettings.config"
                [xml]$customConfig = [System.IO.File]::ReadAllText($customConfigFile)
                $databaseServer = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseServer']").Value
                $databaseInstance = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseInstance']").Value
                $databaseName = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseName']").Value
                
                Set-NavserverInstance -ServerInstance $serverInstance -stop
                Copy-NavDatabase -SourceDatabaseName $databaseName -DestinationDatabaseName "tenant"
                Remove-NavDatabase -DatabaseName $databaseName
                Write-Host "Exporting Application to $DatabaseName"
                Invoke-sqlcmd -serverinstance "$DatabaseServer\$DatabaseInstance" -Database tenant -query 'CREATE USER "NT AUTHORITY\SYSTEM" FOR LOGIN "NT AUTHORITY\SYSTEM";'
                Export-NAVApplication -DatabaseServer $DatabaseServer -DatabaseInstance $DatabaseInstance -DatabaseName "tenant" -DestinationDatabaseName $databaseName -Force -ServiceAccount 'NT AUTHORITY\SYSTEM' | Out-Null
                Write-Host "Removing Application from tenant"
                Remove-NAVApplication -DatabaseServer $DatabaseServer -DatabaseInstance $DatabaseInstance -DatabaseName "tenant" -Force | Out-Null
                Set-NAVServerConfiguration -ServerInstance $ServerInstance -KeyName "Multitenant" -KeyValue "true" -ApplyTo ConfigFile
                Set-NavserverInstance -ServerInstance $serverInstance -start
            }
            New-BcContainerTenant -containerName $containerName -tenantId default
        }
    }

    if (!$restoreBakFolder -and $finalizeDatabasesScriptBlock) {
        Invoke-Command -ScriptBlock $finalizeDatabasesScriptBlock
    }

    if ($bakFolder -and !$restoreBakFolder) {
        Backup-BcContainerDatabases -containerName $containerName -bakFolder $bakFolder
    }

    Write-Host -ForegroundColor Green "Container $containerName successfully created"

    if ($useTraefik) {
        Write-Host -ForegroundColor Yellow "Because of Traefik, the following URLs need to be used when accessing the container from outside your Docker host:"
        Write-Host "Web Client:        $webclientUrl"
        Write-Host "SOAP WebServices:  $soapUrl"
        Write-Host "OData WebServices: $restUrl"
        Write-Host "Dev Service:       $devUrl"
        Write-Host "File downloads:    $dlUrl"
    }

    Write-Host
    Write-Host "Use:"
    Write-Host -ForegroundColor Yellow -NoNewline "Get-BcContainerEventLog -containerName $containerName"
    Write-Host " to retrieve a snapshot of the event log from the container"
    Write-Host -ForegroundColor Yellow -NoNewline "Get-BcContainerDebugInfo -containerName $containerName"
    Write-Host  " to get debug information about the container"
    Write-Host -ForegroundColor Yellow -NoNewline "Enter-BcContainer -containerName $containerName"
    Write-Host " to open a PowerShell prompt inside the container"
    Write-Host -ForegroundColor Yellow -NoNewline "Remove-BcContainer -containerName $containerName"
    Write-Host " to remove the container again"
    Write-Host -ForegroundColor Yellow -NoNewline "docker logs $containerName"
    Write-Host " to retrieve information about URL's again"
}
Set-Alias -Name New-NavContainer -Value New-BcContainer
Export-ModuleMember -Function New-BcContainer -Alias New-NavContainer
