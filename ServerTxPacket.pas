unit ServerTxPacket;

interface

uses
  Windows, Classes, SysUtils, DateUtils, Debug,
  IdGlobal;

type
  TServerTxPacketData = array[0..1023]of Byte;
  TServerTxPacket = class(TPersistent)
    private
      FTxPacket   : TServerTxPacketData;
      FTxSize     : Integer;
    public
      constructor Create();
      procedure Clear();
      procedure PutBytes(ABytes : Pointer; ASize : Word);
      function GetLength() : Integer;
      function GetCommand() : Byte;
      procedure SetCommand(AValue : Byte);
      function SetCRC() : Boolean;
      function InBytes() : TIdBytes;
      procedure PutStringParam(AType : Byte; AValue : String);
      procedure SetID(AValue : Cardinal);
      //procedure SetSuccessfullPacketID(AValue : Cardinal);
      //procedure SetPacketIDFromCurrentTime();
      function GetID() : Cardinal;
      procedure SetData(AChannel : Integer; AValue : Word);
      procedure SetCalibrationData(AChannel : Integer; AValue : Word);
      procedure SetCalibrationValue(AChannel : Integer; AValue : Single);
      procedure SetCalibrationStatus(AChannel : Integer; AValue : Byte);
      procedure SetTotalPulses(AChannel : Integer; AValue : Cardinal);
      procedure Pong(AValue : Cardinal);
//      procedure SetCalibrationStatusInProgress(AChannel : Integer);
//      procedure SetCalibrationStatusDone(AChannel : Integer);
//      procedure SetCalibrationStatusSaved(AChannel : Integer);
//      procedure SetCalibrationStatusError(AChannel : Integer);
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

function TServerTxPacket.SetCRC : Boolean;
//var
//  Len, i : Integer;
//  CRC    : Word;
//  P      : ^Byte;
begin
//  Result:= False;
//
//  if(FTxSize = 0)then Exit;
//
//  Len:= GetLength - 2;
//
//  try
//    CRC:= $FFFF;
//    P:= @FTxPacket;
//    while(Len <> 0)do
//      begin
//        CRC:= CRC xor (P^ shl 8);
//        for i:= 0 to 7 do
//          if((CRC and $8000) <> 0)
//            then CRC:= (CRC shl 1) xor $1021
//            else CRC:= CRC shl 1;
//        Inc(P);
//        Len:= Len - 1;
//      end;
//    FTxPacket[FTxSize - 2]:= Lo(CRC);
//    FTxPacket[FTxSize - 1]:= Hi(CRC);
//    Result:= True;
//  except
//    Result:= False;
//  end;
  Result:= True;
end;


procedure TServerTxPacket.Clear;
var i : Integer;
begin
  for i:= 0 to 1023 do FTxPacket[i]:= 0;
  FTxSize:= 150;
  FTxPacket[0]:= $24;
  FTxPacket[149]:= $0D;
end;

procedure TServerTxPacket.Pong(AValue : Cardinal);
var i : Integer;
begin
  for i:= 0 to 10 do FTxPacket[i]:= 0;
  FTxSize:= 11;
  FTxPacket[0]:= $24;
  FTxPacket[5]:= $11;
  CopyMemory(@FTxPacket[1], @AValue, 4);
  FTxPacket[10]:= $0D;
end;

function TServerTxPacket.GetCommand : Byte;
begin
  Result:= FTxPacket[5 + (13 * 8) + (4 * 8)];
end;

function TServerTxPacket.GetLength : Integer;
begin
  //Result:= FTxPacket[1] + (FTxPacket[2] shl 8);
  Result:= 150;
end;


procedure TServerTxPacket.PutBytes(ABytes : Pointer; ASize : Word);
begin
  if(ABytes = Nil)or(ASize > (1024 - FTxSize))then Exit;

  //if FTxPacket[0] <> $24 then FTxSize:= 18;

  FTxSize:= FTxSize + ASize;

  FTxPacket[0]:= $24;
  FTxPacket[149]:= $0D;
  //FTxPacket[1]:= Lo(FTxSize);
  //FTxPacket[2]:= Hi(FTxSize);
  if ABytes <> Nil then CopyMemory(@FTxPacket[FTxSize - ASize - 2], ABytes, ASize);
end;


function TServerTxPacket.InBytes : TIdBytes;
begin
  Result:= RawToBytes(FTxPacket, FTxSize);
end;

procedure TServerTxPacket.PutStringParam(AType : Byte; AValue : String);
var ParLen : Integer;
begin
  ParLen:= Length(AValue);

  if(ParLen = 0)or(ParLen > (1024 - FTxSize))then Exit;

  if FTxPacket[0] <> $55 then FTxSize:= 18;

  FTxSize:= FTxSize + ParLen + 2;

  FTxPacket[0]:= $55;
  FTxPacket[1]:= Lo(FTxSize);
  FTxPacket[2]:= Hi(FTxSize);

  FTxPacket[FTxSize - ParLen - 4]:= AType;
  CopyMemory(@FTxPacket[FTxSize - ParLen - 3], @AValue[1], ParLen);
  FTxPacket[FTxSize - 3]:= $00;
end;

procedure TServerTxPacket.SetCommand(AValue : Byte);
begin
  //if FTxPacket[0] <> $55 then FTxSize:= 18;
  FTxPacket[0]:= $24;
  FTxPacket[149]:= $0D;
  //FTxPacket[1]:= Lo(FTxSize);
  //FTxPacket[2]:= Hi(FTxSize);
  FTxPacket[5 + (13 * 8) + (4 * 8)]:= AValue;
end;

function TServerTxPacket.GetID : Cardinal;
begin
  Result:= 0;
  CopyMemory(@Result, @FTxPacket[1], 4);
end;

procedure TServerTxPacket.SetID(AValue : Cardinal);
begin
  //if FTxPacket[0] <> $55 then FTxSize:= 18;
  FTxPacket[0]:= $24;
  FTxPacket[149]:= $0D;
  //FTxPacket[1]:= Lo(FTxSize);
  //FTxPacket[2]:= Hi(FTxSize);
  CopyMemory(@FTxPacket[1], @AValue, 4);
end;

//procedure TServerTxPacket.SetPacketIDFromCurrentTime();
//var
//  ID : Int64;
//  NT : TDateTime;
//  TZ : TTimeZoneInformation;
//begin
//  if FTxPacket[0] <> $55 then FTxSize:= 18;
//  FTxPacket[0]:= $55;
//  FTxPacket[1]:= Lo(FTxSize);
//  FTxPacket[2]:= Hi(FTxSize);
//
//  GetTimeZoneInformation(TZ);
//  NT:= Now;
//  ID:= ((DateTimeToUnix(NT) + TZ.Bias * 60) shl 16) + MilliSecondOf(NT);
//
//  //Lof('Time Zone = %d s', [TZ.Bias * 60]);
//  //Lof('My Time   = %d s', [DateTimeToUnix(NT)]);
//  //Lof('My Time   = %s',   [FormatDateTime('YYYY.MM.DD HH:NN:SS', NT)]);
//  //Lof('GMT Time  = %d s', [DateTimeToUnix(NT) + TZ.Bias * 60]);
//  //Lof('GMT Time  = %s',   [FormatDateTime('YYYY.MM.DD HH:NN:SS', UnixToDateTime(DateTimeToUnix(NT) + TZ.Bias * 60))]);
//
//  CopyMemory(@FTxPacket[3], @ID, 6);
//end;
//
//procedure TServerTxPacket.SetSuccessfullPacketID(AValue : Int64);
//begin
//  if FTxPacket[0] <> $55 then FTxSize:= 18;
//  FTxPacket[0]:= $55;
//  FTxPacket[1]:= Lo(FTxSize);
//  FTxPacket[2]:= Hi(FTxSize);
//  CopyMemory(@FTxPacket[9], @AValue, 6);
//end;

procedure TServerTxPacket.SetData(AChannel : Integer; AValue : Word);
begin
  if ((0 > AChannel) or (7 < AChannel)) then Exit;
  CopyMemory(@FTxPacket[5 + (AChannel * 13)], @AValue, 2);
end;

procedure TServerTxPacket.SetTotalPulses(AChannel : Integer; AValue : Cardinal);
begin
  if ((0 > AChannel) or (7 < AChannel)) then Exit;
  CopyMemory(@FTxPacket[5 + 2 + (AChannel * 13)], @AValue, 4);
end;

procedure TServerTxPacket.SetCalibrationData(AChannel : Integer; AValue : Word);
begin
  if ((0 > AChannel) or (7 < AChannel)) then Exit;
  CopyMemory(@FTxPacket[5 + 6 + (AChannel * 13)], @AValue, 2);
end;

procedure TServerTxPacket.SetCalibrationValue(AChannel : Integer; AValue : Single);
begin
  if ((0 > AChannel) or (7 < AChannel)) then Exit;
  CopyMemory(@FTxPacket[5 + 9 + (AChannel * 13)], @AValue, 4);
end;

procedure TServerTxPacket.SetCalibrationStatus(AChannel : Integer; AValue : Byte);
begin
  if ((0 > AChannel) or (7 < AChannel)) then Exit;
  FTxPacket[5 + 8 + (AChannel * 13)]:= AValue;
end;

//procedure TServerTxPacket.SetCalibrationStatusInProgress(AChannel : Integer);
//begin
//  if ((0 > AChannel) or (7 < AChannel)) then Exit;
//  FTxPacket[5 + 8 + (AChannel * 13)]:= CALIBRATION_STATUS_IN_PROGRESS;
//end;
//
//procedure TServerTxPacket.SetCalibrationStatusDone(AChannel : Integer);
//begin
//  if ((0 > AChannel) or (7 < AChannel)) then Exit;
//  FTxPacket[5 + 8 + (AChannel * 13)]:= CALIBRATION_STATUS_DONE;
//end;
//
//procedure TServerTxPacket.SetCalibrationStatusSaved(AChannel : Integer);
//begin
//  if ((0 > AChannel) or (7 < AChannel)) then Exit;
//  FTxPacket[5 + 8 + (AChannel * 13)]:= CALIBRATION_STATUS_SAVED;
//end;
//
//procedure TServerTxPacket.SetCalibrationStatusError(AChannel : Integer);
//begin
//  if ((0 > AChannel) or (7 < AChannel)) then Exit;
//  FTxPacket[5 + 8 + (AChannel * 13)]:= CALIBRATION_STATUS_ERROR;
//end;

end.
