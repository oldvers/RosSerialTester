unit Log;

interface

uses  Windows, Classes, SysUtils, DateUtils;

type
  TLog = class(TPersistent)
    private
      FLevel : Byte;
      FMsg : String;

      function  GetLevel : Byte;
      function  GetMsg : String;

      procedure SetLevel(AValue : Byte);
      procedure SetMsg(AValue : String);
    public
      constructor Create();
      function Serialize(ABuffer : PByte) : Cardinal;
      function Deserialize(ABuffer : PByte; ASize : Cardinal) : Boolean;
      function GetSize : Cardinal;
    published
      property Size : Cardinal read GetSize;
      property Level : Byte read GetLevel write SetLevel;
      property Msg : String read GetMsg write SetMsg;
    end;

implementation

{ TLog }

constructor TLog.Create();
begin
  inherited Create();
  FLevel := 0;
  FMsg := '';
end;

function TLog.GetSize : Cardinal;
begin
  Result := 
    1 +
    4 + Length(FMsg) +
    0;
end;

function TLog.Serialize(ABuffer : PByte) : Cardinal;
var
  Buf : PByte;
  Len : Cardinal;
begin
  Buf := ABuffer;

  Buf^ := FLevel;
  Inc(Buf);

  Len := Length(FMsg);
  CopyMemory(Buf, @Len, 4);
  Inc(Buf, 4);
  CopyMemory(Buf, @FMsg[1], Len);
  Inc(Buf, Len);

end;

function TLog.Deserialize(ABuffer : PByte; ASize : Cardinal) : Boolean;
var
  Buf : PByte;
  Len : Cardinal;
begin
  Buf := ABuffer;

  FLevel := Buf^;
  Inc(Buf);

  CopyMemory(@Len, Buf, 4);
  SetLength(FMsg, Len);
  Inc(Buf, 4);
  CopyMemory(@FMsg[1], Buf, Len);
  Inc(Buf, Len);

end;

function TLog.GetLevel : Byte;
begin
  Result := FLevel;
end;

procedure TLog.SetLevel(AValue : Byte);
begin
  FLevel := AValue;
end;

function TLog.GetMsg : String;
begin
  Result := FMsg;
end;

procedure TLog.SetMsg(AValue : String);
begin
  FMsg := AValue;
end;

end.
