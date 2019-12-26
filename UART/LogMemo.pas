unit LogMemo;

interface

uses
  SysUtils, Classes, Controls, StdCtrls, Graphics;

type
  TLogMemo = class(TMemo)
    private
      { Private declarations }
    protected
      { Protected declarations }
    public
      procedure Print(AString : string; AParameters : array of const);
      constructor Create(AOwner : TComponent); override;
    published
      { Published declarations }
    end;

procedure Register;

implementation

{Добавление ресурса с иконкой для палитры компонент}
{$R *.dcr}

procedure Register;
begin
  RegisterComponents('UART', [TLogMemo]);
end;

{ TLogMemo }

constructor TLogMemo.Create(AOwner : TComponent);
begin
  inherited Create(AOwner);

  Color:= clBlack;
  ScrollBars:= ssVertical;
  Font.Color:= clLime;
  Font.Name:= 'Courier New';
end;

procedure TLogMemo.Print(AString : String; AParameters : array of const);
begin
  Lines.Add(Format(AString, AParameters));
end;

end.
