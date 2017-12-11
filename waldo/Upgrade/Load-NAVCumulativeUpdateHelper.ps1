<#
    .Synopsis
        Loads a .Net assembly to easily find Microsoft Dynamics NAV downloads in the Microsoft Download Center. 
    .DESCRIPTION
        Compiles C# in memory and gives you 2 static functions:
            static System.Collections.Generic.IEnumerable[MicrosoftDownload.NAVDownload] GetDownloadLocales(int productID) 
            static System.Collections.Generic.IEnumerable[MicrosoftDownload.NAVDownload] GetDownloadDetail(int productID, string language)  
        See examples for how to use them.
        The functions only work when you have a ProductID for Microsoft Dynamics NAV Download Center.  The function "Get-NAVCumulativeUpdateFile" shows you how to get to the ProductID for Cumulative Updates.        
    .EXAMPLE
        Load-NAVCumulativeUpdateHelper
        $Locales = [MicrosoftDownload.MicrosoftDownloadParser]::GetDownloadLocales(54317)
        $MyDownload = $Locales | out-gridview -PassThru | foreach {
            $_.DownloadUrl
            Start-BitsTransfer -Source $_.DownloadUrl -Destination C:\_Download\Filename.zip
        }
    .EXAMPLE
        Load-NAVCumulativeUpdateHelper
        $MyDownload = [MicrosoftDownload.MicrosoftDownloadParser]::GetDownloadDetail(54317, 'en-US') | Select-Object *
    .OUTPUT
        THe function gives you the ability to run two static functions: "GetDownloadLocales" and "GetDownloadDetail"
#>
function Load-NAVCumulativeUpdateHelper()
{

	$cp = New-Object CodeDom.Compiler.CompilerParameters             
	$cp.CompilerOptions = "/unsafe"
	$cp.WarningLevel = 4
	$cp.TreatWarningsAsErrors = $true
    $cp.ReferencedAssemblies.Add('System.dll') | Out-Null
    $cp.ReferencedAssemblies.Add('System.Xml.dll') | Out-Null
    $cp.ReferencedAssemblies.Add('System.Xml.Linq.dll') | Out-Null
    $cp.ReferencedAssemblies.Add('System.Data.dll') | Out-Null
    $cp.ReferencedAssemblies.Add('System.Linq.dll') | Out-Null
    $cp.ReferencedAssemblies.Add('System.Net.dll') | Out-Null
    $cp.ReferencedAssemblies.Add('System.Net.Http.dll') | Out-Null
    $cp.ReferencedAssemblies.Add('System.Data.DataSetExtensions.dll') | Out-Null
    $cp.ReferencedAssemblies.Add('System.Collections.dll') | Out-Null
    $cp.ReferencedAssemblies.Add('System.Core.dll') | Out-Null
    
	Add-Type `        -CompilerParameters $cp `        -TypeDefinition @"

namespace MicrosoftDownload
{
    using System;
    using System.Collections.Generic;
    using System.Linq;
    using System.Net;
    using System.Xml.Linq;

    public static class MicrosoftDownloadParser
    {
        private const String urlTemplate = "https://www.microsoft.com/{0}/download/confirmation.aspx?id={1}";
        private const String cdataStartTag = "<![CDATA[*/var " + "baseProductId";
        private const String cdataEndTag = "/*]]>*/";
        private const String downloadStartTag = "downloadData={";
        private const String downloadEndTag = "}}";
        private const String urlTag = "url:";

        public static IEnumerable<NAVDownload> GetDownloadLocales(Int32 productID)
        {
            //Console.WriteLine(productID);

            var XMLDoc = XDocument.Load("https://www.microsoft.com/en-us/download/details.aspx?id=" + productID);
            IEnumerable<XElement> users = (from el in XMLDoc.Descendants()
                                           where (string)el.Attribute("name") == "newlocale"
                                           select el);
            if ((users == null) || (users.Count() == 0))
            {                
                foreach (var detail in GetDownloadDetail(productID, "en-US"))
                    yield return detail;
            }
            else
            {
                foreach (var item in users.FirstOrDefault().Descendants())
                    foreach (var detail in GetDownloadDetail(productID, item.Attribute("value").Value))
                        yield return detail;
            }
            
            
        }

        public static IEnumerable<NAVDownload> GetDownloadDetail(Int32 productID, String language)
        {
            //Console.WriteLine(productID + " - " + language);

            using (WebClient client = new WebClient())
            {                
                var pageData = client.DownloadString(String.Format(urlTemplate, language, productID));
                var CData = FetchSubString(pageData, cdataStartTag, cdataEndTag);
                var downloadData = FetchSubString(CData, downloadStartTag, downloadEndTag);

                //**** Find Urls ***                                
                var xPos = downloadData.IndexOf(urlTag) + urlTag.Length + 1;
                while (xPos > -1)
                {
                    var endPos = downloadData.IndexOf(@"""", xPos + 1);
                    var url = downloadData.Substring(xPos, endPos - xPos);

                    var fileName = System.IO.Path.GetFileName(url).ToUpper();

                    var langCode = "";
                    xPos = downloadData.IndexOf(urlTag, endPos);
                    if (xPos >= 0)
                        xPos += urlTag.Length + 1;

                    if (fileName.StartsWith("CU"))
                    {
                        langCode = url.Substring(url.Length - 6, 2);
                    }
                    else
                    {                        
                        langCode = url.Substring(url.Length - 10, 2);
                    }
                    
                    yield return new NAVDownload(productID, language, langCode, url);
                }
            }
        }


        private static String FetchSubString(String source, String startTag, String endTag)
        {
            var startPos = source.IndexOf(startTag) + startTag.Length;
            return source.Substring(startPos, source.IndexOf(endTag, startPos) - startPos);
        }        
    }

    public class NAVDownload
    {
        public Int32 ProductID { get; private set; }

        public String Locale { get; private set; }

        public String Code { get; private set; }

        public String DownloadUrl { get; private set; }

        public NAVDownload(Int32 productID, String locale, String code, String downloadUrl)
        {
            ProductID = productID;
            Locale = locale;
            Code = code;
            DownloadUrl = downloadUrl;
        }
    }
}
		

"@
}
