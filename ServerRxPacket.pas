unit ServerRxPacket;

interface

uses
  Windows, Classes, SysUtils;

type
  TServerRxPacketData =
    packed record
      TopicId : Word;
      MsgData : array[0..1023]of Byte;
    end;

  TServerRxPacket = class(TPersistent)
    private
      FRxPacket   : TServerRxPacketData;
      FRxNextByte : Boolean;
      FRxIndex    : Integer;
      FRxSize     : Integer;
    public
      constructor Create();
      procedure Clear();
      procedure SetComplete();
      function IsRxSizeMatch() : Boolean;
      procedure PutByte(AValue : Byte);
      function CheckEndOfPacket() : Boolean;
      function GetLength() : Integer;
      function GetTopicId() : Word;
      function GetCs(PArray : PByte; ASize : Cardinal) : Byte;
      function GetData() : PByte; overload;
      function GetDataSize() : Integer;
      function GetString(AIndex : Word) : String;
      //function GetID : Cardinal;

      function GetData(AIndex : Integer) : PByte; overload;
      function GetDataAsInteger(AIndex : Integer) : Integer;
      function GetDataAsByte(AIndex : Integer) : Byte;
      function GetDataAsString(AIndex, ALength : Integer) : String;
      function GetDataAsWord(AIndex : Integer) : Word;
    published
      property CanRxNextByte : Boolean read FRxNextByte;
      property RxIndex : Integer read FRxIndex;
      property RxSize : Integer read FRxSize;
    end;


implementation

{ TRxPacket }

constructor TServerRxPacket.Create();
begin
  inherited Create();
  Clear();
end;

function TServerRxPacket.GetCs(PArray : PByte; ASize : Cardinal) : Byte;
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

function TServerRxPacket.CheckEndOfPacket : Boolean;
begin
  Result:= False;

  if (IsRxSizeMatch()) then
    try
      Result:= True; //CheckCRC();

      if (Result) then
        begin

        end;

      SetComplete();
    except
      //
    end;
end;

procedure TServerRxPacket.Clear;
var i : Integer;
begin
  FRxPacket.TopicId := 0;
  for i:= 0 to 1023 do FRxPacket.MsgData[i]:= 0;
  FRxNextByte:= False;
  FRxIndex:= 0;
  FRxSize:= 0;
end;

function TServerRxPacket.GetTopicId : Word;
begin
  Result:= FRxPacket.TopicId;
end;

function TServerRxPacket.GetLength : Integer;
begin
  //Result:= FRxPacket[1] + (FRxPacket[2] shl 8);
  //if ($10 = GetCommand)
  Result:= FRxSize;
  //  else Result:= 0;
end;

function TServerRxPacket.IsRxSizeMatch: Boolean;
begin
  Result:= ((FRxIndex > 0) and (FRxIndex = (FRxSize + 8)));
end;

procedure TServerRxPacket.PutByte(AValue : Byte);
begin
  FRxNextByte:= True;

  if ((FRxIndex > 6) and (FRxIndex < (FRxSize + 7)))
    then FRxPacket.MsgData[FRxIndex - 7] := AValue

  else if (FRxIndex = 0)
    then FRxNextByte := (AValue = $FF)
  else if (FRxIndex = 1)
    then FRxNextByte := (AValue = $FE)

  else if (FRxIndex = 2)
    then FRxSize := AValue
  else if (FRxIndex = 3)
    then begin
      FRxSize := (AValue shl 8) + FRxSize;
      if ((FRxSize < 0) or (FRxSize > 1023)) then FRxNextByte:= False;
    end

  else if (FRxIndex = 4)
    then FRxNextByte := (AValue = GetCs(@FRxSize, 2))

  else if (FRxIndex = 5)
    then FRxPacket.TopicId := AValue
  else if (FRxIndex = 6)
    then FRxPacket.TopicId := (AValue shl 8) + FRxPacket.TopicId

  else if (FRxIndex = (FRxSize + 7))
    then FRxNextByte := (AValue = GetCs(@FRxPacket, FRxSize + 2));

  if (FRxNextByte) then
    begin
      //FRxPacket[FRxIndex]:= AValue;
      FRxIndex := FRxIndex + 1;
    end else begin
      FRxIndex := 0;
      FRxSize := 0;
    end;
end;

procedure TServerRxPacket.SetComplete;
begin
  FRxIndex := 0;
end;

function TServerRxPacket.GetData : PByte;
begin
  Result := @FRxPacket.MsgData[0];
end;

function TServerRxPacket.GetString(AIndex : Word) : String;
var i, s : Integer;
begin
  Result:= '';
  //if GetCommand <> $01 then Exit;

  //b:= 0;
  //e:= 0;

  {for i:= 10 to 1023 do if FRxPacket.MsgData[i] = AType then
    begin
      b:= i + 1;
      Break;
    end;}

  {for i:= b to 1023 do if FRxPacket.MsgData[i] = $00 then
    begin
      e:= i;
      Break;
    end;}

  //if(b <> 0)and(e <> 0)and(e > b)then
  //  begin

  s := Integer((@FRxPacket.MsgData[AIndex])^);
  if (s < 0) or (s > 100) then Exit;
  if (AIndex > (1023 - 4)) or ((AIndex + s + 4) > 1023) then Exit;

  SetLength(Result, s);
  CopyMemory(@Result[1], @FRxPacket.MsgData[AIndex + 4], s);
  //  end;
end;

{function TServerRxPacket.GetID : Cardinal;
begin
  Result:= 0;
  CopyMemory(@Result, @FRxPacket[1], 4);
end;}

function TServerRxPacket.GetDataSize : Integer;
begin
  Result:= GetLength;
end;

function TServerRxPacket.GetDataAsByte(AIndex : Integer): Byte;
begin
  Result:= FRxPacket.MsgData[AIndex];
end;

function TServerRxPacket.GetDataAsInteger(AIndex : Integer): Integer;
begin
  Result:= Integer((@FRxPacket.MsgData[AIndex])^);
end;

function TServerRxPacket.GetDataAsString(AIndex, ALength : Integer) : String;
var i : Integer;
begin
  SetLength(Result, ALength);
  for i:= 0 to ALength - 1 do Result[i + 1]:= Char(FRxPacket.MsgData[AIndex + i]);
end;

function TServerRxPacket.GetDataAsWord(AIndex : Integer): Word;
begin
  Result:= Word((@FRxPacket.MsgData[AIndex])^);
end;

function TServerRxPacket.GetData(AIndex : Integer) : PByte;
begin
  Result:= @FRxPacket.MsgData[AIndex];
end;

end.
