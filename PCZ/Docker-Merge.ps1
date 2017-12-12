
function Export-Objects($path, $inputPath, $outputPath)
{
    $logs = Join-Path -Path $path "Logs"
    $FileList = Get-ChildItem -Path (Join-Path $path $inputPath)
    $exportPath = Join-Path -Path $path $outputPath
    ForEach ($file in $FileList)
    {
        $id = $file.BaseName.Substring(3)
        switch ($file.BaseName.Substring(0,3))
        {
            "TAB" { $type = "Table" }
            "PAG" { $type = "Page" }
            "REP" { $type = "Report" }
            "COD" { $type = "Codeunit" }
            "QUE" { $type = "Query" }
            "XML" { $type = "XMLport" }
            "MEN" { $type = "MenuSuite" }
        }
       
        $filter = "Type=%0;Id=%1"
        $filter = $filter.Replace("%0", $type)
        $filter = $filter.Replace("%1", $id)

        Write-Host "$type $id"
        Export-NAVApplicationObject -DatabaseName CronusNA -Path (Join-Path -path $exportPath $file.Name) -DatabaseServer localhost\SQLEXPRESS -LogPath (Join-Path $logs "MergeTargetExport") -Filter $filter -Force -ExportTxtSkipUnlicensed -Username sa -Password Password1 | Out-Null
    }
}

function Continue-AfterMerge($RootPath, $ResultFilter)
{
    $LogPath = Join-Path -Path $RootPath "Logs"
    $ResPath = Join-Path -Path $RootPath "Results"
    $MergeResultPath = Join-Path $RootPath "MergeResult"

    Write-Host "Importing objects after merge"
    Get-ChildItem (Join-Path -Path $RootPath "MergeResult") -Filter "*.TXT" | Import-NAVApplicationObject -DatabaseName CronusNA -DatabaseServer localhost\SQLEXPRESS -ImportAction Overwrite -SynchronizeSchemaChanges Force -Username sa -Password Password1 -NavServerName localhost -NavServerInstance NAV -NavServerManagementPort 7045 -LogPath (Join-Path $LogPath "ImportAfterMerge") -Confirm:$false

    Write-Host "Compiling changed and new objects after merge" 
    Compile-NAVApplicationObject -DatabaseName CronusNA -DatabaseServer localhost\SQLEXPRESS -LogPath (Join-Path $LogPath "CompileAfterMerge") -SynchronizeSchemaChanges No -Username sa -Password Password1 -NavServerName localost -NavServerInstance NAV -NavServerManagementPort 7045 -ErrorAction SilentlyContinue
    Write-Host "Syncronizing tenant"
    Sync-NAVTenant -Tenant default -Mode ForceSync -ServerInstance NAV -Force
    Write-Host "Compiling all objects after merge"
    Compile-NAVApplicationObject -DatabaseName CronusNA -DatabaseServer localhost\SQLEXPRESS -LogPath (Join-Path $LogPath "CompileAfterMerge") -SynchronizeSchemaChanges No -Username sa -Password Password1 -NavServerName localost -NavServerInstance NAV -NavServerManagementPort 7045 -Recompile -ErrorAction SilentlyContinue
    Write-Host "Syncronizing tenant"
    Sync-NAVTenant -Tenant default -Mode ForceSync -ServerInstance NAV -Force

    Write-Host "Exporting objects after merge"
    Write-Host $ResultFilter
    Export-Objects -path $RootPath -inputPath "MergeModified" -outputPath (Join-Path -Path "Results" "Objects")
    Export-NAVApplicationObject -DatabaseName CronusNA -Path (Join-Path $ResPath "MergedObjects.fob") -DatabaseServer localhost\SQLEXPRESS -LogPath (Join-Path $LogPath "ExportAfterMerge") -Filter "$ResultFilter" -Force -Username sa -Password Password1 | Out-Null

    Remove-Item -Path $MergeResultPath -Recurse -Force
}

# =========================== start of script ===============================

$NAVClientManagementModule = "$roleTailoredClientFolder\Microsoft.Dynamics.Nav.Ide.psm1"
$NAVClientModelToolsModule = "$roleTailoredClientFolder\NavModelTools.ps1"
if (!(Test-Path $NAVClientManagementModule)) 
{
    Write-Error "Could not load Management Module"
}
if (!(Test-Path $NAVClientModelToolsModule)) 
{
    Write-Error "Could not load Model Tools Module"
}

Write-Host "Setting Confirm Preference = none"
$ConfPref = $ConfirmPreference
$ConfirmPreference = "none"
$logsPath = (Join-Path -Path $myPath "Logs")
$resultPath = (Join-Path -Path $myPath "Results")
$pathMergeSource = Join-Path -Path $myPath "MergeSource"
$pathMergeModified = Join-Path -Path $myPath "MergeModified"
$pathMergeTarget = Join-Path -Path $myPath "MergeTarget"
$pathMergeResult = Join-Path $myPath "MergeResult"

Import-Module $NAVClientManagementModule -DisableNameChecking | Out-Null
Import-Module $NAVClientModelToolsModule -DisableNameChecking | Out-Null

Write-Host "Importing objects"
$filelist = Get-ChildItem (Join-Path -Path $myPath "Source")
$currlog = (Join-Path $logsPath "ImportBeforeMerge")
ForEach ($file in $filelist)
{
    Write-Host $file.Name
    $file | Import-NAVApplicationObject -DatabaseName CronusNA -DatabaseServer localhost\SQLEXPRESS -ImportAction Overwrite -SynchronizeSchemaChanges Force -Username sa -Password Password1 -NavServerName localhost -NavServerInstance NAV -NavServerManagementPort 7045 -LogPath (Join-Path $logsPath "ImportBeforeMerge") -Confirm:$false
    if ((Get-Content -Path (Join-Path $currlog "navcommandresult.txt") | select-string -Pattern "The command completed successfully." -AllMatches).Count -eq 0)
    {
        Throw "Error Importing Objects"
    }
}

Write-Host "Compiling objects"
$currlog = Join-Path $logsPath "CompileBeforeMerge"
Compile-NAVApplicationObject -DatabaseName CronusNA -DatabaseServer localhost\SQLEXPRESS -LogPath $currlog -SynchronizeSchemaChanges Force -Username sa -Password Password1 -NavServerName localhost -NavServerInstance NAV -NavServerManagementPort 7045 -Recompile -ErrorAction SilentlyContinue
if ((Get-Content -Path (Join-Path $currlog "navcommandresult.txt") | select-string -Pattern "The command completed" -AllMatches).Count -eq 0) # could be that it had errors
{
    Throw "Error compiling objects"
}

Write-Host "Exporting objects for merging"
Export-Objects -path $myPath -inputPath "MergeModified" -outputPath "MergeTarget"

Write-Host "Merging objects"
$objects = Merge-NAVApplicationObject -OriginalPath $pathMergeSource -ModifiedPath $pathMergeModified -TargetPath $pathMergeTarget -ResultPath $pathMergeResult -DateTimeProperty Now -ModifiedProperty Yes -VersionListProperty FromTarget -DocumentationConflict TargetFirst  -DisableCommentOut -Force

Write-Host "Adjusting object properties; version list = $NewVersionList"
# update version list, date/time, and modified flag
$objects | Where-Object MergeResult -eq "Merged" | ForEach { Set-NAVApplicationObjectProperty -TargetPath $_.Result -VersionListProperty ($_.Target.VersionList + "," + $NewVersionList) -ModifiedProperty No -DateTimeProperty (Get-Date -Hour 12 -Minute 0 -Second 0 -Millisecond 0 -Format g) }

if (($objects | Where-Object MergeResult -eq "Conflict") -eq $null)
{
    Continue-AfterMerge -RootPath $myPath -ResultFilter $ResultFilter
}
else
{
    Write-Error "Merge resulted in Conflicts:"
    $objects | Where-Object MergeResult -eq "Conflict" | ForEach { Write-Host "    $_.Result" }
}

Write-Host "Resetting Confirm Preference"
$ConfirmPreference = $ConfPref

# =========================== end of script ===============================
