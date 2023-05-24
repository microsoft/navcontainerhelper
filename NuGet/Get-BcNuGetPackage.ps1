<# 
 .Synopsis
  POC PREVIEW: Get Business Central NuGet Package from NuGet Server
 .Description
  Get Business Central NuGet Package from NuGet Server
#>
Function Get-BcNuGetPackage {
    Param(
        [string] $nuGetServerUrl = "https://api.nuget.org/v3/index.json",
        [string] $nuGetToken = "",
        [Parameter(Mandatory=$true)]
        [string] $packageName,
        [Parameter(Mandatory=$false)]
        [System.Version] $version = [System.Version]'0.0.0.0',
        [switch] $silent
    )

    $headers = @{
        "Content-Type" = "application/json; charset=utf-8"
    }
    if ($nuGetToken) {
        $headers += @{
            "Authorization" = "Basic $([Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("user:$nuGetToken")))"
        }
    }

    if (!$silent) {
        Write-Host "Determining Search Url for $nuGetServerUrl"
    }
    try {
        $capabilities = Invoke-RestMethod -UseBasicParsing -Method GET -Headers $headers -Uri $nuGetServerUrl
        $searchResource = $capabilities.resources | Where-Object { $_.'@type' -eq 'SearchQueryService' -or $_.'@type' -eq 'SearchQueryService/3.0.0-beta' }
        $searchUrl = $searchResource.'@id' | Select-Object -First 1
    }
    catch {
        throw (GetExtendedErrorMessage $_)
    }
    if (-not $searchUrl) {
        Write-Host "Supported capabilities:"
        $capabilities.resources.'@type' | ForEach-Object { Write-Host "- $_" }
        throw "$nuGetServerUrl doesn't support SearchQueryService."
    }
    if (!$silent) {
        Write-Host "Using $searchUrl"
    }
    try {
        $searchResult = Invoke-RestMethod -UseBasicParsing -Method GET -Headers $headers -Uri "$searchUrl/?q=$packageName"
        $count = $searchResult.data.count
        Write-Host "$count matching packages found"
        if ($count -gt 1) {
            $searchResult.data | ForEach-Object { Write-Host "- $($_.id)" }
        }
        $packageMetadata = $searchResult.data | Where-Object { $_.id -eq $packageName }
    }
    catch {
        throw (GetExtendedErrorMessage $_)
    }

    $tmpFolder = ''
    if (-not $packageMetadata) {
        if (!$silent) {
            Write-Host "The package named $packageName wasn't found on $nuGetServerUrl"
        }
    }
    else {
        if (!$silent) {
            Write-Host "Found Package $($packageMetadata.id) on $nuGetServerUrl"
        }

        $packageVersion = $packageMetadata.versions | Where-Object { [System.Version]$_.version -ge $version } | Sort-Object { [System.Version]$_.version } | Select-Object -Last 1
        if ($packageVersion.'@id' -notlike 'https://*' -and (($searchUrl -like 'https://pkgs.dev.azure.com/*/v3/query2/') -or ($searchUrl -like 'https://*.pkgs.visualstudio.com/_packaging/*/nuget/v3/query2/'))) {
            # Azure DevOps doesn't store URLs to package metadata in @id
            $contentUrl = "$($searchUrl.Substring(0,$searchUrl.Length-10).Replace('/_packaging/','/_apis/packaging/feeds/'))packages/$($packageVersion.'@id')/versions/$($packageVersion.Version)/content"
        }
        else {
            try {
                $package = Invoke-RestMethod -UseBasicParsing -Method GET -Headers $headers -Uri $packageVersion.'@id'
                $contentUrl = $package.packageContent
            }
            catch {
                throw (GetExtendedErrorMessage $_)
            }
        }

        $tmpFolder = Join-Path ([System.IO.Path]::GetTempPath()) ([GUID]::NewGuid().ToString())    
        if (!$silent) {
            Write-Host "Downloading Package from $contentUrl"
        }
        try {
            Invoke-RestMethod -UseBasicParsing -Method GET -Headers $headers -Uri $contentUrl -OutFile "$tmpFolder.zip"
        }
        catch {
            throw (GetExtendedErrorMessage $_)
        }
        Expand-7zipArchive -Path "$tmpFolder.zip" -DestinationPath $tmpFolder
        Remove-Item "$tmpFolder.zip"
        Write-Host -ForegroundColor Green "Package successfully downloaded"
    }
    $tmpFolder
}
Export-ModuleMember -Function Get-BcNuGetPackage
