<# 
 .Synopsis
  Create a new NAV/BC container from a JSON file
 .Description
  This command will create a new container from a JSON file.
 .Parameter file
  Path to the JSON file to use
 .Parameter containerSuffix
  Suffix to be used for the container (prefix is defined in JSON)
 .Parameter databaseBackup
  Path to a backup file you want to use
 .Parameter licenseFile
  Path or Secure Url of the licenseFile you want to use (override license file defined in JSON)
 .Parameter auth
  Set auth to Windows, NavUserPassword or AAD depending on which authentication mechanism your container should use (defaults to NavUserPassword)
 .Example
  New-NavContainerFromDeployFile -file "C:\temp\git\project\.docker\deploy.json" -containerSuffix DEV
 .Example
  New-NavContainerFromDeployFile -file "C:\temp\git\project\.docker\deploy.json" -containerSuffix DEV -auth Windows -databaseBackup "C:\Workspace\backup.bak"
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
        if ($deploy_licenseFile -ne "") {
            $licenseFile = Join-Path ((Get-Item $file).Directory.FullName) -ChildPath $deploy_licenseFile -Resolve
        }
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
		'isolation'                = 'hyperv';
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
        $totalErrorCount = 0
        Write-Log "Creating container $($fullContainerName)..."
        New-NavContainer @params
        if ($licenseFile -ne "") {
            Write-Log "Importing license file..."
            try {
                $errorCount = 0
                Import-NavContainerLicense -containerName $fullContainerName -licenseFile $licenseFile
                Write-Log "Import of license file $licenseFile finished."
            }
            catch {
                $errorCount++
                Write-Log "Error on import of license $licenseFile"
                Write-Log $_
            }
            finally {
                $totalErrorCount += $errorCount
            }
        }
        if ($appFilesSelected.Count -gt 0) {
            Write-Log "Publishing apps to container $($fullContainerName)..."
            try {
                $errorCount = 0
                $appFilesSelected | ForEach-Object { 
                    try {
                        $current = $_
                        Publish-NavContainerApp -containerName $fullContainerName -appFile $_ -skipVerification 
                        Write-Log "Import of app file $_ finished."
                    }
                    catch {
                        $errorCount++
                        Write-Log "Error on publishing of app file $current"
                        Write-Log $_                       
                    }
                }
                Write-Log "App publishing finished with $errorCount errors."
            }
            catch {
                Write-Log "Error on app publishing."
                Write-Log $_
            }
            finally {
                $totalErrorCount += $errorCount
            }
        }
        if ($rapidstartFiles.Count -gt 0) {
            Write-Log "Adding configuration packages to container $($fullContainerName)..."
            try {
                $errorCount = 0
                $rapidstartFiles | ForEach-Object { 
                    try {
                        $current = $_
                        Import-ConfigPackageInNavContainer -containerName $fullContainerName -configPackage $_ 
                        Write-Log "Import of configuration package $_ finished."
                    }
                    catch {
                        $errorCount++
                        Write-Log "Error on import of configuration package $current"
                        Write-Log $_                        
                    }
                }
                Write-Log "Configuration package import finished with $errorCount errors."
            }
            catch {
                Write-Log "Error on import of configuration packages."
                Write-Log "`t$($_)"                
            }
            finally {
                $totalErrorCount += $errorCount
            }
        }
        if ($fontFiles.Count -gt 0) {
            Write-Log "Adding fonts to container $($fullContainerName)..."
            try {
                $errorCount = 0
                $fontFiles | ForEach-Object {
                    try {
                        $current = $_
                        Add-FontsToNavContainer -containerName $fullContainerName -path $_ 
                        Write-Log "Import of font $_ finished."
                    }
                    catch {
                        $errorCount++
                        Write-Log "Error on installation of font $current"
                        Write-Log $_
                    }
                }
                Write-Log "Font installation finished with $errorCount errors."
            }
            catch {
                Write-Log "Error on font installation."
                Write-Log $_
            }
            finally {
                $totalErrorCount += $errorCount
            }
        }
        if ($databaseBackup) {
            Remove-Item "C:\temp\navdbfiles\dbFile.bak"
            Write-Log "Successfully removed C:\temp\navdbfiles\dbFile.bak"
        }
        Write-Log "Created container $($fullContainerName) in $([timespan]::fromseconds(((Get-Date)-$startDTM).Totalseconds).ToString("hh\:mm\:ss")) with $($totalErrorCount) errors."
        Write-Host "Shortcuts can be found in the start menu (e.g. $($fullContainerName) Web Client)."
        Write-Host "You can download the correct AL language extension by opening 'http://$($fullContainerName):8080'."
    }
    catch {
        Write-Log "Error on creation of container $($fullContainerName)"
        Write-Log $_
    }
}

Export-ModuleMember -Function New-NavContainerFromDeployFile