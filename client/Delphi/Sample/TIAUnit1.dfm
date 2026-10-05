object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'Form1'
  ClientHeight = 809
  ClientWidth = 1161
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  object btLogin: TButton
    Left = 8
    Top = 8
    Width = 75
    Height = 25
    Caption = 'Login'
    TabOrder = 0
    OnClick = btLoginClick
  end
  object btRefreshToken: TButton
    Left = 89
    Top = 8
    Width = 96
    Height = 25
    Caption = 'Refresh Token'
    TabOrder = 1
    OnClick = btRefreshTokenClick
  end
  object btErrorRate: TButton
    Left = 191
    Top = 8
    Width = 96
    Height = 25
    Caption = 'Fehlerquote'
    TabOrder = 2
    OnClick = btErrorRateClick
  end
  object PageControl1: TPageControl
    Left = 8
    Top = 39
    Width = 1129
    Height = 306
    ActivePage = tsDatev
    TabOrder = 2
    object tsB4Value: TTabSheet
      Caption = 'B4Value'
      DesignSize = (
        1121
        276)
      object Label1: TLabel
        Left = 8
        Top = 13
        Width = 66
        Height = 15
        Caption = 'Accesstoken'
      end
      object Label2: TLabel
        Left = 8
        Top = 42
        Width = 69
        Height = 15
        Caption = 'Refreshtoken'
      end
      object Label18: TLabel
        Left = 24
        Top = 84
        Width = 55
        Height = 15
        Caption = 'Traffiqx-ID'
      end
      object edB4ValueAccessToken: TLabeledEdit
        Left = 93
        Top = 9
        Width = 800
        Height = 23
        Anchors = [akLeft, akTop, akRight]
        EditLabel.Width = 3
        EditLabel.Height = 23
        LabelPosition = lpRight
        TabOrder = 0
        Text = ''
      end
      object edB4ValueRefreshToken: TEdit
        Left = 93
        Top = 38
        Width = 1000
        Height = 23
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 1
      end
      object Edit1: TEdit
        Left = 93
        Top = 80
        Width = 128
        Height = 23
        TabOrder = 2
      end
    end
    object tsBundesdruckerei: TTabSheet
      Caption = 'Bundesdruckerei'
      ImageIndex = 1
      DesignSize = (
        1121
        276)
      object Label3: TLabel
        Left = 8
        Top = 13
        Width = 66
        Height = 15
        Caption = 'Accesstoken'
      end
      object Label4: TLabel
        Left = 8
        Top = 42
        Width = 69
        Height = 15
        Caption = 'Refreshtoken'
      end
      object Label19: TLabel
        Left = 24
        Top = 84
        Width = 55
        Height = 15
        Caption = 'Traffiqx-ID'
      end
      object Edit3: TLabeledEdit
        Left = 93
        Top = 9
        Width = 800
        Height = 23
        Anchors = [akLeft, akTop, akRight]
        EditLabel.Width = 3
        EditLabel.Height = 23
        LabelPosition = lpRight
        TabOrder = 0
        Text = ''
      end
      object Edit4: TEdit
        Left = 93
        Top = 38
        Width = 1000
        Height = 23
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 1
      end
      object Edit2: TEdit
        Left = 93
        Top = 80
        Width = 128
        Height = 23
        TabOrder = 2
      end
    end
    object tsBeCloud: TTabSheet
      Caption = 'BeCloud'
      ImageIndex = 2
      DesignSize = (
        1121
        276)
      object Label5: TLabel
        Left = 8
        Top = 13
        Width = 66
        Height = 15
        Caption = 'Accesstoken'
      end
      object Label6: TLabel
        Left = 8
        Top = 42
        Width = 69
        Height = 15
        Caption = 'Refreshtoken'
      end
      object Label20: TLabel
        Left = 24
        Top = 84
        Width = 55
        Height = 15
        Caption = 'Traffiqx-ID'
      end
      object Edit5: TLabeledEdit
        Left = 93
        Top = 9
        Width = 800
        Height = 23
        Anchors = [akLeft, akTop, akRight]
        EditLabel.Width = 3
        EditLabel.Height = 23
        LabelPosition = lpRight
        TabOrder = 0
        Text = ''
      end
      object Edit6: TEdit
        Left = 93
        Top = 38
        Width = 1000
        Height = 23
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 1
      end
      object Edit7: TEdit
        Left = 93
        Top = 80
        Width = 128
        Height = 23
        TabOrder = 2
      end
    end
    object tsDatev: TTabSheet
      Caption = 'Datev'
      ImageIndex = 3
      DesignSize = (
        1121
        276)
      object Label7: TLabel
        Left = 8
        Top = 13
        Width = 66
        Height = 15
        Caption = 'Accesstoken'
      end
      object Label8: TLabel
        Left = 8
        Top = 42
        Width = 69
        Height = 15
        Caption = 'Refreshtoken'
      end
      object edDatevAccessToken: TLabeledEdit
        Left = 93
        Top = 9
        Width = 800
        Height = 23
        Anchors = [akLeft, akTop, akRight]
        EditLabel.Width = 3
        EditLabel.Height = 23
        LabelPosition = lpRight
        TabOrder = 0
        Text = ''
      end
      object edDatevRefreshToken: TEdit
        Left = 93
        Top = 38
        Width = 1000
        Height = 23
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 1
      end
      object PageControl2: TPageControl
        Left = 0
        Top = 70
        Width = 1121
        Height = 206
        ActivePage = TabSheet1
        Align = alBottom
        Anchors = [akLeft, akTop, akRight, akBottom]
        TabOrder = 2
        object TabSheet1: TTabSheet
          Caption = 'Standard'
          object Label17: TLabel
            Left = 4
            Top = 12
            Width = 55
            Height = 15
            Caption = 'Traffiqx-ID'
          end
          object edDatevTraffiqxID: TEdit
            Left = 73
            Top = 8
            Width = 128
            Height = 23
            TabOrder = 0
          end
        end
        object TabSheet2: TTabSheet
          Caption = 'Error Handling'
          ImageIndex = 1
          object RadioGroup1: TRadioGroup
            Left = 3
            Top = 3
            Width = 422
            Height = 105
            Caption = 'Endpunkt'
            ItemIndex = 0
            Items.Strings = (
              '/traffiqx-clients/{trafiqx_id}/inbox-documents'
              
                '/trafiqx-clients/{trafiqx_id}/inbox-documents/{document_id}/meta' +
                'data'
              '/trafiqx-clients/{trafiqx_id}/inbox-documents/{document_id}')
            TabOrder = 0
            OnClick = RadioGroup1Click
          end
          object GroupBox1: TGroupBox
            Left = 431
            Top = 3
            Width = 354
            Height = 166
            Caption = 'Fehler'
            TabOrder = 1
            object RadioButton1: TRadioButton
              Left = 16
              Top = 24
              Width = 113
              Height = 17
              Caption = '1000000000010'
              Checked = True
              TabOrder = 0
              TabStop = True
            end
            object RadioButton2: TRadioButton
              Left = 16
              Top = 47
              Width = 113
              Height = 17
              Caption = '1000000000004'
              TabOrder = 1
            end
            object RadioButton3: TRadioButton
              Left = 16
              Top = 70
              Width = 113
              Height = 17
              Caption = '1000000000011'
              TabOrder = 2
            end
            object RadioButton4: TRadioButton
              Left = 16
              Top = 93
              Width = 113
              Height = 17
              Caption = '1000000000000'
              TabOrder = 3
            end
            object RadioButton5: TRadioButton
              Left = 16
              Top = 116
              Width = 113
              Height = 17
              Caption = '1000000000003'
              TabOrder = 4
            end
            object RadioButton6: TRadioButton
              Left = 16
              Top = 139
              Width = 113
              Height = 17
              Caption = '1000000000005'
              TabOrder = 5
            end
            object RadioButton7: TRadioButton
              Left = 128
              Top = 23
              Width = 113
              Height = 17
              Caption = '1000000000012'
              TabOrder = 6
            end
            object RadioButton8: TRadioButton
              Left = 128
              Top = 46
              Width = 113
              Height = 17
              Caption = '1000000000001'
              TabOrder = 7
            end
            object RadioButton9: TRadioButton
              Left = 128
              Top = 69
              Width = 113
              Height = 17
              Caption = '1000000000006'
              TabOrder = 8
            end
            object RadioButton10: TRadioButton
              Left = 128
              Top = 93
              Width = 113
              Height = 17
              Caption = '1000000000002'
              TabOrder = 9
            end
            object RadioButton11: TRadioButton
              Left = 240
              Top = 23
              Width = 113
              Height = 17
              Caption = '1000000000013'
              Enabled = False
              TabOrder = 10
            end
            object RadioButton12: TRadioButton
              Left = 240
              Top = 69
              Width = 113
              Height = 17
              Caption = '1000000000018'
              TabOrder = 11
            end
            object RadioButton13: TRadioButton
              Left = 240
              Top = 92
              Width = 113
              Height = 17
              Caption = '1000000000017'
              TabOrder = 12
            end
            object Button1: TButton
              Left = 256
              Top = 128
              Width = 75
              Height = 25
              Caption = 'Test'
              TabOrder = 13
              OnClick = Button1Click
            end
          end
          object Memo2: TMemo
            Left = 791
            Top = 0
            Width = 322
            Height = 176
            Align = alRight
            Anchors = [akLeft, akTop, akRight, akBottom]
            ScrollBars = ssBoth
            TabOrder = 2
            WordWrap = False
          end
        end
      end
    end
    object tsExela: TTabSheet
      Caption = 'ExelaAsterion'
      ImageIndex = 4
      DesignSize = (
        1121
        276)
      object Label9: TLabel
        Left = 8
        Top = 13
        Width = 66
        Height = 15
        Caption = 'Accesstoken'
      end
      object Label10: TLabel
        Left = 8
        Top = 42
        Width = 69
        Height = 15
        Caption = 'Refreshtoken'
      end
      object Label21: TLabel
        Left = 24
        Top = 84
        Width = 55
        Height = 15
        Caption = 'Traffiqx-ID'
      end
      object Edit9: TLabeledEdit
        Left = 93
        Top = 9
        Width = 800
        Height = 23
        Anchors = [akLeft, akTop, akRight]
        EditLabel.Width = 3
        EditLabel.Height = 23
        LabelPosition = lpRight
        TabOrder = 0
        Text = ''
      end
      object Edit10: TEdit
        Left = 93
        Top = 38
        Width = 1000
        Height = 23
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 1
      end
      object Edit8: TEdit
        Left = 93
        Top = 80
        Width = 128
        Height = 23
        TabOrder = 2
      end
    end
    object tsQuadient: TTabSheet
      Caption = 'Quadient'
      ImageIndex = 5
      DesignSize = (
        1121
        276)
      object Label11: TLabel
        Left = 8
        Top = 13
        Width = 66
        Height = 15
        Caption = 'Accesstoken'
      end
      object Label12: TLabel
        Left = 8
        Top = 42
        Width = 69
        Height = 15
        Caption = 'Refreshtoken'
      end
      object Label22: TLabel
        Left = 24
        Top = 84
        Width = 55
        Height = 15
        Caption = 'Traffiqx-ID'
      end
      object Edit11: TLabeledEdit
        Left = 93
        Top = 9
        Width = 800
        Height = 23
        Anchors = [akLeft, akTop, akRight]
        EditLabel.Width = 3
        EditLabel.Height = 23
        LabelPosition = lpRight
        TabOrder = 0
        Text = ''
      end
      object Edit12: TEdit
        Left = 93
        Top = 38
        Width = 1000
        Height = 23
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 1
      end
      object Edit17: TEdit
        Left = 93
        Top = 80
        Width = 128
        Height = 23
        TabOrder = 2
      end
    end
    object tsSGHService: TTabSheet
      Caption = 'SGHService'
      ImageIndex = 6
      DesignSize = (
        1121
        276)
      object Label13: TLabel
        Left = 8
        Top = 13
        Width = 66
        Height = 15
        Caption = 'Accesstoken'
      end
      object Label14: TLabel
        Left = 8
        Top = 42
        Width = 69
        Height = 15
        Caption = 'Refreshtoken'
      end
      object Label23: TLabel
        Left = 24
        Top = 71
        Width = 55
        Height = 15
        Caption = 'Traffiqx-ID'
      end
      object Edit13: TLabeledEdit
        Left = 93
        Top = 9
        Width = 800
        Height = 23
        Anchors = [akLeft, akTop, akRight]
        EditLabel.Width = 3
        EditLabel.Height = 23
        LabelPosition = lpRight
        TabOrder = 0
        Text = ''
      end
      object Edit14: TEdit
        Left = 93
        Top = 38
        Width = 1000
        Height = 23
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 1
      end
      object Edit18: TEdit
        Left = 93
        Top = 67
        Width = 128
        Height = 23
        TabOrder = 2
      end
    end
    object tsRicoh: TTabSheet
      Caption = 'Ricoh'
      ImageIndex = 7
      DesignSize = (
        1121
        276)
      object Label15: TLabel
        Left = 8
        Top = 13
        Width = 66
        Height = 15
        Caption = 'Accesstoken'
      end
      object Label16: TLabel
        Left = 8
        Top = 42
        Width = 69
        Height = 15
        Caption = 'Refreshtoken'
      end
      object Label24: TLabel
        Left = 24
        Top = 84
        Width = 55
        Height = 15
        Caption = 'Traffiqx-ID'
      end
      object Edit15: TLabeledEdit
        Left = 93
        Top = 9
        Width = 800
        Height = 23
        Anchors = [akLeft, akTop, akRight]
        EditLabel.Width = 3
        EditLabel.Height = 23
        LabelPosition = lpRight
        TabOrder = 0
        Text = ''
      end
      object Edit16: TEdit
        Left = 93
        Top = 38
        Width = 1000
        Height = 23
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 1
      end
      object Edit19: TEdit
        Left = 93
        Top = 80
        Width = 128
        Height = 23
        TabOrder = 2
      end
    end
    object TabSheet5: TTabSheet
      Caption = 'Datev Smarttransfer'
      ImageIndex = 8
      DesignSize = (
        1121
        276)
      object Label25: TLabel
        Left = 8
        Top = 13
        Width = 66
        Height = 15
        Caption = 'Accesstoken'
      end
      object Label26: TLabel
        Left = 8
        Top = 42
        Width = 69
        Height = 15
        Caption = 'Refreshtoken'
      end
      object Label27: TLabel
        Left = 24
        Top = 84
        Width = 55
        Height = 15
        Caption = 'Traffiqx-ID'
      end
      object LabeledEdit1: TLabeledEdit
        Left = 93
        Top = 9
        Width = 800
        Height = 23
        Anchors = [akLeft, akTop, akRight]
        EditLabel.Width = 3
        EditLabel.Height = 23
        LabelPosition = lpRight
        TabOrder = 0
        Text = ''
      end
      object Edit20: TEdit
        Left = 93
        Top = 38
        Width = 1000
        Height = 23
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 1
      end
      object Edit21: TEdit
        Left = 93
        Top = 80
        Width = 128
        Height = 23
        TabOrder = 2
      end
    end
  end
  object PageControl3: TPageControl
    Left = 0
    Top = 351
    Width = 1161
    Height = 458
    ActivePage = TabSheet4
    Align = alBottom
    Anchors = [akLeft, akTop, akRight, akBottom]
    TabOrder = 3
    object TabSheet3: TTabSheet
      Caption = 'Inbox'
      DesignSize = (
        1153
        428)
      object Memo1: TMemo
        Left = 178
        Top = 219
        Width = 327
        Height = 206
        Anchors = [akLeft, akTop, akRight, akBottom]
        ScrollBars = ssVertical
        TabOrder = 0
      end
      object btGetInboxDocumentIds: TButton
        Left = 3
        Top = 3
        Width = 137
        Height = 25
        Caption = 'GetInboxDocumentIds'
        TabOrder = 1
        OnClick = btGetInboxDocumentIdsClick
      end
      object ListView1: TListView
        Left = 3
        Top = 34
        Width = 1147
        Height = 179
        Columns = <>
        TabOrder = 2
      end
      object btGetInboxDocumentMetadata: TButton
        Left = 3
        Top = 219
        Width = 169
        Height = 25
        Caption = 'GetInboxDocumentMetadata'
        TabOrder = 3
        OnClick = btGetInboxDocumentMetadataClick
      end
      object btDownloadInboxDocument: TButton
        Left = 3
        Top = 250
        Width = 169
        Height = 25
        Caption = 'DownloadInboxDocument'
        TabOrder = 4
        OnClick = btDownloadInboxDocumentClick
      end
      object EdgeBrowser1: TEdgeBrowser
        Left = 511
        Top = 219
        Width = 639
        Height = 206
        TabOrder = 5
        AllowSingleSignOnUsingOSPrimaryAccount = False
        TargetCompatibleBrowserVersion = '137.0.3296.44'
        UserDataFolder = '%LOCALAPPDATA%\bds.exe.WebView2'
      end
    end
    object TabSheet4: TTabSheet
      Caption = 'Outbox'
      ImageIndex = 1
      DesignSize = (
        1153
        428)
      object EdgeBrowser2: TEdgeBrowser
        Left = 519
        Top = 227
        Width = 631
        Height = 198
        Anchors = [akLeft, akTop, akRight, akBottom]
        TabOrder = 0
        AllowSingleSignOnUsingOSPrimaryAccount = False
        TargetCompatibleBrowserVersion = '137.0.3296.44'
        UserDataFolder = '%LOCALAPPDATA%\bds.exe.WebView2'
      end
      object Memo3: TMemo
        Left = 186
        Top = 227
        Width = 327
        Height = 198
        Anchors = [akLeft, akTop, akBottom]
        ScrollBars = ssVertical
        TabOrder = 1
      end
      object btGetOutboxDocumentIds: TButton
        Left = 3
        Top = 11
        Width = 137
        Height = 25
        Caption = 'GetOutboxDocumentIds'
        TabOrder = 2
        OnClick = btGetOutboxDocumentIdsClick
      end
      object ListView2: TListView
        Left = 6
        Top = 42
        Width = 507
        Height = 179
        Columns = <>
        TabOrder = 3
      end
      object btGetOutboxDocumentMetadataClick: TButton
        Left = 11
        Top = 227
        Width = 169
        Height = 25
        Caption = 'GetOutboxDocumentMetadata'
        TabOrder = 4
        OnClick = btGetOutboxDocumentMetadataClickClick
      end
      object btDownloadOutboxDocument: TButton
        Left = 11
        Top = 289
        Width = 169
        Height = 25
        Caption = 'DownloadOutboxDocument'
        TabOrder = 5
        OnClick = btDownloadOutboxDocumentClick
      end
      object btGetOutboxDocumentStatus: TButton
        Left = 12
        Top = 258
        Width = 168
        Height = 25
        Caption = 'GetOutboxDocumentStatus'
        TabOrder = 6
        OnClick = btGetOutboxDocumentStatusClick
      end
      object btUploadStructuredData: TButton
        Left = 11
        Top = 320
        Width = 169
        Height = 25
        Caption = 'UploadStructuredData'
        TabOrder = 7
        OnClick = btUploadStructuredDataClick
      end
      object btUploadZugferdData: TButton
        Left = 11
        Top = 351
        Width = 169
        Height = 25
        Caption = 'UploadZugferdData'
        TabOrder = 8
        OnClick = btUploadZugferdDataClick
      end
      object Button2: TButton
        Left = 12
        Top = 400
        Width = 168
        Height = 25
        Caption = 'Erzeuge Testf'#228'lle'
        TabOrder = 9
        OnClick = Button2Click
      end
      object ListView3: TListView
        Left = 519
        Top = 42
        Width = 631
        Height = 179
        Anchors = [akLeft, akTop, akRight]
        Columns = <>
        TabOrder = 10
      end
      object Button3: TButton
        Left = 1058
        Top = 184
        Width = 75
        Height = 25
        Anchors = [akTop, akRight]
        Caption = 'Upload'
        TabOrder = 11
        OnClick = Button3Click
      end
    end
  end
end
