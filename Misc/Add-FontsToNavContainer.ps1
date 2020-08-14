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

    Get-ChildItem $path -ErrorAction Ignore | % {
        if (!$ExistingFonts.Contains($_.Name) -and $_.Extension -ne ".ini") {

            try
            {
                $WindowsFontPath = Join-Path "c:\Windows\Fonts" $_.Name
                $fullName = $_.FullName
                Copy-FileToBcContainer -containerName $containerName -localPath $fullName -containerPath $WindowsFontPath

                Invoke-ScriptInBcContainer -containerName $containerName -ScriptBlock { Param($path)

#*******************************************************************
#  Load C# code
#*******************************************************************
$fontCSharpCode = @'
using System;
using System.Collections.Generic;
using System.Text;
using System.IO;
using System.Runtime.InteropServices;

namespace FontResource
{
    public class AddRemoveFonts
    {
        [DllImport("gdi32.dll")]
        static extern int AddFontResource(string lpFilename);

        public static int AddFont(string fontFilePath) {
            try 
            {
                return AddFontResource(fontFilePath);
            }
            catch
            {
                return 0;
            }
        }
    }
}
'@

                    Add-Type $fontCSharpCode
                    
                    # Create hashtable containing valid font file extensions and text to append to Registry entry name.
                    $hashFontFileTypes = @{}
                    $hashFontFileTypes.Add(".fon", "")
                    $hashFontFileTypes.Add(".fnt", "")
                    $hashFontFileTypes.Add(".ttf", " (TrueType)")
                    $hashFontFileTypes.Add(".ttc", " (TrueType)")
                    $hashFontFileTypes.Add(".otf", " (OpenType)")
                    $fontRegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
        
                    $fileDir  = split-path $path
                    $fileName = split-path $path -leaf
                    $fileExt = (Get-Item $path).extension
                    $fileBaseName = $fileName -replace($fileExt ,"")
            
                    $shell = new-object -com shell.application
                    $myFolder = $shell.Namespace($fileDir)
                    $fileobj = $myFolder.Items().Item($fileName)
                    $fontName = $myFolder.GetDetailsOf($fileobj,21)
            
                    if ($fontName -eq "") { $fontName = $fileBaseName }
            
                    $retVal = [FontResource.AddRemoveFonts]::AddFont($path)
            
                    if ($retVal -eq 0) {
                        Write-Host -ForegroundColor Red "Font `'$($path)`'`' installation failed"
                    } else {
                        Write-Host -ForegroundColor Green "Font `'$($path)`' installed successfully"
                        Set-ItemProperty -path "$($fontRegistryPath)" -name "$($fontName)$($hashFontFileTypes.item($fileExt))" -value "$($fileName)" -type STRING
                    }
                } -ArgumentList $WindowsFontPath
            }
            catch
            {
                Write-Host -ForegroundColor Red "Font `'$($fullName)`' exception when installing"
                $error.clear()
            }
        }
    }
}
Set-Alias -Name Add-FontsToNavContainer -Value Add-FontsToBcContainer
Export-ModuleMember -Function Add-FontsToBcContainer -Alias Add-FontsToNavContainer
