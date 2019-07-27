codeunit 50114 "HelloWorld Test Install"
{
    Subtype = Install;

    trigger OnInstallAppPerCompany()
    var
        CALTestSuite: Record "CAL Test Suite";
        CALTestLine: Record "CAL Test Line";
        CALTestMgmt: Codeunit "CAL Test Management";
    begin
        if CALTestSuite.Get('DEFAULT') then
            exit;

        with CALTestSuite do begin
            init;

            validate(Name, 'DEFAULT');
            validate(Description, 'DEFAULT');
            validate(Export, false);
            insert(true);
        end;

        with CALTestLine do begin
            init;
            validate("Test Suite", 'DEFAULT');
            validate("Line No.", 1);
            validate("Line Type", "Line Type"::Codeunit);
            validate("Test Codeunit", Codeunit::"HelloWorld Tests");
            validate(Run, true);

            insert(true);

            CALTestMgmt.SETPUBLISHMODE;
            SETRECFILTER;
            CODEUNIT.RUN(CODEUNIT::"CAL Test Runner", CALTestLine);
        end;
    end;
}