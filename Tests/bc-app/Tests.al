codeunit 50113 "HelloWorld Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure WorkingTest();
    begin
        Assert.AreEqual(2, 2, '2 should be 2');
    end;
}