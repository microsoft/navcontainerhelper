<# 
 .Synopsis
  Set up a traefik container to manage traffic for Business Central containers
 .Description
  Set up a traefik container to manage traffic for Business Central containers
 .Parameter PublicDnsName
  The externally reachable FQDN of your Docker host
 .Parameter ContactEMailForLetsEncrypt
  The eMail address to use when requesting an SSL cert from Let's encrypt
 .Parameter overrideDefaultBinding
  Include this switch if you already have an IIS listening on port 80 on your Docker host. This will move the binding on port 80 to port 8180
 .Example
  Setup-TraefikContainerForNavContainers -overrideDefaultBinding
#>
function Setup-TraefikContainerForNavContainers {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$PublicDnsName,
        [Parameter(Mandatory=$true)]
        [string]$ContactEMailForLetsEncrypt,
        [switch]$overrideDefaultBinding
    )

    Process {
        $traefikForBcBasePath = "c:\programdata\navcontainerhelper\traefikforbc"

        if (Test-Path -Path (Join-Path $traefikForBcBasePath "traefik.txt") -PathType Leaf) {
            Write-Host "Traefik container already initialized."
            exit
        }

        Write-Host "Creating folder structure at $traefikForBcBasePath"
        New-Item $traefikForBcBasePath -ItemType Directory
        New-Item (Join-Path $traefikForBcBasePath "traefik.txt") -ItemType File
        New-Item (Join-Path $traefikForBcBasePath "my") -ItemType Directory
        New-Item (Join-Path $traefikForBcBasePath "config") -ItemType Directory
        New-Item (Join-Path $traefikForBcBasePath "config\acme.json") -ItemType File

        Copy-Item (Join-Path $PSScriptRoot "traefik\template_traefik.toml") -Destination (Join-Path $traefikForBcBasePath "config\template_traefik.toml")
        Copy-Item (Join-Path $PSScriptRoot "traefik\CheckHealth.ps1") -Destination (Join-Path $traefikForBcBasePath "my\CheckHealth.ps1")

        Write-Host "Create traefik config file"
        $template = Get-Content (Join-Path $traefikForBcBasePath "config\template_traefik.toml") -Raw
        $expanded = Invoke-Expression "@`"`r`n$template`r`n`"@"
        $expanded | Out-File (Join-Path $traefikForBcBasePath "config\traefik.toml") -Encoding ASCII

        if ($overrideDefaultBinding) {
            Write-Host "Change standard port as Traefik will handle that. Content previously avaiable on port 80 will be available on 8180"
            Set-WebBinding -Name 'Default Web Site' -BindingInformation "*:80:" -PropertyName Port -Value 8180
            New-NetFirewallRule -DisplayName "Allow 8180" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 8180
        }

        Log "Pulling and running traefik"
        docker pull stefanscherer/traefik-windows
        docker run -p 8080:8080 -p 443:443 -p 80:80 --restart always -d -v ((Join-Path $traefikForBcBasePath "config") + ":c:/etc/traefik") -v \\.\pipe\docker_engine:\\.\pipe\docker_engine stefanscherer/traefik-windows --docker.endpoint=npipe:////./pipe/docker_engine
    }
}
Set-Alias -Name Setup-TraefikContainerForBCContainers -Value Setup-TraefikContainerForNavContainers
Export-ModuleMember -Function Setup-TraefikContainerForNavContainers -Alias Setup-TraefikContainerForBCContainers
