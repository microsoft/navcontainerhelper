$eventIds = @{
    "New-BcContainer"                                 = "DO0001"
    "New-BcImage"                                     = "DO0002"
    "Compile-AppInBcContainer"                        = "DO0003"
    "Publish-BcContainerApp"                          = "DO0004"
    "Run-AlCops"                                      = "DO0005"
    "Run-AlValidation"                                = "DO0006"
    "Run-AlPipeline"                                  = "DO0007"
    "Run-TestsInBcContainer"                          = "DO0008"
    "Sign-BcContainerApp"                             = "DO0009"
    "Publish-PerTenantExtensionApps"                  = "DO0010"
    "Install-BcAppFromAppSource"                      = "DO0011"
    "New-BcEnvironment"                               = "DO0012"
    "New-BcDatabaseExport"                            = "DO0013"
    "Remove-BcEnvironment"                            = "DO0014"
    "Download-Artifacts"                              = "DO0015"
    "New-CompanyInNavContainer"                       = "DO0016"
    "Import-TestToolkitToBcContainer"                 = "DO0017"
    "UploadImportAndApply-ConfigPackageInBcContainer" = "DO0018"
    "New-AppSourceSubmission"                         = "DO0019"
    "Promote-AppSourceSubmission"                     = "DO0020"
}

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
            if ($_.Key -eq "RefreshToken" -or $_.Key -eq "AccessToken") {
                if ($_.Value) {
                    $str += "`n  $($_.Key): [token]"
                }
                else {
                    $str += "`n  $($_.Key): [null]"
                }
            }
            else {
                $str += "`n  $($_.Key): $(FormatValue -value $_.Value)"
            }
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

function InitTelemetryClients {
    Param()

    "Microsoft","Partner" | ForEach-Object {
        $clientName = "$($_)Client"
        $telemetryConnectionString = $bcContainerHelperConfig."$($_)TelemetryConnectionString"
        if ($telemetryConnectionString -and $telemetry.Assembly -ne $null) {
            if ($telemetry."$clientName" -eq $null -or $telemetry."$ClientName".TelemetryConfiguration.ConnectionString -ne $telemetryConnectionString) {
                try {
                    $telemetryConfiguration = $telemetry.Assembly.CreateInstance('Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration')
                    $telemetryConfiguration.Connectionstring = $telemetryConnectionString
                    $telemetry."$clientName" = $telemetry.Assembly.CreateInstance('Microsoft.ApplicationInsights.TelemetryClient', $false, 0, $null, $telemetryConfiguration, $null, $null)
                }
                catch {
                    $telemetry."$clientName" = $null
                }
            }
        }
        else {
            $telemetry."$clientName" = $null
        }
    }
}

function RegisterTelemetryScope {
    Param(
        [string] $telemetryScopeJson
    )

    InitTelemetryClients

    $telemetryScope = $telemetryScopeJson | ConvertFrom-Json
    if ($telemetry.TopId -eq "") { 
        $telemetry.TopId = $telemetryScope.CorrelationId
    }

    $scope = @{
        "Name" = $telemetryScope.Name
        "EventId" = $telemetryScope.eventId
        "StartTime" = $telemetryScope.StartTime
        "Properties" = [Collections.Generic.Dictionary[string, string]]::new()
        "Parameters" = [Collections.Generic.Dictionary[string, string]]::new()
        "AllParameters" = [Collections.Generic.Dictionary[string, string]]::new()
        "CorrelationId" = $telemetryScope.CorrelationId
        "ParentId" = $telemetryScope.CorrelationId
        "TopId" = $telemetry.TopId
        "Emitted" = $telemetryScope.Emitted
    }

    "Properties","Parameters","AllParameters" | ForEach-Object {
        $prop = $_
        $telemetryScope."$prop".PSObject.Properties.GetEnumerator() | ForEach-Object { $scope."$prop".Add($_.Name, $_.Value) }
    }

    $telemetry.CorrelationId = $telemetryScope.CorrelationId
    $scope
}

function InitTelemetryScope {
    Param(
        [string] $name,
        [string[]] $includeParameters = @(),
        $parameterValues = $null,
        [string] $eventId = ""
    )
    
    InitTelemetryClients

    if ($telemetry.MicrosoftClient -ne $null -or $telemetry.PartnerClient -ne $null) {
        if ($eventId -eq "" -and ($eventIds.ContainsKey($name))) {
            $eventId = $eventIds[$name]
        }
        if (($eventId -ne "") -or ($telemetry.CorrelationId -eq "")) {
            $CorrelationId = [GUID]::NewGuid().ToString()
            Start-Transcript -Path (Join-Path ([System.IO.Path]::GetTempPath()) $CorrelationId) | Out-Null
            if ($telemetry.Debug) {
                Write-Host -ForegroundColor Yellow "Init telemetry scope $name"
            }
            if ($telemetry.TopId -eq "") { 
                $telemetry.TopId = $CorrelationId
            }
            $scope = @{
                "Name" = $name
                "EventId" = $eventId
                "StartTime" = [DateTime]::Now
                "Properties" = [Collections.Generic.Dictionary[string, string]]::new()
                "Parameters" = [Collections.Generic.Dictionary[string, string]]::new()
                "AllParameters" = [Collections.Generic.Dictionary[string, string]]::new()
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
                    $value = FormatValue -value $_.value
                    $scope.allParameters.Add($key, $value)
                    $includeParameters | ForEach-Object { if ($key -like $_) { $includeParameter = $true } }
                    if ($includeParameter) {
                        $scope.parameters.Add($key, $value)
                    }
                }
            }
            AddTelemetryProperty -telemetryScope $scope -key "eventId" -value $eventId
            AddTelemetryProperty -telemetryScope $scope -key "bcContainerHelperVersion" -value $BcContainerHelperVersion
            AddTelemetryProperty -telemetryScope $scope -key "isAdministrator" -value $isAdministrator
            AddTelemetryProperty -telemetryScope $scope -key "stackTrace" -value (Get-PSCallStack | % { "$($_.Command) at $($_.Location)" }) -join "`n"
            $scope
        }
    }
}

function TrackTrace {
    Param(
        $telemetryScope
    )

    if ($telemetryScope -and !$telemetryScope.Emitted) {
        if ($telemetryScope.CorrelationId -eq $telemetry.CorrelationId) {
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
                $transcript = (@(Get-Content -Path (Join-Path ([System.IO.Path]::GetTempPath()) $telemetryScope.CorrelationId)) | select -skip 18 | select -skiplast 4 | Where-Object { -not "$_".StartsWith("::add-mask::") }) -join "`n"
                if ($transcript.Length -gt 32000) {
                    $transcript = "$($transcript.SubString(0,16000))`n`n...`n`n$($transcript.SubString($transcript.Length-16000))"
                }
                Remove-Item -Path (Join-Path ([System.IO.Path]::GetTempPath()) $telemetryScope.CorrelationId)
            }
            catch {
                $transcript = ""
            }
            $telemetryScope.Properties.Add("duration", [DateTime]::Now.Subtract($telemetryScope.StartTime).TotalSeconds)

            if ($telemetry.Assembly -ne $null) {
                try {
                    $printCorrelationId = $telemetry.Debug
                    "Microsoft","Partner" | ForEach-Object {
                        $clientName = "$($_)Client"
                        $extendedTelemetry = $bcContainerHelperConfig.SendExtendedTelemetryToMicrosoft -or $_ -eq "Partner"
                        if ($telemetry."$clientName") {
                            $traceTelemetry = $telemetry.Assembly.CreateInstance('Microsoft.ApplicationInsights.DataContracts.TraceTelemetry')
                            if ($extendedTelemetry) {
                                $traceTelemetry.Message = "$($telemetryScope.Name)`n$transcript"
                                $traceTelemetry.SeverityLevel = 0
                                $telemetryScope.allParameters.GetEnumerator() | ForEach-Object { 
                                    [void]$traceTelemetry.Properties.TryAdd("parameter[$($_.Key)]", $_.Value)
                                }
                            }
                            else {
                                $traceTelemetry.Message = "$($telemetryScope.Name)"
                                $traceTelemetry.SeverityLevel = 1
                                $telemetryScope.Parameters.GetEnumerator() | ForEach-Object { 
                                    [void]$traceTelemetry.Properties.TryAdd("parameter[$($_.Key)]", $_.Value)
                                }
                            }
                            $telemetryScope.Properties.GetEnumerator() | ForEach-Object { 
                                [void]$traceTelemetry.Properties.TryAdd($_.Key, $_.Value)
                            }
                            $traceTelemetry.Context.Operation.Name = $telemetryScope.Name
                            $traceTelemetry.Context.Operation.Id = $telemetryScope.CorrelationId
                            $traceTelemetry.Context.Operation.ParentId = $telemetryScope.ParentId
                            $telemetry."$clientName".TrackTrace($traceTelemetry)
                            $telemetry."$clientName".Flush()
                            if ($extendedTelemetry) { $printCorrelationId = $true }
                            if ($telemetry.Debug) { 
                                Write-Host "$_ telemetry emitted"
                            }
                        }
                    }
                    if ($printCorrelationId) {
                        Write-Host "$($telemetryScope.Name) Telemetry Correlation Id: $($telemetryScope.CorrelationId)"
                    }
                }
                catch {
                    Write-Host -ForegroundColor Red "Error emitting telemetry."
                    Write-Host -ForegroundColor Red "This might be caused by and old version of dotnet, you need at least dotnet 6.0."
                    Write-Host -ForegroundColor Red "Please upgrade dotnet here: https://dotnet.microsoft.com/en-us/download/dotnet/6.0"
                }
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
        if ($telemetryScope.CorrelationId -eq $telemetry.CorrelationId) {
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
                $transcript = (@(Get-Content -Path (Join-Path ([System.IO.Path]::GetTempPath()) $telemetryScope.CorrelationId)) | select -skip 18 | select -skiplast 4 | Where-Object { -not "$_".StartsWith("::add-mask::") }) -join "`n"
                if ($transcript.Length -gt 32000) {
                    $transcript = "$($transcript.SubString(0,16000))`n`n...`n`n$($transcript.SubString($transcript.Length-16000))"
                }
                Remove-Item -Path (Join-Path ([System.IO.Path]::GetTempPath()) $telemetryScope.CorrelationId)
            }
            catch {
                $transcript = ""
            }
            $telemetryScope.Properties.Add("duration", [DateTime]::Now.Subtract($telemetryScope.StartTime).TotalSeconds)
            if ($scriptStackTrace) {
                $telemetryScope.Properties.Add("errorStackTrace", $scriptStackTrace)
            }
            if ($exception) {
                $telemetryScope.Properties.Add("errorMessage", $exception.Message)
            }

            if ($telemetry.Assembly -ne $null) {
                try {
                    "Microsoft","Partner" | ForEach-Object {
                        $clientName = "$($_)Client"
                        $extendedTelemetry = $bcContainerHelperConfig.SendExtendedTelemetryToMicrosoft -or $_ -eq "Partner"
                        if ($telemetry."$clientName") {
                            $traceTelemetry = $telemetry.Assembly.CreateInstance('Microsoft.ApplicationInsights.DataContracts.TraceTelemetry')
                            if ($extendedTelemetry) {
                                $traceTelemetry.Message = "$($telemetryScope.Name)`n$transcript"
                                $traceTelemetry.SeverityLevel = 0
                                $telemetryScope.allParameters.GetEnumerator() | ForEach-Object { 
                                    [void]$traceTelemetry.Properties.TryAdd("parameter[$($_.Key)]", $_.Value)
                                }
                            }
                            else {
                                $traceTelemetry.Message = "$($telemetryScope.Name)"
                                $traceTelemetry.SeverityLevel = 1
                                $telemetryScope.Parameters.GetEnumerator() | ForEach-Object { 
                                    [void]$traceTelemetry.Properties.TryAdd("parameter[$($_.Key)]", $_.Value)
                                }
                            }
                            $telemetryScope.Properties.GetEnumerator() | ForEach-Object { 
                                [void]$traceTelemetry.Properties.TryAdd($_.Key, $_.Value)
                            }
                            $traceTelemetry.Context.Operation.Name = $telemetryScope.Name
                            $traceTelemetry.Context.Operation.Id = $telemetryScope.CorrelationId
                            $traceTelemetry.Context.Operation.ParentId = $telemetryScope.ParentId
                            $telemetry."$clientName".TrackTrace($traceTelemetry)
                        
                            # emit exception telemetry
                            $exceptionTelemetry = $telemetry.Assembly.CreateInstance('Microsoft.ApplicationInsights.DataContracts.ExceptionTelemetry')
                            if ($extendedTelemetry) {
                                $exceptionTelemetry.Message = "$($telemetryScope.Name)`n$transcript"
                                $exceptionTelemetry.SeverityLevel = 3
                                $telemetryScope.allParameters.GetEnumerator() | ForEach-Object { 
                                    [void]$exceptionTelemetry.Properties.TryAdd("parameter[$($_.Key)]", $_.Value)
                                }
                            }
                            else {
                                $exceptionTelemetry.Message = "$($telemetryScope.Name)"
                                $exceptionTelemetry.SeverityLevel = 1
                                $telemetryScope.Parameters.GetEnumerator() | ForEach-Object { 
                                    [void]$exceptionTelemetry.Properties.TryAdd("parameter[$($_.Key)]", $_.Value)
                                }
                            }
                            $telemetryScope.Properties.GetEnumerator() | ForEach-Object { 
                                [void]$exceptionTelemetry.Properties.TryAdd($_.Key, $_.Value)
                            }
                            $exceptionTelemetry.Context.Operation.Name = $telemetryScope.Name
                            $exceptionTelemetry.Context.Operation.Id = $telemetryScope.CorrelationId
                            $exceptionTelemetry.Context.Operation.ParentId = $telemetryScope.ParentId
                            $telemetry."$clientName".TrackException($exceptionTelemetry)
                            $telemetry."$clientName".Flush()
                        }
                    }
                    Write-Host "$($telemetryScope.Name) Telemetry Correlation Id: $($telemetryScope.CorrelationId)"
                }
                catch {
                    Write-Host -ForegroundColor Red "Error emitting telemetry."
                    Write-Host -ForegroundColor Red "This might be caused by and old version of dotnet, you need at least dotnet 6.0."
                    Write-Host -ForegroundColor Red "Please upgrade dotnet here: https://dotnet.microsoft.com/en-us/download/dotnet/6.0"
                }
            }
        }
    }
}
