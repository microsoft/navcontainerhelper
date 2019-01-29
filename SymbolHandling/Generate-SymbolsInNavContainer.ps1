<# 
 .Synopsis
  Generate application symbols in a Nav Container
 .Description
  Create a session to a Nav container and run finsql command to generate application symbols
 .Parameter containerName
  Name of the container in which you want to generate application symbols
 .Example
  Generate-SymbolsInNavContainer -containerName test2
#>
function Generate-SymbolsInNavContainer {
    Param(
        [Parameter(Mandatory = $true)]
        [string]$containerName
    )

    Invoke-ScriptInNavContainer -containerName $containerName -ScriptBlock { Param($containerName)
        $customConfigFile = Join-Path (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName "CustomSettings.config"
        [xml]$customConfig = [System.IO.File]::ReadAllText($customConfigFile)
        $databaseServer = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseServer']").Value
        $databaseInstance = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseInstance']").Value
        $databaseName = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseName']").Value
        if ($databaseInstance) { $databaseServer += "\$databaseInstance" }
    
        $roleTailoredBasePath = "C:\Program Files (x86)\Microsoft Dynamics NAV\*\RoleTailored Client"    
    
        $ProcessArguments = @()
        $ProcessArguments += "Command=generatesymbolreference, Database=""$databaseName"", ServerName=""$databaseServer"""
    
        Write-Host "Creating application symbols in $containerName"
    
        $Process = Start-Process -FilePath (Join-Path (Get-Item $roleTailoredBasePath).FullName "finsql.exe") -ArgumentList $ProcessArguments -PassThru
    
        Wait-Process -Id $Process.Id
    
        if ($Process.ExitCode -ne 0) {
            $Result = Get-Content -Path (Join-Path (Get-Item $roleTailoredBasePath).FullName "naverrorlog.txt")
            Write-Error $Result
        }
        else {
            $Result = Get-Content -Path (Join-Path (Get-Item $roleTailoredBasePath).FullName "navcommandresult.txt")
            Write-Host $Result
        }
    } -ArgumentList $containerName
    
    Write-Host -ForegroundColor Green "Symbols successfully generated"
}
Export-ModuleMember -Function Generate-SymbolsInNavContainer