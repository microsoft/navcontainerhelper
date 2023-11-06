<# 
 .Synopsis
  Get Business Central NuGet Package from NuGet Server
 .Description
  Get Business Central NuGet Package from NuGet Server
 .OUTPUTS
  string
  Path to the a tmp folder where the package is downloaded
  This folder should be deleted after usage
 .PARAMETER nuGetServerUrl
  NuGet Server URL
  Default: https://api.nuget.org/v3/index.json
 .PARAMETER nuGetToken
  NuGet Token for authenticated access to the NuGet Server
  If not specified, the NuGet Server is accessed anonymously (and needs to support this)
 .PARAMETER packageName
  Package Name to search for.
  This can be the full name or a partial name with wildcards.
  If more than one package is found, matching the name, an error is thrown.
 .PARAMETER version
  Package Version, following the nuget versioning rules
  https://learn.microsoft.com/en-us/nuget/concepts/package-versioning#version-ranges
 .PARAMETER silent
  Suppress output
#>
Function Get-BcNuGetPackage {
    Param(
        [Parameter(Mandatory=$false)]
        [string] $nuGetServerUrl = "",
        [Parameter(Mandatory=$false)]
        [string] $nuGetToken = "",
        [Parameter(Mandatory=$true)]
        [string] $packageName,
        [Parameter(Mandatory=$false)]
        [string] $version = '0.0.0.0',
        [switch] $silent
    )

    foreach($feed in ([PSCustomObject]@{ "Url" = $nuGetServerUrl; "Token" = $nuGetToken; "Patterns" = @('*') }), $bcContainerHelperConfig.TrustedNuGetFeeds) {
        if ($feed -and $feed.Url) {
            try {
                Write-Host "Init NuGetFeed $($feed.Url)"
                $nuGetFeed = [NuGetFeed]::Create($feed.Url, $feed.Token, $feed.Patterns)
            }
            catch {
                Write-Host "Initiation of NuGetFeed failed. Error was $($_.Exception.Message)"
                continue
            }
            $packageId = $nuGetFeed.Search($packageName)
            if ($packageId) {
                Write-Host "PackageId:"
                $packageId | ForEach-Object { Write-Host "  $_" }
                if ($packageId.count -gt 1) {
                    throw "Ambiguous package name provided ($packageName)"
                }
                else {
                    $packageVersion = $nuGetFeed.FindPackageVersion($packageId[0], $version)
                    if (!$packageVersion) {
                        throw "No package found matching version '$version' for package id $($packageId[0])"
                    }
                    return $nuGetFeed.DownloadPackage($packageId[0], $packageVersion)
                }
            }
        }
    }
    Write-Host "No package found matching package name $($packageName)"
    return ''
}
Export-ModuleMember -Function Get-BcNuGetPackage
