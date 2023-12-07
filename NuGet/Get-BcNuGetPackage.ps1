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
        [switch] $silent,
        [Parameter(Mandatory=$false)]
        [ValidateSet('Earliest','Latest','Exact','Any')]
        [string] $select = 'Latest'
    )

    $bestmatch = $null
    # Search all trusted feeds for the package
    foreach($feed in (@([PSCustomObject]@{ "Url" = $nuGetServerUrl; "Token" = $nuGetToken; "Patterns" = @('*') })+$bcContainerHelperConfig.TrustedNuGetFeeds)) {
        if ($feed -and $feed.Url) {
            Write-Host "::group::Search NuGetFeed $($feed.Url)"
            try {
                try {
                    $nuGetFeed = [NuGetFeed]::Create($feed.Url, $feed.Token, $feed.Patterns)
                }
                catch {
                    Write-Host "Initiation of NuGetFeed failed. Error was $($_.Exception.Message)"
                    continue
                }
                $packageIds = $nuGetFeed.Search($packageName)
                if ($packageIds) {
                    foreach($packageId in $packageIds) {
                        Write-Host "PackageId: $packageId"
                        $packageVersion = $nuGetFeed.FindPackageVersion($packageId, $version, $select)
                        if (!$packageVersion) {
                            Write-Host "No package found matching version '$version' for package id $($packageId)"
                            continue
                        }
                        elseif ($bestmatch) {
                            # We already have a match, check if this is a better match
                            if (($select -eq 'Earliest' -and [System.Version]$packageVersion -lt $bestmatch.PackageVersion) -or ($select -eq 'Latest' -and [System.Version]$packageVersion -gt $bestmatch.PackageVersion)) {
                                $bestmatch = [PSCustomObject]@{
                                    "Feed" = $nuGetFeed
                                    "PackageId" = $packageId
                                    "PackageVersion" = [System.Version]$packageVersion
                                }
                            }
                        }
                        elseif ($select -eq 'Exact') {
                            # We only have a match if the version is exact
                            if ($packageVersion -eq $version) {
                                $bestmatch = [PSCustomObject]@{
                                    "Feed" = $nuGetFeed
                                    "PackageId" = $packageId
                                    "PackageVersion" = [System.Version]$packageVersion
                                }
                                break
                            }
                        }
                        else {
                            $bestmatch = [PSCustomObject]@{
                                "Feed" = $nuGetFeed
                                "PackageId" = $packageId
                                "PackageVersion" = [System.Version]$packageVersion
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
                Write-Host "::endgroup::"
            }
        }
        if ($bestmatch -and ($select -eq 'Any' -or $select -eq 'Exact')) {
            # If we have an exact match or any match, we can stop here
            break
        }
    }
    if ($bestmatch) {
        Write-Host "Best match for package name $($packageName) Version $($version): $($bestmatch.PackageId) Version $($bestmatch.PackageVersion)"
        return $bestmatch.Feed.DownloadPackage($bestmatch.PackageId, $bestmatch.PackageVersion)
    }
    else {
        Write-Host "No package found matching package name $($packageName) Version $($version)"
        return ''
    }
}
Export-ModuleMember -Function Get-BcNuGetPackage
