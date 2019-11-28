$healthcheckurl = ("https://localhost/" + $env:webserverinstance + "/")
try {
    $result = Invoke-WebRequest -Uri "${healthcheckurl}Health/System" -UseBasicParsing -TimeoutSec 10
    if ($result.StatusCode -eq 200 -and ((ConvertFrom-Json $result.Content).result)) {
        # Web Client Health Check Endpoint will test Web Client, Service Tier and Database Connection
        exit 0
    }
} catch {
}
exit 1