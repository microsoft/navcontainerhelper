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
#        Write-Host "Telemetry scope $($telemetryScope.Name), add property $key = $((FormatValue -value $value))"
        if ($telemetryScope.properties.ContainsKey($Key)) {
            $telemetryScope.properties."$key" += "`n$(FormatValue -value $value)"
        }
        else {
            $telemetryScope.properties.Add($key, (FormatValue -value $value))
        }
    }
}

function InitTelemetryScope {
    Param(
        [string] $name,
        [string[]] $includeParameters = @(),
        $parameterValues = $null
    )
    if ($telemetry.Client) {
        if ($bcContainerHelperConfig.TelemetryConnectionString) {
            if ($telemetry.Client.TelemetryConfiguration.DisableTelemetry -or $telemetry.Client.TelemetryConfiguration.ConnectionString -ne $bcContainerHelperConfig.TelemetryConnectionString) {
                if ($bcContainerHelperConfig.TelemetryConnectionString) {
                    try {
                        $telemetry.Client.TelemetryConfiguration.ConnectionString = $bcContainerHelperConfig.TelemetryConnectionString
                        $telemetry.Client.TelemetryConfiguration.DisableTelemetry = $false
                        Write-Host "Telemetry client initialized"
                    }
                    catch {
                        $telemetry.Client.TelemetryConfiguration.DisableTelemetry = $true
                    }
                }
            }
            if ($telemetry.Client.IsEnabled()) {
                #Write-Host "Init telemetry scope $name"
                $scope = @{
                    "Name" = $name
                    "StartTime" = [DateTime]::Now
                    "SeverityLevel" = 1
                    "Properties" = [Collections.Generic.Dictionary[string, string]]::new()
                    "CorrelationId" = ""
                    "Emitted" = $false
                }
                if (!$telemetry.Transcripting) {
                    $scope.CorrelationId = [GUID]::NewGuid().ToString()
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
                if ($scope.CorrelationId -ne "") {
                    Start-Transcript -Path (Join-Path $env:TEMP $scope.CorrelationId) | Out-Null
                    $telemetry.Transcripting = $scope.CorrelationId
                }
                $scope
            }
        }
        else {
            $telemetry.Client.TelemetryConfiguration.DisableTelemetry = $true
        }
    }
}

function TrackTrace {
    Param(
        $telemetryScope
    )

    if ($telemetryScope -and !$telemetryScope.Emitted) {
        if ($telemetry.Client.IsEnabled()) {
            #Write-Host "Emit telemetry trace, scope $($telemetryScope.Name)"
            $telemetryScope.Properties.Add("Duration", [DateTime]::Now.Subtract($telemetryScope.StartTime).TotalSeconds)
            $telemetry.Client.TrackTrace($telemetryScope.Name, $telemetryScope.SeverityLevel, $telemetryScope.Properties)
            $telemetryScope.Emitted = $true
            if ($telemetry.Transcripting -eq $telemetryScope.CorrelationId) {
                try{
                    Stop-Transcript | Out-Null
                    $telemetry.Transcripting = ""
                    Remove-Item -Path (Join-Path $env:TEMP $telemetryScope.CorrelationId)
                }
                catch {}
            }
        }
    }

}

function TrackException {
    Param(
        $telemetryScope,
        $errorRecord
    )

    TrackException -telemetryScope $telemetryScope -exception $errorRecord.Exception -scriptStackTrace $errorRecord.scriptStackTrace
}

function TrackException {
    Param(
        $telemetryScope,
        $exception,
        $scriptStackTrace = $null
    )

    if ($telemetryScope -and !$telemetryScope.Emitted) {
        if ($telemetry.Client.IsEnabled()) {
            #Write-Host "Emit telemetry exception, scope $($telemetryScope.Name)"
            $telemetryScope.Properties.Add("Duration", [DateTime]::Now.Subtract($telemetryScope.StartTime).TotalSeconds)
            if ($scriptStackTrace) {
                $telemetryScope.Properties.Add("Error StackTrace", $scriptStackTrace)
            }
   
            if ($telemetry.Transcripting -eq $telemetryScope.CorrelationId) {
                try{
                    Stop-Transcript | Out-Null
                    $telemetry.Transcripting = ""
                    $telemetryScope.Properties.Add("Transcript", (Get-Content -Raw -Path (Join-Path $env:TEMP $telemetryScope.CorrelationId)))
                    $telemetryScope.Properties.Add("CorrelationId", $telemetryScope.CorrelationId)
                    Write-Host -ForegroundColor Red "$($telemetryScope.Name) failure, Correlation Id: $($telemetryScope.CorrelationId)"
                    #Get-Content -Path (Join-Path $env:TEMP $telemetryScope.CorrelationId) | Out-Host
                    Remove-Item -Path (Join-Path $env:TEMP $telemetryScope.CorrelationId)
    
                }
                catch {}
            }
            $telemetry.Client.TrackException($exception, $telemetryScope.Properties)
            $telemetryScope.Emitted = $true
        }
    }
}
