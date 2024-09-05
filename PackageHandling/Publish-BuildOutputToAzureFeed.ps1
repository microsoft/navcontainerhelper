﻿<# 
 .Synopsis
  Function for publishing build output from Run-AlPipeline to storage account
 .Description
  Function for publishing build output to storage account
  The function will publish artifacts in the format of https://github.com/microsoft/bcsamples-bingmaps.pte/releases/download/19.0.0/bcsamples-bingmaps.pte-main-Apps-19.0.168.0.zip
  Please consult the CI/CD Workshop document at http://aka.ms/cicdhol to learn more about this function
 .Parameter Organization
  A connectionstring with access to the storage account in which you want to publish artifacts (SecureString or String)
 .Parameter projectName
  Project name of the app you want to publish. This becomes part of the blob url.
 .Parameter appVersion
  Version of the app you want to publish. This becomes part of the blob url.
 .Parameter path
  Path containing the build output from Run-AlPipeline.
  The content of folders Apps, RuntimePackages and TestApps from this folder is published.
 .Parameter setLatest
  Add this switch if you want this artifact to also be published as latest
#>
function Publish-BuildOutputToAzureFeed {
    Param(
        [Parameter(Mandatory = $true)]
        [string] $organization,
        [Parameter(Mandatory = $true)]
        [string] $feed,
        [Parameter(Mandatory = $true)]
        [string] $path,
        [Parameter(Mandatory = $false)]
        [string] $pat = ''
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {
    if($pat -ne '') {
        Write-Warning "Enviroment Variable AZURE_DEVOPS_EXT_PAT is overridden";
        $env:AZURE_DEVOPS_EXT_PAT = $pat
    }
    Get-Childitem –Path (Join-Path $path "\Apps\*.app") | % {
        $basename = $_.Basename

        $tempAppFolder = Join-Path ([System.IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
        $tempAppOutFolder = Join-Path $tempAppFolder "out"
        $tempAppSourceFolder = Join-Path $tempAppFolder "source"
        try {
            New-Item -path $tempAppFolder -ItemType Directory -Force 
            New-Item -path $tempAppOutFolder -ItemType Directory -Force 
            Copy-Item -Path $_ -Destination $tempAppOutFolder
            Write-Host $tempAppFolder
            Write-Host "Processing: $basename"
            $runtimeApps =  @()
            if(Test-Path -Path (Join-Path $path "\RuntimePackages\")) {
                $runtimeApps = @(Get-Item -Path (Join-Path $path "\RuntimePackages\*$basename*"))
            }
            if ($runtimeApps.length -eq 1) {
                $runtimeApp = $runtimeApps[0];
                Copy-Item -Path $runtimeApp -Destination $tempAppOutFolder
            }
            elseif ($runtimeApps.length -eq 0) {
                Write-Host "No runtime app found."
            }
            else {
                Write-Warning "More then one runtime app found!!!"
            }
    
              
            Extract-AppFileToFolder -appFilename (Join-Path $tempAppOutFolder $_.Name) -generateAppJson -appFolder $tempAppSourceFolder
    
            $appJson = [System.IO.File]::ReadAllLines((Join-Path $tempAppSourceFolder "app.json")) | ConvertFrom-Json
    
            # Downgrade Version to fit AzureFeed... -.- 
            $appVersion = $appJson.version.split('.')
            $appVersion = $appVersion[0..($appVersion.Length - 2)]
            $appVersion = $appVersion -join '.'
    
            az artifacts universal publish `
                --organization $organization `
                --feed $feed `
                --name $appJson.id `
                --version $appVersion `
                --description $appJson.name `
                --path (Join-Path $tempAppOutFolder '.')   
        }
        finally {
            Remove-Item -Path $tempAppFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    TrackTrace -telemetryScope $telemetryScope
}
}
Export-ModuleMember -Function Publish-BuildOutputToAzureFeed
