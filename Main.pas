unit Main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, UARTLink, ExtCtrls, ComCtrls,
  UART, ServerRxPacket;

type
  TMainForm = class(TForm)
    ConnectionGroup: TGroupBox;
    UpdatePortsList: TButton;
    PortsList: TComboBox;
    LED: TPanel;
    ConnectBtn: TButton;
    PourGroup: TGroupBox;
    StartBtn: TButton;
    LogMemo: TMemo;
    UART: TUART;
    ClearBtn: TButton;
    ValueLabel: TLabel;
    LedButton: TButton;
    procedure FormCreate(Sender: TObject);
    procedure UpdatePortsListClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure PortsListChange(Sender: TObject);
    procedure ConnectBtnClick(Sender: TObject);
    procedure StartBtnClick(Sender: TObject);
    procedure UARTRxComplete(const Buffer: Pointer; const Size: Integer;
      const ErrCode: Cardinal);
    procedure FormDestroy(Sender: TObject);
    procedure ClearBtnClick(Sender: TObject);
    procedure LedButtonClick(Sender: TObject);
  private
    RxPacket : TServerRxPacket;
    procedure Log(AStr : String; APar : array of const);
    procedure LogArray(PArray : PByte; ASize : Cardinal);
    function GetRosCs(PArray : PByte; ASize : Cardinal) : Byte;
  public
    { Public declarations }
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

type
  TRosSerialCheckSum = Byte;

  TRosSerialPacket =
    packed record
      Sync        : Byte;
      ProtocolVer : Byte;
      MsgLen      : Word;
      MsgLenCs    : TRosSerialCheckSum;
      TopicId     : Word;
      Msg         : array[0..1025]of Byte;
    end;

  //PPourRsp = ^TPourRsp;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  UART.EnumCOMPorts(PortsList.Items);

  RxPacket := TServerRxPacket.Create;
end;

procedure TMainForm.UpdatePortsListClick(Sender: TObject);
begin
  if PortsList.Enabled then
    begin
      PortsList.Clear;
      UART.EnumCOMPorts(PortsList.Items);
    end;
end;

procedure TMainForm.FormShow(Sender: TObject);
begin
  UpdatePortsList.SetFocus;
  MainForm.Left := 20;
  MainForm.Top := 20;
end;

procedure TMainForm.PortsListChange(Sender: TObject);
begin
  ConnectBtn.SetFocus;
end;

procedure TMainForm.ConnectBtnClick(Sender: TObject);
var
  Port : String;
  Num  : Integer;
begin
  if PortsList.ItemIndex = -1 then Exit;

  try
    if ConnectBtn.Caption = 'Connect' then
      begin
        Port := PortsList.Items[PortsList.ItemIndex];
        Port := Copy(Port, 4, 3);
        Num := StrToInt(Port);
        UART.UARTPort := Num;
        if UART.Connect then
          begin
            UART.RxActive := True;
            LED.Color := clLime;
            PortsList.Enabled := False;
            ConnectBtn.Caption := 'Disconnect';
            LogMemo.Clear;
          end else begin
            LED.Color := clRed;
            PortsList.Enabled := True;
          end;
      end else begin
        UART.Close;
        LED.Color := clRed;
        PortsList.Enabled := True;
        ConnectBtn.Caption := 'Connect';
      end;
  except
    MessageDlg('ERROR: Can not open selected port!', mtError, [mbOK], 0);
  end;
end;

procedure TMainForm.StartBtnClick(Sender: TObject);
var Packet : TRosSerialPacket;
begin
  if not UART.Connected then Exit;

  Packet.Sync := $FF;
  Packet.ProtocolVer := $FE;
  Packet.MsgLen := 0;
  Packet.MsgLenCs := GetRosCs(@Packet.MsgLen, 2);
  Packet.TopicId := 0;
  Packet.Msg[0] := GetRosCs(@Packet.TopicId, Packet.MsgLen + 2);

  LogArray(@Packet, Packet.MsgLen + 8);

  UART.TxBuffer(@Packet, Packet.MsgLen + 8);
end;

procedure TMainForm.Log(AStr : String; APar : array of const);
begin
  LogMemo.Lines.Add(Format(AStr, APar));
end;

procedure TMainForm.UARTRxComplete(const Buffer : Pointer;
  const Size : Integer; const ErrCode : Cardinal);
var
  i , o : Cardinal;
  p     : PByte;
  s     : String;
  rsp   : TRosSerialPacket;
begin
  Log('Rx -------- %d Bytes', [Size]);
  LogArray(Buffer, Size);

  p := Buffer;
  for i := 0 to (Size - 1) do
    begin
      RxPacket.PutByte(p^);
      if RxPacket.CheckEndOfPacket then
        begin
          Log('---- Rx Packet Detected', []);

          case RxPacket.GetTopicId of
            0, 1 :  // ID_PUBLISHER         = 0
                    // ID_SUBSCRIBER        = 1
                  begin
                    if 1 = RxPacket.GetTopicId
                      then Log('  - Topic ID           = %d - Subscriber', [RxPacket.GetTopicId])
                      else Log('  - Topic ID           = %d - Publisher', [RxPacket.GetTopicId]);
                    o := 0;
                    Log('  - Pub/Sub Topic ID   = %d', [RxPacket.GetDataAsWord(o)]);
                    o := o + 2;
                    s := RxPacket.GetString(o);
                    Log('  - Topic Name         = %s', [s]);
                    o := o + Length(s) + 4;
                    s := RxPacket.GetString(o);
                    Log('  - Message Type       = %s', [s]);
                    o := o + Length(s) + 4;
                    s := RxPacket.GetString(o);
                    Log('  - MD5 Sum            = %s', [s]);
                    o := o + Length(s) + 4;
                    Log('  - Buffer Size        = %d', [RxPacket.GetDataAsInteger(o)]);
                  end;
            2   : ;// ID_SERVICE_SERVER    = 2
            4   : ;// ID_SERVICE_CLIENT    = 4
            6   : ;// ID_PARAMETER_REQUEST = 6
            7   : ;// ID_LOG               = 7
            10  :  // ID_TIME              = 10
                  begin
                    Log('  - Topic ID           = %d - Time', [RxPacket.GetTopicId]);
                    Log('  - Seconds            = %d', [RxPacket.GetDataAsInteger(0)]);
                    Log('  - Nano Seconds       = %d', [RxPacket.GetDataAsInteger(4)]);

                    rsp.Sync := $FF;
                    rsp.ProtocolVer := $FE;
                    rsp.MsgLen := 8;
                    rsp.MsgLenCs := GetRosCs(@rsp.MsgLen, 2);
                    rsp.TopicId := 10;
                    rsp.Msg[0] := $00;
                    rsp.Msg[1] := $01;
                    rsp.Msg[2] := $02;
                    rsp.Msg[3] := $03;
                    rsp.Msg[4] := $03;
                    rsp.Msg[5] := $02;
                    rsp.Msg[6] := $01;
                    rsp.Msg[7] := $00;
                    rsp.Msg[8] := GetRosCs(@rsp.TopicId, rsp.MsgLen + 2);
                    UART.TxBuffer(@rsp, rsp.MsgLen + 8);
                  end;
            11  : ;// ID_TX_STOP           = 11
            125 :
                  begin
                    Log('  - Topic ID           = %d - User', [RxPacket.GetTopicId]);
                    //Log('  - Message            = %s', [RxPacket.GetString(0)]);
                    //LogArray(RxPacket.GetData, RxPacket.GetLength);
                    o := 0;
                    Log('  - Sequence           = %d', [RxPacket.GetDataAsInteger(o)]);
                    o := o + 4;
                    Log('  - Time Seconds       = %d', [RxPacket.GetDataAsInteger(o)]);
                    o := o + 4;
                    Log('  - Time Nano Seconds  = %d', [RxPacket.GetDataAsInteger(o)]);
                    o := o + 4;
                    s := RxPacket.GetString(o);
                    Log('  - Frame ID           = %s', [s]);
                    o := o + 4 + Length(s);
                    Log('  - Radiation Type     = %d', [RxPacket.GetDataAsByte(o)]);
                    o := o + 1;
                    Log('  - Field Of View      = %5.2f', [RxPacket.GetDataAsFloat(o)]);
                    o := o + 4;
                    Log('  - Min Range          = %5.2f', [RxPacket.GetDataAsFloat(o)]);
                    o := o + 4;
                    Log('  - Max Range          = %5.2f', [RxPacket.GetDataAsFloat(o)]);
                    o := o + 4;
                    Log('  - Range              = %5.2f', [RxPacket.GetDataAsFloat(o)]);

                    ValueLabel.Caption := Format('Distance = %5.2f cm', [RxPacket.GetDataAsFloat(o)]);
                  end;
            else
                 begin
                   Log('  - Topic ID            = %d - User', [RxPacket.GetTopicId]);
                 end;
          end;
        end;
      Inc(p);
    end;
end;

procedure TMainForm.LogArray(PArray : PByte; ASize : Cardinal);
var
  i : Cardinal;
  s : String;
begin
  s := '';
  for i := 0 to (ASize - 1) do
    begin
      s := s + Format('%0.2X ', [PArray^]);
      Inc(PArray);
    end;
  LogMemo.Lines.Add(s);
end;

function TMainForm.GetRosCs(PArray : PByte; ASize : Cardinal) : Byte;
var i : Cardinal;
begin
  Result := 0;
  for i := 0 to (ASize - 1) do
    begin
      Result := Result + PArray^;
      Inc(PArray);
    end;
  Result := (255 - (Result mod 256));
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  RxPacket.Free;
end;

procedure TMainForm.ClearBtnClick(Sender: TObject);
begin
  LogMemo.Clear;
end;

procedure TMainForm.LedButtonClick(Sender: TObject);
var req : TRosSerialPacket;
begin
  req.Sync := $FF;
  req.ProtocolVer := $FE;
  req.MsgLen := 0;
  req.MsgLenCs := GetRosCs(@req.MsgLen, 2);
  req.TopicId := 100;
  req.Msg[0] := GetRosCs(@req.TopicId, req.MsgLen + 2);
  UART.TxBuffer(@req, req.MsgLen + 8);
end;

end.
