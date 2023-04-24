<# 
 .Synopsis
  Create Traefik image for currently used windows server version.
 .Description
  Create a custom Traefik docker image, based on the best generic image version according to your Windows version.
  This is useful when using Windows Server 2022 for example, where no prebuilt image is provided.
 .Parameter traefikVersion
  Version of Traefik to use. Default value is v1.7.33
 .Parameter imageName
  Name of the docker image, which will be created. Default value is mytraefik:$traefikVersion
 .Parameter doNotUpdateConfig
  Specifies to only create the traefik image, but not updating the BcContainerHelper configuration to use this Traefik image.
 .Example
  Create-CustomTraefikImage -imageName mytraefik
#>
function Create-CustomTraefikImage {
    [CmdletBinding()]
    Param (
        [string] $traefikVersion = '',
        [string] $imageName = '',
        [switch] $doNotUpdateConfig
    )    

    # Set default traefikVersion if not specified
    if ([String]::IsNullOrEmpty($traefikVersion)) {
        $traefikVersion = "v1.7.33"
    }

    # Set default imageName if not specified
    if ([String]::IsNullOrEmpty($imageName)) {
        $imageName = "mytraefik:$traefikVersion"
    }

    # Add :latest if no tag is specified
    if ($imageName -notlike "*:*") {
        $imageName += ":$traefikVersion"
    }

    # Use TempFolder under hostHelperFolder
    $tempFolder = Join-Path $bcContainerHelperConfig.hostHelperFolder ([GUID]::NewGuid().ToString())
    New-Item $tempFolder -ItemType Directory | Out-Null
    Push-Location -Path $tempFolder
    try {
        $bestGenericImage = Get-BestGenericImageName
        $servercoreVersion = $bestGenericImage.Split(':')[1].Split('-')[0]
        $serverCoreImage = "mcr.microsoft.com/windows/servercore:$serverCoreVersion"

        Write-Host "Pulling $serverCoreImage (this might take some time)"
        if (!(DockerDo -imageName $serverCoreImage -command 'pull'))  {
            throw "Error pulling image"
        }

        Download-File -SourceUrl "https://github.com/traefik/traefik/releases/download/$traefikVersion/traefik_windows-amd64.exe" -DestinationFile (Join-Path $tempFolder "traefik.exe")

        @"
FROM $serverCoreImage
SHELL ["powershell", "-Command", "`$ErrorActionPreference = 'Stop'; `$ProgressPreference = 'SilentlyContinue';"]
COPY traefik.exe traefik.exe
EXPOSE 80
ENTRYPOINT [ "/traefik.exe" ]
# Metadata
LABEL org.opencontainers.image.vendor="Traefik Labs" \
    org.opencontainers.image.url="https://traefik.io" \
    org.opencontainers.image.title="Traefik" \
    org.opencontainers.image.description="A modern reverse-proxy" \
    org.opencontainers.image.version="$traefikVersion" \
    org.opencontainers.image.documentation="https://docs.traefik.io"
"@ | Set-Content 'DOCKERFILE'

        docker build --tag $imageName . | Out-Host

        if (!$doNotUpdateConfig) {
            $bcContainerHelperConfig.TraefikImage = $imageName
            Write-Host "Set custom Traefik image in BcContainerHelper config"
            # Only change TraefikImage setting - do not write all settings
            $bcContainerHelperConfigFile = "C:\ProgramData\BcContainerHelper\BcContainerHelper.config.json"
            $config = Get-Content $bcContainerHelperConfigFile -Encoding UTF8 | ConvertFrom-Json
            if (!($config.PSObject.Properties.Name -eq 'TraefikImage')) {
                $config | Add-Member -MemberType NoteProperty -Name 'TraefikImage' -Value $imageName
            }
            else {
                $config.TraefikImage = $imageName
            }
            $config | ConvertTo-Json | Set-Content -Encoding UTF8 -Path $bcContainerHelperConfigFile
        }

        $imageName
    } finally {
        Pop-Location
        Remove-Item $tempFolder -Recurse -Force
    }
}
Export-ModuleMember -Function Create-CustomTraefikImage
