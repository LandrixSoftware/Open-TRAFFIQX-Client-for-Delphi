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

unit MiniApp.Storage;

interface

uses
  System.SysUtils, System.Classes, MiniApp.Model;

type
  TMiniAppClientConfig = record
    SourceFile: string;
    ClientID: string;
    ClientSecret: string;
    TraffiqxID: string;
    Scope: string;
    AppDisplayName: string;
    OAuth2BrokerCallbackUri: string;
    OAuth2BrokerApiKey: string;
    XRechnungDistributionDir: string;
  end;

  TMiniAppInvoiceInfo = record
    InvoiceNumber: string;
    CustomerName: string;
    IssueDate: string;
    GrossAmount: Currency;
    DeliveryChannel: string;
  end;

  TMiniAppOutboxState = record
    DocumentID, Status, ChannelIntended, UploadedAt, CheckedAt: string;
    DocumentFormat, SendDate, DeliveryChannel, DeliveryAddress: string;
    ChannelMatches: Boolean;
    MetadataAt, ArchivedAt, LastError: string;
    PreviousDocumentIDs: TArray<string>;
    // Vor dem POST persistieren: auch ein Absturz/Transportfehler sperrt Wiederholung.
    UploadUnconfirmed: Boolean;
  end;

  TMiniAppInboxInfo = record
    SellerName, ReceivedAt, DocumentFormat: string;
    HasMetadata, EN16931Compliant: Boolean;
  end;

  TMiniAppTokens = record
    AccessToken: string;
    RefreshToken: string;
    AccessExpiresAt: TDateTime;
    RefreshExpiresAt: TDateTime;
    RevocationPending: Boolean;
    LoginUnconfirmed: Boolean;
    LoginUnconfirmedAt: TDateTime;
    UserName: string;
    Environment: TMiniAppEnvironment;
    ClientID: string;
    TraffiqxID: string;
  end;

// False: vorhandene Ablage unlesbar; niemals automatisch überschreiben.
function LoadTokens(out ATokens: TMiniAppTokens): Boolean;
procedure SaveTokens(const ATokens: TMiniAppTokens);

function DataDirectory: string;
function OutgoingDirectory: string;
function IncomingDirectory: string;
function HttpLogDirectory: string;
function InvoiceDirectory(const AInvoiceNumber: string): string;
function IncomingDocumentDirectory(const ADocumentID: string): string;
function MasterDataPath: string;
function TokensPath: string;
function PendingInboxPath: string;
function PlaceholderPdfPath: string;
procedure EnsureDataDirectories;
procedure AtomicWriteText(const APath, AText: string);
function LoadClientConfig: TMiniAppClientConfig;
// Reservierung erfolgt vor allen Erzeugungsschritten. Auch bei einer Exception
// enthält AReservedInvoiceNumber die dauerhaft verbrauchte Nummer (E4).
function CreateOutboxInvoice(AData: TMiniAppData; const ACustomer: TMiniAppCustomer;
  AIssueDate: TDate; out AReservedInvoiceNumber: string): string;
function LoadInvoiceInfo(const AInvoiceNumber: string): TMiniAppInvoiceInfo;
function LoadOutbox(const AInvoiceNumber: string): TMiniAppOutboxState;
procedure SaveOutbox(const AInvoiceNumber: string; const AState: TMiniAppOutboxState);
function OutboxStatusRank(const AStatus: string): Integer;
function OutboxDetails(const AState: TMiniAppOutboxState): string;
procedure ArchiveOutboxOriginal(const AInvoiceNumber: string; AZipStream: TStream);

// Vor jedem Inbox-Ablauf die persistente Bindung prüfen; nur ein Worker schreibt.
procedure EnsureInboxContext(AEnvironment: TMiniAppEnvironment; const ATraffiqxID: string);
// Nur der eine Netzwerk-Worker verändert die Offen-Liste.
function LoadPendingInbox: TArray<string>;
procedure MarkInboxPending(const ADocumentID: string; APending: Boolean);
function InboxDocumentStored(const ADocumentID: string): Boolean;
procedure ArchiveInboxDocument(const ADocumentID: string; AZipStream: TStream);
function LoadInboxInfo(const ADocumentID: string): TMiniAppInboxInfo;
procedure SaveInboxMetadata(const ADocumentID, AJson: string);
function FirstInboxFile(const ADocumentID: string): string;

implementation

uses
  Winapi.Windows, System.IOUtils, System.JSON, System.Zip, System.ZLib,
  intf.Invoice, MiniApp.InvoiceBuilder, intf.TRAFFIQXTokenProtection;

function DataDirectory: string;
begin
  Result := TPath.Combine(ExtractFilePath(ParamStr(0)), 'Daten');
end;

function OutgoingDirectory: string;
begin
  Result := TPath.Combine(DataDirectory, 'ausgang');
end;

function IncomingDirectory: string;
begin
  Result := TPath.Combine(DataDirectory, 'eingang');
end;

function HttpLogDirectory: string;
begin
  Result := TPath.Combine(DataDirectory, 'httplog');
end;

function SafeChildDirectory(const AParent, AName: string): string;
var
  LChar: Char;
  LBase: string;
  LIndex: Integer;
begin
  // IDs sind einzelne Ordnernamen: keine Pfade, ADS oder Windows-Gerätenamen.
  if (AName = '') or (Trim(AName) <> AName) or (AName = '.') or
    (AName = '..') or (AName[Length(AName)] = '.') then
    raise EArgumentException.Create('Ungültiger Name für die Dokumentablage.');
  for LChar in AName do
    if (Ord(LChar) < 32) or CharInSet(LChar, ['<', '>', ':', '"', '/', '\', '|', '?', '*']) then
      raise EArgumentException.Create('Ungültiges Zeichen in der Dokumentkennung.');
  LBase := UpperCase(AName);
  LIndex := Pos('.', LBase);
  if LIndex > 0 then
    LBase := Copy(LBase, 1, LIndex - 1);
  if (LBase = 'CON') or (LBase = 'PRN') or (LBase = 'AUX') or (LBase = 'NUL') or
    (LBase = 'CONIN$') or (LBase = 'CONOUT$') or
    ((Length(LBase) = 4) and ((Copy(LBase, 1, 3) = 'COM') or
    (Copy(LBase, 1, 3) = 'LPT')) and CharInSet(LBase[4], ['0'..'9', '¹', '²', '³'])) then
    raise EArgumentException.Create('Reservierter Windows-Name in der Dokumentkennung.');
  Result := TPath.Combine(AParent, AName);
end;

function InvoiceDirectory(const AInvoiceNumber: string): string;
begin
  Result := SafeChildDirectory(OutgoingDirectory, AInvoiceNumber);
end;

function IncomingDocumentDirectory(const ADocumentID: string): string;
begin
  Result := SafeChildDirectory(IncomingDirectory, ADocumentID);
end;

function MasterDataPath: string;
begin
  Result := TPath.Combine(DataDirectory, 'stammdaten.json');
end;

function TokensPath: string;
begin
  Result := TPath.Combine(DataDirectory, 'tokens.dat');
end;

function PendingInboxPath: string;
begin
  Result := TPath.Combine(DataDirectory, 'eingang-offen.txt');
end;

function PlaceholderPdfPath: string;
begin
  Result := TPath.Combine(ExtractFilePath(ParamStr(0)), 'Belegbild-Platzhalter.pdf');
  if not FileExists(Result) then
    // Standardausgabe: Sample2\Win32|Win64\Debug|Release.
    Result := ExpandFileName(TPath.Combine(ExtractFilePath(ParamStr(0)),
      '..\..\Belegbild-Platzhalter.pdf'));
end;

procedure EnsureDirectory(const APath: string);
begin
  if not ForceDirectories(APath) then
    raise EInOutError.CreateFmt('Der Datenordner konnte nicht angelegt werden: %s', [APath]);
end;

procedure EnsureDataDirectories;
begin
  EnsureDirectory(DataDirectory);
  EnsureDirectory(OutgoingDirectory);
  EnsureDirectory(IncomingDirectory);
  EnsureDirectory(HttpLogDirectory);
end;

procedure AtomicWriteText(const APath, AText: string);
var
  LPath, LTempPath: string;
  LGuid: TGUID;
  LHandle: THandle;
  LStream: THandleStream;
  LBytes: TBytes;
begin
  LPath := ExpandFileName(APath);
  EnsureDirectory(ExtractFileDir(LPath));
  CreateGUID(LGuid);
  // Gleicher Ordner und damit gleiches Volume für den atomaren Austausch.
  LTempPath := LPath + '.' + GUIDToString(LGuid) + '.tmp';
  LHandle := CreateFile(PChar(LTempPath), GENERIC_WRITE, 0, nil, CREATE_NEW,
    FILE_ATTRIBUTE_NORMAL, 0);
  if LHandle = INVALID_HANDLE_VALUE then
    RaiseLastOSError;
  try
    try
      LStream := THandleStream.Create(LHandle);
      try
        LBytes := TEncoding.UTF8.GetBytes(AText);
        if Length(LBytes) > 0 then
          LStream.WriteBuffer(LBytes[0], Length(LBytes));
        if not FlushFileBuffers(LHandle) then
          RaiseLastOSError;
      finally
        LStream.Free;
      end;
    finally
      CloseHandle(LHandle);
    end;
    if not MoveFileEx(PChar(LTempPath), PChar(LPath),
      MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH) then
      RaiseLastOSError;
  finally
    // Nach erfolgreichem Move existiert die Temp-Datei nicht mehr.
    Winapi.Windows.DeleteFile(PChar(LTempPath));
  end;
end;

function LoadClientConfig: TMiniAppClientConfig;
var
  LEnv: TStringList;
  LPath: string;
begin
  Result := Default(TMiniAppClientConfig);
  LPath := TPath.Combine(ExtractFilePath(ParamStr(0)), '.env');
  if not FileExists(LPath) then
    // Wie im Sample: vom Ausgabeordner fünf Ebenen bis zur Repo-Wurzel.
    LPath := ExpandFileName(TPath.Combine(ExtractFilePath(ParamStr(0)),
      '..\..\..\..\..\.env'));
  if not FileExists(LPath) then
    Exit;
  LEnv := TStringList.Create;
  try
    // Wie im Sample einfache NAME=WERT-Zeilen, ohne Shell-Auswertung.
    LEnv.LoadFromFile(LPath, TEncoding.UTF8);
    Result.SourceFile := LPath;
    Result.ClientID := LEnv.Values['PROVIDER_TPDATEV_CLIENT_ID'];
    Result.ClientSecret := LEnv.Values['PROVIDER_TPDATEV_CLIENT_SECRET'];
    Result.TraffiqxID := LEnv.Values['PROVIDER_TPDATEV_TRAFFIQX_ID'];
    Result.Scope := LEnv.Values['PROVIDER_TPDATEV_SCOPE'];
    Result.AppDisplayName := LEnv.Values['PROVIDER_TPDATEV_APP_NAME'];
    Result.OAuth2BrokerCallbackUri := LEnv.Values['OAUTH2_BROKER_CALLBACK_URI'];
    Result.OAuth2BrokerApiKey := LEnv.Values['OAUTH2_BROKER_API_KEY'];
    Result.XRechnungDistributionDir := Trim(LEnv.Values['XRECHNUNG_DISTRIBUTION_DIR']);
    if (Result.XRechnungDistributionDir <> '') and
      not TPath.IsPathRooted(Result.XRechnungDistributionDir) then
      Result.XRechnungDistributionDir := ExpandFileName(TPath.Combine(
        ExtractFileDir(LPath), Result.XRechnungDistributionDir));
  finally
    LEnv.Free;
  end;
end;

function CreateOutboxInvoice(AData: TMiniAppData; const ACustomer: TMiniAppCustomer;
  AIssueDate: TDate; out AReservedInvoiceNumber: string): string;
var
  LInvoice: TInvoice;
  LInfo: TJSONObject;
  LPdf: string;
begin
  AReservedInvoiceNumber := '';
  if AData = nil then
    raise EArgumentNilException.Create('Stammdaten fehlen.');
  AReservedInvoiceNumber := AData.NextInvoiceNumber;
  Result := InvoiceDirectory(AReservedInvoiceNumber);
  EnsureDirectory(OutgoingDirectory);
  // CreateDirectory ist exklusiv: vorhandene Ordner niemals übernehmen.
  if not Winapi.Windows.CreateDirectory(PChar(Result), nil) then
    raise EInOutError.CreateFmt('Rechnungsordner kann nicht neu angelegt werden: %s (%s)',
      [Result, SysErrorMessage(GetLastError)]);
  // Bei Fehlern bleibt die Teilablage zur Diagnose erhalten. Keine Wiederverwendung.
  LInvoice := BuildInvoice(AData, ACustomer, AReservedInvoiceNumber, AIssueDate);
  try
    LPdf := PlaceholderPdfPath;
    if not FileExists(LPdf) then
      raise EInOutError.Create('Belegbild-Platzhalter.pdf fehlt neben der EXE und im Sample2-Ordner.');
    SaveInvoiceXml(LInvoice, TPath.Combine(Result, 'rechnung.xml'));
    if not Winapi.Windows.CopyFile(PChar(LPdf), PChar(TPath.Combine(Result, 'belegbild.pdf')), True) then
      RaiseLastOSError;
    LInfo := TJSONObject.Create;
    try
      LInfo.AddPair('invoice_number', AReservedInvoiceNumber);
      LInfo.AddPair('customer_number', ACustomer.CustomerNumber);
      LInfo.AddPair('customer_name', ACustomer.Name);
      LInfo.AddPair('issue_date', FormatDateTime('yyyy-mm-dd', LInvoice.InvoiceIssueDate));
      LInfo.AddPair('gross_amount', TJSONNumber.Create(CurrToStr(
        LInvoice.TaxInclusiveAmount, TFormatSettings.Invariant)));
      LInfo.AddPair('delivery_channel', ACustomer.DeliveryChannel);
      // Erst als letzten Schritt veröffentlichen: ohne Info ist die Ablage unvollständig.
      AtomicWriteText(TPath.Combine(Result, 'rechnung.json'), LInfo.ToJSON);
    finally
      LInfo.Free;
    end;
  finally
    LInvoice.Free;
  end;
end;

function ReadJsonObject(const AFileName: string): TJSONObject;
var
  LValue: TJSONValue;
  LHandle: THandle;
  LStream: THandleStream;
  LReader: TStreamReader;
begin
  // UI und Worker lesen parallel. FILE_SHARE_DELETE erlaubt den atomaren
  // Austausch von outbox.json auch während die alte Version gelesen wird.
  LHandle := CreateFile(PChar(AFileName), GENERIC_READ,
    FILE_SHARE_READ or FILE_SHARE_WRITE or FILE_SHARE_DELETE, nil, OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL, 0);
  if LHandle = INVALID_HANDLE_VALUE then RaiseLastOSError;
  try
    LStream := THandleStream.Create(LHandle);
    try
      LReader := TStreamReader.Create(LStream, TEncoding.UTF8, True);
      try
        LValue := TJSONObject.ParseJSONValue(LReader.ReadToEnd);
      finally
        LReader.Free;
      end;
    finally
      LStream.Free;
    end;
  finally
    CloseHandle(LHandle);
  end;
  if not (LValue is TJSONObject) then
  begin
    LValue.Free;
    raise EConvertError.Create('Ungültiges JSON-Objekt: ' + AFileName);
  end;
  Result := TJSONObject(LValue);
end;

function ReadJsonText(AObject: TJSONObject; const AKey: string;
  AOptional: Boolean = False): string;
var
  LValue: TJSONValue;
begin
  LValue := AObject.GetValue(AKey);
  if AOptional and (LValue = nil) then
    Exit('');
  if not (LValue is TJSONString) then
    raise EConvertError.CreateFmt('Textfeld "%s" fehlt oder ist ungültig.', [AKey]);
  Result := LValue.Value;
end;

function LoadTokens(out ATokens: TMiniAppTokens): Boolean;
var
  LJson: TJSONObject;
  LTokens: TMiniAppTokens;
  LValue: TJSONValue;
  LEnvironment: string;
  LAttributes, LFileError: DWORD;

  function ReadProtected(const AKey: string): string;
  var
    LText: string;
  begin
    LText := ReadJsonText(LJson, AKey);
    // Der Bibliothekshelfer akzeptiert Legacy-Klartext; diese neue Ablage nicht.
    if (LText <> '') and not LText.StartsWith(TTraffiqxTokenProtection.TEXT_PREFIX) then
      raise EConvertError.Create('Unverschlüsselte Token-Ablage.');
    if not TTraffiqxTokenProtection.UnprotectFromText(LText, Result) then
      raise EConvertError.Create('Token-Ablage nicht entschlüsselbar.');
  end;

  function ReadExpiry(const AKey: string): TDateTime;
  var
    LNumber: TJSONValue;
    LDate: Double;
  begin
    LNumber := LJson.GetValue(AKey);
    if not (LNumber is TJSONNumber) then
      raise EConvertError.Create('Token-Ablauf fehlt.');
    if not TryStrToFloat(LNumber.Value, LDate, TFormatSettings.Invariant) then
      raise EConvertError.Create('Token-Ablauf ungültig.');
    if not ((LDate >= 0) and (LDate <= 2958465)) then
      raise EConvertError.Create('Token-Ablauf außerhalb des Datumsbereichs.');
    Result := LDate;
  end;
begin
  ATokens := Default(TMiniAppTokens);
  Result := False;
  try
    // FileExists allein unterscheidet fehlend und Zugriff verweigert nicht.
    LAttributes := GetFileAttributes(PChar(TokensPath));
    if LAttributes = INVALID_FILE_ATTRIBUTES then
    begin
      LFileError := GetLastError;
      Exit((LFileError = ERROR_FILE_NOT_FOUND) or (LFileError = ERROR_PATH_NOT_FOUND));
    end;
    LTokens := Default(TMiniAppTokens);
    LJson := ReadJsonObject(TokensPath);
    try
      if ReadJsonText(LJson, 'format') <> 'MiniApp.Tokens.v1' then
        raise EConvertError.Create('Unbekanntes Token-Format.');
      LTokens.AccessToken := ReadProtected('access_token');
      LTokens.RefreshToken := ReadProtected('refresh_token');
      LTokens.AccessExpiresAt := ReadExpiry('access_expires_at');
      LTokens.RefreshExpiresAt := ReadExpiry('refresh_expires_at');
      LValue := LJson.GetValue('revocation_pending');
      if not (LValue is TJSONBool) then
        raise EConvertError.Create('Widerrufstatus fehlt.');
      LTokens.RevocationPending := LValue.Value = 'true';
      // Ältere v1-Ablagen haben noch keinen Anmeldemarker.
      LValue := LJson.GetValue('login_unconfirmed');
      if LValue <> nil then
      begin
        if not (LValue is TJSONBool) then
          raise EConvertError.Create('Anmeldestatus ungültig.');
        LTokens.LoginUnconfirmed := LValue.Value = 'true';
        LTokens.LoginUnconfirmedAt := ReadExpiry('login_unconfirmed_at');
        if LTokens.LoginUnconfirmed and (LTokens.LoginUnconfirmedAt = 0) then
          raise EConvertError.Create('Zeitpunkt der ungeklärten Anmeldung fehlt.');
      end;
      LTokens.UserName := ReadJsonText(LJson, 'user_name');
      LTokens.ClientID := ReadJsonText(LJson, 'client_id');
      LTokens.TraffiqxID := ReadJsonText(LJson, 'traffiqx_id');
      LEnvironment := ReadJsonText(LJson, 'environment');
      if LEnvironment = 'sandbox' then
        LTokens.Environment := meSandbox
      else if LEnvironment = 'production' then
        LTokens.Environment := meProduction
      else
        raise EConvertError.Create('Unbekannte Token-Umgebung.');
      ATokens := LTokens;
      Result := True;
    finally
      LJson.Free;
    end;
  except
    // Keine Dateiinhalte oder Konvertierungsfehler mit Tokens weiterreichen.
    ATokens := Default(TMiniAppTokens);
  end;
end;

procedure SaveTokens(const ATokens: TMiniAppTokens);
var
  LJson: TJSONObject;
begin
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('format', 'MiniApp.Tokens.v1');
    LJson.AddPair('access_token', TTraffiqxTokenProtection.ProtectToText(
      ATokens.AccessToken, tpsCurrentUser));
    LJson.AddPair('refresh_token', TTraffiqxTokenProtection.ProtectToText(
      ATokens.RefreshToken, tpsCurrentUser));
    LJson.AddPair('access_expires_at', TJSONNumber.Create(Double(ATokens.AccessExpiresAt)));
    LJson.AddPair('refresh_expires_at', TJSONNumber.Create(Double(ATokens.RefreshExpiresAt)));
    LJson.AddPair('revocation_pending', TJSONBool.Create(ATokens.RevocationPending));
    LJson.AddPair('login_unconfirmed', TJSONBool.Create(ATokens.LoginUnconfirmed));
    LJson.AddPair('login_unconfirmed_at', TJSONNumber.Create(Double(ATokens.LoginUnconfirmedAt)));
    LJson.AddPair('user_name', ATokens.UserName);
    LJson.AddPair('client_id', ATokens.ClientID);
    LJson.AddPair('traffiqx_id', ATokens.TraffiqxID);
    if ATokens.Environment = meSandbox then
      LJson.AddPair('environment', 'sandbox')
    else
      LJson.AddPair('environment', 'production');
    AtomicWriteText(TokensPath, LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

function LoadInvoiceInfo(const AInvoiceNumber: string): TMiniAppInvoiceInfo;
var
  LInfo: TJSONObject;
  LAmount: TJSONValue;
begin
  Result := Default(TMiniAppInvoiceInfo);
  LInfo := ReadJsonObject(TPath.Combine(InvoiceDirectory(AInvoiceNumber), 'rechnung.json'));
  try
    Result.InvoiceNumber := ReadJsonText(LInfo, 'invoice_number');
    if Result.InvoiceNumber <> AInvoiceNumber then
      raise EConvertError.Create('Rechnungsnummer in rechnung.json stimmt nicht mit dem Ordner überein.');
    Result.CustomerName := ReadJsonText(LInfo, 'customer_name');
    Result.IssueDate := ReadJsonText(LInfo, 'issue_date');
    Result.DeliveryChannel := ReadJsonText(LInfo, 'delivery_channel');
    LAmount := LInfo.GetValue('gross_amount');
    if not (LAmount is TJSONNumber) then
      raise EConvertError.Create('Bruttobetrag in rechnung.json fehlt oder ist ungültig.');
    if not TryStrToCurr(LAmount.Value, Result.GrossAmount, TFormatSettings.Invariant) then
      raise EConvertError.Create('Bruttobetrag in rechnung.json liegt außerhalb des Wertebereichs.');
  finally
    LInfo.Free;
  end;
end;

function OutboxStatusRank(const AStatus: string): Integer;
begin
  if AStatus = 'inProcess' then Exit(0);
  if AStatus = 'userAction' then Exit(1);
  if AStatus = 'error' then Exit(2);
  if AStatus = 'deleted' then Exit(3);
  if AStatus = 'sent' then Exit(4);
  Result := -1;
end;

function LoadOutbox(const AInvoiceNumber: string): TMiniAppOutboxState;
var
  LPath: string;
  LInfo: TJSONObject;
  LValue, LItem: TJSONValue;
  LAttributes, LError: DWORD;
  I: Integer;
begin
  Result := Default(TMiniAppOutboxState);
  LPath := TPath.Combine(InvoiceDirectory(AInvoiceNumber), 'outbox.json');
  // Zugriff verweigert ist keine fehlende Datei und darf keinen Versand erlauben.
  LAttributes := GetFileAttributes(PChar(LPath));
  if LAttributes = INVALID_FILE_ATTRIBUTES then
  begin
    LError := GetLastError;
    if (LError = ERROR_FILE_NOT_FOUND) or (LError = ERROR_PATH_NOT_FOUND) then
      Exit;
    RaiseLastOSError(LError);
  end;
  LInfo := ReadJsonObject(LPath);
  try
    Result.DocumentID := ReadJsonText(LInfo, 'document_id');
    Result.Status := ReadJsonText(LInfo, 'status');
    Result.ChannelIntended := ReadJsonText(LInfo, 'channel_intended', True);
    Result.UploadedAt := ReadJsonText(LInfo, 'uploaded_at', True);
    Result.CheckedAt := ReadJsonText(LInfo, 'checked_at', True);
    Result.DocumentFormat := ReadJsonText(LInfo, 'document_format', True);
    Result.SendDate := ReadJsonText(LInfo, 'send_date', True);
    Result.DeliveryChannel := ReadJsonText(LInfo, 'delivery_channel', True);
    Result.DeliveryAddress := ReadJsonText(LInfo, 'delivery_address', True);
    Result.MetadataAt := ReadJsonText(LInfo, 'metadata_at', True);
    Result.ArchivedAt := ReadJsonText(LInfo, 'archived_at', True);
    Result.LastError := ReadJsonText(LInfo, 'last_error', True);
    LValue := LInfo.GetValue('channel_matches');
    if (LValue <> nil) and not (LValue is TJSONBool) and not (LValue is TJSONNull) then
      raise EConvertError.Create('channel_matches ist ungültig.');
    Result.ChannelMatches := (LValue is TJSONBool) and (LValue.Value = 'true');
    LValue := LInfo.GetValue('upload_unconfirmed');
    if (LValue <> nil) and not (LValue is TJSONBool) then
      raise EConvertError.Create('upload_unconfirmed ist ungültig.');
    Result.UploadUnconfirmed := (LValue is TJSONBool) and (LValue.Value = 'true');
    // Auch ältere #PARSE-Marker ohne Zusatzfeld blockieren einen erneuten Upload.
    if (LValue = nil) and (Result.DocumentID = '') and (Result.LastError <> '') then
      Result.UploadUnconfirmed := True;
    LValue := LInfo.GetValue('previous_document_ids');
    if LValue <> nil then
    begin
      if not (LValue is TJSONArray) then
        raise EConvertError.Create('previous_document_ids ist ungültig.');
      SetLength(Result.PreviousDocumentIDs, TJSONArray(LValue).Count);
      I := 0;
      for LItem in TJSONArray(LValue) do
      begin
        if not (LItem is TJSONString) then
          raise EConvertError.Create('Frühere document_id ist ungültig.');
        Result.PreviousDocumentIDs[I] := LItem.Value;
        Inc(I);
      end;
    end;
  finally
    LInfo.Free;
  end;
end;

function OutboxJson(const AState: TMiniAppOutboxState): TJSONObject;
var
  LIDs: TJSONArray;
  LID: string;
begin
  Result := TJSONObject.Create;
  try
    Result.AddPair('document_id', AState.DocumentID);
    Result.AddPair('status', AState.Status);
    Result.AddPair('channel_intended', AState.ChannelIntended);
    Result.AddPair('uploaded_at', AState.UploadedAt);
    Result.AddPair('checked_at', AState.CheckedAt);
    Result.AddPair('document_format', AState.DocumentFormat);
    Result.AddPair('send_date', AState.SendDate);
    Result.AddPair('delivery_channel', AState.DeliveryChannel);
    Result.AddPair('delivery_address', AState.DeliveryAddress);
    if AState.MetadataAt = '' then
      Result.AddPair('channel_matches', TJSONNull.Create)
    else
      Result.AddPair('channel_matches', TJSONBool.Create(AState.ChannelMatches));
    Result.AddPair('metadata_at', AState.MetadataAt);
    Result.AddPair('archived_at', AState.ArchivedAt);
    Result.AddPair('last_error', AState.LastError);
    Result.AddPair('upload_unconfirmed', TJSONBool.Create(AState.UploadUnconfirmed));
    LIDs := TJSONArray.Create;
    Result.AddPair('previous_document_ids', LIDs);
    for LID in AState.PreviousDocumentIDs do
      LIDs.Add(LID);
  except
    Result.Free;
    raise;
  end;
end;

procedure SaveOutbox(const AInvoiceNumber: string; const AState: TMiniAppOutboxState);
var
  LState, LPrevious: TMiniAppOutboxState;
  LJson: TJSONObject;
begin
  LState := AState;
  LPrevious := LoadOutbox(AInvoiceNumber);
  // Rang gilt je document_id. Ein bestätigter Neuversand beginnt bei inProcess.
  if (LState.DocumentID <> '') and (LPrevious.DocumentID = LState.DocumentID) and
    (OutboxStatusRank(LPrevious.Status) > OutboxStatusRank(LState.Status)) then
    LState.Status := LPrevious.Status;
  LJson := OutboxJson(LState);
  try
    AtomicWriteText(TPath.Combine(InvoiceDirectory(AInvoiceNumber), 'outbox.json'), LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

function OutboxDetails(const AState: TMiniAppOutboxState): string;
var
  LJson: TJSONObject;
  LPair: TJSONPair;
begin
  Result := '';
  LJson := OutboxJson(AState);
  try
    for LPair in LJson do
      Result := Result + LPair.JsonString.Value + ': ' + LPair.JsonValue.ToJSON + sLineBreak;
  finally
    LJson.Free;
  end;
end;

procedure ArchiveZip(const ADirectory: string; AZipStream: TStream; AInbox: Boolean);
var
  LZip: TZipFile;
  LContents: TArray<TBytes>;
  LNames: TArray<string>;
  LName, LDirectory, LStage, LPath: string;
  LExisting, LMarker: TBytes;
  LFile: TFileStream;
  LGuid: TGUID;
  I, J, LCount: Integer;
  LTotal: UInt64;
  LCRC: UInt32;
begin
  if (AZipStream = nil) or (AZipStream.Size = 0) then
    raise EReadError.Create('Das Original-ZIP ist leer.');
  LZip := TZipFile.Create;
  try
    AZipStream.Position := 0;
    LZip.Open(AZipStream, zmRead);
    SetLength(LContents, LZip.FileCount);
    SetLength(LNames, LZip.FileCount);
    LCount := 0;
    LTotal := 0;
    for I := 0 to LZip.FileCount - 1 do
    begin
      LName := StringReplace(LZip.FileNames[I], '/', '\', [rfReplaceAll]);
      if LName.EndsWith('\') then
        Continue;
      // Für das kleine Sample begrenzen wir die entpackte Gesamtgröße auf 256 MiB.
      if LZip.FileInfo[I].UncompressedSize64 > UInt64(256 * 1024 * 1024) - LTotal then
        raise EReadError.Create('Original-ZIP überschreitet 256 MiB.');
      Inc(LTotal, LZip.FileInfo[I].UncompressedSize64);
      // Alle Einträge vollständig lesen (einschließlich CRC-Prüfung), erst dann schreiben.
      LZip.Read(I, LContents[LCount]);
      // System.Zip prüft den lokalen Header. Zusätzlich das zentrale Verzeichnis
      // abgleichen, auch für leere Dateien und widersprüchliche ZIP-Header.
      LCRC := crc32(0, nil, 0);
      if Length(LContents[LCount]) > 0 then
        LCRC := crc32(LCRC, @LContents[LCount][0], Length(LContents[LCount]));
      if LCRC <> LZip.FileInfo[I].CRC32 then
        raise EReadError.Create('CRC-Fehler im Original-ZIP.');
      LName := ExtractFileName(LName);
      for J := 1 to Length(LName) do
        if (Ord(LName[J]) < 32) or CharInSet(LName[J], ['<', '>', ':', '"', '|', '?', '*']) then
          LName[J] := '_';
      LName := Copy(LName, 1, 180).TrimRight([' ', '.']);
      if LName = '' then
        LName := 'document';
      // Flache Ablage; Präfix verhindert Geräte-/Doppelnamen auch nach Bereinigung.
      LNames[LCount] := Format('%.4d-', [LCount + 1]) + LName;
      Inc(LCount);
    end;
    if LCount = 0 then
      raise EReadError.Create('Original-ZIP enthält keine Dateien.');
  finally
    LZip.Free;
  end;
  LDirectory := ADirectory;
  if DirectoryExists(LDirectory) then
  begin
    if AInbox then
      raise EInOutError.Create('Vorhandene Eingangsablage ist unvollständig; manuell prüfen.');
    // Absturz nach Veröffentlichung, vor archived_at: identische Ablage übernehmen.
    if (GetFileAttributes(PChar(LDirectory)) and FILE_ATTRIBUTE_REPARSE_POINT) <> 0 then
      raise EInOutError.Create('Originalordner darf keine Verknüpfung sein.');
    if Length(TDirectory.GetFileSystemEntries(LDirectory)) <> LCount then
      raise EInOutError.Create('Vorhandenen Originalordner manuell prüfen; Inhalt weicht ab.');
    for I := 0 to LCount - 1 do
    begin
      LPath := TPath.Combine(LDirectory, LNames[I]);
      if (GetFileAttributes(PChar(LPath)) and FILE_ATTRIBUTE_REPARSE_POINT) <> 0 then
        raise EInOutError.Create('Originaldatei fehlt oder ist eine Verknüpfung.');
      LExisting := TFile.ReadAllBytes(LPath);
      if Length(LExisting) <> Length(LContents[I]) then
        raise EInOutError.Create('Vorhandene Originaldatei weicht ab; manuell prüfen.');
      if (Length(LExisting) > 0) and not CompareMem(@LExisting[0], @LContents[I][0], Length(LExisting)) then
        raise EInOutError.Create('Vorhandene Originaldatei weicht ab; manuell prüfen.');
    end;
    Exit;
  end;
  CreateGUID(LGuid);
  LStage := LDirectory + '.' + GUIDToString(LGuid) + '.tmp';
  EnsureDirectory(LStage);
  // Teilablagen bleiben bei Schreibfehlern zur Diagnose erhalten; nie als archiviert markieren.
  for I := 0 to LCount - 1 do
  begin
    LFile := TFileStream.Create(TPath.Combine(LStage, LNames[I]), fmCreate);
    try
      if Length(LContents[I]) > 0 then
        LFile.WriteBuffer(LContents[I][0], Length(LContents[I]));
      if not FlushFileBuffers(LFile.Handle) then RaiseLastOSError;
    finally
      LFile.Free;
    end;
  end;
  if AInbox then
  begin
    // Noch unveröffentlicht: direkt schreiben und spülen. Keine zweite Temp-Datei
    // mit zusätzlicher GUID (unnötig und bei langen Datenpfaden zu lang).
    LMarker := TEncoding.UTF8.GetBytes(string.Join(sLineBreak, Copy(LNames, 0, LCount)));
    LFile := TFileStream.Create(TPath.Combine(LStage, 'archive.complete'), fmCreate);
    try
      LFile.WriteBuffer(LMarker[0], Length(LMarker));
      if not FlushFileBuffers(LFile.Handle) then RaiseLastOSError;
    finally
      LFile.Free;
    end;
  end;
  if not MoveFileEx(PChar(LStage), PChar(LDirectory), MOVEFILE_WRITE_THROUGH) then
    RaiseLastOSError;
end;


procedure ArchiveOutboxOriginal(const AInvoiceNumber: string; AZipStream: TStream);
begin
  ArchiveZip(TPath.Combine(InvoiceDirectory(AInvoiceNumber), 'original'), AZipStream, False);
end;

function PathPresent(const APath: string): Boolean;
var
  LAttributes, LError: DWORD;
begin
  LAttributes := GetFileAttributes(PChar(APath));
  if LAttributes <> INVALID_FILE_ATTRIBUTES then Exit(True);
  LError := GetLastError;
  if (LError = ERROR_FILE_NOT_FOUND) or (LError = ERROR_PATH_NOT_FOUND) then Exit(False);
  RaiseLastOSError(LError);
end;

procedure EnsureInboxContext(AEnvironment: TMiniAppEnvironment; const ATraffiqxID: string);
var
  LPath, LEnvironment: string;
  LJson: TJSONObject;
begin
  if Trim(ATraffiqxID) = '' then
    raise EArgumentException.Create('TRAFFIQX-ID für den Posteingang fehlt.');
  if AEnvironment = meSandbox then LEnvironment := 'sandbox'
  else LEnvironment := 'production';
  LPath := TPath.Combine(DataDirectory, 'eingang-kontext.json');
  if PathPresent(LPath) then
  begin
    LJson := ReadJsonObject(LPath);
    try
      if (ReadJsonText(LJson, 'format') <> 'MiniApp.InboxContext.v1') or
        (ReadJsonText(LJson, 'environment') <> LEnvironment) or
        (ReadJsonText(LJson, 'traffiqx_id') <> ATraffiqxID) then
        raise EInvalidOperation.Create('Der lokale Posteingang gehört zu einer anderen ' +
          'Umgebung/TRAFFIQX-ID oder hat ein unbekanntes Kontextformat. ' +
          'Ursprüngliche Konfiguration wiederherstellen; die Offen-Liste bleibt unverändert.');
    finally
      LJson.Free;
    end;
    Exit;
  end;
  // Altbestände niemals still der gerade aktiven Verbindung zuschlagen.
  // Auch fertige Dokumente binden: sonst würden fremde IDs/Metadaten vermischt.
  if Length(LoadPendingInbox) > 0 then
    raise EInvalidOperation.Create('Offene Eingangsdokumente ohne Kontextbindung. ' +
      'Ursprüngliche Zuordnung manuell prüfen; siehe README, Bekannte Grenzen.');
  if PathPresent(IncomingDirectory) then
    if Length(TDirectory.GetFileSystemEntries(IncomingDirectory)) > 0 then
      raise EInvalidOperation.Create('Vorhandener Posteingang ohne Kontextbindung. ' +
        'Ursprüngliche Zuordnung manuell prüfen; siehe README, Bekannte Grenzen.');
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('format', 'MiniApp.InboxContext.v1');
    LJson.AddPair('environment', LEnvironment);
    LJson.AddPair('traffiqx_id', ATraffiqxID);
    // Vor Listenabruf, Download oder Metadaten atomar persistieren.
    AtomicWriteText(LPath, LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

function LoadPendingInbox: TArray<string>;
var
  LList: TStringList;
  LID: string;
begin
  Result := nil;
  if not PathPresent(PendingInboxPath) then Exit;
  LList := TStringList.Create;
  try
    LList.LoadFromFile(PendingInboxPath, TEncoding.UTF8);
    // Beschädigte Listen niemals als leer behandeln oder still überschreiben.
    for LID in LList do
      IncomingDocumentDirectory(LID);
    Result := LList.ToStringArray;
  finally
    LList.Free;
  end;
end;

procedure MarkInboxPending(const ADocumentID: string; APending: Boolean);
var
  LList: TStringList;
  LID: string;
  LIndex: Integer;
begin
  IncomingDocumentDirectory(ADocumentID);
  LList := TStringList.Create;
  try
    LList.CaseSensitive := True;
    for LID in LoadPendingInbox do
      if LList.IndexOf(LID) < 0 then LList.Add(LID);
    LIndex := LList.IndexOf(ADocumentID);
    if APending then
    begin
      if LIndex >= 0 then Exit;
      LList.Add(ADocumentID);
    end
    else
    begin
      if LIndex < 0 then Exit;
      LList.Delete(LIndex);
    end;
    AtomicWriteText(PendingInboxPath, LList.Text);
  finally
    LList.Free;
  end;
end;

function InboxFiles(const ADocumentID: string): TArray<string>;
var
  LDirectory, LName, LPath: string;
  LList: TStringList;
  LAttributes: DWORD;
  I: Integer;
begin
  Result := nil;
  LDirectory := IncomingDocumentDirectory(ADocumentID);
  if not PathPresent(LDirectory) then Exit;
  LAttributes := GetFileAttributes(PChar(LDirectory));
  if ((LAttributes and FILE_ATTRIBUTE_REPARSE_POINT) <> 0) or
    ((LAttributes and FILE_ATTRIBUTE_DIRECTORY) = 0) then
    raise EInOutError.Create('Eingangsordner ist keine reguläre Ablage.');
  LList := TStringList.Create;
  try
    // Fehlender/unlesbarer Marker bedeutet unvollständig, niemals erfolgreich.
    LList.LoadFromFile(TPath.Combine(LDirectory, 'archive.complete'), TEncoding.UTF8);
    if LList.Count = 0 then raise EReadError.Create('Eingangsablage enthält keine Dokumentdateien.');
    SetLength(Result, LList.Count);
    for I := 0 to LList.Count - 1 do
    begin
      LName := LList[I];
      LPath := SafeChildDirectory(LDirectory, LName);
      if (LName = 'archive.complete') or (LName = 'metadata.json') then
        raise EReadError.Create('Ungültige Dateiliste der Eingangsablage.');
      LAttributes := GetFileAttributes(PChar(LPath));
      if (LAttributes = INVALID_FILE_ATTRIBUTES) or
        ((LAttributes and (FILE_ATTRIBUTE_REPARSE_POINT or FILE_ATTRIBUTE_DIRECTORY)) <> 0) then
        raise EReadError.Create('Dokumentdatei fehlt oder ist eine Verknüpfung.');
      Result[I] := LPath;
    end;
  finally
    LList.Free;
  end;
end;

function InboxDocumentStored(const ADocumentID: string): Boolean;
begin
  Result := Length(InboxFiles(ADocumentID)) > 0;
end;

function FirstInboxFile(const ADocumentID: string): string;
var
  LFiles: TArray<string>;
begin
  LFiles := InboxFiles(ADocumentID);
  if Length(LFiles) = 0 then raise EReadError.Create('Eingangsdokument ist noch nicht abgelegt.');
  Result := LFiles[0];
end;

procedure ArchiveInboxDocument(const ADocumentID: string; AZipStream: TStream);
begin
  if InboxDocumentStored(ADocumentID) then Exit;
  ArchiveZip(IncomingDocumentDirectory(ADocumentID), AZipStream, True);
end;

function LoadInboxInfo(const ADocumentID: string): TMiniAppInboxInfo;
var
  LJson: TJSONObject;
  LPath: string;
  LValue: TJSONValue;
begin
  Result := Default(TMiniAppInboxInfo);
  LPath := TPath.Combine(IncomingDocumentDirectory(ADocumentID), 'metadata.json');
  if not PathPresent(LPath) then Exit;
  LJson := ReadJsonObject(LPath);
  try
    Result.SellerName := ReadJsonText(LJson, 'seller_name');
    Result.ReceivedAt := ReadJsonText(LJson, 'date_of_receipt');
    Result.DocumentFormat := ReadJsonText(LJson, 'document_format');
    LValue := LJson.GetValue('en_16931_compliant');
    if not (LValue is TJSONBool) or (Result.DocumentFormat = '') then
      raise EConvertError.Create('Validierungsstatus oder Dokumentformat fehlt.');
    Result.EN16931Compliant := LValue.Value = 'true';
    Result.HasMetadata := True;
  finally
    LJson.Free;
  end;
end;

procedure SaveInboxMetadata(const ADocumentID, AJson: string);
begin
  if not InboxDocumentStored(ADocumentID) then
    raise EReadError.Create('Metadaten benötigen eine vollständige Dokumentablage.');
  AtomicWriteText(TPath.Combine(IncomingDocumentDirectory(ADocumentID), 'metadata.json'), AJson);
end;

end.
