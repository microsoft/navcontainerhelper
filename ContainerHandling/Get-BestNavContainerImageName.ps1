<# 
 .Synopsis
  Get Best NAV/BC Container Image Name
 .Description
  If a Container Os platform name is not specified in the imageName, find the best container os and add it (if his is a microsoft image)
 .Parameter imageName
  Name of image
 .Example
  $imageName = Get-BestBcContainerImageName -imageName $imageName
#>
function Get-BestBcContainerImageName {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, ValueFromPipeline)]
        [string] $imageName
    )

    if (!(
          $imagename.EndsWith('-ltsc2016') -or
          $imagename.EndsWith('-1709') -or
          $imagename.EndsWith('-1803') -or
          $imagename.EndsWith('-ltsc2019') -or
          $imagename.EndsWith('-1903') -or
          $imagename.EndsWith('-1909') -or
          $imagename.EndsWith('-2004') -or
          $imagename.EndsWith(':ltsc2016') -or
          $imagename.EndsWith(':1709') -or
          $imagename.EndsWith(':1803') -or
          $imagename.EndsWith(':ltsc2019') -or
          $imagename.EndsWith(':1903') -or
          $imagename.EndsWith(':1909') -or
          $imagename.EndsWith(':2004')
    )) {

        if ($imagename.StartsWith('microsoft/') -or 
            $imagename.StartsWith('bcprivate.azurecr.io/') -or 
            $imagename.StartsWith('bcinsider.azurecr.io/') -or 
            $imagename.StartsWith('mcr.microsoft.com/') -or 
            $imagename.StartsWith('mcrbusinesscentral.azurecr.io/')) {

            $os = (Get-CimInstance Win32_OperatingSystem)
            if ($os.OSType -eq 18 -and $os.Version.StartsWith("10.0.")) {
                $bestContainerOs = "ltsc2016"
                if ($os.BuildNumber -ge 17763) { 
                    $bestContainerOs = "ltsc2019"
                }

                if (!$imageName.Contains(':')) {
                    $imageName += ":$bestContainerOs"
                } else {
                    $imageName += "-$bestContainerOs"
                }
            }
        }
    }
    
    $imageName
}
Set-Alias -Name Get-BestNavContainerImageName -Value Get-BestBcContainerImageName
Export-ModuleMember -Function Get-BestBcContainerImageName -Alias Get-BestNavContainerImageName
