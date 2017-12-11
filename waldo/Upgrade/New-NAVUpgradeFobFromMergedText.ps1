function New-NAVUpgradeFobFromMergedText
{
    [CmdLetBinding()]
    param(
        
        [String] $TargetServerInstance,
        [String] $LicenseFile,
        [String] $TextFileFolder,
        [String] $WorkingFolder,
        [String] $FobFileForCreatingUnlicensedObjects,
        [String] $ResultFobFile,
        [Switch] $Force

    )

    
    $TargetServerInstanceObject = Get-NAVServerInstance4 -ServerInstance $TargetServerInstance -ErrorAction Stop
    $SandboxInstance = "$($TargetServerInstance)_Sandbox"

    $SandboxInstanceObject = Get-NAVServerInstance4 -ServerInstance $SandboxInstance
    if ($SandboxInstanceObject){
        if (Confirm-YesOrNo -title "Remove $SandboxInstance ?" -message "The Sandbox DB '$SandboxInstance' already exist.  Remove?" ){
            Remove-NAVEnvironment -ServerInstance $SandboxInstance -Force

            Copy-NAVEnvironment -ServerInstance $TargetServerInstance -ToServerInstance $SandboxInstance
        }
    } else {
        #Create WorkingDB
        Copy-NAVEnvironment -ServerInstance $TargetServerInstance -ToServerInstance $SandboxInstance
    }

    $SandboxInstanceObject = Get-NAVServerInstanceDetails -ServerInstance $SandboxInstance
    
    #Creating Workspace
    $LogFolder = Join-Path $WorkingFolder 'Log_NAVUpgradeFobFromMergedText'
    if(Test-Path $LogFolder){Remove-Item $LogFolder -Force -Recurse}
    $LogImportFob        = join-path $LogFolder '01_ImportFob'
    $LogImportText       = join-path $LogFolder '02_ImportText'
    $LogCompileObjects   = join-path $LogFolder '03_CompileObjects'
    $LogResultObjectFile = join-path $LogFolder '04_ExportFob'
        
    #Make Admin user DB-Owner
    $CurrentUser = [environment]::UserDomainName + '\' + [Environment]::UserName
    Invoke-SQL -DatabaseServer $TargetServerInstanceObject.DatabaseServer -DatabaseInstance $TargetServerInstanceObject.DatabaseInstance -DatabaseName $SandboxInstance -SQLCommand "CREATE USER [$CurrentUser] FOR LOGIN [$CurrentUser]" -ErrorAction Continue
    Invoke-SQL -DatabaseServer $TargetServerInstanceObject.DatabaseServer -DatabaseInstance $TargetServerInstanceObject.DatabaseInstance -DatabaseName $SandboxInstance -SQLCommand "ALTER ROLE [db_owner] ADD MEMBER [$CurrentUser]" -ErrorAction Continue

    #Drop ReVision Triggers
    Invoke-SQL -DatabaseServer $TargetServerInstanceObject.DatabaseServer -DatabaseInstance $TargetServerInstanceObject.DatabaseInstance -DatabaseName $SandboxInstance -SQLCommand 'DISABLE TRIGGER [dbo].[REVISION_UPDATE] ON [dbo].[Object]' -ErrorAction Continue
    Invoke-SQL -DatabaseServer $TargetServerInstanceObject.DatabaseServer -DatabaseInstance $TargetServerInstanceObject.DatabaseInstance -DatabaseName $SandboxInstance -SQLCommand 'DISABLE TRIGGER [dbo].[REVISION_INSERT] ON [dbo].[Object]' -ErrorAction Continue
    Invoke-SQL -DatabaseServer $TargetServerInstanceObject.DatabaseServer -DatabaseInstance $TargetServerInstanceObject.DatabaseInstance -DatabaseName $SandboxInstance -SQLCommand 'DISABLE TRIGGER [dbo].[REVISION_DELETE] ON [dbo].[Object]' -ErrorAction Continue

    #Import NAV LIcense
    if (!([string]::IsNullOrEmpty($LicenseFile))){
        Write-Host "Import NAV license in $SandboxInstance" -ForegroundColor Green
        Get-NAVServerInstance -ServerInstance $SandboxInstance | Import-NAVServerLicense -LicenseFile $LicenseFile -Database NavDatabase -WarningAction SilentlyContinue -ErrorAction Stop
        Set-NAVServerInstance -Restart -ServerInstance $SandboxInstance -ErrorAction continue
    }
     
    if (!([string]::IsNullOrEmpty($TargetServerInstanceObject.DatabaseInstance))){
        $DatabaseServer = "$($TargetServerInstanceObject.DatabaseServer)\$($TargetServerInstanceObject.DatabaseInstance)"
    } else
    {
        $DatabaseServer = $TargetServerInstanceObject.DatabaseServer
    }

    #Import unlicensed objects  
    if ($FobFileForCreatingUnlicensedObjects) {
        Write-host 'Import Fob for Unlicensed objects' -ForegroundColor Green
            $null = 
                Import-NAVApplicationObject `
                    -DatabaseServer $DatabaseServer `
                    -DatabaseName $SandboxInstance `
                    -Path $FobFileForCreatingUnlicensedObjects `
                    -LogPath $LogImportFob `
                    -NavServerName ([net.dns]::GetHostName()) `
                    -NavServerInstance $SandboxInstance `
                    -confirm:$false `
                    -ErrorAction continue `
                    -SynchronizeSchemaChanges No `
                    -ImportAction Overwrite
    }
    
    #Import Objects
    Write-Host 'Import Merged Objects' -ForegroundColor Green
    Write-Host '-> Make sure you have the necessary dlls in the client Add-ins folder!'  -ForegroundColor Green
    Set-NAVServerInstance -Stop -ServerInstance $SandboxInstance
    #Get-Service (Get-navserverinstance $SandboxInstance).ServerInstance | Set-Service -StartupType Disabled
    $ObjectsToImport = Get-ChildItem $TextFileFolder -Filter '*.txt'
    $count = $ObjectsToImport.Count
    $i = 0
    foreach ($ObjectToImport in $ObjectsToImport) {
        $i++
        #Write-Progress -Activity 'Importing Objects' -Status "($i/$count) - $($ObjectToImport.Basename)" -PercentComplete (($i/$count)*100)
        Write-Verbose "($i/$count) - Importing $($ObjectToImport.Fullname)"

        $null = 
            Import-NAVApplicationObject `
                -DatabaseServer $DatabaseServer `
                -DatabaseName $SandboxInstance `
                -Path $ObjectToImport.Fullname `
                -LogPath $LogImportText `
                -confirm:$false `
                -ErrorAction continue `
                -ImportAction Overwrite `
                -SynchronizeSchemaChanges No  
    }
        
    #Compile Objects
    write-host 'Compile System Tables' -ForegroundColor Green
    $null = Compile-NAVApplicationObject `
                -DatabaseServer $DatabaseServer `
                -DatabaseName $SandboxInstance `
                -LogPath $LogCompileObjects `
                -SynchronizeSchemaChanges No `
                -Filter 'ID=2000000000..' `
                -Recompile `
                -ErrorAction Continue 

    write-host 'Compile Menusuites' -ForegroundColor Green
    $null = Compile-NAVApplicationObject `
                -DatabaseServer $DatabaseServer `
                -DatabaseName $SandboxInstance `
                -LogPath $LogCompileObjects `
                -SynchronizeSchemaChanges No `
                -Filter 'Type=MenuSuite' `
                -Recompile `
                -ErrorAction Continue 

    Write-Host 'Compile Uncompiled' -ForegroundColor Green
    $null = Compile-NAVApplicationObject `
                -DatabaseServer $DatabaseServer `
                -DatabaseName $SandboxInstance `
                -LogPath $LogCompileObjects `
                -SynchronizeSchemaChanges No `
                -ErrorAction Continue 

    #Set-NAVServerInstance -Start ServerInstance $SandboxInstance

    if ((Get-ChildItem $LogCompileObjects | where Name -eq 'naverrorlog.txt').Count -gt 0)
    {      
        if (!$Force){  
            if (!(Confirm-YesOrNo -Title 'There are still uncompiled objects' -Message "There are still uncompiled objects `n Do you want to continue and create fob?")){
                Break    
            }
        }
    } 
    

    #Export Result
    if (!($ResultFobFile)){
        $ResultFobFile = Join-Path $WorkingFolder 'result.fob'
    }
    Write-Host "Export $ResultFobFile" -ForegroundColor Green
    $null = Export-NAVApplicationObject `
        -DatabaseServer $DatabaseServer `
        -DatabaseName $SandboxInstance `
        -Path $ResultFobFile `
        -LogPath $LogResultObjectFile `
        -ExportTxtSkipUnlicensed `
        -Force `
        -ErrorAction Continue       

    #Remove WorkingDB
    if (!$Force){
        if (!(Confirm-YesOrNo -Title "Remove Temporary DB" -Message "Do you want to continue and remove the Sandbox DB?")){
            return (get-item $ResultFobFile) 
            break   
        }
    }

    Write-Host "Remove Temporary DB $SandboxInstance" -ForegroundColor Green
    Remove-NAVEnvironment -ServerInstance $SandboxInstance -Force

    return (get-item $ResultFobFile)
}

