unit ServerTxPacket;

interface

uses
  Windows, Classes, SysUtils, DateUtils;

type
  TServerTxPacketData =
    packed record
      Sync        : Byte;
      ProtocolVer : Byte;
      MsgLen      : Word;
      MsgLenCs    : Byte;
      TopicId     : Word;
      MsgData     : array[0..1024]of Byte;
    end;

  TServerTxPacket = class(TPersistent)
    private
      FTxPacket   : TServerTxPacketData;
      FTxSize     : Integer;
      function    GetCs(PArray : PByte; ASize : Cardinal) : Byte;
    public
      constructor Create();
      procedure   Clear();
      procedure   PutBytes(ATopicId : Word; ABytes : PByte; ASize : Word);
      function    GetLength() : Integer;
      function    GetTopicId() : Word;
      procedure   SetTopicId(AValue : Word);
      function    SetCs() : Boolean;
      function    Raw() : PByte;
      function    RawSize() : Cardinal;
    published
      property TxSize : Integer read FTxSize;
    end;

implementation

{ TTxPacket }

constructor TServerTxPacket.Create();
begin
  inherited Create();
  Clear();
end;

function TServerTxPacket.SetCs : Boolean;
begin
  Result:= True;
end;

function TServerTxPacket.GetCs(PArray : PByte; ASize : Cardinal) : Byte;
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

procedure TServerTxPacket.Clear;
var i : Integer;
begin
  for i:= 0 to 1024 do FTxPacket.MsgData[i] := 0;
  FTxSize:= 0;
  FTxPacket.Sync := $FF;
  FTxPacket.ProtocolVer := $FE;
  FTxPacket.MsgLen := 0;
  FTxPacket.MsgLenCs := GetCs(@FTxPacket.MsgLen, 2);
  FTxPacket.TopicId := 0;
  FTxPacket.MsgData[0] := GetCs(@FTxPacket.TopicId, 2);
end;

function TServerTxPacket.GetTopicId : Word;
begin
  Result:= FTxPacket.TopicId;
end;

function TServerTxPacket.GetLength : Integer;
begin
  Result:= FTxSize;
end;


procedure TServerTxPacket.PutBytes(ATopicId : Word; ABytes : PByte; ASize : Word);
begin
  if (ABytes = Nil) or (ASize > 1023) then Exit;

  FTxSize := ASize;

  FTxPacket.Sync := $FF;
  FTxPacket.ProtocolVer := $FE;
  FTxPacket.MsgLen := ASize;
  FTxPacket.MsgLenCs := GetCs(@FTxPacket.MsgLen, 2);
  FTxPacket.TopicId := ATopicId;
  CopyMemory(@FTxPacket.MsgData[0], ABytes, ASize);
  FTxPacket.MsgData[ASize] := GetCs(@FTxPacket.TopicId, ASize + 2);
end;

procedure TServerTxPacket.SetTopicId(AValue : Word);
begin
  FTxPacket.TopicId := AValue;
  FTxPacket.MsgData[FTxPacket.MsgLen] := GetCs(@FTxPacket.TopicId, FTxPacket.MsgLen + 2);
end;

function TServerTxPacket.Raw : PByte;
begin
  Result := @FTxPacket;
end;

function TServerTxPacket.RawSize : Cardinal;
begin
  Result:= FTxSize + 8;
end;

end.
