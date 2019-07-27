codeunit 50131 "Insert Tests"
{
    Subtype = Install;

    trigger OnInstallAppPerCompany()
    var
        TestSuite: Codeunit "Test Suite";
    begin
        TestSuite.Create('DEFAULT', '134006..134007', false);
    end;
}