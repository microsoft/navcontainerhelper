##only the first time.
{ "hosts": ["tcp://0.0.0.0:2375", "npipe://"] }' | Set-Content "C:\ProgramData\docker\config\daemon.json"
restart-service docker

##only the first time
netsh advfirewall firewall add rule name="DockerPortainer" dir=in action=allow protocol=TCP localport=2375

##only the first time
new-item -Path "C:\Docker\Portainer" -ItemType Directory
$ipAddress = (get-netadapter | Select-Object -First 1 | get-netipaddress | ? addressfamily -eq 'IPv4').ipaddress
docker run -d -p 9000:9000 --name portainer -h portainer --restart=always -v C:\Docker\Portainer:C:\Data portainer/portainer --no-auth -H tcp://${ipAddress}:2375

##Remove existing portainer line
Set-Content -Path "$env:windir\System32\Drivers\etc\hosts" -Value (get-content -Path "$env:windir\System32\Drivers\etc\hosts" | Select-String -Pattern 'portainer' -NotMatch)

##add portainer ip:host mapping to host file
$ipadd = docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' portainer
Add-Content -Value "${ipadd} portainer" -Path "$env:windir\System32\Drivers\etc\hosts"
