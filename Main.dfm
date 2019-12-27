object MainForm: TMainForm
  Left = 2897
  Top = 330
  BorderStyle = bsToolWindow
  Caption = 'ROS Serial Tester'
  ClientHeight = 602
  ClientWidth = 497
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object ValueLabel: TLabel
    Left = 40
    Top = 568
    Width = 329
    Height = 13
    Alignment = taCenter
    AutoSize = False
    Caption = 'ValueLabel'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clBlack
    Font.Height = -13
    Font.Name = 'Tahoma'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object ConnectionGroup: TGroupBox
    Left = 8
    Top = 8
    Width = 249
    Height = 49
    Caption = '  Connection  '
    TabOrder = 0
    object UpdatePortsList: TButton
      Left = 8
      Top = 16
      Width = 21
      Height = 20
      Caption = 'U'
      TabOrder = 0
      OnClick = UpdatePortsListClick
    end
    object PortsList: TComboBox
      Left = 32
      Top = 16
      Width = 97
      Height = 21
      Style = csDropDownList
      DragKind = dkDock
      ItemHeight = 13
      TabOrder = 1
      OnChange = PortsListChange
    end
    object LED: TPanel
      Left = 132
      Top = 16
      Width = 29
      Height = 21
      BevelOuter = bvNone
      BorderStyle = bsSingle
      Color = clRed
      TabOrder = 2
    end
    object ConnectBtn: TButton
      Left = 164
      Top = 16
      Width = 75
      Height = 20
      Caption = 'Connect'
      TabOrder = 3
      OnClick = ConnectBtnClick
    end
  end
  object PourGroup: TGroupBox
    Left = 264
    Top = 8
    Width = 225
    Height = 49
    Caption = '  Pour  '
    TabOrder = 1
    object StartBtn: TButton
      Left = 8
      Top = 16
      Width = 209
      Height = 25
      Caption = 'Start'
      TabOrder = 0
      OnClick = StartBtnClick
    end
  end
  object LogMemo: TMemo
    Left = 8
    Top = 64
    Width = 481
    Height = 497
    Color = clBlack
    Font.Charset = RUSSIAN_CHARSET
    Font.Color = clLime
    Font.Height = -11
    Font.Name = 'Courier New'
    Font.Style = []
    ParentFont = False
    ScrollBars = ssVertical
    TabOrder = 2
  end
  object ClearBtn: TButton
    Left = 8
    Top = 568
    Width = 25
    Height = 25
    Caption = 'C'
    TabOrder = 3
    OnClick = ClearBtnClick
  end
  object LedButton: TButton
    Left = 456
    Top = 568
    Width = 35
    Height = 25
    Caption = 'LED'
    TabOrder = 4
    OnClick = LedButtonClick
  end
  object UART: TUART
    UARTPort = 6
    UARTProp.BaudRate = BR_115200
    UARTProp.ByteSize = BS8
    UARTProp.Parity = P_None
    UARTProp.StopBits = SB_10
    BufferSize = 65536
    WaitFullBuffer = False
    OnRxComplete = UARTRxComplete
    Left = 16
    Top = 72
  end
end
