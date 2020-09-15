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
 .Parameter IP
  IP Address to use for binding. If you don't specify, the function will grab the IP address of the first dhcp adapter 
 .Parameter traefikToml
  Path/Url of the toml file for traefik
 .Parameter CrtFile
  Path/Url of the certificate crt file for using your own domain
 .Parameter CrtKeyFile
  Path/Url of the certificate key file for using your own domain
 .Parameter Recreate
  Switch to recreate traefik container and discard all existing configuration
 .Parameter isolation
  Isolation mode for the traefik container (default is process for Windows Server host else hyperv)
 .Parameter forceHttpWithTraefik
  Use this parameter to force http (disable SSL) although traefik is used. This will mean that the mobile apps and
  the modern Windows app won't work
 .Example
  Setup-TraefikContainerForBcContainers -PublicDnsName "dev.mycorp.com" -ContactEMailForLetsEncrypt admin@mycorp.com
 .Example
  Setup-TraefikContainerForBcContainers -PublicDnsName "dev.mycorp.com" -CrtFile "c:\my\cert.crt" -CrtKeyFile "c:\my\cert.key"
#>
function Setup-TraefikContainerForBcContainers {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [string] $PublicDnsName,
        [Parameter(Mandatory=$true, ParameterSetName="LetsEncrypt")]
        [string] $ContactEMailForLetsEncrypt,
        [switch] $overrideDefaultBinding,
        [string] $IP = "",
        [Parameter(Mandatory=$false)]
        [string] $traefikToml = (Join-Path $PSScriptRoot "traefik\template_traefik_https.toml"),
        [Parameter(Mandatory=$true, ParameterSetName="OwnCertificate")]
        [string] $CrtFile,
        [Parameter(Mandatory=$true, ParameterSetName="OwnCertificate")]
        [string] $CrtKeyFile,
        [Switch] $Recreate,
        [ValidateSet('','process','hyperv')]
        [string] $isolation = "",
        [switch] $forceHttpWithTraefik
    )

    Process {
        $traefikForBcBasePath = "c:\programdata\bccontainerhelper\traefikforbc"
        $traefikDockerImage = "stefanscherer/traefik-windows:v1.7.12"
        $traefiktomltemplate = (Join-Path $traefikForBcBasePath "config\template_traefik.toml")
        if ($forceHttpWithTraefik) {
            $traefikToml = (Join-Path $PSScriptRoot "traefik\template_traefik.toml")
        }
        $CrtFilePath = (Join-Path $traefikForBcBasePath "config\certificate.crt")
        $CrtKeyFilePath = (Join-Path $traefikForBcBasePath "config\certificate.key")

        if ($Recreate){
            Write-Host "Removing running Instances of the Traefik container"
            docker images --filter "label=org.label-schema.name=Traefik" --format "{{.ID}}" | ForEach-Object { docker ps --filter ancestor=$_ --format "{{.ID}}" } | ForEach-Object { docker rm $_ -f }
            Write-Host "Removing old Traefik configuration"
            if (Test-Path -Path $traefikForBcBasePath){
                remove-item -Path $traefikForBcBasePath -Recurse -force 
            }
        }

        if (Test-Path -Path (Join-Path $traefikForBcBasePath "traefik.txt") -PathType Leaf) {
            Write-Host "Traefik container already initialized."
            return
        }

        if ($traefikToml -is [string]) {
            if ($traefikToml.ToLower().StartsWith("http://") -or $traefikToml.ToLower().StartsWith("https://")) {
                $traefikTomlFile = (Join-Path $PSScriptRoot "traefik\template_traefik_custom.toml")
                (New-Object System.Net.WebClient).DownloadFile($traefikToml, $traefikTomlFile)
            } else {
                if (!(Test-Path $traefikToml)) {
                    throw "File $traefikToml does not exist"
                } else {
                    $traefikTomlFile = $traefikToml
                }
            }
        } else {
            throw "Illegal value in traefikToml"
        }

        Write-Host "Creating folder structure at $traefikForBcBasePath"
        New-Item $traefikForBcBasePath -ItemType Directory
        New-Item (Join-Path $traefikForBcBasePath "traefik.txt") -ItemType File
        New-Item (Join-Path $traefikForBcBasePath "my") -ItemType Directory
        New-Item (Join-Path $traefikForBcBasePath "config") -ItemType Directory
        New-Item (Join-Path $traefikForBcBasePath "config\acme.json") -ItemType File

        Copy-Item $traefikTomlFile -Destination $traefiktomltemplate
        if ($forceHttpWithTraefik) {
            Copy-Item (Join-Path $PSScriptRoot "traefik\CheckHealth.ps1") -Destination (Join-Path $traefikForBcBasePath "my\CheckHealth.ps1")
        } else {
            Copy-Item (Join-Path $PSScriptRoot "traefik\CheckHealth_https.ps1") -Destination (Join-Path $traefikForBcBasePath "my\CheckHealth.ps1")
        }

        if($CrtFile) {
            if ($CrtFile -is [string]) {
                if ($CrtFile.ToLower().StartsWith("http://") -or $CrtFile.ToLower().StartsWith("https://")) {
                    (New-Object System.Net.WebClient).DownloadFile($CrtFile, $CrtFilePath)
                } else {
                    if (!(Test-Path $CrtFile)) {
                        throw "File $CrtFile does not exist"
                    } else {
                        Copy-Item $CrtFile -Destination $CrtFilePath
                    }
                }
            } else {
                throw "Illegal value in CrtFile"
            }
        }

        if($CrtKeyFile) {
            if ($CrtKeyFile -is [string]) {
                if ($CrtKeyFile.ToLower().StartsWith("http://") -or $CrtKeyFile.ToLower().StartsWith("https://")) {
                    (New-Object System.Net.WebClient).DownloadFile($CrtKeyFile, $CrtKeyFilePath)
                } else {
                    if (!(Test-Path $CrtKeyFile)) {
                        throw "File $CrtKeyFile does not exist"
                    } else {
                        Copy-Item $CrtKeyFile -Destination $CrtKeyFilePath
                    }
                }
            } else {
                throw "Illegal value in CertKeyFile"
            }
        }

        Write-Host "Create traefik config file"
        $template = Get-Content $traefiktomltemplate -Raw
        if ($IP -eq "") {
            $IP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object PrefixOrigin -eq "Dhcp" | Select-Object -First 1).IPAddress
        }
        $expanded = Invoke-Expression "@`"`r`n$template`r`n`"@"
        $expanded | Out-File (Join-Path $traefikForBcBasePath "config\traefik.toml") -Encoding ASCII

        if ($overrideDefaultBinding) {
            Write-Host "Change standard port as Traefik will handle that. Content previously avaiable on port 80 will be available on 8180"
            Set-WebBinding -Name 'Default Web Site' -BindingInformation "*:80:" -PropertyName Port -Value 8180
            New-NetFirewallRule -DisplayName "Allow 8180" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 8180
        }

        Log "Pulling and running traefik"
        docker pull $traefikDockerImage
        if ($isolation) {
            docker run -p 8080:8080 -p 443:443 -p 80:80 --restart always --isolation $isolation -d -v ((Join-Path $traefikForBcBasePath "config") + ":c:/etc/traefik") -v \\.\pipe\docker_engine:\\.\pipe\docker_engine $traefikDockerImage --docker.endpoint=npipe:////./pipe/docker_engine
        }
        else {
            docker run -p 8080:8080 -p 443:443 -p 80:80 --restart always -d -v ((Join-Path $traefikForBcBasePath "config") + ":c:/etc/traefik") -v \\.\pipe\docker_engine:\\.\pipe\docker_engine $traefikDockerImage --docker.endpoint=npipe:////./pipe/docker_engine
        }
    }
}
Set-Alias -Name Setup-TraefikContainerForNavContainers -Value Setup-TraefikContainerForBcContainers
Export-ModuleMember -Function Setup-TraefikContainerForBcContainers -Alias Setup-TraefikContainerForNavContainers
