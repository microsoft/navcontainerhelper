<# 
 .Synopsis
  PROOF OF CONCEPT PREVIEW: Get Business Central NuGet Package from NuGet Server
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
 .PARAMETER select
  Select the package to download if more than one package is found matching the name and version
  - Earliest: Select the earliest version
  - Latest: Select the latest version (default)
  - Exact: Select the exact version
  - Any: Select the first version found
 .PARAMETER allowPrerelease
  Include prerelease versions in the search
 .EXAMPLE
  Get-BcNuGetPackage -packageName 'FreddyKristiansen.BingMapsPTE.165d73c1-39a4-4fb6-85a5-925edc1684fb'
 .EXAMPLE
  Get-BcNuGetPackage -nuGetServerUrl $nugetServerUrl -nuGetToken $nuGetToken -packageName '437dbf0e-84ff-417a-965d-ed2bb9650972' -allowPrerelease
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
        [Parameter(Mandatory=$false)]
        [string[]] $excludeVersions = @(),
        [Parameter(Mandatory=$false)]
        [ValidateSet('Earliest','Latest','Exact','Any')]
        [string] $select = 'Latest',
        [switch] $allowPrerelease
    )

try {    
    $feed, $packageId, $packageVersion = Find-BcNugetPackage -nuGetServerUrl $nuGetServerUrl -nuGetToken $nuGetToken -packageName $packageName -version $version -excludeVersions $excludeVersions -verbose:($VerbosePreference -eq 'Continue') -select $select -allowPrerelease:($allowPrerelease.IsPresent)
    if (-not $feed) {
        Write-Host "No package found matching package name $($packageName) Version $($version)"
        return ''
    }
    else {
        Write-Host "Best match for package name $($packageName) Version $($version): $packageId Version $packageVersion from $($feed.Url)"
        return $feed.DownloadPackage($packageId, $packageVersion)
    }
}
catch {
    Write-Host -ForegroundColor Red "Error Message: $($_.Exception.Message.Replace("`r",'').Replace("`n",' '))`r`nStackTrace: $($_.ScriptStackTrace)"
    throw
}
}
Export-ModuleMember -Function Get-BcNuGetPackage
