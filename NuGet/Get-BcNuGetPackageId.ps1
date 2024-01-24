<# 
 .Synopsis
  PROOF OF CONCEPT PREVIEW: Get Business Central NuGet Package Id from Publisher, Name and Id
 .Description
  Get Business Central NuGet Package Id from Publisher, Name and Id
 .OUTPUTS
  string
  Package Id
 .PARAMETER packageIdTemplate
  Template for package id with placeholders for publisher, name, id and version
 .PARAMETER publisher
  App Publisher (will be normalized)
 .PARAMETER name
  App name (will be normalized)
 .PARAMETER id
  App Id (must be a GUID)
 .PARAMETER tag
  Tag to add to the package id
 .PARAMETER version
  App Version
 .EXAMPLE
  Get-BcNuGetPackageId -publisher 'Freddy Kristiansen' -name 'Bing Maps PTE' -id '165d73c1-39a4-4fb6-85a5-925edc1684fb'
#>
function Get-BcNuGetPackageId {
    Param(
        [Parameter(Mandatory=$false)]
        [string] $packageIdTemplate = '{publisher}.{name}.{tag}.{id}',
        [Parameter(Mandatory=$true)]
        [string] $publisher,
        [Parameter(Mandatory=$true)]
        [string] $name,
        [Parameter(Mandatory=$true)]
        [string] $id,
        [Parameter(Mandatory=$false)]
        [string] $tag = '',
        [Parameter(Mandatory=$false)]
        [string] $version = ''
    )

    try { $id = ([GUID]::Parse($id)).Guid } catch { throw "Package id must be a valid GUID: $id" }
    $nname = [nuGetFeed]::Normalize($name)
    $npublisher = [nuGetFeed]::Normalize($publisher)
    if ($nname -eq '') { throw "Package name is invalid: '$name'" }
    if ($npublisher -eq '') { throw "Package publisher is invalid: '$publisher'" }
    $packageIdTemplate = $packageIdTemplate.replace('{id}',$id).replace('{publisher}',$npublisher).replace('{tag}',$tag).replace('..','.').replace('{version}',$version)
    $packageId = $packageIdTemplate.replace('{name}',$nname)
    if ($packageId.Length -ge 100) {
        if ($nname.Length -gt ($packageId.Length - 99)) {
            $nname = $nname.Substring(0, $nname.Length - ($packageId.Length - 99))
        }
        else {
            throw "Package id is too long: $packageId, unable to shorten it"
        }
        $packageId = $packageIdTemplate.replace('{name}',$nname)
    }
    return $packageId
}
Export-ModuleMember -Function Get-BcNuGetPackageId
