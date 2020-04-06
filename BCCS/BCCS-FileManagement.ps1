try {
    git -C $bccsScriptFolder pull
}
catch {
    Write-Log "Could not pull latest version"
}

function Get-BCCSTemplateFile() {
    Param (
        [string] $file = ""
    )

    if ($file -eq "") {
        $file = Join-Path $bccsFolder "templates.json"
        if (!(Test-Path $file)) {
            Write-Log "No file specified. Creating $($file)"
            New-Item $file -ItemType File | Out-Null
        }
        else {
            Write-Log "No file specified. Using $($file)"            
        }
    }
    else {
        Write-Log "Using $($file)"
    }

    $jsonFile = Get-Item $file
    if ($jsonFile.Extension -ne ".json") {
        throw "$($file) is not a json file"
    }

    $file
}

function Write-Log($message) {
    $currDate = Get-Date -Format "yyyy-MM-dd"
    $logFile = Join-Path $bccsFolder "$($currDate).log"
    if (!(Test-Path $logFile)) {
        New-Item $logFile -ItemType File | Out-Null
    }

    $time = Get-Date -Format "[HH:mm:ss]"
    Write-Host $time $message -ForegroundColor Yellow
    Add-Content $logFile -value "$($time) $($message)"
}