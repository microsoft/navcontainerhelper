Param(
    [string] $hostsFile = "c:\driversetc\hosts",
    [string] $hostname = "onprem",
    [string] $ipAddress = "172.23.159.117"
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
    
        $hosts

    } finally {
        if ($file) {
            $file.Dispose()
        }
    }
}

$hosts = UpdateHostsFile -hostsFile $hostsFile -hostname $hostname -ipAddress $ipAddress

$myhostsFile = "c:\windows\system32\drivers\etc\hosts"
new-item -Path $myhostsFile -ItemType File -ErrorAction Ignore | Out-Null

$hosts | Where-Object { $_.ToLowerInvariant().EndsWith('.docker.internal') -and $_.Split(" ").Count -eq 2 } | % {
    UpdateHostsFile -hostsFile $myhostsFile -ipAddress $_.Split(" ")[0] -hostname $_.Split(" ")[1] | Out-Null
}
