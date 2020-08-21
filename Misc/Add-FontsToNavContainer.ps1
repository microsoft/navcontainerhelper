<# 
 .Synopsis
  Copy Font(s) to a NAV/BC container
 .Description
  Copies and registers missing fonts in a container to use in report printing or preview
 .Parameter containerName
  Name of the container to which you want to copy fonts
 .Parameter path
  Path to fonts to copy and register in the container
 .Example
  Add-FontsToBcContainer
 .Example
  Add-FontsToBcContainer -containerName test2
 .Example
  Add-FontsToBcContainer -containerName test2 -path "C:\Windows\Fonts\ming*.*"
 .Example
  Add-FontsToBcContainer -containerName test2 -path "C:\Windows\Fonts\mingliu.ttc"
#>
function Add-FontsToBcContainer {
   Param (
        [Parameter(Mandatory=$false)]
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName, 
        [Parameter(Mandatory=$false)]
        [string] $path = "C:\Windows\Fonts"
    )

    $ExistingFonts = Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock {
        $fontsFolderPath = "C:\Windows\Fonts"
        Get-ChildItem -Path $fontsFolderPath | % { $_.Name }
    }

    $fontsFolder = Join-Path $extensionsFolder "$containerName\Fonts"
    if (Test-Path $fontsFolder) {
        Remove-Item $fontsFolder -Recurse -Force
    }
    New-Item -Path $fontsFolder -ItemType Directory | Out-Null
    $extensions = @(".fon", ".fnt", ".ttf", ".ttc", ".otf")

    $found = $false
    Get-ChildItem $path -ErrorAction Ignore | % {
        if ($extensions.Contains($_.Extension.ToLowerInvariant())) {
            if ($ExistingFonts.Contains($_.Name)) {
                Write-Host "Skipping font '$($_.Name)' as it is already installed"
            }
            else {
                Copy-Item -Path $_.FullName -Destination $fontsFolder
                $found = $true
            }
        }
    }

    if ($found) {
        Copy-Item -Path (Join-Path $PSScriptRoot "..\AddFonts.ps1") -Destination $fontsFolder

        Invoke-ScriptInBcContainer -containerName $containerName -scriptblock { Param($addFontsScript)
            . $addFontsScript
        } -argumentList (Get-BcContainerPath -containerName $containerName -path (Join-Path $fontsFolder "AddFonts.ps1"))
    }
}
Set-Alias -Name Add-FontsToNavContainer -Value Add-FontsToBcContainer
Export-ModuleMember -Function Add-FontsToBcContainer -Alias Add-FontsToNavContainer
