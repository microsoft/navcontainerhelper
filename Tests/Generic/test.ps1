$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "..\..\NavContainerHelper.ps1")
. (Join-Path $PSScriptRoot "..\settings.ps1")

New-NavContainer -accept_eula `
                 -containerName genericserver `
                 -navdvdpath $navdvdpath `
                 -Credential $credential `
                 -updateHosts `
                 -useSSL:$false

Remove-NavContainer -containerName genericserver
