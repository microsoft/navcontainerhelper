<# 
 .Synopsis
  Create a new template to be used with the Business Central Container Script
 .Description
  This command will create a new template entry in a JSON file. If no file is specified it will be created in the user's appdata folder.
 .Parameter file
  Name of the container in which you want to backup databases
 .Parameter prefix
  Prefix to use for any container's name created from the template
 .Parameter name
  Name to easily identify your template by
 .Parameter imageName
  Name of the image you want to use for your Container
 .Parameter licenseFile
  Path or Secure Url of the licenseFile you want to use
 .Parameter auth
  Set auth to Windows, NavUserPassword or AAD depending on which authentication mechanism your container should use (defaults to Windows)
 .Parameter addinFile
  Path of a .zip archive containing service add-ins to be copied into the container (not working yet!)
 .Example
  New-BCCSTemplate -prefix BC365 -name "Business Central" -image "mcr.microsoft.com/businesscentral/onprem"
#>

function New-BCCSTemplate {
    Param (
        [string] $file = "", 
        [Parameter(mandatory = $true)]
        [string] $prefix,
        [Parameter(mandatory = $true)]
        [string] $name,
        [Parameter(mandatory = $true)]
        [string] $imageName,
        [string] $licenseFile = "",
        [string] $serviceAddinZip = "",
        [ValidateSet('Windows', 'NavUserPassword', 'UserPassword', 'AAD')]
        [string] $auth = "Windows"
    )

    $file = Get-BCCSTemplateFile $file

    if (Test-Path $file) {
        $jsonData = Get-Content -Path $file -Raw | ConvertFrom-Json
    }
    else {
        throw "$($file) could not be read as a json file"
    }

    if ($jsonData -ne "[]" -ne " ") {
        if ($jsonData.prefix -contains $prefix) {
            throw "Template $($prefix) already exists"
        }
    }

    $template = [PSCustomObject]@{prefix = $prefix; name = $name; imageName = $imageName; licenseFile = $licenseFile; serviceAddinZip = $serviceAddinZip; auth = $auth }
    $jsonData += $template

    try {
        Write-Host ""
        Write-Host "Saved the following template to $($file)"
        Write-Host "Prefix = " -NoNewline
        Write-Host $prefix -ForegroundColor Yellow
        Write-Host "Name = " -NoNewline
        Write-Host $name -ForegroundColor Yellow
        Write-Host "Image Name = " -NoNewline
        Write-Host $imageName -ForegroundColor Yellow
        Write-Host "License File = " -NoNewline
        Write-Host $licenseFile -ForegroundColor Yellow
        Write-Host "Add-In .zip File = " -NoNewline
        Write-Host $serviceAddinZip -ForegroundColor Yellow
        Write-Host "Authentication Type = " -NoNewline
        Write-Host $auth -ForegroundColor Yellow
        ConvertTo-Json @($jsonData) | Out-File -FilePath $file
    }
    catch {
        throw "Could not save template $($prefix)"
    }
}

Export-ModuleMember -Function New-BCCSTemplate