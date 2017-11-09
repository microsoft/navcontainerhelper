<# 
 .Synopsis
  Compile Objects to Nav Container
 .Description
  Create a session to a Nav container and run Compile-NavApplicationObject
 .Parameter containerName
  Name of the container for which you want to enter a session
 .Parameter filter
  filter of the objects you want to compile (default is modified=Yes)
 .Parameter vmadminUsername
  Username of the administrator user in the container (defaults to sa)
 .Parameter adminPassword
  Password of the administrator user in the container (if using NavUserPassword authentication)
 .Example
  Compile-ObjectsToNavContainer -containerName test2 -adminPassword <adminpassword>
#>
function Compile-ObjectsInNavContainer {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName, 
        [string]$filter = "modified=Yes", 
        [string]$vmadminUsername = 'sa',
        [SecureString]$adminPassword = $null
    )

    $containerAuth = Get-NavContainerAuth -containerName $containerName
    if ($containerAuth -eq "NavUserPassword" -and !($adminPassword)) {
        $adminPassword = Get-DefaultAdminPassword
    }

    $session = Get-NavContainerSession -containerName $containerName
    Invoke-Command -Session $session -ScriptBlock { Param($filter, $vmadminUsername, $adminPassword)

        $customConfigFile = Join-Path (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName "CustomSettings.config"
        [xml]$customConfig = [System.IO.File]::ReadAllText($customConfigFile)
        $databaseServer = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseServer']").Value
        $databaseInstance = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseInstance']").Value
        $databaseName = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseName']").Value
        if ($databaseInstance) { $databaseServer += "\$databaseInstance" }

        $params = @{}
        if ($adminPassword) {
            $params = @{ 'Username' = $vmadminUsername; 'Password' = ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($adminPassword))) }
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

    } -ArgumentList $filter, $vmadminUsername, $adminPassword
    Write-Host -ForegroundColor Green "Objects successfully compiled"
}
Export-ModuleMember -Function Compile-ObjectsInNavContainer
