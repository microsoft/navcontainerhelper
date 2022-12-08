param(
    [switch] $Silent,
    [string[]] $bcContainerHelperConfigFile = @(),
    [string] $moduleName,
	[string[]] $moduleDependencies = @()
)

Set-StrictMode -Version 2.0

$verbosePreference = "SilentlyContinue"
$warningPreference = 'Continue'
$errorActionPreference = 'Stop'

if ([intptr]::Size -eq 4) {
    throw "ContainerHelper cannot run in Windows PowerShell (x86), need 64bit mode"
}

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdministrator = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$isInsideContainer = ((whoami) -eq "user manager\containeradministrator")

try {
    $myUsername = $currentPrincipal.Identity.Name
} catch {
    $myUsername = (whoami)
}

$BcContainerHelperVersion = Get-Content (Join-Path $PSScriptRoot "Version.txt")
if (!$silent) {
    Write-Host "$($moduleName.SubString(0,$moduleName.Length-5)) version $BcContainerHelperVersion"
}
$isInsider = $BcContainerHelperVersion -like "*-dev" -or $BcContainerHelperVersion -like "*-preview*"

$Source = @"
	using System.Net;
 
	public class TimeoutWebClient : WebClient
	{
        int theTimeout;

        public TimeoutWebClient(int timeout)
        {
            theTimeout = timeout;
        }

		protected override WebRequest GetWebRequest(System.Uri address)
		{
			WebRequest request = base.GetWebRequest(address);
			if (request != null)
			{
				request.Timeout = theTimeout;
			}
			return request;
		}
 	}
"@;
 
try {
    Add-Type -TypeDefinition $Source -Language CSharp -WarningAction SilentlyContinue | Out-Null
}
catch {}

if ($isInsider) { 
    $depVersion = "0.0"
}
else {
    $depVersion = $BcContainerHelperVersion.split('-')[0]
}

$moduleDependencies | ForEach-Object {
    $module = Get-Module $_
    if ($module -ne $null -and $module.Version -lt [Version]$depVersion) {
        Write-Error "Module $_ is already loaded in version $($module.Version). This module requires version $depVersion. Please reinstall BC modules."
    }
    elseif ($module -eq $null) {
        Import-Module $_ -MinimumVersion $depVersion -DisableNameChecking -Global -ArgumentList $silent,$bcContainerHelperConfigFile    }
}

