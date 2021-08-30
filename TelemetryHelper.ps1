function FormatValue {
    Param(
        $value
    )

    if ($value -eq $null) {
        "[null]"
    }
    elseif ($value -is [switch]) {
        $value.IsPresent
    }
    elseif ($value -is [boolean]) {
        $value
    }
    elseif ($value -is [SecureString]) {
        "[SecureString]"
    }
    elseif ($value -is [PSCredential]) {
        "[PSCredential]"
    }
    elseif ($value -is [string]) {
        if (($value -like "https:*" -or $value -like "http:*") -and ($value.Contains('?'))) {
            "$($value.Split('?')[0])?[parameters]"
        }
        else {
            "$value"
        }
    }
    elseif ($value -is [System.Collections.IDictionary]) {
        $arr = @($value.GetEnumerator() | ForEach-Object { $_ })
        $str = "{"
        $arr | ForEach-Object {
            $str += "`n  $($_.Key): $(FormatValue -value $_.Value)"
        }
        "$str`n}"
    }
    elseif ($value -is [System.Collections.IEnumerable]) {
        $arr = @($value.GetEnumerator() | ForEach-Object { $_ })
        if ($arr.Count -gt 1) { $str = "[" } else { $str = "" }
        $arr | ForEach-Object {
            if ($arr.Count -gt 1) { $str += "`n  " }
            $str += "$(FormatValue -value $_)"
        }
        if ($arr.Count -gt 1) { "$str`n]" } else { $str }
    }
    else {
        $value
    }
}

function AddTelemetryProperty {
    Param(
        $telemetryScope,
        $key,
        $value
    )

    if ($telemetryScope) {
        $value = FormatValue -value $value
        if ($telemetry.Debug) {
            Write-Host -ForegroundColor Yellow "Telemetry scope $($telemetryScope.Name), add property $key = '$value', type = $($value.GetType())"
        }
        if ($telemetryScope.properties.ContainsKey($Key)) {
            $telemetryScope.properties."$key" += "`n$value"
        }
        else {
            $telemetryScope.properties.Add($key, $value)
        }
    }
}

function InitTelemetryScope {
    Param(
        [string] $name,
        [switch] $always,
        [string[]] $includeParameters = @(),
        $parameterValues = $null
    )
    $includeParameters = "*"
    if ($telemetry.Client) {
        if ($bcContainerHelperConfig.TelemetryConnectionString) {
            if ($telemetry.Client.TelemetryConfiguration.DisableTelemetry -or $telemetry.Client.TelemetryConfiguration.ConnectionString -ne $bcContainerHelperConfig.TelemetryConnectionString) {
                if ($bcContainerHelperConfig.TelemetryConnectionString) {
                    try {
                        $telemetry.Client.TelemetryConfiguration.ConnectionString = $bcContainerHelperConfig.TelemetryConnectionString
                        $telemetry.Client.TelemetryConfiguration.DisableTelemetry = $false
                        if ($telemetry.Debug) {
                            Write-Host -ForegroundColor Yellow "Telemetry client initialized"
                        }
                    }
                    catch {
                        $telemetry.Client.TelemetryConfiguration.DisableTelemetry = $true
                    }
                }
            }
            if ($telemetry.Client.IsEnabled() -and ($always -or ($telemetry.CorrelationId -eq ""))) {
                $CorrelationId = [GUID]::NewGuid().ToString()
                Start-Transcript -Path (Join-Path $env:TEMP $CorrelationId) | Out-Null
                if ($telemetry.Debug) {
                    Write-Host -ForegroundColor Yellow "Init telemetry scope $name"
                }
                if ($telemetry.TopId -eq "") { $telemetry.TopId = $CorrelationId }
                $scope = @{
                    "Name" = $name
                    "StartTime" = [DateTime]::Now
                    "SeverityLevel" = 1
                    "Properties" = [Collections.Generic.Dictionary[string, string]]::new()
                    "CorrelationId" = $CorrelationId
                    "ParentId" = $telemetry.CorrelationId
                    "TopId" = $telemetry.TopId
                    "Emitted" = $false
                }
                $telemetry.CorrelationId = $CorrelationId
                if ($includeParameters) {
                    $parameterValues.GetEnumerator() | ForEach-Object {
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
        if ($telemetry.Client.IsEnabled() -and ($telemetryScope.CorrelationId -eq $telemetry.CorrelationId)) {
            if ($telemetry.Debug) {
                Write-Host -ForegroundColor Yellow "Emit telemetry trace, scope $($telemetryScope.Name)"
            }
            $telemetry.CorrelationId = $telemetryScope.ParentId
            if ($telemetry.CorrelationId -eq "") {
                $telemetry.TopId = ""
            }
            $telemetryScope.Emitted = $true
            try {
                Stop-Transcript | Out-Null
                $transcript = (@(Get-Content -Path (Join-Path $env:TEMP $telemetryScope.CorrelationId)) | select -skip 18 | select -skiplast 4) -join "`n"
                if ($transcript.Length -gt 32000) {
                    $transcript = "$($transcript.SubString(0,16000))`n`n...`n`n$($transcript.SubString($transcript.Length-16000))"
                }
                Remove-Item -Path (Join-Path $env:TEMP $telemetryScope.CorrelationId)
            }
            catch {
                $transcript = ""
            }
            $telemetryScope.Properties.Add("Duration", [DateTime]::Now.Subtract($telemetryScope.StartTime).TotalSeconds)

            $traceTelemetry = $telemetry.Client.GetType().Assembly.CreateInstance('Microsoft.ApplicationInsights.DataContracts.TraceTelemetry')
            $traceTelemetry.Message = "$($telemetryScope.Name)`n$transcript"
            $traceTelemetry.SeverityLevel = $telemetryScope.SeverityLevel
            $telemetryScope.Properties.GetEnumerator() | ForEach-Object { 
                [void]$traceTelemetry.Properties.TryAdd($_.Key, $_.Value)
            }
            $traceTelemetry.Context.Operation.Name = $telemetryScope.Name
            $traceTelemetry.Context.Operation.Id = $telemetryScope.CorrelationId
            $traceTelemetry.Context.Operation.ParentId = $telemetryScope.ParentId
            $telemetry.Client.TrackTrace($traceTelemetry)
            $telemetry.Client.Flush()
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
        if ($telemetry.Client.IsEnabled() -and ($telemetryScope.CorrelationId -eq $telemetry.CorrelationId)) {
            if ($telemetry.Debug) {
                Write-Host -ForegroundColor Yellow "Emit telemetry exception, scope $($telemetryScope.Name)"
            }
            $telemetry.CorrelationId = $telemetryScope.ParentId
            if ($telemetry.CorrelationId -eq "") {
                $telemetry.TopId = ""
            }
            $telemetryScope.Emitted = $true

            try {
                Stop-Transcript | Out-Null
                $transcript = (@(Get-Content -Path (Join-Path $env:TEMP $telemetryScope.CorrelationId)) | select -skip 18 | select -skiplast 4) -join "`n"
                if ($transcript.Length -gt 32000) {
                    $transcript = "$($transcript.SubString(0,16000))`n`n...`n`n$($transcript.SubString($transcript.Length-16000))"
                }
                Remove-Item -Path (Join-Path $env:TEMP $telemetryScope.CorrelationId)
            }
            catch {
                $transcript = ""
            }
            $telemetryScope.Properties.Add("Duration", [DateTime]::Now.Subtract($telemetryScope.StartTime).TotalSeconds)
            if ($scriptStackTrace) {
                $telemetryScope.Properties.Add("Error StackTrace", $scriptStackTrace)
            }
            if ($exception) {
                $telemetryScope.Properties.Add("Error Message", $exception.Message)
            }

            # emit trace telemetry with Error info
            $traceTelemetry = $telemetry.Client.GetType().Assembly.CreateInstance('Microsoft.ApplicationInsights.DataContracts.TraceTelemetry')
            $traceTelemetry.Message = "$($telemetryScope.Name)`n$transcript"
            $traceTelemetry.SeverityLevel = $telemetryScope.SeverityLevel
            $telemetryScope.Properties.GetEnumerator() | ForEach-Object { 
                [void]$traceTelemetry.Properties.TryAdd($_.Key, $_.Value)
            }
            $traceTelemetry.Context.Operation.Name = $telemetryScope.Name
            $traceTelemetry.Context.Operation.Id = $telemetryScope.CorrelationId
            $traceTelemetry.Context.Operation.ParentId = $telemetryScope.ParentId
            $telemetry.Client.TrackTrace($traceTelemetry)

            # emit exception telemetry
            $exceptionTelemetry = $telemetry.Client.GetType().Assembly.CreateInstance('Microsoft.ApplicationInsights.DataContracts.ExceptionTelemetry')
            $exceptionTelemetry.Message = "$($telemetryScope.Name)`n$transcript"
            $exceptionTelemetry.SeverityLevel = $telemetryScope.SeverityLevel
            $telemetryScope.Properties.GetEnumerator() | ForEach-Object { 
                [void]$exceptionTelemetry.Properties.TryAdd($_.Key, $_.Value)
            }
            $exceptionTelemetry.Context.Operation.Name = $telemetryScope.Name
            $exceptionTelemetry.Context.Operation.Id = $telemetryScope.CorrelationId
            $exceptionTelemetry.Context.Operation.ParentId = $telemetryScope.ParentId
            $telemetry.Client.TrackException($exceptionTelemetry)
            $telemetry.Client.Flush()
        }
    }
}
