<# 
 .Synopsis
  Copy the NavSip.dll Crypto Provider from a NAV/BC Container and install it locally
 .Description
  The NavSip crypto provider is used when signing extensions
  Extensions cannot be signed inside the container, they need to be signed on the host.
  Beside the NavSip.dll you also need the SignTool.exe which you get with Visual Studio.
 .Parameter containerName
  Name of the container from which you want to copy and install the NavSip.dll
 .Example
  Install-NAVSipCryptoProviderFromBcContainer
#>
function Install-NAVSipCryptoProviderFromBcContainer {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName
    )

    $msvcr120Path = "C:\Windows\System32\msvcr120.dll"
    if (!(Test-Path $msvcr120Path)) {
        Copy-FileFromBcContainer -containerName $containerName -ContainerPath $msvcr120Path
    }

    $navSip64Path = "C:\Windows\System32\NavSip.dll"
    $navSip32Path = "C:\Windows\SysWow64\NavSip.dll"

    RegSvr32 /u /s $navSip64Path
    RegSvr32 /u /s $navSip32Path

    Log "Copy SIP crypto provider from container $containerName"
    Copy-FileFromBcContainer -containerName $containerName -ContainerPath $navSip64Path
    Copy-FileFromBcContainer -containerName $containerName -ContainerPath $navSip32Path

    RegSvr32 /s $navSip32Path
    RegSvr32 /s $navSip64Path
}
Set-Alias -Name Install-NAVSipCryptoProviderFromNavContainer -Value Install-NAVSipCryptoProviderFromBcContainer
Export-ModuleMember -Function Install-NAVSipCryptoProviderFromBcContainer -Alias Install-NAVSipCryptoProviderFromNavContainer
