codeunit 50133 "HelloWorld Test"
{
    Subtype = Test;

    // Test kindly donated by Gunnar Gestsson:-)

    [Test]
    [HandlerFunctions('HelloWorldMessageHandler')]
    procedure TestHelloWorldMessage()
    var
        CustList: TestPage "Customer List";
    begin
        CustList.OpenView();
        CustList.Close();
        Assert.IsTrue(MessageDisplayed, 'Message was not displayed!');
    end;

    [MessageHandler]
    procedure HelloWorldMessageHandler(Message: Text[1024])
    begin
        MessageDisplayed := Message = 'App Published: Hello World Base!';
    end;

    var
        Assert: Codeunit "Library Assert";
        MessageDisplayed: Boolean;
}