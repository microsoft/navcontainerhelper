﻿<# 
 .Synopsis
  Restore Business Central Database(s) from artifacts
 .Description
  Restore Business Central Databases to an external SQL Server from articacts.
  Windows Authentication to the SQL Server is required.
 .Parameter artifactUrl
  Url for application artifact to use for locating database .bak file
 .Parameter databaseServer
  database Server on which you want to restore the database(s)
 .Parameter databaseInstance
  database Instance on the database Server on which you want to restore the database(s)
 .Parameter databasePrefix
  database prefix to avoid conflicts on the SQL Server
 .Parameter databaseName
  database name (prefix will be inserted before the name) on the SQL Server.
 .Parameter bakFile
  Database backup file to restore. Default is to take the .bak file from the artifacts.
 .Parameter multitenant
  Include this switch if you want to split the database .bak file into an application database and a tenant template
 .Parameter async
  Include this parameter if you want to restore the database asynchronous. A file called <databasePrefix>databasescreated.txt will be created in the containerhelper folder when done
 .Parameter sqlTimeout
  SQL Timeout for database restore operations
#>
function Restore-BcDatabaseFromArtifacts {
    Param(
        [Parameter(Mandatory=$true)]
        [string] $artifactUrl,
        [Parameter(Mandatory=$true)]
        [string] $databaseServer,
        [Parameter(Mandatory=$false)]
        [string] $databaseInstance = "",
        [Parameter(Mandatory=$false)]
        [string] $databasePrefix = "",
        [Parameter(Mandatory=$true)]
        [string] $databaseName,
        [Parameter(Mandatory=$false)]
        [string] $bakFile,
        [switch] $multitenant,
        [switch] $async,
        [int] $sqlTimeout = -1
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {

    if ($databaseServer -eq 'host.containerhelper.internal') {
        $databaseServer = 'localhost'
    }
    $successFileName = ""
    if ($async) {
        $successFileName = Join-Path $bcContainerHelperConfig.hostHelperFolder "$($databasePrefix)databasescreated.txt"
        if (Test-Path $successFileName) { Remove-Item $successFileName -Force }
    }
    Write-Host "Starting Database Restore job from $($artifactUrl.split('?')[0])"
    $containerHelperPath = (Get-Item (Join-Path $PSScriptRoot "..\Import-BcContainerHelper.ps1")).FullName
    Write-Host $containerHelperPath

    $job = Start-Job -ScriptBlock { Param( $containerHelperPath, $artifactUrl, $databaseServer, $databaseInstance, $databasePrefix, $databaseName, $multitenant, $successFileName, $bakFile, $sqlTimeout )
        $ErrorActionPreference = "Stop"
        try {
            . "$containerHelperPath"
            Write-Host "Downloading Artifacts $($artifactUrl.Split('?')[0])"
            $artifactPath = Download-Artifacts $artifactUrl -includePlatform
            
            $ManagementModule = Get-Item -Path (Join-Path $artifactPath[1] "ServiceTier\program files\Microsoft Dynamics NAV\*\Service\Microsoft.Dynamics.Nav.Management.dll")
            if (!($ManagementModule)) {
                $ManagementModule = Get-Item -Path (Join-Path $artifactPath[1] "ServiceTier\program files\Microsoft Dynamics NAV\*\Service\Management\Microsoft.Dynamics.Nav.Management.dll")
                if (!($ManagementModule)) {
                    throw "Unable to locate management module in artifacts"
                }
            }

            $manifest = Get-Content -Path (Join-Path $artifactPath[0] "manifest.json") | ConvertFrom-Json
            if ($bakFile) {
                if (!(Test-Path $bakFile)) {
                    throw "Database backup ($bakFile) doesn't exist"
                }
                Write-Host "Using bakFile $bakfile"
            }
            else {
                $bakFile = Join-Path $artifactPath[0] $manifest.database
                if (!(Test-Path $bakFile)) {
                    throw "Unable to locate database backup in artifacts"
                }
            }

            Write-Host "Importing PowerShell module $($ManagementModule.FullName)"
            Import-Module $ManagementModule.FullName -NoClobber

            $databaseServerInstance = $databaseServer
            if ($databaseInstance) {
                $databaseServerInstance += "\$databaseInstance"
            }

            $dbName = "$databasePrefix$databaseName"
            if ($multitenant) {
                $dbName = "$($databasePrefix)tenant"
            }
            Import-Module sqlps -ErrorAction SilentlyContinue
            $sqlpsModule = get-module sqlps
            if (-not $sqlpsModule) {
                import-module SqlServer
                $SqlModule = get-module SqlServer
                if (-not $SqlModule) {
                    throw "You need to have a local installation of SQL or you need the SqlServer PowerShell module installed"
                }
            }
            $sqlParams = @{
                "ServerInstance" = $databaseserverinstance
            }
            $function = Get-Command 'Invoke-SqlCmd' -ErrorAction SilentlyContinue
            if ($null -eq $function) {
                throw "Invoke-SqlCmd not found, please install the SqlServer module"
            }
            if ($function.Parameters.ContainsKey('TrustServerCertificate')) {
                $sqlParams += @{ "TrustServerCertificate" = $true }
            }
        
            $DefaultDataPath = (Invoke-SqlCmd @sqlParams `
                -Query "SELECT SERVERPROPERTY('InstanceDefaultDataPath') AS InstanceDefaultDataPath" ).InstanceDefaultDataPath

            if($databaseServer -ne 'localhost'){
                # Copy local database to SQL Server
                $defaultBackupPath = (Invoke-SqlCmd @sqlParams `
                    -Query "SELECT SERVERPROPERTY('InstanceDefaultBackupPath') AS InstanceDefaultBackupPath" ).InstanceDefaultBackupPath

                $qualifier = $defaultBackupPath | Split-Path -Qualifier
                $newQualifier = '\\{0}\{1}' -f $databaseServer, $qualifier.Replace(':','$').ToLower()
                $uncDefaultBackupPath = $defaultBackupPath.Replace($qualifier, $newQualifier)

                Copy-Item -Path $bakFile -Destination $uncDefaultBackupPath -Force

                $bakFile = "$($defaultBackupPath.TrimEnd('\'))\$($bakFile | Split-Path -Leaf)"
            }

            $destinationPath = "$($DefaultDataPath.TrimEnd('\'))\$($databaseprefix -replace '[^a-zA-Z0-9]', '')"

            # Create destination folder
            if($databaseServer -ne 'localhost'){
                $qualifier = $destinationPath | Split-Path -Qualifier
                $newQualifier = '\\{0}\{1}' -f $databaseServer, $qualifier.Replace(':','$').ToLower()
                if((Test-Path $destinationPath.Replace($qualifier, $newQualifier)) -eq $false){
                    New-Item -Path $destinationPath.Replace($qualifier, $newQualifier) -ItemType Directory -Force
                }
            } else {
                if((Test-Path $destinationPath) -eq $false){
                    New-Item -Path $destinationPath -ItemType Directory -Force
                }
            }

            $newNavDBparams = @{
                "DatabaseInstance" = $databaseInstance
                "DatabaseServer"   = $databaseServer
                "DatabaseName"     = $dbName
                "FilePath"         = $bakFile
                "DestinationPath"  = $destinationPath
            }
            if ($sqlTimeout -ge 0) {
                $newNavDBparams += @{ "timeout" = $sqlTimeout }
            }

            Write-Host "Restoring database $dbName into $destinationPath"
            New-NAVDatabase @newNavDBparams | Out-Null

            if ($multitenant) {
                if ($sqlpsModule) {
                    $smoServer = New-Object Microsoft.SqlServer.Management.Smo.Server $databaseServerInstance
                    $Smo = [reflection.assembly]::Load("Microsoft.SqlServer.Smo, Version=$($smoServer.VersionMajor).$($smoServer.VersionMinor).0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91")
                    $SmoExtended = [reflection.assembly]::Load("Microsoft.SqlServer.SmoExtended, Version=$($smoServer.VersionMajor).$($smoServer.VersionMinor).0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91")
                    $ConnectionInfo = [reflection.assembly]::Load("Microsoft.SqlServer.ConnectionInfo, Version=$($smoServer.VersionMajor).$($smoServer.VersionMinor).0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91")
                    $SqlEnum = [reflection.assembly]::Load("Microsoft.SqlServer.SqlEnum, Version=$($smoServer.VersionMajor).$($smoServer.VersionMinor).0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91")
                }           
                else {
                    $Path = Split-Path $SqlModule.Path
                    $Smo = [Reflection.Assembly]::LoadFile((Join-Path $Path 'Microsoft.SqlServer.Smo.dll'))
                    $SmoExtended = [Reflection.Assembly]::LoadFile((Join-Path $Path 'Microsoft.SqlServer.SmoExtended.dll'))
                    $ConnectionInfo = [Reflection.Assembly]::LoadFile((Join-Path $Path 'Microsoft.SqlServer.ConnectionInfo.dll'))
                    $SqlEnum = [Reflection.Assembly]::LoadFile((Join-Path $Path 'Microsoft.SqlServer.SqlEnum.dll'))
                }

                $OnAssemblyResolve = [System.ResolveEventHandler] {
                    param($sender, $e)
                    if ($e.Name -like "Microsoft.SqlServer.Smo, Version=*, Culture=neutral, PublicKeyToken=89845dcd8080cc91") { return $Smo }
                    if ($e.Name -like "Microsoft.SqlServer.SmoExtended, Version=*, Culture=neutral, PublicKeyToken=89845dcd8080cc91") { return $SmoExtended }
                    if ($e.Name -like "Microsoft.SqlServer.ConnectionInfo, Version=*, Culture=neutral, PublicKeyToken=89845dcd8080cc91") { return $ConnectionInfo }
                    if ($e.Name -like "Microsoft.SqlServer.SqlEnum, Version=*, Culture=neutral, PublicKeyToken=89845dcd8080cc91") { return $SqlEnum }
                    foreach($a in [System.AppDomain]::CurrentDomain.GetAssemblies()) {
                        if ($a.FullName -eq $e.Name) { return $a }
                    }
                    return $null
                }
                [System.AppDomain]::CurrentDomain.add_AssemblyResolve($OnAssemblyResolve)

                Write-Host "Exporting Application to $databasePrefix$databaseName"
                Export-NAVApplication `
                    -DatabaseServer $databaseServer `
                    -DatabaseInstance $databaseInstance `
                    -DatabaseName "$($databasePrefix)tenant" `
                    -DestinationDatabaseName "$databasePrefix$databaseName" `
                    -Force | Out-Null

                Write-Host "Removing Application from $($databasePrefix)tenant"
                Remove-NAVApplication `
                    -DatabaseServer $databaseServer `
                    -DatabaseInstance $databaseInstance `
                    -DatabaseName "$($databasePrefix)tenant" `
                    -Force | Out-Null

                [System.AppDomain]::CurrentDomain.remove_AssemblyResolve($OnAssemblyResolve)
            }
            Write-Host "Success"
            if ($successFileName) {
                Set-Content -Path $successFileName -Value "Success"
            }
        }
        catch {
            if ($successFileName) {
                Set-Content -Path $successFileName -Value "Error restoring databases. Error was $($_.Exception.Message)`n$($_.ScriptStackTrace)"
            }
            throw
        }
    
    } -ArgumentList $containerHelperPath, $artifactUrl, $databaseServer, $databaseInstance, $databasePrefix, $databaseName, $multitenant, $successFileName, $bakFile, $sqlTimeout

    if (!$async) {
        While ($job.State -eq "Running") {
            Start-Sleep -Seconds 1
            $job | Receive-Job
        }
        $job | Receive-Job
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
Export-ModuleMember -Function Restore-BcDatabaseFromArtifacts
