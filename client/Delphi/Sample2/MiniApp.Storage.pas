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

implementation

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.IOUtils;

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
  finally
    LEnv.Free;
  end;
end;

end.
