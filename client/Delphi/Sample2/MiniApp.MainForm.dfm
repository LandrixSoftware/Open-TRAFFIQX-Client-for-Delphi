object MiniAppMainForm: TMiniAppMainForm
  Left = 0
  Top = 0
  Caption = 'TIA Mini-Anwendung – DATEV-Verbindung und Rechnungen (S1–S5)'
  ClientHeight = 820
  ClientWidth = 1040
  Constraints.MinHeight = 600
  Constraints.MinWidth = 720
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  Scaled = True
  PixelsPerInch = 96
  OnCreate = FormCreate
  OnCloseQuery = FormCloseQuery
  TextHeight = 15
  object Pages: TPageControl
    Align = alClient
    ActivePage = MasterDataTab
    TabOrder = 0
    object ConnectionTab: TTabSheet
      Caption = 'Verbindung'
      object ConnectionScroll: TScrollBox
        Align = alClient
        BorderStyle = bsNone
        HorzScrollBar.Visible = False
        object ConnectionHint: TLabel
          Align = alTop
          Top = 0
          AutoSize = False
          Height = 44
          Caption = 'Provider: DATEV E-Rechnungsplattform. Vor dem Umgebungswechsel die bestehende Verbindung trennen.'
          WordWrap = True
          Layout = tlCenter
        end
        object ConnectionEnvironmentPanel: TPanel
          Align = alTop
          Top = 44
          Height = 44
          BevelOuter = bvNone
          object ConnectionEnvironmentLabel: TLabel
            Left = 8
            Top = 12
            Caption = 'Umgebung'
          end
          object ConnectionEnvironmentCombo: TComboBox
            Left = 150
            Top = 8
            Width = 220
            Style = csDropDownList
            Items.Strings = (
              'Sandbox'
              'Produktion')
            OnChange = EnvironmentChanged
          end
        end
        object ConnectionIdentity: TLabel
          Align = alTop
          Top = 88
          AutoSize = False
          Height = 32
          Caption = 'TRAFFIQX-ID:'
          WordWrap = True
          Layout = tlCenter
        end
        object ConnectionConfigHint: TLabel
          Align = alTop
          Top = 120
          AutoSize = False
          Height = 60
          Caption = 'Pflege der Client-Daten in .env (neben der EXE, sonst Repo-Wurzel): PROVIDER_TPDATEV_TRAFFIQX_ID. Danach neu starten. Umgebung wird in den Stammdaten gespeichert.'
          WordWrap = True
          Layout = tlCenter
        end
        object ConnectionStatusPanel: TPanel
          Align = alTop
          Top = 180
          Height = 44
          BevelOuter = bvNone
          object ConnectionLamp: TShape
            Left = 8
            Top = 10
            Width = 24
            Height = 24
            Shape = stCircle
            Brush.Color = clRed
          end
          object ConnectionStatus: TLabel
            AlignWithMargins = True
            Margins.Left = 44
            Align = alClient
            AutoSize = False
            Caption = 'Nicht verbunden'
            WordWrap = True
            Layout = tlCenter
          end
        end
        object ConnectionExpiry: TLabel
          Align = alTop
          Top = 224
          AutoSize = False
          Height = 32
          Caption = 'Refresh-Token gültig bis: –'
          WordWrap = True
          Layout = tlCenter
        end
        object ConnectionUser: TLabel
          Align = alTop
          Top = 256
          AutoSize = False
          Height = 44
          Caption = 'Person: noch nicht verfügbar'
          WordWrap = True
          Layout = tlCenter
        end
        object ConnectionButtons: TFlowPanel
          Align = alTop
          Top = 300
          Height = 88
          BevelOuter = bvNone
          object ConnectButton: TButton
            AlignWithMargins = True
            Width = 190
            Height = 32
            Caption = 'Mit DATEV verbinden'
            OnClick = ConnectClick
          end
          object CancelConnectButton: TButton
            AlignWithMargins = True
            Width = 190
            Height = 32
            Caption = 'Abbrechen'
            OnClick = CancelConnectClick
          end
          object CheckConnectionButton: TButton
            AlignWithMargins = True
            Width = 190
            Height = 32
            Caption = 'Verbindung prüfen'
            OnClick = CheckConnectionClick
          end
          object DisconnectButton: TButton
            AlignWithMargins = True
            Width = 190
            Height = 32
            Caption = 'Verbindung trennen'
            OnClick = DisconnectClick
          end
        end
        object ConnectedAppsLink: TLinkLabel
          Align = alTop
          Top = 388
          AutoSize = False
          Height = 32
          Caption = '<a href="apps">Verbundene Anwendungen</a> (DATEV)'
          OnLinkClick = ConnectionLinkClick
        end
        object ConnectionHelpLink: TLinkLabel
          Align = alTop
          Top = 420
          AutoSize = False
          Height = 32
          Caption = '<a href="help">Hilfe zum letzten API-Fehler öffnen</a> – Details im Protokoll'
          ShowHint = True
          Visible = False
          OnLinkClick = ConnectionLinkClick
        end
      end
    end
    object MasterDataTab: TTabSheet
      Caption = 'Stammdaten'
      object SavePanel: TPanel
        Width = 1032
        Align = alBottom
        Height = 48
        BevelOuter = bvNone
        object SaveButton: TButton
          Left = 8
          Top = 8
          Width = 120
          Height = 28
          Caption = 'Speichern'
          OnClick = SaveClick
        end
        object SaveState: TLabel
          Left = 144
          Top = 14
          Width = 850
          Height = 24
          Anchors = [akLeft, akTop, akRight]
          AutoSize = False
          Caption = 'Stammdaten'
          ShowHint = True
        end
      end
      object MasterPages: TPageControl
        Align = alClient
        ActivePage = SellerTab
        object SellerTab: TTabSheet
          Caption = 'Rechnungssteller'
          object SellerScroll: TScrollBox
            Align = alClient
            BorderStyle = bsNone
            HorzScrollBar.Visible = False
            object SettingsPanel: TPanel
              Align = alTop
              Top = 420
              Height = 124
              BevelOuter = bvNone
              object ExampleHint: TLabel
                Align = alTop
                AutoSize = False
                Height = 36
                Top = 0
                Caption = 'Fiktive Testdaten mit ungültigen Steuer- und Bankkennungen. Nicht für echten Versand verwenden.'
                WordWrap = True
                Layout = tlCenter
              end
              object EnvironmentLabel: TLabel
                Left = 8
                Top = 48
                Caption = 'Umgebung'
              end
              object EnvironmentCombo: TComboBox
                Left = 150
                Top = 44
                Width = 220
                Style = csDropDownList
                Items.Strings = (
                  'Sandbox'
                  'Produktion')
                OnChange = EnvironmentChanged
              end
              object InvoiceNumberLabel: TLabel
                Left = 8
                Top = 88
                Caption = 'Nächste Rechnungsnummer: TEST-0001'
              end
            end
            object SellerGrid: TGridPanel
              Align = alTop
              Height = 406
              BevelOuter = bvNone
              ColumnCollection = <
                item
                  Value = 50.000000000000000000
                end
                item
                  Value = 50.000000000000000000
                end>
              ControlCollection = <
                item
                  Column = 0
                  Control = SellerNamePanel
                  Row = 0
                end
                item
                  Column = 1
                  Control = SellerStreetPanel
                  Row = 0
                end
                item
                  Column = 0
                  Control = SellerPostalCodePanel
                  Row = 1
                end
                item
                  Column = 1
                  Control = SellerCityPanel
                  Row = 1
                end
                item
                  Column = 0
                  Control = SellerCountryCodePanel
                  Row = 2
                end
                item
                  Column = 1
                  Control = SellerVatIDPanel
                  Row = 2
                end
                item
                  Column = 0
                  Control = SellerTaxNumberPanel
                  Row = 3
                end
                item
                  Column = 1
                  Control = SellerContactNamePanel
                  Row = 3
                end
                item
                  Column = 0
                  Control = SellerPhonePanel
                  Row = 4
                end
                item
                  Column = 1
                  Control = SellerEmailPanel
                  Row = 4
                end
                item
                  Column = 0
                  Control = SellerElectronicAddressPanel
                  Row = 5
                end
                item
                  Column = 1
                  Control = SellerIBANPanel
                  Row = 5
                end
                item
                  Column = 0
                  Control = SellerBICPanel
                  Row = 6
                end
                item
                  Column = 1
                  Control = SellerBankNamePanel
                  Row = 6
                end>
              RowCollection = <
                item
                  Value = 14.2857142857142865
                end
                item
                  Value = 14.2857142857142865
                end
                item
                  Value = 14.2857142857142865
                end
                item
                  Value = 14.2857142857142865
                end
                item
                  Value = 14.2857142857142865
                end
                item
                  Value = 14.2857142857142865
                end
                item
                  Value = 14.2857142857142865
                end>
              object SellerNamePanel: TPanel
                Align = alClient
                BevelOuter = bvNone
                Padding.Left = 8
                Padding.Right = 8
                Padding.Bottom = 4
                object SellerName: TLabeledEdit
                  Align = alBottom
                  Height = 25
                  EditLabel.Caption = 'Name'
                  TabOrder = 0
                  OnChange = SellerChanged
                end
              end
              object SellerStreetPanel: TPanel
                Align = alClient
                BevelOuter = bvNone
                Padding.Left = 8
                Padding.Right = 8
                Padding.Bottom = 4
                object SellerStreet: TLabeledEdit
                  Align = alBottom
                  Height = 25
                  EditLabel.Caption = 'Straße'
                  TabOrder = 0
                  OnChange = SellerChanged
                end
              end
              object SellerPostalCodePanel: TPanel
                Align = alClient
                BevelOuter = bvNone
                Padding.Left = 8
                Padding.Right = 8
                Padding.Bottom = 4
                object SellerPostalCode: TLabeledEdit
                  Align = alBottom
                  Height = 25
                  EditLabel.Caption = 'PLZ'
                  TabOrder = 0
                  OnChange = SellerChanged
                end
              end
              object SellerCityPanel: TPanel
                Align = alClient
                BevelOuter = bvNone
                Padding.Left = 8
                Padding.Right = 8
                Padding.Bottom = 4
                object SellerCity: TLabeledEdit
                  Align = alBottom
                  Height = 25
                  EditLabel.Caption = 'Ort'
                  TabOrder = 0
                  OnChange = SellerChanged
                end
              end
              object SellerCountryCodePanel: TPanel
                Align = alClient
                BevelOuter = bvNone
                Padding.Left = 8
                Padding.Right = 8
                Padding.Bottom = 4
                object SellerCountryCode: TLabeledEdit
                  Align = alBottom
                  Height = 25
                  EditLabel.Caption = 'Land (ISO, z. B. DE)'
                  TabOrder = 0
                  OnChange = SellerChanged
                end
              end
              object SellerVatIDPanel: TPanel
                Align = alClient
                BevelOuter = bvNone
                Padding.Left = 8
                Padding.Right = 8
                Padding.Bottom = 4
                object SellerVatID: TLabeledEdit
                  Align = alBottom
                  Height = 25
                  EditLabel.Caption = 'USt-IdNr.'
                  TabOrder = 0
                  OnChange = SellerChanged
                end
              end
              object SellerTaxNumberPanel: TPanel
                Align = alClient
                BevelOuter = bvNone
                Padding.Left = 8
                Padding.Right = 8
                Padding.Bottom = 4
                object SellerTaxNumber: TLabeledEdit
                  Align = alBottom
                  Height = 25
                  EditLabel.Caption = 'Steuernummer'
                  TabOrder = 0
                  OnChange = SellerChanged
                end
              end
              object SellerContactNamePanel: TPanel
                Align = alClient
                BevelOuter = bvNone
                Padding.Left = 8
                Padding.Right = 8
                Padding.Bottom = 4
                object SellerContactName: TLabeledEdit
                  Align = alBottom
                  Height = 25
                  EditLabel.Caption = 'Kontaktname'
                  TabOrder = 0
                  OnChange = SellerChanged
                end
              end
              object SellerPhonePanel: TPanel
                Align = alClient
                BevelOuter = bvNone
                Padding.Left = 8
                Padding.Right = 8
                Padding.Bottom = 4
                object SellerPhone: TLabeledEdit
                  Align = alBottom
                  Height = 25
                  EditLabel.Caption = 'Telefon'
                  TabOrder = 0
                  OnChange = SellerChanged
                end
              end
              object SellerEmailPanel: TPanel
                Align = alClient
                BevelOuter = bvNone
                Padding.Left = 8
                Padding.Right = 8
                Padding.Bottom = 4
                object SellerEmail: TLabeledEdit
                  Align = alBottom
                  Height = 25
                  EditLabel.Caption = 'E-Mail'
                  TabOrder = 0
                  OnChange = SellerChanged
                end
              end
              object SellerElectronicAddressPanel: TPanel
                Align = alClient
                BevelOuter = bvNone
                Padding.Left = 8
                Padding.Right = 8
                Padding.Bottom = 4
                object SellerElectronicAddress: TLabeledEdit
                  Align = alBottom
                  Height = 25
                  EditLabel.Caption = 'Elektronische Adresse (BT-34, E-Mail)'
                  TabOrder = 0
                  OnChange = SellerChanged
                end
              end
              object SellerIBANPanel: TPanel
                Align = alClient
                BevelOuter = bvNone
                Padding.Left = 8
                Padding.Right = 8
                Padding.Bottom = 4
                object SellerIBAN: TLabeledEdit
                  Align = alBottom
                  Height = 25
                  EditLabel.Caption = 'IBAN'
                  TabOrder = 0
                  OnChange = SellerChanged
                end
              end
              object SellerBICPanel: TPanel
                Align = alClient
                BevelOuter = bvNone
                Padding.Left = 8
                Padding.Right = 8
                Padding.Bottom = 4
                object SellerBIC: TLabeledEdit
                  Align = alBottom
                  Height = 25
                  EditLabel.Caption = 'BIC'
                  TabOrder = 0
                  OnChange = SellerChanged
                end
              end
              object SellerBankNamePanel: TPanel
                Align = alClient
                BevelOuter = bvNone
                Padding.Left = 8
                Padding.Right = 8
                Padding.Bottom = 4
                object SellerBankName: TLabeledEdit
                  Align = alBottom
                  Height = 25
                  EditLabel.Caption = 'Bankname'
                  TabOrder = 0
                  OnChange = SellerChanged
                end
              end
            end
          end
        end
        object CustomerTab: TTabSheet
          Caption = 'Kunden'
          object CustomerScroll: TScrollBox
            Align = alClient
            BorderStyle = bsNone
            HorzScrollBar.Visible = False
            object CustomerEditor: TPanel
              Align = alTop
              Top = 180
              Height = 454
              BevelOuter = bvNone
              object CustomerButtons: TPanel
                Align = alBottom
                Height = 48
                BevelOuter = bvNone
                object CustomerNewButton: TButton
                  Left = 8
                  Top = 8
                  Width = 120
                  Height = 28
                  Caption = 'Neu'
                  OnClick = CustomerNewClick
                end
                object CustomerDeleteButton: TButton
                  Left = 136
                  Top = 8
                  Width = 120
                  Height = 28
                  Caption = 'Löschen'
                  OnClick = CustomerDeleteClick
                end
                object CustomerApplyButton: TButton
                  Left = 264
                  Top = 8
                  Width = 120
                  Height = 28
                  Caption = 'Übernehmen'
                  OnClick = CustomerApplyClick
                end
              end
              object CustomerGrid: TGridPanel
                Align = alTop
                Height = 406
                BevelOuter = bvNone
                ColumnCollection = <
                  item
                    Value = 50.000000000000000000
                  end
                  item
                    Value = 50.000000000000000000
                  end>
                ControlCollection = <
                  item
                    Column = 0
                    Control = CustomerCustomerNumberPanel
                    Row = 0
                  end
                  item
                    Column = 1
                    Control = CustomerNamePanel
                    Row = 0
                  end
                  item
                    Column = 0
                    Control = CustomerStreetPanel
                    Row = 1
                  end
                  item
                    Column = 1
                    Control = CustomerPostalCodePanel
                    Row = 1
                  end
                  item
                    Column = 0
                    Control = CustomerCityPanel
                    Row = 2
                  end
                  item
                    Column = 1
                    Control = CustomerCountryCodePanel
                    Row = 2
                  end
                  item
                    Column = 0
                    Control = CustomerVatIDPanel
                    Row = 3
                  end
                  item
                    Column = 1
                    Control = CustomerDeliveryChannelPanel
                    Row = 3
                  end
                  item
                    Column = 0
                    Control = CustomerBuyerReferencePanel
                    Row = 4
                  end
                  item
                    Column = 1
                    Control = CustomerElectronicAddressPanel
                    Row = 4
                  end
                  item
                    Column = 0
                    Control = CustomerElectronicAddressSchemePanel
                    Row = 5
                  end
                  item
                    Column = 1
                    Control = CustomerContactEmailPanel
                    Row = 5
                  end
                  item
                    Column = 0
                    Control = CustomerTraffiqxIDPanel
                    Row = 6
                  end>
                RowCollection = <
                  item
                    Value = 14.2857142857142865
                  end
                  item
                    Value = 14.2857142857142865
                  end
                  item
                    Value = 14.2857142857142865
                  end
                  item
                    Value = 14.2857142857142865
                  end
                  item
                    Value = 14.2857142857142865
                  end
                  item
                    Value = 14.2857142857142865
                  end
                  item
                    Value = 14.2857142857142865
                  end>
                object CustomerCustomerNumberPanel: TPanel
                  Align = alClient
                  BevelOuter = bvNone
                  Padding.Left = 8
                  Padding.Right = 8
                  Padding.Bottom = 4
                  object CustomerCustomerNumber: TLabeledEdit
                    Align = alBottom
                    Height = 25
                    EditLabel.Caption = 'Kundennummer'
                    TabOrder = 0
                    OnChange = CustomerChanged
                  end
                end
                object CustomerNamePanel: TPanel
                  Align = alClient
                  BevelOuter = bvNone
                  Padding.Left = 8
                  Padding.Right = 8
                  Padding.Bottom = 4
                  object CustomerName: TLabeledEdit
                    Align = alBottom
                    Height = 25
                    EditLabel.Caption = 'Name'
                    TabOrder = 0
                    OnChange = CustomerChanged
                  end
                end
                object CustomerStreetPanel: TPanel
                  Align = alClient
                  BevelOuter = bvNone
                  Padding.Left = 8
                  Padding.Right = 8
                  Padding.Bottom = 4
                  object CustomerStreet: TLabeledEdit
                    Align = alBottom
                    Height = 25
                    EditLabel.Caption = 'Straße'
                    TabOrder = 0
                    OnChange = CustomerChanged
                  end
                end
                object CustomerPostalCodePanel: TPanel
                  Align = alClient
                  BevelOuter = bvNone
                  Padding.Left = 8
                  Padding.Right = 8
                  Padding.Bottom = 4
                  object CustomerPostalCode: TLabeledEdit
                    Align = alBottom
                    Height = 25
                    EditLabel.Caption = 'PLZ'
                    TabOrder = 0
                    OnChange = CustomerChanged
                  end
                end
                object CustomerCityPanel: TPanel
                  Align = alClient
                  BevelOuter = bvNone
                  Padding.Left = 8
                  Padding.Right = 8
                  Padding.Bottom = 4
                  object CustomerCity: TLabeledEdit
                    Align = alBottom
                    Height = 25
                    EditLabel.Caption = 'Ort'
                    TabOrder = 0
                    OnChange = CustomerChanged
                  end
                end
                object CustomerCountryCodePanel: TPanel
                  Align = alClient
                  BevelOuter = bvNone
                  Padding.Left = 8
                  Padding.Right = 8
                  Padding.Bottom = 4
                  object CustomerCountryCode: TLabeledEdit
                    Align = alBottom
                    Height = 25
                    EditLabel.Caption = 'Land (ISO, z. B. DE)'
                    TabOrder = 0
                    OnChange = CustomerChanged
                  end
                end
                object CustomerVatIDPanel: TPanel
                  Align = alClient
                  BevelOuter = bvNone
                  Padding.Left = 8
                  Padding.Right = 8
                  Padding.Bottom = 4
                  object CustomerVatID: TLabeledEdit
                    Align = alBottom
                    Height = 25
                    EditLabel.Caption = 'USt-IdNr. (optional)'
                    TabOrder = 0
                    OnChange = CustomerChanged
                  end
                end
                object CustomerDeliveryChannelPanel: TPanel
                  Align = alClient
                  BevelOuter = bvNone
                  Padding.Left = 8
                  Padding.Right = 8
                  Padding.Bottom = 4
                  object DeliveryChannelLabel: TLabel
                    Align = alTop
                    Top = 8
                    Caption = 'Versandweg'
                  end
                  object CustomerDeliveryChannel: TComboBox
                    Align = alBottom
                    Style = csDropDownList
                    Items.Strings = (
                      'email'
                      'leitwegid'
                      'traffiqx'
                      'peppol')
                    OnChange = CustomerChanged
                  end
                end
                object CustomerBuyerReferencePanel: TPanel
                  Align = alClient
                  BevelOuter = bvNone
                  Padding.Left = 8
                  Padding.Right = 8
                  Padding.Bottom = 4
                  object CustomerBuyerReference: TLabeledEdit
                    Align = alBottom
                    Height = 25
                    EditLabel.Caption = 'Leitweg-ID (BT-10)'
                    TabOrder = 0
                    OnChange = CustomerChanged
                  end
                end
                object CustomerElectronicAddressPanel: TPanel
                  Align = alClient
                  BevelOuter = bvNone
                  Padding.Left = 8
                  Padding.Right = 8
                  Padding.Bottom = 4
                  object CustomerElectronicAddress: TLabeledEdit
                    Align = alBottom
                    Height = 25
                    EditLabel.Caption = 'Elektronische Adresse (BT-49)'
                    TabOrder = 0
                    OnChange = CustomerChanged
                  end
                end
                object CustomerElectronicAddressSchemePanel: TPanel
                  Align = alClient
                  BevelOuter = bvNone
                  Padding.Left = 8
                  Padding.Right = 8
                  Padding.Bottom = 4
                  object CustomerElectronicAddressScheme: TLabeledEdit
                    Align = alBottom
                    Height = 25
                    EditLabel.Caption = 'Schema (z. B. EM, 0204)'
                    TabOrder = 0
                    OnChange = CustomerChanged
                  end
                end
                object CustomerContactEmailPanel: TPanel
                  Align = alClient
                  BevelOuter = bvNone
                  Padding.Left = 8
                  Padding.Right = 8
                  Padding.Bottom = 4
                  object CustomerContactEmail: TLabeledEdit
                    Align = alBottom
                    Height = 25
                    EditLabel.Caption = 'Kontakt-E-Mail'
                    TabOrder = 0
                    OnChange = CustomerChanged
                  end
                end
                object CustomerTraffiqxIDPanel: TPanel
                  Align = alClient
                  BevelOuter = bvNone
                  Padding.Left = 8
                  Padding.Right = 8
                  Padding.Bottom = 4
                  object CustomerTraffiqxID: TLabeledEdit
                    Align = alBottom
                    Height = 25
                    EditLabel.Caption = 'TRAFFIQX-ID'
                    TabOrder = 0
                    OnChange = CustomerChanged
                  end
                end
              end
            end
            object CustomerList: TListView
              Align = alTop
              Top = 0
              Height = 180
              HideSelection = False
              ReadOnly = True
              RowSelect = True
              ViewStyle = vsReport
              OnSelectItem = CustomerSelected
              Columns = <
              item
                Caption = 'Nummer'
                Width = 100
              end
              item
                Caption = 'Name'
                Width = 280
              end
              item
                Caption = 'Versandweg'
                Width = 140
              end>
            end
          end
        end
        object PositionTab: TTabSheet
          Caption = 'Testpositionen'
          object PositionScroll: TScrollBox
            Align = alClient
            BorderStyle = bsNone
            HorzScrollBar.Visible = False
            object PositionEditor: TPanel
              Align = alTop
              Top = 180
              Height = 222
              BevelOuter = bvNone
              object PositionButtons: TPanel
                Align = alBottom
                Height = 48
                BevelOuter = bvNone
                object PositionNewButton: TButton
                  Left = 8
                  Top = 8
                  Width = 120
                  Height = 28
                  Caption = 'Neu'
                  OnClick = PositionNewClick
                end
                object PositionDeleteButton: TButton
                  Left = 136
                  Top = 8
                  Width = 120
                  Height = 28
                  Caption = 'Löschen'
                  OnClick = PositionDeleteClick
                end
                object PositionApplyButton: TButton
                  Left = 264
                  Top = 8
                  Width = 120
                  Height = 28
                  Caption = 'Übernehmen'
                  OnClick = PositionApplyClick
                end
              end
              object PositionGrid: TGridPanel
                Align = alTop
                Height = 174
                BevelOuter = bvNone
                ColumnCollection = <
                  item
                    Value = 50.000000000000000000
                  end
                  item
                    Value = 50.000000000000000000
                  end>
                ControlCollection = <
                  item
                    Column = 0
                    Control = PositionDescriptionPanel
                    Row = 0
                  end
                  item
                    Column = 1
                    Control = PositionQuantityPanel
                    Row = 0
                  end
                  item
                    Column = 0
                    Control = PositionUnitCodePanel
                    Row = 1
                  end
                  item
                    Column = 1
                    Control = PositionNetUnitPricePanel
                    Row = 1
                  end
                  item
                    Column = 0
                    Control = PositionVatRatePanel
                    Row = 2
                  end>
                RowCollection = <
                  item
                    Value = 33.3333333333333357
                  end
                  item
                    Value = 33.3333333333333357
                  end
                  item
                    Value = 33.3333333333333357
                  end>
                object PositionDescriptionPanel: TPanel
                  Align = alClient
                  BevelOuter = bvNone
                  Padding.Left = 8
                  Padding.Right = 8
                  Padding.Bottom = 4
                  object PositionDescription: TLabeledEdit
                    Align = alBottom
                    Height = 25
                    EditLabel.Caption = 'Positionstext'
                    TabOrder = 0
                    OnChange = PositionChanged
                  end
                end
                object PositionQuantityPanel: TPanel
                  Align = alClient
                  BevelOuter = bvNone
                  Padding.Left = 8
                  Padding.Right = 8
                  Padding.Bottom = 4
                  object PositionQuantity: TLabeledEdit
                    Align = alBottom
                    Height = 25
                    EditLabel.Caption = 'Menge'
                    TabOrder = 0
                    OnChange = PositionChanged
                  end
                end
                object PositionUnitCodePanel: TPanel
                  Align = alClient
                  BevelOuter = bvNone
                  Padding.Left = 8
                  Padding.Right = 8
                  Padding.Bottom = 4
                  object PositionUnitCode: TLabeledEdit
                    Align = alBottom
                    Height = 25
                    EditLabel.Caption = 'Einheit UN/ECE (H87 / HUR)'
                    TabOrder = 0
                    OnChange = PositionChanged
                  end
                end
                object PositionNetUnitPricePanel: TPanel
                  Align = alClient
                  BevelOuter = bvNone
                  Padding.Left = 8
                  Padding.Right = 8
                  Padding.Bottom = 4
                  object PositionNetUnitPrice: TLabeledEdit
                    Align = alBottom
                    Height = 25
                    EditLabel.Caption = 'Netto-Einzelpreis (EUR)'
                    TabOrder = 0
                    OnChange = PositionChanged
                  end
                end
                object PositionVatRatePanel: TPanel
                  Align = alClient
                  BevelOuter = bvNone
                  Padding.Left = 8
                  Padding.Right = 8
                  Padding.Bottom = 4
                  object PositionVatRate: TLabeledEdit
                    Align = alBottom
                    Height = 25
                    EditLabel.Caption = 'USt.-Satz (%)'
                    TabOrder = 0
                    OnChange = PositionChanged
                  end
                end
              end
            end
            object PositionList: TListView
              Align = alTop
              Top = 0
              Height = 180
              HideSelection = False
              ReadOnly = True
              RowSelect = True
              ViewStyle = vsReport
              OnSelectItem = PositionSelected
              Columns = <
              item
                Caption = 'Text'
                Width = 320
              end
              item
                Caption = 'Menge'
                Width = 100
              end
              item
                Caption = 'Einheit'
                Width = 90
              end
              item
                Caption = 'Netto (EUR)'
                Width = 120
              end
              item
                Caption = 'USt. (%)'
                Width = 100
              end>
            end
          end
        end
      end
    end
    object OutgoingTab: TTabSheet
      Caption = 'Ausgang'
      OnShow = OutgoingShow
      object OutgoingHint: TLabel
        Align = alTop
        AutoSize = False
        Height = 36
        Top = 0
        Caption = 'GoBD-konforme Archivierung: Das Original liegt im Rechnungsordner. Die DATEV E-Rechnungsplattform archiviert nicht.'
        WordWrap = True
        Layout = tlCenter
      end
      object OutgoingConnectionHint: TLabel
        Align = alTop
        Top = 36
        AutoSize = False
        Height = 36
        Caption = 'Ohne geprüfte DATEV-Verbindung sind die Versandfunktionen gesperrt.'
        WordWrap = True
        Layout = tlCenter
      end
      object OutgoingCustomerPanel: TPanel
        Align = alTop
        Top = 72
        Height = 40
        BevelOuter = bvNone
        TabOrder = 0
        object OutgoingCustomerLabel: TLabel
          Align = alLeft
          AutoSize = False
          Width = 72
          Caption = 'Kunde:'
          Layout = tlCenter
          FocusControl = OutgoingCustomerCombo
        end
        object OutgoingCustomerCombo: TComboBox
          Align = alClient
          AlignWithMargins = True
          Style = csDropDownList
          TabOrder = 0
        end
      end
      object OutgoingButtons: TFlowPanel
        Align = alTop
        Top = 112
        Height = 112
        AutoWrap = True
        BevelOuter = bvNone
        TabOrder = 1
        object NewInvoiceButton: TButton
          AlignWithMargins = True
          Width = 170
          Height = 30
          Caption = 'Neue Testrechnung'
          TabOrder = 0
          OnClick = NewInvoiceClick
        end
        object ShowXmlButton: TButton
          AlignWithMargins = True
          Width = 115
          Height = 30
          Caption = 'XML anzeigen'
          TabOrder = 1
          OnClick = ShowXmlClick
        end
        object OpenFolderButton: TButton
          AlignWithMargins = True
          Width = 120
          Height = 30
          Caption = 'Ordner öffnen'
          TabOrder = 2
          OnClick = OpenFolderClick
        end
        object ValidateInvoiceButton: TButton
          AlignWithMargins = True
          Width = 145
          Height = 30
          Caption = 'Prüfen (KoSIT)'
          Enabled = False
          TabOrder = 3
          OnClick = ValidateInvoiceClick
        end
        object RefreshOutgoingButton: TButton
          AlignWithMargins = True
          Width = 120
          Height = 30
          Caption = 'Aktualisieren'
          TabOrder = 4
          OnClick = OutgoingShow
        end
        object SendInvoiceButton: TButton
          AlignWithMargins = True
          Width = 115
          Height = 30
          Caption = 'Senden'
          Enabled = False
          TabOrder = 5
          OnClick = SendInvoiceClick
        end
        object QueryStatusButton: TButton
          AlignWithMargins = True
          Width = 140
          Height = 30
          Caption = 'Status abfragen'
          Enabled = False
          TabOrder = 6
          OnClick = QueryStatusClick
        end
        object ShowOriginalButton: TButton
          AlignWithMargins = True
          Width = 145
          Height = 30
          Caption = 'Original anzeigen'
          Enabled = False
          TabOrder = 7
          OnClick = ShowOriginalClick
        end
      end
      object OutgoingDetails: TMemo
        Align = alBottom
        Top = 600
        Height = 160
        ReadOnly = True
        ScrollBars = ssBoth
        WordWrap = False
        TabOrder = 3
      end
      object OutgoingSplitter: TSplitter
        Align = alBottom
        Top = 595
        Height = 5
        MinSize = 60
      end
      object OutgoingList: TListView
        Align = alClient
        TabOrder = 2
        ReadOnly = True
        RowSelect = True
        HideSelection = False
        ViewStyle = vsReport
        OnSelectItem = OutgoingSelected
        Columns = <
          item
            Caption = 'Nummer'
            Width = 110
          end
          item
            Caption = 'Kunde'
            Width = 220
          end
          item
            Caption = 'Datum'
            Width = 100
          end
          item
            Caption = 'Brutto'
            Width = 110
          end
          item
            Caption = 'Kanal soll'
            Width = 110
          end
          item
            Caption = 'document_id'
            Width = 180
          end
          item
            Caption = 'Status'
            Width = 125
          end
          item
            Caption = 'Kanal ist'
            Width = 160
          end>
      end
    end
    object IncomingTab: TTabSheet
      Caption = 'Eingang'
      OnShow = IncomingShow
      object IncomingHint: TLabel
        Align = alTop
        AutoSize = False
        Height = 56
        Top = 0
        Caption = 'Die Eingangsrechnungen liegen im Ordner Daten\eingang; die DATEV E-Rechnungsplattform archiviert nicht GoBD-konform.'
        WordWrap = True
        Layout = tlCenter
      end
      object IncomingResult: TLabel
        Align = alTop
        AutoSize = False
        Height = 64
        Top = 56
        Caption = 'Zuerst DATEV-Verbindung prüfen und einmal „Alle abgleichen“ wählen. Danach den Posteingang bei Bedarf abrufen. Ungeprüfte Dokumente: Metadaten nachholen.'
        WordWrap = True
        Layout = tlCenter
      end
      object IncomingButtons: TFlowPanel
        Align = alTop
        Top = 120
        Height = 90
        BevelOuter = bvNone
        TabOrder = 0
        object FetchInboxButton: TButton
          Width = 175
          Height = 32
          Caption = 'Posteingang abrufen'
          TabOrder = 0
          OnClick = FetchInboxClick
        end
        object SyncInboxButton: TButton
          Width = 140
          Height = 32
          Caption = 'Alle abgleichen'
          TabOrder = 1
          OnClick = FetchInboxClick
        end
        object ShowInboxButton: TButton
          Width = 165
          Height = 32
          Caption = 'Dokument anzeigen'
          TabOrder = 2
          OnClick = ShowInboxClick
        end
        object OpenInboxFolderButton: TButton
          Width = 135
          Height = 32
          Caption = 'Ordner öffnen'
          TabOrder = 3
          OnClick = OpenInboxFolderClick
        end
        object InboxMetadataButton: TButton
          Width = 180
          Height = 32
          Caption = 'Metadaten nachholen'
          TabOrder = 4
          OnClick = InboxMetadataClick
        end
      end
      object IncomingList: TListView
        Align = alClient
        Top = 210
        TabOrder = 1
        ReadOnly = True
        RowSelect = True
        HideSelection = False
        ViewStyle = vsReport
        OnSelectItem = IncomingSelected
        OnCustomDrawItem = IncomingDrawItem
        Columns = <
          item
            Caption = 'document_id'
            Width = 285
          end
          item
            Caption = 'Absender'
            Width = 170
          end
          item
            Caption = 'Eingang'
            Width = 180
          end
          item
            Caption = 'Format'
            Width = 150
          end
          item
            Caption = 'EN-16931 gültig'
            Width = 125
          end
          item
            Caption = 'Ablage'
            Width = 110
          end>
      end
    end
    object ProtocolTab: TTabSheet
      Caption = 'Protokoll'
      object ProtocolHint: TLabel
        Align = alTop
        AutoSize = False
        Height = 36
        Top = 0
        Caption = 'Service-Meldungen; HTTP-Protokoll in Daten\httplog (14 Tage). Fehlerquote folgt in S7.'
        WordWrap = True
        Layout = tlCenter
      end
      object ProtocolHelpLink: TLinkLabel
        Align = alTop
        Top = 36
        AutoSize = False
        Height = 32
        Caption = '<a href="help">Hilfe zum letzten API-Fehler öffnen</a>'
        ShowHint = True
        Visible = False
        OnLinkClick = ConnectionLinkClick
      end
      object ProtocolMemo: TMemo
        Align = alClient
        ReadOnly = True
        ScrollBars = ssBoth
        WordWrap = False
      end
    end
  end
  object ConnectionTimer: TTimer
    Interval = 1000
    OnTimer = ConnectionTimerTick
    Left = 960
    Top = 8
  end
end
