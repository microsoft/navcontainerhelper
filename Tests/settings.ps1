$Source = @"
	using System.Net;
 
	public class MyWebClient : WebClient
	{
		protected override WebRequest GetWebRequest(System.Uri address)
		{
			WebRequest request = base.GetWebRequest(address);
			if (request != null)
			{
				request.Timeout = -1;
			}
			return request;
		}
 	}
"@;
 
Add-Type -TypeDefinition $Source -Language CSharp -WarningAction SilentlyContinue | Out-Null

$imageName = "microsoft/dynamics-nav:2018"
$imageName2 = "microsoft/dynamics-nav:2018-dk"

$licenseFile = "c:\programdata\navcontainerhelper\license.flf"
if (!(Test-Path $licenseFile)) {
    throw "License file must be in $licenseFile to run test"
}

$navDvdUrl = "http://download.microsoft.com/download/F/D/1/FD164E3F-9FB2-46DB-B314-065D86ACA3B1/CU%2014%20NAV%202017%20W1.zip"
$navDvdPath = "c:\programdata\navcontainerhelper\navdvd"
if (!(Test-Path -Path $navDvdPath -PathType Container)) {
    Download-File -sourceUrl $navDvdUrl -destinationFile "${navDvdPath}.zip"
    Write-Host "Expanding .zip file"
    Expand-Archive -Path "${navDvdPath}.zip" -DestinationPath "${navDvdPath}.temp"
    (Get-item -Path "${navDvdPath}.temp\*.zip").FullName
    Write-Host "Expanding NAV DVD"
    $zipname = (Get-item -Path "${navDvdPath}.temp\*.zip").FullName
    Expand-Archive -Path $zipname -DestinationPath $navdvdPath
    Write-Host "Cleaning up"
    Remove-Item -Path "${navdvdPath}.temp" -Recurse -Force
    Remove-Item -Path "$navdvdPath.zip" -Force
}

if ($credential -eq $null -or $credential -eq [System.Management.Automation.PSCredential]::Empty) {
    $credential = Get-Credential -Username $env:USERNAME -Message "Enter a set of credentials to use for containers in the tests"
}
$sqlCredential = New-Object System.Management.Automation.PSCredential ('sa', $credential.Password)

#docker pull $imageName
#docker pull $imageName2
