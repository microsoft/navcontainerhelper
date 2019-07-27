// Welcome to your new AL extension.
// Remember that object names and IDs should be unique across all extensions.
// AL snippets start with t*, like tpageext - give them a try and happy coding!

pageextension 50113 CustomerListExt extends "Customer List"
{
    trigger OnOpenPage();
    var
        HelloText: Codeunit GreetingsManagement;
    begin
        Message('%1, %2', HelloText.GetRandomGreeting(), Rec.Name);
    end;
}