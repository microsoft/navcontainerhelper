<# 
 .Synopsis
  Cleans the Database in a BC Container
 .Description
  This function will remove existing base app from the database in a container, leaving the container without app
  You will have to publish a new base app before Business Central is useful
 .Parameter containerName
  Name of the container in which you want to clean the database
 .Parameter saveData
  Include the saveData switch if you want to save data while uninstalling apps
 .Parameter onlySaveBaseAppData
  Include the onlySaveBaseAppData switch if you want to only save data in the base application and not in other apps
 .Parameter doNotUnpublish
  Include the doNotUnpublish switch if you do not want to unpublish apps (only 15.x containers or later)
 .Parameter useNewDatabase
  Add this switch if you want to create a new and empty database in the container
  This switch (or useCleanDatabase) is needed when turning a C/AL container into an AL Container.
 .Parameter doNotCopyEntitlements
  Specify this parameter to avoid copying entitlements when using -useNewDatabase
 .Parameter copyTables
  Array if table names to copy from original database when using -useNewDatabase
 .Parameter companyName
  CompanyName when using -useNewDatabase. Default is My Company.
 .Parameter credential
  Credentials of the container super user if using NavUserPassword authentication
 .Parameter evaluationCompany
  Specifies whether the company that you want to create is an evaluation company when using -useNewDatabase
 .Example
  Clean-BcContainerDatabase -containerName test
#>
function Clean-BcContainerDatabase {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [switch] $saveData,
        [Switch] $onlySaveBaseAppData,
        [switch] $doNotUnpublish,
        [switch] $useNewDatabase,
        [switch] $doNotCopyEntitlements,
        [string[]] $copyTables = @(),
        [string] $companyName = "My Company",
        [PSCredential] $credential,
        [switch] $evaluationCompany
    )

    $platform = Get-BcContainerPlatformversion -containerOrImageName $containerName
    if ("$platform" -eq "") {
        $platform = (Get-BcContainerNavVersion -containerOrImageName $containerName).Split('-')[0]
    }
    [System.Version]$platformversion = $platform

    if ($platformversion.Major -lt 14) {
        throw "Container $containerName does not support the function Clean-BcContainerDatabase"
    }

    $myFolder = Join-Path $ExtensionsFolder "$containerName\my"
    if (!(Test-Path "$myFolder\license.flf")) {
        throw "Container must be started with a developer license to perform this operation"
    }

    $customconfig = Get-BcContainerServerConfiguration -ContainerName $containerName

    if ($useNewDatabase) {
        if ($saveData) {
            throw "Cannot use SaveData with useNewDatabase."
        }
        if ($doNotUnpublish) {
            throw "Cannot use doNotUnpublish with useNewDatabase."
        }
        if ($customconfig.ClientServicesCredentialType -ne "Windows" -and !($credential)) {
            throw "You need to specify credentials if using useNewDatabase and authentication is not Windows"
        }

        if ($platformversion.Major -lt 15) {
            $SystemSymbolsFile = Join-Path $ExtensionsFolder "$containerName\system.app"
            $systemSymbols = Get-BcContainerAppInfo -containerName $containerName -symbolsOnly | Where-Object { $_.Name -eq "System" }
            Get-BcContainerApp -containerName $containerName -appName $SystemSymbols.Name -publisher $SystemSymbols.Publisher -appVersion $SystemSymbols.Version -appFile $SystemSymbolsFile -credential $credential
            $SystemApplicationFile = ""
        }
        else {
            $SystemSymbolsFile = ":" + (Invoke-ScriptInBCContainer -containerName $containerName -scriptblock {
                (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\AL Development Environment\System.app").FullName
            })
            $SystemApplicationFile = ":C:\Applications\System Application\Source\Microsoft_System Application.app"
        }

        if (!$doNotCopyEntitlements) {
            $copyTables += @("Entitlement", "Entitlement Set", "Membership Entitlement")
        }

        Invoke-ScriptInBCContainer -containerName $containerName -scriptblock { Param($platformVersion, $databaseName, $databaseServer, $databaseInstance, $copyTables, $multitenant)
        
            Write-Host "Stopping ServiceTier in order to replace database"
            Set-NavServerInstance -ServerInstance $ServerInstance -stop
        
            $databaseServerInstance = $databaseServer
            if ($databaseInstance) {
                $databaseServerInstance += "\$databaseInstance"
            }

            if ($platformVersion.Major -ge 15) {
                $dbproperties = Invoke-Sqlcmd -ServerInstance $databaseServerInstance -Query "SELECT [applicationversion],[applicationfamily] FROM [$databaseName].[dbo].[`$ndo`$dbproperty]"
            }

            if ($copyTables) {
                Copy-NavDatabase -sourceDatabaseName $databaseName -destinationDatabaseName "mytempdb" -DatabaseServer $databaseServer -databaseInstance $databaseInstance
            }
            Remove-NavDatabase -databasename $databaseName -databaseserver $databaseServer -databaseInstance $databaseInstance

            if ($multitenant) {
                Write-Host "Multitenant setup. Creating Single Tenant Database and switching to multitenancy later"
                Set-NavServerConfiguration -ServerInstance $ServerInstance -KeyName "Multitenant" -KeyValue "False" -WarningAction SilentlyContinue
                Set-NavServerConfiguration -ServerInstance $ServerInstance -KeyName "DatabaseName" -KeyValue "tenant" -WarningAction SilentlyContinue
                $databaseName = "tenant"

                Remove-NavDatabase -databasename "tenant" -databaseserver $databaseServer -databaseInstance $databaseInstance
                Remove-NavDatabase -databasename "default" -databaseserver $databaseServer -databaseInstance $databaseInstance
            }

            $CollationParam = @{}
            $collationFile = "c:\run\my\Collation.txt"
            if (!(Test-Path $collationfile)) {
                $collationFile = "c:\run\Collation.txt"
            }
            if (Test-Path $collationFile) {
                $Collation = Get-Content $collationFile
                $CollationParam = @{ "Collation" = $collation }
                Write-Host "Creating new database $databaseName on $databaseServerInstance with Collation $Collation"
            }
            else {
                Write-Host "Creating new database $databaseName on $databaseServerInstance with default Collation"
            }

            if ($platformVersion.Major -ge 15) {
                New-NAVApplicationDatabase -DatabaseServer $databaseServerInstance -DatabaseName $databaseName @CollationParam | Out-Null
                Invoke-Sqlcmd -ServerInstance $databaseServerInstance -Query "UPDATE [$databaseName].[dbo].[`$ndo`$dbproperty] SET [applicationfamily] = '$($dbproperties.applicationfamily)', [applicationversion] = '$($dbproperties.applicationversion)'"
            }
            else {
                Create-NAVDatabase -databasename $databaseName -databaseserver $databaseServerInstance @CollationParam | Out-Null
            }

            if ($copyTables) {
                $copyTables | % {
                    Write-Host "Copying table [$_] from original database"

                    $fields = Invoke-Sqlcmd -ServerInstance $databaseServerInstance -database "mytempdb" -query "SELECT * FROM INFORMATION_SCHEMA.COLUMNS where TABLE_SCHEMA = 'dbo' AND TABLE_NAME = '$_'" | Where-Object { $_.Column_Name -ne "timestamp" } | % { """$($_.Column_Name)""" }

                    Invoke-Sqlcmd -ServerInstance $databaseServerInstance -Query "Delete From [$databaseName].[dbo].[$_]"
                    Invoke-Sqlcmd -ServerInstance $databaseServerInstance -Query "Insert Into [$databaseName].[dbo].[$_] ($($([String]::Join(',',$fields)))) Select $([String]::Join(',',$fields)) from [mytempdb].[dbo].[$_]"
                }
                Remove-NavDatabase -databaseName "mytempdb" -databaseserver $databaseServer -databaseInstance $databaseInstance
            }
            
            Write-Host "Starting Service Tier"
            Set-NavServerInstance -ServerInstance $ServerInstance -start
            
            Write-Host "Synchronizing"
            Sync-NavTenant -ServerInstance $ServerInstance -Force
        
        } -argumentList $platformVersion, $customconfig.DatabaseName, $customconfig.DatabaseServer, $customconfig.DatabaseInstance, $copyTables, ($customconfig.Multitenant -eq "True")
        
        Write-Host "Importing license file"
        Import-BcContainerLicense -containerName $containerName -licenseFile "$myFolder\license.flf"
        
        if ($customconfig.ClientServicesCredentialType -eq "Windows") {
            Write-Host "Creating user $($env:USERNAME)"
            Invoke-ScriptInBCContainer -containerName $containerName -scriptblock { Param($username)
                New-NavServerUser -ServerInstance $ServerInstance -WindowsAccount $username
                New-NavServerUserPermissionSet -ServerInstance $ServerInstance -WindowsAccount $username -PermissionSetId SUPER
            } -argumentList $env:USERNAME
        }
        else {
            Write-Host "Creating user $($credential.UserName)"
            New-BcContainerNavUser -containerName $containerName -Credential $credential -PermissionSetId SUPER -ChangePasswordAtNextLogOn:$false
        }
        
        Write-Host "Publishing System Symbols"
        Publish-BcContainerApp -containerName $containerName -appFile $SystemSymbolsFile -packageType SymbolsOnly -skipVerification

        Write-Host "Creating Company"
        New-CompanyInBcContainer -containerName $containerName -companyName $companyName -evaluationCompany:$evaluationCompany
        
        if ($SystemApplicationFile) {
            Write-Host "Publishing System Application"
            Publish-BcContainerApp -containerName $containerName -appFile $SystemApplicationFile -skipVerification -install -sync
        }

        if ($customconfig.Multitenant -eq "True") {
            
            Write-Host "Switching to multitenancy"
            Invoke-ScriptInBCContainer -containerName $containerName -scriptblock { Param($databaseName, $databaseServer, $databaseInstance)
                $databaseServerInstance = $databaseServer
                if ($databaseInstance) {
                    $databaseServerInstance += "\$databaseInstance"
                }

                Write-Host "Stopping ServiceTier"
                Set-NavServerInstance -ServerInstance $ServerInstance -stop

                Set-NavServerConfiguration -ServerInstance $ServerInstance -KeyName "DatabaseName" -KeyValue "$databaseName" -WarningAction SilentlyContinue
        
                Invoke-sqlcmd -serverinstance $databaseServerInstance -Database "tenant" -query 'CREATE USER "NT AUTHORITY\SYSTEM" FOR LOGIN "NT AUTHORITY\SYSTEM";'
                Export-NAVApplication -DatabaseServer $DatabaseServer -DatabaseInstance $DatabaseInstance -DatabaseName "tenant" -DestinationDatabaseName $databaseName -Force -ServiceAccount 'NT AUTHORITY\SYSTEM' | Out-Null
                Write-Host "Removing Application from tenant"
                Remove-NAVApplication -DatabaseServer $DatabaseServer -DatabaseInstance $DatabaseInstance -DatabaseName "tenant" -Force | Out-Null

                Set-NavServerConfiguration -ServerInstance $ServerInstance -KeyName "Multitenant" -KeyValue "True" -WarningAction SilentlyContinue
                Write-Host "Starting ServiceTier"

                Set-NavServerInstance -ServerInstance $ServerInstance -start

                Write-Host "Copying tenant to default db"
                Copy-NavDatabase -SourceDatabaseName "tenant" -DestinationDatabaseName "default"

                Write-Host "Mounting default tenant"
                Mount-NavDatabase -ServerInstance $ServerInstance -TenantId "default" -DatabaseName "default"

            } -argumentList $customconfig.DatabaseName, $customconfig.DatabaseServer, $customconfig.DatabaseInstance
        }

    }
    else {
    
        $installedApps = Get-BcContainerAppInfo -containerName $containerName -tenantSpecificProperties -sort DependenciesLast | Where-Object { $_.Name -ne "System Application" }
        $installedApps | % {
            $app = $_
            Invoke-ScriptInBCContainer -containerName $containerName -scriptblock { Param($app, $SaveData, $onlySaveBaseAppData)
                if ($app.IsInstalled) {
                    Write-Host "Uninstalling $($app.Name)"
                    $tenant = "Default"
                    if ($app.Tenant)
                    {
                      $tenant = $app.Tenant
                    }
                    $app | Uninstall-NavApp -tenant $tenant -Force -doNotSaveData:(!$SaveData -or ($Name -ne "BaseApp" -and $Name -ne "Base Application" -and $onlySaveBaseAppData))
                }
            } -argumentList $app, $SaveData, $onlySaveBaseAppData
        }
    
        if ($platformversion.Major -eq 14) {
            Invoke-ScriptInBcContainer -containerName $containerName -scriptblock { Param ( $customConfig )
                
                if ($customConfig.databaseInstance) {
                    $databaseServerInstance = "$($customConfig.databaseServer)\$($customConfig.databaseInstance)"
                }
                else {
                    $databaseServerInstance = $customConfig.databaseServer
                }
        
                Write-Host "Removing C/AL Application Objects"
                Delete-NAVApplicationObject -DatabaseName $customConfig.databaseName -DatabaseServer $databaseServerInstance -Filter 'ID=1..1999999999' -SynchronizeSchemaChanges Force -Confirm:$false
    
            } -argumentList $customconfig
        }
        else {
            if (!$doNotUnpublish) {
                $installedApps | % {
                    $app = $_
                    Invoke-ScriptInBCContainer -containerName $containerName -scriptblock { Param($app)
                        if ($app.IsPublished) {
                            Write-Host "Unpublishing $($app.Name)"
                            $app | UnPublish-NavApp
                        }
                    } -argumentList $app
                }
            }
        }
    }
}
Export-ModuleMember -Function Clean-BcContainerDatabase
