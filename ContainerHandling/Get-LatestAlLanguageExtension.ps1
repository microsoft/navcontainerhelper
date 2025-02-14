<# 
 .Synopsis
  Get back the path of the latest AL Language Extension downloaded from VS Code Marketplace.
 .Description
  Get back the path of the latest AL Language Extension downloaded from VS Code Marketplace.
  All files and folders are created in the $bcContainerHelperConfig.hostHelperFolder.
 .Parameter vsixFile
  The name of the VSIX file to download. This can ba a full VSCode Marketplace URL or a local path.
  If 'latest' is specified, the latest version will be downloaded.
  If 'preview' is specified, the latest preview version will be downloaded. You can also use the switch -allowPrerelease.
 .Parameter allowPrerelease
  If specified, will return the path to the latest pre-release version of the AL Language Extension.
 .Parameter extract
  If specified, the downloaded VSIX file will be extracted to a folder consisting of the version number.
 .Parameter skipCleanup
  If specified, no cleanup in the alLanguageExtension folder will be done. 
  Cleanup is done by default and deletes all vsix files and folders except for the latest 2 per prerelease/non-prerelease.
 .Example
  New-BcContainer ... -vsixFile (Get-LatestAlLanguageExtension -extract) ...
#>
function Get-LatestAlLanguageExtension {
    param (
		[string] $vsixFile = 'latest',
        [switch] $allowPrerelease,
		[switch] $extract,
		[switch] $skipCleanup
    )

	$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()

	try {
		$vsixFile = GetAlLanguageExtension -vsixFile $vsixFile -allowPrerelease:$allowPrerelease -extract:$extract -skipCleanup:$skipCleanup;

		return $vsixFile
	}

	catch {
		TrackException -telemetryScope $telemetryScope -errorRecord $_

		throw
	}

	finally {
		TrackTrace -telemetryScope $telemetryScope
	}
}

Export-ModuleMember -Function Get-LatestAlLanguageExtension;
