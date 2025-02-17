<# 
 .Synopsis
  Get the URL of the latest AL Language Extension from VS Code Marketplace
 .Description
  Get the URL of the latest AL Language Extension from VS Code Marketplace
 .Parameter vsixFile
  The name of the VSIX file to download. This can ba a full VSCode Marketplace URL or a local path.
  If 'latest' is specified, the latest version will be downloaded.
  If 'preview' is specified, the latest preview version will be downloaded. You can also use the switch -allowPrerelease.
 .Parameter allowPrerelease
  If specified, will return the URL of the latest version (including pre-release versions) of the AL Language Extension
 .Example
  New-BcContainer ... -vsixFile (Get-LatestAlLanguageExtensionUrl) ...
 .Example
  Download-File -SourceUrl (Get-LatestAlLanguageExtensionUrl) -DestinationFile "c:\temp\al.vsix"
#>
function Get-LatestAlLanguageExtensionUrl {
    param (
		[string] $vsixFile = 'latest',
        [switch] $allowPrerelease
    )

	$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()

	try {
		$version, $isPrerelease, $url = GetAlLanguageExtensionVersionAndUrl -vsixFile $vsixFile -allowPrerelease:$allowPrerelease;

		return $url
	}

	catch {
		TrackException -telemetryScope $telemetryScope -errorRecord $_
		throw
	}

	finally {
		TrackTrace -telemetryScope $telemetryScope
	}
}

Export-ModuleMember -Function Get-LatestAlLanguageExtensionUrl;
