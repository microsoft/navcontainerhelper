function New-ALGoAppSourceContext {
    Param(
        [Parameter(Mandatory=$true, ValueFromPipeline)]
        [HashTable] $authContext,
        [switch] $skipTest
    )

    if ($authContext.ClientSecret) {
        $appSourceContext = [ordered]@{
            "clientID" = $authContext.clientID
            "clientSecret" = $authContext.ClientSecret | Get-PlainText
            "tenantID" = $authContext.tenantID
            "scopes" = @("https://api.partner.microsoft.com/.default")
        }
    }
    else {
        $appSourceContext = [ordered]@{
            "refreshToken" = $authContext.RefreshToken
            "tenantID" = $authContext.tenantID
            "scopes" = $authContext.scopes
        }
    }

    if (!$skipTest) {
        Write-Host "Testing AppSourceContext"
        try {
            $newAuthContext = New-BcAuthContext @appSourceContext
        }
        catch {
            Write-Host -ForegroundColor Red "Unable to use specified authContext"
            throw
        }
        try {
            $products = Get-AppSourceProduct -authContext $newAuthContext -silent
        }
        catch {
            Write-Host -ForegroundColor Red "Unable to get AppSource Products from ingestion API using the specified authContext"
            throw
        }
        Write-Host -ForegroundColor Green "AppSourceContext successfully validated"
    }
    $appSourceContext | ConvertTo-Json -Depth 99 -Compress
}
Export-ModuleMember -Function New-ALGoAppSourceContext
