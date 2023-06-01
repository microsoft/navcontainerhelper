<# 
 .Synopsis
  Function to install Az Cli and enable Devops extension
 .Description
  Function to install Az Cli and enable Devops extension. If az cli is installed, an update will be done. Otherwise the installation will be performed.
#>
function Install-AzDevops {
    Param(
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {

    Try {
        $az_upgrade = Write-Output n | az upgrade 2>&1
    } catch {
        $az_upgrade = "Latest version available"
    }

    if (@($az_upgrade | Select-String "Latest version available").Count -ne 0) {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; Remove-Item .\AzureCLI.msi
    }
    
    $extensions = az extension list -o json | ConvertFrom-Json

    $devopsFound = $False
    foreach($extension in $extensions)
    {
        if($extension.name -eq 'azure-devops'){
            $devopsFound = $True
        }
    }
    
    if ($devopsFound -eq $False){
        az extension add -n azure-devops
    }
}
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    TrackTrace -telemetryScope $telemetryScope
}
}
Export-ModuleMember -Function Install-AzDevops
