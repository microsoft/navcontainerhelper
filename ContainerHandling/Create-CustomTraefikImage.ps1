<# 
 .Synopsis
  Create Traefik image for currently used windows server version.
 .Description
  Create a custom Traefik docker image, based on the best generic image version according to your Windows version.
  This is useful when using Windows Server 2022 for example, where no prebuilt image is provided.
 .Parameter imageName
  Name of the docker image, which will be created. Default value is "mytraefik"
 .Parameter doNotUpdateConfig
  Specifies to only create the traefik image, but not updating the BcContainerHelper configuration to use this Traefik image.
 .Example
  Create-CustomTraefikImage -imageName mytraefik
#>
function Create-CustomTraefikImage {
    [CmdletBinding()]
    Param (
        [string] $imageName = "mytraefik",
        [switch] $doNotUpdateConfig
    )    

    Process {
      $originalPath = Get-Location

      function PullDockerImage {
          Param(
              [Parameter(Mandatory=$true)]
              [string]$imageName
          )

          $result = $true
          $arguments = ("pull $imageName")
          $pinfo = New-Object System.Diagnostics.ProcessStartInfo
          $pinfo.FileName = "docker.exe"
          $pinfo.RedirectStandardError = $true
          $pinfo.RedirectStandardOutput = $true
          $pinfo.CreateNoWindow = $true
          $pinfo.UseShellExecute = $false
          $pinfo.Arguments = $arguments
          $p = New-Object System.Diagnostics.Process
          $p.StartInfo = $pinfo
          $p.Start() | Out-Null

          $outtask = $null
          $errtask = $p.StandardError.ReadToEndAsync()
          $out = ""
          $err = ""

          do {
              if ($null -eq $outtask) {
                  $outtask = $p.StandardOutput.ReadLineAsync()
              }
              $outtask.Wait(100) | Out-Null
              if ($outtask.IsCompleted) {
                  $outStr = $outtask.Result
                  if ($null -eq $outStr) {
                      break
                  }
                  if (!$silent) {
                      Write-Host $outStr
                  }
                  $out += $outStr
                  $outtask = $null
              } elseif ($outtask.IsCanceled) {
                  break
              } elseif ($outtask.IsFaulted) {
                  break
              }
          } while(!($p.HasExited))

          $err = $errtask.Result
          $p.WaitForExit();

          if ($p.ExitCode -ne 0) {
              $result = $false
              if (!$silent) {
                  $err = $err.Trim()
                  if ("$error" -ne "") {
                      Write-Host $error -ForegroundColor Red
                  }
                  Write-Host "ExitCode: "+$p.ExitCode -ForegroundColor Red
                  Write-Host "Commandline: docker $arguments" -ForegroundColor Red
              }
          }
          return $result
      }


      try {
          $bestGenericImage = Get-BestGenericImageName
          $servercoreVersion = $bestGenericImage.Split(':')[1]
          $serverCoreImage = "mcr.microsoft.com/windows/servercore:$serverCoreVersion"

          Write-Host "Pulling $serverCoreImage (this might take some time)"
          if (!(PullDockerImage -imageName $serverCoreImage))  {
              throw "Error pulling image"
          }
          $traefikVersion = "v1.7.33"

          New-Item 'C:\build\Traefik' -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
          Set-Location 'C:\build\Traefik'

          @"
FROM $serverCoreImage
SHELL ["powershell", "-Command", "`$ErrorActionPreference = 'Stop'; `$ProgressPreference = 'SilentlyContinue';"]
RUN Invoke-WebRequest \
    -Uri "https://github.com/traefik/traefik/releases/download/$traefikVersion/traefik_windows-amd64.exe" \
    -OutFile "/traefik.exe"
EXPOSE 80
ENTRYPOINT [ "/traefik" ]
# Metadata
LABEL org.opencontainers.image.vendor="Traefik Labs" \
    org.opencontainers.image.url="https://traefik.io" \
    org.opencontainers.image.title="Traefik" \
    org.opencontainers.image.description="A modern reverse-proxy" \
    org.opencontainers.image.version="$traefikVersion" \
    org.opencontainers.image.documentation="https://docs.traefik.io"
"@ | Set-Content 'DOCKERFILE'

          docker build --tag $imageName .
          
          if (!$doNotUpdateConfig) {
            Write-Host "Set custom Traefik image in BcContainerHelper config"
            $bcContainerHelperConfig.TraefikImage = $imageName + ":latest"
            $bcContainerHelperConfig | ConvertTo-Json | Set-Content "C:\ProgramData\BcContainerHelper\BcContainerHelper.config.json"
          }

          Set-Location $originalPath
      } catch {
          Set-Location $originalPath

          throw $_
      }
    }
}
Export-ModuleMember -Function Create-CustomTraefikImage
