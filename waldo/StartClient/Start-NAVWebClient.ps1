function Start-NAVWebClient
{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]$WebServerInstance,
        [ValidateSet('Web','Tablet','Phone')]
        [String]$WebClientType='Web'
        )
    
    $WebClientUri = (Get-NAVWebServerInstance -WebServerInstance $WebServerInstance).uri
    
    switch ($WebClientType)
    {        
        'Web'    {$WebClientUri += '/default.aspx'}
        'Tablet' {$WebClientUri += '/tablet.aspx'}
        'Phone'  {$WebClientUri += '/phone.aspx'}        
    }

    Start-Process -FilePath $WebClientUri
}

