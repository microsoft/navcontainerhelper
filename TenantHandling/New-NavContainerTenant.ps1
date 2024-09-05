﻿<# 
 .Synopsis
  Creates a new Tenant in a multitenant NAV/BC Container
 .Description
  Creates a tenant database in the Container and mounts it as a new tenant
 .Parameter containerName
  Name of the container in which you want create a tenant
 .Parameter tenantId
  Name of tenant you want to create in the container
 .Parameter sqlCredential
  Credentials for the SQL server of the tenant database (if using an external SQL Server)
 .Parameter sourceDatabase
  Specify a source database which will be the template for the new tenant (default is tenant)
 .Parameter destinationDatabase
  Specify a database name for the new tenant (default is the tenantid)
 .Parameter alternateId
  Specify an array of alternate tenant ids (hostnames f.ex.)
 .Parameter allowAppDatabaseWrite
  Include this switch if the tenant should have AllowAppDatabaseWrite set
 .Parameter doNotCopyDatabase
  Mount the database specified in destinationDatabase. Do not copy source database.
 .Example
  New-BcContainerTenant -containerName test2 -tenantId mytenant
#>
function New-BcContainerTenant {
    Param (
        [Parameter(Mandatory=$false)]
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory=$true)]
        [string] $tenantId,
        [PSCredential] $sqlCredential = $null,
        [string] $sourceDatabase = "tenant",
        [string] $destinationDatabase = $tenantId,
        [string[]] $alternateId = @(),
        [switch] $allowAppDatabaseWrite,
        [switch] $doNotCopyDatabase,
        [string] $applicationInsightsKey = ""
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {

    Write-Host "Creating Tenant $tenantId on $containerName"

    if ($tenantId -eq "tenant") {
        throw "You cannot add a tenant called tenant"
    }

    Invoke-ScriptInBcContainer -containerName $containerName -useSession $false -usePwsh $false -ScriptBlock { Param($containerName, $tenantId, [PSCredential]$sqlCredential, $sourceDatabase, $destinationDatabase, $alternateId, $doNotCopyDatabase, $allowAppDatabaseWrite, $applicationInsightsKey)

        $customConfigFile = Join-Path (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName "CustomSettings.config"
        [xml]$customConfig = [System.IO.File]::ReadAllText($customConfigFile)
        if ($customConfig.SelectSingleNode("//appSettings/add[@key='Multitenant']").Value -ne "true") {
            throw "The Container is not setup for multitenancy"
        }
        $databaseServer = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseServer']").Value
        $databaseInstance = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseInstance']").Value
        if ("$databaseServer\$databaseInstance" -eq "localhost\SQLEXPRESS") {
            $sqlCredential = $null
        }

        if ((Test-Path "c:\run\my\updatehosts.ps1") -or (Test-Path "c:\run\my\updatecontainerhosts.ps1")) {
            $hostname = hostname
            $dotidx = $hostname.indexOf('.')
            if ($dotidx -eq -1) { $dotidx = $hostname.Length }
            $tenantHostname = $hostname.insert($dotidx,"-$tenantId")
            $alternateId += @($tenantHostname)
        }

        $Params = @{}
        if ($allowAppDatabaseWrite) {
            $Params += @{ "AllowAppDatabaseWrite" = $true }
        }
        if ($applicationInsightsKey) {
            $Params += @{ "applicationInsightsInstrumentationKey" = $applicationInsightsKey }
        }

        # Setup tenant
        if (!$doNotCopyDatabase) {
            Copy-NavDatabase -SourceDatabaseName $sourceDatabase -DestinationDatabaseName $destinationDatabase -DatabaseServer $databaseServer -DatabaseInstance $databaseInstance -DatabaseCredentials $sqlCredential
        }
        Mount-NavDatabase -ServerInstance $ServerInstance -TenantId $TenantId -DatabaseName $destinationDatabase -DatabaseServer $databaseServer -DatabaseInstance $databaseInstance -DatabaseCredentials $sqlCredential -AlternateId $alternateId @Params -WarningAction SilentlyContinue

        if (Test-Path "c:\run\my\updatehosts.ps1") {
            $ip = "127.0.0.1"
            $ips = Get-NetIPAddress | Where-Object { $_.AddressFamily -eq "IPv4" -and $_.IPAddress -ne "127.0.0.1" }
            if ($ips) {
                $ips | ForEach-Object {
                    if ($ip -eq "127.0.0.1") {
                        $ip = $_.IPAddress
                    }
                }
            }

            if ($ip -ne "127.0.0.1") {
                . "c:\run\my\updatehosts.ps1" -hostsFile "c:\driversetc\hosts" -theHostname $tenantHostname -theIpAddress $ip
                . "c:\run\my\updatehosts.ps1" -hostsFile "c:\windows\system32\drivers\etc\hosts" -theHostname $tenantHostname -theIpAddress $ip
            }
        }
        elseif (Test-Path "c:\run\my\updatecontainerhosts.ps1") {
            . "c:\run\my\updatecontainerhosts.ps1" -hostsFile "c:\windows\system32\drivers\etc\hosts" -theHostname $tenantHostname -theIpAddress "127.0.0.1"
        }


    } -ArgumentList $containerName, $tenantId, $sqlCredential, $sourceDatabase, $destinationDatabase, $alternateId, $doNotCopyDatabase, $allowAppDatabaseWrite, $applicationInsightsKey
    Write-Host -ForegroundColor Green "Tenant successfully created"
}
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    TrackTrace -telemetryScope $telemetryScope
}
}
Set-Alias -Name New-NavContainerTenant -Value New-BcContainerTenant
Export-ModuleMember -Function New-BcContainerTenant -Alias New-NavContainerTenant
