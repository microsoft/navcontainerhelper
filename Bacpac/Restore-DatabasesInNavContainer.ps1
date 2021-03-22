<# 
 .Synopsis
  Restore databases in a NAV/BC Container from .bak files
 .Description
  If the Container is multi-tenant, this command will restore an app.bak and a number of tenant databases
  If the Container is single-tenant, this command will restore one .bak file called database.bak.
 .Parameter containerName
  Name of the container in which you want to restore databases
 .Parameter bakFolder
  The folder to which the bak files are exported (default is the container folder c:\programdata\bccontainerhelper\extensions\<containername>)
 .Parameter tenant
  The tenant database(s) to restore, only applies to multi-tenant containers. Omit to restore all tenants
 .Parameter sqlTimeout
  SQL Timeout for database restore operations
 .Example
  Restore-DatabasesInBcContainer -containerName test
 .Example
  Restore-DatabasesInBcContainer -containerName test -tenant @("default")
 .Example
  Restore-DatabasesInBCContainer -containerName test -bakFile C:\ProgramData\bccontainerhelper\mydb.bak -databaseFolder "c:\databases\mydb"
#>
function Restore-DatabasesInBcContainer {
    Param(
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName, 
        [string] $bakFolder = "",
        [string] $bakFile = "",
        [string] $databaseName = "",
        [string[]] $tenant,
        [Parameter(Mandatory=$false)]
        [string] $databaseFolder = "c:\databases",
        [int] $sqlTimeout = 300
    )

    $containerBakFile = ""
    $containerBakFolder = ""

    if ($bakFile) {
        if ($bakFolder) {
            throw "You cannot specify bakFolder when you specify bakFile"
        }
        if ($tenant) {
            throw "You cannot specify tenant when you specify bakFile"
        }
        $containerBakFile = Get-BcContainerPath -containerName $containerName -path $bakFile -throw
        if (-not $databaseName) {
            $databaseName = [System.IO.Path]::GetFileNameWithoutExtension($bakFile)
        }
    }
    elseif ($databaseName) {
        throw "You need to specify bakFile when you specify databaseName"
    }
    else {
        $containerFolder = Join-Path $ExtensionsFolder $containerName
        if ("$bakFolder" -eq "") {
            $bakFolder = $containerFolder
        }
        elseif (!$bakFolder.Contains('\')) {
            $navversion = Get-BcContainerNavversion -containerOrImageName $containerName
            if ((Invoke-ScriptInBcContainer -containerName $containerName -scriptblock { $env:IsBcSandbox }) -eq "Y") {
                $folderPrefix = "sandbox"
            }
            else {
                $folderPrefix = "onprem"
            }
            $bakFolder = Join-Path $containerHelperFolder "$folderPrefix-$NavVersion-bakFolders\$bakFolder"
        }
        $containerBakFolder = Get-BcContainerPath -containerName $containerName -path $bakFolder -throw
    }

    Invoke-ScriptInBCContainer -containerName $containerName -scriptblock { Param($bakFolder, $bakFile, $databaseName, $tenant, $databaseFolder, $sqlTimeout)

        function Restore {
            Param (
                [string] $databaseServer,
                [string] $databaseInstance,
                [string] $databaseName,
                [string] $bakFile,
                [string] $databaseFolder,
                [int] $sqlTimeout
            )
            if (!(Test-Path -Path $bakFile -PathType Leaf)) {
                throw "Database backup $bakFile not found"
            }
            if (Test-NavDatabase -DatabaseServer $databaseServer `
                                 -DatabaseInstance $databaseInstance `
                                 -DatabaseName $databaseName) {

                Remove-NavDatabase -DatabaseServer $databaseServer `
                                   -DatabaseInstance $databaseInstance `
                                   -DatabaseName $databaseName
            }
        
            Write-Host "Restoring $bakFile to $databaseName"
            New-NAVDatabase -DatabaseServer $databaseServer `
                            -DatabaseInstance $databaseInstance `
                            -DatabaseName $databaseName `
                            -FilePath $bakFile `
                            -DestinationPath $databaseFolder `
                            -Timeout $SqlTimeout | Out-Null
        }

        $customConfigFile = Join-Path (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName "CustomSettings.config"
        [xml]$customConfig = [System.IO.File]::ReadAllText($customConfigFile)
        $multitenant = ($customConfig.SelectSingleNode("//appSettings/add[@key='Multitenant']").Value -eq "true")
        $databaseServer = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseServer']").Value
        $databaseInstance = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseInstance']").Value

        if ($bakFile) {
            Restore -databaseServer $databaseServer -databaseInstance $databaseInstance -databaseName $DatabaseName -bakFile $bakFile -databaseFolder $databaseFolder -sqlTimeout $sqlTimeout
        }
        else {
            $databaseName = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseName']").Value
    
            if ($multitenant -and !($tenant)) {
                $tenant = @(get-navtenant $serverInstance | % { $_.Id }) + "tenant"
            }
    
            Set-NavServerInstance -ServerInstance $serverInstance -stop
    
            if ($multitenant) {
                Restore -databaseServer $databaseServer -databaseInstance $databaseInstance -databaseName $DatabaseName -bakFile (Join-Path $bakFolder "app.bak") -databaseFolder $databaseFolder -sqlTimeout $sqlTimeout
                $tenant | ForEach-Object {
                    Restore -databaseServer $databaseServer -databaseInstance $databaseInstance -databaseName $_ -bakFile (Join-Path $bakFolder "$_.bak") -databaseFolder $databaseFolder -sqlTimeout $sqlTimeout
                }
            } else {
                Restore -databaseServer $databaseServer -databaseInstance $databaseInstance -databaseName $DatabaseName -bakFile (Join-Path $bakFolder "database.bak") -databaseFolder $databaseFolder -sqlTimeout $sqlTimeout
            }
    
            Set-NavServerInstance -ServerInstance $serverInstance -start
        }
    
    } -argumentList $containerBakFolder, $containerBakFile, $databaseName, $tenant, $databaseFolder, $sqlTimeout

    if (Test-Path -Path "C:\ProgramData\BcContainerHelper\Extensions\$containerName\PsTestTool-*") {
        Get-Item -Path "C:\ProgramData\BcContainerHelper\Extensions\$containerName\PsTestTool-*" | % {
            Remove-Item -Path $_.FullName -Force -Recurse
        }
    }

}
Set-Alias -Name Restore-DatabasesInNavContainer -Value Restore-DatabasesInBcContainer
Export-ModuleMember -Function Restore-DatabasesInBcContainer -Alias Restore-DatabasesInNavContainer

