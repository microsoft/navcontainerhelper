<# 
 .Synopsis
  Restart a NAV/BC Container
 .Description
  Restart a Container
 .Parameter containerName
  Name of the container you want to restart
 .Parameter renewBindings
  Include this switch if you want the container to renew bindings (f.ex. after renewing a certificate)
 .Parameter timeout
  Specify the number of seconds to wait for activity. Default is 1800 (30 min.), -1 means wait forever, 0 means don't wait.
 .Example
  Restart-BcContainer -containerName test
 .Example
  Restart-BcContainer -containerName test -renewBindings
#>
function Restart-BcContainer {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false, ValueFromPipeline)]
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [switch] $renewBindings,
        [int] $timeout = 1800
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {

    if ((docker inspect -f '{{.State.Running}}' $containerName) -eq "true") {
        Invoke-ScriptInBcContainer -containerName $containerName -useSession:$false -ScriptBlock { Param( $renewBindings )
            if ($renewBindings) { Set-Content -Path "c:\run\PublicDnsName.txt" -Value "" }
            Set-Content -Path "c:\run\startcount.txt" -Value "0"
        } -argumentList $renewBindings.IsPresent
    }
    else {
        $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
        if ($renewBindings) {
            Set-Content -Path $tempFile -Value ""
            docker cp $tempFile "$($containerName):c:\run\PublicDnsName.txt"
        }
        Set-Content -Path $tempFile -Value "0"
        docker cp $tempFile "$($containerName):c:\run\startcount.txt"
        Remove-Item -Path $tempFile
    }

    Write-Host "Removing Session $containerName"
    Remove-BcContainerSession $containerName

    $logs = @(docker logs $containerName)
    $startlog = [string]::Join("`r`n",$logs)

    if (!(DockerDo -command restart -imageName $containerName)) {
        return
    }
    if ($timeout -ne 0) {
        Wait-BcContainerReady -containerName $containerName -timeout $timeout -startlog $startlog
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
Set-Alias -Name Restart-NavContainer -Value Restart-BcContainer
Export-ModuleMember -Function Restart-BcContainer -Alias Restart-NavContainer
