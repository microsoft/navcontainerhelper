<#
 .SYNOPSIS
  Invoke script inside an Alpaca container.
 .DESCRIPTION
  Invokes a script inside an Alpaca container, outputting the host output of the script to the host and returning the output of the script.
 .Parameter authContext
  Authorization Context for Alpaca obtained by New-BcAuthContext with -clientId $bcContainerHelperConfig.AlpacaSettings.OAuthClientId -Scopes $bcContainerHelperConfig.AlpacaSettings.OAuthScopes
 .PARAMETER containerId
  Container id of the Alpaca Container to invoke a script in.
 .PARAMETER scriptBlock
  ScriptBlock to execute inside the container.
 .PARAMETER argumentList
  ArgumentList to pass to the scriptblock.
 .PARAMETER silent
  If specified, the output to the host from the scriptblock is not output to the host.
 .EXAMPLE
  $authContext = New-BcAuthContext -clientId $bcContainerHelperConfig.AlpacaSettings.OAuthClientId -Scopes $bcContainerHelperConfig.AlpacaSettings.OAuthScopes -includeDeviceLogin
  $container = Get-AlpacaBcContainer -authContext $authContext | Select-Object -First 1
  $result = Invoke-ScriptInAlpacaBcContainer -authContext $authContext -containerId $container.id -scriptblock { Param( [string] $name)
      Write-Host "Returning Hello $name"
      return "Hello $name"
  } -argumentList 'Freddy'
 .EXAMPLE
  $authContext = New-BcAuthContext -clientId $bcContainerHelperConfig.AlpacaSettings.OAuthClientId -Scopes $bcContainerHelperConfig.AlpacaSettings.OAuthScopes -includeDeviceLogin
  $container = Get-AlpacaBcContainer -authContext $authContext | Select-Object -First 1
  $result = Invoke-ScriptInAlpacaBcContainer -authContext $authContext -containerId $container.id -scriptblock {
      Get-NAVServerConfiguration -serverInstance $serverInstance -AsXml
  }
  $result.configuration.appSettings.add
#>
function Invoke-ScriptInAlpacaBcContainer {
    Param (
        [Parameter(Mandatory=$true)]
        [Alias('AlpacaAuthContext')]
        [HashTable] $authContext,
        [Parameter(Mandatory=$true)]
        [string] $containerId,
        [Parameter(Mandatory=$true)]
        [ScriptBlock] $scriptblock,
        [Parameter(Mandatory=$false)]
        [Object[]] $argumentList,
        [switch] $silent
    )

    $sb = [System.Text.StringBuilder]::new()
    if ($argumentList) {
        $xml = [xml]([System.Management.Automation.PSSerializer]::Serialize($argumentList))
        $nsmgr = New-Object System.Xml.XmlNamespaceManager -ArgumentList $xml.NameTable
        $nsmgr.AddNamespace("ns", "http://schemas.microsoft.com/powershell/2004/04");  
        $nodes = $xml.SelectNodes("//ns:SS", $nsmgr)
        foreach($node in $nodes) { $node.InnerText = $node.InnerText | ConvertTo-SecureString | Get-PlainText }
        $xmlbytes =[System.Text.Encoding]::UTF8.GetBytes($xml.OuterXml)
        $sb.AppendLine('$xmlbytes = [Convert]::FromBase64String('''+[Convert]::ToBase64String($xmlbytes)+''')') | Out-Null
        $sb.AppendLine('$xml = [xml]([System.Text.Encoding]::UTF8.GetString($xmlbytes))') | Out-Null
        $sb.AppendLine('$nodes = $xml.SelectNodes("//ns:SS", $nsmgr)') | Out-Null
        $sb.AppendLine('foreach($node in $nodes) { $node.InnerText = ConvertTo-SecureString -String $node.InnerText -AsPlainText -Force | ConvertFrom-SecureString }') | Out-Null
        $sb.AppendLine('$argumentList = [System.Management.Automation.PSSerializer]::Deserialize($xml.OuterXml)') | Out-Null
    }
    else {
        $sb.AppendLine('$argumentList = $null') | Out-Null
    }
    $sb.AppendLine('. c:\run\prompt.ps1 -silent') | Out-Null
    $ast = $scriptblock.Ast
    if ($ast -is [System.Management.Automation.Language.FunctionDefinitionAst]) {
        $ast = $ast.Body
    }
    if ($ast -is [System.Management.Automation.Language.ScriptBlockAst]) {
        if ($ast.ParamBlock) {
            $script = $ast.Extent.text.Replace($ast.ParamBlock.Extent.Text,'').Trim()
            if ($script.StartsWith('{')) {
                $sb.AppendLine("`$result = Invoke-Command -ScriptBlock { $($ast.ParamBlock.Extent.Text) try $script catch { ""::EXCEPTION::`$(`$_.Exception.Message)"" } } -ArgumentList `$argumentList") | Out-Null
            }
            else {
                $sb.AppendLine("`$result = Invoke-Command -ScriptBlock { $($ast.ParamBlock.Extent.Text) try { $script } catch { ""::EXCEPTION::`$(`$_.Exception.Message)"" } } -ArgumentList `$argumentList") | Out-Null
            }
        }
        else {
            $script = $ast.Extent.text.Trim()
            if ($script.StartsWith('{')) {
                $sb.AppendLine("`$result = Invoke-Command -ScriptBlock { try $($ast.Extent.text) catch { ""::EXCEPTION::`$(`$_.Exception.Message)"" } }") | Out-Null
            }
            else {
                $sb.AppendLine("`$result = Invoke-Command -ScriptBlock { try { $($ast.Extent.text) } catch { ""::EXCEPTION::`$(`$_.Exception.Message)"" } }") | Out-Null
            }

        }
    }
    else {
        throw "Unsupported Scriptblock type $($ast.GetType())"
    }
    $sb.AppendLine('return [System.Management.Automation.PSSerializer]::Serialize($result)') | Out-Null
    #$sb.ToString() | Out-Host
    $uri, $headers = Get-UriAndHeadersForAlpaca -authContext $authContext -serviceUrl "Task/$containerId/execute"
    $result = Invoke-RestMethod -Method PATCH -Uri $uri -Headers $headers -Body ($sb.ToString().Trim() | ConvertTo-Json -Compress)
    $resultStr = $result.ToString()
    $idx = $resultStr.IndexOf('<Objs ')
    if ($idx -ge 0) {
        # Output to host
        if (!$silent) { Write-Host $resultStr.Substring(0,$idx) }
        # Get return value
        $output = [System.Management.Automation.PSSerializer]::Deserialize($resultStr.SubString($idx))
    }
    elseif ($result -is [System.Xml.XmlDocument]) {
        # No output to host - get return value
        $output = [System.Management.Automation.PSSerializer]::Deserialize($result.OuterXml)
    }
    else {
        $output = ''
    }
    $exception = $output | Where-Object { $_ -like "::EXCEPTION::*" }
    if ($exception) {
        $errorMessage = $exception.SubString(13)
        if (!$silent) {
            Write-Host -ForegroundColor Red "Exception thrown inside Alpaca container: $errorMessage"
            Write-Host
        }
        throw $errorMessage
    }
    $output
}
Export-ModuleMember -Function Invoke-ScriptInAlpacaBcContainer
