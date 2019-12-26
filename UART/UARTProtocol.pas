unit UARTProtocol;

interface

uses
  Windows, Messages, SysUtils, Classes,
  UART;

type
  {Событие при получении нового значения}
  TNewBlockRx = procedure(const Block :Pointer; const Size :Byte ) of object;

  ByteArray = array [0..255] of Byte;

  {Реализация простого протокола обмена}
  TUARTProtocol = class(TComponent)
    private
      FUART         : TUART;         {транспортный компонент}
      FStartByte    : Byte;           {байт начала посылки}
      FQuantity     : Byte;           {количество байт в блоке}
      FBlock        : ByteArray;      {буфер для блока}
      FEndByte      : Byte;           {байт конца посылки}
      FOnNewBlockRx : TNewBlockRx;    {событие}
      FByteIndex    : Integer;        {счетчик байт посылки}
      FUseCS        : Boolean;        {проверка контрольной суммы}
      procedure SetUART(const Value: TUART);
      {Перекрытие события компонента TUART}
      procedure OnRxComplete(const Buffer: Pointer;
                             const Size: Integer;
                             const ErrCode: Cardinal);
      {Вычисление полного размера посылки}
      function  GetBufferSize : Integer;
      {Вычисление контрольной суммы для SingleArray}
      function  GetBlockCS(Buf : Pointer) : Byte;
    public
      constructor Create(AOwner : TComponent); override;
      destructor  Destroy; override;
      procedure   Notification(AComponent: TComponent; Operation: TOperation); override;
    published
      {Привязка к компоненту TUART}
      property UART : TUART read FUART write SetUART;
      {Стартовый байт}
      property StartByte : Byte read FStartByte write FStartByte;
      {Размер блока}
      property Quantity : Byte read FQuantity write FQuantity;
      {Завершающий байт}
      property EndByte : Byte read FEndByte write FEndByte;
      {Проверка контрольной суммы}
      property UseCS : Boolean read FUseCS write FUseCS;
      {Событие при получении нового блока}
      property OnNewBlockRx : TNewBlockRx read FOnNewBlockRx write FOnNewBlockRx;
    public
      {Передача блока, согласно протоколу. }
      procedure TxBlock(const Buffer :Pointer; const Size :Byte);
    end;

procedure Register;

implementation

{Добавление ресурса с иконкой для палитры компонент}
{$R *.dcr}

constructor TUARTProtocol.Create(AOwner : TComponent);
begin
  inherited Create(AOwner);
  FByteIndex:= 0;
  FStartByte:= 133;    {байт начала посылки по умолчанию}
  FQuantity:= 3;       {размер пакета по умолчанию}
  FEndByte:= 33;       {байт конца посылки по умолчанию}
end;

destructor TUARTProtocol.Destroy;
begin
  inherited Destroy;
end;

{Вызывается при операциях в редакторе форм Delphi}
procedure TUARTProtocol.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited;
  {Если компонент TUART удалили с формы...}
  if (Operation = opRemove) and (FUART <> nil) then
    begin
      if AComponent = FUART then FUART:= nil;
    end;
end;

{******************************************************************************}
{Вычисление контрольной суммы для числа Single}
{function TCOM_TUARTProtocol.GetCSSingle(AValue : Single) : Byte;
var Buf : SingleArray;
begin
  Move(AValue, Buf, SizeOf(Buf));
  Result:= GetCSBuf(Buf);
end;}

{Вычисление контрольной суммы для посылки}
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

{Передача блока, согласно протоколу}
procedure TUARTProtocol.TxBlock(const Buffer :Pointer; const Size :Byte);
var CS : Byte;
begin
  if Assigned(FUART) then
    if FUART.Connected then
      begin
        {Послать символ начала посылки}
        FUART.TxBuffer(@FStartByte, SizeOf(FStartByte));
        {Послать символ начала посылки}
        FQuantity:= Size;
        FUART.TxBuffer(@FQuantity, SizeOf(FQuantity));
        {Послать число}
        FUART.TxBuffer(Buffer, FQuantity);
        {Послать символ завершения посылки}
        FUART.TxBuffer(@FEndByte, SizeOf(FEndByte));
        {контрольная сумма, если включено}
        if FUseCS then
          begin
            CS:= GetBlockCS(Buffer);
            FUART.TxBuffer(@CS, SizeOf(CS));
          end;
      end;
end;

{Привязка к компоненту TUART}
procedure TUARTProtocol.SetUART(const Value: TUART);
begin
  FUART:= nil;
  if Value <> nil then
    begin
      FUART:= Value;
      {Заставляем компонент TUART пересылать уведомления редактора}
      {форм этому компоненту}
      FUART.FreeNotification(Self);
      {Перехватываем обработчик получения новых посылок}
      FUART.OnRxComplete:= OnRxComplete;
    end;
end;

{Вычисление полного размера посылки}
function TUARTProtocol.GetBufferSize : Integer;
begin
  Result:= SizeOf(FStartByte) + SizeOf(FQuantity) + FQuantity + SizeOf(FEndByte);
  if FUseCS then Inc(Result); {+ контрольная сумма}
end;

{Перекрытие процедуры обработки получения новой посылки компонентом TUART}
procedure TUARTProtocol.OnRxComplete(const Buffer: Pointer;
        const Size: Integer; const ErrCode: Cardinal);
var B : Byte; i : Integer; bNextByte : Boolean;
begin
  for i:= 0 to Size - 1 do
    begin
      B:= Byte(Pointer(LongInt(Buffer)+i)^);
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
      if FByteIndex = GetBufferSize then
        begin
          try
            {Переписываем буфер в число Single}
            {Move(FBuffer, AValue, SizeOf(AValue));}

            {Вызываем обработчик}
            if Assigned(FOnNewBlockRx) then FOnNewBlockRx(@FBlock, FQuantity);
          finally
            {Независимо от ошибок начинаем отсчет снова}
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
