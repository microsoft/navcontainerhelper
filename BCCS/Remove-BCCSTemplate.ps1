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

function Remove-BCCSTemplate {
    Param (
        [Parameter(mandatory = $true)]
        [string] $prefix,
        [string] $file = ""
    )

    $file = Get-BCCSTemplateFile $file

    if (Test-Path $file) {
        $jsonData = Get-Content -Path $file -Raw | ConvertFrom-Json
    }
    else {
        throw "$($file) could not be read as a json file"
    }

    if ($jsonData -ne "[]" -ne " ") {
        if ($jsonData.prefix -notcontains $prefix) {
            throw "Could not find any template with prefix $($prefix)"
        }
    }

    try {
        $jsonData = $jsonData | Where-Object prefix -ne $prefix
        ConvertTo-Json @($jsonData) | Out-File -FilePath $file
        Write-Host ""
        Write-Host "Removed template $($prefix)"
    }
    catch {
        throw "Could not remove template $($prefix)"
    }
}

Export-ModuleMember -Function Remove-BCCSTemplate