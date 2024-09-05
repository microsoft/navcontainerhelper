﻿<# 
 .Synopsis
  Import Objects to Nav Container
 .Description
  Copy the object file to the Nav container if necessary.
  Create a session to a Nav container and run Import-NavApplicationObject
 .Parameter containerName
  Name of the container in which you want to import objects
 .Parameter objectsFile
  Path of the objects file you want to import
 .Parameter sqlCredential
  Credentials for the SQL admin user if using NavUserPassword authentication. User will be prompted if not provided
 .Parameter ImportAction
  Specifies the import action. Default is Overwrite.
 .Parameter SynchronizeSchemaChanges
  Specify whether you want to Synchronize Schema Changes. Values are Yes, No or Force. Default is Force.
 .Example
  Import-ObjectsToNavContainer -containerName test2 -objectsFile c:\temp\objects.txt -sqlCredential (get-credential -credential 'sa')
#>
function Import-ObjectsToNavContainer {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory=$true)]
        [string] $objectsFile,
        [PSCredential] $sqlCredential = $null,
        [ValidateSet("Overwrite","Skip")]
        [string] $ImportAction = "Overwrite",
        [ValidateSet("Force","Yes","No")]
        [string] $SynchronizeSchemaChanges = "Force",
        [switch] $suppressBuildSearchIndex
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {

    AssumeNavContainer -containerOrImageName $containerName -functionName $MyInvocation.MyCommand.Name

    $sqlCredential = Get-DefaultSqlCredential -containerName $containerName -sqlCredential $sqlCredential -doNotAskForCredential
    $containerObjectsFile = Get-NavContainerPath -containerName $containerName -path $objectsFile
    $copied = $false
    if ("$containerObjectsFile" -eq "") {
        $containerObjectsFile = Join-Path "c:\run" ([System.IO.Path]::GetFileName($objectsFile))
        Copy-FileToNavContainer -containerName $containerName -localPath $objectsFile -containerPath $containerObjectsFile
        $copied = $true
    }

    Invoke-ScriptInNavContainer -containerName $containerName -ScriptBlock { Param($objectsFile, [System.Management.Automation.PSCredential]$sqlCredential, $ImportAction, $SynchronizeSchemaChanges, $copied, $suppressBuildSearchIndex)
    
        $customConfigFile = Join-Path (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName "CustomSettings.config"
        [xml]$customConfig = [System.IO.File]::ReadAllText($customConfigFile)
        $databaseServer = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseServer']").Value
        $databaseInstance = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseInstance']").Value
        $databaseName = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseName']").Value
        $managementServicesPort = $customConfig.SelectSingleNode("//appSettings/add[@key='ManagementServicesPort']").Value
        if ($databaseInstance) { $databaseServer += "\$databaseInstance" }
        $enableSymbolLoadingKey = $customConfig.SelectSingleNode("//appSettings/add[@key='EnableSymbolLoadingAtServerStartup']")
    
        $params = @{}
        if ($sqlCredential) {
            $params = @{ 'Username' = $sqlCredential.UserName; 'Password' = ([System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sqlCredential.Password))) }
        }
        if ($suppressBuildSearchIndex) {
            $params += @{ "suppressBuildSearchIndex" = $suppressBuildSearchIndex }
        }
        Write-Host "Importing Objects from $objectsFile (container path)"
        $databaseServerParameter = $databaseServer
        if ($enableSymbolLoadingKey -ne $null -and $enableSymbolLoadingKey.Value -eq "True") {
            # HACK: Parameter insertion...
            # generatesymbolreference is not supported by Import-NAVApplicationObject yet
            # insert an extra parameter for the finsql command by splitting the filter property
            $databaseServerParameter = '",generatesymbolreference=1,ServerName="'+$databaseServer
        }
        Import-NAVApplicationObject @params -Path $objectsFile `
                                    -DatabaseName $databaseName `
                                    -DatabaseServer $databaseServerParameter `
                                    -ImportAction $ImportAction `
                                    -SynchronizeSchemaChanges $SynchronizeSchemaChanges `
                                    -NavServerName localhost `
                                    -NavServerInstance $ServerInstance `
                                    -NavServerManagementPort "$managementServicesPort" `
                                    -Confirm:$false

        if ($copied) {
            Remove-Item -Path $objectsFile -Force
        }
    
    } -ArgumentList $containerObjectsFile, $sqlCredential, $ImportAction, $SynchronizeSchemaChanges, $copied, $suppressBuildSearchIndex
    Write-Host -ForegroundColor Green "Objects successfully imported"
}
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    TrackTrace -telemetryScope $telemetryScope
}
}
Export-ModuleMember -Function Import-ObjectsToNavContainer
