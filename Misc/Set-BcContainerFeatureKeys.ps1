<# 
 .Synopsis
  Set Feature Keys in container
 .Description
  Enumerates hash table and sets the feature keys in a container tenant database
 .Parameter containerName
  Name of the container in which you want to set feature keys
 .Parameter tenant
  Tenant in which you want to set feature keys
 .Parameter featureKeys
  Hashtable of featureKeys you want to set
 .Example
  Set-BcContainerFeatureKeys -containerName test2 -featureKeys @{"EmailHandlingImprovements" = "None"}
#>
function Set-BcContainerFeatureKeys {
   Param (
        [Parameter(Mandatory=$false)]
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName, 
        [Parameter(Mandatory=$false)]
        [string] $tenant = "*",
        [Parameter(Mandatory=$true)]
        [hashtable] $featureKeys
    )

    if ($featureKeys.Keys.Count -ne 0) {    
        Invoke-ScriptInBCContainer -containerName $containerName -ScriptBlock { Param([string] $tenant, [hashtable] $featureKeys) 
            $customConfigFile = Join-Path (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName "CustomSettings.config"
            [xml]$customConfig = [System.IO.File]::ReadAllText($customConfigFile)
            $databaseServer = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseServer']").Value
            $databaseInstance = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseInstance']").Value
            $databaseName = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseName']").Value
            $multitenant = $customConfig.SelectSingleNode("//appSettings/add[@key='Multitenant']").Value -eq "true"
    
            if ($databaseServer -ne "localhost" -or $databaseInstance -ne "SQLEXPRESS") {
                Write-Host "WARNING: Trying to use Set-BcContainerFeatureKeys on a foreign database, no feature keys are set"
                exit
            }
    
            if (!$multitenant) {
                $databases = @($databaseName)
            }
            else {
                if ($tenant -eq "*") {
                    $databases = @(Get-NAVTenant -ServerInstance $serverinstance | % { $_.Id })
                    $databases += @("tenant")
                }
                else {
                    $databases = @($tenant)
                }
            }
    
            $databases | % {
                $databaseName = $_
                Write-Host "Setting feature keys on database: $databaseName"
                $featureKeys.Keys | % {
                    $featureKey = $_
                    $enabledStr = $featureKeys[$featureKey]
                    if ($enabledStr -eq "All Users" -or $enabledStr -eq "1") {
                        $enabled = 1
                    }
                    elseif ($enabledStr -eq "None" -or $enabledStr -eq "0") {
                        $enabled = 0
                    }
                    else {
                        $enabled = -1
                        Write-Host "WARNING: Unknown value ($enabledStr) for feature key $featureKey"
                    }
                    if ($enabled -ne -1) {
                        try {
                            Write-Host -NoNewline "Setting feature key $featureKey to $enabledStr - "
                            $result = Invoke-Sqlcmd -Database $databaseName -Query "UPDATE [dbo].[Tenant Feature Key] set Enabled = $enabled where ID = '$featureKey';Select @@ROWCOUNT"
                            if ($result[0] -eq "1") {
                                Write-Host " Success"
                            }
                            else {
                                throw
                            }
                        }
                        catch {
                            Write-Host " Failure"
                            Write-Host "WARNING: Unable to set feature key $featureKey"
                        }
                    }
                }
            }
        } -argumentList $tenant, $featureKeys
    }
}
Export-ModuleMember -Function Set-BcContainerFeatureKeys
