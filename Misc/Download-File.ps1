<#
 .Synopsis
  Download File
 .Description
  Download a file to local computer
 .Parameter sourceUrl
  Url from which the file will get downloaded
 .Parameter destinationFile
  Destinatin for the downloaded file
 .Parameter dontOverwrite
  Specify dontOverwrite if you want top skip downloading if the file already exists
 .Parameter timeout
  Timeout in seconds for the download
 .Example
  Download-File -sourceUrl "https://myurl/file.zip" -destinationFile "c:\temp\file.zip" -dontOverwrite
#>
function Download-File {
    Param (
        [Parameter(Mandatory=$true)]
        [string] $sourceUrl,
        [Parameter(Mandatory=$true)]
        [string] $destinationFile,
        [switch] $dontOverwrite,
        [int]    $timeout = 100
    )

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
 
    Add-Type -TypeDefinition $Source -Language CSharp -WarningAction SilentlyContinue | Out-Null

    if (Test-Path $destinationFile -PathType Leaf) {
        if ($dontOverwrite) { 
            return
        }
        Remove-Item -Path $destinationFile -Force
    }
    $path = [System.IO.Path]::GetDirectoryName($destinationFile)
    if (!(Test-Path $path -PathType Container)) {
        New-Item -Path $path -ItemType Directory -Force | Out-Null
    }
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    Write-Host "Downloading $destinationFile"
    (New-Object TimeoutWebClient -ArgumentList (1000*$timeout)).DownloadFile($sourceUrl, $destinationFile)
}
Export-ModuleMember -Function Download-File
