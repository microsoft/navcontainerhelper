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
        # The hosts file may be UTF-8 with a BOM (Docker Desktop writes it that way). Decoding it as ASCII
        # turns the BOM into "???" and corrupts the first line, so decode as UTF-8 and keep the BOM if present.
        $utf8 = New-Object System.Text.UTF8Encoding $false
        $hasBom = ($content.Length -ge 3 -and $content[0] -eq 0xEF -and $content[1] -eq 0xBB -and $content[2] -eq 0xBF)
        if ($hasBom) {
            $text = $utf8.GetString($content, 3, $content.Length - 3)
        }
        else {
            $text = $utf8.GetString($content)
        }
        [System.Collections.ArrayList]$hosts = $text.Replace("`r`n","`n").Split("`n")
    
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
        
            $content = $utf8.GetBytes($($hosts -join [Environment]::NewLine)+[Environment]::NewLine)
            if ($hasBom) {
                $content = [byte[]](@(0xEF, 0xBB, 0xBF) + $content)
            }
        
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
    if ($hostsFile -eq "c:\windows\system32\drivers\etc\hosts") {
        $loc = "container"
    }
    else {
        $loc = "host"
    }
    if ($theIpAddress) {
        Write-Host "Setting $theHostname to $theIpAddress in $loc hosts file"
    }
    else {
        Write-Host "Removing $theHostname from $loc hosts file"
    }
    $hosts = UpdateHostsFile -hostsFile $hostsFile -theHostname $theHostname -theIpAddress $theIpAddress
}
else {
    $myhostsFile = "c:\windows\system32\drivers\etc\hosts"
    new-item -Path $myhostsFile -ItemType File -ErrorAction Ignore | Out-Null
    $sethost = $true
    if ($hostsFile) {
        $hosts = UpdateHostsFile -hostsFile $hostsFile
        $hosts | Where-Object { ($_ -match "^\s*(?<IP>\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s+(?<HOSTNAME>\S+)") -and $Matches.hostname.ToLowerInvariant().EndsWith('.internal') } | ForEach-Object {        
            Write-Host "Setting $($Matches.hostname) to $($Matches.ip) in container hosts file (copy from host hosts file)"
            UpdateHostsFile -hostsFile $myhostsFile -theHostname $Matches.hostname -theIpAddress $Matches.ip | Out-Null
            if ($Matches.hostname -ieq "host.containerhelper.internal") {
                $sethost = $false
            }
        }
    }
    if ($sethost) {
        $hostIP = "$ENV:hostIP"
        if (-not $hostIP) {
            $hostIP = (ipconfig | where-object { $_ –match "Default Gateway" } | foreach-object{ $_.Split(":")[1] } | Where-Object { $_.Trim() -ne "" } ) | Select-Object -First 1
        }

        if ($hostIP -and ($hostIP -is [string])) {
            Write-Host "Setting host.containerhelper.internal to $($hostIP.Trim()) in container hosts file"
            UpdateHostsFile -hostsFile $myhostsFile -theHostname "host.containerhelper.internal" -theIpAddress $hostIP.Trim() | Out-Null
        }
    }
}
