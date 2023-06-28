<#
 .SYNOPSIS
  Wait for an Alpaca container to become ready
 .DESCRIPTION
  Wait for an Alpaca container to become ready
 .PARAMETER authContext
  Authorization Context for Alpaca obtained by New-BcAuthContext with -clientId $bcContainerHelperConfig.AlpacaSettings.OAuthClientId -Scopes $bcContainerHelperConfig.AlpacaSettings.OAuthScopes
 .PARAMETER containerId
  Container id of the Alpaca Container, returned by New-AlpacaBcContainer, to wait for
 .EXAMPLE
  $authContext = New-BcAuthContext -clientId $bcContainerHelperConfig.AlpacaSettings.OAuthClientId -Scopes $bcContainerHelperConfig.AlpacaSettings.OAuthScopes -includeDeviceLogin
  $artifactUrl = Get-BCArtifactUrl -country us -select Weekly
  $credential = New-Object pscredential -ArgumentList 'admin', $securePassword
  $containerId = New-AlpacaBcContainer `
      -authContext $authContext `
      -artifactUrl $artifactUrl `
      -credential $credential `
      -containerName 'bcserver' `
      -doNotWait `
      -devContainer
  Wait-AlpacaBcContainerReady `
      -authContext $authContext `
      -containerId $containerId
#>
function Wait-AlpacaBcContainerReady {
    Param(
        [Parameter(Mandatory=$true)]
        [Alias('AlpacaAuthContext')]
        [HashTable] $authContext,
        [Parameter(Mandatory=$true)]
        [string] $containerId
    )

    Start-Sleep -Seconds 5
    $previousStatus = ""
    $previousLogs = ""
    $getLog = $false
    do {
        # keep the refreshed context in scope
        $authContext = Renew-BcAuthContext $authContext
        $uri, $headers = Get-UriAndHeadersForAlpaca -authContext $authContext -serviceUrl "Service/$containerId/status"
        $statusResponse = Invoke-RestMethod -Method GET -Uri $uri -Headers $headers
        $statusCode = $statusResponse.StatusCode
        if ($statusCode -eq 'Unknown') {
            $statusCode = 'Waiting'
        }
        if ($statusCode -eq 'Building') {
            $waitTime = 60
        }
        elseif ($statusCode -eq 'Running') {
            $getLog = $true
            $waitTime = 1
        }
        elseif ($statusCode -eq 'Healthy') {
            $getLog = $true
            $waitTime = 0
        }
        else {
            $waitTime = 5
        }
        if ($statusCode -ne 'Healthy') {
            if ($statusCode -ne $previousStatus) {
                if ($previousStatus) { Write-Host }
                $previousStatus = $statusCode
                if ($statusCode -ne 'Running') { Write-Host -NoNewline $previousStatus }
            }
            else {
                if ($statusCode -ne 'Running') { Write-Host -NoNewline '.' }
            }
        }
        Start-Sleep -Seconds $waitTime
        if ($getLog) {
            $uri, $headers = Get-UriAndHeadersForAlpaca -authContext $authContext -serviceUrl "Task/$containerId/logs"
            $logsResponse = Invoke-RestMethod -Method GET -Uri $uri -Headers $headers  
            $newLines = $logsResponse
            if ($previousLogs -ne ""){
                $newLines = $newLines.Replace($previousLogs, "").Trim()  
            }
            if ($newLines -ne "") {  
                Write-Host $newLines  
            }  
            $previousLogs = $logsResponse
            Start-Sleep -Seconds 1
        }
        if ($statusResponse.ErrorMessage) {
            throw $statusResponse.ErrorMessage
        }
    } while (!$statusResponse.Healthy)
}
Export-ModuleMember -Function Wait-AlpacaBcContainerReady
