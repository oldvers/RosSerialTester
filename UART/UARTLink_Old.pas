unit UARTLink;

interface

uses
  Windows, Messages, SysUtils, Classes,
  UART;

type
  {Событие при получении нового блока данных}
  TRxBlock = procedure(const Block : Pointer; const Size : Byte ) of object;

  ByteArray = array [0..255] of Byte;

  {Реализация протокола обмена}
  TUARTLink = class(TComponent)
    private
      FUART         : TUART;          {транспортный компонент}
      FStartByte    : Byte;           {байт начала посылки}
      FQuantity     : Byte;           {количество байт в блоке}
      FBlock        : ByteArray;      {буфер для блока}
      FEndByte      : Byte;           {байт конца посылки}
      FOnRxBlock    : TRxBlock;       {событие при приеме нового блока данных}
      FByteIndex    : Integer;        {счетчик байт посылки}
      FUseCS        : Boolean;        {признак проверки контрольной суммы}

      {Перекрытие события компонента TUART}
      procedure OnRxComplete(const Buffer: Pointer; const Size: Integer; const ErrCode: Cardinal);
      {Вычисление полного размера посылки}
      function GetPacketSize : Integer;
      {Вычисление контрольной суммы для блока данных}
      function GetBlockCS(Buf : Pointer) : Byte;
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
      {Стартовый байт}
      property StartByte : Byte read FStartByte write FStartByte;
      {Завершающий байт}
      property EndByte : Byte read FEndByte write FEndByte;
      {Проверка контрольной суммы}
      property UseCS : Boolean read FUseCS write FUseCS;
      {Событие при получении нового блока}
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
      {Передача блока данных, согласно протоколу}
      procedure TxBlock(const Block : Pointer; const Size : Byte);
    end;

procedure Register;

implementation

{Добавление ресурса с иконкой для палитры компонент}
{$R *.dcr}

constructor TUARTLink.Create(AOwner : TComponent);
begin
  inherited Create(AOwner);
  FUART:= TUART.Create(Self);
  FUART.OnRxComplete:= OnRxComplete;
  FByteIndex:= 0;
  FStartByte:= 133;    {байт начала посылки по умолчанию}
  FQuantity:= 3;       {размер блока данных по умолчанию}
  FEndByte:= 33;       {байт конца посылки по умолчанию}
end;

destructor TUARTLink.Destroy;
begin
  if Connected then FUART.Close;
  FUART.Free;
  inherited Destroy;
end;

{Вызывается при операциях в редакторе форм Delphi}
procedure TUARTLink.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  {Если компонент TUART удалили с формы...}
  {if (Operation = opRemove) and (FUART <> nil) then
    begin
      if AComponent = FUART then FUART:= nil;
    end;}
end;

{******************************************************************************}
{Вычисление полного размера посылки (пакета)}
function TUARTLink.GetPacketSize : Integer;
begin
  Result:= SizeOf(FStartByte) + SizeOf(FQuantity) + FQuantity + SizeOf(FEndByte);
  if FUseCS then Inc(Result); {+ контрольная сумма}
end;

{Вычисление контрольной суммы блока данных}
function TUARTLink.GetBlockCS(Buf : Pointer) : Byte;
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

function TUARTLink.GetPort : Integer;
begin
  Result:= FUART.UARTPort;
end;

procedure TUARTLink.SetPort(AValue : Integer);
begin
  if AValue <> 0 then FUART.UARTPort:= AValue else FUART.UARTPort:= 2;
end;

function TUARTLink.GetBufferSize : Cardinal;
begin
  Result:= FUART.BufferSize;
end;

procedure TUARTLink.SetBufferSize(AValue : Cardinal);
begin
  if AValue <> 0 then FUART.BufferSize:= AValue;
end;

function TUARTLink.GetBaudRate : TBaudRate;
begin
  Result:= FUART.UARTProp.BaudRate;
end;

procedure TUARTLink.SetBaudRate(AValue : TBaudRate);
begin
  FUART.UARTProp.BaudRate:= AValue;
end;

function TUARTLink.GetByteSize : TByteSize;
begin
  Result:= FUART.UARTProp.ByteSize;
end;

procedure TUARTLink.SetByteSize(AValue : TByteSize);
begin
  FUART.UARTProp.ByteSize:= AValue;
end;

function TUARTLink.GetParity : TParity;
begin
  Result:= FUART.UARTProp.Parity;
end;

procedure TUARTLink.SetParity(AValue : TParity);
begin
  FUART.UARTProp.Parity:= AValue;
end;

function TUARTLink.GetStopBits : TStopBits;
begin
  Result:= FUART.UARTProp.StopBits;
end;

procedure TUARTLink.SetStopBits(AValue : TStopBits);
begin
  FUART.UARTProp.StopBits:= AValue;
end;

function TUARTLink.GetConnected : Boolean;
begin
  Result:= FUART.Connected;
end;

{******************************************************************************}
{Передача блока данных, согласно протоколу}
procedure TUARTLink.TxBlock(const Block : Pointer; const Size : Byte);
var CS : Byte;
begin
  if Assigned(FUART) then
    if Connected then
      begin
        {Послать символ начала посылки}
        FUART.TxBuffer(@FStartByte, SizeOf(FStartByte));
        {Послать символ начала посылки}
        FQuantity:= Size;
        FUART.TxBuffer(@FQuantity, SizeOf(FQuantity));
        {Послать число}
        FUART.TxBuffer(Block, FQuantity);
        {Послать символ завершения посылки}
        FUART.TxBuffer(@FEndByte, SizeOf(FEndByte));
        {контрольная сумма, если включено}
        if FUseCS then
          begin
            CS:= GetBlockCS(Block);
            FUART.TxBuffer(@CS, SizeOf(CS));
          end;
      end;
end;

{Привязка к компоненту TUART}
{procedure TUARTLink.SetUART(const Value: TUART);
begin
  FUART:= nil;
  if Value <> nil then
    begin
      FUART:= Value;
      {Заставляем компонент TUART пересылать уведомления редактора}
      {форм этому компоненту}
{      FUART.FreeNotification(Self);
      {Перехватываем обработчик получения новых посылок}
{      FUART.OnRxComplete:= OnRxComplete;
    end;
end;

{Перекрытие процедуры обработки получения новой посылки компонентом TUART}
procedure TUARTLink.OnRxComplete(const Buffer : Pointer; const Size : Integer; const ErrCode : Cardinal);
var
  B         : Byte;
  i         : Integer;
  bNextByte : Boolean;
begin
  for i:= 0 to Size - 1 do
    begin
      B:= Byte(Pointer(LongInt(Buffer) + i)^);
      bNextByte:= False;

      {ожидается символ начала посылки}
      if FByteIndex = 0 then bNextByte:= (B = FStartByte);
      {получение посылки}
      if FByteIndex = 1 then
        begin
          FQuantity:= B;
          bNextByte:= True;
        end;
      {получение посылки}
      if(FByteIndex >= 2)and(FByteIndex <= FQuantity + 1)then
        begin
          FBlock[FByteIndex - 2]:= B;
          bNextByte:= True;
        end;
      {ожидается символ конца посылки}
      if FByteIndex = FQuantity + 2 then bNextByte:= (B = FEndByte);
      {ожидается контрольная сумма}
      if FByteIndex = FQuantity + 3 then bNextByte:= (B = GetBlockCS(@FBlock));

      if bNextByte then
        begin
          {переходим к ожиданию следующего байта посылки}
          Inc(FByteIndex);
        end
      else
        begin
          {неверный формат посылки начинаем ожидание сначала}
          FByteIndex:= 0;
        end;

      {посылка закончена}
      if FByteIndex = GetPacketSize then
        begin
          try
            {Переписываем буфер в число Single}
            {Move(FBuffer, AValue, SizeOf(AValue));}

            {Вызываем обработчик}
            if Assigned(FOnRxBlock) then FOnRxBlock(@FBlock, FQuantity);
          finally
            {Независимо от ошибок начинаем отсчет снова}
            FByteIndex:= 0;
          end;
        end;
    end;
end;

function TUARTLink.Open : Boolean;
begin
  Result:= False;
  FUART.Open;
  if Connected then
    begin
      FUART.RxActive:= True;
      Result:= True;
    end else FUART.Close;
end;

procedure TUARTLink.Close;
begin
  FUART.Close;
end;

procedure Register;
begin
  RegisterComponents('UART', [TUARTLink]);
end;

end.
