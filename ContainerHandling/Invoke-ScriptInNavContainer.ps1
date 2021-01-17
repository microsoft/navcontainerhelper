<# 
 .Synopsis
  Invoke a PowerShell scriptblock in a NAV/BC Container
 .Description
  If you are running as administrator, this function will create a session to a Container and invoke a scriptblock in this session.
  If you are not an administrator, this function will create a PowerShell script in the container and use docker exec to launch the PowerShell script in the container.
 .Parameter containerName
  Name of the container in which you want to invoke a PowerShell scriptblock
 .Parameter scriptblock
  A pre-compiled PowerShell scriptblock to invoke
 .Parameter argumentList
  Arguments to transfer to the scriptblock in form of an object[]
 .Example
  Invoke-ScriptInBcContainer -containerName dev -scriptblock { $env:UserName }
 .Example
  [xml](Invoke-ScriptInBcContainer -containerName dev -scriptblock { Get-Content -Path (Get-item 'c:\Program Files\Microsoft Dynamics NAV\*\Service\CustomSettings.config').FullName })
#>
function Invoke-ScriptInBcContainer {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName, 
        [Parameter(Mandatory=$true)]
        [ScriptBlock] $scriptblock,
        [Parameter(Mandatory=$false)]
        [Object[]] $argumentList
    )

    $useSession = (Get-ContainerHelperConfig).usePsSession

    if ($useSession) {
        try {
            $session = Get-BcContainerSession -containerName $containerName -silent
        }
        catch {
            $useSession = $false
        }
    }
    if ($useSession) {
        try {
            Invoke-Command -Session $session -ScriptBlock $scriptblock -ArgumentList $argumentList
        }
        catch {
            Write-Host -ForegroundColor Red $_.Exception.Message
            Write-Host -ForegroundColor Red $_.ScriptStackTrace
            Get-PSCallStack | Write-Host -ForegroundColor Red
            throw $_.Exception.Message
        }
    } else {
        $file = Join-Path $containerHelperFolder ([GUID]::NewGuid().Tostring()+'.ps1')
        $outputFile = "$file.output"
        try {
            if ($argumentList) {
                $encryptionKey = $null
                $xml = [xml]([System.Management.Automation.PSSerializer]::Serialize($argumentList))
                $nsmgr = New-Object System.Xml.XmlNamespaceManager -ArgumentList $xml.NameTable
                $nsmgr.AddNamespace("ns", "http://schemas.microsoft.com/powershell/2004/04");  
                $nodes = $xml.SelectNodes("//ns:SS", $nsmgr)
                if ($nodes.Count -gt 0) {
                    $encryptionKey = New-Object Byte[] 16
                    [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($encryptionKey)
                    '$encryptionkey = [System.Management.Automation.PSSerializer]::Deserialize('''+([xml]([System.Management.Automation.PSSerializer]::Serialize($encryptionKey))).OuterXml+''')' | Add-Content $file
                }
                foreach($node in $nodes) {
                    $node.InnerText = ConvertFrom-SecureString -SecureString ($node.InnerText | ConvertTo-SecureString) -Key $encryptionkey
                }
                
                $xmlbytes =[System.Text.Encoding]::UTF8.GetBytes($xml.OuterXml)
                '$xmlbytes = [Convert]::FromBase64String('''+[Convert]::ToBase64String($xmlbytes)+''')' | Add-Content $file
                '$xml = [xml]([System.Text.Encoding]::UTF8.GetString($xmlbytes))' | Add-Content $file

                if ($encryptionKey) {
                    '$nsmgr = New-Object System.Xml.XmlNamespaceManager -ArgumentList $xml.NameTable' | Add-Content $file
                    '$nsmgr.AddNamespace("ns", "http://schemas.microsoft.com/powershell/2004/04")' | Add-Content $file
                    '$nodes = $xml.SelectNodes("//ns:SS", $nsmgr)' | Add-Content $file
                    'foreach($node in $nodes) { $node.InnerText = ConvertFrom-SecureString -SecureString ($node.InnerText | ConvertTo-SecureString -Key $encryptionKey) }' | Add-Content $file
                }
                '$argumentList = [System.Management.Automation.PSSerializer]::Deserialize($xml.OuterXml)' | Add-Content $file
            }

'$runPath = "c:\Run"
$myPath = Join-Path $runPath "my"

function Get-MyFilePath([string]$FileName)
{
    if ((Test-Path $myPath -PathType Container) -and (Test-Path (Join-Path $myPath $FileName) -PathType Leaf)) {
        (Join-Path $myPath $FileName)
    } else {
        (Join-Path $runPath $FileName)
    }
}

. (Get-MyFilePath "prompt.ps1") -silent | Out-Null
. (Get-MyFilePath "ServiceSettings.ps1") | Out-Null
. (Get-MyFilePath "HelperFunctions.ps1") | Out-Null

$txt2al = ""
if ($roleTailoredClientFolder) {
    $txt2al = Join-Path $roleTailoredClientFolder "txt2al.exe"
    if (!(Test-Path $txt2al)) {
        $txt2al = ""
    }
}

Set-Location $runPath
' | Add-Content $file

            '$result = Invoke-Command -ScriptBlock {' + $scriptblock.ToString() + '} -ArgumentList $argumentList' | Add-Content $file
            'if ($result) { [System.Management.Automation.PSSerializer]::Serialize($result) | Set-Content "'+$outputFile+'" }' | Add-Content $file
            docker exec $containerName powershell $file
            if($LASTEXITCODE -ne 0) {
                Remove-Item $file -Force -ErrorAction SilentlyContinue
                Remove-Item $outputFile -Force -ErrorAction SilentlyContinue
                throw
            }
            if (Test-Path -Path $outputFile -PathType Leaf) {
                [System.Management.Automation.PSSerializer]::Deserialize((Get-content $outputFile))
            }
        } finally {
            Remove-Item $file -Force -ErrorAction SilentlyContinue
            Remove-Item $outputFile -Force -ErrorAction SilentlyContinue
        }
    }
}
Set-Alias -Name Invoke-ScriptInNavContainer -Value Invoke-ScriptInBcContainer
Export-ModuleMember -Function Invoke-ScriptInBcContainer -Alias Invoke-ScriptInNavContainer
