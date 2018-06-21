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
 .Example
  Import-TestToolkitToNavContainer -containerName test2
#>
function Import-TestToolkitToNavContainer {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName, 
        [System.Management.Automation.PSCredential]$sqlCredential = $null
    )

    $sqlCredential = Get-DefaultSqlCredential -containerName $containerName -sqlCredential $sqlCredential

    $session = Get-NavContainerSession -containerName $containerName -silent
    Invoke-Command -Session $session -ScriptBlock { Param([System.Management.Automation.PSCredential]$sqlCredential)
    
        $customConfigFile = Join-Path (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName "CustomSettings.config"
        [xml]$customConfig = [System.IO.File]::ReadAllText($customConfigFile)
        $databaseServer = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseServer']").Value
        $databaseInstance = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseInstance']").Value
        $databaseName = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseName']").Value
        if ($databaseInstance) { $databaseServer += "\$databaseInstance" }
        $enableSymbolLoadingKey = $customConfig.SelectSingleNode("//appSettings/add[@key='EnableSymbolLoadingAtServerStartup']")
    
        $params = @{}
        if ($sqlCredential) {
            $params = @{ 'Username' = $sqlCredential.UserName; 'Password' = ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sqlCredential.Password))) }
        }
        Get-ChildItem -Path "C:\TestToolKit\*.fob" | ForEach-Object { 
            $objectsFile = $_.FullName
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
                                        -ImportAction Overwrite `
                                        -SynchronizeSchemaChanges Force `
                                        -NavServerName localhost `
                                        -NavServerInstance NAV `
                                        -NavServerManagementPort 7045 `
                                        -Confirm:$false
        }
    } -ArgumentList $sqlCredential
    Write-Host -ForegroundColor Green "TestToolkit successfully imported"
}
Export-ModuleMember -Function Import-TestToolkitToNavContainer
