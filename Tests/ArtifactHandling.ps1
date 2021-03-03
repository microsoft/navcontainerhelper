Describe 'ArtifactHandling' {
    $appName = "test";
    $appVersion = "1.1.1";
    It 'Publish-BuildOutputToAzureFeed' {
        Publish-BuildOutputToAzureFeed -organization "https://dev.azure.com/bynd365/" -feed "BCApps"  -path "C:\temp\test\output" -pat "qa5jj2ngjopds7nkqyessdvr72flghg6fl5r63cbtbvhnl4ghhsa"
    }
}