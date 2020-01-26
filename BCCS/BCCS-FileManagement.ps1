function Get-BCCSTemplateFile() {
    Param (
        [string] $file = ""
    )
    Write-Host ""

    if ($file -eq "") {
        $file = Join-Path $bccsFolder "templates.json"
        if (!(Test-Path $file)) {
            Write-Host "No file specified. Creating $($file)"
            New-Item $file -ItemType File | Out-Null
        }
        else {
            Write-Host "No file specified. Using $($file)"            
        }
    }

    $jsonFile = Get-Item $file
    if ($jsonFile.Extension -ne ".json") {
        throw "$($file) is not a json file"
    }

    $file
}