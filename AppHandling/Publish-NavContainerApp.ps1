<# 
 .Synopsis
  Publish Nav App to a Nav container
 .Description
  Copies the appFile to the container if necessary
  Creates a session to the Nav container and runs the Nav CmdLet Publish-NavApp in the container
 .Parameter containerName
  Name of the container in which you want to publish an app (default is navserver)
 .Parameter appFile
  Path of the app you want to publish  
 .Parameter skipVerification
  Include this parameter if the app you want to publish is not signed
 .Parameter sync
  Include this parameter if you want to synchronize the app after publishing
 .Parameter install
  Include this parameter if you want to install the app after publishing
 .Parameter tenant
  If you specify the install switch, then you can specify the tenant in which you want to install the app
 .Parameter packageType
  Specify Extension or SymbolsOnly based on which package yu 
 .Example
  Publish-NavContainerApp -appFile c:\temp\myapp.app
 .Example
  Publish-NavContainerApp -containerName test2 -appFile c:\temp\myapp.app -skipVerification
 .Example
  Publish-NavContainerApp -containerName test2 -appFile c:\temp\myapp.app -install
 .Example
  Publish-NavContainerApp -containerName test2 -appFile c:\temp\myapp.app -skipVerification -install -tenant mytenant
#>
function Publish-NavContainerApp {
    Param(
        [string]$containerName = "navserver",
        [Parameter(Mandatory=$true)]
        [string]$appFile,
        [switch]$skipVerification,
        [switch]$sync,
        [switch]$install,
        [Parameter(Mandatory=$false)]
        [string]$tenant = "default",
        [ValidateSet('Extension','SymbolsOnly')]
        [string]$packageType = 'Extension'
    )

    $copied = $false
    if ($appFile.ToLower().StartsWith("http://") -or $appFile.ToLower().StartsWith("https://")) {
        $containerAppFile = $appFile
    } else {
        $containerAppFile = Get-NavContainerPath -containerName $containerName -path $appFile
        if ("$containerAppFile" -eq "") {
            $containerAppFile = Join-Path "c:\run" ([System.IO.Path]::GetFileName($appFile))
            Copy-FileToNavContainer -containerName $containerName -localPath $appFile -containerPath $containerAppFile
            $copied = $true
        }
    }

    $session = Get-NavContainerSession -containerName $containerName
    Invoke-Command -Session $session -ScriptBlock { Param($appFile, $skipVerification, $copied, $sync, $install, $tenant, $packageType)

        if ($appFile.ToLower().StartsWith("http://") -or $appFile.ToLower().StartsWith("https://")) {
            $appUrl = $appFile
            $appFile = Join-Path "c:\run" ([System.Uri]::UnescapeDataString([System.IO.Path]::GetFileName($appUrl).split("?")[0]))
            (New-Object System.Net.WebClient).DownloadFile($appUrl, $appFile)
            $copied = $true
        }

        Write-Host "Publishing $appFile"
        Publish-NavApp -ServerInstance NAV -Path $appFile -SkipVerification:$SkipVerification -packageType $packageType
        if ($sync -or $install) {
            $appName = (Get-NAVAppInfo -Path $appFile).Name
    
            if ($sync) {
                Write-Host "Synchronizing $appName on tenant $tenant"
                Sync-NavTenant -ServerInstance NAV -Tenant $tenant -Force
                Sync-NavApp -ServerInstance NAV -Name $appName -Tenant $tenant -WarningAction Ignore
            }
    
            if ($install) {
                Write-Host "Installing $appName on tenant $tenant"
                Install-NavApp -ServerInstance NAV -Name $appName -Tenant $tenant
            }
        }

        if ($copied) { 
            Remove-Item $appFile -Force
        }
    } -ArgumentList $containerAppFile, $skipVerification, $copied, $sync, $install, $tenant, $packageType
    Write-Host -ForegroundColor Green "App successfully published"
}
Export-ModuleMember -Function Publish-NavContainerApp
