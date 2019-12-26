program RosSerialTester;

uses
  Forms,
  Main in 'Main.pas' {MainForm},
  ServerRxPacket in 'ServerRxPacket.pas',
  ServerTxPacket in 'ServerTxPacket.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
