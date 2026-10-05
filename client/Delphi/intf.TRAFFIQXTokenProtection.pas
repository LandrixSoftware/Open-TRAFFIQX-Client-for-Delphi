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

unit intf.TRAFFIQXTokenProtection;

// Hilfen fuer die Token-Ablage (DATEV-Abnahme: "Daten mit hoeherem
// Schutzbedarf sind immer auf Basis aktueller Techniken zu verschluesseln";
// DONT: Tokens im Klartext ablegen oder protokollieren).
//
// 1. Verschluesseln per Windows DPAPI (CryptProtectData). Die Bindung waehlt
//    die Anwendung:
//    - tpsCurrentUser: nur derselbe Windows-Benutzer kann entschluesseln. Die
//      richtige Wahl fuer ein Desktop-Programm, das seine Tokens selbst
//      haelt. Ein anderer Benutzer kann nichts damit anfangen (zu anderen
//      Rechnern siehe unten).
//    - tpsLocalMachine: jeder Prozess auf diesem Rechner kann entschluesseln.
//      Fuer einen Dienst/Server, der die Tokens fuer mehrere Arbeitsplaetze
//      verwahrt. Schuetzt gegen Kopien der Ablage auf andere Rechner (auch
//      Backups), nicht gegen lokale Benutzer: Zugriffsrechte auf die Ablage
//      gehoeren ins Betriebskonzept.
//    Was nicht mehr lesbar ist, erfordert eine neue Anmeldung:
//    - tpsCurrentUser: fuer einen anderen Benutzer nicht lesbar. Mit
//      servergespeichertem (Roaming-)Profil kann derselbe Benutzer die Daten
//      auch auf anderen Rechnern lesen.
//    - tpsLocalMachine: auf einem anderen Rechner nicht lesbar, fuer jeden
//      lokalen Benutzer mit Dateizugriff dagegen schon (die Entropie steht im
//      Programm). Die Ablage daher per Dateirechten auf das Dienstkonto
//      beschraenken.
//    Die Entropie trennt die Daten der Anwendung von anderen DPAPI-Daten; sie
//    ist kein Geheimnis, sollte aber je Anwendung eigen sein.
//
// 2. Fingerabdruck eines Refresh-Tokens (die ersten 16 Hex-Zeichen von
//    SHA-256). Damit laesst sich pruefen, ob eine gespeicherte Sitzung zu
//    einer bestimmten Anmeldung gehoert, ohne das Token zu zeigen oder zu
//    uebertragen - etwa wenn ein Arbeitsplatz nach einer abgebrochenen
//    Uebergabe klaeren muss, ob der Server "seine" Tokens hat. Weil DATEV das
//    Refresh-Token bei jeder Erneuerung austauscht, den Fingerabdruck bei der
//    Anmeldung festhalten und nicht aus dem aktuellen Token neu bilden.
//
// Einbinden (Beispiel INI-Datei):
//   Ini.WriteString(S, 'refreshtoken', TTraffiqxTokenProtection.ProtectToText(Api.RefreshToken));
//   if TTraffiqxTokenProtection.UnprotectFromText(Ini.ReadString(S, 'refreshtoken', ''), lToken) then
//     Api.RefreshToken := lToken
//   else
//     ... Tokens nicht lesbar (anderer Rechner/Benutzer): neu anmelden

interface

uses
  Winapi.Windows
  ,System.SysUtils
  ;

type
  TTraffiqxProtectionScope = (tpsCurrentUser, tpsLocalMachine);

  TTraffiqxTokenProtection = class
  public
    const
      // Kennzeichen verschluesselter Texte (ProtectToText); Texte ohne
      // Kennzeichen liest UnprotectFromText als Klartext (alte Ablage).
      TEXT_PREFIX = 'dpapi:';
      DEFAULT_ENTROPY = 'Open-TRAFFIQX-Client.Tokens.v1';
    // Verschluesselt APlain (UTF-8). Leerer Klartext ergibt leere Bytes.
    // AError = GetLastError bei Fehlschlag.
    class function Protect(const APlain: String; out ACipher: TBytes; out AError: DWORD;
      AScope: TTraffiqxProtectionScope = tpsCurrentUser;
      const AEntropy: String = DEFAULT_ENTROPY): Boolean; static;
    // Entschluesselt; False, wenn die Daten auf diesem Rechner/fuer diesen
    // Benutzer nicht lesbar sind (AError = GetLastError).
    class function Unprotect(const ACipher: TBytes; out APlain: String; out AError: DWORD;
      const AEntropy: String = DEFAULT_ENTROPY): Boolean; static;
    // Wie Protect, als Text 'dpapi:<Base64>' fuer INI-Dateien o.ae.
    // Leerer Klartext ergibt ''. Loest bei Fehlschlag EOSError aus.
    class function ProtectToText(const APlain: String;
      AScope: TTraffiqxProtectionScope = tpsCurrentUser;
      const AEntropy: String = DEFAULT_ENTROPY): String; static;
    // Gegenstueck zu ProtectToText. Text ohne Kennzeichen gilt als Klartext
    // (Uebernahme einer alten Ablage; beim naechsten Speichern verschluesselt).
    class function UnprotectFromText(const AText: String; out APlain: String;
      const AEntropy: String = DEFAULT_ENTROPY): Boolean; static;
    // Fingerabdruck eines Refresh-Tokens: die ersten 16 Hex-Zeichen von
    // SHA-256 ('' bei leerem Token).
    class function Fingerprint(const ARefreshToken: String): String; static;
  end;

implementation

uses
  System.NetEncoding
  ,System.Hash
  ;

const
  CRYPTPROTECT_UI_FORBIDDEN = $1;
  CRYPTPROTECT_LOCAL_MACHINE = $4;

type
  TDataBlob = record
    cbData: DWORD;
    pbData: PByte;
  end;
  PDataBlob = ^TDataBlob;

function CryptProtectData(const DataIn: TDataBlob; szDataDescr: PWideChar;
  OptionalEntropy: PDataBlob; Reserved, PromptStruct: Pointer; dwFlags: DWORD;
  var DataOut: TDataBlob): BOOL; stdcall; external 'crypt32.dll' name 'CryptProtectData';

// ppszDataDescr ist ein Ausgabeparameter (LPWSTR*); hier immer nil.
function CryptUnprotectData(const DataIn: TDataBlob; ppszDataDescr: PPWideChar;
  OptionalEntropy: PDataBlob; Reserved, PromptStruct: Pointer; dwFlags: DWORD;
  var DataOut: TDataBlob): BOOL; stdcall; external 'crypt32.dll' name 'CryptUnprotectData';

function ToBlob(const ABytes: TBytes): TDataBlob;
begin
  Result.cbData := Length(ABytes);
  if Length(ABytes) > 0 then
    Result.pbData := @ABytes[0]
  else
    Result.pbData := nil;
end;

// Base64 ohne Zeilenumbrueche: nur A-Z a-z 0-9 + /, Laenge durch 4 teilbar,
// hoechstens zwei '=' am Ende.
function IsStrictBase64(const AText: String): Boolean;
var
  i, lPad: Integer;
begin
  Result := False;
  if (AText = '') or (Length(AText) mod 4 <> 0) then
    Exit;
  lPad := 0;
  if AText[Length(AText)] = '=' then
    Inc(lPad);
  if (Length(AText) > 1) and (AText[Length(AText) - 1] = '=') then
    Inc(lPad);
  for i := 1 to Length(AText) - lPad do
    if not CharInSet(AText[i], ['A'..'Z', 'a'..'z', '0'..'9', '+', '/']) then
      Exit;
  Result := True;
end;

{ TTraffiqxTokenProtection }

class function TTraffiqxTokenProtection.Protect(const APlain: String; out ACipher: TBytes;
  out AError: DWORD; AScope: TTraffiqxProtectionScope; const AEntropy: String): Boolean;
var
  lPlain, lEntropy: TBytes;
  lIn, lEntropyBlob, lOut: TDataBlob;
  lFlags: DWORD;
begin
  ACipher := nil;
  AError := 0;
  if APlain = '' then
    Exit(True);
  lPlain := TEncoding.UTF8.GetBytes(APlain);
  lEntropy := TEncoding.UTF8.GetBytes(AEntropy);
  lIn := ToBlob(lPlain);
  lEntropyBlob := ToBlob(lEntropy);
  lOut := Default(TDataBlob);
  lFlags := CRYPTPROTECT_UI_FORBIDDEN;
  if AScope = tpsLocalMachine then
    lFlags := lFlags or CRYPTPROTECT_LOCAL_MACHINE;
  try
    Result := CryptProtectData(lIn, nil, @lEntropyBlob, nil, nil, lFlags, lOut);
    if not Result then
    begin
      AError := GetLastError;
      Exit;
    end;
    try
      SetLength(ACipher, lOut.cbData);
      if lOut.cbData > 0 then
        Move(lOut.pbData^, ACipher[0], lOut.cbData);
    finally
      LocalFree(HLOCAL(lOut.pbData));
    end;
  finally
    // Klartext nicht laenger als noetig im Speicher stehen lassen
    if Length(lPlain) > 0 then
      FillChar(lPlain[0], Length(lPlain), 0);
  end;
end;

class function TTraffiqxTokenProtection.Unprotect(const ACipher: TBytes; out APlain: String;
  out AError: DWORD; const AEntropy: String): Boolean;
var
  lEntropy, lPlain: TBytes;
  lIn, lEntropyBlob, lOut: TDataBlob;
begin
  APlain := '';
  AError := 0;
  if Length(ACipher) = 0 then
    Exit(True);
  lEntropy := TEncoding.UTF8.GetBytes(AEntropy);
  lIn := ToBlob(ACipher);
  lEntropyBlob := ToBlob(lEntropy);
  lOut := Default(TDataBlob);
  // Die Bindung (Benutzer/Rechner) steht im Blob selbst.
  Result := CryptUnprotectData(lIn, nil, @lEntropyBlob, nil, nil,
    CRYPTPROTECT_UI_FORBIDDEN, lOut);
  if not Result then
  begin
    AError := GetLastError;
    Exit;
  end;
  try
    SetLength(lPlain, lOut.cbData);
    if lOut.cbData > 0 then
      Move(lOut.pbData^, lPlain[0], lOut.cbData);
    try
      APlain := TEncoding.UTF8.GetString(lPlain);
    finally
      if Length(lPlain) > 0 then
        FillChar(lPlain[0], Length(lPlain), 0);
    end;
  finally
    if lOut.cbData > 0 then
      FillChar(lOut.pbData^, lOut.cbData, 0);
    LocalFree(HLOCAL(lOut.pbData));
  end;
end;

class function TTraffiqxTokenProtection.ProtectToText(const APlain: String;
  AScope: TTraffiqxProtectionScope; const AEntropy: String): String;
var
  lCipher: TBytes;
  lError: DWORD;
  lBase64: TBase64Encoding;
begin
  if APlain = '' then
    Exit('');
  if not Protect(APlain, lCipher, lError, AScope, AEntropy) then
    RaiseLastOSError(lError);
  // Eigene Instanz ohne Zeilenumbrueche (TNetEncoding.Base64 bricht nach 76 Zeichen um)
  lBase64 := TBase64Encoding.Create(0);
  try
    Result := TEXT_PREFIX + lBase64.EncodeBytesToString(lCipher);
  finally
    lBase64.Free;
  end;
end;

class function TTraffiqxTokenProtection.UnprotectFromText(const AText: String;
  out APlain: String; const AEntropy: String): Boolean;
var
  lCipher: TBytes;
  lError: DWORD;
begin
  APlain := '';
  if AText = '' then
    Exit(True);
  if not AText.StartsWith(TEXT_PREFIX) then
  begin
    APlain := AText;  // alte Klartext-Ablage
    Exit(True);
  end;
  // Streng pruefen: Der RTL-Decoder ueberspringt ungueltige Zeichen.
  if not IsStrictBase64(Copy(AText, Length(TEXT_PREFIX) + 1, MaxInt)) then
    Exit(False);
  try
    lCipher := TNetEncoding.Base64.DecodeStringToBytes(Copy(AText, Length(TEXT_PREFIX) + 1, MaxInt));
  except
    Exit(False);
  end;
  // Kaputtes Base64 dekodiert nachsichtig zu nichts: mit Kennzeichen, aber
  // ohne Inhalt ist das kein leeres Token, sondern unlesbar.
  if Length(lCipher) = 0 then
    Exit(False);
  Result := Unprotect(lCipher, APlain, lError, AEntropy);
end;

class function TTraffiqxTokenProtection.Fingerprint(const ARefreshToken: String): String;
begin
  if ARefreshToken = '' then
    Exit('');
  Result := Copy(THashSHA2.GetHashString(ARefreshToken, THashSHA2.TSHA2Version.SHA256), 1, 16);
end;

end.
