<# 
 .Synopsis
  Generate application symbols in a Nav Container
 .Description
  Create a session to a Nav container and run finsql command to generate application symbols
 .Parameter containerName
  Name of the container in which you want to generate application symbols
 .Parameter sqlCredential
  Credentials for the SQL admin user if using NavUserPassword authentication. User will be prompted if not provided 
 .Example
  Generate-SymbolsInNavContainer -containerName test2
 .Example
  Generate-SymbolsInNavContainer -containerName test2 -sqlCredential (get-credential -credential 'sa') 
#>
function Generate-SymbolsInNavContainer {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [PSCredential] $sqlCredential = $null
    )

    AssumeNavContainer -containerOrImageName $containerName -functionName $MyInvocation.MyCommand.Name

    Invoke-ScriptInNavContainer -containerName $containerName -ScriptBlock { Param($containerName, $sqlCredential)
        $customConfigFile = Join-Path (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName "CustomSettings.config"
        [xml]$customConfig = [System.IO.File]::ReadAllText($customConfigFile)
        $databaseServer = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseServer']").Value
        $databaseInstance = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseInstance']").Value
        $databaseName = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseName']").Value
        if ($databaseInstance) { $databaseServer += "\$databaseInstance" }
    
        $roleTailoredBasePath = "C:\Program Files (x86)\Microsoft Dynamics NAV\*\RoleTailored Client"    
    
        $ProcessArguments = @()
        $ProcessArguments += "Command=generatesymbolreference, Database=""$databaseName"", ServerName=""$databaseServer"""
        if ($sqlCredential) {
            Write-Host "Adding SQL-Server credentials for authentication"
            $ProcessArguments += ", ntauthentication=0, username=""$($sqlCredential.UserName)"", password=""$([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sqlCredential.Password)))"""
        }

        Write-Host "Creating application symbols in $containerName"
    
        $Process = Start-Process -FilePath (Join-Path (Get-Item $roleTailoredBasePath).FullName "finsql.exe") -ArgumentList $ProcessArguments -PassThru
    
        Wait-Process -Id $Process.Id
    
        if ($Process.ExitCode -ne 0) {
            $Result = Get-Content -Path (Join-Path (Get-Item $roleTailoredBasePath).FullName "naverrorlog.txt")
            Write-Error ([system.String]::Join("`n", $result))
        }
        else {
            $Result = Get-Content -Path (Join-Path (Get-Item $roleTailoredBasePath).FullName "navcommandresult.txt")
            Write-Host ([system.String]::Join("`n", $result))
        }
    } -ArgumentList $containerName, $sqlCredential
    
    Write-Host -ForegroundColor Green "Symbols successfully generated"
}
Export-ModuleMember -Function Generate-SymbolsInNavContainer
