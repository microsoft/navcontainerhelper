Param(
    [string] $hostsFile = "c:\driversetc\hosts",
    [string] $hostname = "",
    [string] $ipAddress = ""
)

function UpdateHostsFile {
    Param(
        [string] $hostsFile,
        [string] $hostname,
        [string] $ipAddress
    )
    
    new-item -Path $hostsFile -ItemType File -ErrorAction Ignore | Out-Null
    
    $file = $null
    try {
        while (!($file)) {
            try {
                $file = [System.IO.File]::Open($hostsFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::Read)
            } catch [SYstem.IO.IOException]  {
                Start-Sleep -Seconds 1
            }
        }
    
        $content = New-Object System.Byte[] ($file.Length)
        $file.Read($content, 0, $file.Length) | Out-Null
        [System.Collections.ArrayList]$hosts = ([System.Text.Encoding]::ASCII.GetString($content)).Replace("`r`n","`n").Split("`n")
    
        if ($hostname) {
            $hostname = $hostname.ToLowerInvariant()
            $ln = 0
            while ($ln -lt $hosts.Count) {
                $line = $hosts[$ln]
                $idx = $line.IndexOf("#")
                if ($idx -ge 0) {
                    $line = $line.Substring(0,$idx)
                }
                $hidx = ("$line ".Replace("`t"," ")).ToLowerInvariant().IndexOf(" $hostName ")
                if ($hidx -ge 0 -or $line -eq "") {
                    $hosts.RemoveAt($ln) | Out-Null
                } else {
                    $ln++
                }
            }
            if ("$ipAddress" -ne "") {
                $hosts.Add("$ipAddress $hostName") | Out-Null
            }
        
            $content = [System.Text.Encoding]::ASCII.GetBytes($($hosts -join [Environment]::NewLine)+[Environment]::NewLine)
        
            $file.Seek(0, [System.IO.SeekOrigin]::Begin) | Out-Null
            $file.Write($content, 0, $content.Length)
            $file.SetLength($content.Length)
            $file.Flush()
        }
    
        $hosts

    } finally {
        if ($file) {
            $file.Dispose()
        }
    }
}

if ($hostname) {
    if ($ipAddress) {
        Write-Host "Setting $hostname to $ipAddress in host hosts file"
    }
    else {
        Write-Host "Removing $hostname from host hosts file"
    }
    $hosts = UpdateHostsFile -hostsFile $hostsFile -hostname $hostname -ipAddress $ipAddress
}
else {
    $myhostsFile = "c:\windows\system32\drivers\etc\hosts"
    new-item -Path $myhostsFile -ItemType File -ErrorAction Ignore | Out-Null
    $hosts = UpdateHostsFile -hostsFile $hostsFile
    $sethost = $true
    $hosts | Where-Object { $_.ToLowerInvariant().EndsWith('.internal') -and $_.Split(" ").Count -eq 2 } | % {
        $aHostname = $_.Split(" ")[1]
        $anIp = $_.Split(" ")[0]
        Write-Host "Setting $aHostname to $anIp in container hosts file (copy from host hosts file)"
        UpdateHostsFile -hostsFile $myhostsFile -ipAddress $anIp -hostname $aHostname | Out-Null
        if ($aHostname -eq "host.containerhelper.internal") {
            $sethost = $false
        }
    }
    if ($sethost) {
        $gateway = (ipconfig | where-object { $_ –match "Default Gateway" } | foreach-object{ $_.Split(":")[1] } | Where-Object { $_.Trim() -ne "" } )
        if ($gateway -and ($gateway -is [string])) {
            Write-Host "Setting host.containerhelper.internal to $($gateway.Trim()) in container hosts file"
            UpdateHostsFile -hostsFile $myhostsFile -ipAddress $gateway.Trim() -hostname "host.containerhelper.internal" | Out-Null
        }
    }
}
