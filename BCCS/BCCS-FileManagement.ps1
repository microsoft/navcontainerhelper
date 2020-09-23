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

function IsURL($string) {
    $regex = "https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)"
    $result = Select-String -InputObject $string -Pattern $regex
    if ($null -eq $result) {
        $result = Select-String -InputObject $string -Pattern "mcr.microsoft.com"
    }
    return $null -ne $result
}

function FindSingleResultByPattern ($string, $pattern, $name, $default) {
    Set-StrictMode -Off
    $results = $string | Select-String -Pattern $pattern -AllMatches
    $ambiguous = $results.Matches.Count -gt 1
    if ($ambiguous) {
        throw "Ambiguous $($name). $($results.Matches.Count) occurences found in string."
    }
    if ($results.Matches.Count -eq 0) {
        Write-Host "$($name) is missing in string. Assuming $($default)."
        $result = $default
    }
    else {
        $result = $results.Matches[0].Value
        Write-Host "Found $($name) $($result) in string and using it now."
    }
    Set-StrictMode -Version 2.0
    return $result
}

function GetArtifactURLFromString($string) {
    $str = $string
    
    $type = FindSingleResultByPattern $str "OnPrem|Sandbox" "Type" "OnPrem"
    $str = $str.Replace($type, "")

    $country = FindSingleResultByPattern $str "at|au|base|be|ca|ch|co|cz|de|dk|ee|es|fi|fr|gb|hk|hr|hu|is|it|jp|kr|lt|lv|mx|na|nl|no|nz|pe|ph|pl|pt|rs|se|si|sk|th|tr|tw|us|vn|w1" "Country" "w1"
    $str = $str.Replace($country, "")

    $navVersion = FindSingleResultByPattern $str "2018|2017|2016" "NAV Version" "BC"
    $str = $str.Replace($navVersion, "")

    $cu = FindSingleResultByPattern $str "cu" "Cumulative Update" "version"
    if ($cu -ne "version") {
        if ($navVersion -eq "BC") {
            throw "Trying to use CU for BC. This only works for NAV 2018/2017/2016."
        }
    }
    $str = $str.Replace($cu, "")

    if ($cu -eq "cu") {
        $version = FindSingleResultByPattern $str "[0-9]{1,2}(\.[0-9]{1,2})?(\.[0-9]{1,5})?(\.[0-9]{1,5})?" "CU Number" "0"
        $version = "cu$($version)"
    }
    else {
        $version = FindSingleResultByPattern $str "[0-9]{1,2}(\.[0-9]{1,2})?(\.[0-9]{1,5})?(\.[0-9]{1,5})?" "Version" "latest"
    }

    if ($navVersion -eq "BC") {
        $url = Get-BCArtifactUrl -type $type -country $country -version $version
        if ($null -eq $url) {
            throw "No BC Artifact URL found!"
        }
    }
    else {
        $url = Get-NavArtifactUrl -nav $navVersion -country $country -cu $version
        if ($null -eq $url) {
            throw "No NAV Artifact URL found!"
        }
    }

    return $url
}