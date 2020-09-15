<# 
 .Synopsis
  Import License file to a NAV/BC Container
 .Description
  Import a license from a file or a url to a container
 .Parameter containerName
  Name of the container in which you want to import a license
 .Parameter licenseFile
  Path or secure url to the licensefile to upload
 .Parameter restart
  Include this switch to restart the service tier after importing the license file
 .Example
  Import-BcContainerLicense -containerName test -licenseFile c:\temp\mylicense.flf -restart
 .Example
  Import-BcContainerLicense -containerName test -licenseFile "https://www.dropbox.com/s/fhwfwjfjwhff/license.flf?dl=1"
#>
function Import-BcContainerLicense {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName, 
        [Parameter(Mandatory=$true)]
        [string] $licenseFile,
        [switch] $restart
    )

    $containerLicenseFile = Join-Path $ExtensionsFolder "$containerName\my\license.flf"
    if ($licensefile.StartsWith("https://", "OrdinalIgnoreCase") -or $licensefile.StartsWith("http://", "OrdinalIgnoreCase")) {
        Write-Host "Downloading license file '$licensefile' to container"
        (New-Object System.Net.WebClient).DownloadFile($licensefile, $containerlicensefile)
        $bytes = [System.IO.File]::ReadAllBytes($containerlicenseFile)
        $text = [System.Text.Encoding]::ASCII.GetString($bytes, 0, 100)
        if (!($text.StartsWith("Microsoft Software License Information"))) {
            Remove-Item -Path $containerlicenseFile -Force
            Write-Error "Specified license file Uri isn't a direct download Uri"
        }
    } else {
        if ($containerLicenseFile -ne $licenseFile) {
            Write-Host "Copying license file '$licensefile' to container"
            Copy-Item -Path $licenseFile -Destination $containerLicenseFile -Force
        }
    }

    Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param($licensefile, $restart)

        Write-Host "Importing License $licensefile"
        Import-NAVServerLicense -LicenseFile $licensefile -ServerInstance $ServerInstance -Database NavDatabase -WarningAction SilentlyContinue
        
        if ($restart) {
            Write-Host "Restarting Service Tier"
            Set-NavServerInstance -ServerInstance $ServerInstance -restart
        }
    
    }  -ArgumentList (Get-BcContainerPath -ContainerName $containerName -Path $containerLicenseFile), $restart
}
Set-Alias -Name Import-NavContainerLicense -Value Import-BcContainerLicense
Export-ModuleMember -Function Import-BcContainerLicense -Alias Import-NavContainerLicense
