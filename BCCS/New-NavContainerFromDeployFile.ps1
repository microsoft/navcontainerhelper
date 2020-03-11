<# 
 .Synopsis
  Create a new template to be used with the Business Central Container Script
 .Description
  This command will create a new template entry in a JSON file. If no file is specified it will be created in the user's appdata folder.
 .Parameter file
  Name of the container in which you want to backup databases
 .Parameter prefix
  Prefix of the template to use
 .Parameter name
  Name for this container. Is added to the prefix (PREFIX-NAME)
 .Parameter imageName
  Name of the image you want to use for your Container
 .Parameter licenseFile
  Path or Secure Url of the licenseFile you want to use
 .Parameter auth
  Set auth to Windows, NavUserPassword or AAD depending on which authentication mechanism your container should use
 .Parameter addinFile
  Path of a .zip archive containing service add-ins to be copied into the container (not working yet!)
 .Example
  New-BCCSContainerFromTemplate -prefix BC365 -name DEV
 .Example
  New-BCCSContainerFromTemplate -prefix BC365 -name TEST -licenseFile "C:\Files\license.flf"
#>

function New-NavContainerFromDeployFile {
    Param (
        [Parameter(mandatory = $true, ValueFromPipeline = $true)]
        [string] $file,
        [Parameter(mandatory = $true)]
        [string] $containerSuffix,
        [string] $licenseFile = "",
        [string] $databaseBackup = "",
        [ValidateSet('Windows', 'NavUserPassword', 'UserPassword', 'AAD')]
        [string] $auth = "NavUserPassword"
    )

    if (Test-Path $file) {
        $jsonData = Get-Content -Path $file -Raw | ConvertFrom-Json
    }
    else {
        throw "$($file) could not be read"
    }

    $deploy_Prefix = $jsonData.prefix
    $deploy_Name = $jsonData.name
    $deploy_imageName = $jsonData.imageName
    $deploy_appFilePaths = $jsonData.appFilePaths
    $deploy_fontPaths = $jsonData.fontPaths
    $deploy_addinPaths = $jsonData.addinPaths
    $deploy_rapidstartPaths = $jsonData.rapidstartPaths
    $deploy_licenseFile = $jsonData.licenseFilePath

    $appFilePaths = @()
    $deploy_appFilePaths | ForEach-Object { $appFilePaths = $appFilePaths + (Join-Path ((Get-Item $file).Directory.FullName) -ChildPath $_ -Resolve) }
    
    $appFiles = @()
    $appFilePaths | ForEach-Object {
        Get-ChildItem (Join-Path -Path $_ -ChildPath "\*") -Include '*.app' -File | ForEach-Object {
            $appFiles += $_.FullName
        }
    }

    $fontPaths = @()
    $fontFiles = @()
    $deploy_fontPaths | ForEach-Object { $fontPaths = $fontPaths + (Join-Path ((Get-Item $file).Directory.FullName) -ChildPath $_ -Resolve) }
    $fontPaths | ForEach-Object {
        Get-ChildItem (Join-Path -Path $_ -ChildPath "\*") -Include ('*.fon', '*.ttf', '*.ttc', '*.otf', '*.fnt') -File | ForEach-Object {
            $fontFiles += $_.FullName
        }
    }

    $rapidstartPaths = @()
    $rapidstartFiles = @()
    $deploy_rapidstartPaths | ForEach-Object { $rapidstartPaths = $rapidstartPaths + (Join-Path ((Get-Item $file).Directory.FullName) -ChildPath $_ -Resolve) }
    $rapidstartPaths | ForEach-Object {
        Get-ChildItem (Join-Path -Path $_ -ChildPath "\*") -Include ('*.rapidstart') -File | ForEach-Object {
            $rapidstartFiles += $_.FullName
        }
    }

    $appFilesSelected = @()
    if ($appFiles.Count -gt 0) {
        $appFiles | Out-GridView -OutputMode Multiple | ForEach-Object { 
            $appFilesSelected += $_ 
        }
    }
    
    if ($licenseFile -eq "") {
        $licenseFile = Join-Path ((Get-Item $file).Directory.FullName) -ChildPath $deploy_licenseFile -Resolve
    }

    $fullContainerName = $deploy_Prefix + "-" + $containerSuffix

    Check-NavContainerName -containerName $fullContainerName

    $params = @{
        'containerName'            = $fullContainerName;
        'imageName'                = $deploy_imageName;
        'auth'                     = $auth;
        'shortcuts'                = 'StartMenu';
        'accept_eula'              = $true;
        'accept_outdated'          = $true;
        'doNotCheckHealth'         = $true;
        'doNotExportObjectsToText' = $true;
        'alwaysPull'               = $true;
        'updateHosts'              = $true;
        'useBestContainerOS'       = $true;
        'includeCSide'             = $true;
        'enableSymbolLoading'      = $true;
    }

    if ($licenseFile -ne "") {
        if (!(Test-Path -path $licenseFile)) {
            throw "Could not open license file at $($licenseFile)"
        }
    }

    if ($databaseBackup) {
        if (!(Test-Path -path "C:\temp")) { New-Item "C:\temp" -Type Directory }
        if (!(Test-Path -path "C:\temp\navdbfiles")) { New-Item "C:\temp\navdbfiles" -Type Directory }
        Write-Log "Copying database backup to C:\temp\navdbfiles\dbFile.bak ..."
        Copy-Item $databaseBackup "C:\temp\navdbfiles\dbFile.bak"
        $params += @{'additionalParameters' = @('--volume c:\temp\navdbfiles:c:\temp', '--env bakfile="c:\temp\dbFile.bak"') }
        Write-Log "Successfully copied database backup"
    }

    try {
        $startDTM = (Get-Date)
        Write-Log "Creating container..."
        New-NavContainer @params
        if ($licenseFile -ne "") {
            Write-Log "Importing license file..."
            try {
                Import-NavContainerLicense -containerName $fullContainerName -licenseFile $licenseFile
            }
            finally {
                Write-Log "License import finished."
            }
        }
        if ($appFilesSelected.Count -gt 0) {
            Write-Log "Publishing apps to container..."
            try {
                $appFilesSelected | ForEach-Object { Publish-NavContainerApp -containerName $fullContainerName -appFile $_ -skipVerification }
            }
            finally {
                Write-Log "App publishing finished."
            }
        }
        if ($rapidstartFiles.Count -gt 0) {
            Write-Log "Adding configuration packages to container..."
            try {
                $rapidstartFiles | ForEach-Object { Import-ConfigPackageInNavContainer -containerName $fullContainerName -configPackage $_ }
            }
            finally {
                Write-Log "Configuration package import finished."
            }
        }
        if ($fontFiles.Count -gt 0) {
            Write-Log "Adding fonts to container..."
            try {
                $fontFiles | ForEach-Object { Add-FontsToNavContainer -containerName $fullContainerName -path $_ }
            }
            finally {
                Write-Log "Font installation finished."
            }
        }
        if ($databaseBackup) {
            Remove-Item "C:\temp\navdbfiles\dbFile.bak"
            Write-Log "Successfully removed C:\temp\navdbfiles\dbFile.bak"
        }
    }
    catch {
        throw "Could not create $($fullContainerName)"
    }
    finally {
        Write-Log "Successfully created container $($fullContainerName) in $([timespan]::fromseconds(((Get-Date)-$startDTM).Totalseconds).ToString("hh\:mm\:ss"))"
        Write-Host "Shortcuts can be found in the start menu (e.g. $($fullContainerName) Web Client)."
        Write-Host "You can download the correct AL language extension by opening 'http://$($fullContainerName):8080'."
    }
}

Export-ModuleMember -Function New-NavContainerFromDeployFile