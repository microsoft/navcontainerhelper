<# 
 .Synopsis
  PROOF OF CONCEPT PREVIEW: Get Business Central NuGet Package from NuGet Server
 .Description
  Find Business Central NuGet Package from NuGet Server
 .OUTPUTS
  NuGetFeed class, packageId and package Version
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
 .PARAMETER select
  Select the package to download if more than one package is found matching the name and version
  - Earliest: Select the earliest version
  - Latest: Select the latest version (default)
  - Exact: Select the exact version
  - Any: Select the first version found
 .PARAMETER allowPrerelease
  Include prerelease versions in the search
 .EXAMPLE
  $feed, $packageId, $packageVersion = Find-BcNuGetPackage -packageName 'FreddyKristiansen.BingMapsPTE.165d73c1-39a4-4fb6-85a5-925edc1684fb'
 .EXAMPLE
  $feed, $packageId, $packageVersion = Find-BcNuGetPackage -nuGetServerUrl $nugetServerUrl -nuGetToken $nuGetToken -packageName '437dbf0e-84ff-417a-965d-ed2bb9650972' -allowPrerelease
#>
Function Find-BcNuGetPackage {
    Param(
        [Parameter(Mandatory=$false)]
        [string] $nuGetServerUrl = "",
        [Parameter(Mandatory=$false)]
        [string] $nuGetToken = "",
        [Parameter(Mandatory=$true)]
        [string] $packageName,
        [Parameter(Mandatory=$false)]
        [string] $version = '0.0.0.0',
        [Parameter(Mandatory=$false)]
        [string[]] $excludeVersions = @(),
        [Parameter(Mandatory=$false)]
        [ValidateSet('Earliest','Latest','Exact','Any')]
        [string] $select = 'Latest',
        [switch] $allowPrerelease
    )

    function dump([string]$message) {
        if ($message -like '::*' -and $VerbosePreference -eq 'Continue') {
            Write-Host $message
        }
        else {
            Write-Verbose $message
        }
    }

    $bestmatch = $null
    # Search all trusted feeds for the package
    foreach($feed in (@([PSCustomObject]@{ "Url" = $nuGetServerUrl; "Token" = $nuGetToken; "Patterns" = @('*') })+$bcContainerHelperConfig.TrustedNuGetFeeds)) {
        if ($feed -and $feed.Url) {
            Dump "::group::Search NuGetFeed $($feed.Url)"
            try {
                $nuGetFeed = [NuGetFeed]::Create($feed.Url, $feed.Token, $feed.Patterns, ($VerbosePreference -eq 'Continue'))
                $packageIds = $nuGetFeed.Search($packageName)
                if ($packageIds) {
                    foreach($packageId in $packageIds) {
                        Dump "PackageId: $packageId"
                        $packageVersion = $nuGetFeed.FindPackageVersion($packageId, $version, $excludeVersions, $select, $allowPrerelease.IsPresent)
                        if (!$packageVersion) {
                            Dump "No package found matching version '$version' for package id $($packageId)"
                            continue
                        }
                        elseif ($bestmatch) {
                            # We already have a match, check if this is a better match
                            if (($select -eq 'Earliest' -and ([NuGetFeed]::CompareVersions($packageVersion, $bestmatch.PackageVersion) -eq -1)) -or 
                                ($select -eq 'Latest' -and ([NuGetFeed]::CompareVersions($packageVersion, $bestmatch.PackageVersion) -eq 1))) {
                                $bestmatch = [PSCustomObject]@{
                                    "Feed" = $nuGetFeed
                                    "PackageId" = $packageId
                                    "PackageVersion" = $packageVersion
                                }
                            }
                        }
                        elseif ($select -eq 'Exact') {
                            # We only have a match if the version is exact
                            if ($packageVersion -eq $version) {
                                $bestmatch = [PSCustomObject]@{
                                    "Feed" = $nuGetFeed
                                    "PackageId" = $packageId
                                    "PackageVersion" = $packageVersion
                                }
                                break
                            }
                        }
                        else {
                            $bestmatch = [PSCustomObject]@{
                                "Feed" = $nuGetFeed
                                "PackageId" = $packageId
                                "PackageVersion" = $packageVersion
                            }
                            # If we are looking for any match, we can stop here
                            if ($select -eq 'Any') {
                                break
                            }
                        }
                    }
                }
            }
            finally {
                Dump "::endgroup::"
            }
        }
        if ($bestmatch -and ($select -eq 'Any' -or $select -eq 'Exact')) {
            # If we have an exact match or any match, we can stop here
            break
        }
    }
    if ($bestmatch) {
        return $bestmatch.Feed, $bestmatch.PackageId, $bestmatch.PackageVersion
    }
}
Export-ModuleMember -Function Find-BcNuGetPackage
