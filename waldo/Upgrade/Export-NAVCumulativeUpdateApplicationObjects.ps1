function Export-NAVCumulativeUpdateApplicationObjects {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [Object] $CUObjectFile,
        [Parameter(Mandatory=$true)]
        [String] $ServerInstance,
        [Parameter(Mandatory=$true)]
        [String] $Workingfolder
                
    )

    #Replaced by Export-NAVApplicationObjects_SameAsObjectfile    
    Export-NAVApplicationObjects_BasedOnObjectfile `
        -ObjectFile $CUObjectFile `        -ServerInstance $ServerInstance `        -ResultFolder $Workingfolder

}