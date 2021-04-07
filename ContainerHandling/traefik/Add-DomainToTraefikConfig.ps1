<# 
 .Synopsis
  Add public dns name to traefik configuration.
 .Description
  Check traefik.toml configuration file whether the given public dns name exists or not. 
  If public dns name does not exist it will be extended as a subdomain configuration (sans).
 .Parameter PublicDnsName
  Specifies the public dns name to add in traefik configuration.
 .Example
  Add-DomainToTraefikConfig -PublicDnsName "businesscentral.dynamics.com" 
#>
function Add-DomainToTraefikConfig {
    Param (
        [string]$PublicDnsName
    )

    Write-Host "Looking up for dns Name '$PublicDnsName' in Traefik configuration . . ."

    $tomlFile = (Join-Path -Path $hostHelperFolder -ChildPath "traefikforbc\config\traefik.toml")
    if (-not (Test-Path -Path $tomlFile)) {
        throw "Traefik configuration could not been found! Please call Setup-TraefikContainerForBcContainers before using -useTraefik"
    }
    
    Write-Host "Reading configuration from '$tomlFile'"
    $traefikConfig = Get-Content $tomlFile
    $newTraefikConfig = ""
    $acmeDomainCfg = $false

    foreach ($traefikConfigLine in $traefikConfig) {
        $isAcmeDomainArea = (($traefikConfigLine -match "\[\[acme\.domains\]\]") -or ($traefikConfigLine -match "...main.?=.?") -or ($traefikConfigLine -match "...sans.?=.?\["))
        if ($isAcmeDomainArea) {
            $acmeDomainCfg = $true
        }
        if ($isAcmeDomainArea) {
            switch ($true) {
                ($traefikConfigLine -match "\[\[acme\.domains\]\]") {
                    $newTraefikConfig += "$traefikConfigLine`n"
                }
                # domain configuration
                ($traefikConfigLine -match "...main.?=.?(.*)") {
                    $newTraefikConfig += "$traefikConfigLine`n"
                    if ($Matches[1] -match $PublicDnsName) {
                        Write-Host "DNS name '$PublicDnsName' has been found in Traefik configuration."
                        return
                    }
                }
                # subdomain configuration
                ($traefikConfigLine -match "...sans.?=.?\[(.*)]") { 
                    if ($Matches[1] -match $PublicDnsName) {
                        Write-Host "DNS name '$PublicDnsName' has been found in Traefik configuration (subdomain)."
                        return
                    }
                    # if domain has not been found in subdomain configuration (sans) add requested domain to list
                    $sansConfiguration = $('"' + $PublicDnsName + '"')
                    foreach ($subdomain in $Matches[1].Split(',')) {
                        if ($sansConfiguration -ne "") {
                            $sansConfiguration += ","
                        }
                        $sansConfiguration += $subdomain
                    } 
                    $newTraefikConfig += "   sans = [$sansConfiguration]`n"

                    $acmeDomainCfg = $false
                    Write-Host "DNS name '$PublicDnsName' has been added to Traefik configuration as subdomain."
                }
            }
        } else {
            # if acme domain configuration has found, but requested domain does not add "sans" configuration to yaml
            if ($acmeDomainCfg -eq $true) {
                $newTraefikConfig += $('   sans = ["' + $PublicDnsName + '"]')
                $newTraefikConfig += "`n"

                $acmeDomainCfg = $false
                Write-Host "DNS name '$PublicDnsName' has been added to Traefik configuration as subdomain."
            }
            $newTraefikConfig += "$traefikConfigLine`n"
        }
    }

    Write-Host "Updating configuration in '$tomlFile'"
    Set-Content -Path $tomlFile -Value $newTraefikConfig

    Write-Host "Please restart traefik container to apply changes in configuration. Otherwise you may face certificate related error messages." -ForegroundColor Yellow
}