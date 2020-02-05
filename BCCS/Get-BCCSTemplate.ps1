<# 
 .Synopsis
  Create a new template to be used with the Business Central Container Script
 .Description
  This command will create a new template entry in a JSON file. If no file is specified it will be created in the user's appdata folder.
 .Parameter file
  Name of the container in which you want to backup databases
 .Parameter prefix
  Prefix to use for any container's name created from the template
 .Example
  New-BCCSTemplate -prefix BC365 -name "Business Central" -image "mcr.microsoft.com/businesscentral/onprem"
#>

function Get-BCCSTemplate {
    Param (
        [string] $file = ""
    )

    $file = Get-BCCSTemplateFile $file

    if (Test-Path $file) {
        $jsonData = Get-Content -Path $file -Raw | ConvertFrom-Json
    }
    else {
        throw "$($file) could not be read as a json file"
    }

    if (($jsonData -eq "[]") -or ($jsonData -eq " ")) {
        throw "$($file) does not contain any templates"
    }

    $jsonEntries = $jsonData | ForEach-Object { $_ }
    $tempList = @()
    foreach ($jsonEntry in $jsonEntries) {
        $temp = [PSCustomObject]@{
            Prefix          = $jsonEntry.prefix;
            Name            = $jsonEntry.name;
            ImageName       = $jsonEntry.imageName;
            LicenseFile     = $jsonEntry.licenseFile;
            ServiceAddinZip = $jsonEntry.serviceAddinZip;
            Auth            = $jsonEntry.auth;
        }
        $tempList += $temp
    }
    return $tempList
}

Export-ModuleMember -Function Get-BCCSTemplate