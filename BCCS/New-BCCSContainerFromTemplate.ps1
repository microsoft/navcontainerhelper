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

function New-BCCSContainerFromTemplate {
    Param (
        [Parameter(mandatory = $true)]
        [string] $prefix,
        [Parameter(mandatory = $true)]
        [string] $containerName,
        [string] $databaseBackup = "",
        [string] $imageName = "",
        [string] $licenseFile = "",
        [string] $file = ""
    )

    $file = Get-BCCSTemplateFile $file

    if (Test-Path $file) {
        $jsonData = Get-Content -Path $file -Raw | ConvertFrom-Json
    }
    else {
        throw "$($file) could not be read as a json file"
    }

    if ($jsonData.prefix -notcontains $prefix) {
        throw "Could not find template with prefix $($prefix)"
    }

    $fullContainerName = $prefix + "-" + $containerName

    Check-NavContainerName -containerName $fullContainerName

    $template = $jsonData | Where-Object prefix -eq $prefix

    $params = @{
        'containerName'            = $fullContainerName;
        'imageName'                = $template.imageName;
        'auth'                     = $template.auth;
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

    if ($template.auth -match "UserPassword") {
        $credential = $host.ui.PromptForCredential("Enter credentials to use for the container", "Please enter a user name and password.", "admin", "")
        $params += @{'credential' = $credential }
    }

    if ($template.licenseFile -ne "") {
        if (!(Test-Path -path $template.licenseFile)) {
            throw "Could not open license file at $($template.licenseFile)"
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
        Write-Log "Creating container..."
        New-NavContainer @params
        if ($template.licenseFile -ne "") {
            Write-Log "Importing license file..."
            Import-NavContainerLicense -containerName $fullContainerName -licenseFile $template.licenseFile
        }
        Write-Log "Adding fonts to container..."
        Add-FontsToNavContainer -containerName $fullContainerName 
    }
    catch {
        throw "Could not create $($fullContainerName)"
    }

    if ($databaseBackup) {
        Remove-Item "C:\temp\navdbfiles\dbFile.bak"
        Write-Log "Successfully removed C:\temp\navdbfiles\dbFile.bak"
    }
}

Export-ModuleMember -Function New-BCCSContainerFromTemplate