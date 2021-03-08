function Install-AzDevops {
    Param(
    )

    Try {
        az upgrade
    } catch {
        Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; rm .\AzureCLI.msi
    }
    $extensions = az extension list -o json | ConvertFrom-Json

    $devopsFound = $False
    foreach($extension in $extensions)
    {
        if($extension.name -eq 'azure-devops'){
            $devopsFound = $True
        }
    }
    
    if ($devopsFound -eq $False){
        az extension add -n azure-devops
    }
}
Export-ModuleMember -Function Install-AzDevops
