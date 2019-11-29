if (-not("dummy" -as [type])) {
    add-type -TypeDefinition @"
using System;
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
public static class Dummy {
    public static bool ReturnTrue(object sender,
        X509Certificate certificate,
        X509Chain chain,
        SslPolicyErrors sslPolicyErrors) { return true; }
    public static RemoteCertificateValidationCallback GetDelegate() {
        return new RemoteCertificateValidationCallback(Dummy.ReturnTrue);
    }
}
"@
}

[System.Net.ServicePointManager]::ServerCertificateValidationCallback = [dummy]::GetDelegate()

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