Describe 'updatehosts.ps1 preserves hosts file encoding' {

    BeforeAll {
        $script:updateHosts = Join-Path (Split-Path -Parent $PSScriptRoot) 'ContainerHandling\updatehosts.ps1'
        $script:utf8 = New-Object System.Text.UTF8Encoding $false
        $script:bom = [byte[]](0xEF, 0xBB, 0xBF)

        function script:New-HostsFile([byte[]]$Bytes) {
            $path = Join-Path $TestDrive ([Guid]::NewGuid().ToString())
            [System.IO.File]::WriteAllBytes($path, $Bytes)
            $path
        }

        function script:Get-HostsLines([string]$Path) {
            $bytes = [System.IO.File]::ReadAllBytes($Path)
            $start = 0
            if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $start = 3 }
            $script:utf8.GetString($bytes, $start, $bytes.Length - $start).TrimEnd() -split "`r`n"
        }
    }

    It 'keeps the UTF-8 BOM and does not turn it into question marks' {
        $path = New-HostsFile ([byte[]]($bom + $utf8.GetBytes("172.24.121.37 bc27`r`n# Added by Docker Desktop`r`n192.168.0.53 host.docker.internal`r`n")))

        . $updateHosts -hostsFile $path -theHostname 'bctest' -theIpAddress '10.1.2.3' | Out-Null

        $bytes = [System.IO.File]::ReadAllBytes($path)
        $bytes[0..2] | Should -Be $bom
        $bytes[3] | Should -Not -Be 0x3F
        Get-HostsLines $path | Should -Be @('172.24.121.37 bc27', '# Added by Docker Desktop', '192.168.0.53 host.docker.internal', '10.1.2.3 bctest')
    }

    It 'removes an entry from a hosts file with a BOM' {
        $path = New-HostsFile ([byte[]]($bom + $utf8.GetBytes("172.24.121.37 bc27`r`n192.168.0.53 host.docker.internal`r`n")))

        . $updateHosts -hostsFile $path -theHostname 'bc27' -theIpAddress '' | Out-Null

        [System.IO.File]::ReadAllBytes($path)[0..2] | Should -Be $bom
        Get-HostsLines $path | Should -Be @('192.168.0.53 host.docker.internal')
    }

    It 'does not add a BOM to a hosts file without one' {
        $path = New-HostsFile ($utf8.GetBytes("192.168.0.53 host.docker.internal`r`n"))

        . $updateHosts -hostsFile $path -theHostname 'bctest' -theIpAddress '10.1.2.3' | Out-Null

        $expected = $utf8.GetBytes("192.168.0.53 host.docker.internal`r`n10.1.2.3 bctest`r`n")
        [System.IO.File]::ReadAllBytes($path) | Should -Be $expected
    }

    It 'keeps non-ASCII characters in comments' {
        $comment = "# $([char]0x104)$([char]0x17E)uolas"
        $path = New-HostsFile ($utf8.GetBytes("$comment`r`n172.24.121.37 bc27`r`n"))

        . $updateHosts -hostsFile $path -theHostname 'bctest' -theIpAddress '10.1.2.3' | Out-Null

        Get-HostsLines $path | Should -Be @($comment, '172.24.121.37 bc27', '10.1.2.3 bctest')
    }
}
