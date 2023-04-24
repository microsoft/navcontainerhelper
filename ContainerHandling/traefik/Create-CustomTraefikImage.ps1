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
        [string] $traefikVersion = "v1.7.33",
        [switch] $doNotUpdateConfig
    )    

    Process {
      $originalPath = Get-Location
      try {
          $bestGenericImage = Get-BestGenericImageName
          $servercoreVersion = $bestGenericImage.Split(':')[1].Split('-')[0]
          $serverCoreImage = "mcr.microsoft.com/windows/servercore:$serverCoreVersion"

          Write-Host "Pulling $serverCoreImage (this might take some time)"
          if (!(DockerDo -imageName $serverCoreImage -command 'pull'))  {
              throw "Error pulling image"
          }
          
          if ((-not $traefikVersion) -or ($traefikVersion -eq "")) {
              Write-Warning "Parameter 'traefikVersion' is not set or invalid. Using default version 'v1.7.33' instead."
              $traefikVersion = "v1.7.33" # fallback in case of invalid parameter set
          }

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
      } finally {
          Set-Location $originalPath      
      }
    }
}
Export-ModuleMember -Function Create-CustomTraefikImage
