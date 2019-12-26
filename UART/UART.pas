{$A+,B-,C+,D+,E-,F-,G+,H+,I+,J-,K-,L+,M-,N+,O+,P+,Q-,R-,S-,T-,U-,V+,W-,X+,Y+,Z1}
{$MINSTACKSIZE $00004000}
{$MAXSTACKSIZE $00100000}
{$IMAGEBASE $00400000}
{$APPTYPE GUI}
unit UART;

interface

uses
  Windows, Messages, SysUtils, Classes;

type
  TBaudRate = ( BR____110, BR____300, BR____600, BR___1200,
                BR___2400, BR___4800, BR___9600, BR__14400,
                BR__19200, BR__38400, BR__56000, BR__57600,
                BR_115200, BR_230400, BR_460800, BR_921600 );

  TByteSize = ( BS5, BS6, BS7, BS8 );

  TParity = ( P_None, P_Odd, P_Even, P_Mark, P_Space );

  TStopBits = ( SB_10, SB_15, SB_20 );

  {тип события при получении байта}
  TRxComplete = procedure (const Buffer :Pointer;
                           const Size :Integer;
                           const ErrCode :Cardinal) of object;

  {опережающее описание}
  TUART = class;

  {читающий поток}
  TRxThread = class(TThread)
    FOwner     : TUART;  {читающий компонент}
    FBuffer    : Pointer; {входной буфер}
    FErrorCode : Cardinal;{сохраняет код ошибок}
    FNOfBytes  : Integer; {реально прочитанное число байт}
  protected
    procedure Execute; override;
    procedure DoRx;
  public
    constructor Create(AOwner : TUART);
    destructor  Destroy; override;
  end;

  {свойства порта}
  TUARTProp = class(TPersistent)
    private
      FBaudRate    : TBaudRate; {скорость обмена (бод)}
      FByteSize    : TByteSize; {число бит в байте}
      FParity      : TParity;   {четность}
      FStopBits    : TStopBits; {число стоп-бит}
      function  GetDCB: TDCB;
      procedure SetDCB(const Value: TDCB);
    public
      property DCB : TDCB read GetDCB write SetDCB;
    published
      {Скорость обмена}
      property BaudRate  : TBaudRate read FBaudRate write FBaudRate;
      {Число бит в байте}
      property ByteSize  : TByteSize read FByteSize write FByteSize;
      {Четность}
      property Parity    : TParity   read FParity   write FParity;
      {Число стоп-бит}
      property StopBits  : TStopBits read FStopbits write FStopbits;
    end;

  {компонент порта}
  TUART = class(TComponent)
    protected
      FUARTPort       : Integer;     {номер порта}
      FHandle         : THandle;     {дескриптор порта}
      FOnRxComplete   : TRxComplete; {событие "получение пакета"}
      FRxThread       : TRxThread;   {читающий поток}
      FBufferSize     : Cardinal;    {размер входной очереди }
      FWaitFullBuffer : Boolean;     {ожидание наполнения буфера}
      FUARTProp       : TUARTProp;   {свойства порта}
      procedure DoOpenUART;          {открытие порта}
      procedure DoCloseUART;         {закрытие порта}
      procedure ApplyUARTSettings;
    private
      function  GetConnected: Boolean;
      procedure SetConnected(const Value: Boolean);
      procedure SetUARTPort(const Value: Integer);
      procedure SetRxActive(const Value: Boolean);
      function  GetRxActive: Boolean;
      procedure SetBufferSize(const Value: Cardinal);
    public
      constructor Create(AOwner : TComponent); override;
      destructor  Destroy; override;
      {Открывает/закрывает порт}
      procedure Open;
      procedure Close;
      {Возвращает True, если порт открыт}
      function  Connect : Boolean;
      {Возвращает структуру состояния порта ComStat, а в    }
      {переменной CodeError возвращается текущий код ошибки }
      function  GetState(var CodeError : Cardinal) : TCOMStat;
      {Передает буфер. В случае успеха возвращает True}
      function  TxBuffer(const P : PChar; const Size : Integer) : Boolean;
      {Передает строку. В случае успеха возвращает True}
      function  TxString(const S : String) : Boolean;
      {Возвращает строковое имя порта}
      function  GetUARTName(FullName : Boolean) : String;
      {Диалог настройки параметров порта}
      function  UARTPropDialog : Boolean;
      {Активность чтения порта}
      property RxActive : Boolean read GetRxActive write SetRxActive;
      {Возвращает True, если порт открыт}
      property Connected : Boolean read GetConnected write SetConnected;
    published
      {Номер порта. При изменении порт переоткрывается, если был открыт}
      property UARTPort : Integer read FUARTPort write SetUARTPort;
      {Параметры порта}
      property UARTProp : TUARTProp read FUARTProp write FUARTProp;
      {Размер входного буфера}
      property BufferSize : Cardinal read FBufferSize write SetBufferSize;
      {Ожидание наполнения буфера}
      property WaitFullBuffer : Boolean read FWaitFullBuffer write FWaitFullBuffer;
      {Событие, вызываемое при получении байта}
      property OnRxComplete : TRxComplete read FOnRxComplete
                                          write FOnRxComplete;
    public {Дополнительные функции}
      {Получение базового адреса}
      function GetBaseAddress : Word;
      {Управление линией DTR}
      procedure Toggle_DTR(State : Boolean);
      {Управление линией RTS}
      procedure Toggle_RTS(State : Boolean);
      {Перечисление всех COM портов}
      class procedure EnumUARTPorts(Ports: TStrings);
      class procedure EnumUARTPortsEx(Ports: TStrings);
      class function EnumCOMPorts(APorts : TStrings) : Boolean;
    end;

procedure Register;

implementation

uses
  Dialogs, WinSpool, Math;

{Добавление ресурса с иконкой для палитры компонент}
{$R *.dcr}

const
  CBR_230400 = 230400;
  CBR_460800 = 460800;
  CBR_921600 = 921600;
  WindowsBaudRates: array[BR____110..BR_921600] of DWORD =
    ( CBR_110, CBR_300, CBR_600, CBR_1200, CBR_2400, CBR_4800, CBR_9600,
      CBR_14400, CBR_19200, CBR_38400, CBR_56000, CBR_57600, CBR_115200,
      CBR_230400, CBR_460800, CBR_921600 );

const
  dcb_Binary              = $00000001;
  dcb_ParityCheck         = $00000002;
  dcb_OutxCtsFlow         = $00000004;
  dcb_OutxDsrFlow         = $00000008;
  dcb_DtrControlMask      = $00000030;
  dcb_DtrControlDisable   = $00000000;
  dcb_DtrControlEnable    = $00000010;
  dcb_DtrControlHandshake = $00000020;
  dcb_DsrSensivity        = $00000040;
  dcb_TXContinueOnXoff    = $00000080;
  dcb_OutX                = $00000100;
  dcb_InX                 = $00000200;
  dcb_ErrorChar           = $00000400;
  dcb_NullStrip           = $00000800;
  dcb_RtsControlMask      = $00003000;
  dcb_RtsControlDisable   = $00000000;
  dcb_RtsControlEnable    = $00001000;
  dcb_RtsControlHandshake = $00002000;
  dcb_RtsControlToggle    = $00003000;
  dcb_AbortOnError        = $00004000;
  dcb_Reserveds           = $FFFF8000;

{******************************************************************************}

{Класс TRxThread }
constructor TRxThread.Create(AOwner : TUART);
begin
  inherited Create(True);
  FOwner:= AOwner;
  {Создаем новый буфер}
  GetMem(FBuffer, FOwner.FBufferSize);
end;

destructor TRxThread.Destroy;
begin
  {Освобождаем буфер}
  FreeMem(FBuffer);
  inherited Destroy;
end;

{Основная функция потока}
procedure TRxThread.Execute;
var
  CurrentState : TCOMStat;
  AvaibleBytes, ErrCode, RealRx : Cardinal;
  RxOL : TOverLapped; {структура для асинхронного чтения}
  Signaled, Mask : DWORD;
  BytesTrans : DWORD; {не используется для WaitCommEvent}
  bReadable : Boolean; {готовность к чтению данных}
begin
  with FOwner do
    begin
      try
        {создание события для асинхронного чтения}
        FillChar(RxOL, SizeOf(RxOL), 0);
        RxOL.hEvent:= CreateEvent(nil, True, True, nil);

        {Маска событий, которые будет отслеживать читающий поток }
        {Пока это только получение символа                       }
        SetCommMask(FHandle, EV_RXCHAR);

        while (not Terminated) and Connected do  {пока порт открыт}
          begin
            { Ждем одного из событий }
            WaitCommEvent(FHandle, Mask, @RxOL);

            Signaled:= WaitForSingleObject(RxOL.hEvent, INFINITE);

            if (Signaled  = WAIT_OBJECT_0) then
              begin
                if GetOverlappedResult(FHandle, RxOL, BytesTrans, False) then
                  begin
                    {после GetOverlappedResult в переменной mask, которая}
                    {передавалась в WaitCommEvent, появятся флаги произошедших}
                    {событий, либо 0 в случае ошибки.}
                    if (Mask and EV_RXCHAR) <> 0 then
                      begin
                        {Получаем состояние порта (линий и модема)}
                        CurrentState:= GetState(ErrCode);

                        {Число полученных, но еще не прочитанных байт}
                        AvaibleBytes:= CurrentState.cbInQue;
                        {Проверка числа доступных байт}
                        if FWaitFullBuffer then
                          begin
                            {ждать только полного буфера}
                            bReadable:= AvaibleBytes >= FBufferSize;
                          end
                        else
                          begin
                            {ждать любого числа байт}
                            bReadable:= AvaibleBytes > 0;
                          end;

                        if bReadable then
                          begin
                            {Чистка буфера}
                            ZeroMemory(FBuffer, FBufferSize);
                            if ReadFile(FHandle, FBuffer^, Min(FBufferSize, AvaibleBytes), RealRx, @RxOL) then
                              begin
                                {сохраняем параметры вызова события}
                                FErrorCode:= ErrCode;
                                FNOfBytes:= RealRx;
                                {Вызываем событие OnReadByte. Для синхронизации с VCL}
                                {надо вызвать метод Synchronize                      }
                                Synchronize(DoRx);
                              end;
                          end;

                      end;
                  end;
              end;
          end;
      finally
        {закрытие дескриптора сигнального объекта}
        CloseHandle(RxOL.hEvent);
        {Сброс события и маски ожидания}
        SetCommMask(FHandle, 0);
      end;
    end;
end;

{Вызывается для передачи события о приходе байта}
{в основной компонент через метод Synchronize   }
procedure TRxThread.DoRx;
begin
  with FOwner do
    begin
      if Assigned(OnRxComplete) then
        OnRxComplete(FBuffer, FNOfBytes, FErrorCode);
    end;
end;

{******************************************************************************}

{Класс TUARTProp }
function TUARTProp.GetDCB: TDCB;
begin
  {Чистка структуры }
  ZeroMemory(@Result, SizeOf(TDCB));
  {Пеле DCBLength должно содержать размер структуры }
  Result.DCBLength:= SizeOf(TDCB);
  {Скорость обмена (бод) }
  Result.BaudRate := WindowsBaudRates[FBaudRate];
  {Windows не поддерживает не бинарный режим работы последовательных портов }
  Result.Flags := dcb_Binary;
  {Число бит в байте }
  Result.ByteSize := 5 + Ord(FByteSize);
  {Контроль четности }
  Result.Parity := Ord(FParity);
  {Число стоп бит }
  Result.StopBits := Ord(FStopBits);
end;

procedure TUARTProp.SetDCB(const Value: TDCB);
var i : TBaudRate;
begin
  {скорость обмена (бод)}
  FBaudRate:= BR____110;
  for i:= Low(WindowsBaudRates) to High(WindowsBaudRates) do
    begin
      if Value.BaudRate = WindowsBaudRates[i] then
        begin
          FBaudRate:= i;
          Break;
        end;
    end;
  {число бит в байте}
  FByteSize:= TByteSize(Value.ByteSize - 5);
  {четность}
  FParity := TParity(Value.Parity);
  {число стоп-бит}
  FStopBits:= TStopBits(Value.StopBits);
end;

{******************************************************************************}

constructor TUART.Create(AOwner : TComponent);
begin
  inherited Create(AOwner);
  FUARTPort:= 2;
  FUARTProp:= TUARTProp.Create; {свойства порта}
  with FUARTProp do
    begin
      FBaudRate:= BR__57600;
      FByteSize:= BS8;
      FParity:= P_None;
    end;
  FHandle := INVALID_HANDLE_VALUE;
  FRxThread:= nil;
  FBufferSize := 10;
  FWaitFullBuffer:= False;
end;

destructor TUART.Destroy;
begin
  {Закрываем порт и соединение}
  DoCloseUART;
  FUARTProp.Free;
  inherited Destroy;
end;

procedure TUART.ApplyUARTSettings;
begin
  if not Connected then Exit;
  {Установить настройки порта, согласно DCB }
  SetCommState(FHandle, FUARTProp.DCB);
end;

{Диалог настройки параметров порта}
function TUART.UARTPropDialog : Boolean;
var COMCfg : TCommConfig;
begin
  ZeroMemory(@COMCfg, SizeOf(TCommConfig));
  COMCfg.dwSize:= SizeOf(TCommConfig);
  COMCfg.DCB:= FUARTProp.DCB;
  Result:= CommConfigDialog(PChar(GetUARTName(False)), 0, COMCfg);
  if Result then
    begin
      FUARTProp.DCB:= COMCfg.DCB;
      ApplyUARTSettings;
    end;
end;

{Изменение размера входного буфера}
procedure TUART.SetBufferSize(const Value: Cardinal);
begin
  {Разрешаем менять только при выключенном соединении}
  if Connected then Exit;
  {Нельзя задать нулевое или неверное значение размера}
  if Value <= 0 then Exit;
  {Запоминаем новый размер буфера}
  FBufferSize:= Value;
end;

function TUART.GetConnected: Boolean;
begin
  Result:= (FHandle <> INVALID_HANDLE_VALUE);
end;

procedure TUART.SetConnected(const Value: Boolean);
begin
  if Value then DoOpenUART else DoCloseUART;
end;

{Установка соединения}
function TUART.Connect : Boolean;
begin
  DoOpenUART;
  Result:= Connected;
end;

{Установка соединения (дублирует Connect:= True)}
procedure TUART.Open;
begin
  DoOpenUART;
end;

{Закрытие соединения (дублирует Connect:= False)}
procedure TUART.Close;
begin
  DoCloseUART;
end;

{Установка номера порта}
procedure TUART.SetUARTPort(const Value: Integer);
var Active : Boolean;
begin
  if FUARTPort = Value then Exit;
  Active:= Connected; {сохраним значение активности порта}
  if Active then DoCloseUART; {закрыть порт перед изменением индекса}
  FUARTPort:= Value; {устанавливаем новое значение номера порта}
  if Active then DoOpenUART; {открыть порт, если он был открыт}
end;

{Возвращает строковое имя порта}
function TUART.GetUARTName(FullName : Boolean) : String;
begin
  {Для портов 1..9 можно использовать простые имена COM1..COM9,}
  {но для портов 10-256 надо писать полное имя. Для общности   }
  {будем всегда использовать полное имя порта, за исключением  }
  {вызова CommConfigDialog }
  if FullName then
    Result:= Format('\\.\COM%-d', [FUARTPort])
  else
    Result:= Format('COM%-d', [FUARTPort]);
end;

{открытие порта}
procedure TUART.DoOpenUART;
var TimeOuts:TCommTimeOuts;
begin
  if Connected then Exit;
  {Запрещаем подключение в среде разработки}
  if csDesigning in ComponentState then Exit;

  {Открытие последовательного порта}
  FHandle:= CreateFile(
              PChar(GetUARTName(True)), {передаем имя открываемого порта}
              GENERIC_READ or GENERIC_WRITE, {ресурс для чтения и записи}
              0, { не разделяемый ресурс }
              nil, { Нет атрибутов защиты }
              OPEN_EXISTING, {вернуть ошибку, если ресурс не существует}
              FILE_ATTRIBUTE_NORMAL or FILE_FLAG_OVERLAPPED, {асинхронный режим доступа}
              0 ); { Должно быть 0 для COM портов }
  {Если ошибка открытия порта - выход}
  if not Connected then Exit;
  {Задание параметров порта}
  ApplyUARTSettings;

  {Размеры входного и выходного буферов}
  SetupComm(FHandle, 65536, 65536);

  {Задание таймаутов на немедленное возвращение результата чтения}
  GetCommTimeOuts(FHandle,TimeOuts);
  FillChar(TimeOuts,SizeOf(TimeOuts),0);
  TimeOuts.ReadIntervalTimeout:= MAXDWORD;
  SetCommTimeOuts(FHandle,TimeOuts);

  Toggle_DTR(True);

  {Создание читающего потока}
  if not Assigned(FRxThread) then
    FRxThread:= TRxThread.Create(Self);
end;

{закрытие порта}
procedure TUART.DoCloseUART;
begin
  if not Connected then Exit;
  {Замораживаем поток чтения}
  RxActive:= False;
  {Уничтожение читающего потока}
  FRxThread.FreeOnTerminate:= True;
  FRxThread.Terminate;
  FRxThread:= nil;
  {Освобождение дескриптора порта}
  CloseHandle(FHandle);
  {Сброс дескриптора порта}
  FHandle:= INVALID_HANDLE_VALUE;
end;

{Возвращает структуру состояния порта и код ошибок}
function TUART.GetState(var CodeError : Cardinal) : TCOMStat;
begin
  ClearCommError(FHandle, CodeError, @Result);
end;

{Передача строки}
function TUART.TxString(const S : String) : Boolean;
begin
  Result:= TxBuffer(PChar(S), Length(S));
end;

{Передача буфера данных}
function TUART.TxBuffer(const P : PChar; const Size : Integer) : Boolean;
var Signaled, RealTx, BytesTrans : Cardinal;
    TxOL : TOverLapped; {структура для асинхронной записи}
begin
  Result:= False;
  if P = nil then Exit;

  {создание события для асинхронной записи}
  FillChar(TxOL, SizeOf(TxOL), 0);
  TxOL.hEvent:= CreateEvent(nil, True, True, nil);

  try
    {начало асинхронной записи}
    WriteFile(FHandle, P^, Size, RealTx, @TxOL);
    {ожидания завершения асинхронной операции}
    Signaled:= WaitForSingleObject(TxOL.hEvent, INFINITE);
    {получение результата асинхронной операции}
    Result :=
      (Signaled = WAIT_OBJECT_0) and
      (GetOverlappedResult(FHandle, TxOL, BytesTrans, False));
  finally
    {освобождение дескриптора события}
    CloseHandle(TxOL.hEvent);
  end;
end;

{Активность чтения порта}
procedure TUART.SetRxActive(const Value: Boolean);
begin
  if not Assigned(FRxThread) then Exit;

  if Value then
    begin
      if FRxThread.Suspended then FRxThread.Resume;
    end
  else
    begin
      if not FRxThread.Suspended then FRxThread.Suspend;
    end;
end;

function TUART.GetRxActive: Boolean;
begin
  Result:= False;
  if Assigned(FRxThread) then
    Result:= not FRxThread.Suspended;
end;

{недокументированный код функции - получение базового адреса в dx}
function TUART.GetBaseAddress : Word;
begin
  EscapeCommFunction(FHandle, 10);
  asm
    mov  Result, dx
  end;
end;

{Управление линией DTR}
procedure TUART.Toggle_DTR(State : Boolean);
const Funcs: array[Boolean] of Cardinal = (CLRDTR, SETDTR);
begin
  if Connected then
    EscapeCommFunction(FHandle, Funcs[State]);
end;

{Управление линией RTS}
procedure TUART.Toggle_RTS(State : Boolean);
const Funcs: array[Boolean] of Cardinal = (CLRRTS, SETRTS);
begin
  if Connected then
    EscapeCommFunction(FHandle, Funcs[State]);
end;

{перечисление имен всех доступных коммуникационных портов}
class procedure TUART.EnumUARTPorts(Ports: TStrings);
var
  BytesNeeded, Returned, I: DWORD;
  Success: Boolean;
  PortsPtr: Pointer;
  InfoPtr: PPortInfo1;
  TempStr: string;
begin
  {Запрос размера нужного буфера}
  Success := EnumPorts(nil, 1, nil, 0, BytesNeeded, Returned);

  if (not Success) and (GetLastError = ERROR_INSUFFICIENT_BUFFER) then
    begin
      {Отводим нужный блок памяти}
      GetMem(PortsPtr, BytesNeeded);
      try
        {Получаем список имен портов}
        Success := EnumPorts(nil, 1, PortsPtr, BytesNeeded, BytesNeeded, Returned);

        {Переписываем имена в StringList, отсеивая не COM-порты}
        for I := 0 to Returned - 1 do
          begin
            InfoPtr := PPortInfo1(DWORD(PortsPtr) + I * SizeOf(TPortInfo1));
            TempStr := InfoPtr^.pName;
            if Copy(TempStr, 1, 3) = 'COM' then Ports.Add(TempStr);
          end;
      finally
        {Освобождаем буфер}
        FreeMem(PortsPtr);
      end;
    end;
end;

class function TUART.EnumCOMPorts(APorts : TStrings) : Boolean;
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
  {Открываем ключ в реестре}
  ErrCode:= RegOpenKeyEx(HKEY_LOCAL_MACHINE, 'HARDWARE\DEVICEMAP\SERIALCOMM', 0, KEY_READ, KeyHdl);
  if ErrCode <> ERROR_SUCCESS then Exit;

  {Перечисляем все значения ключа}
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
  {Закрываем ключ в реестре}
  RegCloseKey(KeyHdl);
end;

{перечисление всех доступных коммуникационных портов и их описаний}
class procedure TUART.EnumUARTPortsEx(Ports: TStrings);
var
  BytesNeeded, Returned, I: DWORD;
  Success: Boolean;
  PortsPtr: Pointer;
  InfoPtr: PPortInfo2;
  TempStr: string;
  Description : string;
begin
  {Запрос размера нужного буфера}
  Success := EnumPorts(nil, 2, nil, 0, BytesNeeded, Returned);

  if (not Success) and (GetLastError = ERROR_INSUFFICIENT_BUFFER) then
    begin
      {Отводим нужный блок памяти}
      GetMem(PortsPtr, BytesNeeded);
      try
        {Получаем список имен портов и их описания}
        Success := EnumPorts(nil, 2, PortsPtr, BytesNeeded, BytesNeeded, Returned);

        {Переписываем имена в StringList, отсеивая не COM-порты}
        for I := 0 to Returned - 1 do
          begin
            InfoPtr := PPortInfo2(DWORD(PortsPtr) + I * SizeOf(TPortInfo2));
            TempStr := InfoPtr^.pPortName;

            {Добавляем описание порта, если оно есть}
            Description:= '';
            if InfoPtr^.pDescription <> nil then
              Description:= ' ' + InfoPtr^.pDescription;

            {Переписываем имена в StringList, отсеивая не COM-порты}
            if Copy(TempStr, 1, 3) = 'COM' then
              begin
                TempStr:= TempStr + Description;
                Ports.Add(TempStr);
              end;
          end;
      finally
        {Освобождаем буфер}
        FreeMem(PortsPtr);
      end;
    end;
end;

{******************************************************************************}

procedure Register;
begin
  RegisterComponents('UART', [TUART]);
end;

end.



