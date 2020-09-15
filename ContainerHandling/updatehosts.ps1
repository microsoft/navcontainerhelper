Param(
    [string] $hostsFile = "",
    [string] $theHostname = "",
    [string] $theIpAddress = ""
)

function UpdateHostsFile {
    Param(
        [string] $hostsFile,
        [string] $theHostname,
        [string] $theIpAddress
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
    
        if ($theHostname) {
            $theHostname = $theHostname.ToLowerInvariant()
            $ln = 0
            while ($ln -lt $hosts.Count) {
                $line = $hosts[$ln]
                $idx = $line.IndexOf("#")
                if ($idx -eq 0) {
                    $ln++
                }
                else {
                    if ($idx -gt 0) {
                        $line = $line.Substring(0,$idx)
                    }
                    if (("$line ".Replace("`t"," ")) -like "* $theHostname *" -or $line -eq "") {
                        $hosts.RemoveAt($ln) | Out-Null
                    } else {
                        $existsLater = $false

                        # Check wether the same hostname exists later
                        $line = $line.Replace("`t"," ").Trim().ToLowerInvariant()
                        $idx = $line.LastIndexOf(' ')
                        if ($idx -ge 0) {
                            $thisHostName = $line.SubString($idx + 1)
                            $chkln = $ln+1
                            while ($chkln -lt $hosts.Count) {
                                $line = $hosts[$chkln]
                                $idx = $line.IndexOf("#")
                                if ($idx -ge 0) {
                                    $line = $line.Substring(0,$idx)
                                }
                                if (("$line ".Replace("`t"," ")).ToLowerInvariant().IndexOf(" $thisHostname ") -ge 0) {
                                    $existsLater = $true
                                }
                                $chkln++
                            }
                        }
                        if ($existsLater) {
                            $hosts.RemoveAt($ln) | Out-Null
                        }
                        else {
                            $ln++
                        }
                    }
                }
            }
            if ("$theIpAddress" -ne "") {
                $hosts.Add("$theIpAddress $theHostname") | Out-Null
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

if ($theHostname) {
    if ($theIpAddress) {
        Write-Host "Setting $theHostname to $theIpAddress in host hosts file"
    }
    else {
        Write-Host "Removing $theHostname from host hosts file"
    }
    $hosts = UpdateHostsFile -hostsFile $hostsFile -theHostname $theHostname -theIpAddress $theIpAddress
}
else {
    $myhostsFile = "c:\windows\system32\drivers\etc\hosts"
    new-item -Path $myhostsFile -ItemType File -ErrorAction Ignore | Out-Null
    $sethost = $true
    if ($hostsFile) {
        $hosts = UpdateHostsFile -hostsFile $hostsFile
        $hosts | Where-Object { $_.ToLowerInvariant().EndsWith('.internal') -and $_.Split(" ").Count -eq 2 } | % {
            $aHostname = $_.Split(" ")[1]
            $anIp = $_.Split(" ")[0]
            Write-Host "Setting $aHostname to $anIp in container hosts file (copy from host hosts file)"
            UpdateHostsFile -hostsFile $myhostsFile -theHostname $aHostname -theIpAddress $anIp | Out-Null
            if ($aHostname -eq "host.containerhelper.internal") {
                $sethost = $false
            }
        }
    }
    if ($sethost) {
        $gateway = (ipconfig | where-object { $_ –match "Default Gateway" } | foreach-object{ $_.Split(":")[1] } | Where-Object { $_.Trim() -ne "" } )
        if ($gateway -and ($gateway -is [string])) {
            Write-Host "Setting host.containerhelper.internal to $($gateway.Trim()) in container hosts file"
            UpdateHostsFile -hostsFile $myhostsFile -theHostname "host.containerhelper.internal" -theIpAddress $gateway.Trim() | Out-Null
        }
    }
}
