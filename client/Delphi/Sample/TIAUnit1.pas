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

unit TIAUnit1;

interface

{.$DEFINE WPDF}

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils,
  System.Variants, System.DateUtils, System.Math, System.UITypes, System.StrUtils,
  System.Classes, System.IniFiles, System.JSON, Vcl.Graphics,System.NetEncoding,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, System.TypInfo, System.IOUtils,
  Vcl.ComCtrls, Vcl.ExtCtrls, Vcl.Mask, Winapi.WebView2, Winapi.ActiveX, Vcl.Edge
  ,intf.Invoice,intf.XRechnungHelper,intf.XRechnung_3_0
  ,intf.XRechnungValidationHelperJava,intf.XRechnung,XRechnungUnit2TestCases
  {$IFDEF WPDF}
  ,WPPDFR1,WPPDFR2
  {$ENDIF}
  ,intf.TRAFFIQXInvoiceAPI, intf.TRAFFIQXHttpLog, intf.TRAFFIQXTokenProtection;

type
  TForm1 = class(TForm)
    btLogin: TButton;
    btRefreshToken: TButton;
    btErrorRate: TButton;
    PageControl1: TPageControl;
    tsB4Value: TTabSheet;
    tsBundesdruckerei: TTabSheet;
    tsBeCloud: TTabSheet;
    tsDatev: TTabSheet;
    tsExela: TTabSheet;
    tsQuadient: TTabSheet;
    tsSGHService: TTabSheet;
    tsRicoh: TTabSheet;
    Label1: TLabel;
    Label2: TLabel;
    edB4ValueAccessToken: TLabeledEdit;
    edB4ValueRefreshToken: TEdit;
    Label3: TLabel;
    Label4: TLabel;
    Edit3: TLabeledEdit;
    Edit4: TEdit;
    Label5: TLabel;
    Label6: TLabel;
    Edit5: TLabeledEdit;
    Edit6: TEdit;
    Label7: TLabel;
    Label8: TLabel;
    edDatevAccessToken: TLabeledEdit;
    edDatevRefreshToken: TEdit;
    Label9: TLabel;
    Label10: TLabel;
    Edit9: TLabeledEdit;
    Edit10: TEdit;
    Label11: TLabel;
    Label12: TLabel;
    Edit11: TLabeledEdit;
    Edit12: TEdit;
    Label13: TLabel;
    Label14: TLabel;
    Edit13: TLabeledEdit;
    Edit14: TEdit;
    Label15: TLabel;
    Label16: TLabel;
    Edit15: TLabeledEdit;
    Edit16: TEdit;
    PageControl2: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    RadioGroup1: TRadioGroup;
    GroupBox1: TGroupBox;
    RadioButton1: TRadioButton;
    RadioButton2: TRadioButton;
    RadioButton3: TRadioButton;
    RadioButton4: TRadioButton;
    RadioButton5: TRadioButton;
    RadioButton6: TRadioButton;
    RadioButton7: TRadioButton;
    RadioButton8: TRadioButton;
    RadioButton9: TRadioButton;
    RadioButton10: TRadioButton;
    RadioButton11: TRadioButton;
    RadioButton12: TRadioButton;
    RadioButton13: TRadioButton;
    Button1: TButton;
    Memo2: TMemo;
    edDatevTraffiqxID: TEdit;
    Label17: TLabel;
    Edit1: TEdit;
    Label18: TLabel;
    Edit2: TEdit;
    Label19: TLabel;
    Edit7: TEdit;
    Label20: TLabel;
    Edit8: TEdit;
    Label21: TLabel;
    Edit17: TEdit;
    Label22: TLabel;
    Edit18: TEdit;
    Label23: TLabel;
    Edit19: TEdit;
    Label24: TLabel;
    EdgeBrowser1: TEdgeBrowser;
    PageControl3: TPageControl;
    TabSheet3: TTabSheet;
    TabSheet4: TTabSheet;
    Memo1: TMemo;
    btGetInboxDocumentIds: TButton;
    ListView1: TListView;
    btGetInboxDocumentMetadata: TButton;
    btDownloadInboxDocument: TButton;
    EdgeBrowser2: TEdgeBrowser;
    Memo3: TMemo;
    btGetOutboxDocumentIds: TButton;
    ListView2: TListView;
    btGetOutboxDocumentMetadataClick: TButton;
    btDownloadOutboxDocument: TButton;
    btGetOutboxDocumentStatus: TButton;
    btUploadStructuredData: TButton;
    btUploadZugferdData: TButton;
    Button2: TButton;
    ListView3: TListView;
    Button3: TButton;
    TabSheet5: TTabSheet;
    Label25: TLabel;
    Label26: TLabel;
    Label27: TLabel;
    LabeledEdit1: TLabeledEdit;
    Edit20: TEdit;
    Edit21: TEdit;
    procedure btLoginClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btRefreshTokenClick(Sender: TObject);
    procedure btGetInboxDocumentIdsClick(Sender: TObject);
    procedure RadioGroup1Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure btGetInboxDocumentMetadataClick(Sender: TObject);
    procedure btDownloadInboxDocumentClick(Sender: TObject);
    procedure btGetOutboxDocumentIdsClick(Sender: TObject);
    procedure btGetOutboxDocumentMetadataClickClick(Sender: TObject);
    procedure btGetOutboxDocumentStatusClick(Sender: TObject);
    procedure btUploadZugferdDataClick(Sender: TObject);
    procedure btUploadStructuredDataClick(Sender: TObject);
    procedure btDownloadOutboxDocumentClick(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure btErrorRateClick(Sender: TObject);
  private
    FConfigurationPath : String;
    FConfiguration : TIniFile;
    // Distribution-Verzeichnis von XRechnung-for-Delphi (Java, Saxon, FOP) fuer
    // die Visualisierung der Testfaelle; .env: XRECHNUNG_DISTRIBUTION_DIR
    FXRechnungDistributionDir : String;
    FTIA : array[1..9] of TTRAFFIQXInvoiceAPI;
    edAccessTokenReference : array[1..9] of TLabeledEdit;
    edRefreshTokenReference : array[1..9] of TEdit;
    edTraffiqxIDReference : array[1..9] of TEdit;
    procedure ShowApiError(AError: TTraffiqxError);
    function IsReloginRequiredMessage(const AMessage: string): Boolean;
    procedure ShowReloginHint(const AMessage: string);
    function FormatDateSafe(const ADate: TDateTime): string;
    function GuessExtension(AStream: TMemoryStream): string;
    function ToFileUrl(const APath: string): string;
    procedure AppendStatusInfo(ATargetMemo: TMemo; const APrefix: string;
      AStatus: TTraffiqxInboxDocumentStatusInfo);
    procedure AppendOutboxMetadata(ATargetMemo: TMemo;
      AMetadata: TTraffiqxOutboxMetadata);
    procedure OpenFirstZipEntry(AZipStream: TMemoryStream; ATargetMemo: TMemo;
      ATargetBrowser: TEdgeBrowser);
    procedure HandlePollingCompleted(const AResult: TTraffiqxPollResult; ASender : TTRAFFIQXInvoiceAPI);
    procedure PopulateOutboxTestCases;
    // Tokens verschluesselt in cfg.ini (DPAPI, an den Windows-Benutzer
    // gebunden; intf.TRAFFIQXTokenProtection). Nicht lesbar (anderer
    // Benutzer/Rechner) = leer, also neu anmelden.
    function ReadToken(const ASection, AKey: String): String;
    procedure WriteToken(const ASection, AKey, AValue: String);
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

function ProviderEnvPrefix(const ProviderType: TTraffiqxProviderType): string;
const
  PROVIDER_PREFIX: array[TTraffiqxProviderType] of string = (
    'PROVIDER_TPNOTSET',
    'PROVIDER_TPB4VALUE',
    'PROVIDER_TPBUNDESDRUCKEREI',
    'PROVIDER_TPBCLOUD',
    'PROVIDER_TPDATEV',
    'PROVIDER_TPEXELAASTERION',
    'PROVIDER_TPQUADIENT',
    'PROVIDER_TPSGHSERVICE',
    'PROVIDER_TPRICOH',
    'PROVIDER_TPDATEVSMARTTRANSFER'
  );
begin
  Result := PROVIDER_PREFIX[ProviderType];
end;

function DefaultEnvironmentForProvider(
  const ProviderType: TTraffiqxProviderType): TTraffiqxEnvironment;
begin
  case ProviderType of
    tpB4Value,
    tpDatev:
      Result := teSandbox;
  else
    Result := teProduction;
  end;
end;

function TestDataPath(const AFileName: string): string;
begin
  Result := TPath.GetFullPath('..\..\..\..\..\testdata\'+AFileName);
end;

type
  TSandboxScenarioCase = record
    ScenarioId: string;
    FilePrefix: string;
    FormatSuffix: string;
    UseExtended: Boolean;
  end;

  TRecipientAddressCase = record
    DisplayName: string;
    FileSuffix: string;
    BuyerReference: string;
    CustomerEndpointId: string;
    CustomerEndpointSchemeId: string;
  end;

  TDocumentVariantKind = (dvXRechnungCii, dvXRechnungUbl, dvZugferdCii);

  TDocumentVariantCase = record
    DisplayName: string;
    FileSuffix: string;
    Kind: TDocumentVariantKind;
  end;

const
  SANDBOX_SCENARIOS: array[0..2] of TSandboxScenarioCase = (
    (ScenarioId: 'SBSZ:110'; FilePrefix: 'sbsz110'; FormatSuffix: 'en16931'; UseExtended: False),
    (ScenarioId: 'SBSZ:120'; FilePrefix: 'sbsz120'; FormatSuffix: 'extended'; UseExtended: True),
    (ScenarioId: 'SBSZ:210'; FilePrefix: 'sbsz210'; FormatSuffix: 'en16931'; UseExtended: False)
  );
  RECIPIENT_ADDRESS_CASES: array[0..3] of TRecipientAddressCase = (
    (DisplayName: 'BT-10 TRAFFIQX-ID'; FileSuffix: 'bt10-traffiqxid'; BuyerReference: 'TX:1234567890000'; CustomerEndpointId: 'Muster.Tester@datev.de'; CustomerEndpointSchemeId: 'EM'),
    (DisplayName: 'BT-10 Leitweg-ID'; FileSuffix: 'bt10-leitwegid'; BuyerReference: '42-TEST-18'; CustomerEndpointId: 'Muster.Tester@datev.de'; CustomerEndpointSchemeId: 'EM'),
    (DisplayName: 'BT-49 Peppol-ID'; FileSuffix: 'bt49-peppolid'; BuyerReference: ''; CustomerEndpointId: 'DE123456789'; CustomerEndpointSchemeId: '9930'),
    (DisplayName: 'BT-49 E-Mail'; FileSuffix: 'bt49-email'; BuyerReference: ''; CustomerEndpointId: 'Muster.Tester@datev.de'; CustomerEndpointSchemeId: 'EM')
  );
  DOCUMENT_VARIANT_CASES: array[0..2] of TDocumentVariantCase = (
    (DisplayName: 'XRechnung CII'; FileSuffix: 'xrechnung-cii-30x'; Kind: dvXRechnungCii),
    (DisplayName: 'XRechnung UBL'; FileSuffix: 'xrechnung-ubl-30x'; Kind: dvXRechnungUbl),
    (DisplayName: 'ZUGFeRD CII'; FileSuffix: 'zugferd-cii'; Kind: dvZugferdCii)
  );

function BuildOutboxTestCaseXmlPath(const AScenarioCase: TSandboxScenarioCase;
  const AAddressCase: TRecipientAddressCase;
  const ADocumentCase: TDocumentVariantCase): string;
begin
  Result := TestDataPath(AScenarioCase.FilePrefix + '-' + AAddressCase.FileSuffix
    + '-' + ADocumentCase.FileSuffix);

  if ADocumentCase.Kind = dvZugferdCii then
    Result := Result + '-' + AScenarioCase.FormatSuffix + '-232.xml'
  else
    Result := Result + '.xml';
end;

function DocumentVariantKindFromText(const AText: string): TDocumentVariantKind;
begin
  if SameText(AText, DOCUMENT_VARIANT_CASES[0].DisplayName) then
    Exit(dvXRechnungCii);
  if SameText(AText, DOCUMENT_VARIANT_CASES[1].DisplayName) then
    Exit(dvXRechnungUbl);
  Result := dvZugferdCii;
end;

procedure TForm1.ShowApiError(AError: TTraffiqxError);
var
  LUserMessage: string;
begin
  if AError = nil then
    Exit;

  LUserMessage := TTraffiqxInboxErrorHelper.BuildUserMessage(AError);

  if LUserMessage <> '' then
    MessageDlg('Hinweis ' + LUserMessage + sLineBreak + sLineBreak +
      'Title ' + AError.Title + sLineBreak +
      'Status ' + AError.Status.ToString + sLineBreak +
      'Detail ' + AError.Detail, mtError, [mbOK], 0)
  else
    MessageDlg('Title ' + AError.Title + sLineBreak +
      'Status ' + AError.Status.ToString + sLineBreak +
      'Detail ' + AError.Detail, mtError, [mbOK], 0);
end;

function TForm1.IsReloginRequiredMessage(const AMessage: string): Boolean;
var
  LMessage: string;
begin
  LMessage := LowerCase(Trim(AMessage));
  Result := (Pos('refresh-token', LMessage) > 0)
    or (Pos('refreshtoken', LMessage) > 0)
    or (Pos('invalid_grant', LMessage) > 0)
    or (Pos('erneut anmelden', LMessage) > 0)
    or (Pos('erneut durchführen', LMessage) > 0);
end;

procedure TForm1.ShowReloginHint(const AMessage: string);
begin
  MessageDlg('Die Sitzung ist nicht mehr fuer einen Token-Refresh geeignet.' + sLineBreak + sLineBreak
    + 'Bitte erneut anmelden.' + sLineBreak + sLineBreak
    + 'Detail: ' + AMessage, mtWarning, [mbOK], 0);
end;

function TForm1.FormatDateSafe(const ADate: TDateTime): string;
begin
  if ADate = 0 then
    Result := ''
  else
    Result := DateTimeToStr(ADate);
end;

function TForm1.GuessExtension(AStream: TMemoryStream): string;
var
  lHead: TBytes;
  lHeadStr: string;
begin
  Result := '.bin';
  if (AStream = nil) or (AStream.Size = 0) then
    Exit;

  SetLength(lHead, Min(16, AStream.Size));
  AStream.Position := 0;
  AStream.ReadBuffer(lHead[0], Length(lHead));
  AStream.Position := 0;

  lHeadStr := TEncoding.ASCII.GetString(lHead);

  if Pos('%PDF-', lHeadStr) = 1 then
    Exit('.pdf');

  if Pos('<?xml', lHeadStr) = 1 then
    Exit('.xml');

  if (Length(lHead) >= 2) and (lHead[0] = $50) and (lHead[1] = $4B) then
    Exit('.zip');
end;

function TForm1.ToFileUrl(const APath: string): string;
begin
  Result := 'file:///' + StringReplace(APath, '\', '/', [rfReplaceAll]);
  Result := StringReplace(Result, ' ', '%20', [rfReplaceAll]);
end;

procedure TForm1.AppendStatusInfo(ATargetMemo: TMemo; const APrefix: string;
  AStatus: TTraffiqxInboxDocumentStatusInfo);
var
  LStatusMeaning: string;
  LErrorCodeMeaning: string;
  LErrorDetailsMeaning: string;
begin
  if (ATargetMemo = nil) or (AStatus = nil) then
    Exit;

  LStatusMeaning := TTraffiqxDocumentStatusHelper.DescribeStatus(AStatus.ParsedStatus);
  LErrorCodeMeaning := TTraffiqxDocumentStatusHelper.DescribeErrorCode(AStatus.ErrorCode);
  LErrorDetailsMeaning := TTraffiqxDocumentStatusHelper.DescribeErrorDetails(AStatus.ErrorDetails);

  ATargetMemo.Lines.Add(APrefix + '.ParsedStatus: '
    + TTraffiqxDocumentStatusHelper.ToDisplayString(AStatus.ParsedStatus));
  ATargetMemo.Lines.Add(APrefix + '.Status: ' + AStatus.Status);
  if LStatusMeaning <> '' then
    ATargetMemo.Lines.Add(APrefix + '.StatusMeaning: ' + LStatusMeaning);
  ATargetMemo.Lines.Add(APrefix + '.ErrorCode: ' + AStatus.ErrorCode);
  if LErrorCodeMeaning <> '' then
    ATargetMemo.Lines.Add(APrefix + '.ErrorCodeMeaning: ' + LErrorCodeMeaning);
  ATargetMemo.Lines.Add(APrefix + '.ErrorDetails: ' + AStatus.ErrorDetails);
  if LErrorDetailsMeaning <> '' then
    ATargetMemo.Lines.Add(APrefix + '.ErrorDetailsMeaning: ' + LErrorDetailsMeaning);
  ATargetMemo.Lines.Add(APrefix + '.Downloaded: ' + BoolToStr(AStatus.Downloaded, True));
end;

procedure TForm1.AppendOutboxMetadata(ATargetMemo: TMemo;
  AMetadata: TTraffiqxOutboxMetadata);
begin
  if (ATargetMemo = nil) or (AMetadata = nil) then
    Exit;

  ATargetMemo.Lines.Add('InvoiceDate: ' + FormatDateSafe(AMetadata.InvoiceDate));
  ATargetMemo.Lines.Add('InvoiceNumber: ' + AMetadata.InvoiceNumber);
  ATargetMemo.Lines.Add('GrossTotal: ' + FormatFloat('0.00##', AMetadata.GrossTotal));
  ATargetMemo.Lines.Add('CurrencyCode: ' + AMetadata.CurrencyCode);
  ATargetMemo.Lines.Add('SellerName: ' + AMetadata.SellerName);
  ATargetMemo.Lines.Add('BuyerName: ' + AMetadata.BuyerName);
  ATargetMemo.Lines.Add('InvoiceType: ' + AMetadata.InvoiceType);
  ATargetMemo.Lines.Add('DocumentFormat: ' + AMetadata.DocumentFormat);
  ATargetMemo.Lines.Add('SendDate: ' + FormatDateSafe(AMetadata.SendDate));

  if Assigned(AMetadata.DeliveryChannel) then
  begin
    ATargetMemo.Lines.Add('DeliveryChannel.Name: ' + AMetadata.DeliveryChannel.Name);
    ATargetMemo.Lines.Add('DeliveryChannel.Address: ' + AMetadata.DeliveryChannel.Address);
  end;

  if Assigned(AMetadata.StatusInfo) then
    AppendStatusInfo(ATargetMemo, 'Status', AMetadata.StatusInfo);
end;

procedure TForm1.OpenFirstZipEntry(AZipStream: TMemoryStream; ATargetMemo: TMemo;
  ATargetBrowser: TEdgeBrowser);
var
  lExtracted: TMemoryStream;
  lZipError: TTraffiqxError;
  lTempFile, lExt: string;
begin
  lExtracted := nil;
  lZipError := nil;
  if not TTraffiqxHelper.ExtractFirstFileFromZip(AZipStream, lExtracted, lZipError) then
  begin
    try
      if Assigned(ATargetMemo) then
      begin
        ATargetMemo.Lines.Add('Zip-Fehler: ' + lZipError.Title);
        ATargetMemo.Lines.Add('Status: ' + lZipError.Status.ToString);
        ATargetMemo.Lines.Add('Detail: ' + lZipError.Detail);
      end;
    finally
      lZipError.Free;
    end;
    Exit;
  end;

  try
    lExt := GuessExtension(lExtracted);
    lTempFile := TPath.ChangeExtension(TPath.GetTempFileName, lExt);

    lExtracted.Position := 0;
    lExtracted.SaveToFile(lTempFile);

    if Assigned(ATargetMemo) then
    begin
      ATargetMemo.Lines.Add('Dokument gespeichert unter: ' + lTempFile);
      ATargetMemo.Lines.Add('Erkannte Extension: ' + lExt);
    end;

    if Assigned(ATargetBrowser) then
      ATargetBrowser.Navigate(ToFileUrl(lTempFile));
  finally
    lExtracted.Free;
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  lEnv : TStringList;
  lPrefix: string;
begin
  FConfigurationPath := ExtractFilePath(ExtractFileDir(ExtractFileDir(ExtractFileDir(ExtractFileDir(Application.ExeName)))));
  FConfiguration := TIniFile.Create(FConfigurationPath+'cfg.ini');

  PageControl1.ActivePageIndex := FConfiguration.ReadInteger('provider','index',0);

  edAccessTokenReference[1] := edB4ValueAccessToken;
  edAccessTokenReference[2] := Edit3;
  edAccessTokenReference[3] := Edit5;
  edAccessTokenReference[4] := edDatevAccessToken;
  edAccessTokenReference[5] := Edit9;
  edAccessTokenReference[6] := Edit11;
  edAccessTokenReference[7] := Edit13;
  edAccessTokenReference[8] := Edit15;
  edAccessTokenReference[9] := LabeledEdit1;

  edRefreshTokenReference[1] := edB4ValueRefreshToken;
  edRefreshTokenReference[2] := Edit4;
  edRefreshTokenReference[3] := Edit6;
  edRefreshTokenReference[4] := edDatevRefreshToken;
  edRefreshTokenReference[5] := Edit10;
  edRefreshTokenReference[6] := Edit12;
  edRefreshTokenReference[7] := Edit14;
  edRefreshTokenReference[8] := Edit16;
  edRefreshTokenReference[9] := Edit20;

  edTraffiqxIDReference[1]   := Edit1;
  edTraffiqxIDReference[2]   := Edit2;
  edTraffiqxIDReference[3]   := Edit7;
  edTraffiqxIDReference[4]   := edDatevTraffiqxID;
  edTraffiqxIDReference[5]   := Edit8;
  edTraffiqxIDReference[6]   := Edit17;
  edTraffiqxIDReference[7]   := Edit18;
  edTraffiqxIDReference[8]   := Edit19;
  edTraffiqxIDReference[9]   := Edit21;

  // Tokens nie im Klartext anzeigen (Bildschirmfotos, Fernwartung)
  for var i : Integer := 1 to 9 do
  begin
    edAccessTokenReference[i].PasswordChar := '*';
    edRefreshTokenReference[i].PasswordChar := '*';
  end;

  // Technisches HTTP-Protokoll: eine Datei pro Tag unter client\http-log\
  // (in einer echten Anwendung ein gemeinsames Verzeichnis aller Arbeitsplaetze)
  var lLogDir : String := FConfigurationPath + 'http-log' + PathDelim;
  TTraffiqxHttpLog.ResolveDirectory :=
    function: String
    begin
      Result := lLogDir;
    end;

  lEnv := TStringList.Create;
  try
    if FileExists(ExtractFilePath(ExtractFileDir(FConfigurationPath))+'.env') then
      lEnv.LoadFromFile(ExtractFilePath(ExtractFileDir(FConfigurationPath))+'.env',TEncoding.UTF8);

    for var i : Integer := 1 to 9 do
    begin
      FTIA[i] := TTRAFFIQXInvoiceAPI.Create;
      FTIA[i].OnPollingCompleted := HandlePollingCompleted;
      // Technisches HTTP-Protokoll (intf.TRAFFIQXHttpLog), Verzeichnis siehe oben
      TTraffiqxHttpLog.Attach(FTIA[i]);
      FTIA[i].ProviderType := TTraffiqxProviderType(i);
      FTIA[i].Environment := DefaultEnvironmentForProvider(FTIA[i].ProviderType);

      lPrefix := ProviderEnvPrefix(FTIA[i].ProviderType);

      //Config
      FTIA[i].AccessToken := ReadToken(lPrefix,'accesstoken');
      FTIA[i].RefreshToken := ReadToken(lPrefix,'refreshtoken');
      FTIA[i].AccessTokenExpiresAt := FConfiguration.ReadFloat(lPrefix,'accesstokenexpiresat',0);
      FTIA[i].RefreshTokenExpiresAt := FConfiguration.ReadFloat(lPrefix,'refreshtokenexpiresat',0);

      //Env
      FTIA[i].ClientID := lEnv.Values[lPrefix + '_CLIENT_ID'];
      FTIA[i].ClientSecret := lEnv.Values[lPrefix + '_CLIENT_SECRET'];
      FTIA[i].TRAFFIQXId := lEnv.Values[lPrefix + '_TRAFFIQX_ID'];
      FTIA[i].Scope := lEnv.Values[lPrefix + '_SCOPE'];
      FTIA[i].AppDisplayName := lEnv.Values[lPrefix + '_APP_NAME'];  // Bei DATEV-Providern muss der Name exakt der registrierten App entsprechen.
      // Adresse des eigenen Brokers (siehe README, "OAuth2-Broker Einrichten")
      FTIA[i].OAuth2BrokerCallbackUri := lEnv.Values['OAUTH2_BROKER_CALLBACK_URI'];
      FTIA[i].OAuth2BrokerApiKey := lEnv.Values['OAUTH2_BROKER_API_KEY'];
      FXRechnungDistributionDir := lEnv.Values['XRECHNUNG_DISTRIBUTION_DIR'];

      //View
      edAccessTokenReference[i].Text := FTIA[i].AccessToken;
      edAccessTokenReference[i].EditLabel.Caption := 'expires at: '+DateTimeToStr(FTIA[i].AccessTokenExpiresAt);
      edRefreshTokenReference[i].Text := FTIA[i].RefreshToken;
      edTraffiqxIDReference[i].Text := FTIA[i].TRAFFIQXId;
    end;
  finally
    LEnv.Free;
  end;

  PopulateOutboxTestCases;
end;

procedure TForm1.PopulateOutboxTestCases;
var
  LScenarioIndex: Integer;
  LAddressIndex: Integer;
  LDocumentIndex: Integer;
  LXmlPath: string;
  LPdfPath: string;
begin
  if ListView3 = nil then
    Exit;

  if ListView3.Columns.Count = 0 then
  begin
    ListView3.ViewStyle := vsReport;
    ListView3.RowSelect := True;
    with ListView3.Columns.Add do begin Caption := 'Szenario'; Width := 90; end;
    with ListView3.Columns.Add do begin Caption := 'Sendevariante'; Width := 150; end;
    with ListView3.Columns.Add do begin Caption := 'Dokumenttyp'; Width := 130; end;
    with ListView3.Columns.Add do begin Caption := 'Vorhanden'; Width := 80; end;
    with ListView3.Columns.Add do begin Caption := 'XML'; Width := 420; end;
    with ListView3.Columns.Add do begin Caption := 'PDF'; Width := 420; end;
  end;

  ListView3.Items.BeginUpdate;
  try
    ListView3.Items.Clear;
    for LScenarioIndex := Low(SANDBOX_SCENARIOS) to High(SANDBOX_SCENARIOS) do
    begin
      for LAddressIndex := Low(RECIPIENT_ADDRESS_CASES) to High(RECIPIENT_ADDRESS_CASES) do
      begin
        for LDocumentIndex := Low(DOCUMENT_VARIANT_CASES) to High(DOCUMENT_VARIANT_CASES) do
        begin
          LXmlPath := BuildOutboxTestCaseXmlPath(SANDBOX_SCENARIOS[LScenarioIndex],
            RECIPIENT_ADDRESS_CASES[LAddressIndex],DOCUMENT_VARIANT_CASES[LDocumentIndex]);
          LPdfPath := ChangeFileExt(LXmlPath,'.pdf');

          with ListView3.Items.Add do
          begin
            Caption := SANDBOX_SCENARIOS[LScenarioIndex].ScenarioId;
            SubItems.Add(RECIPIENT_ADDRESS_CASES[LAddressIndex].DisplayName);
            SubItems.Add(DOCUMENT_VARIANT_CASES[LDocumentIndex].DisplayName);
            SubItems.Add(BoolToStr(FileExists(LXmlPath) and FileExists(LPdfPath), True));
            SubItems.Add(LXmlPath);
            SubItems.Add(LPdfPath);
          end;
        end;
      end;
    end;
  finally
    ListView3.Items.EndUpdate;
  end;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  FConfiguration.WriteInteger('provider','index',PageControl1.ActivePageIndex);
  FConfiguration.UpdateFile;
  FConfiguration.Free;
  for var i : Integer := 1 to 9 do
    FTIA[i].Free;
end;

procedure TForm1.HandlePollingCompleted(const AResult: TTraffiqxPollResult; ASender : TTRAFFIQXInvoiceAPI);
var
  lPrefix : String;
  LErrorMessage: string;
  LProviderIndex: Integer;
  LConnectionError: TTraffiqxError;
  LRevocationError: TTraffiqxError;
begin
  case AResult.Status of
    psSuccess:
      begin
        lPrefix := ProviderEnvPrefix(ASender.ProviderType);
        LProviderIndex := Integer(ASender.ProviderType);

        edAccessTokenReference[LProviderIndex].Text := ASender.AccessToken;
        edAccessTokenReference[LProviderIndex].EditLabel.Caption := 'expires at: '+DateTimeToStr(ASender.AccessTokenExpiresAt);
        edRefreshTokenReference[LProviderIndex].Text := ASender.RefreshToken;

        WriteToken(lPrefix,'accesstoken',ASender.AccessToken);
        WriteToken(lPrefix,'refreshtoken',ASender.RefreshToken);
        FConfiguration.WriteFloat(lPrefix,'accesstokenexpiresat',ASender.AccessTokenExpiresAt);
        FConfiguration.WriteFloat(lPrefix,'refreshtokenexpiresat',ASender.RefreshTokenExpiresAt);
        FConfiguration.UpdateFile;
        Memo1.Lines.Add('Polling abgeschlossen: Tokens aktualisiert.');

        LConnectionError := nil;
        if ASender.CheckConnectionAccess(LConnectionError) then
          Memo1.Lines.Add('Verbindungscheck erfolgreich: Inbox und Outbox sind erreichbar.')
        else
        begin
          Memo1.Lines.Add('Verbindungscheck fehlgeschlagen. Tokens werden widerrufen.');
          try
            ShowApiError(LConnectionError);
          finally
            LConnectionError.Free;
          end;

          LRevocationError := nil;
          try
            if ASender.RevokeTokens(LRevocationError) then
              Memo1.Lines.Add('Token-Revocation erfolgreich abgeschlossen.')
            else
            begin
              Memo1.Lines.Add('Token-Revocation konnte nicht abgeschlossen werden.');
              if Assigned(LRevocationError) then
                ShowApiError(LRevocationError);
            end;
          finally
            LRevocationError.Free;
          end;

          ASender.AccessToken := '';
          ASender.RefreshToken := '';
          ASender.AccessTokenExpiresAt := 0;
          ASender.RefreshTokenExpiresAt := 0;
          edAccessTokenReference[LProviderIndex].Text := '';
          edAccessTokenReference[LProviderIndex].EditLabel.Caption := 'expires at: ';
          edRefreshTokenReference[LProviderIndex].Text := '';
          WriteToken(lPrefix,'accesstoken','');
          WriteToken(lPrefix,'refreshtoken','');
          FConfiguration.WriteFloat(lPrefix,'accesstokenexpiresat',0);
          FConfiguration.WriteFloat(lPrefix,'refreshtokenexpiresat',0);
          FConfiguration.UpdateFile;
        end;
      end;
    psError:
      begin
        LErrorMessage := Trim(AResult.ErrorCode + ' ' + AResult.ErrorDescription);
        Memo1.Lines.Add('Polling Fehler: ' + LErrorMessage);
        if IsReloginRequiredMessage(LErrorMessage) then
          ShowReloginHint(LErrorMessage);
      end;
    psTimeout:
      Memo1.Lines.Add('Polling Timeout: keine Rueckmeldung vom Broker.');
    psCancelled:
      Memo1.Lines.Add('Polling abgebrochen.');
  else
    Memo1.Lines.Add('Polling Status: '+GetEnumName(TypeInfo(TTraffiqxPollStatus), Ord(AResult.Status)));
  end;
end;

procedure TForm1.btGetInboxDocumentMetadataClick(Sender: TObject);
var
  lApiResult : TTraffiqxInboxDocumentMetadata;
  lApiError: TTraffiqxError;
  lTIA : TTRAFFIQXInvoiceAPI;
  lDocumentId: string;
  function FormatDateSafe(const ADate: TDateTime): string;
  begin
    if ADate = 0 then
      Result := ''
    else
      Result := DateTimeToStr(ADate);
  end;
begin
  if ListView1.Selected = nil then
  begin
    Memo1.Lines.Text := 'Bitte zuerst ein Dokument in der Liste markieren.';
    Exit;
  end;

  lDocumentId := ListView1.Selected.Caption;
  lTIA := FTIA[PageControl1.ActivePageIndex+1];
  Memo1.Clear;

  if lTIA.GetInboxDocumentMetadata(lDocumentId, lApiResult, lApiError) then
  try
    Memo1.Lines.Clear;
    Memo1.Lines.Add('InvoiceDate: ' + FormatDateSafe(lApiResult.InvoiceDate));
    Memo1.Lines.Add('InvoiceNumber: ' + lApiResult.InvoiceNumber);
    Memo1.Lines.Add('GrossTotal: ' + FormatFloat('0.00##', lApiResult.GrossTotal));
    Memo1.Lines.Add('CurrencyCode: ' + lApiResult.CurrencyCode);
    Memo1.Lines.Add('SellerName: ' + lApiResult.SellerName);
    Memo1.Lines.Add('BuyerName: ' + lApiResult.BuyerName);
    Memo1.Lines.Add('InvoiceType: ' + lApiResult.InvoiceType);
    Memo1.Lines.Add('DocumentFormat: ' + lApiResult.DocumentFormat);
    Memo1.Lines.Add('DateOfReceipt: ' + FormatDateSafe(lApiResult.DateOfReceipt));
    Memo1.Lines.Add('EN16931Compliant: ' + BoolToStr(lApiResult.EN16931Compliant, True));
    Memo1.Lines.Add('Downloaded: ' + BoolToStr(lApiResult.Downloaded, True));
    Memo1.Lines.Add('');
    Memo1.Lines.Add(lApiResult.ToJson.ToJSON);
  finally
    lApiResult.Free;
  end
  else
  begin
    try
      ShowApiError(lApiError);
    finally
      lApiError.Free;
    end;
  end;
end;

procedure TForm1.btGetOutboxDocumentIdsClick(Sender: TObject);
var
  lApiResult : TTraffiqxOutboxDocumentList;
  lApiError: TTraffiqxError;
  lTIA : TTRAFFIQXInvoiceAPI;
begin
  lTIA := FTIA[PageControl1.ActivePageIndex+1];
  Memo1.Clear;

  if lTIA.GetOutboxDocumentIds(lApiResult, lApiError) then
  try
    // Erfolg: lApiResult nutzen
    if ListView2.Columns.Count = 0 then
    begin
      ListView2.ViewStyle := vsReport;
      with ListView2.Columns.Add do begin Caption := 'Document ID'; Width := 240; end;
      with ListView2.Columns.Add do begin Caption := 'Status';      Width := 140; end;
      with ListView2.Columns.Add do begin Caption := 'Downloaded';  Width := 100; end;
      with ListView2.Columns.Add do begin Caption := 'Href';        Width := 620; end;
    end;

    ListView2.Items.BeginUpdate;
    try
      ListView2.Items.Clear;
      for var lDoc in lApiResult do
      begin
        with ListView2.Items.Add do
        begin
          Caption := lDoc.DocumentId;
          SubItems.Add(TTraffiqxDocumentStatusHelper.ToDisplayString(lDoc.ParsedStatus));
          SubItems.Add(BoolToStr(lDoc.Downloaded, True));
          SubItems.Add(lDoc.Href);
        end;
      end;
    finally
      ListView2.Items.EndUpdate;
    end;

    Memo3.Lines.Text := lTIA.LastRawContentReceived;
  finally
    lApiResult.Free;
  end
  else
  begin
    try
      // Fehler behandeln, z.B. Log oder Anzeige
      ShowApiError(lApiError);
    finally
      lApiError.Free;
    end;
  end;
end;

procedure TForm1.btGetOutboxDocumentMetadataClickClick(Sender: TObject);
var
  lApiResult : TTraffiqxOutboxMetadata;
  lApiError: TTraffiqxError;
  lTIA : TTRAFFIQXInvoiceAPI;
  lDocumentId: string;
begin
  if ListView2.Selected = nil then
  begin
    Memo3.Lines.Text := 'Bitte zuerst ein Dokument in der Outbox-Liste markieren.';
    Exit;
  end;

  lDocumentId := ListView2.Selected.Caption;
  lTIA := FTIA[PageControl1.ActivePageIndex+1];
  Memo3.Clear;

  if lTIA.GetOutboxDocumentMetadata(lDocumentId, lApiResult, lApiError) then
  try
    Memo3.Lines.Clear;
    AppendOutboxMetadata(Memo3, lApiResult);
    Memo3.Lines.Add('');
    Memo3.Lines.Add(lTIA.LastRawContentReceived);
  finally
    lApiResult.Free;
  end
  else
  begin
    try
      ShowApiError(lApiError);
    finally
      lApiError.Free;
    end;
  end;
end;

procedure TForm1.btGetOutboxDocumentStatusClick(Sender: TObject);
var
  lStatus : TTraffiqxInboxDocumentStatusInfo;
  lApiError: TTraffiqxError;
  lTIA : TTRAFFIQXInvoiceAPI;
  lDocumentId: string;
begin
  if ListView2.Selected = nil then
  begin
    Memo3.Lines.Text := 'Bitte zuerst ein Dokument in der Outbox-Liste markieren.';
    Exit;
  end;

  lDocumentId := ListView2.Selected.Caption;
  lTIA := FTIA[PageControl1.ActivePageIndex+1];
  Memo3.Clear;

  if lTIA.GetOutboxDocumentStatus(lDocumentId, lStatus, lApiError) then
  try
    AppendStatusInfo(Memo3, 'Status', lStatus);
  finally
    lStatus.Free;
  end
  else
  begin
    try
      ShowApiError(lApiError);
    finally
      lApiError.Free;
    end;
  end;
end;

procedure TForm1.btLoginClick(Sender: TObject);
begin
  if FTIA[PageControl1.ActivePageIndex+1].OAuth2BrokerCallbackUri = '' then
  begin
    Memo1.Lines.Add('OAUTH2_BROKER_CALLBACK_URI fehlt in der .env (Adresse des eigenen Brokers).');
    exit;
  end;

  FTIA[PageControl1.ActivePageIndex+1].Environment :=
    DefaultEnvironmentForProvider(FTIA[PageControl1.ActivePageIndex+1].ProviderType);

  if not FTIA[PageControl1.ActivePageIndex+1].TryFetchWellKnownEndpoints then
    Memo1.Lines.Add('Fehler beim Abrufen der well-known-Endpunkte - Default wird genommen.');

  if not FTIA[PageControl1.ActivePageIndex+1].StartAuth then
    exit;

  FTIA[PageControl1.ActivePageIndex+1].BeginPolling;

  Memo1.Lines.Add('Login gestartet: '+DateTimeToStr(Now)+' '+ProviderEnvPrefix(FTIA[PageControl1.ActivePageIndex+1].ProviderType));
  Memo1.Lines.Add('  Warten auf Abschluss des OAuth-Flows...');
//  if FTIA.TokenIssuer <> '' then
//    Memo1.Lines.Add('  Issuer: '+FTIA.TokenIssuer);
//  if FTIA.TokenSubject <> '' then
//    Memo1.Lines.Add('  Subject: '+FTIA.TokenSubject);
//  if FTIA.TokenAudience <> '' then
//    Memo1.Lines.Add('  Audience: '+FTIA.TokenAudience);
//  if FTIA.TokenExpiration > 0 then
//    Memo1.Lines.Add('  Expires (UTC): '+FormatDateTime('yyyy-mm-dd hh:nn:ss', FTIA.TokenExpiration));
//  if FTIA.TokenScopes.Count > 0 then
//    Memo1.Lines.Add('  Scopes: '+StringReplace(FTIA.TokenScopes.CommaText, ',', ', ', [rfReplaceAll]));
//  if FTIA.TokenParseError <> '' then
//    Memo1.Lines.Add('  TokenParseError: '+FTIA.TokenParseError);
end;

procedure TForm1.btRefreshTokenClick(Sender: TObject);
var
  lPrefix : String;
  lTIA: TTRAFFIQXInvoiceAPI;
begin
  lTIA := FTIA[PageControl1.ActivePageIndex+1];

  if not lTIA.TryFetchWellKnownEndpoints then
    Memo1.Lines.Add('Fehler beim Abrufen der well-known-Endpunkte - Default wird genommen.');

  try
    if not lTIA.RefreshAccessToken then
      Exit;
  except
    on E: Exception do
    begin
      Memo1.Lines.Add('Refresh Fehler: ' + E.Message);
      if IsReloginRequiredMessage(E.Message) then
        ShowReloginHint(E.Message)
      else
        MessageDlg(E.Message, mtError, [mbOK], 0);
      Exit;
    end;
  end;

  lPrefix := ProviderEnvPrefix(lTIA.ProviderType);

  edAccessTokenReference[PageControl1.ActivePageIndex+1].Text := lTIA.AccessToken;
  edAccessTokenReference[PageControl1.ActivePageIndex+1].EditLabel.Caption := 'expires at: ' + DateTimeToStr(lTIA.AccessTokenExpiresAt);
  edRefreshTokenReference[PageControl1.ActivePageIndex+1].Text := lTIA.RefreshToken;

  WriteToken(lPrefix,'accesstoken',lTIA.AccessToken);
  WriteToken(lPrefix,'refreshtoken',lTIA.RefreshToken);
  FConfiguration.WriteFloat(lPrefix,'accesstokenexpiresat',lTIA.AccessTokenExpiresAt);
  FConfiguration.WriteFloat(lPrefix,'refreshtokenexpiresat',lTIA.RefreshTokenExpiresAt);
  FConfiguration.UpdateFile;

  Memo1.Lines.Add('Refresh: '+DateTimeToStr(now));
  // Nur Ablaufzeiten und Fingerabdruck protokollieren, nie die Tokens selbst
  Memo1.Lines.Add('  Accesstoken expires at ' + DateTimeToStr(lTIA.AccessTokenExpiresAt));
  Memo1.Lines.Add('  Refreshtoken (' + TTraffiqxTokenProtection.Fingerprint(lTIA.RefreshToken) + ') expires at ' + DateTimeToStr(lTIA.RefreshTokenExpiresAt));
end;

procedure TForm1.btUploadStructuredDataClick(Sender: TObject);
var
  lUploadResult : TTraffiqxUploadResult;
  lApiError: TTraffiqxError;
  lTIA : TTRAFFIQXInvoiceAPI;
  lDocument,lDocumentPdf: TMemoryStream;
  lDeliveryParams : TTraffiqxDeliveryParamameter;
  LStructuredXmlPath: string;
begin
  lTIA := FTIA[PageControl1.ActivePageIndex+1];
  Memo3.Clear;

  lDocument:= TMemoryStream.Create;
  lDocumentPdf:= TMemoryStream.Create;
  try
  try
    LStructuredXmlPath := TPath.GetFullPath('..\..\..\..\..\testdata\sbsz120-cii-extended-232.xml');
    if not FileExists(LStructuredXmlPath) then
      raise Exception.Create('Testdatei nicht gefunden: ' + LStructuredXmlPath);

    lDocument.LoadFromFile(LStructuredXmlPath);
    lDocumentPdf.LoadFromFile(TestDataPath('XRechnung-UBL-Test.pdf'));
    lDeliveryParams := Default(TTraffiqxDeliveryParamameter);
    lDeliveryParams.PreferredFormat := pfNone; //TODO im Init

    if lTIA.UploadStructuredData(lDocument, lDocumentPdf, ExtractFilename(LStructuredXmlPath), 'XRechnung-UBL-Test.pdf', lDeliveryParams.ToJsonString, lUploadResult, lApiError) then
    try
      //Memo3.Lines.Add('StructuredTestCase: ' + cbStructuredOutboxTestCase.Text);
      //Memo3.Lines.Add('Expected: ' + StructuredOutboxScenarioHint);
      Memo3.Lines.Add('SourceFile: ' + LStructuredXmlPath);
      Memo3.Lines.Add('DocumentId: ' + lUploadResult.DocumentId);
      Memo3.Lines.Add('Href: ' + lUploadResult.Href);
    finally
      lUploadResult.Free;
    end
    else
    begin
      try
        ShowApiError(lApiError);
      finally
        lApiError.Free;
      end;
    end;
  finally
    lDocumentPdf.Free;
    lDocument.Free;
  end;
  except
    on E: Exception do
      MessageDlg(E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TForm1.btUploadZugferdDataClick(Sender: TObject);
var
  lUploadResult : TTraffiqxUploadResult;
  lApiError: TTraffiqxError;
  lTIA : TTRAFFIQXInvoiceAPI;
  lDocument: TMemoryStream;
  lDeliveryParams : TTraffiqxDeliveryParamameter;
  LZugferdPdfPath: string;
begin
  lTIA := FTIA[PageControl1.ActivePageIndex+1];
  Memo3.Clear;

  lDocument:= TMemoryStream.Create;
  try
  try
    //LZugferdPdfPath := TPath.GetFullPath('..\..\..\..\..\testdata\sbsz110-cii-en16931-232.pdf');
    LZugferdPdfPath := TPath.GetFullPath('..\..\..\..\..\testdata\sbsz120-cii-extended-232.pdf');
    if not FileExists(LZugferdPdfPath) then
      raise Exception.Create('Testdatei nicht gefunden: ' + LZugferdPdfPath);

    lDocument.LoadFromFile(LZugferdPdfPath);
    lDeliveryParams := Default(TTraffiqxDeliveryParamameter);
    lDeliveryParams.PreferredFormat := pfNone; //TODO im Init

    if lTIA.UploadZugferdData(lDocument, ExtractFilename(LZugferdPdfPath), lDeliveryParams.ToJsonString, lUploadResult, lApiError) then
    try
      //Memo3.Lines.Add('ZugferdTestCase: ' + cbZugferdOutboxTestCase.Text);
      //Memo3.Lines.Add('Expected: ' + ZugferdOutboxScenarioHint);
      Memo3.Lines.Add('SourceFile: ' + LZugferdPdfPath);
      Memo3.Lines.Add('DocumentId: ' + lUploadResult.DocumentId);
      Memo3.Lines.Add('Href: ' + lUploadResult.Href);
    finally
      lUploadResult.Free;
    end
    else
    begin
      try
        ShowApiError(lApiError);
      finally
        lApiError.Free;
      end;
    end;
  finally
    lDocument.Free;
  end;
  except
    on E: Exception do
      MessageDlg(E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TForm1.RadioGroup1Click(Sender: TObject);
begin
  RadioButton11.Enabled := (RadioGroup1.ItemIndex in [1,2]); if not RadioButton11.Enabled then if RadioButton11.Checked then RadioButton1.Checked := true;
  RadioButton12.Enabled := (RadioGroup1.ItemIndex in [0]);   if not RadioButton12.Enabled then if RadioButton12.Checked then RadioButton1.Checked := true;
  RadioButton13.Enabled := (RadioGroup1.ItemIndex in [0]);   if not RadioButton13.Enabled then if RadioButton13.Checked then RadioButton1.Checked := true;
end;

procedure TForm1.Button1Click(Sender: TObject);
var
  lApiResult : TTraffiqxInboxDocumentList;
  lApiError: TTraffiqxError;
  lTIA : TTRAFFIQXInvoiceAPI;
  lMetaData : TTraffiqxInboxDocumentMetadata;
  lStr : TMemoryStream;
begin
  lTIA := FTIA[4];
  Memo2.Clear;

  if (RadioGroup1.ItemIndex in [0]) then
  if RadioButton11.Checked then
    exit;

  if (RadioGroup1.ItemIndex in [1,2]) then
  if RadioButton12.Checked or RadioButton13.Checked then
    exit;


  if RadioButton1.Checked then lTIA.TRAFFIQXId := '1000000000010'
  else
  if RadioButton2.Checked then lTIA.TRAFFIQXId := '1000000000004'
  else
  if RadioButton3.Checked then lTIA.TRAFFIQXId := '1000000000011'
  else
  if RadioButton4.Checked then lTIA.TRAFFIQXId := '1000000000000'
  else
  if RadioButton5.Checked then lTIA.TRAFFIQXId := '1000000000003'
  else
  if RadioButton6.Checked then lTIA.TRAFFIQXId := '1000000000005'
  else
  if RadioButton7.Checked then lTIA.TRAFFIQXId := '1000000000012'
  else
  if RadioButton8.Checked then lTIA.TRAFFIQXId := '1000000000001'
  else
  if RadioButton9.Checked then lTIA.TRAFFIQXId := '1000000000006'
  else
  if RadioButton10.Checked then lTIA.TRAFFIQXId := '1000000000002'
  else
  if RadioButton11.Checked then lTIA.TRAFFIQXId := '1000000000013'
  else
  if RadioButton12.Checked then lTIA.TRAFFIQXId := '1000000000018'
  else
  if RadioButton13.Checked then lTIA.TRAFFIQXId := '1000000000017';

  case RadioGroup1.ItemIndex of
    0 :
    begin
      if lTIA.GetInboxDocumentIds(lApiResult, lApiError) then
      try
        // Erfolg: lApiResult nutzen
        Memo2.Lines.Text := lApiResult.Count.ToString;
      finally
        lApiResult.Free;
      end
      else
      begin
        try
          // Fehler behandeln, z.B. Log oder Anzeige
          ShowApiError(lApiError);
        finally
          lApiError.Free;
        end;
      end;
    end;
    1 :
    begin
      if lTIA.GetInboxDocumentMetadata('bd0c3402-f738-4d74-9887-53872a64bfb8', lMetaData, lApiError) then
      try
        // Erfolg: lMetaData nutzen
        Memo2.Lines.Text := lMetaData.InvoiceNumber;
      finally
        lMetaData.Free;
      end
      else
      begin
        try
          // Fehler behandeln, z.B. Log oder Anzeige
          ShowApiError(lApiError);
        finally
          lApiError.Free;
        end;
      end;
    end;
    2 :
    begin
      if lTIA.DownloadInboxDocument('bd0c3402-f738-4d74-9887-53872a64bfb8', lStr, lApiError) then
      try
        // Erfolg: lStr nutzen
        lStr.Position := 0;
        Memo2.Lines.LoadFromStream(lStr);
      finally
        lStr.Free;
      end
      else
      begin
        try
          // Fehler behandeln, z.B. Log oder Anzeige
          ShowApiError(lApiError);
        finally
          lApiError.Free;
        end;
      end;
    end;
  end;
end;

procedure TForm1.Button2Click(Sender: TObject);
var
  inv : TInvoice;
  lFilename : String;
  lScenarioIndex: Integer;
  lAddressIndex: Integer;
  lDocumentIndex: Integer;
  lGeneratedCount: Integer;

  procedure ApplyCommonSenderData;
  begin
    inv.AccountingSupplierParty.ContactElectronicMail := 'info@landrix.de';
    inv.AccountingSupplierParty.ElectronicAddressSellerBuyer := 'info@landrix.de';
    inv.AccountingSupplierParty.ElectronicAddressSellerBuyerSchemeID := 'EM';
  end;

  procedure ApplyRecipientAddress(const AAddressCase: TRecipientAddressCase);
  begin
    inv.BuyerReference := AAddressCase.BuyerReference; // BT-10
    inv.AccountingCustomerParty.ContactElectronicMail := 'Muster.Tester@datev.de';
    inv.AccountingCustomerParty.ElectronicAddressSellerBuyer := AAddressCase.CustomerEndpointId; // BT-49
    inv.AccountingCustomerParty.ElectronicAddressSellerBuyerSchemeID := AAddressCase.CustomerEndpointSchemeId;
  end;

  procedure CreatePdfFromXRechnung(const AXmlFilename: string);
  {$IFNDEF WPDF}
  var
    cmdoutput: string;
    pdfresult: TMemoryStream;
    lDist: string;
  {$ENDIF}
  begin
    {$IFDEF WPDF}
    WPDF_Start('','');
    var pdf : TWPPDFPrinter := TWPPDFPrinter.Create(Self);
    pdf.PDFReadMode := wpdfStandard;
    pdf.PDFAMode := wpdfaLevel3B;
    pdf.Encryption := [];
    pdf.Security := wpp40bit;
    pdf.InMemoryMode := false;
    pdf.Filename := ChangeFileExt(AXmlFilename,'.pdf');
    pdf.BeginDoc;
    pdf.StartPage(595, 842, 72, 72, 0); // A4 Hochformat
    pdf.Canvas.TextOut(10,10,ExtractFilename(AXmlFilename));
    pdf.EndPage;
    pdf.EndDoc;
    pdf.Free;
    {$ELSE}
    pdfresult := nil;
    if FXRechnungDistributionDir = '' then
      raise Exception.Create('XRECHNUNG_DISTRIBUTION_DIR fehlt in der .env (Distribution-Verzeichnis von XRechnung-for-Delphi).');
    lDist := IncludeTrailingPathDelimiter(FXRechnungDistributionDir);
    GetXRechnungValidationHelperJava.SetJavaRuntimeEnvironmentPath(lDist + 'java\')
      .SetSaxonLibPath(lDist + 'saxon\')
      .SetVisualizationLibPath(lDist + 'visualization30x\')
      .SetFopLibPath(lDist + 'apache-fop\')
      .VisualizeFileAsPdf(AXmlFilename,cmdoutput,pdfresult);

    if pdfresult <> nil then
    try
      pdfresult.SaveToFile(ChangeFileExt(AXmlFilename,'.pdf'));
    finally
      pdfresult.Free;
    end;
    {$ENDIF}
  end;

  procedure CreatePdfA3FromZUGFeRD(AXmlFilename : String; _Extended : Boolean);
  var
    cmdoutput,fn : String;
    pdfresult : TMemoryStream;
    lDist : String;
  begin
    if FXRechnungDistributionDir = '' then
      raise Exception.Create('XRECHNUNG_DISTRIBUTION_DIR fehlt in der .env (Distribution-Verzeichnis von XRechnung-for-Delphi).');
    lDist := IncludeTrailingPathDelimiter(FXRechnungDistributionDir);
    GetXRechnungValidationHelperJava.SetJavaRuntimeEnvironmentPath(lDist + 'java\')
        .SetMustangprojectLibPath(lDist + 'mustangproject\')
        .MustangVisualizeFileAsPdf(AXmlFilename,cmdoutput,pdfresult);

    if pdfresult <> nil then
    begin
      pdfresult.SaveToFile(ChangeFileExt(AXmlFilename,'.pdf'));
      pdfresult.Free;

    GetXRechnungValidationHelperJava.SetJavaRuntimeEnvironmentPath(lDist + 'java\')
        .SetMustangprojectLibPath(lDist + 'mustangproject\')
          .MustangCombinePdfAndXML(ChangeFileExt(AXmlFilename,'.pdf'),AXmlFilename,_Extended,cmdoutput,pdfresult);

      if pdfresult <> nil then
      begin
        pdfresult.SaveToFile(ChangeFileExt(AXmlFilename,'.pdf'));
        pdfresult.Free;
      end;
    end;
  end;

  procedure SaveSandboxCase(const AScenarioCase: TSandboxScenarioCase;
    const AAddressCase: TRecipientAddressCase;
    const ADocumentCase: TDocumentVariantCase; const AFileName: string);
  begin
    inv.ProfileID := AScenarioCase.ScenarioId; // BT-23
    ApplyCommonSenderData;
    ApplyRecipientAddress(AAddressCase);

    DeleteFile(AFileName);
    DeleteFile(ChangeFileExt(AFileName,'.pdf'));

    case ADocumentCase.Kind of
      dvXRechnungCii:
        begin
          TXRechnungInvoiceAdapter.SaveToFile(inv,XRechnungVersion_30x_UNCEFACT,AFileName);
          CreatePdfFromXRechnung(AFileName);
        end;
      dvXRechnungUbl:
        begin
          TXRechnungInvoiceAdapter.SaveToFile(inv,XRechnungVersion_30x_UBL,AFileName);
          CreatePdfFromXRechnung(AFileName);
        end;
    else
      begin
        if AScenarioCase.UseExtended then
          TXRechnungInvoiceAdapter.SaveToFile(inv,ZUGFeRDExtendedVersion_250,AFileName)
        else
          TXRechnungInvoiceAdapter.SaveToFile(inv,ZUGFeRDEN16931Version_250,AFileName);
        CreatePdfA3FromZUGFeRD(AFileName,AScenarioCase.UseExtended);
      end;
    end;
  end;
begin
  {$IFNDEF WPDF}
  if (MessageDlg('XRechnung Belegbilder muessen gueltige PDF/A-3b ohne Anhang sein.'+#13+#10+'Diese kann diese Funktion mit Open Source Mitteln nicht erstellen.', mtWarning, [mbOK, mbCancel], 0) in [mrCancel, mrNone]) then
    exit;
  {$ENDIF}

  inv := TInvoice.Create;
  try
    TInvoiceTestCases.Gesamtbeispiel(inv,0,false,false,false,false);
    lGeneratedCount := 0;
    for lScenarioIndex := Low(SANDBOX_SCENARIOS) to High(SANDBOX_SCENARIOS) do
    begin
      for lAddressIndex := Low(RECIPIENT_ADDRESS_CASES) to High(RECIPIENT_ADDRESS_CASES) do
      begin
        for lDocumentIndex := Low(DOCUMENT_VARIANT_CASES) to High(DOCUMENT_VARIANT_CASES) do
        begin
          lFilename := BuildOutboxTestCaseXmlPath(SANDBOX_SCENARIOS[lScenarioIndex],
            RECIPIENT_ADDRESS_CASES[lAddressIndex],DOCUMENT_VARIANT_CASES[lDocumentIndex]);

          SaveSandboxCase(SANDBOX_SCENARIOS[lScenarioIndex],
            RECIPIENT_ADDRESS_CASES[lAddressIndex],
            DOCUMENT_VARIANT_CASES[lDocumentIndex],lFilename);
          Inc(lGeneratedCount);
        end;
      end;
    end;

    lFilename := TPath.GetFullPath('..\..\..\..\..\testdata\sbsz110-cii-en16931-232.xml');
    SaveSandboxCase(SANDBOX_SCENARIOS[0],RECIPIENT_ADDRESS_CASES[3],DOCUMENT_VARIANT_CASES[2],lFilename);

    lFilename := TPath.GetFullPath('..\..\..\..\..\testdata\sbsz120-cii-extended-232.xml');
    SaveSandboxCase(SANDBOX_SCENARIOS[1],RECIPIENT_ADDRESS_CASES[3],DOCUMENT_VARIANT_CASES[2],lFilename);

    Memo3.Lines.Add('Sandbox-Testdateien erzeugt: ' + lGeneratedCount.ToString);
    Memo3.Lines.Add('Kompatibilitaetsdateien fuer bestehende Upload-Buttons erzeugt: 2');
    PopulateOutboxTestCases;

  finally
    inv.Free;
  end;
end;

procedure TForm1.btDownloadInboxDocumentClick(Sender: TObject);
var
  lApiResult : TMemoryStream;
  lApiError: TTraffiqxError;
  lTIA : TTRAFFIQXInvoiceAPI;
  lDocumentId: string;
begin
  if ListView1.Selected = nil then
  begin
    Memo1.Lines.Text := 'Bitte zuerst ein Dokument in der Liste markieren.';
    Exit;
  end;

  lDocumentId := ListView1.Selected.Caption;
  lTIA := FTIA[PageControl1.ActivePageIndex+1];

  if lTIA.DownloadInboxDocument(lDocumentId, lApiResult, lApiError) then
  try
    Memo1.Lines.Clear;
    OpenFirstZipEntry(lApiResult, Memo1, EdgeBrowser1);
  finally
    lApiResult.Free;
  end
  else
  begin
    try
      ShowApiError(lApiError);
    finally
      lApiError.Free;
    end;
  end;
end;

procedure TForm1.btDownloadOutboxDocumentClick(Sender: TObject);
var
  lApiResult : TMemoryStream;
  lApiError: TTraffiqxError;
  lPendingStatus: TTraffiqxInboxDocumentStatusInfo;
  lWaitStatus: TTraffiqxInboxDocumentStatusInfo;
  lMetadata: TTraffiqxOutboxMetadata;
  lTIA : TTRAFFIQXInvoiceAPI;
  lDocumentId: string;
begin
  if ListView2.Selected = nil then
  begin
    Memo3.Lines.Text := 'Bitte zuerst ein Dokument in der Liste markieren.';
    Exit;
  end;

  lDocumentId := ListView2.Selected.Caption;
  lTIA := FTIA[PageControl1.ActivePageIndex+1];
  lWaitStatus := nil;
  Memo3.Clear;

  Screen.Cursor := crHourGlass;
  try
    if not lTIA.WaitForOutboxDocumentSent(lDocumentId, lWaitStatus, lApiError) then
    begin
      if Assigned(lWaitStatus) then
      begin
        Memo3.Lines.Add('Outbox-Dokument ist noch nicht versandbereit oder fachlich beendet.');
        AppendStatusInfo(Memo3, 'Status', lWaitStatus);
      end;

      if Assigned(lApiError) then
      begin
        try
          ShowApiError(lApiError);
        finally
          lApiError.Free;
        end;
      end;
      Exit;
    end;

  Memo3.Lines.Add('Outbox-Dokument ist im Status "sent".');
    AppendStatusInfo(Memo3, 'Status', lWaitStatus);

    if lTIA.GetOutboxDocumentMetadata(lDocumentId, lMetadata, lApiError) then
    try
      Memo3.Lines.Add('');
      Memo3.Lines.Add('Metadaten zum Originaldokument:');
      AppendOutboxMetadata(Memo3, lMetadata);
    finally
      lMetadata.Free;
    end
    else
    begin
      try
        ShowApiError(lApiError);
      finally
        lApiError.Free;
      end;
      Exit;
    end;
  finally
    Screen.Cursor := crDefault;
  end;

  if lTIA.DownloadOutboxDocument(lDocumentId, lApiResult, lPendingStatus, lApiError) then
  try
    if Assigned(lPendingStatus) then
    begin
      Memo3.Lines.Add('');
      Memo3.Lines.Add('Download noch nicht freigegeben:');
      AppendStatusInfo(Memo3, 'Pending', lPendingStatus);
    end;

    if Assigned(lApiResult) then
    begin
      Memo3.Lines.Add('');
      OpenFirstZipEntry(lApiResult, Memo3, EdgeBrowser2);
    end;
  finally
    if Assigned(lPendingStatus) then
      lPendingStatus.Free;
    if Assigned(lApiResult) then
      lApiResult.Free;
    if Assigned(lWaitStatus) then
      lWaitStatus.Free;
  end
  else
  begin
    try
      ShowApiError(lApiError);
    finally
      lApiError.Free;
      if Assigned(lWaitStatus) then
        lWaitStatus.Free;
    end;
  end;
end;

procedure TForm1.btGetInboxDocumentIdsClick(Sender: TObject);
var
  lApiResult : TTraffiqxInboxDocumentList;
  lApiError: TTraffiqxError;
  lTIA : TTRAFFIQXInvoiceAPI;
begin
  lTIA := FTIA[PageControl1.ActivePageIndex+1];
  Memo1.Clear;

  if lTIA.GetInboxDocumentIds(lApiResult, lApiError) then
  try
    // Erfolg: lApiResult nutzen
    if ListView1.Columns.Count = 0 then
    begin
      ListView1.ViewStyle := vsReport;
      with ListView1.Columns.Add do begin Caption := 'Document ID'; Width := 300; end;
      with ListView1.Columns.Add do begin Caption := 'Downloaded';  Width := 100; end;
      with ListView1.Columns.Add do begin Caption := 'Href';        Width := 700; end;
    end;

    ListView1.Items.BeginUpdate;
    try
      ListView1.Items.Clear;
      for var lDoc in lApiResult do
      begin
        with ListView1.Items.Add do
        begin
          Caption := lDoc.DocumentId;
          SubItems.Add(BoolToStr(lDoc.Downloaded, True));
          SubItems.Add(lDoc.Href);
        end;
      end;
    finally
      ListView1.Items.EndUpdate;
    end;
  finally
    lApiResult.Free;
  end
  else
  begin
    try
      // Fehler behandeln, z.B. Log oder Anzeige
      ShowApiError(lApiError);
    finally
      lApiError.Free;
    end;
  end;
end;

function TForm1.ReadToken(const ASection, AKey: String): String;
var
  lIni : TMemIniFile;
begin
  // TMemIniFile statt FConfiguration (TIniFile): TIniFile.ReadString liest
  // hoechstens 2047 Zeichen, verschluesselte Tokens sind laenger.
  lIni := TMemIniFile.Create(FConfiguration.FileName);
  try
    if not TTraffiqxTokenProtection.UnprotectFromText(
      lIni.ReadString(ASection, AKey, ''), Result) then
      Result := '';
  finally
    lIni.Free;
  end;
end;

procedure TForm1.WriteToken(const ASection, AKey, AValue: String);
begin
  FConfiguration.WriteString(ASection, AKey, TTraffiqxTokenProtection.ProtectToText(AValue));
end;

procedure TForm1.btErrorRateClick(Sender: TObject);
var
  lRate : TTraffiqxErrorRate;
  lText : String;
  lFlushed : Boolean;
begin
  // Im Sample direkt im UI-Thread; eine Anwendung mit Protokoll auf einem
  // Netzlaufwerk wertet im Hintergrund aus (siehe intf.TRAFFIQXHttpLog).
  lFlushed := TTraffiqxHttpLog.Flush;
  if not TTraffiqxHttpLog.GetErrorRate(TDateTime.NowUTC, lRate) then
    lText := 'Kein Protokollverzeichnis festgelegt.'
  else if lRate.Unreachable then
    lText := 'Protokollverzeichnis nicht erreichbar.'
  else if lRate.Requests = 0 then
    lText := 'Keine Anfragen an DATEV protokolliert.'
  else
    lText := Format('Fehlerquote DATEV (14 Tage): %.1f %% (%d von %d Anfragen mit 4xx/5xx, %d ohne Antwort)',
      [lRate.Errors * 100 / lRate.Requests, lRate.Errors, lRate.Requests, lRate.NoResponse])
      + sLineBreak + 'DATEV-Vorgabe: unter 10 %.';
  if lRate.Unreadable > 0 then
    lText := lText + sLineBreak + Format('Unvollstaendig: %d Protokolldatei(en) nicht lesbar.', [lRate.Unreadable]);
  if not lFlushed then
    lText := lText + sLineBreak + 'Unvollstaendig: eigene Eintraege noch nicht geschrieben (Protokolldatei gesperrt?).';
  ShowMessage(lText);
end;

procedure TForm1.Button3Click(Sender: TObject);
var
  LTIA: TTRAFFIQXInvoiceAPI;
  LSelected: TListItem;
  LDocumentKind: TDocumentVariantKind;
  LScenario: string;
  LRoute: string;
  LDocumentType: string;
  LXmlPath: string;
  LPdfPath: string;
  LDeliveryParams: TTraffiqxDeliveryParamameter;
  LUploadResult: TTraffiqxUploadResult;
  LStatus: TTraffiqxInboxDocumentStatusInfo;
  LMetadata: TTraffiqxOutboxMetadata;
  LApiError: TTraffiqxError;
  LXmlStream: TMemoryStream;
  LPdfStream: TMemoryStream;
  LProgressForm: TForm;
  LProgressLabel: TLabel;
  LStartedAt: UInt64;
  LPollIntervalMs: Cardinal;
  LPollCount: Integer;
  LResultText: string;

  procedure UpdateProgress(const AText: string);
  begin
    if Assigned(LProgressLabel) then
    begin
      LProgressLabel.Caption := AText;
      LProgressLabel.Update;
    end;
    Application.ProcessMessages;
  end;

  procedure WaitWithUi(const AIntervalMs: Cardinal);
  var
    LWaitedMs: Cardinal;
  begin
    LWaitedMs := 0;
    while LWaitedMs < AIntervalMs do
    begin
      TThread.Sleep(100);
      Inc(LWaitedMs, 100);
      Application.ProcessMessages;
    end;
  end;

  function BuildStatusText(const AStatus: TTraffiqxInboxDocumentStatusInfo): string;
  var
    LStatusMeaning: string;
    LErrorCodeMeaning: string;
    LErrorDetailsMeaning: string;
  begin
    if AStatus = nil then
      Exit('Status: unbekannt');

    LStatusMeaning := TTraffiqxDocumentStatusHelper.DescribeStatus(AStatus.ParsedStatus);
    LErrorCodeMeaning := TTraffiqxDocumentStatusHelper.DescribeErrorCode(AStatus.ErrorCode);
    LErrorDetailsMeaning := TTraffiqxDocumentStatusHelper.DescribeErrorDetails(AStatus.ErrorDetails);

    Result := 'Status: ' + TTraffiqxDocumentStatusHelper.ToDisplayString(AStatus.ParsedStatus)
      + ' (' + AStatus.Status + ')';
    if LStatusMeaning <> '' then
      Result := Result + sLineBreak + LStatusMeaning;
    if AStatus.ErrorCode <> '' then
      Result := Result + sLineBreak + 'ErrorCode: ' + AStatus.ErrorCode;
    if LErrorCodeMeaning <> '' then
      Result := Result + sLineBreak + LErrorCodeMeaning;
    if AStatus.ErrorDetails <> '' then
      Result := Result + sLineBreak + 'ErrorDetails: ' + AStatus.ErrorDetails;
    if LErrorDetailsMeaning <> '' then
      Result := Result + sLineBreak + LErrorDetailsMeaning;
  end;
begin
  LSelected := ListView3.Selected;
  if LSelected = nil then
  begin
    MessageDlg('Bitte zuerst einen Ausgangsrechnungs-Testfall in der Liste markieren.', mtInformation, [mbOK], 0);
    Exit;
  end;

  if LSelected.SubItems.Count < 5 then
  begin
    MessageDlg('Der markierte Testfall ist unvollstaendig. Bitte die Testfallliste neu laden.', mtError, [mbOK], 0);
    Exit;
  end;

  LScenario := LSelected.Caption;
  LRoute := LSelected.SubItems[0];
  LDocumentType := LSelected.SubItems[1];
  LXmlPath := LSelected.SubItems[3];
  LPdfPath := LSelected.SubItems[4];
  LDocumentKind := DocumentVariantKindFromText(LDocumentType);

  if not FileExists(LXmlPath) then
  begin
    MessageDlg('XML-Testdatei nicht gefunden:' + sLineBreak + LXmlPath + sLineBreak + sLineBreak
      + 'Bitte zuerst die Testdateien mit Button2 erzeugen.', mtWarning, [mbOK], 0);
    Exit;
  end;

  if not FileExists(LPdfPath) then
  begin
    MessageDlg('PDF-Testdatei nicht gefunden:' + sLineBreak + LPdfPath + sLineBreak + sLineBreak
      + 'Bitte zuerst die Testdateien mit Button2 erzeugen.', mtWarning, [mbOK], 0);
    Exit;
  end;

  LTIA := FTIA[PageControl1.ActivePageIndex+1];
  LUploadResult := nil;
  LStatus := nil;
  LMetadata := nil;
  LApiError := nil;
  LXmlStream := nil;
  LPdfStream := nil;
  LProgressForm := nil;
  LProgressLabel := nil;
  LDeliveryParams := Default(TTraffiqxDeliveryParamameter);
  LDeliveryParams.PreferredFormat := pfNone;

  Screen.Cursor := crHourGlass;
  try
    LProgressForm := TForm.Create(Self);
    LProgressForm.BorderStyle := bsDialog;
    LProgressForm.Position := poOwnerFormCenter;
    LProgressForm.Caption := 'Ausgangsrechnung wird verarbeitet';
    LProgressForm.ClientWidth := 520;
    LProgressForm.ClientHeight := 90;

    LProgressLabel := TLabel.Create(LProgressForm);
    LProgressLabel.Parent := LProgressForm;
    LProgressLabel.Left := 16;
    LProgressLabel.Top := 16;
    LProgressLabel.Width := 488;
    LProgressLabel.Height := 60;
    LProgressLabel.WordWrap := True;
    LProgressLabel.Caption := 'Upload wird vorbereitet...';
    LProgressForm.Show;
    Application.ProcessMessages;

    UpdateProgress('Upload laeuft: ' + LScenario + ', ' + LRoute + ', ' + LDocumentType);

    if LDocumentKind = dvZugferdCii then
    begin
      LPdfStream := TMemoryStream.Create;
      LPdfStream.LoadFromFile(LPdfPath);
      if not LTIA.UploadZugferdData(LPdfStream, ExtractFileName(LPdfPath),
        LDeliveryParams.ToJsonString, LUploadResult, LApiError) then
      begin
        ShowApiError(LApiError);
        Exit;
      end;
    end
    else
    begin
      LXmlStream := TMemoryStream.Create;
      LPdfStream := TMemoryStream.Create;
      LXmlStream.LoadFromFile(LXmlPath);
      LPdfStream.LoadFromFile(LPdfPath);
      if not LTIA.UploadStructuredData(LXmlStream, LPdfStream,
        ExtractFileName(LXmlPath), ExtractFileName(LPdfPath),
        LDeliveryParams.ToJsonString, LUploadResult, LApiError) then
      begin
        ShowApiError(LApiError);
        Exit;
      end;
    end;

    UpdateProgress('Upload angenommen. Dokument-ID: ' + LUploadResult.DocumentId
      + sLineBreak + 'Status wird abgefragt...');

    LStartedAt := TThread.GetTickCount64;
    LPollIntervalMs := 2000;
    LPollCount := 0;
    while True do
    begin
      Inc(LPollCount);
      FreeAndNil(LStatus);
      FreeAndNil(LApiError);

      if not LTIA.GetOutboxDocumentStatus(LUploadResult.DocumentId, LStatus, LApiError) then
      begin
        ShowApiError(LApiError);
        Exit;
      end;

      UpdateProgress('Statusabfrage ' + LPollCount.ToString + ': '
        + TTraffiqxDocumentStatusHelper.ToDisplayString(LStatus.ParsedStatus)
        + sLineBreak + 'Dokument-ID: ' + LUploadResult.DocumentId);

      if LStatus.IsSuccessful or LStatus.HasProcessingError then
        Break;

      if (TThread.GetTickCount64 - LStartedAt) >= 180000 then
      begin
        LResultText := 'Timeout beim Warten auf den finalen Outbox-Status.' + sLineBreak
          + BuildStatusText(LStatus);
        MessageDlg(LResultText, mtWarning, [mbOK], 0);
        Exit;
      end;

      WaitWithUi(LPollIntervalMs);
      LPollIntervalMs := Min(LPollIntervalMs * 2, 8000);
    end;

    LResultText := 'Testfall: ' + LScenario + ' / ' + LRoute + ' / ' + LDocumentType + sLineBreak
      + 'Quelle: ' + IfThen(LDocumentKind = dvZugferdCii, LPdfPath, LXmlPath) + sLineBreak
      + 'DocumentId: ' + LUploadResult.DocumentId + sLineBreak
      + BuildStatusText(LStatus);

    if LStatus.IsSuccessful then
    begin
      FreeAndNil(LApiError);
      if LTIA.GetOutboxDocumentMetadata(LUploadResult.DocumentId, LMetadata, LApiError) then
      begin
        try
          LResultText := LResultText + sLineBreak + sLineBreak
            + 'DocumentFormat: ' + LMetadata.DocumentFormat;
          if Assigned(LMetadata.DeliveryChannel) then
            LResultText := LResultText + sLineBreak
              + 'Zustellkanal: ' + LMetadata.DeliveryChannel.Name + ' / '
              + LMetadata.DeliveryChannel.Address;
        finally
          FreeAndNil(LMetadata);
        end;
      end
      else
        FreeAndNil(LApiError);
    end;

    if LStatus.IsSuccessful then
      MessageDlg(LResultText, mtInformation, [mbOK], 0)
    else
      MessageDlg(LResultText, mtWarning, [mbOK], 0);
  finally
    Screen.Cursor := crDefault;
    if Assigned(LProgressForm) then
      LProgressForm.Free;
    if Assigned(LXmlStream) then
      LXmlStream.Free;
    if Assigned(LPdfStream) then
      LPdfStream.Free;
    if Assigned(LUploadResult) then
      LUploadResult.Free;
    if Assigned(LStatus) then
      LStatus.Free;
    if Assigned(LMetadata) then
      LMetadata.Free;
    if Assigned(LApiError) then
      LApiError.Free;
  end;
end;

end.
