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

unit intf.TRAFFIQXHttpLog;

// Technisches HTTP-Protokoll fuer intf.TRAFFIQXInvoiceAPI (DATEV-Abnahme,
// MUST): jede Anfrage und Antwort an DATEV und den OAuth-Broker,
// chronologisch, mindestens 14 Tage, dazu die Fehlerquote (unter 10 %).
//
// Einbinden:
//   TTraffiqxHttpLog.ResolveDirectory := function: String
//     begin Result := 'X:\Pfad\zum\Protokoll\'; end;
//   TTraffiqxHttpLog.Attach(lApi);   // bzw. lApi.OnHttpTrace := TTraffiqxHttpLog.Write
//   ...
//   TTraffiqxHttpLog.GetErrorRate(TDateTime.NowUTC, lRate);   // nicht im UI-Thread
//
// Mehrere Prozesse (etwa ein Server und mehrere Arbeitsplaetze) duerfen in
// dasselbe Verzeichnis schreiben: eine Datei pro Tag (UTC)
//   TIA-HTTP_yyyy-mm-dd.log
// Jeder Eintrag nennt Rechner, Programm und Benutzer.
//
// Write reiht den Eintrag nur ein; ein Hintergrund-Thread pro Prozess haengt
// ihn an die Datei. Der HTTP-Aufruf wartet also nie auf Platte oder Netz. Ist
// die Datei gesperrt oder das Verzeichnis nicht erreichbar, bleiben die
// Eintraege im Speicher und werden nachgeschrieben (hoechstens MAX_PENDING;
// darueber fallen die aeltesten weg, das wird im Protokoll vermerkt). Beim
// Programmende wird noch bis zu 3 Sekunden nachgeschrieben.
//
// Reihenfolge: Innerhalb eines Prozesses in der Reihenfolge der Aufrufe.
// Zwischen Prozessen entscheidet, wer die Datei zuerst bekommt; massgeblich
// ist deshalb der Zeitstempel (UTC, Millisekunden) am Zeilenanfang, nach dem
// Auswertungen sortieren.
//
// Dateien, deren Tag mehr als 14 Tage zurueckliegt, loescht der Schreiber
// beim ersten Schreiben eines Tages. Tokens und Secrets filtert bereits die
// Bibliothek (OnHttpTrace). Ein Fehler im Protokoll stoert den eigentlichen
// Aufruf nie.
//
// Nur fuer EXE-Programme: finalization laesst einen nach 3 s noch haengenden
// Schreiber stehen, das waere beim Entladen einer DLL/BPL unsicher. Der Code,
// der beim Programmende noch in Hintergrund-Threads laufen kann, meidet
// RTL-Globals, die dabei freigegeben werden (TEncoding.UTF8, TNetEncoding).
//
// Aufbau eines Eintrags (erste Zeile, danach eingerueckt Header und Body):
//   2026-09-30T15:05:04.145Z d24c3d8d-a15d >> GET https://... | RECHNER | Programm.exe | benutzer
//   2026-09-30T15:05:04.253Z d24c3d8d-a15d << 401 Unauthorized (109 ms) | RECHNER | Programm.exe | benutzer
//   2026-09-30T15:05:04.253Z d24c3d8d-a15d << 0 FEHLER ENetHTTPClientException: ... (21016 ms) | ...

interface

uses
  System.SysUtils
  ,intf.TRAFFIQXInvoiceAPI
  ;

type
  TTraffiqxErrorRate = record
    Requests: Integer;    // Anfragen an AHostDomain und Subdomains (Broker zaehlt nicht)
    Errors: Integer;      // davon Antworten mit 4xx/5xx
    NoResponse: Integer;  // davon Transportfehler ohne HTTP-Antwort
    Unreadable: Integer;  // Tagesdateien, die nicht (vollstaendig) lesbar waren
    Unreachable: Boolean; // Protokollverzeichnis nicht erreichbar (Netz, Rechte)
  end;

  TTraffiqxHttpLog = class
  public
    const
      RETENTION_DAYS = 14;
      FILE_PREFIX = 'TIA-HTTP_';
      FILE_EXT = '.log';
      MAX_PENDING = 20000;
    class var
      // Liefert das Protokollverzeichnis (mit oder ohne abschliessenden
      // Trenner); leer = kein Protokoll. Wird im Thread des HTTP-Aufrufs
      // gefragt, nie im Schreiber - darf also auf Objekte der Anwendung
      // zugreifen, solange diese beim HTTP-Aufruf noch leben.
      ResolveDirectory: TFunc<String>;
    // Verzeichnis der Protokolldateien, '' wenn nicht bestimmbar
    class function Directory: String;
    // Haengt das Protokoll an eine API-Instanz (nur wenn noch keins haengt)
    class procedure Attach(AApi: TTRAFFIQXInvoiceAPI);
    // Reiht einen Eintrag ein (Handler fuer OnHttpTrace, threadsicher)
    class procedure Write(const AEntry: TTraffiqxHttpTrace);
    // Schreibt alles Eingereihte sofort; False, wenn etwas offen blieb.
    // Fuer Tests; im Betrieb erledigt das der Hintergrund-Thread.
    class function Flush: Boolean;
    // Loescht Dateien, deren Tag mehr als RETENTION_DAYS zurueckliegt
    class procedure Cleanup(const ADirectory: String; ATodayUtc: TDateTime);
    // Fehlerquote (DATEV-Abnahme: unter 10 %) aus dem Protokoll der letzten
    // RETENTION_DAYS * 24 Stunden, ueber alle Rechner und Programme (siehe
    // TTraffiqxErrorRate). Gezaehlt werden Anfragen an AHostDomain und dessen
    // Subdomains. False, wenn kein Protokollverzeichnis bestimmbar ist. Liest
    // Dateien, kann ueber UNC dauern: nicht im UI-Thread aufrufen. Laeuft die
    // Auswertung in einem Thread, der beim Programmende noch leben kann, das
    // Verzeichnis vorher bestimmen und die Ueberladung mit ADirectory nehmen.
    class function GetErrorRate(ANowUtc: TDateTime; out ARate: TTraffiqxErrorRate;
      const AHostDomain: String = 'datev.de'): Boolean; overload;
    class function GetErrorRate(const ADirectory: String; ANowUtc: TDateTime;
      out ARate: TTraffiqxErrorRate; const AHostDomain: String = 'datev.de'): Boolean; overload;
  end;

implementation

uses
  Winapi.Windows
  ,System.Classes, System.SyncObjs, System.DateUtils, System.IOUtils
  ,System.Generics.Collections
  ,System.Net.URLClient
  ;

type
  TPendingEntry = record
    FileName: String;  // Tagesdatei, beim Einreihen bestimmt
    Text: String;
  end;

  TLogWriter = class(TThread)
  protected
    procedure Execute; override;
  end;

var
  GLock: TCriticalSection;          // schuetzt GQueue, GDropped, GStopping, GWriter
  GFlushLock: TCriticalSection;     // nur ein Schreibdurchgang zur Zeit
  GQueue: TList<TPendingEntry>;
  GDropped: Integer = 0;
  GStopping: Boolean = False;
  GWakeup: TEvent;
  GWriter: TLogWriter;
  GLastCleanupDay: Integer = 0;     // nur im Schreibdurchgang
  GSource: String = '';             // einmal in initialization ermittelt
  // Eigene UTF-8-Kodierung statt TEncoding.UTF8: Schreiber und Auswertung
  // koennen beim Programmende noch laufen, TEncoding.UTF8 gibt die RTL dann
  // frei. Wird wie die Sperren nie freigegeben.
  GUtf8: TEncoding;
  GLastDir: String = '';            // Verzeichnis des zuletzt eingereihten Eintrags

function FormatEntry(const AEntry: TTraffiqxHttpTrace): String;
var
  lText: TStringBuilder;
  lHeader: TNetHeader;
  lLine: String;
begin
  lText := TStringBuilder.Create;
  try
    lText.Append(DateToISO8601(AEntry.TimestampUtc, True)).Append(' ')
      .Append(AEntry.RequestId);
    if AEntry.Kind = htkRequest then
      lText.Append(' >> ').Append(AEntry.Method).Append(' ').Append(AEntry.Url)
    else if AEntry.StatusCode = 0 then
      lText.Append(' << 0 FEHLER ').Append(AEntry.ErrorMessage.Replace(#13, ' ').Replace(#10, ' '))
        .Append(' (').Append(AEntry.DurationMs).Append(' ms)')
    else
    begin
      lText.Append(' << ').Append(AEntry.StatusCode);
      if AEntry.StatusText <> '' then  //bei HTTP/2 leer
        lText.Append(' ').Append(AEntry.StatusText);
      lText.Append(' (').Append(AEntry.DurationMs).Append(' ms)');
    end;
    lText.Append(' | ').Append(GSource).Append(sLineBreak);

    for lHeader in AEntry.Headers do
      lText.Append('    ').Append(lHeader.Name).Append(': ')
        .Append(lHeader.Value.Replace(#13, ' ').Replace(#10, ' ')).Append(sLineBreak);

    if AEntry.Body <> '' then
    begin
      lText.Append('    Body:').Append(sLineBreak);
      for lLine in AEntry.Body.Replace(#13#10, #10).Split([#10, #13]) do
        lText.Append('      ').Append(lLine).Append(sLineBreak);
    end;
    Result := lText.ToString;
  finally
    lText.Free;
  end;
end;

function DayFileName(const ADirectory: String; ADayUtc: TDateTime): String;
begin
  Result := ADirectory + TTraffiqxHttpLog.FILE_PREFIX
    + FormatDateTime('yyyy"-"mm"-"dd', ADayUtc) + TTraffiqxHttpLog.FILE_EXT;
end;

// Haengt an die Datei an. Mehrere Prozesse schreiben in dieselbe Datei:
// OPEN_ALWAYS legt sie an, ohne eine gerade von einem anderen Prozess
// angelegte Datei zu leeren; die Schreibsperre haelt Eintraege beisammen und
// garantiert, dass das Dateiende waehrenddessen stehen bleibt. Scheitert das
// Schreiben mittendrin, wird auf die alte Laenge zurueckgeschnitten - ein
// neuer Versuch haengt dann nichts doppelt an. Scheitert auch das
// Zurueckschneiden (etwa Netzabbruch), darf nicht wiederholt werden, sonst
// stuende der Anfang doppelt da: arAbandoned. Bei Sperre kurz wiederholen,
// sonst arRetry (der Schreiber versucht es spaeter erneut).
type
  TAppendResult = (arWritten, arRetry, arAbandoned);

function AppendToFile(const AFileName: String; const ABytes: TBytes): TAppendResult;
var
  lHandle: THandle;
  lWritten: DWORD;
  lTry: Integer;
  lStart, lDummy: Int64;
begin
  Result := arRetry;
  if Length(ABytes) = 0 then
    Exit(arWritten);
  ForceDirectories(ExtractFilePath(AFileName));
  for lTry := 1 to 10 do
  begin
    lHandle := CreateFile(PChar(AFileName), GENERIC_WRITE, FILE_SHARE_READ, nil,
      OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
    if lHandle <> INVALID_HANDLE_VALUE then
    begin
      try
        if not SetFilePointerEx(lHandle, 0, @lStart, FILE_END) then
          Exit;
        if WriteFile(lHandle, ABytes[0], Length(ABytes), lWritten, nil)
          and (Integer(lWritten) = Length(ABytes)) then
          Result := arWritten
        else if SetFilePointerEx(lHandle, lStart, @lDummy, FILE_BEGIN)
          and SetEndOfFile(lHandle) then
          Result := arRetry
        else
          Result := arAbandoned;
      finally
        CloseHandle(lHandle);
      end;
      Exit;
    end;
    if GetLastError <> ERROR_SHARING_VIOLATION then
      Exit;
    Sleep(20);
  end;
end;

// Stellt nicht geschriebene Eintraege wieder an den Anfang der Warteschlange.
// Was ueber MAX_PENDING hinausgeht, faellt vorne weg und wird gezaehlt.
procedure Requeue(const AItems: TArray<TPendingEntry>; AFrom: Integer);
var
  lCount: Integer;
begin
  lCount := Length(AItems) - AFrom;
  if lCount <= 0 then
    Exit;
  GLock.Enter;
  try
    try
      GQueue.InsertRange(0, Copy(AItems, AFrom, lCount));
      while GQueue.Count > TTraffiqxHttpLog.MAX_PENDING do
      begin
        GQueue.Delete(0);
        Inc(GDropped);
      end;
    except
      //Kein Speicher mehr: wenigstens als verworfen zaehlen (ohne Allokation)
      Inc(GDropped, lCount);
    end;
  finally
    GLock.Leave;
  end;
end;

const
  MAX_CHUNK_BYTES = 1024 * 1024;

// Ein Schreibdurchgang: alles Eingereihte, aufeinanderfolgende Eintraege
// derselben Tagesdatei in Stuecken bis etwa 1 MB. Was nicht geschrieben ist
// (Fehler oder Exception), geht zurueck in die Warteschlange.
function FlushPending: Boolean;
var
  lItems: TArray<TPendingEntry>;
  lDropped, i, j: Integer;
  lChunk: TBytesStream;
  lBytes: TBytes;
  lNote: String;
  lNowUtc: TDateTime;
  lDir: String;
  lAppend: TAppendResult;
begin
  GFlushLock.Enter;
  try
    GLock.Enter;
    try
      lItems := GQueue.ToArray;
      GQueue.Clear;
      // Der Zaehler bleibt stehen, bis sein Vermerk geschrieben ist.
      lDropped := GDropped;
      lDir := GLastDir;
    finally
      GLock.Leave;
    end;
    if Length(lItems) = 0 then
    begin
      // Nichts eingereiht, aber ein Verlust ist noch nicht vermerkt: den
      // Vermerk allein schreiben (sonst ginge er ohne weitere Aufrufe verloren).
      if (lDropped = 0) or (lDir = '') then
        Exit(True);
      lNowUtc := TDateTime.NowUTC;
      lNote := DateToISO8601(lNowUtc, True) + ' - !! ' + IntToStr(lDropped)
        + ' Eintraege verworfen, das Protokoll war zu lange nicht schreibbar | '
        + GSource + sLineBreak;
      // Nur ein geschriebener Vermerk senkt den Zaehler; bei arAbandoned steht
      // hoechstens ein Teil da, der Verlust bleibt offen.
      if AppendToFile(DayFileName(lDir, lNowUtc), GUtf8.GetBytes(lNote)) <> arWritten then
        Exit(False);
      GLock.Enter;
      try
        Dec(GDropped, lDropped);
      finally
        GLock.Leave;
      end;
      Exit(True);
    end;

    lNowUtc := TDateTime.NowUTC;
    i := 0;
    lChunk := nil;
    try
      lChunk := TBytesStream.Create;
      while i < Length(lItems) do
      begin
        lChunk.Clear;
        if (i = 0) and (lDropped > 0) then
        begin
          lNote := DateToISO8601(lNowUtc, True) + ' - !! ' + IntToStr(lDropped)
            + ' Eintraege verworfen, das Protokoll war zu lange nicht schreibbar | '
            + GSource + sLineBreak;
          lBytes := GUtf8.GetBytes(lNote);
          lChunk.WriteBuffer(lBytes, Length(lBytes));
        end;
        j := i;
        repeat
          lBytes := GUtf8.GetBytes(lItems[j].Text);
          lChunk.WriteBuffer(lBytes, Length(lBytes));
          Inc(j);
        until (j >= Length(lItems)) or (lChunk.Size >= MAX_CHUNK_BYTES)
          or not SameText(lItems[j].FileName, lItems[i].FileName);

        lAppend := AppendToFile(lItems[i].FileName, Copy(lChunk.Bytes, 0, lChunk.Size));
        if lAppend = arRetry then
          Break;
        if lAppend = arAbandoned then
        begin
          // Teilweise geschrieben und nicht zurueckzunehmen: nicht wiederholen,
          // als verworfen vermerken (der Verlustvermerk kommt beim naechsten Mal).
          GLock.Enter;
          try
            Inc(GDropped, j - i);
          finally
            GLock.Leave;
          end;
          lDropped := 0;
          i := j;
          Continue;
        end;
        if (i = 0) and (lDropped > 0) then
        begin
          GLock.Enter;
          try
            Dec(GDropped, lDropped);
          finally
            GLock.Leave;
          end;
          lDropped := 0;
        end;
        i := j;
      end;
    except
      //unten: Rest zurueck in die Warteschlange
    end;
    lChunk.Free;
    if i < Length(lItems) then
    begin
      Requeue(lItems, i);
      Exit(False);
    end;

    // Aufraeumen einmal am Tag, im Verzeichnis des zuletzt geschriebenen Eintrags
    if GLastCleanupDay <> Trunc(lNowUtc) then
    begin
      GLastCleanupDay := Trunc(lNowUtc);
      lDir := ExtractFilePath(lItems[High(lItems)].FileName);
      try
        TTraffiqxHttpLog.Cleanup(lDir, lNowUtc);
      except
        //Aufraeumen ist zweitrangig; am naechsten Tag wieder
      end;
    end;
    Result := True;
  finally
    GFlushLock.Leave;
  end;
end;

{ TLogWriter }

procedure TLogWriter.Execute;
var
  lOk: Boolean;
  lStopping: Boolean;
  lEmpty: Boolean;
begin
  lOk := True;
  while True do
  begin
    GLock.Enter;
    try
      lStopping := GStopping;
    finally
      GLock.Leave;
    end;
    // Nach einem Fehler beim Beenden rasch erneut versuchen; finalization
    // wartet hoechstens 3 s und laesst den Thread danach stehen.
    if lStopping and not lOk then
      Sleep(200)
    else
      GWakeup.WaitFor(1000);
    try
      lOk := FlushPending;
    except
      lOk := False;
    end;
    GLock.Enter;
    try
      lStopping := GStopping;
      lEmpty := (GQueue.Count = 0) and (GDropped = 0);
    finally
      GLock.Leave;
    end;
    if lStopping and lEmpty and lOk then
      Exit;
  end;
end;

function LocalComputerName: String;
var
  lBuffer: array[0..MAX_COMPUTERNAME_LENGTH] of Char;
  lSize: DWORD;
begin
  lSize := Length(lBuffer);
  if GetComputerName(lBuffer, lSize) then
    Result := lBuffer
  else
    Result := '?';
end;

function LocalUserName: String;
var
  lBuffer: array[0..256] of Char;
  lSize: DWORD;
begin
  lSize := Length(lBuffer);
  if GetUserName(lBuffer, lSize) then
    Result := lBuffer
  else
    Result := '?';
end;

{ TTraffiqxHttpLog }

class function TTraffiqxHttpLog.Directory: String;
begin
  Result := '';
  if not Assigned(ResolveDirectory) then
    Exit;
  try
    Result := ResolveDirectory();
  except
    Result := '';
  end;
  // Relative Angaben absolut machen (sonst fehlte bei "http-log" das
  // Elternverzeichnis fuer die Unterscheidung fehlt/unerreichbar)
  if Result <> '' then
    Result := IncludeTrailingPathDelimiter(ExpandFileName(Result));
end;

class procedure TTraffiqxHttpLog.Attach(AApi: TTRAFFIQXInvoiceAPI);
begin
  if (AApi <> nil) and not Assigned(AApi.OnHttpTrace) then
    AApi.OnHttpTrace := Write;
end;

// Tag aus dem Dateinamen TIA-HTTP_yyyy-mm-dd.log
function TryFileDay(const AFileName: String; out ADay: TDateTime): Boolean;
var
  lName: String;
  lFormat: TFormatSettings;
begin
  lFormat := TFormatSettings.Invariant;
  lFormat.DateSeparator := '-';
  lFormat.ShortDateFormat := 'yyyy-mm-dd';
  lName := ChangeFileExt(ExtractFileName(AFileName), '');
  Delete(lName, 1, Length(TTraffiqxHttpLog.FILE_PREFIX));
  Result := TryStrToDate(lName, ADay, lFormat);
end;

class procedure TTraffiqxHttpLog.Cleanup(const ADirectory: String; ATodayUtc: TDateTime);
var
  lFile: String;
  lDay: TDateTime;
begin
  if not DirectoryExists(ADirectory) then
    Exit;
  for lFile in TDirectory.GetFiles(ADirectory, FILE_PREFIX + '*' + FILE_EXT) do
    if TryFileDay(lFile, lDay) and (Trunc(lDay) < Trunc(ATodayUtc) - RETENTION_DAYS) then
      System.SysUtils.DeleteFile(lFile);
end;

// Host einer URL in Kleinbuchstaben ('' wenn keiner). Ohne TURI: das nutzt
// globale Objekte (TNetEncoding), die beim Programmende freigegeben werden.
function UrlHost(const AUrl: String): String;
var
  i, j: Integer;
begin
  Result := '';
  i := Pos('://', AUrl);
  if i = 0 then
    Exit;
  Inc(i, 3);
  j := i;
  while (j <= Length(AUrl)) and not CharInSet(AUrl[j], ['/', ':', '?', '#', '@']) do
    Inc(j);
  // Benutzerangaben (user@host) ueberspringen
  if (j <= Length(AUrl)) and (AUrl[j] = '@') then
    Exit(UrlHost(Copy(AUrl, 1, i - 1) + Copy(AUrl, j + 1, MaxInt)));
  Result := LowerCase(Copy(AUrl, i, j - i));
end;

type
  TListResult = (llOk, llNoDirectory, llUnreachable);

// Listet die Protokolldateien und unterscheidet anhand der Windows-Fehler:
// Protokollverzeichnis fehlt unter einem vorhandenen Vorfahren = noch kein
// Protokoll; Zugriff verweigert, Netzfehler (auch mitten in der Auflistung)
// oder kein vorhandener Vorfahr = nicht erreichbar.
function ListLogFiles(const ADirectory: String; out AFiles: TArray<String>): TListResult;
var
  lFind: THandle;
  lData: TWin32FindData;
  lError: DWORD;
  lParentDir, lPrevDir: String;
  lAttr: DWORD;
begin
  AFiles := nil;
  lFind := FindFirstFile(PChar(ADirectory + TTraffiqxHttpLog.FILE_PREFIX + '*'
    + TTraffiqxHttpLog.FILE_EXT), lData);
  if lFind = INVALID_HANDLE_VALUE then
  begin
    lError := GetLastError;
    if lError = ERROR_FILE_NOT_FOUND then
      Exit(llOk);  //Verzeichnis da, aber leer
    if lError <> ERROR_PATH_NOT_FOUND then
      Exit(llUnreachable);
    // Protokollverzeichnis fehlt: nach oben gehen bis zum ersten vorhandenen
    // Verzeichnis. Gibt es eines, wurde nur noch nichts geschrieben (der
    // Schreiber legt fehlende Verzeichnisse an). Scheitert der Zugriff mit
    // einem anderen Fehler als "nicht gefunden" (keine Rechte, Netz oder
    // Freigabe weg) oder gibt es keinen vorhandenen Vorfahren, ist das
    // Verzeichnis nicht erreichbar.
    lParentDir := ADirectory;
    repeat
      lPrevDir := lParentDir;
      lParentDir := ExtractFilePath(ExcludeTrailingPathDelimiter(lParentDir));
      if (lParentDir = '') or SameText(lParentDir, lPrevDir) then
        Exit(llUnreachable);
      lAttr := GetFileAttributes(PChar(lParentDir));
      if lAttr <> INVALID_FILE_ATTRIBUTES then
      begin
        if lAttr and FILE_ATTRIBUTE_DIRECTORY <> 0 then
          Exit(llNoDirectory);
        Exit(llUnreachable);
      end;
      lError := GetLastError;
      if (lError <> ERROR_FILE_NOT_FOUND) and (lError <> ERROR_PATH_NOT_FOUND) then
        Exit(llUnreachable);
    until False;
  end;
  try
    repeat
      if lData.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY = 0 then
        AFiles := AFiles + [ADirectory + lData.cFileName];
    until not FindNextFile(lFind, lData);
    if GetLastError <> ERROR_NO_MORE_FILES then
      Exit(llUnreachable);  //Abbruch mitten in der Auflistung
  finally
    Winapi.Windows.FindClose(lFind);
  end;
  Result := llOk;
end;

class function TTraffiqxHttpLog.GetErrorRate(ANowUtc: TDateTime;
  out ARate: TTraffiqxErrorRate; const AHostDomain: String): Boolean;
var
  lDir: String;
begin
  ARate := Default(TTraffiqxErrorRate);
  lDir := Directory;
  if lDir = '' then
    Exit(False);
  Result := GetErrorRate(lDir, ANowUtc, ARate, AHostDomain);
end;

class function TTraffiqxHttpLog.GetErrorRate(const ADirectory: String; ANowUtc: TDateTime;
  out ARate: TTraffiqxErrorRate; const AHostDomain: String): Boolean;
var
  lDomain: String;
  lDirectory: String;
  lFile, lLine, lHost: String;
  lFiles: TArray<String>;
  lDay, lStamp, lFrom: TDateTime;
  lParts: TArray<String>;
  lMatchIds: TDictionary<String, Boolean>;
  lStream: TFileStream;
  lReader: TStreamReader;
  lCode: Integer;
begin
  ARate := Default(TTraffiqxErrorRate);
  Result := True;
  lDirectory := IncludeTrailingPathDelimiter(ExpandFileName(ADirectory));
  lDomain := LowerCase(AHostDomain);
  case ListLogFiles(lDirectory, lFiles) of
    llNoDirectory:
      Exit;  //noch kein Protokoll
    llUnreachable:
    begin
      ARate.Unreachable := True;
      Exit;
    end;
  end;

  // Rollierend: Anfragen der letzten RETENTION_DAYS * 24 Stunden nach ihrem
  // Zeitstempel. Die Dateien davor werden nur grob nach Tag vorgefiltert.
  lFrom := ANowUtc - RETENTION_DAYS;
  TArray.Sort<String>(lFiles);

  // Anfrage- und Antwortzeilen tragen dieselbe RequestId; nur die
  // Anfragezeile nennt die URL. Die Zuordnung reicht ueber Dateigrenzen
  // (Anfrage kurz vor, Antwort kurz nach Mitternacht UTC).
  lMatchIds := TDictionary<String, Boolean>.Create;
  try
    for lFile in lFiles do
    begin
      if not TryFileDay(lFile, lDay) or (Trunc(lDay) < Trunc(lFrom)) then
        Continue;
      try
        // Der Schreiber haelt die Datei mit Schreibzugriff offen: lesen ohne Sperre.
        lStream := TFileStream.Create(lFile, fmOpenRead or fmShareDenyNone);
      except
        Inc(ARate.Unreadable);
        Continue;
      end;
      try
        try
          lReader := TStreamReader.Create(lStream, GUtf8);
          try
            while not lReader.EndOfStream do
            begin
              lLine := lReader.ReadLine;
              // Nur Kopfzeilen: "<UTC> <RequestId> >> METHODE URL | ..." bzw.
              // "<UTC> <RequestId> << CODE ..."; Header/Body sind eingerueckt.
              if (lLine = '') or not CharInSet(lLine[1], ['0'..'9']) then
                Continue;
              lParts := lLine.Split([' '], 6);
              if Length(lParts) < 4 then
                Continue;
              if (lParts[2] = '>>') and (Length(lParts) >= 5) then
              begin
                if not TryISO8601ToDate(lParts[0], lStamp, True) or (lStamp < lFrom) then
                  Continue;
                lHost := UrlHost(lParts[4]);
                if (lHost = lDomain) or lHost.EndsWith('.' + lDomain) then
                begin
                  lMatchIds.AddOrSetValue(lParts[1], True);
                  Inc(ARate.Requests);
                end;
              end
              else if (lParts[2] = '<<') and lMatchIds.ContainsKey(lParts[1])
                and TryStrToInt(lParts[3], lCode) then
              begin
                if lCode = 0 then
                  Inc(ARate.NoResponse)
                else if lCode >= 400 then
                  Inc(ARate.Errors);
              end;
            end;
          finally
            lReader.Free;
          end;
        except
          // Lesefehler mitten in der Datei: als unvollstaendig kennzeichnen
          Inc(ARate.Unreadable);
        end;
      finally
        lStream.Free;
      end;
    end;
  finally
    lMatchIds.Free;
  end;
end;

class procedure TTraffiqxHttpLog.Write(const AEntry: TTraffiqxHttpTrace);
var
  lItem: TPendingEntry;
  lDir: String;
begin
  try
    lDir := Directory;
    if lDir = '' then
      Exit;
    lItem.FileName := DayFileName(lDir, TDateTime.NowUTC);
    lItem.Text := FormatEntry(AEntry);

    GLock.Enter;
    try
      if GStopping then
        Exit;
      GQueue.Add(lItem);
      GLastDir := lDir;
      if GQueue.Count > MAX_PENDING then
      begin
        GQueue.Delete(0);
        Inc(GDropped);
      end;
      if GWriter = nil then
        GWriter := TLogWriter.Create(False);
    finally
      GLock.Leave;
    end;
    GWakeup.SetEvent;
  except
    //Das Protokoll darf den Aufruf nie stoeren.
  end;
end;

class function TTraffiqxHttpLog.Flush: Boolean;
begin
  Result := FlushPending;
end;

procedure StopWriter;
var
  lWriter: TLogWriter;
begin
  GLock.Enter;
  try
    GStopping := True;
    lWriter := GWriter;
  finally
    GLock.Leave;
  end;
  if lWriter = nil then
    Exit;
  GWakeup.SetEvent;
  // Hoechstens 3 s nachschreiben. Ist der Schreiber dann nicht fertig (etwa
  // Netzlaufwerk haengt), bleiben Thread und Verwaltungsobjekte stehen - der
  // Prozess endet ohnehin.
  if WaitForSingleObject(lWriter.Handle, 3000) = WAIT_OBJECT_0 then
  begin
    lWriter.Free;
    GWriter := nil;
  end;
end;

initialization
  GLock := TCriticalSection.Create;
  GFlushLock := TCriticalSection.Create;
  GQueue := TList<TPendingEntry>.Create;
  GUtf8 := TUTF8Encoding.Create;
  GWakeup := TEvent.Create(nil, False, False, '');
  GSource := LocalComputerName + ' | ' + ExtractFileName(ParamStr(0)) + ' | ' + LocalUserName;

finalization
  StopWriter;
  // GLock, GFlushLock, GQueue und GWakeup bleiben bewusst stehen: Ein noch
  // laufender Schreiber oder eine Auswertung (Flush) in einem anderen Thread
  // koennte sie sonst nach der Freigabe benutzen. Der Prozess endet ohnehin.

end.
