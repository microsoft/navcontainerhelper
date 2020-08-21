$fontsFolderPath = "C:\Windows\Fonts"
$ExistingFonts = Get-ChildItem -Path $fontsFolderPath | % { $_.Name }

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

Get-ChildItem $PSScriptRoot -ErrorAction Ignore | % {
    if ($_.Extension -ne ".ini" -and $_.Extension -ne ".ps1") {
        $path = Join-Path "c:\Windows\Fonts" $_.Name
        if ($ExistingFonts.Contains($_.Name)) {
            Write-Host "Skipping font '$path' as it is already installed"
        }
        else {
            Copy-Item -Path $_.FullName -Destination $path
    
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
                Write-Host -ForegroundColor Red "Font '$path' installation failed"
            } else {
                Set-ItemProperty -path "$($fontRegistryPath)" -name "$($fontName)$($hashFontFileTypes.item($fileExt))" -value "$($fileName)" -type STRING
                Write-Host -ForegroundColor Green "Font '$path' installed successfully"
            }
        }
    }
}
