<# 
 .Synopsis
  Export objects from a Nav container
 .Description
  Creates a session to the Nav container and launch the Export-NavApplicationObjects Cmdlet to export object
 .Parameter containerName
  Name of the container for which you want to enter a session
 .Parameter objectsFolder
  The folder to which the objects are exported (needs to be shared with the container)
 .Parameter vmadminUsername
  Username of the administrator user in the container (defaults to sa)
 .Parameter adminPassword
  The admin password for the container (if using NavUserPassword authentication)
 .Parameter filter
  Specifies which objects to export (default is modified=Yes)
 .Parameter exportToNewSyntax
  Specifies whether or not to export objects in new syntax (default is true)
 .Example
  Export-NavContainerObject -containerName test -objectsFolder c:\demo\objects
 .Example
  Export-NavContainerObject -containerName test -objectsFolder c:\demo\objects -adminPassword <adminPassword> -filter ""
#>
function Export-NavContainerObjects {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName, 
        [Parameter(Mandatory=$true)]
        [string]$objectsFolder, 
        [string]$vmadminUsername = 'sa',
        [SecureString]$adminPassword = $null, 
        [string]$filter = "modified=Yes", 
        [switch]$exportToNewSyntax = $true
    )

    $containerAuth = Get-NavContainerAuth -containerName $containerName
    if ($containerAuth -eq "NavUserPassword" -and !($adminPassword)) {
        $adminPassword = Get-DefaultAdminPassword
    }

    $containerObjectsFolder = Get-NavContainerPath -containerName $containerName -path $objectsFolder -throw

    $session = Get-NavContainerSession -containerName $containerName
    Invoke-Command -Session $session -ScriptBlock { Param($filter, $objectsFolder, $vmadminUsername, $adminPassword, $exportToNewSyntax)

        $objectsFile = "$objectsFolder.txt"
        Remove-Item -Path $objectsFile -Force -ErrorAction Ignore
        Remove-Item -Path $objectsFolder -Force -Recurse -ErrorAction Ignore
        $filterStr = ""
        if ($filter) {
            $filterStr = " with filter '$filter'"
        }
        if ($exportToNewSyntax) {
            Write-Host "Export Objects$filterStr (new syntax) to $objectsFile"
        } else {
            Write-Host "Export Objects$filterStr to $objectsFile"
        }

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
        if ($exportToNewSyntax) {
            $params += @{ 'ExportToNewSyntax' = $true }
        }

        Export-NAVApplicationObject @params -DatabaseName $databaseName `
                                    -Path $objectsFile `
                                    -DatabaseServer $databaseServer `
                                    -Force `
                                    -Filter "$filter" | Out-Null

        Write-Host "Split $objectsFile to $objectsFolder"
        New-Item -Path $objectsFolder -ItemType Directory -Force -ErrorAction Ignore | Out-Null
        Split-NAVApplicationObjectFile -Source $objectsFile `
                                       -Destination $objectsFolder
        Remove-Item -Path $objectsFile -Force -ErrorAction Ignore
    
    }  -ArgumentList $filter, $containerObjectsFolder, $vmadminUsername, $adminPassword, $exportToNewSyntax
}
Export-ModuleMember -function Export-NavContainerObjects
