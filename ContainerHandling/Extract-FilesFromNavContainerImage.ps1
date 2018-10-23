<# 
 .Synopsis
  Extract Files From NAV Container Image
 .Description
  Extract all files from a NAV Container Image necessary to start a generic container with these files
 .Parameter imageName
  Name of the NAV Container Image from which you want to extract the files
 .Parameter path
  Location where you want the files to be placed
 .Example
  Extract-FilesFromNavContainerImage -ImageName microsoft/bcsandbox:us -Path "c:\programdata\navcontainerhelper\extensions\acontainer\afolder"
#>
function Extract-FilesFromNavContainerImage {
    [CmdletBinding()]
    Param
    (
        [string]$imageName,
        [string]$path,
        [ValidateSet('all','vsix','database')]
        [string]$extract = "all"
    )

    New-Item -Path $path -ItemType Directory -Force -ErrorAction Ignore | Out-Null

    Write-Host "Creating temp container from $imagename and extract necessary files"
    docker create --name navcontainerhelper-temp $imagename | Out-Null

    if ($extract -eq "all") {
        New-Item "$path\ServiceTier\System64Folder" -ItemType Directory | Out-Null
        New-Item "$path\ServiceTier\Program Files" -ItemType Directory | Out-Null
        New-Item "$path\WebClient\Microsoft Dynamics NAV" -ItemType Directory | Out-Null
        New-Item "$path\RoleTailoredClient\systemFolder" -ItemType Directory | Out-Null
        New-Item "$path\RoleTailoredClient\Program Files" -ItemType Directory | Out-Null
        New-Item "$path\ClickOnceInstallerTools\Program Files\Microsoft Dynamics NAV" -ItemType Directory | Out-Null
        New-Item "$path\WindowsPowerShellScripts\Cloud" -ItemType Directory | Out-Null
        New-Item "$path\RoleTailoredClient\CommonAppData\Microsoft\Microsoft Dynamics NAV\VER" -ItemType Directory | Out-Null
        
        Write-Host "Extracting Service Tier and WebClient Files"
        docker cp navcontainerhelper-temp:"\Windows\System32\NavSip.dll" "$path\ServiceTier\System64Folder"
        docker cp navcontainerhelper-temp:"\Program Files\Microsoft Dynamics NAV" "$path\ServiceTier\program files\Microsoft Dynamics NAV"
        Write-Host "Extracting Windows Client Files"
        docker cp navcontainerhelper-temp:"\Windows\SysWow64\NavSip.dll" "$path\RoleTailoredClient\systemFolder"
        docker cp navcontainerhelper-temp:"\Program Files (x86)\Microsoft Dynamics NAV" "$path\RoleTailoredClient\Program Files"
        Write-Host "Extracting Configuration packages"
        docker cp navcontainerhelper-temp:"\ConfigurationPackages" "$path" 2>$null
        Write-Host "Extracting Test Assemblies"
        docker cp navcontainerhelper-temp:"\Test Assemblies" "$path" 2>$null
        Write-Host "Extracting Test Toolkit"
        docker cp navcontainerhelper-temp:"\TestToolKit" "$path" 2>$null
        Write-Host "Extracting Upgrade Toolkit"
        docker cp navcontainerhelper-temp:"\UpgradeToolKit" "$path" 2>$null
        Write-Host "Extracting Extensions"
        docker cp navcontainerhelper-temp:"\Extensions" "$path" 2>$null

        $sourceFolder = (Get-Item "$path\ServiceTier\Program Files\Microsoft Dynamics NAV\*\Web Client").FullName
        $destFolder = $sourceFolder.Replace('\Web Client','').Replace('ServiceTier\Program Files','WebClient')
        New-Item -Path $destFolder -ItemType Directory | Out-Null
        Move-Item -Path $sourceFolder -Destination $destFolder
        
        $sourceFolder = (Get-Item "$path\RoleTailoredClient\Program Files\Microsoft Dynamics NAV\*\ClickOnce Installer Tools").FullName
        $destFolder = $sourceFolder.Replace('\ClickOnce Installer Tools','').Replace('\RoleTailoredClient\','\ClickOnceInstallerTools\')
        New-Item -Path $destFolder -ItemType Directory | Out-Null
        Move-Item -Path $sourceFolder -Destination $destFolder
    }
    if ($extract -eq "all" -or $extract -eq "vsix") {
        Write-Host "Extracting Files from Run folder"
        docker cp navcontainerhelper-temp:"\Run" "$path"
    }
    if ($extract -eq "all" -or $extract -eq "database") {
        Write-Host "Extracting Database Files"
        docker cp navcontainerhelper-temp:"\databases" "$path" 2>$null
    }
    
    Write-Host "Performing cleanup"
    if ($extract -eq "all" -or $extract -eq "database") {
        if (Test-Path "$path\databases\*.mdf") {
            Move-Item -Path (Get-Item "$path\databases\*.mdf").FullName -Destination "$path\databases\Cronus.mdf"
            Move-Item -Path (Get-Item "$path\databases\*.ldf").FullName -Destination "$path\databases\Cronus.ldf"
        } else {
            $folder = Get-ChildItem -Path "$path\databases"
            if ($folder) {
                $name = $folder.Name
                Move-Item -Path (Get-Item "$path\databases\$Name\*.mdf").FullName -Destination "$path\databases\$name.mdf"
                Move-Item -Path (Get-Item "$path\databases\$Name\*.ldf").FullName -Destination "$path\databases\$name.ldf"
                Remove-Item $folder.FullName -Recurse -Force
            } else {
                docker cp navcontainerhelper-temp:"\Program Files\Microsoft SQL Server\MSSQL13.SQLEXPRESS\MSSQL\DATA" "$path"
                $mdffile = Get-Item "$path\DATA\Financials*.mdf"
                if ($mdffile) {
                    $name = $mdffile.Name.SubString(0,$mdffile.Name.IndexOf('_'))
                    Move-Item -Path (Get-Item "$path\DATA\Financials*.mdf").FullName -Destination "$path\databases\$name.mdf"
                    Move-Item -Path (Get-Item "$path\DATA\Financials*.ldf").FullName -Destination "$path\databases\$name.ldf"
                    Remove-Item -path "$path\DATA" -Recurse -Force
                } else {
                    throw "Cannot locate database"
                }
            }
        }
    }
    
    if ($extract -eq "all") {
        Copy-Item -Path "$path\Run\NAVAdministration" -Destination "$path\WindowsPowerShellScripts\Cloud" -Force -Recurse
        Copy-Item -Path "$path\Run\ClientUserSettings.config" -Destination "$path\RoleTailoredClient\CommonAppData\Microsoft\Microsoft Dynamics NAV\VER" -Force
        If (Test-Path "$path\Run\inetpub") {
            Copy-Item -Path "$path\Run\inetpub" -Destination "$path\WebClient" -Force -Recurse
        }
    }
    if ($extract -eq "all" -or $extract -eq "vsix") {
        Copy-Item -Path "$path\Run\*.vsix" -Destination "$path" -Force
        Remove-Item -Path "$path\Run" -Recurse -Force
    }
    
    Write-Host "Removing temp container"
    docker rm navcontainerhelper-temp | Out-null
}
Export-ModuleMember -function Extract-FilesFromNavContainerImage
