function Invoke-ScriptInNavContainer {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName, 
        [Parameter(Mandatory=$true)]
        [ScriptBlock] $scriptblock,
        [Parameter(Mandatory=$false)]
        [Object[]] $argumentList
    )

    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $session = Get-NavContainerSession -containerName $containerName -silent
        Invoke-Command -Session $session -ScriptBlock $scriptblock -ArgumentList $argumentList
    } else {
        $file = 'c:\ProgramData\NavContainerHelper\'+[GUID]::NewGuid().Tostring()+'.ps1'
        $outputFile = "$file.output"
        try {
            if ($argumentList) {
                $encryptionKey = $null
                # Encrypt Secure Strings (if any)
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
                '$xml = [xml](''' + $xml.OuterXml + ''')' | Add-Content $file
                if ($encryptionKey) {
                    '$nsmgr = New-Object System.Xml.XmlNamespaceManager -ArgumentList $xml.NameTable' | Add-Content $file
                    '$nsmgr.AddNamespace("ns", "http://schemas.microsoft.com/powershell/2004/04")' | Add-Content $file
                    '$nodes = $xml.SelectNodes("//ns:SS", $nsmgr)' | Add-Content $file
                    'foreach($node in $nodes) { $node.InnerText = ConvertFrom-SecureString -SecureString ($node.InnerText | ConvertTo-SecureString -Key $encryptionKey) }' | Add-Content $file
                }
                '$argumentList = [System.Management.Automation.PSSerializer]::Deserialize($xml.OuterXml)' | Add-Content $file
            }

            '$result = Invoke-Command -ScriptBlock {'+$scriptblock.ToString()+'} -ArgumentList $argumentList' | Add-Content $file
            'if ($result) { [System.Management.Automation.PSSerializer]::Serialize($result) | Set-Content "'+$outputFile+'" }' | Add-Content $file
            docker exec $containerName powershell $file
            if (Test-Path -Path $outputFile -PathType Leaf) {
                [System.Management.Automation.PSSerializer]::Deserialize((Get-content $outputFile))
            }
        } finally {
            Remove-Item $file -Force -ErrorAction SilentlyContinue
            Remove-Item $outputFile -Force -ErrorAction SilentlyContinue
        }
    }
}

$credential = New-Object PSCredential -ArgumentList "freddy", (ConvertTo-SecureString -String "P@ssword1" -AsPlainText -Force)

$result = Invoke-ScriptInNavContainer -containerName dev -scriptblock {
    Param(
        [PSCredential]$cred
    )

    $cred.UserName
    ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($cred.Password)))

} -argumentList $credential

Write-Host ("UserName is "+$result[0])
Write-Host ("Password is "+$result[1])
