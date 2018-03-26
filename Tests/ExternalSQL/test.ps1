$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "..\..\NavContainerHelper.ps1")
. (Join-Path $PSScriptRoot "..\settings.ps1")

$txtPath = (Join-Path $PSScriptRoot "test.txt")

New-NavContainer -accept_eula `
                 -containerName server1 `
                 -imageName $imageName `
                 -Credential $credential `
                 -licenseFile $licenseFile `
                 -updateHosts `
                 -useSSL:$false `
                 -includeCSide `
                 -doNotExportObjectsToText

New-NavContainer -accept_eula `
                 -containerName server2 `
                 -imageName $imageName `
                 -Credential $credential `
                 -updateHosts `
                 -useSSL:$false `
                 -includeCSide `
                 -doNotExportObjectsToText `
                 -databaseServer server1 `
                 -databaseInstance SQLEXPRESS `
                 -databaseName CRONUS `
                 -databaseCredential $sqlCredential

New-NavContainer -accept_eula `
                 -containerName server3 `
                 -imageName $imageName `
                 -Credential $credential `
                 -updateHosts `
                 -useSSL:$false `
                 -includeCSide `
                 -doNotExportObjectsToText `
                 -databaseServer server1 `
                 -databaseInstance SQLEXPRESS `
                 -databaseName CRONUS `
                 -databaseCredential $sqlCredential `
                 -additionalParameters ("--env encryptionPassword=P@ssword1")

Import-ObjectsToNavContainer -containerName server3 -objectsFile $txtPath -sqlCredential $sqlCredential
Export-NavContainerObjects -containerName server3 -objectsFolder "C:\ProgramData\NavContainerHelper\Extensions\server3\Objects" -sqlCredential $sqlCredential

Remove-NavContainer -containerName server3
Remove-NavContainer -containerName server2
Remove-NavContainer -containerName server1
