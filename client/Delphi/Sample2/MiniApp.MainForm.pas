{
License Open-TRAFFIQX-Client-for-Delphi

Copyright (C) 2026 Landrix Software GmbH & Co. KG
Sven Harazim, info@landrix.de
Version 0.1

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <https://www.gnu.org/licenses/>.
}

unit MiniApp.MainForm;

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls,
  Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Mask, MiniApp.Model, MiniApp.Storage, MiniApp.Service;

type
  TMiniAppMainForm = class(TForm)
    Pages: TPageControl;
    ConnectionTab: TTabSheet;
    ConnectionHint: TLabel;
    ConnectionScroll: TScrollBox;
    ConnectionEnvironmentPanel: TPanel;
    ConnectionEnvironmentLabel: TLabel;
    ConnectionEnvironmentCombo: TComboBox;
    ConnectionIdentity: TLabel;
    ConnectionConfigHint: TLabel;
    ConnectionStatusPanel: TPanel;
    ConnectionLamp: TShape;
    ConnectionStatus: TLabel;
    ConnectionExpiry: TLabel;
    ConnectionUser: TLabel;
    ConnectionButtons: TFlowPanel;
    ConnectButton: TButton;
    CancelConnectButton: TButton;
    CheckConnectionButton: TButton;
    DisconnectButton: TButton;
    ConnectedAppsLink: TLinkLabel;
    ConnectionHelpLink: TLinkLabel;
    ConnectionTimer: TTimer;
    MasterDataTab: TTabSheet;
    SavePanel: TPanel;
    SaveButton: TButton;
    SaveState: TLabel;
    MasterPages: TPageControl;
    SellerTab: TTabSheet;
    SellerScroll: TScrollBox;
    SettingsPanel: TPanel;
    ExampleHint: TLabel;
    EnvironmentLabel: TLabel;
    EnvironmentCombo: TComboBox;
    InvoiceNumberLabel: TLabel;
    SellerGrid: TGridPanel;
    SellerNamePanel: TPanel;
    SellerName: TLabeledEdit;
    SellerStreetPanel: TPanel;
    SellerStreet: TLabeledEdit;
    SellerPostalCodePanel: TPanel;
    SellerPostalCode: TLabeledEdit;
    SellerCityPanel: TPanel;
    SellerCity: TLabeledEdit;
    SellerCountryCodePanel: TPanel;
    SellerCountryCode: TLabeledEdit;
    SellerVatIDPanel: TPanel;
    SellerVatID: TLabeledEdit;
    SellerTaxNumberPanel: TPanel;
    SellerTaxNumber: TLabeledEdit;
    SellerContactNamePanel: TPanel;
    SellerContactName: TLabeledEdit;
    SellerPhonePanel: TPanel;
    SellerPhone: TLabeledEdit;
    SellerEmailPanel: TPanel;
    SellerEmail: TLabeledEdit;
    SellerElectronicAddressPanel: TPanel;
    SellerElectronicAddress: TLabeledEdit;
    SellerIBANPanel: TPanel;
    SellerIBAN: TLabeledEdit;
    SellerBICPanel: TPanel;
    SellerBIC: TLabeledEdit;
    SellerBankNamePanel: TPanel;
    SellerBankName: TLabeledEdit;
    CustomerTab: TTabSheet;
    CustomerScroll: TScrollBox;
    CustomerEditor: TPanel;
    CustomerButtons: TPanel;
    CustomerNewButton: TButton;
    CustomerDeleteButton: TButton;
    CustomerApplyButton: TButton;
    CustomerGrid: TGridPanel;
    CustomerCustomerNumberPanel: TPanel;
    CustomerCustomerNumber: TLabeledEdit;
    CustomerNamePanel: TPanel;
    CustomerName: TLabeledEdit;
    CustomerStreetPanel: TPanel;
    CustomerStreet: TLabeledEdit;
    CustomerPostalCodePanel: TPanel;
    CustomerPostalCode: TLabeledEdit;
    CustomerCityPanel: TPanel;
    CustomerCity: TLabeledEdit;
    CustomerCountryCodePanel: TPanel;
    CustomerCountryCode: TLabeledEdit;
    CustomerVatIDPanel: TPanel;
    CustomerVatID: TLabeledEdit;
    CustomerDeliveryChannelPanel: TPanel;
    DeliveryChannelLabel: TLabel;
    CustomerDeliveryChannel: TComboBox;
    CustomerBuyerReferencePanel: TPanel;
    CustomerBuyerReference: TLabeledEdit;
    CustomerElectronicAddressPanel: TPanel;
    CustomerElectronicAddress: TLabeledEdit;
    CustomerElectronicAddressSchemePanel: TPanel;
    CustomerElectronicAddressScheme: TLabeledEdit;
    CustomerContactEmailPanel: TPanel;
    CustomerContactEmail: TLabeledEdit;
    CustomerTraffiqxIDPanel: TPanel;
    CustomerTraffiqxID: TLabeledEdit;
    CustomerList: TListView;
    PositionTab: TTabSheet;
    PositionScroll: TScrollBox;
    PositionEditor: TPanel;
    PositionButtons: TPanel;
    PositionNewButton: TButton;
    PositionDeleteButton: TButton;
    PositionApplyButton: TButton;
    PositionGrid: TGridPanel;
    PositionDescriptionPanel: TPanel;
    PositionDescription: TLabeledEdit;
    PositionQuantityPanel: TPanel;
    PositionQuantity: TLabeledEdit;
    PositionUnitCodePanel: TPanel;
    PositionUnitCode: TLabeledEdit;
    PositionNetUnitPricePanel: TPanel;
    PositionNetUnitPrice: TLabeledEdit;
    PositionVatRatePanel: TPanel;
    PositionVatRate: TLabeledEdit;
    PositionList: TListView;
    OutgoingTab: TTabSheet;
    OutgoingHint: TLabel;
    OutgoingCustomerPanel: TPanel;
    OutgoingCustomerLabel: TLabel;
    OutgoingCustomerCombo: TComboBox;
    OutgoingButtons: TFlowPanel;
    NewInvoiceButton: TButton;
    ShowXmlButton: TButton;
    OpenFolderButton: TButton;
    ValidateInvoiceButton: TButton;
    RefreshOutgoingButton: TButton;
    OutgoingList: TListView;
    IncomingTab: TTabSheet;
    IncomingHint: TLabel;
    ProtocolTab: TTabSheet;
    ProtocolHint: TLabel;
    ProtocolHelpLink: TLinkLabel;
    ProtocolMemo: TMemo;
    procedure FormCreate(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure SellerChanged(Sender: TObject);
    procedure CustomerChanged(Sender: TObject);
    procedure PositionChanged(Sender: TObject);
    procedure EnvironmentChanged(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure CustomerSelected(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure PositionSelected(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure CustomerNewClick(Sender: TObject);
    procedure CustomerDeleteClick(Sender: TObject);
    procedure CustomerApplyClick(Sender: TObject);
    procedure PositionNewClick(Sender: TObject);
    procedure PositionDeleteClick(Sender: TObject);
    procedure PositionApplyClick(Sender: TObject);
    procedure OutgoingShow(Sender: TObject);
    procedure NewInvoiceClick(Sender: TObject);
    procedure ShowXmlClick(Sender: TObject);
    procedure OpenFolderClick(Sender: TObject);
    procedure ValidateInvoiceClick(Sender: TObject);
    procedure ConnectClick(Sender: TObject);
    procedure CancelConnectClick(Sender: TObject);
    procedure CheckConnectionClick(Sender: TObject);
    procedure DisconnectClick(Sender: TObject);
    procedure ConnectionLinkClick(Sender: TObject; const Link: string; LinkType: TSysLinkType);
    procedure ConnectionTimerTick(Sender: TObject);
  private
    FData: TMiniAppData;
    FClientConfig: TMiniAppClientConfig;
    FService: TMiniAppService;
    FServiceBusy: Boolean;
    FPreviousCursor: TCursor;
    FUpdating: Boolean;
    FDirty: Boolean;
    FCustomerDirty: Boolean;
    FPositionDirty: Boolean;
    FCustomerIndex: Integer;
    FPositionIndex: Integer;
    FOutgoingCustomerNumbers: TArray<string>;
    procedure MarkDirty;
    procedure ReadSeller;
    procedure ShowSeller;
    procedure ShowCustomer;
    procedure ShowPosition;
    procedure RefreshCustomers;
    procedure RefreshPositions;
    procedure ApplyCustomer;
    procedure ApplyPosition;
    function ConfirmCustomerChange: Boolean;
    function ConfirmPositionChange: Boolean;
    function SaveData: Boolean;
    procedure RefreshOutgoingCustomers;
    procedure RefreshOutgoing;
    function SelectedInvoiceNumber: string;
    procedure OpenLocalPath(const APath: string);
    procedure ValidationError(const AMessage: string);
    procedure UpdateConnection;
    function ConfirmLoginUnconfirmed: Boolean;
  public
    destructor Destroy; override;
    // S3: ausschließlich Hauptthread, auch die Service-Abschlussmeldung.
    procedure Log(const AText: string; AKind: TMiniAppLogKind = lkInfo);
  end;

var
  MiniAppMainForm: TMiniAppMainForm;

implementation

uses
  Vcl.Dialogs, Vcl.Graphics, System.UITypes, System.IOUtils, Winapi.Windows, Winapi.ShellAPI,
  intf.XRechnungValidationHelperJava;

{$R *.dfm}

procedure TMiniAppMainForm.FormCreate(Sender: TObject);
begin
  FUpdating := True;
  FCustomerIndex := -1;
  FPositionIndex := -1;
  EnsureDataDirectories;
  FData := TMiniAppData.Create;
  // Lesefehler sind fatal: vorhandene Daten niemals durch Beispiele ersetzen.
  // Die VCL wuerde eine Exception aus OnCreate nur anzeigen und das halb
  // geladene Fenster trotzdem oeffnen; deshalb hier melden und beenden.
  try
    FData.LoadFromFile(MasterDataPath);
  except
    on E: Exception do
    begin
      MessageDlg('Die Stammdaten konnten nicht gelesen werden:' + sLineBreak + MasterDataPath
        + sLineBreak + sLineBreak + E.Message + sLineBreak + sLineBreak
        + 'Die Datei bleibt unverändert. Das Programm wird beendet.', mtError, [mbOK], 0);
      Application.ShowMainForm := False;
      Application.Terminate;
      Exit;
    end;
  end;
  ShowSeller;
  RefreshCustomers;
  RefreshPositions;
  FCustomerIndex := 0;
  if FData.Customers.Count = 0 then
    FCustomerIndex := -1;
  FPositionIndex := 0;
  if FData.Positions.Count = 0 then
    FPositionIndex := -1;
  ShowCustomer;
  ShowPosition;
  FUpdating := False;
  FDirty := False;
  SaveState.Caption := 'Gespeichert: ' + MasterDataPath;
  SaveState.Hint := SaveState.Caption;
  Log('Stammdaten geladen. Ablage: ' + DataDirectory);
  try
    FClientConfig := LoadClientConfig;
    if FClientConfig.SourceFile = '' then
      Log('Keine .env gefunden. Stammdaten können ohne Client-Konfiguration bearbeitet werden.', lkWarning)
    else
      Log('Client-Konfiguration geladen.');
  except
    // Niemals Konfigurationswerte oder Zugangsdaten in das Protokoll übernehmen.
    Log('Client-Konfiguration konnte nicht gelesen werden. Bitte .env prüfen.', lkWarning);
  end;
  FService := TMiniAppService.Create(FClientConfig, FData.Environment,
    procedure(const AText: string; AKind: TMiniAppLogKind)
    begin
      Log(AText, AKind);
    end);
  FService.OnChanged := UpdateConnection;
  FService.OnConfirmLoginUnconfirmed := ConfirmLoginUnconfirmed;
  UpdateConnection;
  ValidateInvoiceButton.Enabled := FClientConfig.XRechnungDistributionDir <> '';
  OutgoingShow(nil);
end;

destructor TMiniAppMainForm.Destroy;
begin
  FUpdating := True;
  FreeAndNil(FService);
  if FServiceBusy then
    Screen.Cursor := FPreviousCursor;
  FreeAndNil(FData);
  inherited;
end;

procedure TMiniAppMainForm.Log(const AText: string; AKind: TMiniAppLogKind);
const
  KindNames: array[TMiniAppLogKind] of string = ('Info', 'Warnung', 'Fehler');
begin
  ProtocolMemo.Lines.Add(FormatDateTime('dd.mm.yyyy hh:nn:ss', Now) +
    ' [' + KindNames[AKind] + '] ' + AText);
end;

procedure TMiniAppMainForm.MarkDirty;
begin
  FDirty := True;
  SaveState.Caption := 'Ungespeicherte Änderungen';
  SaveState.Hint := SaveState.Caption;
end;

procedure TMiniAppMainForm.SellerChanged(Sender: TObject);
begin
  if not FUpdating then
    MarkDirty;
end;

procedure TMiniAppMainForm.CustomerChanged(Sender: TObject);
begin
  if not FUpdating then
  begin
    FCustomerDirty := True;
    MarkDirty;
  end;
end;

procedure TMiniAppMainForm.PositionChanged(Sender: TObject);
begin
  if not FUpdating then
  begin
    FPositionDirty := True;
    MarkDirty;
  end;
end;

procedure TMiniAppMainForm.EnvironmentChanged(Sender: TObject);
var
  LEnvironment: TMiniAppEnvironment;
begin
  if FUpdating then
    Exit;
  if (FService <> nil) and not FService.CanChangeEnvironment then
  begin
    EnvironmentCombo.ItemIndex := Ord(FService.Environment);
    ConnectionEnvironmentCombo.ItemIndex := Ord(FService.Environment);
    Exit;
  end;
  LEnvironment := TMiniAppEnvironment(TComboBox(Sender).ItemIndex);
  if LEnvironment = meProduction then
    if MessageDlg('Produktion verarbeitet echte Rechnungen. Die Beispieldaten sind dafür ungeeignet. ' +
      'Trotzdem auf Produktion umschalten?', mtWarning, [mbYes, mbNo], 0) <> mrYes then
    begin
      EnvironmentCombo.ItemIndex := Ord(meSandbox);
      ConnectionEnvironmentCombo.ItemIndex := Ord(meSandbox);
      Exit;
    end;
  EnvironmentCombo.ItemIndex := Ord(LEnvironment);
  ConnectionEnvironmentCombo.ItemIndex := Ord(LEnvironment);
  if FService <> nil then
    FService.SetEnvironment(LEnvironment);
  MarkDirty;
end;

procedure TMiniAppMainForm.ShowSeller;
begin
  SellerName.Text := FData.Seller.Name;
  SellerStreet.Text := FData.Seller.Street;
  SellerPostalCode.Text := FData.Seller.PostalCode;
  SellerCity.Text := FData.Seller.City;
  SellerCountryCode.Text := FData.Seller.CountryCode;
  SellerVatID.Text := FData.Seller.VatID;
  SellerTaxNumber.Text := FData.Seller.TaxNumber;
  SellerContactName.Text := FData.Seller.ContactName;
  SellerPhone.Text := FData.Seller.Phone;
  SellerEmail.Text := FData.Seller.Email;
  SellerElectronicAddress.Text := FData.Seller.ElectronicAddress;
  SellerIBAN.Text := FData.Seller.IBAN;
  SellerBIC.Text := FData.Seller.BIC;
  SellerBankName.Text := FData.Seller.BankName;
  EnvironmentCombo.ItemIndex := Ord(FData.Environment);
  InvoiceNumberLabel.Caption := 'Nächste Rechnungsnummer: ' + FData.PendingInvoiceNumber;
end;

procedure TMiniAppMainForm.ReadSeller;
begin
  FData.Seller.Name := Trim(SellerName.Text);
  FData.Seller.Street := Trim(SellerStreet.Text);
  FData.Seller.PostalCode := Trim(SellerPostalCode.Text);
  FData.Seller.City := Trim(SellerCity.Text);
  FData.Seller.CountryCode := Trim(SellerCountryCode.Text);
  FData.Seller.VatID := Trim(SellerVatID.Text);
  FData.Seller.TaxNumber := Trim(SellerTaxNumber.Text);
  FData.Seller.ContactName := Trim(SellerContactName.Text);
  FData.Seller.Phone := Trim(SellerPhone.Text);
  FData.Seller.Email := Trim(SellerEmail.Text);
  FData.Seller.ElectronicAddress := Trim(SellerElectronicAddress.Text);
  FData.Seller.IBAN := Trim(SellerIBAN.Text);
  FData.Seller.BIC := Trim(SellerBIC.Text);
  FData.Seller.BankName := Trim(SellerBankName.Text);
  FData.Seller.CountryCode := UpperCase(FData.Seller.CountryCode);
  FData.Environment := TMiniAppEnvironment(EnvironmentCombo.ItemIndex);
end;

procedure TMiniAppMainForm.ShowCustomer;
var
  LValue: TMiniAppCustomer;
begin
  LValue := Default(TMiniAppCustomer);
  if FCustomerIndex >= 0 then
    LValue := FData.Customers[FCustomerIndex]
  else
  begin
    LValue.CountryCode := 'DE';
    LValue.DeliveryChannel := 'email';
    LValue.ElectronicAddressScheme := 'EM';
  end;
  CustomerCustomerNumber.Text := LValue.CustomerNumber;
  CustomerName.Text := LValue.Name;
  CustomerStreet.Text := LValue.Street;
  CustomerPostalCode.Text := LValue.PostalCode;
  CustomerCity.Text := LValue.City;
  CustomerCountryCode.Text := LValue.CountryCode;
  CustomerVatID.Text := LValue.VatID;
  CustomerDeliveryChannel.ItemIndex := CustomerDeliveryChannel.Items.IndexOf(LValue.DeliveryChannel);
  CustomerBuyerReference.Text := LValue.BuyerReference;
  CustomerElectronicAddress.Text := LValue.ElectronicAddress;
  CustomerElectronicAddressScheme.Text := LValue.ElectronicAddressScheme;
  CustomerContactEmail.Text := LValue.ContactEmail;
  CustomerTraffiqxID.Text := LValue.TraffiqxID;
  if FCustomerIndex >= 0 then
    CustomerList.Selected := CustomerList.Items[FCustomerIndex]
  else
    CustomerList.Selected := nil;
  FCustomerDirty := False;
end;

procedure TMiniAppMainForm.RefreshCustomers;
var
  I: Integer;
  LValue: TMiniAppCustomer;
  LItem: TListItem;
begin
  // Bestehende Items erhalten: auch innerhalb von OnSelectItem aufrufbar.
  CustomerList.Items.BeginUpdate;
  try
    while CustomerList.Items.Count > FData.Customers.Count do
      CustomerList.Items.Delete(CustomerList.Items.Count - 1);
    while CustomerList.Items.Count < FData.Customers.Count do
      CustomerList.Items.Add;
    for I := 0 to FData.Customers.Count - 1 do
    begin
      LValue := FData.Customers[I];
      LItem := CustomerList.Items[I];
      LItem.SubItems.Clear;
      LItem.Caption := LValue.CustomerNumber;
      LItem.SubItems.Add(LValue.Name);
      LItem.SubItems.Add(LValue.DeliveryChannel);
    end;
  finally
    CustomerList.Items.EndUpdate;
  end;
  RefreshOutgoingCustomers;
end;

procedure TMiniAppMainForm.ApplyCustomer;
var
  LValue: TMiniAppCustomer;
  I: Integer;
begin
  if not FCustomerDirty then
    Exit;
  LValue := Default(TMiniAppCustomer);
  LValue.CustomerNumber := Trim(CustomerCustomerNumber.Text);
  LValue.Name := Trim(CustomerName.Text);
  LValue.Street := Trim(CustomerStreet.Text);
  LValue.PostalCode := Trim(CustomerPostalCode.Text);
  LValue.City := Trim(CustomerCity.Text);
  LValue.CountryCode := Trim(CustomerCountryCode.Text);
  LValue.VatID := Trim(CustomerVatID.Text);
  LValue.DeliveryChannel := CustomerDeliveryChannel.Text;
  LValue.BuyerReference := Trim(CustomerBuyerReference.Text);
  LValue.ElectronicAddress := Trim(CustomerElectronicAddress.Text);
  LValue.ElectronicAddressScheme := Trim(CustomerElectronicAddressScheme.Text);
  LValue.ContactEmail := Trim(CustomerContactEmail.Text);
  LValue.TraffiqxID := Trim(CustomerTraffiqxID.Text);
  LValue.CountryCode := UpperCase(LValue.CountryCode);
  for I := 0 to FData.Customers.Count - 1 do
    if (I <> FCustomerIndex) and SameText(LValue.CustomerNumber, FData.Customers[I].CustomerNumber) then
      raise EConvertError.Create('Diese Kundennummer ist bereits vergeben.');
  ValidateCustomer(LValue);
  if FCustomerIndex < 0 then
    FCustomerIndex := FData.Customers.Add(LValue)
  else
    FData.Customers[FCustomerIndex] := LValue;
  FCustomerDirty := False;
  MarkDirty;
end;

function TMiniAppMainForm.ConfirmCustomerChange: Boolean;
begin
  Result := True;
  if not FCustomerDirty then
    Exit;
  case MessageDlg('Änderungen im aktuellen Kundeneditor übernehmen?',
    mtConfirmation, [mbYes, mbNo, mbCancel], 0) of
    mrYes:
      try
        ApplyCustomer;
      except
        on E: Exception do
        begin
          MessageDlg(E.Message, mtError, [mbOK], 0);
          Result := False;
        end;
      end;
    mrNo: FCustomerDirty := False;
  else
    Result := False;
  end;
end;

procedure TMiniAppMainForm.CustomerSelected(Sender: TObject; Item: TListItem; Selected: Boolean);
var
  LIndex: Integer;
begin
  if FUpdating or not Selected then
    Exit;
  LIndex := Item.Index;
  if LIndex = FCustomerIndex then
    Exit;
  FUpdating := True;
  try
    if ConfirmCustomerChange then
    begin
      FCustomerIndex := LIndex;
      RefreshCustomers;
      ShowCustomer;
    end
    else if FCustomerIndex >= 0 then
      CustomerList.Selected := CustomerList.Items[FCustomerIndex]
    else
      CustomerList.Selected := nil;
  finally
    FUpdating := False;
  end;
end;

procedure TMiniAppMainForm.CustomerNewClick(Sender: TObject);
begin
  FUpdating := True;
  try
    if not ConfirmCustomerChange then
      Exit;
    RefreshCustomers;
    FCustomerIndex := -1;
    ShowCustomer;
    CustomerCustomerNumber.SetFocus;
  finally
    FUpdating := False;
  end;
end;

procedure TMiniAppMainForm.CustomerDeleteClick(Sender: TObject);
begin
  if (FCustomerIndex < 0) and not FCustomerDirty then
    Exit;
  if MessageDlg('Aktuellen Kunden löschen?', mtConfirmation,
    [mbYes, mbNo], 0) <> mrYes then
    Exit;
  FUpdating := True;
  try
    if FCustomerIndex >= 0 then
      FData.Customers.Delete(FCustomerIndex);
    FCustomerIndex := -1;
    RefreshCustomers;
    ShowCustomer;
    MarkDirty;
  finally
    FUpdating := False;
  end;
end;

procedure TMiniAppMainForm.CustomerApplyClick(Sender: TObject);
begin
  FUpdating := True;
  try
    try
      ApplyCustomer;
      RefreshCustomers;
      ShowCustomer;
    except
      on E: Exception do
        MessageDlg(E.Message, mtError, [mbOK], 0);
    end;
  finally
    FUpdating := False;
  end;
end;

procedure TMiniAppMainForm.ShowPosition;
var
  LValue: TMiniAppPosition;
begin
  LValue := Default(TMiniAppPosition);
  if FPositionIndex >= 0 then
    LValue := FData.Positions[FPositionIndex]
  else
  begin
    LValue.Quantity := 1;
    LValue.UnitCode := 'H87';
    LValue.VatRate := 19;
  end;
  PositionDescription.Text := LValue.Description;
  PositionQuantity.Text := CurrToStr(LValue.Quantity);
  PositionUnitCode.Text := LValue.UnitCode;
  PositionNetUnitPrice.Text := CurrToStr(LValue.NetUnitPrice);
  PositionVatRate.Text := CurrToStr(LValue.VatRate);
  if FPositionIndex >= 0 then
    PositionList.Selected := PositionList.Items[FPositionIndex]
  else
    PositionList.Selected := nil;
  FPositionDirty := False;
end;

procedure TMiniAppMainForm.RefreshPositions;
var
  I: Integer;
  LValue: TMiniAppPosition;
  LItem: TListItem;
begin
  // Bestehende Items erhalten: auch innerhalb von OnSelectItem aufrufbar.
  PositionList.Items.BeginUpdate;
  try
    while PositionList.Items.Count > FData.Positions.Count do
      PositionList.Items.Delete(PositionList.Items.Count - 1);
    while PositionList.Items.Count < FData.Positions.Count do
      PositionList.Items.Add;
    for I := 0 to FData.Positions.Count - 1 do
    begin
      LValue := FData.Positions[I];
      LItem := PositionList.Items[I];
      LItem.SubItems.Clear;
      LItem.Caption := LValue.Description;
      LItem.SubItems.Add(CurrToStr(LValue.Quantity));
      LItem.SubItems.Add(LValue.UnitCode);
      LItem.SubItems.Add(CurrToStr(LValue.NetUnitPrice));
      LItem.SubItems.Add(CurrToStr(LValue.VatRate));
    end;
  finally
    PositionList.Items.EndUpdate;
  end;
end;

procedure TMiniAppMainForm.ApplyPosition;
var
  LValue: TMiniAppPosition;
begin
  if not FPositionDirty then
    Exit;
  LValue := Default(TMiniAppPosition);
  LValue.Description := Trim(PositionDescription.Text);
  if not TryStrToCurr(Trim(PositionQuantity.Text), LValue.Quantity) then
    raise EConvertError.Create('Menge: Bitte eine gültige Zahl im Windows-Zahlenformat eingeben.');
  LValue.UnitCode := Trim(PositionUnitCode.Text);
  if not TryStrToCurr(Trim(PositionNetUnitPrice.Text), LValue.NetUnitPrice) then
    raise EConvertError.Create('Netto-Einzelpreis (EUR): Bitte eine gültige Zahl im Windows-Zahlenformat eingeben.');
  if not TryStrToCurr(Trim(PositionVatRate.Text), LValue.VatRate) then
    raise EConvertError.Create('USt.-Satz (%): Bitte eine gültige Zahl im Windows-Zahlenformat eingeben.');
  LValue.UnitCode := UpperCase(LValue.UnitCode);
  ValidatePosition(LValue);
  if FPositionIndex < 0 then
    FPositionIndex := FData.Positions.Add(LValue)
  else
    FData.Positions[FPositionIndex] := LValue;
  FPositionDirty := False;
  MarkDirty;
end;

function TMiniAppMainForm.ConfirmPositionChange: Boolean;
begin
  Result := True;
  if not FPositionDirty then
    Exit;
  case MessageDlg('Änderungen im aktuellen Positionseditor übernehmen?',
    mtConfirmation, [mbYes, mbNo, mbCancel], 0) of
    mrYes:
      try
        ApplyPosition;
      except
        on E: Exception do
        begin
          MessageDlg(E.Message, mtError, [mbOK], 0);
          Result := False;
        end;
      end;
    mrNo: FPositionDirty := False;
  else
    Result := False;
  end;
end;

procedure TMiniAppMainForm.PositionSelected(Sender: TObject; Item: TListItem; Selected: Boolean);
var
  LIndex: Integer;
begin
  if FUpdating or not Selected then
    Exit;
  LIndex := Item.Index;
  if LIndex = FPositionIndex then
    Exit;
  FUpdating := True;
  try
    if ConfirmPositionChange then
    begin
      FPositionIndex := LIndex;
      RefreshPositions;
      ShowPosition;
    end
    else if FPositionIndex >= 0 then
      PositionList.Selected := PositionList.Items[FPositionIndex]
    else
      PositionList.Selected := nil;
  finally
    FUpdating := False;
  end;
end;

procedure TMiniAppMainForm.PositionNewClick(Sender: TObject);
begin
  FUpdating := True;
  try
    if not ConfirmPositionChange then
      Exit;
    RefreshPositions;
    FPositionIndex := -1;
    ShowPosition;
    PositionDescription.SetFocus;
  finally
    FUpdating := False;
  end;
end;

procedure TMiniAppMainForm.PositionDeleteClick(Sender: TObject);
begin
  if (FPositionIndex < 0) and not FPositionDirty then
    Exit;
  if MessageDlg('Aktuellen Positionseintrag löschen?', mtConfirmation,
    [mbYes, mbNo], 0) <> mrYes then
    Exit;
  FUpdating := True;
  try
    if FPositionIndex >= 0 then
      FData.Positions.Delete(FPositionIndex);
    FPositionIndex := -1;
    RefreshPositions;
    ShowPosition;
    MarkDirty;
  finally
    FUpdating := False;
  end;
end;

procedure TMiniAppMainForm.PositionApplyClick(Sender: TObject);
begin
  FUpdating := True;
  try
    try
      ApplyPosition;
      RefreshPositions;
      ShowPosition;
    except
      on E: Exception do
        MessageDlg(E.Message, mtError, [mbOK], 0);
    end;
  finally
    FUpdating := False;
  end;
end;

function TMiniAppMainForm.SaveData: Boolean;
begin
  Result := False;
  FUpdating := True;
  try
    try
      ApplyCustomer;
      RefreshCustomers;
      ApplyPosition;
      RefreshPositions;
      ReadSeller;
      FData.SaveToFile;
      RefreshCustomers;
      RefreshPositions;
      ShowCustomer;
      ShowPosition;
      ShowSeller;
      FDirty := False;
      SaveState.Caption := 'Gespeichert: ' + MasterDataPath;
      SaveState.Hint := SaveState.Caption;
      Log('Stammdaten gespeichert.');
      Result := True;
    except
      on E: Exception do
      begin
        Log('Speichern fehlgeschlagen: ' + E.Message, lkError);
        MessageDlg('Stammdaten konnten nicht gespeichert werden: ' + E.Message,
          mtError, [mbOK], 0);
      end;
    end;
  finally
    FUpdating := False;
  end;
end;

procedure TMiniAppMainForm.SaveClick(Sender: TObject);
begin
  SaveData;
end;

procedure TMiniAppMainForm.RefreshOutgoingCustomers;
var
  LNumber: string;
  LCustomer: TMiniAppCustomer;
  LIndex: Integer;
begin
  // Auswahl anhand der stabilen Kundennummer erhalten, auch nach Bearbeitungen.
  LNumber := '';
  LIndex := OutgoingCustomerCombo.ItemIndex;
  if (LIndex >= 0) and (LIndex < Length(FOutgoingCustomerNumbers)) then
    LNumber := FOutgoingCustomerNumbers[LIndex];
  OutgoingCustomerCombo.Items.BeginUpdate;
  try
    OutgoingCustomerCombo.Clear;
    SetLength(FOutgoingCustomerNumbers, FData.Customers.Count);
    LIndex := -1;
    for LCustomer in FData.Customers do
    begin
      OutgoingCustomerCombo.Items.Add(LCustomer.CustomerNumber + ' - ' + LCustomer.Name);
      FOutgoingCustomerNumbers[OutgoingCustomerCombo.Items.Count - 1] := LCustomer.CustomerNumber;
      if LCustomer.CustomerNumber = LNumber then
        LIndex := OutgoingCustomerCombo.Items.Count - 1;
    end;
    if (LIndex < 0) and (OutgoingCustomerCombo.Items.Count > 0) then
      LIndex := 0;
    OutgoingCustomerCombo.ItemIndex := LIndex;
    NewInvoiceButton.Enabled := LIndex >= 0;
  finally
    OutgoingCustomerCombo.Items.EndUpdate;
  end;
end;

procedure TMiniAppMainForm.RefreshOutgoing;
var
  LDirectory, LNumber, LSelected, LDocumentID, LStatus: string;
  LInfo: TMiniAppInvoiceInfo;
  LItem: TListItem;
begin
  LSelected := '';
  if OutgoingList.Selected <> nil then
    LSelected := OutgoingList.Selected.Caption;
  OutgoingList.Items.BeginUpdate;
  try
    OutgoingList.Clear;
    for LDirectory in TDirectory.GetDirectories(OutgoingDirectory) do
    begin
      LNumber := ExtractFileName(LDirectory);
      LItem := OutgoingList.Items.Add;
      LItem.Caption := LNumber;
      LItem.SubItems.Add('');
      LItem.SubItems.Add('');
      LItem.SubItems.Add('');
      LItem.SubItems.Add('');
      LItem.SubItems.Add('');
      LItem.SubItems.Add('');
      try
        LInfo := LoadInvoiceInfo(LNumber);
        LItem.SubItems[0] := LInfo.CustomerName;
        LItem.SubItems[1] := LInfo.IssueDate;
        LItem.SubItems[2] := FormatCurr('0.00', LInfo.GrossAmount) + ' EUR';
        LItem.SubItems[3] := LInfo.DeliveryChannel;
      except
        on E: Exception do
        begin
          LItem.SubItems[0] := '(Ablage unvollständig / Info nicht lesbar)';
          Log(LNumber + ': ' + E.Message, lkWarning);
        end;
      end;
      try
        LoadOutboxState(LNumber, LDocumentID, LStatus);
        LItem.SubItems[4] := LDocumentID;
        LItem.SubItems[5] := LStatus;
      except
        on E: Exception do
          Log(LNumber + ': outbox.json nicht lesbar: ' + E.Message, lkWarning);
      end;
      if LNumber = LSelected then
        LItem.Selected := True;
    end;
  finally
    OutgoingList.Items.EndUpdate;
  end;
end;

procedure TMiniAppMainForm.OutgoingShow(Sender: TObject);
begin
  if FData = nil then
    Exit;
  try
    RefreshOutgoingCustomers;
    RefreshOutgoing;
  except
    on E: Exception do
      Log('Ausgang konnte nicht aktualisiert werden: ' + E.Message, lkError);
  end;
end;

procedure TMiniAppMainForm.NewInvoiceClick(Sender: TObject);
var
  LNumber, LDirectory: string;
  LCustomer: TMiniAppCustomer;
  LItem: TListItem;
  LCustomerIndex: Integer;
begin
  LCustomerIndex := OutgoingCustomerCombo.ItemIndex;
  // Offene Editoren vor der Erzeugung übernehmen und Stammdaten persistieren.
  if not SaveData then
    Exit;
  // SaveData ändert keine bestehenden Listenindizes. Bei einer Umbenennung
  // der Kundennummer darf die Combo-Aktualisierung keinen anderen Empfänger wählen.
  if LCustomerIndex < 0 then
    LCustomerIndex := OutgoingCustomerCombo.ItemIndex;
  if LCustomerIndex < 0 then
    Exit;
  OutgoingCustomerCombo.ItemIndex := LCustomerIndex;
  LCustomer := FData.Customers[LCustomerIndex];
  LNumber := '';
  try
    LDirectory := CreateOutboxInvoice(FData, LCustomer, Date, LNumber);
    Log(LNumber + ' für ' + LCustomer.Name + ' erzeugt: ' + LDirectory);
  except
    on E: Exception do
    begin
      Log('Rechnungserzeugung fehlgeschlagen: ' + E.Message, lkError);
      if LNumber <> '' then
        Log('Rechnungsnummer ' + LNumber + ' bleibt verbraucht und wird nie wiederverwendet. ' +
          'Eine eventuell vorhandene Teilablage bleibt zur Diagnose erhalten.', lkWarning);
      MessageDlg(E.Message, mtError, [mbOK], 0);
    end;
  end;
  InvoiceNumberLabel.Caption := 'Nächste Rechnungsnummer: ' + FData.PendingInvoiceNumber;
  OutgoingShow(nil);
  LItem := OutgoingList.FindCaption(0, LNumber, False, True, False);
  if LItem <> nil then
  begin
    LItem.Selected := True;
    LItem.MakeVisible(False);
  end;
end;

function TMiniAppMainForm.SelectedInvoiceNumber: string;
begin
  if OutgoingList.Selected = nil then
    raise EInvalidOperation.Create('Bitte zuerst eine Rechnung im Ausgang auswählen.');
  Result := OutgoingList.Selected.Caption;
end;

procedure TMiniAppMainForm.OpenLocalPath(const APath: string);
var
  LResult: NativeInt;
begin
  if not FileExists(APath) and not DirectoryExists(APath) then
    raise EInOutError.Create('Datei oder Ordner fehlt: ' + APath);
  LResult := NativeInt(ShellExecute(Handle, 'open', PChar(APath), nil, nil, SW_SHOWNORMAL));
  if LResult <= 32 then
    raise EInOutError.CreateFmt('Das Standardprogramm konnte nicht geöffnet werden (Fehler %d).', [LResult]);
end;

procedure TMiniAppMainForm.ShowXmlClick(Sender: TObject);
begin
  try
    OpenLocalPath(TPath.Combine(InvoiceDirectory(SelectedInvoiceNumber), 'rechnung.xml'));
  except
    on E: Exception do
    begin
      Log(E.Message, lkError);
      MessageDlg(E.Message, mtError, [mbOK], 0);
    end;
  end;
end;

procedure TMiniAppMainForm.OpenFolderClick(Sender: TObject);
begin
  try
    OpenLocalPath(InvoiceDirectory(SelectedInvoiceNumber));
  except
    on E: Exception do
    begin
      Log(E.Message, lkError);
      MessageDlg(E.Message, mtError, [mbOK], 0);
    end;
  end;
end;

procedure TMiniAppMainForm.ValidationError(const AMessage: string);
begin
  Log('KoSIT: ' + AMessage, lkError);
end;

procedure TMiniAppMainForm.ValidateInvoiceClick(Sender: TObject);
var
  LDirectory, LDist, LOutput, LXml, LHtml: string;
  LSuccess: Boolean;
begin
  if FClientConfig.XRechnungDistributionDir = '' then
    Exit;
  try
    LDirectory := InvoiceDirectory(SelectedInvoiceNumber);
    LDist := IncludeTrailingPathDelimiter(FClientConfig.XRechnungDistributionDir);
    Screen.Cursor := crHourGlass;
    try
      Log('KoSIT-Prüfung gestartet: ' + SelectedInvoiceNumber);
      // Lokaler, begrenzter Lauf ohne ProcessMessages (keine Wiedereintritte).
      LSuccess := GetXRechnungValidationHelperJava
        .SetJavaRuntimeEnvironmentPath(LDist + 'java')
        .SetValidatorLibPath(LDist + 'validator')
        .SetValidatorConfigurationPath(LDist + 'validator-configuration30x')
        .SetValidationErrorHandler(ValidationError)
        .SetExecTimeout(60)
        .ValidateFile(TPath.Combine(LDirectory, 'rechnung.xml'), LOutput, LXml, LHtml);
      if LOutput <> '' then
        Log('KoSIT-Ausgabe: ' + sLineBreak + LOutput);
      if LXml <> '' then
      begin
        AtomicWriteText(TPath.Combine(LDirectory, 'pruefbericht.xml'), LXml);
        Log('KoSIT-Ergebnis: ' + sLineBreak + LXml);
      end;
      if LHtml <> '' then
        AtomicWriteText(TPath.Combine(LDirectory, 'pruefbericht.html'), LHtml);
      // Der Boolean meldet nur den Prozessstatus, nicht die fachliche Gültigkeit.
      if LSuccess and (LXml <> '') then
        Log('KoSIT beendet. Fachliches Ergebnis siehe Bericht und Protokoll; Ablage: ' + LDirectory)
      else
        Log('KoSIT nicht erfolgreich abgeschlossen oder kein Bericht erzeugt. ' +
          'Distribution und Protokoll prüfen.', lkError);
    finally
      Screen.Cursor := crDefault;
    end;
  except
    on E: Exception do
    begin
      Log('KoSIT-Prüfung fehlgeschlagen: ' + E.Message, lkError);
      MessageDlg(E.Message, mtError, [mbOK], 0);
    end;
  end;
end;

procedure TMiniAppMainForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := True;
  if FDirty then
    case MessageDlg('Änderungen vor dem Schließen speichern?', mtConfirmation,
      [mbYes, mbNo, mbCancel], 0) of
      mrYes: CanClose := SaveData;
      mrNo: CanClose := True;
    else
      CanClose := False;
    end;
  if CanClose and (FService <> nil) then
    FService.CancelConnect;
end;

procedure TMiniAppMainForm.UpdateConnection;
begin
  if FService = nil then
    Exit;
  // Kein ProcessMessages: insbesondere der Polling-Handler bleibt nicht-reentrant.
  if FService.Busy and not FServiceBusy then
  begin
    FPreviousCursor := Screen.Cursor;
    Screen.Cursor := crHourGlass;
  end
  else if not FService.Busy and FServiceBusy then
    Screen.Cursor := FPreviousCursor;
  FServiceBusy := FService.Busy;
  ConnectionEnvironmentCombo.ItemIndex := Ord(FService.Environment);
  ConnectionEnvironmentCombo.Enabled := FService.CanChangeEnvironment;
  EnvironmentCombo.Enabled := FService.CanChangeEnvironment;
  ConnectionIdentity.Caption := 'TRAFFIQX-ID: ' + FService.TraffiqxID;
  ConnectionStatus.Font.Color := clRed;
  ConnectionLamp.Brush.Color := clRed;
  if FService.LoginUnconfirmed then
  begin
    ConnectionStatus.Font.Color := clOlive;
    ConnectionLamp.Brush.Color := clYellow;
    ConnectionStatus.Caption := 'Anmeldung abgebrochen – Verbindung bei DATEV prüfen';
  end
  else if FService.RevocationPending then
  begin
    ConnectionStatus.Font.Color := clOlive;
    ConnectionLamp.Brush.Color := clYellow;
    ConnectionStatus.Caption := 'Widerruf ausstehend – Tokens für Nutzung gesperrt';
  end
  else if FService.StorageBlocked then
    ConnectionStatus.Caption := 'Nicht verbunden – Token-Ablage gesperrt (siehe Protokoll)'
  else if FService.Connecting then
    ConnectionStatus.Caption := 'Anmeldung läuft – bitte im Browser abschließen'
  else if FService.Connected then
  begin
    ConnectionStatus.Font.Color := clGreen;
    ConnectionLamp.Brush.Color := clLime;
    ConnectionStatus.Caption := 'Verbunden (Inbox und Outbox geprüft)';
  end
  else if FService.HasTokens and (FService.RefreshExpiresAt > Now) then
    ConnectionStatus.Caption := 'Nicht geprüft – bitte „Verbindung prüfen“ wählen'
  else
    ConnectionStatus.Caption := 'Nicht verbunden – bitte neu verbinden';
  ConnectionExpiry.Caption := 'Refresh-Token gültig bis: –';
  if FService.RefreshExpiresAt > 0 then
    ConnectionExpiry.Caption := 'Refresh-Token gültig bis: ' +
      FormatDateTime('dd.mm.yyyy hh:nn', FService.RefreshExpiresAt);
  ConnectionUser.Caption := 'Person: ' + FService.UserName;
  if FService.UserName = '' then
    ConnectionUser.Caption := 'Person: noch nicht verfügbar';
  ConnectButton.Enabled := not (FService.Busy or FService.Connecting or FService.StorageBlocked);
  CancelConnectButton.Visible := FService.Connecting;
  CancelConnectButton.Enabled := FService.Connecting and not FService.Busy;
  CheckConnectionButton.Enabled := FService.HasTokens and not
    (FService.Busy or FService.Connecting or FService.StorageBlocked or
     FService.RevocationPending or FService.LoginUnconfirmed);
  DisconnectButton.Enabled := (FService.HasTokens or FService.RevocationPending or
    FService.LoginUnconfirmed) and not
    (FService.Busy or FService.Connecting or FService.StorageBlocked);
  ConnectionHelpLink.Visible := FService.HelpUrl <> '';
  ProtocolHelpLink.Visible := FService.HelpUrl <> '';
  // Die URL bleibt Datenwert, kein ungeprüftes Markup im TLinkLabel.
  ConnectionHelpLink.Hint := FService.HelpUrl;
  ProtocolHelpLink.Hint := FService.HelpUrl;
end;

function TMiniAppMainForm.ConfirmLoginUnconfirmed: Boolean;
var
  LDialog: TTaskDialog;
  LCursor: TCursor;
begin
  Result := False;
  LCursor := Screen.Cursor;
  Screen.Cursor := crDefault;
  LDialog := TTaskDialog.Create(Self);
  try
    LDialog.Caption := 'DATEV-Verbindung prüfen';
    LDialog.Title := 'Ungeklärte Anmeldung';
    LDialog.Text := 'Eine abgebrochene Anmeldung kann bei DATEV eine Verbindung angelegt haben. ' +
      'Bitte unter „Verbundene Anwendungen“ (https://apps.datev.de/tokrevui) prüfen und ' +
      'eine nicht benötigte Verbindung entfernen. Fortfahren?';
    LDialog.CommonButtons := [tcbYes, tcbNo];
    LDialog.DefaultButton := tcbNo;
    with LDialog.Buttons.Add do
    begin
      Caption := 'Verbundene Anwendungen öffnen';
      ModalResult := mrRetry;
    end;
    repeat
      if not LDialog.Execute then
        Exit;
      if LDialog.ModalResult = mrRetry then
        ConnectionLinkClick(ConnectedAppsLink, '', sltURL);
    until LDialog.ModalResult <> mrRetry;
    Result := LDialog.ModalResult = mrYes;
  finally
    LDialog.Free;
    Screen.Cursor := LCursor;
  end;
end;

procedure TMiniAppMainForm.ConnectClick(Sender: TObject);
begin
  // Umgebung vor der Anmeldung dauerhaft sichern, damit der Neustart dieselbe nutzt.
  if (FService <> nil) and SaveData then
    FService.Connect;
end;

procedure TMiniAppMainForm.CancelConnectClick(Sender: TObject);
begin
  if FService <> nil then
    FService.CancelConnect;
end;

procedure TMiniAppMainForm.CheckConnectionClick(Sender: TObject);
begin
  if FService <> nil then
    FService.CheckConnection;
end;

procedure TMiniAppMainForm.DisconnectClick(Sender: TObject);
begin
  if FService <> nil then
    FService.Disconnect;
end;

procedure TMiniAppMainForm.ConnectionLinkClick(Sender: TObject; const Link: string;
  LinkType: TSysLinkType);
var
  LUrl: string;
begin
  if Sender = ConnectedAppsLink then
    LUrl := 'https://apps.datev.de/tokrevui'
  else if FService <> nil then
    LUrl := FService.HelpUrl
  else
    Exit;
  if LUrl = '' then
    Exit;
  if NativeInt(ShellExecute(Handle, 'open', PChar(LUrl), nil, nil, SW_SHOWNORMAL)) <= 32 then
    Log('Hilfeseite konnte nicht im Browser geöffnet werden: ' + LUrl, lkWarning);
end;

procedure TMiniAppMainForm.ConnectionTimerTick(Sender: TObject);
begin
  // Nur Anzeigeablauf; kein Netzwerk-Polling im Leerlauf.
  UpdateConnection;
end;

end.
