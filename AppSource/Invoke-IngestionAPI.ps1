function Invoke-IngestionApiRestMethod {
    Param(
        [Parameter(Mandatory=$true)]
        [HashTable] $authContext,
        [Parameter(Mandatory=$false)]
        [HashTable] $headers = @{},
        [string] $method = "GET",
        [Parameter(Mandatory=$true)]
        [string] $path,
        [Parameter(Mandatory=$false)]
        [string] $query = '',
        [Parameter(Mandatory=$false)]
        [string] $body = '',
        [switch] $silent
    )

    $authContext = Renew-BcAuthContext -bcAuthContext $authContext
    $headers += @{
        "Authorization" = "Bearer $($authcontext.AccessToken)"
        "Content-Type" = "application/json"
    }
    $uriBuilder = [UriBuilder]::new("https://api.partner.microsoft.com/v1.0/ingestion$path")
    if (!$silent) {
        Write-Host "$method $($UriBuilder.Uri.ToString())"
    }
    if ($query) {
        $uriBuilder.Query = $query
    }
    $parameters = @{
        "useBasicParsing" = $true
        "method" = $method
        "uri" = $UriBuilder.Uri.ToString()
        "headers" = $headers
    }
    if ($PSBoundParameters.ContainsKey('body')) {
        if (!$silent) {
            $body | Out-Host
        }
        $parameters += @{
            "body" = $body
        }
    }
    $waitTime = 1
    $retries = 5
    $success = $false
    do {
        try {
            Invoke-RestMethod @parameters
            $success = $true
        }
        catch {
            $statusCode = 0
            try {
                $errorDetails = $_.ErrorDetails | ConvertFrom-Json
                $statusCode = $errorDetails.statusCode
            }
            catch {}
            if ($retries -gt 0 -and $statusCode -eq 500) {
                $retries--
                Write-Host "$(GetExtendedErrorMessage $_)".TrimEnd()
                Write-Host "...retrying in $waittime minute(s)"
                Start-Sleep -Seconds ($waitTime*60)
                $waitTime = $waitTime * 2
            }
            else {
                throw (GetExtendedErrorMessage $_)
            }
        }
    } while (!$success)
}

<#
 .Synopsis
  Invoke a HTTP GET to receive a collection of objects from the Ingestion API
  This function handles paging and always returns the full array
 .Description
  Returns an array of PSCustomObjects with properties from the Objects received
 .Parameter authContext
  Authentication Context from New-BcAuthContext
 .Parameter path
  Ingestion API path as described on Swagger doc (https://ingestionapi-swagger.azureedge.net/)
 .Parameter headers
  Optional. Hashtable with additional headers for the request
 .Parameter query
  Optional. Query parameters for the invoke
 .Parameter silent
  Include this switch if you do not want the method to display URLs etc.
 .Example
  @(Invoke-IngestionApiGetCollection -authContext $authContext -path "/products")
  GET https://api.partner.microsoft.com/v1.0/ingestion/products
  
  resourceType        : AzureDynamics365BusinessCentral
  name                : C5 2012 Data Migration
  externalIDs         : {@{type=AzureOfferId; value=c5-2012-data-migration}}
  isModularPublishing : True
  id                  : bc09759f-4d41-4d56-a57a-2f7e4cfad4a2
  
  resourceType        : AzureDynamics365BusinessCentral
  name                : ELSTER VAT Localization for Germany
  externalIDs         : {@{type=AzureOfferId; value=elster-vat-file-de}}
  isModularPublishing : True
  id                  : 29cb661d-ea77-4415-ac43-b0f7a90cd9b5
  
  resourceType        : AzureDynamics365BusinessCentral
  name                : PayPal Payments Standard
  externalIDs         : {@{type=AzureOfferId; value=fb310c16-0b22-4569-a5f0-8f9a01571cee}}
  isModularPublishing : True
  id                  : 193aec22-a99f-4024-8aba-c01ec540c0b7

  ...
#>
function Invoke-IngestionApiGetCollection {
    Param(
        [Parameter(Mandatory=$true)]
        [HashTable] $authContext,
        [Parameter(Mandatory=$true)]
        [string] $path,
        [Parameter(Mandatory=$false)]
        [HashTable] $headers = @{},
        [Parameter(Mandatory=$false)]
        [string] $query = '',
        [switch] $silent
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {
    $nextlink = $path
    while ($nextlink) {

        $ps = Invoke-IngestionApiRestMethod -authContext $authContext -method GET -headers $headers -path $nextlink -query $query -silent:$silent

        if ($ps.PSObject.Properties.Name -eq 'nextlink') {
            $nextlink = $ps.nextlink.SubString("v1.0/ingestion".Length)
        }
        else {
            $nextlink = ""
        }
        if ($ps.value) {
            $ps.value
        }
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

<#
 .Synopsis
  Invoke a HTTP GET to receive a single object from the Ingestion API
 .Description
  Returns a PSCustomObject with properties from the Object received
 .Parameter authContext
  Authentication Context from New-BcAuthContext
 .Parameter path
  Ingestion API path as described on Swagger doc (https://ingestionapi-swagger.azureedge.net/)
 .Parameter headers
  Optional. Hashtable with additional headers for the request
 .Parameter query
  Optional. Query parameters for the invoke
 .Parameter silent
  Include this switch if you do not want the method to display URLs etc.
 .Example
  Invoke-IngestionApiGet -authContext $authContext -path "/products/5fbe0803-a545-4504-b41a-d9d158112360"
  GET https://api.partner.microsoft.com/v1.0/ingestion/products/5fbe0803-a545-4504-b41a-d9d158112360

  resourceType        : AzureDynamics365BusinessCentral
  name                : BingMaps.AppSource
  externalIDs         : {@{type=AzureOfferId; value=bingmapsintegration}}
  isModularPublishing : True
  id                  : 5fbe0803-a545-4504-b41a-d9d158112360
#>
function Invoke-IngestionApiGet {
    Param(
        [Parameter(Mandatory=$true)]
        [HashTable] $authContext,
        [Parameter(Mandatory=$true)]
        [string] $path,
        [Parameter(Mandatory=$false)]
        [HashTable] $headers = @{},
        [Parameter(Mandatory=$false)]
        [string] $query = '',
        [switch] $silent
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {
    Invoke-IngestionApiRestMethod -authContext $authContext -method GET -headers $headers -path $path -query $query -silent:$silent
}
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    TrackTrace -telemetryScope $telemetryScope
}
}

<#
 .Synopsis
  Invoke a HTTP POST to create a new object or run an action in the Ingestion API
 .Description
  Returns a PSCustomObject with properties from the newly created Object received
 .Parameter authContext
  Authentication Context from New-BcAuthContext
 .Parameter path
  Ingestion API path as described on Swagger doc (https://ingestionapi-swagger.azureedge.net/)
 .Parameter body
  Optional. HashTable with properties for the request
 .Parameter headers
  Optional. Hashtable with additional headers for the request
 .Parameter query
  Optional. Query parameters for the invoke
 .Parameter silent
  Include this switch if you do not want the method to display URLs etc.
 .Example
  Invoke-IngestionApiPost -authContext $authContext -path "/products/5fbe0803-a545-4504-b41a-d9d158112360/submissions/123456789/promote"
 .Example
  $packageUpload = Invoke-IngestionApiPost -authContext $authContext -path "/products/$productId/packages" -Body $body
#>
function Invoke-IngestionApiPost {
    Param(
        [Parameter(Mandatory=$true)]
        [HashTable] $authContext,
        [Parameter(Mandatory=$true)]
        [string] $path,
        [Parameter(Mandatory=$false)]
        [HashTable] $body = @{},
        [Parameter(Mandatory=$false)]
        [HashTable] $headers = @{},
        [Parameter(Mandatory=$false)]
        [string] $query = '',
        [switch] $silent
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {
    Invoke-IngestionApiRestMethod -authContext $authContext -method POST -headers $headers -path $path -query $query -body ($body | ConvertTo-Json) -silent:$silent
}
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    TrackTrace -telemetryScope $telemetryScope
}
}

<#
 .Synopsis
  Invoke a HTTP PUT to modify a single object through the Ingestion API
 .Description
  Returns a PSCustomObject with properties from the modified Object
 .Parameter authContext
  Authentication Context from New-BcAuthContext
 .Parameter path
  Ingestion API path as described on Swagger doc (https://ingestionapi-swagger.azureedge.net/)
 .Parameter body
  Optional. HashTable with properties for the request (incl. an '@odata.etag' property)
 .Parameter headers
  Optional. Hashtable with additional headers for the request
 .Parameter query
  Optional. Query parameters for the invoke
 .Parameter silent
  Include this switch if you do not want the method to display URLs etc.
 .Example
  $packageUpload.state = "Uploaded"
  $packageUploaded = Invoke-IngestionApiPut -authContext $authContext -path "/products/$productId/packages/$($packageUpload.id)" -Body ($packageUpload | ConvertTo-HashTable)
#>
function Invoke-IngestionApiPut {
    Param(
        [Parameter(Mandatory=$true)]
        [HashTable] $authContext,
        [Parameter(Mandatory=$true)]
        [string] $path,
        [Parameter(Mandatory=$true)]
        [HashTable] $body,
        [Parameter(Mandatory=$false)]
        [HashTable] $headers = @{},
        [Parameter(Mandatory=$false)]
        [string] $query,
        [switch] $silent
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {
    $headers += @{
        "If-Match" = $body.'@odata.etag'
    }
    Invoke-IngestionApiRestMethod -authContext $authContext -method PUT -headers $headers -path $path -query $query -body ($body | ConvertTo-Json) -silent:$silent
}
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    TrackTrace -telemetryScope $telemetryScope
}
}

<#
 .Synopsis
  Invoke a HTTP DELETE to delete a single object through the Ingestion API
  Primary used to cancel an in progress validation
 .Description
  Returns a PSCustomObject with properties from the removed Object
 .Parameter authContext
  Authentication Context from New-BcAuthContext
 .Parameter path
  Ingestion API path as described on Swagger doc (https://ingestionapi-swagger.azureedge.net/)
 .Parameter headers
  Optional. Hashtable with additional headers for the request
 .Parameter query
  Optional. Query parameters for the invoke
 .Parameter silent
  Include this switch if you do not want the method to display URLs etc.
 .Example
  Invoke-IngestionApiDelete -authContext $authContext -path "/products/$productId/submissions/$($submission.id)"
#>
function Invoke-IngestionApiDelete {
    Param(
        [Parameter(Mandatory=$true)]
        [HashTable] $authContext,
        [Parameter(Mandatory=$true)]
        [string] $path,
        [Parameter(Mandatory=$false)]
        [HashTable] $headers = @{},
        [Parameter(Mandatory=$false)]
        [string] $query = '',
        [switch] $silent
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {
    Invoke-IngestionApiRestMethod -authContext $authContext -method DELETE -headers $headers -path $path -query $query -silent:$silent
}
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    TrackTrace -telemetryScope $telemetryScope
}
}
Export-ModuleMember -Function Invoke-IngestionApiGet, Invoke-IngestionApiGetCollection, Invoke-IngestionApiPost, Invoke-IngestionApiPut, Invoke-IngestionApiDelete
