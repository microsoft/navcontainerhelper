<# 
 .Synopsis
  Import TestToolkit to Nav Container
 .Description
  Import the objects from the TestToolkit to the Nav Container.
  The TestToolkit objects are already in a folder on the NAV on Docker image from version 0.0.4.3
 .Parameter containerName
  Name of the container for which you want to enter a session
 .Parameter sqlCredential
  Credentials for the SQL admin user if using NavUserPassword authentication. User will be prompted if not provided
 .Parameter includeTestLibrariesOnly
  Only import TestLibraries (do not import Test Codeunits)
 .Parameter testToolkitCountry
  Only import TestToolkit objects for a specific country.
  You must specify the country code that is used in the TestToolkit object name (e.g. CA, US, MX, etc.).
  This parameter only needs to be used in the event there are multiple country-specific sets of objects in the TestToolkit folder.
 .Parameter doNotUpdateSymbols
  Add this switch to avoid updating symbols when importing the test toolkit
 .Example
  Import-TestToolkitToNavContainer -containerName test2
  .Example
  Import-TestToolkitToNavContainer -containerName test2 -testToolkitCountry US
#>
function Import-TestToolkitToNavContainer {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName, 
        [System.Management.Automation.PSCredential]$sqlCredential = $null,
        [switch]$includeTestLibrariesOnly,
        [string]$testToolkitCountry,
        [switch]$doNotUpdateSymbols
    )

    $sqlCredential = Get-DefaultSqlCredential -containerName $containerName -sqlCredential $sqlCredential

    Invoke-ScriptInNavContainer -containerName $containerName -ScriptBlock { Param([System.Management.Automation.PSCredential]$sqlCredential, $includeTestLibrariesOnly, $testToolkitCountry, $doNotUpdateSymbols)
    
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
            $params = @{ 'Username' = $sqlCredential.UserName; 'Password' = ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sqlCredential.Password))) }
        }
        if ($testToolkitCountry) {
            $fileFilter = "*.$testToolkitCountry.fob"
        }
        else {
            $fileFilter = "*.fob"
        }
        Get-ChildItem -Path "C:\TestToolKit" -Filter $fileFilter | ForEach-Object { 
            if (!$includeTestLibrariesOnly -or $_.Name.StartsWith("CALTestLibraries")) {
                $objectsFile = $_.FullName
                Write-Host "Importing Objects from $objectsFile (container path)"
                $databaseServerParameter = $databaseServer

                if ($enableSymbolLoadingKey -ne $null -and $enableSymbolLoadingKey.Value -eq "True" -and !$doNotUpdateSymbols) {
                    # HACK: Parameter insertion...
                    # generatesymbolreference is not supported by Import-NAVApplicationObject yet
                    # insert an extra parameter for the finsql command by splitting the filter property
                    $databaseServerParameter = '",generatesymbolreference=1,ServerName="'+$databaseServer
                }
    
                Import-NAVApplicationObject @params -Path $objectsFile `
                                            -DatabaseName $databaseName `
                                            -DatabaseServer $databaseServerParameter `
                                            -ImportAction Overwrite `
                                            -SynchronizeSchemaChanges No `
                                            -NavServerName localhost `
                                            -NavServerInstance NAV `
                                            -NavServerManagementPort "$managementServicesPort" `
                                            -Confirm:$false
    
            }
        }

        # Sync after all objects hav been imported
         Get-NAVTenant NAV | Sync-NavTenant -Mode ForceSync -Force

    } -ArgumentList $sqlCredential, $includeTestLibrariesOnly, $testToolkitCountry, $doNotUpdateSymbols
    Write-Host -ForegroundColor Green "TestToolkit successfully imported"
}
Export-ModuleMember -Function Import-TestToolkitToNavContainer
