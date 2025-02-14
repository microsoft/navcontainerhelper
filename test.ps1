Import-Module -Name "C:\Dev\Tools\_ext\navcontainerhelper\BCContainerHelper.psm1" -Scope Local;

$version = '25.2.27733.28402';
$artifactUrl = "https://bcartifacts-exdbf9fwegejdqak.b02.azurefd.net/sandbox/$version/de";
#$vsixFile = Get-LatestAlLanguageExtension -vsixFile 'latest' -allowPrerelease;
$cacheFolder = "C:\Temp\CompilerCache\$version";

#$daFolda = New-BcCompilerFolder -artifactUrl $artifactUrl -containerName "sandbox-$version" -vsixFile $vsixFile; #-cacheFolder $cacheFolder

############

$vsixFile = Get-LatestAlLanguageExtension -vsixFile '';

$cred = (New-Object System.Management.Automation.PSCredential -ArgumentList 'admin', (ConvertTo-SecureString -String 'modus' -AsPlainText -Force));
New-BcContainer -accept_eula -accept_insiderEula -accept_outdated -containerName 'compiler-test' -artifactUrl $artifactUrl -Credential $cred -auth UserPassword -updateHosts;

exit;


$listing = Invoke-WebRequest -Method POST -UseBasicParsing `
	-Uri 'https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery?api-version=3.0-preview.1' `
	-Body '{"filters":[{"criteria":[{"filterType":8,"value":"Microsoft.VisualStudio.Code"},{"filterType":12,"value":"4096"},{"filterType":7,"value":"ms-dynamics-smb.al"}],"pageNumber":1,"pageSize":50,"sortBy":0,"sortOrder":0}],"assetTypes":[],"flags":0x192}' `
	-ContentType 'application/json' | ConvertFrom-Json;

$results = $listing.results | Select-Object -First 1 -ExpandProperty 'extensions' | Select-Object -ExpandProperty 'versions';
$results = $results | Select-Object -First 15;

$results | ForEach-Object {
	$result = $_;
	$vsixUrl = $result.files | Where-Object { $_.assetType -eq "Microsoft.VisualStudio.Services.VSIXPackage"} | Select-Object -ExpandProperty 'source';

	$vsixFile = Get-LatestAlLanguageExtension -vsixFile $vsixUrl -extract -skipCleanup;
}
