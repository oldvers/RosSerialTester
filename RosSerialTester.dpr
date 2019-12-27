program RosSerialTester;

uses
  Forms,
  Main in 'Main.pas' {MainForm},
  ServerRxPacket in 'ServerRxPacket.pas',
  ServerTxPacket in 'ServerTxPacket.pas',
  TopicInfo in 'Msgs\RosMsgs\TopicInfo.pas',
  Log in 'Msgs\RosMsgs\Log.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
