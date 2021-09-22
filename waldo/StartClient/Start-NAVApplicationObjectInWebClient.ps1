function Start-NAVApplicationObjectInWebClient
{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]$WebServerInstance,
        [ValidateSet('Web','Tablet','Phone')]
        [String]$WebClientType='Web',
        [Parameter(Mandatory=$true)]
        [ValidateSet('Page','Report')]
        [String]$ObjectType,
        [Parameter(Mandatory=$true)]
        [int]$ObjectID
        )
    
    $WebClientUri = (Get-NAVWebServerInstance -WebServerInstance $WebServerInstance).uri -split ',' | select -First 1
    
    switch ($WebClientType)
    {        
        'Web'    {$WebClientUri += '/default.aspx'}
        'Tablet' {$WebClientUri += '/tablet.aspx'}
        'Phone'  {$WebClientUri += '/phone.aspx'}        
    }

    switch($ObjectType)
    {
        'Page'   {$WebClientUri += "?Page=$ObjectID"}
        'Report' {$WebClientUri += "?Report=$ObjectID"}
    }

    Write-Host -ForegroundColor Green -Object "Starting: $WebClientUri"
    Start-Process -FilePath $WebClientUri
}

