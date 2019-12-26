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

  {��� ������� ��� ��������� �����}
  TRxComplete = procedure (const Buffer :Pointer;
                           const Size :Integer;
                           const ErrCode :Cardinal) of object;

  {����������� ��������}
  TUART = class;

  {�������� �����}
  TRxThread = class(TThread)
    FOwner     : TUART;  {�������� ���������}
    FBuffer    : Pointer; {������� �����}
    FErrorCode : Cardinal;{��������� ��� ������}
    FNOfBytes  : Integer; {������� ����������� ����� ����}
  protected
    procedure Execute; override;
    procedure DoRx;
  public
    constructor Create(AOwner : TUART);
    destructor  Destroy; override;
  end;

  {�������� �����}
  TUARTProp = class(TPersistent)
    private
      FBaudRate    : TBaudRate; {�������� ������ (���)}
      FByteSize    : TByteSize; {����� ��� � �����}
      FParity      : TParity;   {��������}
      FStopBits    : TStopBits; {����� ����-���}
      function  GetDCB: TDCB;
      procedure SetDCB(const Value: TDCB);
    public
      property DCB : TDCB read GetDCB write SetDCB;
    published
      {�������� ������}
      property BaudRate  : TBaudRate read FBaudRate write FBaudRate;
      {����� ��� � �����}
      property ByteSize  : TByteSize read FByteSize write FByteSize;
      {��������}
      property Parity    : TParity   read FParity   write FParity;
      {����� ����-���}
      property StopBits  : TStopBits read FStopbits write FStopbits;
    end;

  {��������� �����}
  TUART = class(TComponent)
    protected
      FUARTPort       : Integer;     {����� �����}
      FHandle         : THandle;     {���������� �����}
      FOnRxComplete   : TRxComplete; {������� "��������� ������"}
      FRxThread       : TRxThread;   {�������� �����}
      FBufferSize     : Cardinal;    {������ ������� ������� }
      FWaitFullBuffer : Boolean;     {�������� ���������� ������}
      FUARTProp       : TUARTProp;   {�������� �����}
      procedure DoOpenUART;          {�������� �����}
      procedure DoCloseUART;         {�������� �����}
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
      {���������/��������� ����}
      procedure Open;
      procedure Close;
      {���������� True, ���� ���� ������}
      function  Connect : Boolean;
      {���������� ��������� ��������� ����� ComStat, � �    }
      {���������� CodeError ������������ ������� ��� ������ }
      function  GetState(var CodeError : Cardinal) : TCOMStat;
      {�������� �����. � ������ ������ ���������� True}
      function  TxBuffer(const P : PChar; const Size : Integer) : Boolean;
      {�������� ������. � ������ ������ ���������� True}
      function  TxString(const S : String) : Boolean;
      {���������� ��������� ��� �����}
      function  GetUARTName(FullName : Boolean) : String;
      {������ ��������� ���������� �����}
      function  UARTPropDialog : Boolean;
      {���������� ������ �����}
      property RxActive : Boolean read GetRxActive write SetRxActive;
      {���������� True, ���� ���� ������}
      property Connected : Boolean read GetConnected write SetConnected;
    published
      {����� �����. ��� ��������� ���� ���������������, ���� ��� ������}
      property UARTPort : Integer read FUARTPort write SetUARTPort;
      {��������� �����}
      property UARTProp : TUARTProp read FUARTProp write FUARTProp;
      {������ �������� ������}
      property BufferSize : Cardinal read FBufferSize write SetBufferSize;
      {�������� ���������� ������}
      property WaitFullBuffer : Boolean read FWaitFullBuffer write FWaitFullBuffer;
      {�������, ���������� ��� ��������� �����}
      property OnRxComplete : TRxComplete read FOnRxComplete
                                          write FOnRxComplete;
    public {�������������� �������}
      {��������� �������� ������}
      function GetBaseAddress : Word;
      {���������� ������ DTR}
      procedure Toggle_DTR(State : Boolean);
      {���������� ������ RTS}
      procedure Toggle_RTS(State : Boolean);
      {������������ ���� COM ������}
      class procedure EnumUARTPorts(Ports: TStrings);
      class procedure EnumUARTPortsEx(Ports: TStrings);
      class function EnumCOMPorts(APorts : TStrings) : Boolean;
    end;

procedure Register;

implementation

uses
  Dialogs, WinSpool, Math;

{���������� ������� � ������� ��� ������� ���������}
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

{����� TRxThread }
constructor TRxThread.Create(AOwner : TUART);
begin
  inherited Create(True);
  FOwner:= AOwner;
  {������� ����� �����}
  GetMem(FBuffer, FOwner.FBufferSize);
end;

destructor TRxThread.Destroy;
begin
  {����������� �����}
  FreeMem(FBuffer);
  inherited Destroy;
end;

{�������� ������� ������}
procedure TRxThread.Execute;
var
  CurrentState : TCOMStat;
  AvaibleBytes, ErrCode, RealRx : Cardinal;
  RxOL : TOverLapped; {��������� ��� ������������ ������}
  Signaled, Mask : DWORD;
  BytesTrans : DWORD; {�� ������������ ��� WaitCommEvent}
  bReadable : Boolean; {���������� � ������ ������}
begin
  with FOwner do
    begin
      try
        {�������� ������� ��� ������������ ������}
        FillChar(RxOL, SizeOf(RxOL), 0);
        RxOL.hEvent:= CreateEvent(nil, True, True, nil);

        {����� �������, ������� ����� ����������� �������� ����� }
        {���� ��� ������ ��������� �������                       }
        SetCommMask(FHandle, EV_RXCHAR);

        while (not Terminated) and Connected do  {���� ���� ������}
          begin
            { ���� ������ �� ������� }
            WaitCommEvent(FHandle, Mask, @RxOL);

            Signaled:= WaitForSingleObject(RxOL.hEvent, INFINITE);

            if (Signaled  = WAIT_OBJECT_0) then
              begin
                if GetOverlappedResult(FHandle, RxOL, BytesTrans, False) then
                  begin
                    {����� GetOverlappedResult � ���������� mask, �������}
                    {������������ � WaitCommEvent, �������� ����� ������������}
                    {�������, ���� 0 � ������ ������.}
                    if (Mask and EV_RXCHAR) <> 0 then
                      begin
                        {�������� ��������� ����� (����� � ������)}
                        CurrentState:= GetState(ErrCode);

                        {����� ����������, �� ��� �� ����������� ����}
                        AvaibleBytes:= CurrentState.cbInQue;
                        {�������� ����� ��������� ����}
                        if FWaitFullBuffer then
                          begin
                            {����� ������ ������� ������}
                            bReadable:= AvaibleBytes >= FBufferSize;
                          end
                        else
                          begin
                            {����� ������ ����� ����}
                            bReadable:= AvaibleBytes > 0;
                          end;

                        if bReadable then
                          begin
                            {������ ������}
                            ZeroMemory(FBuffer, FBufferSize);
                            if ReadFile(FHandle, FBuffer^, Min(FBufferSize, AvaibleBytes), RealRx, @RxOL) then
                              begin
                                {��������� ��������� ������ �������}
                                FErrorCode:= ErrCode;
                                FNOfBytes:= RealRx;
                                {�������� ������� OnReadByte. ��� ������������� � VCL}
                                {���� ������� ����� Synchronize                      }
                                Synchronize(DoRx);
                              end;
                          end;

                      end;
                  end;
              end;
          end;
      finally
        {�������� ����������� ����������� �������}
        CloseHandle(RxOL.hEvent);
        {����� ������� � ����� ��������}
        SetCommMask(FHandle, 0);
      end;
    end;
end;

{���������� ��� �������� ������� � ������� �����}
{� �������� ��������� ����� ����� Synchronize   }
procedure TRxThread.DoRx;
begin
  with FOwner do
    begin
      if Assigned(OnRxComplete) then
        OnRxComplete(FBuffer, FNOfBytes, FErrorCode);
    end;
end;

{******************************************************************************}

{����� TUARTProp }
function TUARTProp.GetDCB: TDCB;
begin
  {������ ��������� }
  ZeroMemory(@Result, SizeOf(TDCB));
  {���� DCBLength ������ ��������� ������ ��������� }
  Result.DCBLength:= SizeOf(TDCB);
  {�������� ������ (���) }
  Result.BaudRate := WindowsBaudRates[FBaudRate];
  {Windows �� ������������ �� �������� ����� ������ ���������������� ������ }
  Result.Flags := dcb_Binary;
  {����� ��� � ����� }
  Result.ByteSize := 5 + Ord(FByteSize);
  {�������� �������� }
  Result.Parity := Ord(FParity);
  {����� ���� ��� }
  Result.StopBits := Ord(FStopBits);
end;

procedure TUARTProp.SetDCB(const Value: TDCB);
var i : TBaudRate;
begin
  {�������� ������ (���)}
  FBaudRate:= BR____110;
  for i:= Low(WindowsBaudRates) to High(WindowsBaudRates) do
    begin
      if Value.BaudRate = WindowsBaudRates[i] then
        begin
          FBaudRate:= i;
          Break;
        end;
    end;
  {����� ��� � �����}
  FByteSize:= TByteSize(Value.ByteSize - 5);
  {��������}
  FParity := TParity(Value.Parity);
  {����� ����-���}
  FStopBits:= TStopBits(Value.StopBits);
end;

{******************************************************************************}

constructor TUART.Create(AOwner : TComponent);
begin
  inherited Create(AOwner);
  FUARTPort:= 2;
  FUARTProp:= TUARTProp.Create; {�������� �����}
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
  {��������� ���� � ����������}
  DoCloseUART;
  FUARTProp.Free;
  inherited Destroy;
end;

procedure TUART.ApplyUARTSettings;
begin
  if not Connected then Exit;
  {���������� ��������� �����, �������� DCB }
  SetCommState(FHandle, FUARTProp.DCB);
end;

{������ ��������� ���������� �����}
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

{��������� ������� �������� ������}
procedure TUART.SetBufferSize(const Value: Cardinal);
begin
  {��������� ������ ������ ��� ����������� ����������}
  if Connected then Exit;
  {������ ������ ������� ��� �������� �������� �������}
  if Value <= 0 then Exit;
  {���������� ����� ������ ������}
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

{��������� ����������}
function TUART.Connect : Boolean;
begin
  DoOpenUART;
  Result:= Connected;
end;

{��������� ���������� (��������� Connect:= True)}
procedure TUART.Open;
begin
  DoOpenUART;
end;

{�������� ���������� (��������� Connect:= False)}
procedure TUART.Close;
begin
  DoCloseUART;
end;

{��������� ������ �����}
procedure TUART.SetUARTPort(const Value: Integer);
var Active : Boolean;
begin
  if FUARTPort = Value then Exit;
  Active:= Connected; {�������� �������� ���������� �����}
  if Active then DoCloseUART; {������� ���� ����� ���������� �������}
  FUARTPort:= Value; {������������� ����� �������� ������ �����}
  if Active then DoOpenUART; {������� ����, ���� �� ��� ������}
end;

{���������� ��������� ��� �����}
function TUART.GetUARTName(FullName : Boolean) : String;
begin
  {��� ������ 1..9 ����� ������������ ������� ����� COM1..COM9,}
  {�� ��� ������ 10-256 ���� ������ ������ ���. ��� ��������   }
  {����� ������ ������������ ������ ��� �����, �� �����������  }
  {������ CommConfigDialog }
  if FullName then
    Result:= Format('\\.\COM%-d', [FUARTPort])
  else
    Result:= Format('COM%-d', [FUARTPort]);
end;

{�������� �����}
procedure TUART.DoOpenUART;
var TimeOuts:TCommTimeOuts;
begin
  if Connected then Exit;
  {��������� ����������� � ����� ����������}
  if csDesigning in ComponentState then Exit;

  {�������� ����������������� �����}
  FHandle:= CreateFile(
              PChar(GetUARTName(True)), {�������� ��� ������������ �����}
              GENERIC_READ or GENERIC_WRITE, {������ ��� ������ � ������}
              0, { �� ����������� ������ }
              nil, { ��� ��������� ������ }
              OPEN_EXISTING, {������� ������, ���� ������ �� ����������}
              FILE_ATTRIBUTE_NORMAL or FILE_FLAG_OVERLAPPED, {����������� ����� �������}
              0 ); { ������ ���� 0 ��� COM ������ }
  {���� ������ �������� ����� - �����}
  if not Connected then Exit;
  {������� ���������� �����}
  ApplyUARTSettings;

  {������� �������� � ��������� �������}
  SetupComm(FHandle, 65536, 65536);

  {������� ��������� �� ����������� ����������� ���������� ������}
  GetCommTimeOuts(FHandle,TimeOuts);
  FillChar(TimeOuts,SizeOf(TimeOuts),0);
  TimeOuts.ReadIntervalTimeout:= MAXDWORD;
  SetCommTimeOuts(FHandle,TimeOuts);

  Toggle_DTR(True);

  {�������� ��������� ������}
  if not Assigned(FRxThread) then
    FRxThread:= TRxThread.Create(Self);
end;

{�������� �����}
procedure TUART.DoCloseUART;
begin
  if not Connected then Exit;
  {������������ ����� ������}
  RxActive:= False;
  {����������� ��������� ������}
  FRxThread.FreeOnTerminate:= True;
  FRxThread.Terminate;
  FRxThread:= nil;
  {������������ ����������� �����}
  CloseHandle(FHandle);
  {����� ����������� �����}
  FHandle:= INVALID_HANDLE_VALUE;
end;

{���������� ��������� ��������� ����� � ��� ������}
function TUART.GetState(var CodeError : Cardinal) : TCOMStat;
begin
  ClearCommError(FHandle, CodeError, @Result);
end;

{�������� ������}
function TUART.TxString(const S : String) : Boolean;
begin
  Result:= TxBuffer(PChar(S), Length(S));
end;

{�������� ������ ������}
function TUART.TxBuffer(const P : PChar; const Size : Integer) : Boolean;
var Signaled, RealTx, BytesTrans : Cardinal;
    TxOL : TOverLapped; {��������� ��� ����������� ������}
begin
  Result:= False;
  if P = nil then Exit;

  {�������� ������� ��� ����������� ������}
  FillChar(TxOL, SizeOf(TxOL), 0);
  TxOL.hEvent:= CreateEvent(nil, True, True, nil);

  try
    {������ ����������� ������}
    WriteFile(FHandle, P^, Size, RealTx, @TxOL);
    {�������� ���������� ����������� ��������}
    Signaled:= WaitForSingleObject(TxOL.hEvent, INFINITE);
    {��������� ���������� ����������� ��������}
    Result :=
      (Signaled = WAIT_OBJECT_0) and
      (GetOverlappedResult(FHandle, TxOL, BytesTrans, False));
  finally
    {������������ ����������� �������}
    CloseHandle(TxOL.hEvent);
  end;
end;

{���������� ������ �����}
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

{������������������� ��� ������� - ��������� �������� ������ � dx}
function TUART.GetBaseAddress : Word;
begin
  EscapeCommFunction(FHandle, 10);
  asm
    mov  Result, dx
  end;
end;

{���������� ������ DTR}
procedure TUART.Toggle_DTR(State : Boolean);
const Funcs: array[Boolean] of Cardinal = (CLRDTR, SETDTR);
begin
  if Connected then
    EscapeCommFunction(FHandle, Funcs[State]);
end;

{���������� ������ RTS}
procedure TUART.Toggle_RTS(State : Boolean);
const Funcs: array[Boolean] of Cardinal = (CLRRTS, SETRTS);
begin
  if Connected then
    EscapeCommFunction(FHandle, Funcs[State]);
end;

{������������ ���� ���� ��������� ���������������� ������}
class procedure TUART.EnumUARTPorts(Ports: TStrings);
var
  BytesNeeded, Returned, I: DWORD;
  Success: Boolean;
  PortsPtr: Pointer;
  InfoPtr: PPortInfo1;
  TempStr: string;
begin
  {������ ������� ������� ������}
  Success := EnumPorts(nil, 1, nil, 0, BytesNeeded, Returned);

  if (not Success) and (GetLastError = ERROR_INSUFFICIENT_BUFFER) then
    begin
      {������� ������ ���� ������}
      GetMem(PortsPtr, BytesNeeded);
      try
        {�������� ������ ���� ������}
        Success := EnumPorts(nil, 1, PortsPtr, BytesNeeded, BytesNeeded, Returned);

        {������������ ����� � StringList, �������� �� COM-�����}
        for I := 0 to Returned - 1 do
          begin
            InfoPtr := PPortInfo1(DWORD(PortsPtr) + I * SizeOf(TPortInfo1));
            TempStr := InfoPtr^.pName;
            if Copy(TempStr, 1, 3) = 'COM' then Ports.Add(TempStr);
          end;
      finally
        {����������� �����}
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

{������������ ���� ��������� ���������������� ������ � �� ��������}
class procedure TUART.EnumUARTPortsEx(Ports: TStrings);
var
  BytesNeeded, Returned, I: DWORD;
  Success: Boolean;
  PortsPtr: Pointer;
  InfoPtr: PPortInfo2;
  TempStr: string;
  Description : string;
begin
  {������ ������� ������� ������}
  Success := EnumPorts(nil, 2, nil, 0, BytesNeeded, Returned);

  if (not Success) and (GetLastError = ERROR_INSUFFICIENT_BUFFER) then
    begin
      {������� ������ ���� ������}
      GetMem(PortsPtr, BytesNeeded);
      try
        {�������� ������ ���� ������ � �� ��������}
        Success := EnumPorts(nil, 2, PortsPtr, BytesNeeded, BytesNeeded, Returned);

        {������������ ����� � StringList, �������� �� COM-�����}
        for I := 0 to Returned - 1 do
          begin
            InfoPtr := PPortInfo2(DWORD(PortsPtr) + I * SizeOf(TPortInfo2));
            TempStr := InfoPtr^.pPortName;

            {��������� �������� �����, ���� ��� ����}
            Description:= '';
            if InfoPtr^.pDescription <> nil then
              Description:= ' ' + InfoPtr^.pDescription;

            {������������ ����� � StringList, �������� �� COM-�����}
            if Copy(TempStr, 1, 3) = 'COM' then
              begin
                TempStr:= TempStr + Description;
                Ports.Add(TempStr);
              end;
          end;
      finally
        {����������� �����}
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



