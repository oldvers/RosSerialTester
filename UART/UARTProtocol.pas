unit UARTProtocol;

interface

uses
  Windows, Messages, SysUtils, Classes,
  UART;

type
  {������� ��� ��������� ������ ��������}
  TNewBlockRx = procedure(const Block :Pointer; const Size :Byte ) of object;

  ByteArray = array [0..255] of Byte;

  {���������� �������� ��������� ������}
  TUARTProtocol = class(TComponent)
    private
      FUART         : TUART;         {������������ ���������}
      FStartByte    : Byte;           {���� ������ �������}
      FQuantity     : Byte;           {���������� ���� � �����}
      FBlock        : ByteArray;      {����� ��� �����}
      FEndByte      : Byte;           {���� ����� �������}
      FOnNewBlockRx : TNewBlockRx;    {�������}
      FByteIndex    : Integer;        {������� ���� �������}
      FUseCS        : Boolean;        {�������� ����������� �����}
      procedure SetUART(const Value: TUART);
      {���������� ������� ���������� TUART}
      procedure OnRxComplete(const Buffer: Pointer;
                             const Size: Integer;
                             const ErrCode: Cardinal);
      {���������� ������� ������� �������}
      function  GetBufferSize : Integer;
      {���������� ����������� ����� ��� SingleArray}
      function  GetBlockCS(Buf : Pointer) : Byte;
    public
      constructor Create(AOwner : TComponent); override;
      destructor  Destroy; override;
      procedure   Notification(AComponent: TComponent; Operation: TOperation); override;
    published
      {�������� � ���������� TUART}
      property UART : TUART read FUART write SetUART;
      {��������� ����}
      property StartByte : Byte read FStartByte write FStartByte;
      {������ �����}
      property Quantity : Byte read FQuantity write FQuantity;
      {����������� ����}
      property EndByte : Byte read FEndByte write FEndByte;
      {�������� ����������� �����}
      property UseCS : Boolean read FUseCS write FUseCS;
      {������� ��� ��������� ������ �����}
      property OnNewBlockRx : TNewBlockRx read FOnNewBlockRx write FOnNewBlockRx;
    public
      {�������� �����, �������� ���������. }
      procedure TxBlock(const Buffer :Pointer; const Size :Byte);
    end;

procedure Register;

implementation

{���������� ������� � ������� ��� ������� ���������}
{$R *.dcr}

constructor TUARTProtocol.Create(AOwner : TComponent);
begin
  inherited Create(AOwner);
  FByteIndex:= 0;
  FStartByte:= 133;    {���� ������ ������� �� ���������}
  FQuantity:= 3;       {������ ������ �� ���������}
  FEndByte:= 33;       {���� ����� ������� �� ���������}
end;

destructor TUARTProtocol.Destroy;
begin
  inherited Destroy;
end;

{���������� ��� ��������� � ��������� ���� Delphi}
procedure TUARTProtocol.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited;
  {���� ��������� TUART ������� � �����...}
  if (Operation = opRemove) and (FUART <> nil) then
    begin
      if AComponent = FUART then FUART:= nil;
    end;
end;

{******************************************************************************}
{���������� ����������� ����� ��� ����� Single}
{function TCOM_TUARTProtocol.GetCSSingle(AValue : Single) : Byte;
var Buf : SingleArray;
begin
  Move(AValue, Buf, SizeOf(Buf));
  Result:= GetCSBuf(Buf);
end;}

{���������� ����������� ����� ��� �������}
function  TUARTProtocol.GetBlockCS(Buf : Pointer) : Byte;
var i : Integer;
begin
  Result:= 0;
  {$R-}
  for i:= 0 to FQuantity - 1 do
    begin
      Result:= Result xor Byte(Pointer(LongInt(Buf)+i)^);
    end;
  {$R+}
end;

{******************************************************************************}

{�������� �����, �������� ���������}
procedure TUARTProtocol.TxBlock(const Buffer :Pointer; const Size :Byte);
var CS : Byte;
begin
  if Assigned(FUART) then
    if FUART.Connected then
      begin
        {������� ������ ������ �������}
        FUART.TxBuffer(@FStartByte, SizeOf(FStartByte));
        {������� ������ ������ �������}
        FQuantity:= Size;
        FUART.TxBuffer(@FQuantity, SizeOf(FQuantity));
        {������� �����}
        FUART.TxBuffer(Buffer, FQuantity);
        {������� ������ ���������� �������}
        FUART.TxBuffer(@FEndByte, SizeOf(FEndByte));
        {����������� �����, ���� ��������}
        if FUseCS then
          begin
            CS:= GetBlockCS(Buffer);
            FUART.TxBuffer(@CS, SizeOf(CS));
          end;
      end;
end;

{�������� � ���������� TUART}
procedure TUARTProtocol.SetUART(const Value: TUART);
begin
  FUART:= nil;
  if Value <> nil then
    begin
      FUART:= Value;
      {���������� ��������� TUART ���������� ����������� ���������}
      {���� ����� ����������}
      FUART.FreeNotification(Self);
      {������������� ���������� ��������� ����� �������}
      FUART.OnRxComplete:= OnRxComplete;
    end;
end;

{���������� ������� ������� �������}
function TUARTProtocol.GetBufferSize : Integer;
begin
  Result:= SizeOf(FStartByte) + SizeOf(FQuantity) + FQuantity + SizeOf(FEndByte);
  if FUseCS then Inc(Result); {+ ����������� �����}
end;

{���������� ��������� ��������� ��������� ����� ������� ����������� TUART}
procedure TUARTProtocol.OnRxComplete(const Buffer: Pointer;
        const Size: Integer; const ErrCode: Cardinal);
var B : Byte; i : Integer; bNextByte : Boolean;
begin
  for i:= 0 to Size - 1 do
    begin
      B:= Byte(Pointer(LongInt(Buffer)+i)^);
      bNextByte:= False;

      {��������� ������ ������ �������}
      if FByteIndex = 0 then bNextByte:= (B = FStartByte);
      {��������� �������}
      if FByteIndex = 1 then
        begin
          FQuantity:= B;
          bNextByte:= True;
        end;
      {��������� �������}
      if(FByteIndex >= 2)and(FByteIndex <= FQuantity + 1)then
        begin
          FBlock[FByteIndex - 2]:= B;
          bNextByte:= True;
        end;
      {��������� ������ ����� �������}
      if FByteIndex = FQuantity + 2 then bNextByte:= (B = FEndByte);
      {��������� ����������� �����}
      if FByteIndex = FQuantity + 3 then bNextByte:= (B = GetBlockCS(@FBlock));

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
      if FByteIndex = GetBufferSize then
        begin
          try
            {������������ ����� � ����� Single}
            {Move(FBuffer, AValue, SizeOf(AValue));}

            {�������� ����������}
            if Assigned(FOnNewBlockRx) then FOnNewBlockRx(@FBlock, FQuantity);
          finally
            {���������� �� ������ �������� ������ �����}
            FByteIndex:= 0;
          end;
        end;
    end;
end;

procedure Register;
begin
  RegisterComponents('UART', [TUARTProtocol]);
end;

end.
