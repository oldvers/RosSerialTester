unit TopicInfo;

interface

uses  Windows, Classes, SysUtils, DateUtils;

type
  TTopicInfo = class(TPersistent)
    private
      FTopicId : Word;
      FTopicName : String;
      FMsgType : String;
      FMD5Sum : String;
      FBufSize : Word;

      function  GetTopicId : Word;
      function  GetTopicName : String;
      function  GetMsgType : String;
      function  GetMD5Sum : String;
      function  GetBufSize : Word;

      procedure SetTopicId(AValue : Word);
      procedure SetTopicName(AValue : String);
      procedure SetMsgType(AValue : String);
      procedure SetMD5Sum(AValue : String);
      procedure SetBufSize(AValue : Word);
    public
      constructor Create();
      function Serialize(ABuffer : PByte) : Cardinal;
      function Deserialize(ABuffer : PByte; ASize : Cardinal) : Boolean;
      function GetSize : Cardinal;
    published
      property Size : Cardinal read GetSize;
      property TopicId : Word read GetTopicId write SetTopicId;
      property TopicName : String read GetTopicName write SetTopicName;
      property MsgType : String read GetMsgType write SetMsgType;
      property MD5Sum : String read GetMD5Sum write SetMD5Sum;
      property BufSize : Word read GetBufSize write SetBufSize;
    end;

implementation

{ TTopicInfo }

constructor TTopicInfo.Create();
begin
  inherited Create();
  FTopicId := 0;
  FTopicName := '';
  FMsgType := '';
  FMD5Sum := '';
  FBufSize := 0;
end;

function TTopicInfo.GetSize : Cardinal;
begin
  Result := 
    2 +
    4 + Length(FTopicName) +
    4 + Length(FMsgType) +
    4 + Length(FMD5Sum) +
    2 +
    0;
end;

function TTopicInfo.Serialize(ABuffer : PByte) : Cardinal;
var
  Buf : PByte;
  Len : Cardinal;
begin
  Buf := ABuffer;

  Len := 2;
  CopyMemory(Buf, @FTopicId, Len);
  Inc(Buf, Len);

  Len := Length(FTopicName);
  CopyMemory(Buf, @Len, 4);
  Inc(Buf, 4);
  CopyMemory(Buf, @FTopicName[1], Len);
  Inc(Buf, Len);

  Len := Length(FMsgType);
  CopyMemory(Buf, @Len, 4);
  Inc(Buf, 4);
  CopyMemory(Buf, @FMsgType[1], Len);
  Inc(Buf, Len);

  Len := Length(FMD5Sum);
  CopyMemory(Buf, @Len, 4);
  Inc(Buf, 4);
  CopyMemory(Buf, @FMD5Sum[1], Len);
  Inc(Buf, Len);

  Len := 2;
  CopyMemory(Buf, @FBufSize, Len);
  Inc(Buf, Len);

end;

function TTopicInfo.Deserialize(ABuffer : PByte; ASize : Cardinal) : Boolean;
var
  Buf : PByte;
  Len : Cardinal;
begin
  Buf := ABuffer;

  Len := 2;
  CopyMemory(@FTopicId, Buf, Len);
  Inc(Buf, Len);

  CopyMemory(@Len, Buf, 4);
  SetLength(FTopicName, Len);
  Inc(Buf, 4);
  CopyMemory(@FTopicName[1], Buf, Len);
  Inc(Buf, Len);

  CopyMemory(@Len, Buf, 4);
  SetLength(FMsgType, Len);
  Inc(Buf, 4);
  CopyMemory(@FMsgType[1], Buf, Len);
  Inc(Buf, Len);

  CopyMemory(@Len, Buf, 4);
  SetLength(FMD5Sum, Len);
  Inc(Buf, 4);
  CopyMemory(@FMD5Sum[1], Buf, Len);
  Inc(Buf, Len);

  Len := 2;
  CopyMemory(@FBufSize, Buf, Len);
  Inc(Buf, Len);

end;

function TTopicInfo.GetTopicId : Word;
begin
  Result := FTopicId;
end;

procedure TTopicInfo.SetTopicId(AValue : Word);
begin
  FTopicId := AValue;
end;

function TTopicInfo.GetTopicName : String;
begin
  Result := FTopicName;
end;

procedure TTopicInfo.SetTopicName(AValue : String);
begin
  FTopicName := AValue;
end;

function TTopicInfo.GetMsgType : String;
begin
  Result := FMsgType;
end;

procedure TTopicInfo.SetMsgType(AValue : String);
begin
  FMsgType := AValue;
end;

function TTopicInfo.GetMD5Sum : String;
begin
  Result := FMD5Sum;
end;

procedure TTopicInfo.SetMD5Sum(AValue : String);
begin
  FMD5Sum := AValue;
end;

function TTopicInfo.GetBufSize : Word;
begin
  Result := FBufSize;
end;

procedure TTopicInfo.SetBufSize(AValue : Word);
begin
  FBufSize := AValue;
end;

end.
