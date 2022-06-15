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
        [Object[]] $argumentList,
        [bool] $useSession = $bcContainerHelperConfig.usePsSession
    )

    $file = Join-Path $hostHelperFolder ([GUID]::NewGuid().Tostring()+'.ps1')
    $containerFile = ""
    if (!$useSession) {
        if ($isInsideContainer) {
            $useSession = $true
        }
        else {
            $containerFile = Get-BcContainerPath -containerName $containerName -path $file
            if ("$containerFile" -eq "") {
                $useSession = $true
            }
        }
    }

    if ($useSession) {
        try {
            $session = Get-BcContainerSession -containerName $containerName -silent
        }
        catch {
            if ($isInsideContainer) {
                Start-Sleep -Seconds 5
                $session = Get-BcContainerSession -containerName $containerName -silent
            }
            else {
                $useSession = $false
            }
        }
    }
    if ($useSession) {
        $startTime = [DateTime]::Now
        try {
            Invoke-Command -Session $session -ScriptBlock $scriptblock -ArgumentList $argumentList
        }
        catch {
            $errorMessage = $_.Exception.Message
            Write-Host -ForegroundColor Red $errorMessage
            Write-Host
            Write-Host "Exception Script Stack Trace:"
            Write-Host -ForegroundColor Red $_.scriptStackTrace
            Write-Host
            Write-Host "PowerShell Call Stack:"
            Get-PSCallStack | Write-Host -ForegroundColor Red
            try {
               $isOutOfMemory = Invoke-Command -Session $session -ScriptBlock { Param($containerName, $startTime)
                    $cimInstance = Get-CIMInstance Win32_OperatingSystem
                    Write-Host "`nContainer Free Physical Memory: $(($cimInstance.FreePhysicalMemory/1024/1024).ToString('F1',[CultureInfo]::InvariantCulture))Gb"
                    $any = $false
                    Write-Host "`nServices in container $($containerName):"
                    Get-Service |
                        Where-Object { $_.Name -like "MicrosoftDynamics*" -or $_.Name -like "MSSQL`$*" } |
                        Select-Object -Property name, Status |
                        ForEach-Object {
                            if ($_.Status -eq "Running") {
                                Write-Host "- $($_.Name) is $($_.Status)"
                            }
                            else {
                                Write-Host -ForegroundColor Red "- $($_.Name) is $($_.Status)"
                            }
                            $any = $true
                        }
                    if (!$any) { Write-Host -ForegroundColor Red "- No services found" }
                    Write-Host
                    $any = $false
                    $isOutOfMemory = $false
                    Get-EventLog -LogName Application | 
                        Where-Object { $_.EntryType -eq "Error" -and $_.TimeGenerated -gt $startTime -and ($_.Source -like "MicrosoftDynamics*" -or $_.Source -like "MSSQL`$*") } | 
                        Select-Object -Property TimeGenerated, Source, Message |
                        ForEach-Object {
                            if (!$any) {
                                Write-Host "`nRelevant event log from container $($containerName):"
                            }
                            Write-Host -ForegroundColor Red "- $($_.TimeGenerated.ToString('yyyyMMdd hh:mm:ss')) - $($_.Source)"
                            Write-Host -ForegroundColor Gray "`n  $($_.Message.Replace("`n","`n  "))`n"
                            if ($_.Message.Contains('OutOfMemoryException')) { $isOutOfMemory = $true }
                            $any = $true
                        }
                    $isOutOfMemory
                } -ArgumentList $containerName, $startTime
                if ($isOutOfMemory) {
                    $errorMessage = "Out Of Memory Exception thrown inside container $containerName"
                }
            } catch {}
            throw $errorMessage
        }
    } else {
        if ("$containerFile" -eq "") {
            $containerFile = Get-BcContainerPath -containerName $containerName -path $file -throw
        }
        $hostOutputFile = "$file.output"
        $containerOutputFile = "$containerFile.output"
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

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

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
$ErrorActionPreference = "Stop"
$startTime = [DateTime]::Now
' | Add-Content $file

"`$containerName = '$containerName'
" | Add-Content $file

            if ($bcContainerHelperConfig.addTryCatchToScriptBlock) {
                if ($scriptblock.Ast.ParamBlock) {
                    $script = $scriptBlock.Ast.Extent.text.Replace($scriptblock.Ast.ParamBlock.Extent.Text,'').Trim()
                    if ($script.StartsWith('{')) {
                        "`$result = Invoke-Command -ScriptBlock { $($scriptblock.Ast.ParamBlock.Extent.Text) try $script catch { ""::EXCEPTION::`$(`$_.Exception.Message)"" } } -ArgumentList `$argumentList" | Add-Content $file
                    }
                    else {
                        "`$result = Invoke-Command -ScriptBlock { $($scriptblock.Ast.ParamBlock.Extent.Text) try { $script } catch { ""::EXCEPTION::`$(`$_.Exception.Message)"" } } -ArgumentList `$argumentList" | Add-Content $file
                    }
                }
                else {
                    "`$result = Invoke-Command -ScriptBlock { try $($scriptBlock.Ast.Extent.text) catch { ""::EXCEPTION::`$(`$_.Exception.Message)"" } }" | Add-Content $file
                }
@'
$exception = $result | Where-Object { $_ -like "::EXCEPTION::*" }
if ($exception) {
    $errorMessage = $exception.SubString(13)
    Write-Host -ForegroundColor Red "$errorMessage"
    Write-Host
    try {
       $isOutOfMemory = Invoke-Command -ScriptBlock { Param($containerName, $startTime)
            $cimInstance = Get-CIMInstance Win32_OperatingSystem
            Write-Host "Container Free Physical Memory: $(($cimInstance.FreePhysicalMemory/1024/1024).ToString('F1',[CultureInfo]::InvariantCulture))Gb"
            $any = $false
            Write-Host "`nServices in container $($containerName):"
            Get-Service |
                Where-Object { $_.Name -like "MicrosoftDynamics*" -or $_.Name -like "MSSQL`$*" } |
                Select-Object -Property name, Status |
                ForEach-Object {
                    if ($_.Status -eq "Running") {
                        Write-Host "- $($_.Name) is $($_.Status)"
                    }
                    else {
                        Write-Host -ForegroundColor Red "- $($_.Name) is $($_.Status)"
                    }
                    $any = $true
                }
            if (!$any) { Write-Host -ForegroundColor Red "- No services found" }
            Write-Host
            $any = $false
            $isOutOfMemory = $false
            Get-EventLog -LogName Application | 
                Where-Object { $_.EntryType -eq "Error" -and $_.TimeGenerated -gt $startTime -and ($_.Source -like "MicrosoftDynamics*" -or $_.Source -like "MSSQL`$*") } | 
                Select-Object -Property TimeGenerated, Source, Message |
                ForEach-Object {
                    if (!$any) {
                        Write-Host "`nRelevant event log from container $($containerName):"
                    }
                    Write-Host -ForegroundColor Red "- $($_.TimeGenerated.ToString('yyyyMMdd hh:mm:ss')) - $($_.Source)"
                    $message = @($_.Message.Split("`n") | Select-Object -First 15) -join "`n  "
                    Write-Host -ForegroundColor Gray "`n  $($message)`n"
                    if ($_.Message.Contains('OutOfMemoryException')) { $isOutOfMemory = $true }
                    $any = $true
                }
            $isOutOfMemory
        } -ArgumentList $containerName, $startTime
        if ($isOutOfMemory) {
            $errorMessage = "Out Of Memory Exception thrown inside container $containerName"
        }
    } catch {}

    $result = @("::EXCEPTION::$errorMessage") + @($result | Where-Object { $_ -notlike "::EXCEPTION::*" })
}
'@ | Add-Content $file

'if ($result -ne $null) { [System.Management.Automation.PSSerializer]::Serialize($result) | Set-Content "'+$containerOutputFile+'" }' | Add-Content $file

#Write-Host -ForegroundColor cyan (Get-Content $file -Raw -Encoding UTF8)

                $ErrorActionPreference = "Stop"
                docker exec $containerName powershell $containerFile | Out-Host
                if($LASTEXITCODE -ne 0) {
                    Remove-Item $file -Force -ErrorAction SilentlyContinue
                    Remove-Item $hostOutputFile -Force -ErrorAction SilentlyContinue
                    throw "Error executing script in Container"
                }
                if (Test-Path -Path $hostOutputFile -PathType Leaf) {

#Write-Host -ForegroundColor Cyan "'$(Get-content $hostOutputFile -Raw -Encoding UTF8)'"
                    $result = [System.Management.Automation.PSSerializer]::Deserialize((Get-content $hostOutputFile))
                    $exception = $result | Where-Object { $_ -like "::EXCEPTION::*" }
                    if ($exception) {
                        $errorMessage = $exception.SubString(13)
                        throw $errorMessage
                    }
                    $result
                }
            }
            else {
                '$result = Invoke-Command -ScriptBlock {' + $scriptblock.ToString() + '} -ArgumentList $argumentList' | Add-Content $file
                'if ($result) { [System.Management.Automation.PSSerializer]::Serialize($result) | Set-Content "'+$containerOutputFile+'" }' | Add-Content $file
                $ErrorActionPreference = "Stop"
                docker exec $containerName powershell $containerFile | Out-Host
                if($LASTEXITCODE -ne 0) {
                    Remove-Item $file -Force -ErrorAction SilentlyContinue
                    Remove-Item $hostOutputFile -Force -ErrorAction SilentlyContinue
                    throw "Error executing script in Container"
                }
                if (Test-Path -Path $hostOutputFile -PathType Leaf) {
                    [System.Management.Automation.PSSerializer]::Deserialize((Get-content $hostOutputFile))
                }
            }
        } finally {
            Remove-Item $file -Force -ErrorAction SilentlyContinue
            Remove-Item $hostOutputFile -Force -ErrorAction SilentlyContinue
        }
    }
}
Set-Alias -Name Invoke-ScriptInNavContainer -Value Invoke-ScriptInBcContainer
Export-ModuleMember -Function Invoke-ScriptInBcContainer -Alias Invoke-ScriptInNavContainer
