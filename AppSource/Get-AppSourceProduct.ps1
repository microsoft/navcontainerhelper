<#
 .Synopsis
  Get information about an AppSource product from the authenticated account
 .Description
  Returns a PSCustomObject with your AppSource product
 .Parameter authContext
  Authentication Context from New-BcAuthContext
 .Parameter productId
  Id of the product for which you want to get information 
 .Parameter productName
  Name of the product for which you want to get information (supports wildcards)
 .Parameter includeProperty
  Include this switch if you want do include the properties of the product
 .Parameter includeListing
  Include this switch if you want do include the listings of the product
 .Parameter includeSetup
  Include this switch if you want do include the setup of the product
 .Parameter includeProductAvailability
  Include this switch if you want do include the productavailability of the product
 .Parameter includeFeatureAvailability
  Include this switch if you want do include the featureavailability of the product (including markets)
 .Parameter includeListingAsset
  Include this switch if you want do include the assets of the listings of the product (including FileSasUri)
 .Parameter includeListingImage
  Include this switch if you want do include the images of the listings of the product (including FileSasUri)
 .Parameter includeListingVideo
  Include this switch if you want do include the videos of the listings of the product (including FileSasUri)
 .Parameter includePackage
  Include this switch if you want do include the packages of the product
 .Parameter includeAll
  Include this switch if you want to include all additional information about the product
 .Parameter silent
  Include this switch if you do not want the method to display URLs etc.
 .Example
  @(Get-AppSourceProduct -authContext $authcontext -silent)

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
 .Example
  Get-AppSourceProduct -authContext $authcontext -productId $productId -silent
  
  resourceType          : AzureDynamics365BusinessCentral
  name                  : BingMaps.AppSource
  externalIDs           : {@{type=AzureOfferId; value=bingmapsintegration}}
  isModularPublishing   : True
  id                    : 5fbe0803-a545-4504-b41a-d9d158112360

 .Example
  Get-AppSourceProduct -authContext $authcontext -productName 'BingMaps.*' -silent
  
  resourceType          : AzureDynamics365BusinessCentral
  name                  : BingMaps.AppSource
  externalIDs           : {@{type=AzureOfferId; value=bingmapsintegration}}
  isModularPublishing   : True
  id                    : 5fbe0803-a545-4504-b41a-d9d158112360

 .Example
  $product = Get-AppSourceProduct -authContext $authcontext -productId $productId -includeFeatureAvailability -silent
  $product.FeatureAvailability[0].marketStates | Where-Object { $_.state -eq "Enabled" }
  
  marketCode state  
  ---------- -----  
  DK         Enabled
  IT         Enabled
  US         Enabled

 .Example
  $product = Get-AppSourceProduct -authContext $authcontext -productId $productId -includepackage -silent
  $product
  $product.packageConfigurations
  
  resourceType          : AzureDynamics365BusinessCentral
  name                  : BingMaps.AppSource
  externalIDs           : {@{type=AzureOfferId; value=bingmapsintegration}}
  isModularPublishing   : True
  id                    : 5fbe0803-a545-4504-b41a-d9d158112360
  PackageConfigurations : {@{resourceType=Dynamics365BusinessCentralPackageConfiguration; packageType=AddOn; packageReferences=System.Object[]; 
                          @odata.etag="0000d552-0000-0800-0000-62eba1680000"; id=2c3eb741-7421-40b7-870b-1caea05f017e; Dynamics365BusinessCentralAddOnExtensionPackage=}}

  resourceType                                    : Dynamics365BusinessCentralPackageConfiguration
  packageType                                     : AddOn
  packageReferences                               : {@{type=Dynamics365BusinessCentralAddOnExtensionPackage; value=7cb9f83f-96a7-4e71-a782-6edcaf6a26e4}}
  @odata.etag                                     : "0000d552-0000-0800-0000-62eba1680000"
  id                                              : 2c3eb741-7421-40b7-870b-1caea05f017e
  Dynamics365BusinessCentralAddOnExtensionPackage : @{resourceType=; fileName=Freddy Kristiansen_BingMaps.AppSource_3.0.163.0.app; state=Processed; 
                                                    @odata.etag="40001820-0000-0800-0000-62eba15f0000"; id=7cb9f83f-96a7-4e71-a782-6edcaf6a26e4}
  
#>
function Get-AppSourceProduct {
     [CmdletBinding(DefaultParameterSetName = 'ProductId')]
     Param(
        [Parameter(Mandatory=$true)]
        [HashTable] $authContext,
        [Parameter(Mandatory=$false, ParameterSetName = 'ProductId')]
        [string] $productId = '',
        [Parameter(Mandatory=$false, ParameterSetName = 'ProductName')]
        [string] $productName = '',
        [switch] $includeSetup,
        [switch] $includeProperty,
        [switch] $includeListing,
        [switch] $includePackage,
        [switch] $includeProductAvailability,
        [switch] $includeFeatureAvailability,
        [switch] $includeListingAsset,
        [switch] $includeListingImage,
        [switch] $includeListingVideo,
        [switch] $includeAll,
        [switch] $silent
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {
    $authContext = Renew-BcAuthContext -bcAuthContext $authContext
    if ($productId) {
        $product = Invoke-IngestionApiGet -authContext $authContext -path "/products/$productId" -silent:($silent.IsPresent)
        if (-not $product) {
            throw "Product with ID $productId cannot be found"
        }
        $products = @($product)
    }
    elseif ($productName) {
        $product = Invoke-IngestionApiGetCollection -authContext $authContext -path '/products' -silent:($silent.IsPresent) | Where-Object { $_.Name -like $productName }
        if (-not $product) {
            throw "Product with Name $productName cannot be found"
        }
        $products = @($product)
    }
    else {
        $products = @(Invoke-IngestionApiGetCollection -authContext $authContext -path '/products' -silent:($silent.IsPresent))
    }
    $products | ForEach-Object {
        $product = $_
        #$product | ConvertTo-Json -Depth 99 | Out-Host
        $variantID = ''
        if ($includeSetup -or $includeAll) {
            $product | Add-Member -MemberType NoteProperty -Name 'Setup' -Value (Invoke-IngestionApiGet -authContext $authContext -path "/products/$($product.Id)/setup" -silent:($silent.IsPresent))
        }
        if ($includeFeatureAvailability -or $includeProductAvailability -or $includeAll) {
            $branchesAvailability = @(Invoke-IngestionApiGetCollection -authContext $authContext -path "/products/$($product.Id)/branches/getByModule(module=Availability)" -silent:($silent.IsPresent) | Where-Object { 
                $thisVariantID = ''
                if ($_.PSObject.Properties.name -eq "variantID") { $thisVariantID = $_.variantID }
                $variantID -eq $thisVariantID
            })
            if ($branchesAvailability.Count -ne 1) {
                throw "Unable to find branchesAvailability for product $($product.Id)"
            }
            if ($includeProductAvailability -or $includeAll) {
                $product | Add-Member -MemberType NoteProperty -Name "ProductAvailability" -Value @(Invoke-IngestionApiGetCollection -authContext $authContext -path "/products/$($product.Id)/productavailabilities/getByInstanceID(instanceID=$($branchesAvailability[0].currentDraftInstanceID))" -silent:($silent.IsPresent))
            }
            if ($includeFeatureAvailability -or $includeAll) {
                $product | Add-Member -MemberType NoteProperty -Name "FeatureAvailability" -Value @(Invoke-IngestionApiGetCollection -authContext $authContext -path "/products/$($product.Id)/featureavailabilities/getByInstanceID(instanceID=$($branchesAvailability[0].currentDraftInstanceID))" -query '$expand=MarketStates' -silent:($silent.IsPresent))
            }
        }
        if ($includeProperty -or $includeAll) {
            $branchesProperty = @(Invoke-IngestionApiGetCollection -authContext $authContext -path "/products/$($product.Id)/branches/getByModule(module=Property)" -silent:($silent.IsPresent) | Where-Object { 
                $thisVariantID = ''
                if ($_.PSObject.Properties.name -eq "variantID") { $thisVariantID = $_.variantID }
                $variantID -eq $thisVariantID
            })
            if ($branchesProperty.Count -ne 1) {
                throw "Unable to find branchesProperty for product $($product.Id)"
            }
            $product | Add-Member -MemberType NoteProperty -Name "Property" -Value @(Invoke-IngestionApiGetCollection -authContext $authContext -path "/products/$($product.Id)/properties/getByInstanceID(instanceID=$($branchesProperty[0].currentDraftInstanceID))" -silent:($silent.IsPresent))
        }
        if ($includeListing -or $includeAll) {
            $branchesListing = @(Invoke-IngestionApiGetCollection -authContext $authContext -path "/products/$($product.Id)/branches/getByModule(module=Listing)" -silent:($silent.IsPresent) | Where-Object { 
                $thisVariantID = ''
                if ($_.PSObject.Properties.name -eq "variantID") { $thisVariantID = $_.variantID }
                $variantID -eq $thisVariantID
            })
            if ($branchesListing.Count -ne 1) {
                throw "Unable to find branchesListing for product $($product.Id)"
            }
            $product | Add-Member -MemberType NoteProperty -Name "Listing" -Value @(Invoke-IngestionApiGetCollection -authContext $authContext -path "/products/$($product.Id)/listings/getByInstanceID(instanceID=$($branchesListing[0].currentDraftInstanceID))" -silent:($silent.IsPresent))
            $product.Listing | ForEach-Object {
                $listing = $_
                if ($includeListingAsset -or $includeAll) {
                    $listing | Add-Member -MemberType NoteProperty -Name "Asset" -Value @(Invoke-IngestionApiGetCollection -authContext $authContext -path "/products/$($product.Id)/listings/$($listing.id)/assets" -query '$expand=FileSasUri' -silent:($silent.IsPresent))
                }
                if ($includeListingImage -or $includeAll) {
                    $listing | Add-Member -MemberType NoteProperty -Name "Image" -Value @(Invoke-IngestionApiGetCollection -authContext $authContext -path "/products/$($product.Id)/listings/$($listing.id)/images" -query '$expand=FileSasUri' -silent:($silent.IsPresent))
                }
                if ($includeListingVideo -or $includeAll) {
                    $listing | Add-Member -MemberType NoteProperty -Name "Video" -Value @(Invoke-IngestionApiGetCollection -authContext $authContext -path "/products/$($product.Id)/listings/$($listing.id)/videos" -query '$expand=FileSasUri' -silent:($silent.IsPresent))
                }
            }
        }
        if ($includePackage -or $includeAll) {
            $variantID = ''
            $branchesPackage = @(Invoke-IngestionApiGetCollection -authContext $authContext -path "/products/$($product.Id)/branches/getByModule(module=Package)" -silent:($silent.IsPresent) | Where-Object { 
                $thisVariantID = ''
                if ($_.PSObject.Properties.name -eq "variantID") { $thisVariantID = $_.variantID }
                $variantID -eq $thisVariantID
            })
            $branchesPackage | ForEach-Object {
                $packageConfigurations = @(Invoke-IngestionApiGetCollection -authContext $authContext -path "/products/$($product.Id)/packageconfigurations/getByInstanceID(instanceID=$($_.currentDraftInstanceID))" -silent:($silent.IsPresent))
                $packageConfigurations | ForEach-Object {
                    $addOnExtensionPackageId = $_.packageReferences | Where-Object { $_.type -eq 'Dynamics365BusinessCentralAddOnExtensionPackage' } | ForEach-Object { $_.Value }
                    if ($addOnExtensionPackageId) {
                        $_ | Add-Member -MemberType NoteProperty -Name 'Dynamics365BusinessCentralAddOnExtensionPackage' -value (Invoke-IngestionApiGet -authContext $authContext -path "/products/$($product.Id)/packages/$addOnExtensionPackageId" -silent:($silent.IsPresent))
                    }
                    $addOnLibraryExtensionPackageId = $_.packageReferences | Where-Object { $_.type -eq 'Dynamics365BusinessCentralAddOnLibraryExtensionPackage' } | ForEach-Object { $_.Value }
                    if ($addOnLibraryExtensionPackageId) {
                        $_ | Add-Member -MemberType NoteProperty -Name 'Dynamics365BusinessCentralAddOnLibraryExtensionPackage' -value (Invoke-IngestionApiGet -authContext $authContext -path "/products/$($product.Id)/packages/$addOnLibraryExtensionPackageId" -silent:($silent.IsPresent))
                    }
                }
                $product | Add-Member -MemberType NoteProperty -Name 'PackageConfigurations' -Value $packageConfigurations
            }
        }
        $product
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
Export-ModuleMember -Function Get-AppSourceProduct