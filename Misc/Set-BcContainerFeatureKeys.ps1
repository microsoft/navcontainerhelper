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
 .Parameter EnableInCompany
  Enables/disables features for given company name. No data update is initiated.
 .Example
  Set-BcContainerFeatureKeys -containerName test2 -featureKeys @{"EmailHandlingImprovements" = "None"}
  Set-BcContainerFeatureKeys -containerName test2 -featureKeys @{"EmailHandlingImprovements" = "None"} -EnableInCompany 'CRONUS International Ltd.'
#>
function Set-BcContainerFeatureKeys {
   Param (
        [Parameter(Mandatory=$false)]
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName, 
        [Parameter(Mandatory=$false)]
        [string] $tenant = "*",
        [Parameter(Mandatory=$true)]
        [hashtable] $featureKeys,
        [Parameter(Mandatory=$false)]
        [string] $EnableInCompany
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @("featureKeys")
try {
    
    if ($featureKeys.Keys.Count -ne 0) {    
        Invoke-ScriptInBCContainer -containerName $containerName -ScriptBlock { Param([string] $tenant, [hashtable] $featureKeys, $EnableInCompany) 
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
                # Just information about 'mode' of Feature Key update
                if ([String]::IsNullOrEmpty($EnableInCompany))
                {
                    Write-Host "Setting feature keys globally, but not for any company" -ForegroundColor Yellow
                }
                else
                {
                    Write-Host "Setting feature keys globally and for company "$EnableInCompany -ForegroundColor Yellow
                }
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
                    
                    # Test if feature which has to be updated is available in table "Feature Data Update Status$63ca2fa4-4f03-4f2b-a480-172fef340d3f"
                    $FeatureExistsInDestination = Invoke-Sqlcmd -Database $databaseName -Query $("SELECT COUNT(*) FROM [dbo].[Feature Data Update Status"+'$'+"63ca2fa4-4f03-4f2b-a480-172fef340d3f] where [Feature Key] = '$featureKey'")

                    if(($FeatureExistsInDestination[0].ToString()) -eq "0")
                    {
                        Write-host "Feature $featureKey doesn't exist in database"
                    }

                    # Feature key is updated just in case that status is correct and respective feature is available in table
                    if (($enabled -ne -1) -and ($FeatureExistsInDestination[0].ToString() -ne "0")){
                        try {
                            #Create new record in table "Tenant Feature Key" in case it is missing
                            $SQLRecord = Invoke-Sqlcmd -Database $databaseName -Query "SELECT * FROM [dbo].[Tenant Feature Key] where ID = '$featureKey'"
                            if ([String]::IsNullOrEmpty($SQLRecord))
                            {
                                Write-host "Creating record for feature $featureKey"
                                $SQLcolumns = "ID, Enabled"
                                $SQLvalues = "'$featureKey',0"
                                Invoke-Sqlcmd -Database $databaseName -Query "INSERT INTO [CRONUS].[dbo].[Tenant Feature Key] ($SQLcolumns) VALUES ($SQLvalues)" -Verbose
                            }
                            Write-Host -NoNewline "Setting feature key $featureKey to $enabledStr - "
                            $result = Invoke-Sqlcmd -Database $databaseName -Query "UPDATE [dbo].[Tenant Feature Key] set Enabled = $enabled where ID = '$featureKey';Select @@ROWCOUNT"
                            
                            # Update record in table "Feature Data Update Status$63ca2fa4-4f03-4f2b-a480-172fef340d3f" if it is requested for particular company
                            $result2 = ''
                            if (![String]::IsNullOrEmpty($EnableInCompany))
                            {
                                $result2 = Invoke-Sqlcmd -Database $databaseName -Query $("UPDATE [dbo].[Feature Data Update Status"+'$'+"63ca2fa4-4f03-4f2b-a480-172fef340d3f] set [Feature Status] = $enabled where [Feature Key] = '$featureKey' AND [Company Name] = '$EnableInCompany';Select @@ROWCOUNT")
                            }
                            if (($result[0] -eq "1") -and ((($result2[0] -eq "1") -and ![String]::IsNullOrEmpty($EnableInCompany)) -or ([String]::IsNullOrEmpty($EnableInCompany)))) {
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
        } -argumentList $tenant, $featureKeys, $EnableInCompany
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
Export-ModuleMember -Function Set-BcContainerFeatureKeys
