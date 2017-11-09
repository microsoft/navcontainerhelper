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
 .Example
  Publish-NavContainerApp -appFile c:\temp\myapp.app
 .Example
  Publish-NavContainerApp -containerName test2 -appFile c:\temp\myapp.app -skipVerification
#>
function Publish-NavContainerApp {
    Param(
        [string]$containerName = "navserver",
        [Parameter(Mandatory=$true)]
        [string]$appFile,
        [switch]$skipVerification
    )

    $containerAppFile = Get-NavContainerPath -containerName $containerName -path $appFile
    $copied = $false
    if ("$containerAppFile" -eq "") {
        $containerAppFile = Join-Path "c:\run" ([System.IO.Path]::GetFileName($appFile))
        Copy-FileToNavContainer -containerName $containerName -localPath $appFile -containerPath $containerAppFile
        $copied = $true
    }
    
    $session = Get-NavContainerSession -containerName $containerName
    Invoke-Command -Session $session -ScriptBlock { Param($appFile, $skipVerification, $copied)
        Write-Host "Publishing app $appFile"
        Publish-NavApp -ServerInstance NAV -Path $appFile -SkipVerification:$SkipVerification
        if ($copied) { 
            Remove-Item $appFile -Force
        }
    } -ArgumentList $containerAppFile, $skipVerification, $copied
    Write-Host -ForegroundColor Green "App successfully published"
}
Export-ModuleMember -Function Publish-NavContainerApp
