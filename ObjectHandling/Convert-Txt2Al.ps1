<# 
 .Synopsis
  Convert txt and delta files to AL
 .Description
  Convert objects in myDeltaFolder to AL. Page and Table extensions are created as new objects using the startId as object Id offset.
  Code modifications and other things not supported in extensions will not be converted to AL.
  Manual modifications are required after the conversion.
 .Parameter containerName
  Name of the container in which the txt2al tool will be executed
 .Parameter myDeltaFolder
  Folder containing delta files
 .Parameter myAlFolder
  Folder in which the AL files are created
 .Parameter startId
  Starting offset for objects created by the tool (table and page extensions)
 .Parameter dotNetAddInsPackage
  Path to folder where dotnet add-ins are located (folder must be shared with container)
 .Example
  Convert-Txt2Al -containerName test -mydeltaFolder c:\programdata\bccontainerhelper\mydeltafiles -myAlFolder c:\programdata\bccontainerhelper\myAlFiles -startId 50100
#>
function Convert-Txt2Al {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory=$true)]
        [string] $myDeltaFolder, 
        [Parameter(Mandatory=$true)]
        [string] $myAlFolder, 
        [int] $startId = 50100,
        [string] $dotNetAddInsPackage
    )

    #AssumeNavContainer -containerOrImageName $containerName -functionName $MyInvocation.MyCommand.Name

    $containerMyDeltaFolder = Get-NavContainerPath -containerName $containerName -path $myDeltaFolder -throw
    $containerMyAlFolder = Get-NavContainerPath -containerName $containerName -path $myAlFolder -throw
    $containerDotNetAddInsPackage = ""
    if ($dotNetAddInsPackage) {
        $containerDotNetAddInsPackage = Get-NavContainerPath -containerName $containerName -path $dotNetAddInsPackage -throw
    }

    $navversion = Get-NavContainerNavversion -containerOrImageName $containerName
    $version = [System.Version]($navversion.split('-')[0])
    $ignoreSystemObjects = ($version.Major -ge 14)
    $platformVersion = Get-NavContainerPlatformVersion -containerOrImageName $containerName

    $dummy = Invoke-ScriptInNavContainer -containerName $containerName -ScriptBlock { Param($myDeltaFolder, $myAlFolder, $startId, $dotNetAddInsPackage, $platformVersion)
        
        $erroractionpreference = 'Continue'

        if (!($txt2al)) {
            throw "You cannot run Convert-Txt2Al on this Container"
        }
        Write-Host "Converting files in $myDeltaFolder to .al files in $myAlFolder with startId $startId (container paths)"
        Remove-Item -Path $myAlFolder -Recurse -Force -ErrorAction Ignore
        New-Item -Path $myAlFolder -ItemType Directory -ErrorAction Ignore | Out-Null

        if ([System.Text.Encoding]::Default.BodyName -eq "utf-8") {
            $cp = (Get-Culture).TextInfo.OEMCodePage
            $encoding = [System.Text.Encoding]::GetEncoding($cp)
            
            Write-Host "Converting my delta files from OEM($cp) to UTF8 before converting"
            Get-ChildItem -Path (Join-Path $myDeltaFolder "*.*") | ForEach-Object {
                $content = [System.IO.File]::ReadAllText($_.FullName, $encoding )
                [System.IO.File]::WriteAllText($_.FullName, $content, [System.Text.Encoding]::UTF8 )
            }
        }

        $txt2alParameters = @("--source=""$myDeltaFolder""", "--target=""$myAlFolder""", "--rename", "--extensionStartId=$startId")
        if ($dotNetAddInsPackage) {
            $txt2alParameters += @("--dotNetAddInsPackage=""$dotNetAddInsPackage""")
        }

        if ($platformVersion) {
            $ver = [System.Version]($platformVersion)
            if (($ver.Major -eq 14 -and $ver.Build -ge 34429) -or ($ver.Major -eq 15 -and $ver.Build -ge 34399)) {
                Write-Host "Using Compiler CodeAnalysis to format documents"
                if (-not (Test-Path (Join-Path ([System.IO.Path]::GetDirectoryName($txt2al)) "Microsoft.Dynamics.Nav.CodeAnalysis.Workspaces.dll"))) {
                    Write-Host "Copying Microsoft.Dynamics.Nav.CodeAnalysis.Workspaces.dll from vsix"
                    if (!(Test-Path "c:\build" -PathType Container)) {
                        $tempZip = Join-Path (Get-TempDir) "alc.zip"
                        Copy-item -Path (Get-Item -Path "c:\run\*.vsix").FullName -Destination $tempZip
                        Expand-Archive -Path $tempZip -DestinationPath "c:\build\vsix"
                    }
                    $alcPath = 'C:\build\vsix\extension\bin'
                    Copy-Item -Path (Join-Path $alcPath "Microsoft.Dynamics.Nav.CodeAnalysis.Workspaces.dll") -Destination ([System.IO.Path]::GetDirectoryName($txt2al))
                }
            }
        }

        Write-Host "txt2al.exe $([string]::Join(' ', $txt2alParameters))"
        & $txt2al $txt2alParameters 2> $null

        if ([System.Text.Encoding]::Default.BodyName -eq "utf-8") {
            Write-Host "Converting my delta files from UTF8 to OEM($cp) after converting"
            Get-ChildItem -Path (Join-Path $myDeltaFolder "*.*") | ForEach-Object {
                $content = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8 )
                [System.IO.File]::WriteAllText($_.FullName, $content, $encoding )
            }
        }

        $erroractionpreference = 'Stop'

    } -ArgumentList $containerMyDeltaFolder, $containerMyAlFolder, $startId, $containerDotNetAddInsPackage, $platformVersion
}
Export-ModuleMember -Function Convert-Txt2Al
