<# 
 .Synopsis
  Generate application symbols in a Nav Container
 .Description
  Create a session to a Nav container and run finsql command to generate application symbols
 .Parameter containerName
  Name of the container in which you want to generate application symbols
 .Example
  Create-ApplicationSymbolsInNavContainer -containerName test2
#>
function Create-ApplicationSymbolsInNavContainer {
    Param(
        [Parameter(Mandatory = $true)]
        [string]$containerName
    )

    $session = Get-NavContainerSession -containerName $containerName -silent
    
    Invoke-Command -Session $session -ScriptBlock { Param($containerName)
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
    
    Write-Host -ForegroundColor Green "Application symbols successfully created"
    
    
    
    
    
    
    
    
    
    
    
    
    
    Invoke-Command -Session $session -ScriptBlock { Param($filter, [System.Management.Automation.PSCredential]$sqlCredential)

        $customConfigFile = Join-Path (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName "CustomSettings.config"
        [xml]$customConfig = [System.IO.File]::ReadAllText($customConfigFile)
        $databaseServer = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseServer']").Value
        $databaseInstance = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseInstance']").Value
        $databaseName = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseName']").Value
        if ($databaseInstance) { $databaseServer += "\$databaseInstance" }

        $enableSymbolLoadingKey = $customConfig.SelectSingleNode("//appSettings/add[@key='EnableSymbolLoadingAtServerStartup']")
        if ($enableSymbolLoadingKey -ne $null -and $enableSymbolLoadingKey.Value -eq "True") {
            # HACK: Parameter insertion...
            # generatesymbolreference is not supported by Compile-NAVApplicationObject yet
            # insert an extra parameter for the finsql command by splitting the filter property
            $filter = '",generatesymbolreference=1,filter="' + $filter
        }

        $params = @{}
        if ($sqlCredential) {
            $params = @{ 'Username' = $sqlCredential.UserName; 'Password' = ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sqlCredential.Password))) }
        }
        Write-Host "Compiling objects"
        Compile-NAVApplicationObject @params -Filter $filter `
            -DatabaseName $databaseName `
            -DatabaseServer $databaseServer `
            -Recompile `
            -SynchronizeSchemaChanges Force `
            -NavServerName localhost `
            -NavServerInstance NAV `
            -NavServerManagementPort 7045

    } -ArgumentList $filter, $sqlCredential
    Write-Host -ForegroundColor Green "Objects successfully compiled"
}
Export-ModuleMember -Function Create-ApplicationSymbolsInNavContainer
