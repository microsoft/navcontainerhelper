# This script performs a simple happy-path test of most navcontainerhelper functions

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "..\..\NavContainerHelper.ps1")
. (Join-Path $PSScriptRoot "..\settings.ps1")

"2016", "2017", "2018", "devpreview" | % {

    $imageName = "microsoft/dynamics-nav:$_"

    $containerName = "test"

    Write-Host "$imagename"

    # New-NavContainer single tenant
    New-NavContainer -accept_eula `
                     -includeCSide `
                     -doNotExportObjectsToText `
                     -containerName $containerName `
                     -imageName $imageName `
                     -credential $credential `
                     -UpdateHosts `
                     -Auth Windows `

    # Add user
    New-NavContainerNavUser -containerName $containerName -Credential $Credential -PermissionSetId SUPER
                        
#    # New-NavContainer single tenant
#    New-NavContainer -accept_eula `
#                     -includeCSide `
#                     -doNotExportObjectsToText `
#                     -containerName $containerName `
#                     -imageName $imageName `
#                     -credential $credential `
#                     -UpdateHosts `
#                     -multitenant `
#                     -Auth Windows `
#
#    # Create Extra tenant
#    New-NavContainerTenant -containerName $containerName -tenantId mytenant
#
#    # Add user
#    New-NavContainerUser -containerName $containerName -tenant mytenant -Credential $Credential -PermissionSetId SUPER
#
#    # Remove tenant
#    Remove-NavContainerTenant -containerName $containerName -tenantId mytenant
}

# Remove-NavContainer
Remove-NavContainer -containerName $containerName
