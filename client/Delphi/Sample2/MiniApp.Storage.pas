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
  System.SysUtils, MiniApp.Model;

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
procedure LoadOutboxState(const AInvoiceNumber: string; out ADocumentID, AStatus: string);

implementation

uses
  Winapi.Windows, System.Classes, System.IOUtils, System.JSON,
  intf.Invoice, MiniApp.InvoiceBuilder;

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
begin
  LValue := TJSONObject.ParseJSONValue(TFile.ReadAllText(AFileName, TEncoding.UTF8));
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

procedure LoadOutboxState(const AInvoiceNumber: string; out ADocumentID, AStatus: string);
var
  LPath: string;
  LInfo: TJSONObject;
begin
  ADocumentID := '';
  AStatus := '';
  LPath := TPath.Combine(InvoiceDirectory(AInvoiceNumber), 'outbox.json');
  if not FileExists(LPath) then
    Exit;
  LInfo := ReadJsonObject(LPath);
  try
    ADocumentID := ReadJsonText(LInfo, 'document_id', True);
    AStatus := ReadJsonText(LInfo, 'status', True);
  finally
    LInfo.Free;
  end;
end;

end.
