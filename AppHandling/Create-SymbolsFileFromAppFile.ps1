<# 
 .Synopsis
  Create a Symbols only .app file from an .app file
 .Description
 .Parameter AppFile
  Path of the application file which should be converted to symbols
 .Parameter symbolsFile
  Path of the symbols file which should be created 
 .Example
  Create-SymbolsFileFromAppFile -appFile c:\temp\baseapp.app -symbolsFile c:\temp\baseapp.symbols.app
#>
function Create-SymbolsFileFromAppFile {
    Param(
        [Parameter(Mandatory=$true)]
        [string] $appFile,
        [Parameter(Mandatory=$true)]
        [string] $symbolsFile
    )
    Write-Host "-------------"
    Write-Host $appFile
    Write-Host $symbolsFile

    RunAlTool -arguments @('CreateSymbolPackage', """$appFile""", """$symbolsFile""")
    
}
Export-ModuleMember -Function Create-SymbolsFileFromAppFile
