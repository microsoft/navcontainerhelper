function New-ALGoNugetContext {
    Param(
        [Parameter(Mandatory=$true)]
        [string] $serverUrl,
        [Parameter(Mandatory=$true)]
        [string] $token,
        [switch] $skipTest
    )

    $nuGetContext = @{
        "serverUrl" = $serverUrl
        "token" = $token
    }

    if (!$skipTest) {
        Write-Host "Testing NuGetContext"

        try {
            $headers = @{
                "Content-Type" = "application/json; charset=utf-8"
                "Authorization" = "Basic $([Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("user:$token")))"
            }

            $capabilities = Invoke-RestMethod -UseBasicParsing -Method GET -Headers $headers -Uri $serverUrl
            $searchResource = $capabilities.resources | Where-Object { $_.'@type' -eq 'SearchQueryService' -or $_.'@type' -eq 'SearchQueryService/3.0.0-beta' }
            $publishResource = $capabilities.resources | Where-Object { $_."@type" -eq 'PackagePublish/2.0.0' }
        }
        catch {
            throw "Error trying to download NuGet Server capabilities. Error was: $($_.Message)"
        }

        if (-not $searchResource) {
            throw "NuGet Server does not support SearchQueryService API (or SearchQueryService/3.0.0-beta), which is needed for BcContainerHelper NuGet functions to work"
        }

        if (-not $publishResource) {
            throw "NuGet Server does not support PackagePublish/2.0.0 API, which is needed for BcContainerHelper NuGet functions to work"
        }

        Write-Host -ForegroundColor Green "NuGetContext successfully validated"
    }

    $nuGetContext | ConvertTo-Json -Depth 99 -Compress
}
Export-ModuleMember -Function New-ALGoNuGetContext
