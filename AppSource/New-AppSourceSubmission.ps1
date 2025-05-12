<#
 .Synopsis
  Create a new AppSource submission (submit a new version of your app for validation)
 .Description
  Returns a PSCustomObject with submission details
 .Parameter authContext
  Authentication Context from New-BcAuthContext
 .Parameter productId
  Id of the product for which you want to create a new submission
 .Parameter appFile
  Path of the main app File
 .Parameter libraryAppFiles
  An array of app files to be included as library app files. If this array consists of a single file, it will be uploaded as-is - if multiple files are provided, they will be zipped together and uploaded
 .Parameter autoPromote
  Include this switch if you want to automatically promote the submission to production / Go Live after validation/preview
 .Parameter doNotWait
  Include this switch if you do not want to wait for the submission to pass or fail (note that if you include autoPromote, the function will wait for first part of validation)
 .Parameter force
  If another submission is in progress, it will be cancelled if you include the force switch
 .Parameter silent
  Include this switch if you do not want the method to display URLs etc.
 .Parameter doNotCheckVersionNumber
  Include this switch avoid checking whether the new version number is greater than the existing version number in Partner Center
 .Parameter doNotUpdateVersionNumber
  Include this switch when you do not want to change the version number of the product in Partner Center (can be used for hotfixes) 
 .Example
  New-AppSourceSubmission -authContext $authContext -productId $product.Id -appFile $appFile
 .Example
  New-AppSourceSubmission -authContext $authContext -productId $product.Id -appFile $appFile -libraryAppFiles @($libraryApp1,$libraryApp2) -autoPromote -doNotWait -silent
#>
function New-AppSourceSubmission {
    Param(
        [Parameter(Mandatory=$true)]
        [HashTable] $authContext,
        [Parameter(Mandatory=$true)]
        [string] $productId,
        [Parameter(Mandatory=$false)]
        [string] $appFile = "",
        [Parameter(Mandatory=$false)]
        [string[]] $libraryAppFiles = @(),
        [switch] $autoPromote,
        [switch] $doNotWait,
        [switch] $force,
        [switch] $silent,
        [Obsolete("doNotCheckVersionNumber is obsolete, please use doNotUpdateVersionNumber instead")]
        [switch] $doNotCheckVersionNumber,
        [switch] $doNotUpdateVersionNumber
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {
    $authContext = Renew-BcAuthContext -bcAuthContext $authContext
    if ($telemetryScope) {
        if ($authContext.ClientID) {
            AddTelemetryProperty -telemetryScope $telemetryScope -key "client" -value (GetHash -str $authContext.ClientID)
        }
        AddTelemetryProperty -telemetryScope $telemetryScope -key "product" -value (GetHash -str $productId)
        AddTelemetryProperty -telemetryScope $telemetryScope -key "autoPromote" -value "$autoPromote"
    }
    
    $product = Get-AppSourceProduct -authContext $authContext -productId $productId -silent:($silent.IsPresent) -includeSetup
    if ($product) {
        if ($product.Setup.packageType -eq "Connect") {
            throw "Product $($product.Name) is a Connect App, you cannot submit an app to a Connect app"
        }
    }
    else {
        throw "No product found with ProductID=$productID with this account"
    }

    $submission = Get-AppSourceSubmission -authContext $authContext -productId $productId -silent:($silent.IsPresent)
    if ($submission) {
        if ($submission.state -eq "InProgress") {
            if ($submission.substate -eq "Failed") {
                # ignore
            }
            elseif ($force) {
                Cancel-AppSourceSubmission -authContext $authContext -productId $productId -submissionId $submission.id -silent:($silent.IsPresent)
            }
            else {
                throw "An AppSource submission is in progress. If you want to cancel an in progress submission, you need to add -force"
            }
        }
        elseif (!($submission.state -eq "Published" -and ($submission.substate -eq "ReadyToPublish" -or $submission.substate -eq "InStore"))) {
            throw "An AppSource submission already running. You cannot create a new submission, when an existing submission is in substate=$($submission.substate)"
        }
    }

    $variantID = ''
    $branchesPackage = @(Invoke-IngestionApiGetCollection -authContext $authContext -path "/products/$productId/branches/getByModule(module=Package)" -silent:($silent.IsPresent) | Where-Object { 
        $thisVariantID = ''
        if ($_.PSObject.Properties.name -eq "variantID") { $thisVariantID = $_.variantID }
        $variantID -eq $thisVariantID
    })
    if ($branchesPackage.Count -ne 1) {
        throw "Unable to locate package from Ingestion API"
    }
    $packageCurrentDraftInstanceID = $branchesPackage[0].currentDraftInstanceID
    
    $appVersionNumber = ""
    if ($appFile) {
        $appJson = Get-AppJsonFromAppFile -appFile $appFile
        $appVersionNumber = [System.Version]$appJson.version
    }

    $tempFolder = ""
    $libraryAppFile = ""
    if ($libraryAppFiles -and ($libraryAppFiles.Count -gt 0)) {
        if ($libraryAppFiles.Count -eq 1) {
            $libraryAppFile = $libraryAppFiles[0]
        }
        else {
            $tempFolder = Join-Path ([System.IO.Path]::GetTempPath()) ([GUID]::NewGuid().ToString())
            New-Item -Path $tempFolder -ItemType Directory | Out-Null
            $libraryAppFile = Join-Path $tempFolder "$([System.IO.Path]::GetFileNameWithoutExtension($appFile)).libraries.zip"
            Compress-Archive -Path $libraryAppFiles -DestinationPath $libraryAppFile -CompressionLevel Fastest
        }
    }
    
    $packageConfigurations = @(Invoke-IngestionApiGetCollection -authContext $authContext -path "/products/$productId/packageConfigurations/getByInstanceID(instanceID=$($packageCurrentDraftInstanceID))" -silent:($silent.IsPresent))
    if ($packageConfigurations.Count -ne 1) {
        $packageConfigurations | fl | Out-Host
        throw "unable to locate package configuration"
    }
    $packageConfiguration = $packageConfigurations[0]

    0..1 | ForEach-Object {
        if ($_ -eq 0) {
            $parameterName = 'AppFile'
            $file = $appFile
            $resourceType = "Dynamics365BusinessCentralAddOnExtensionPackage"
        }
        else {
            $parameterName = 'LibraryAppFiles'
            $file = $libraryAppFile
            $resourceType = "Dynamics365BusinessCentralAddOnLibraryExtensionPackage"
        }
        if ($PSBoundParameters.ContainsKey($parameterName)) {
            $packageConfiguration.packageReferences = @($packageConfiguration.packageReferences | Where-Object { $_.type -ne $resourceType })
        }
        if ($file) {
            $body = @{
                "resourceType" = $resourceType
                "fileName" = [System.IO.Path]::GetFileName($file)
            }
            $packageUpload = Invoke-IngestionApiPost -authContext $authContext -path "/products/$productId/packages" -Body $body -silent:($silent.IsPresent)
        
            $uri = [System.Uri] $packageUpload.fileSasUri
            $storageAccountName = $uri.DnsSafeHost.Split(".")[0]
            $container = $uri.LocalPath.Substring(1).split('/')[0]
            $blobname = $uri.LocalPath.Substring(1).split('/')[1]
            $sasToken = $uri.Query

            if (!(get-command New-AzureStorageContext -ErrorAction SilentlyContinue)) {
                Set-Alias -Name New-AzureStorageContext -Value New-AzStorageContext
                Set-Alias -Name Set-AzureStorageBlobContent -Value Set-AzStorageBlobContent
            }

            $storageContext = New-AzureStorageContext -StorageAccountName $storageAccountName -SasToken $sasToken
            Set-AzureStorageBlobContent -File $file -Container $container -Blob $blobname -Context $storageContext -Force | Out-Null
        
            $packageUpload.state = "Uploaded"
            $packageUploaded = Invoke-IngestionApiPut -authContext $authContext -path "/products/$productId/packages/$($packageUpload.id)" -Body ($packageUpload | ConvertTo-HashTable) -silent:($silent.IsPresent)
            if ($packageUploaded.state -ne "Processed") {
                throw "Could not process package"
            }

            $packageConfiguration.packageReferences += @([PSCustomObject]@{
                "type" = $resourceType
                "value" = $packageUploaded.id
            })
        }
    }
    if ($tempFolder -and (Test-Path $tempFolder -PathType Container)) {
        Remove-Item $tempFolder -Recurse -Force
    }

    $result = Invoke-IngestionApiPut -authContext $authContext -path "/products/$productId/packageConfigurations/$($packageConfiguration.id)" -Body ($packageConfiguration | ConvertTo-HashTable -recurse) -silent:($silent.IsPresent)
    
    $body = [ordered]@{
        "resourceType" = "SubmissionCreationRequest"
        "targets" = @(
            [ordered]@{
                "type" = "Scope"
                "value" = "preview"
            }
        )
        "resources" = @(
            [ordered]@{
                "type" = "Package"
                "value" = $packageCurrentDraftInstanceID
            }
        )
    }
    if ($appVersionNumber -and !$doNotUpdateVersionNumber) {
        $branchesProperty = @(Invoke-IngestionApiGetCollection -authContext $authContext -path "/products/$productId/branches/getByModule(module=Property)" -silent:($silent.IsPresent) | Where-Object { 
            $thisVariantID = ''
            if ($_.PSObject.Properties.name -eq "variantID") { $thisVariantID = $_.variantID }
            $variantID -eq $thisVariantID
        })
        if ($branchesProperty.Count -ne 1) {
            throw "Unable to locate properties from Ingestion API"
        }
        $propertyCurrentDraftInstanceID = $branchesProperty[0].currentDraftInstanceID

        $properties = @(Invoke-IngestionApiGetCollection -authContext $authContext -path "/products/$productId/properties/getByInstanceID(instanceID=$propertyCurrentDraftInstanceID)" -silent:($silent.IsPresent))
        if ($properties.Count -ne 1) {
            $properties | fl | Out-Host
            throw "unable to locate properties"
        }
        $property = $properties[0]
        if (!$doNotCheckVersionNumber) {
            $prevVersion = [System.Version]"0.0.0.0"
            if ([System.Version]::TryParse($property.appVersion, [ref] $prevVersion)) {
                if ($prevVersion -gt $appVersionNumber) {
                    # This error message is used in the Federated credentials test in AL-Go for GitHub to determine the next version number for a submission
                    throw "The new version number ($appVersionNumber) is lower than the existing version number ($prevVersion) in Partner Center"
                }
            }
        }
        $property.appVersion = $appVersionNumber.ToString()
        $result = Invoke-IngestionApiPut -authContext $authContext -path "/products/$productId/properties/$($property.id)" -Body ($property | ConvertTo-HashTable -recurse) -silent:($silent.IsPresent)
        $body.resources += @(
            [ordered]@{
                "type" = "Property"
                "value" = $propertyCurrentDraftInstanceID
            }
        )
    }
    
    $submission = Invoke-IngestionApiPost -authContext $authContext -path "/products/$productId/submissions" -Body $body -silent:($silent.IsPresent)
    
    if ($doNotWait.IsPresent -and !$autoPromote.IsPresent) {
        Write-Host -ForegroundColor Green "New AppSource submission created"
        $submission
    }
    else {
        $jobs = @{
            "Automated validation" = "NotStarted"
            "Preview Creation" = "NotStarted"
            "Publisher Signoff" = "NotStarted"
            "Certification" = "NotStarted"
            "Publish" = "NotStarted"
        }
        $promoted = $false
        $lastName = ""
        do {
            Start-Sleep -Seconds 30
            $authContext = Renew-BcAuthContext -bcAuthContext $authContext -silent

            $complete = $false
            $failed = $false
            $status = @(Invoke-IngestionApiGetCollection -authContext $authContext -path "/products/$productId/submissions/$($submission.id)/workflowdetails" -silent)
            if ($status.Count -ne 2) {
                $status | fl | Out-Host
                throw "Unexpected error when trying to get status for submission. Please consult Partner Center UI."
            }
            0..1 | ForEach-Object {
                $st = $status[$_]
                $st.workflowSteps | ForEach-Object {
                    if ($jobs."$($_.Name)" -eq $_.State) {
                        if ($_.state -eq "InProgress") {
                            Write-Host -NoNewline '.'
                        }
                        elseif ($_.state -eq "NotStarted") {
                        }
                    }
                    else {
                        if ($jobs."$($_.Name)" -eq "NotStarted") {
                            Write-Host -NoNewline $_.Name
                        }
                        if ($_.State -eq "Success") {
                            Write-Host -ForegroundColor Green ' Success'
                        }
                        elseif ($_.state -eq "InProgress") {
                            Write-Host -NoNewline '.'
                        }
                        else {
                            Write-Host -ForegroundColor Red ' Failure'
                            $failed = $true
                        }
                        $jobs."$($_.Name)" = $_.State
                    }
                }
            }
            $sm = Invoke-IngestionApiGet -authContext $authContext -path "/products/$productId/submissions/$($submission.id)" -silent
            if ($sm.state -eq "Published" -and $sm.substate -eq "ReadyToPublish") {
                if ($autoPromote.IsPresent) {
                    if (!$promoted) {
                        Promote-AppSourceSubmission -authContext $authContext -productId $productId -submissionId $submission.id -silent:($silent.IsPresent) | Out-Null
                        $promoted = $true
                        if ($doNotWait.IsPresent) {
                            $complete = $true
                        }
                    }
                }
                else {
                    $complete = $true
                }
            }
            elseif ($sm.state -eq "Published" -and $sm.substate -eq "InStore") {
                $complete = $true
            }
        } while (!$complete -and !$failed)
        
        if ($failed) {
            Write-Host -ForegroundColor Red "New AppSource submission failed"
        }
        else {
            Write-Host -ForegroundColor Green "New AppSource submission succeeded"
        }
        $sm
    }
}
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    TrackTrace -telemetryScope $telemetryScope
}
}
Export-ModuleMember -Function New-AppSourceSubmission