unit EAST2Link;

interface

uses
  Windows, Messages, SysUtils, Classes,
  UART;

type
  {������� ��� ��������� ������ ����� ������}
  TRxBlock = procedure(const Block : Pointer; const Size : Word) of object;

  ByteArray = array [0..65535] of Byte;

  {���������� ��������� ������}
  TEAST2Link = class(TComponent)
    private
      FUART         : TUART;          {������������ ���������}
      FStartByte    : Byte;           {���� ������ �������}
      FQuantity     : Word;           {���������� ���� � �����}
      FBlock        : ByteArray;      {����� ��� �����}
      FEndByte      : Byte;           {���� ����� �������}
      FCS           : Word;
      FOnRxBlock    : TRxBlock;       {������� ��� ������ ������ ����� ������}
      FByteIndex    : Integer;        {������� ���� �������}
      FUseCS        : Boolean;        {������� �������� ����������� �����}

      {���������� ������� ���������� TUART}
      procedure OnRxComplete(const Buffer : Pointer; const Size : Integer; const ErrCode : Cardinal);
      {���������� ������� ������� �������}
      function GetPacketSize : Integer;
      {���������� ����������� ����� ��� ����� ������}
      function GetBlockCS(Buf : Pointer) : Word;
      function GetPort : Integer;
      procedure SetPort(AValue : Integer);
      function GetBufferSize : Cardinal;
      procedure SetBufferSize(AValue : Cardinal);
      function GetBaudRate : TBaudRate;
      procedure SetBaudRate(AValue : TBaudRate);
      function GetByteSize : TByteSize;
      procedure SetByteSize(AValue : TByteSize);
      function GetParity : TParity;
      procedure SetParity(AValue : TParity);
      function GetStopBits : TStopBits;
      procedure SetStopBits(AValue : TStopBits);
      function GetConnected : Boolean;
    public
      constructor Create(AOwner : TComponent); override;
      destructor  Destroy; override;
      procedure   Notification(AComponent: TComponent; Operation: TOperation); override;
    published
      {��������� ����}
      property StartByte : Byte read FStartByte write FStartByte;
      {����������� ����}
      property EndByte : Byte read FEndByte write FEndByte;
      {�������� ����������� �����}
      property UseCS : Boolean read FUseCS write FUseCS;
      {������� ��� ��������� ������ �����}
      property OnRxBlock : TRxBlock read FOnRxBlock write FOnRxBlock;
      property Port : Integer read GetPort write SetPort;
      property BufferSize : Cardinal read GetBufferSize write SetBufferSize;
      property BaudRate : TBaudRate read GetBaudRate write SetBaudRate;
      property ByteSize  : TByteSize read GetByteSize write SetByteSize;
      property Parity    : TParity   read GetParity write SetParity;
      property StopBits  : TStopBits read GetStopBits write SetStopBits;
      property Connected : Boolean read GetConnected;
    public
      function Open : Boolean;
      procedure Close;
      function EnumPorts(APorts : TStrings) : Boolean;
      function SetPortByName(AName : String) : Boolean;
      {�������� ����� ������, �������� ���������}
      procedure TxBlock(const Block : Pointer; const Size : Word);
    end;

procedure Register;

implementation

{���������� ������� � ������� ��� ������� ���������}
{$R *.dcr}

constructor TEAST2Link.Create(AOwner : TComponent);
begin
  inherited Create(AOwner);
  FUART:= TUART.Create(Self);
  FUART.OnRxComplete:= OnRxComplete;
  FByteIndex:= 0;
  FStartByte:= 133;    {���� ������ ������� �� ���������}
  FQuantity:= 3;       {������ ����� ������ �� ���������}
  FEndByte:= 33;       {���� ����� ������� �� ���������}
end;

destructor TEAST2Link.Destroy;
begin
  if Connected then FUART.Close;
  FUART.Free;
  inherited Destroy;
end;

{���������� ��� ��������� � ��������� ���� Delphi}
procedure TEAST2Link.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  {���� ��������� TUART ������� � �����...}
  {if (Operation = opRemove) and (FUART <> nil) then
    begin
      if AComponent = FUART then FUART:= nil;
    end;}
end;

{******************************************************************************}
{���������� ������� ������� ������� (������)}
function TEAST2Link.GetPacketSize : Integer;
begin
  Result:= SizeOf(FStartByte) + SizeOf(FQuantity) + FQuantity + SizeOf(FEndByte);
  if FUseCS then Result:= Result + 2; {+ ����������� �����}
end;

{���������� ����������� ����� ����� ������}
function TEAST2Link.GetBlockCS(Buf : Pointer) : Word;
var i : Integer;
begin
  Result:= 0;
  {$R-}
  for i:= 0 to FQuantity - 1 do
    begin
      Result:= Result xor Byte(Pointer(LongInt(Buf) + i)^);
    end;
  {$R+}
end;

function TEAST2Link.GetPort : Integer;
begin
  Result:= FUART.UARTPort;
end;

procedure TEAST2Link.SetPort(AValue : Integer);
begin
  if AValue <> 0 then FUART.UARTPort:= AValue else FUART.UARTPort:= 2;
end;

function TEAST2Link.GetBufferSize : Cardinal;
begin
  Result:= FUART.BufferSize;
end;

procedure TEAST2Link.SetBufferSize(AValue : Cardinal);
begin
  if AValue <> 0 then FUART.BufferSize:= AValue;
end;

function TEAST2Link.GetBaudRate : TBaudRate;
begin
  Result:= FUART.UARTProp.BaudRate;
end;

procedure TEAST2Link.SetBaudRate(AValue : TBaudRate);
begin
  FUART.UARTProp.BaudRate:= AValue;
end;

function TEAST2Link.GetByteSize : TByteSize;
begin
  Result:= FUART.UARTProp.ByteSize;
end;

procedure TEAST2Link.SetByteSize(AValue : TByteSize);
begin
  FUART.UARTProp.ByteSize:= AValue;
end;

function TEAST2Link.GetParity : TParity;
begin
  Result:= FUART.UARTProp.Parity;
end;

procedure TEAST2Link.SetParity(AValue : TParity);
begin
  FUART.UARTProp.Parity:= AValue;
end;

function TEAST2Link.GetStopBits : TStopBits;
begin
  Result:= FUART.UARTProp.StopBits;
end;

procedure TEAST2Link.SetStopBits(AValue : TStopBits);
begin
  FUART.UARTProp.StopBits:= AValue;
end;

function TEAST2Link.GetConnected : Boolean;
begin
  Result:= FUART.Connected;
end;

{******************************************************************************}
{�������� ����� ������, �������� ���������}
procedure TEAST2Link.TxBlock(const Block : Pointer; const Size : Word);
var CS : Word;
begin
  if Assigned(FUART) then
    if Connected then
      begin
        {������� ������ ������ �������}
        FUART.TxBuffer(@FStartByte, SizeOf(FStartByte));
        {������� ������ ������ �������}
        FQuantity:= Size;
        FUART.TxBuffer(@FQuantity, SizeOf(FQuantity));
        {������� �����}
        FUART.TxBuffer(Block, FQuantity);
        {������� ������ ���������� �������}
        FUART.TxBuffer(@FEndByte, SizeOf(FEndByte));
        {����������� �����, ���� ��������}
        if FUseCS then
          begin
            CS:= GetBlockCS(Block);
            FUART.TxBuffer(@CS, SizeOf(CS));
          end;
      end;
end;

{���������� ��������� ��������� ��������� ����� ������� ����������� TUART}
procedure TEAST2Link.OnRxComplete(const Buffer : Pointer; const Size : Integer; const ErrCode : Cardinal);
var
  B         : Byte;
  i         : Integer;
  bNextByte : Boolean;
begin
  for i:= 0 to Size - 1 do
    begin
      B:= Byte(Pointer(LongInt(Buffer) + i)^);
      bNextByte:= False;

      {��������� ������ ������ �������}
      if FByteIndex = 0 then bNextByte:= (B = FStartByte);

      {������ �������}
      if FByteIndex = 1 then
        begin
          FQuantity:= B;
          bNextByte:= True;
        end;

      if FByteIndex = 2 then
        begin
          FQuantity:= FQuantity + B*256;
          bNextByte:= True;
        end;

      {���� ������}
      if(FByteIndex >= 3)and(FByteIndex <= FQuantity + 2)then
        begin
          FBlock[FByteIndex - 3]:= B;
          bNextByte:= True;
        end;

      {��������� ������ ����� �������}
      if FByteIndex = FQuantity + 3 then bNextByte:= (B = FEndByte);

      {��������� ����������� �����}
      if FByteIndex = FQuantity + 4 then
        begin
          FCS:= B;
          bNextByte:= True;
        end;

      if FByteIndex = FQuantity + 5 then
        begin
          FCS:= FCS + B*256;
          bNextByte:= (FCS = GetBlockCS(@FBlock));
        end;

      if bNextByte then
        begin
          {��������� � �������� ���������� ����� �������}
          Inc(FByteIndex);
        end
      else
        begin
          {�������� ������ ������� �������� �������� �������}
          FByteIndex:= 0;
        end;

      {������� ���������}
      if FByteIndex = GetPacketSize then
        begin
          try
            {�������� ����������}
            if Assigned(FOnRxBlock) then FOnRxBlock(@FBlock, FQuantity);
          finally
            {���������� �� ������ �������� ������ �����}
            FByteIndex:= 0;
            FCS:= 0;
          end;
        end;
    end;
end;

function TEAST2Link.Open : Boolean;
begin
  Result:= False;
  FUART.Open;
  if Connected then
    begin
      FUART.RxActive:= True;
      Result:= True;
    end else FUART.Close;
end;

procedure TEAST2Link.Close;
begin
  FUART.Close;
end;

function TEAST2Link.EnumPorts(APorts : TStrings) : Boolean;
var
  KeyHdl      :HKEY;
  ErrCode     :Integer;
  Index       :Cardinal;
  ValueLen    :Cardinal;
  ValueType   :DWORD;
  DataLen     :DWORD;
  ValueName   :String;
  Data        :String;
begin
  Result:= False;
  {��������� ���� � �������}
  ErrCode:= RegOpenKeyEx(HKEY_LOCAL_MACHINE, 'HARDWARE\DEVICEMAP\SERIALCOMM', 0, KEY_READ, KeyHdl);
  if ErrCode <> ERROR_SUCCESS then Exit;

  {����������� ��� �������� �����}
  Index:= 0;
  repeat
    ValueLen:= 256;
    DataLen:= 256;
    SetLength(ValueName, ValueLen);
    SetLength(Data, DataLen);
    ErrCode:= RegEnumValue(KeyHdl, Index, PChar(ValueName), ValueLen, nil, @ValueType,
                           PByte(PChar(Data)), @DataLen);
    if (ErrCode = ERROR_SUCCESS)and(ValueType = REG_SZ) then
      begin
        SetLength(ValueName, ValueLen - 1);
        SetLength(Data, DataLen - 1);
        Inc(Index);

        APorts.Add(Data);
      end;
  until (ErrCode <> ERROR_SUCCESS);
  Result:= True;
  {��������� ���� � �������}
  RegCloseKey(KeyHdl);
end;

function TEAST2Link.SetPortByName(AName: String): Boolean;
begin
  Result:= False;
  if Pos('COM', AName) = 0 then Exit;

  try
    Port:= StrToInt(Copy(AName, Pos('COM', AName) + 3, 3));
    Result:= True;
  except
    Port:= 2;
  end;
end;

procedure Register;
begin
  RegisterComponents('UART', [TEAST2Link]);
end;



end.
