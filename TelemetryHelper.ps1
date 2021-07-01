$telemetryClient = $null

function FormatValue {
    Param(
        $value
    )

    if ($value -is [switch]) {
        "$($value.IsPresent)"
    }
    elseif ($value -is [boolean]) {
        "$value"
    }
    elseif ($value -is [SecureString]) {
        "[SecureString]"
    }
    elseif ($value -is [PSCredential]) {
        "[PSCredential]"
    }
    elseif ($value -is [string]) {
        if (($value -like "https:*" -or $value -like "http:*") -and ($value.Contains('?'))) {
            """$($value.Split('?')[0])?[parameters]"""
        }
        else {
            """$value"""
        }
    }
    elseif ($value -is [System.Collections.IDictionary]) {
        $str = ""
        $value.GetEnumerator() | ForEach-Object {
            if ($str) { $str += ", " } else { $str = "{ " }
            $str += "$($_.Key): $(FormatValue -value $_.Value)"
        }
        "$str }"
    }
    elseif ($value -is [System.Collections.IEnumerable]
    ) {
        $str = ""
        $value.GetEnumerator() | ForEach-Object {
            if ($str) { $str += ", " } else { $str = "[ " }
            $str += "$(FormatValue -value $_)"
        }
        "$str ]"
    }
    else {
        "$value"
    }
}

function AddTelemetryProperty {
    Param(
        $telemetryScope,
        $key,
        $value
    )

    if ($telemetryScope) {
        $telemetryScope.properties.Add($key, (FormatValue -value $value))
    }
}

function InitTelemetryScope {
    Param(
        [string] $name,
        [string[]] $includeParameters = @(),
        $parameterValues = $null
    )

    if ($telemetryClient -eq $null) {
        if ($bcContainerHelperConfig.InstrumentationKey) {
            Add-Type -path (Join-Path $PSScriptRoot "Microsoft.ApplicationInsights.dll") -ErrorAction SilentlyContinue
            $telemetryClient = [Microsoft.ApplicationInsights.TelemetryClient]::new()
            $telemetryClient.InstrumentationKey = $bcContainerHelperConfig.InstrumentationKey
        }
    }
    if ($telemetryClient) {
        $scope = @{
            "Name" = $name
            "StartTime" = [DateTime]::Now
            "SeverityLevel" = 1
            "Properties" = [Collections.Generic.Dictionary[string, string]]::new()
        }
        if ($includeParameters) {
            $parameterValues.GetEnumerator() | % {
                $includeParameter = $false
                $key = $_.key
                $includeParameters | ForEach-Object { if ($key -like $_) { $includeParameter = $true } }
                if ($includeParameter) {
                    AddTelemetryProperty -telemetryScope $scope -key "Parameter[$Key]" -value $_.Value
                }
            }
        }
        AddTelemetryProperty -telemetryScope $scope -key "BcContainerHelperVersion" -value $BcContainerHelperVersion
        AddTelemetryProperty -telemetryScope $scope -key "IsAdministrator" -value $isAdministrator
        AddTelemetryProperty -telemetryScope $scope -key "StackTrace" -value (Get-PSCallStack | % { "$($_.Command) at $($_.Location)" }) -join "`n"
        $scope
    }
}

function TrackTrace {
    Param(
        $telemetryScope
    )

    if ($telemetryClient -and $telemetryClient.IsEnabled()) {
        $telemetryScope.Properties.Add("Duration", [DateTime]::Now.Subtract($telemetryScope.StartTime).TotalSeconds)
        $telemetryClient.TrackTrace($telemetryScope.Name, $telemetryScope.SeverityLevel, $telemetryScope.Properties)
    }
}

function TrackException {
    Param(
        $telemetryScope,
        $errorRecord
    )

    if ($telemetryClient -and $telemetryClient.IsEnabled()) {
        $telemetryScope.Properties.Add("Duration", [DateTime]::Now.Subtract($telemetryScope.StartTime).TotalSeconds)
        $telemetryScope.Properties.Add("StackTrace", $errorRecord.ScriptStackTrace)
        $telemetryClient.TrackException($errorRecord.Exception, $telemetryScope.Properties)
    }
}
