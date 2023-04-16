<# 
 .Synopsis
  POC PREVIEW: Push Business Central NuGet Package to NuGet Server
 .Description
  Push Business Central NuGet Package to NuGet Server
#>
Function Push-BcNuGetPackage {
    Param(
        [string] $nuGetServerUrl = "https://api.nuget.org/v3/index.json",
        [Parameter(Mandatory=$true)]
        [string] $nuGetToken,
        [Parameter(Mandatory=$true)]
        [string] $bcNuGetPackage
    )
    
    Write-Host "Determining NuGet Publish Url"
    $headers = @{
        "Content-Type" = "application/json; charset=utf-8"
        "Authorization" = "Basic $([Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("user:$nuGetToken")))"
    }
    try {
        $capabilities = Invoke-RestMethod -UseBasicParsing -Method GET -Headers $headers -Uri $nuGetServerUrl
        $publishResource = $capabilities.resources | Where-Object { $_."@type" -eq 'PackagePublish/2.0.0' }
        $publishUrl = $publishResource.'@id' | Select-Object -First 1
    }
    catch {
        throw (GetExtendedErrorMessage $_)
    }
    if (-not $publishUrl) {
        Write-Host "Supported capabilities:"
        $capabilities.resources.'@type' | ForEach-Object { Write-Host "- $_" }
        throw "$nuGetServerUrl doesn't support PackagePublish/2.0.0."
    }
    
    Write-Host "Preparing NuGet Package for submission"
    $headers += @{
        "X-NuGet-ApiKey" = $nuGetToken
        "X-NuGet-Client-Version" = "6.3.0"
    }
    $FileContent = [System.IO.File]::ReadAllBytes($bcNuGetPackage)
    $boundary = [System.Guid]::NewGuid().ToString(); 
    $LF = "`r`n";
    
    $body  = [System.Text.Encoding]::UTF8.GetBytes("--$boundary$LF")
    $body += [System.Text.Encoding]::UTF8.GetBytes("Content-Type: application/octet-stream$($LF)Content-Disposition: form-data; name=package; filename=""$([System.IO.Path]::GetFileName($bcNuGetPackage))""$($LF)$($LF)")
    $body += $fileContent
    $body += [System.Text.Encoding]::UTF8.GetBytes("$LF--$boundary--$LF")
    
    $tmpFile = Join-Path ([System.IO.Path]::GetTempPath()) ([GUID]::NewGuid().ToString())
    [System.IO.File]::WriteAllBytes($tmpFile, $body)
    Write-Host "Submitting NuGet package"
    try {
        Invoke-RestMethod -UseBasicParsing -Uri $publishUrl -ContentType "multipart/form-data; boundary=$boundary" -Method Put -Headers $headers -inFile $tmpFile | Out-Host
        Write-Host -ForegroundColor Green "NuGet package successfully submitted"
    }
    catch [System.Net.WebException] {
        if ($_.Status -eq "ProtocolError") {
            $response = $_.Response as [System.Net.HttpWebResponse]
            if ($response.StatusCode -eq [System.Net.HttpStatusCode]::Conflict) {
                Write-Host -ForegroundColor Yellow "NuGet package already exists"
            }
            else {
                throw (GetExtendedErrorMessage $_)
            }
        else {
            throw (GetExtendedErrorMessage $_)
        }
    }
    catch {
        throw (GetExtendedErrorMessage $_)
    }
    finally {
        Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
    }
}
Export-ModuleMember -Function Push-BcNuGetPackage
