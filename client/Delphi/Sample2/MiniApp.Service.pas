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

unit MiniApp.Service;

interface

uses
  System.SysUtils, MiniApp.Model, MiniApp.Storage, intf.TRAFFIQXInvoiceAPI;

type
  TMiniAppLogKind = (lkInfo, lkWarning, lkError);
  TMiniAppLogEvent = reference to procedure(const AText: string; AKind: TMiniAppLogKind);
  TMiniAppChangedEvent = reference to procedure;
  TMiniAppConfirmLoginEvent = reference to function: Boolean;

  // Eine Instanz, ausschließlich im Hauptthread. Callbacks dürfen weder warten
  // noch Nachrichten pumpen. Ausnahme: OnConfirmLoginUnconfirmed wird nur vor
  // einem neuen Login ohne laufendes Polling aufgerufen und darf modal fragen.
  // S4 muss die Thread-Zuordnung ausdrücklich neu regeln.
  TMiniAppService = class
  private
    FApi: TTRAFFIQXInvoiceAPI;
    FConfig: TMiniAppClientConfig;
    FEnvironment: TMiniAppEnvironment;
    FLog: TMiniAppLogEvent;
    FOnChanged: TMiniAppChangedEvent;
    FOnConfirmLoginUnconfirmed: TMiniAppConfirmLoginEvent;
    FConnected: Boolean;
    FConnecting: Boolean;
    FBusy: Boolean;
    FCancelRequested: Boolean;
    FRevocationPending: Boolean;
    FLoginUnconfirmed: Boolean;
    FLoginUnconfirmedAt: TDateTime;
    FStorageBlocked: Boolean;
    FUserName: string;
    FHelpUrl: string;
    procedure RequireMainThread;
    procedure Changed;
    procedure SetBusy(AValue: Boolean);
    procedure Log(const AText: string; AKind: TMiniAppLogKind = lkInfo);
    function SafeText(const AText: string): string;
    procedure ShowApiError(const AContext: string; AError: TTraffiqxError);
    procedure PersistTokens;
    procedure MarkLoginUnconfirmed;
    function ConfirmLoginUnconfirmed: Boolean;
    function ClearTokens: Boolean;
    function TryRevokeTokens: Boolean;
    function EnsureAccessTokenCore(AMinValidSeconds: Integer): Boolean;
    function CheckConnectionCore: Boolean;
    procedure HandlePollingCompleted(const AResult: TTraffiqxPollResult;
      ASender: TTRAFFIQXInvoiceAPI);
    function GetConnected: Boolean;
    function GetHasTokens: Boolean;
    function GetCanChangeEnvironment: Boolean;
    function GetRefreshExpiresAt: TDateTime;
    function GetTraffiqxID: string;
  public
    constructor Create(const AConfig: TMiniAppClientConfig;
      AEnvironment: TMiniAppEnvironment; const ALog: TMiniAppLogEvent);
    destructor Destroy; override;
    procedure Connect;
    procedure CancelConnect;
    procedure Disconnect;
    function CheckConnection: Boolean;
    function EnsureAccessToken(AMinValidSeconds: Integer): Boolean;
    procedure SetEnvironment(AEnvironment: TMiniAppEnvironment);
    property OnChanged: TMiniAppChangedEvent read FOnChanged write FOnChanged;
    property OnConfirmLoginUnconfirmed: TMiniAppConfirmLoginEvent
      read FOnConfirmLoginUnconfirmed write FOnConfirmLoginUnconfirmed;
    property LoginUnconfirmed: Boolean read FLoginUnconfirmed;
    property Connected: Boolean read GetConnected;
    property Connecting: Boolean read FConnecting;
    property Busy: Boolean read FBusy;
    property HasTokens: Boolean read GetHasTokens;
    property RevocationPending: Boolean read FRevocationPending;
    property StorageBlocked: Boolean read FStorageBlocked;
    property CanChangeEnvironment: Boolean read GetCanChangeEnvironment;
    property RefreshExpiresAt: TDateTime read GetRefreshExpiresAt;
    property UserName: string read FUserName;
    property TraffiqxID: string read GetTraffiqxID;
    property Environment: TMiniAppEnvironment read FEnvironment;
    property HelpUrl: string read FHelpUrl;
  end;

implementation

uses
  System.Classes, System.DateUtils, System.NetEncoding, intf.TRAFFIQXHttpLog;

procedure TMiniAppService.RequireMainThread;
begin
  if TThread.CurrentThread.ThreadID <> MainThreadID then
    raise EInvalidOperation.Create('Der MiniApp-Service gehört dem Hauptthread.');
end;

constructor TMiniAppService.Create(const AConfig: TMiniAppClientConfig;
  AEnvironment: TMiniAppEnvironment; const ALog: TMiniAppLogEvent);
var
  LTokens: TMiniAppTokens;
begin
  inherited Create;
  RequireMainThread;
  FLog := ALog;
  FConfig := AConfig;
  FApi := TTRAFFIQXInvoiceAPI.Create;
  FApi.ProviderType := tpDatev;
  SetEnvironment(AEnvironment);
  FApi.ClientId := AConfig.ClientID;
  FApi.ClientSecret := AConfig.ClientSecret;
  FApi.TRAFFIQXId := AConfig.TraffiqxID;
  FApi.Scope := AConfig.Scope;
  FApi.AppDisplayName := AConfig.AppDisplayName;
  FApi.OAuth2BrokerCallbackUri := AConfig.OAuth2BrokerCallbackUri;
  FApi.OAuth2BrokerApiKey := AConfig.OAuth2BrokerApiKey;
  // Statischer Empfänger ohne Self/Form-Referenz: ein Trace kann Free überleben.
  TTraffiqxHttpLog.ResolveDirectory :=
    function: string
    begin
      Result := HttpLogDirectory;
    end;
  TTraffiqxHttpLog.Attach(FApi);
  FApi.OnPollingCompleted := HandlePollingCompleted;
  if not LoadTokens(LTokens) then
  begin
    FStorageBlocked := True;
    Log('tokens.dat ist nicht lesbar. Nicht verbunden; Datei bleibt unverändert. ' +
      'Ursprünglichen Windows-Benutzer verwenden oder die alte Verbindung unter ' +
      '„Verbundene Anwendungen“ widerrufen und die Datei anschließend manuell sichern/entfernen.', lkWarning);
    Exit;
  end;
  if (LTokens.AccessToken = '') and (LTokens.RefreshToken = '') and
    not LTokens.RevocationPending and not LTokens.LoginUnconfirmed then
    Exit;
  if (LTokens.Environment <> FEnvironment) or
    (LTokens.ClientID <> FApi.ClientId) or (LTokens.TraffiqxID <> FApi.TRAFFIQXId) then
  begin
    FStorageBlocked := True;
    Log('tokens.dat gehört zu einer anderen Umgebung, Client-ID oder TRAFFIQX-ID. ' +
      'Nicht verbunden; ursprüngliche Stammdaten/.env wiederherstellen und neu starten, ' +
      'dann die alte Verbindung trennen. Die Datei bleibt unverändert.', lkWarning);
    Exit;
  end;
  FApi.AccessToken := LTokens.AccessToken;
  FApi.RefreshToken := LTokens.RefreshToken;
  FApi.AccessTokenExpiresAt := LTokens.AccessExpiresAt;
  FApi.RefreshTokenExpiresAt := LTokens.RefreshExpiresAt;
  FRevocationPending := LTokens.RevocationPending;
  FLoginUnconfirmed := LTokens.LoginUnconfirmed;
  FLoginUnconfirmedAt := LTokens.LoginUnconfirmedAt;
  FUserName := SafeText(LTokens.UserName);
  // Nach Neustart keine grüne Ampel ohne aktuellen HTTP-200-Check.
  if FRevocationPending then
    Log('Widerruf ausstehend. Mit „Mit DATEV verbinden“ oder „Verbindung trennen“ erneut versuchen.', lkWarning)
  else if FLoginUnconfirmed then
    Log('Anmeldung abgebrochen – Verbindung bei DATEV prüfen.', lkWarning)
  else
    Log('Gespeicherte Verbindung geladen. Bitte „Verbindung prüfen“ wählen.');
end;

destructor TMiniAppService.Destroy;
begin
  FOnChanged := nil;
  FOnConfirmLoginUnconfirmed := nil;
  FLog := nil;
  if FApi <> nil then
  begin
    FApi.OnPollingCompleted := nil;
    // Auch direktes Free ohne FormCloseQuery sichert den ungeklärten Login.
    if FConnecting then
      MarkLoginUnconfirmed;
    FApi.CancelPolling;
    FApi.Free;
  end;
  inherited;
end;

procedure TMiniAppService.Changed;
begin
  if Assigned(FOnChanged) then
    FOnChanged();
end;

procedure TMiniAppService.SetBusy(AValue: Boolean);
begin
  FBusy := AValue;
  Changed;
end;

function TMiniAppService.SafeText(const AText: string): string;
  procedure Hide(const ASecret: string);
  begin
    if ASecret = '' then
      Exit;
    Result := StringReplace(Result, ASecret, '[...]', [rfReplaceAll]);
    Result := StringReplace(Result, TNetEncoding.URL.Encode(ASecret), '[...]',
      [rfReplaceAll, rfIgnoreCase]);
  end;
begin
  Result := AText;
  Hide(FApi.AccessToken);
  Hide(FApi.RefreshToken);
  Hide(FConfig.ClientSecret);
  Hide(FConfig.OAuth2BrokerApiKey);
  Result := TTRAFFIQXInvoiceAPI.RedactTokenLike(Result);
end;

procedure TMiniAppService.Log(const AText: string; AKind: TMiniAppLogKind);
begin
  if Assigned(FLog) then
    FLog(SafeText(AText), AKind);
end;

procedure TMiniAppService.ShowApiError(const AContext: string; AError: TTraffiqxError);
var
  LUrl: string;
begin
  LUrl := SafeText(TTraffiqxInboxErrorHelper.HelpUrl(AError));
  if not (LUrl.StartsWith('https://', True) or LUrl.StartsWith('http://', True)) then
    LUrl := '';
  if LUrl = '' then
    LUrl := 'https://developer.datev.de/de/product-detail/traffiqx-invoice';
  FHelpUrl := LUrl;
  Log(AContext + ': ' + TTraffiqxInboxErrorHelper.ErrorText(AError) +
    ' Hilfe: ' + FHelpUrl, lkError);
  Changed;
end;

procedure TMiniAppService.PersistTokens;
var
  LTokens: TMiniAppTokens;
begin
  if FStorageBlocked then
    raise EInvalidOperation.Create('Token-Ablage ist gesperrt.');
  LTokens := Default(TMiniAppTokens);
  LTokens.AccessToken := FApi.AccessToken;
  LTokens.RefreshToken := FApi.RefreshToken;
  LTokens.AccessExpiresAt := FApi.AccessTokenExpiresAt;
  LTokens.RefreshExpiresAt := FApi.RefreshTokenExpiresAt;
  LTokens.RevocationPending := FRevocationPending;
  LTokens.LoginUnconfirmed := FLoginUnconfirmed;
  LTokens.LoginUnconfirmedAt := FLoginUnconfirmedAt;
  LTokens.UserName := FUserName;
  LTokens.Environment := FEnvironment;
  LTokens.ClientID := FApi.ClientId;
  LTokens.TraffiqxID := FApi.TRAFFIQXId;
  SaveTokens(LTokens);
end;

procedure TMiniAppService.MarkLoginUnconfirmed;
begin
  FConnected := False;
  if not FLoginUnconfirmed then
    FLoginUnconfirmedAt := Now;
  FLoginUnconfirmed := True;
  try
    // Vor CancelPolling sichern: dessen Callback kann beim Schließen entfallen.
    PersistTokens;
  except
    FStorageBlocked := True;
    Log('Ungeklärte Anmeldung konnte nicht gespeichert werden. Keine neue Anmeldung; ' +
      'Schreibrechte und Verbindung unter „Verbundene Anwendungen“ bei DATEV prüfen.', lkError);
  end;
end;

function TMiniAppService.ConfirmLoginUnconfirmed: Boolean;
var
  LUnconfirmedAt: TDateTime;
begin
  Result := not FLoginUnconfirmed;
  if Result then
    Exit;
  // Ohne Oberfläche/Bestätigung bleibt der Marker erhalten.
  if not Assigned(FOnConfirmLoginUnconfirmed) then
    Exit;
  if not FOnConfirmLoginUnconfirmed() then
    Exit;
  LUnconfirmedAt := FLoginUnconfirmedAt;
  FLoginUnconfirmed := False;
  FLoginUnconfirmedAt := 0;
  try
    PersistTokens;
    Result := True;
  except
    FLoginUnconfirmed := True;
    FLoginUnconfirmedAt := LUnconfirmedAt;
    FStorageBlocked := True;
    Log('Anmeldestatus konnte nicht gespeichert werden. Keine neue Anmeldung; ' +
      'Schreibrechte für tokens.dat prüfen.', lkError);
  end;
end;

function TMiniAppService.ClearTokens: Boolean;
begin
  FConnected := False;
  FApi.AccessToken := '';
  FApi.RefreshToken := '';
  FApi.AccessTokenExpiresAt := 0;
  FApi.RefreshTokenExpiresAt := 0;
  FUserName := '';
  FRevocationPending := False;
  FLoginUnconfirmed := False;
  FLoginUnconfirmedAt := 0;
  Result := False;
  try
    // Atomarer leerer Datensatz entfernt die Tokenwerte ohne Löschlücke.
    PersistTokens;
    Result := True;
  except
    FStorageBlocked := True;
    Log('Tokens im Speicher verworfen, lokale Ablage konnte nicht geleert werden. ' +
      'Keine neue Anmeldung; Schreibrechte prüfen und Anwendung neu starten.', lkError);
  end;
  Changed;
end;

function TMiniAppService.TryRevokeTokens: Boolean;
var
  LError: TTraffiqxError;
begin
  Result := False;
  FConnected := False;
  FRevocationPending := True;
  LError := nil;
  try
    // Vor dem Netzaufruf sichern. Scheitert die Platte, trotzdem sofort revoken.
    try
      PersistTokens;
    except
      Log('Widerrufstatus konnte nicht gespeichert werden. Widerruf wird trotzdem versucht; ' +
        'Schreibrechte für tokens.dat prüfen.', lkError);
    end;
    try
      if FApi.RevokeTokens(LError) then
      begin
        Result := ClearTokens;
        if Result then
          Log('Verbindung getrennt; Tokens bei DATEV widerrufen und lokal entfernt.');
      end
      else
        ShowApiError('Widerruf fehlgeschlagen', LError);
    except
      Log('Widerruf konnte nicht abgeschlossen werden. Verbindung und Schreibrechte prüfen.', lkError);
    end;
  finally
    LError.Free;
    if FRevocationPending then
      Log('Widerruf ausstehend. Tokens bleiben ausschließlich für den erneuten Widerruf ' +
        'gespeichert; keine neue Anmeldung und kein Refresh.', lkWarning);
    Changed;
  end;
end;

procedure TMiniAppService.Connect;
begin
  RequireMainThread;
  if FBusy or FConnecting or FStorageBlocked then
    Exit;
  SetBusy(True);
  try
    try
      if not ConfirmLoginUnconfirmed then
        Exit;
      if (HasTokens or FRevocationPending) and not TryRevokeTokens then
        Exit;
      if (FApi.ClientId = '') or (FApi.TRAFFIQXId = '') or
        (FApi.Scope = '') or (FApi.AppDisplayName = '') or
        (FApi.OAuth2BrokerCallbackUri = '') or (FApi.OAuth2BrokerApiKey = '') then
      begin
        Log('Client-Konfiguration unvollständig. DATEV-Werte und Broker-Zugang in .env prüfen.', lkError);
        Exit;
      end;
      FHelpUrl := '';
      FCancelRequested := False;
      // Ohne OnOpenAuthUrl verwendet die Bibliothek den Standardbrowser.
      if not FApi.StartAuth then
      begin
        Log('DATEV-Anmeldung konnte nicht gestartet werden. .env, Broker und Verbindung prüfen.', lkError);
        Exit;
      end;
      FConnecting := True;
      FApi.BeginPolling;
      Log('DATEV-Anmeldung im Browser abschließen. Warten auf Rückmeldung …');
    except
      if FConnecting then
        MarkLoginUnconfirmed;
      FApi.CancelPolling;
      FConnecting := False;
      Log('DATEV-Anmeldung konnte nicht gestartet werden.', lkError);
    end;
  finally
    SetBusy(False);
  end;
end;

procedure TMiniAppService.CancelConnect;
begin
  RequireMainThread;
  if not FConnecting then
    Exit;
  FCancelRequested := True;
  MarkLoginUnconfirmed;
  FApi.CancelPolling;
  // Erst der Abschluss gibt den nächsten Login frei (Erfolg/Abbruch-Rennen).
  Log('Abbruch angefordert. Eine noch offene Browser-Anmeldung bitte schließen.');
  Changed;
end;

procedure TMiniAppService.HandlePollingCompleted(const AResult: TTraffiqxPollResult;
  ASender: TTRAFFIQXInvoiceAPI);
begin
  RequireMainThread;
  FConnecting := False;
  SetBusy(True);
  try
    case AResult.Status of
      psSuccess:
        begin
          if FApi.RefreshTokenExpiresAt = 0 then
            FApi.RefreshTokenExpiresAt := FApi.DefaultRefreshTokenExpiresAt(Now);
          FRevocationPending := False;
          FLoginUnconfirmed := False;
          FLoginUnconfirmedAt := 0;
          try
            // Sofort sichern, bevor Check/Userinfo weitere Netzaufrufe auslösen.
            PersistTokens;
          except
            Log('Neue Tokens konnten nicht sicher gespeichert werden; Verbindung wird widerrufen.', lkError);
            TryRevokeTokens;
            Exit;
          end;
          if FCancelRequested then
            TryRevokeTokens
          else
            CheckConnectionCore;
        end;
      psCancelled, psTimeout, psError:
        begin
          // Auch ein Transportfehler kann eine bereits erfolgte Anmeldung verdecken.
          MarkLoginUnconfirmed;
          case AResult.Status of
            psCancelled: Log('Anmeldung abgebrochen – Verbindung bei DATEV prüfen.', lkWarning);
            psTimeout: Log('Zeitüberschreitung der Anmeldung. Offene Browser-Anmeldung schließen; ' +
              'Verbindung bei DATEV prüfen.', lkWarning);
            psError: Log('Anmeldung fehlgeschlagen. Broker-Konfiguration und Verbindung prüfen; ' +
              'auch unter „Verbundene Anwendungen“ bei DATEV prüfen.', lkError);
          end;
        end;
    end;
  finally
    SetBusy(False);
  end;
end;

procedure TMiniAppService.Disconnect;
begin
  RequireMainThread;
  if FBusy or FConnecting or FStorageBlocked then
    Exit;
  SetBusy(True);
  try
    if FLoginUnconfirmed and not HasTokens then
    begin
      // Ohne bekannte Tokens ist kein serverseitiger Widerruf möglich.
      if ClearTokens then
        Log('Lokaler Anmeldemarker entfernt. Eine mögliche Verbindung bei DATEV ' +
          'unter „Verbundene Anwendungen“ prüfen und entfernen.', lkWarning);
    end
    else
      TryRevokeTokens;
  finally
    SetBusy(False);
  end;
end;

function TMiniAppService.EnsureAccessTokenCore(AMinValidSeconds: Integer): Boolean;
begin
  Result := False;
  if FStorageBlocked or FRevocationPending or FLoginUnconfirmed or FConnecting then
    Exit;
  if (FApi.RefreshToken = '') or (FApi.RefreshTokenExpiresAt <= Now) then
  begin
    FConnected := False;
    Log('Nicht verbunden – bitte neu verbinden. Refresh-Token fehlt oder ist abgelaufen.', lkWarning);
    Exit;
  end;
  if (FApi.AccessToken <> '') and
    (FApi.AccessTokenExpiresAt >= IncSecond(Now, AMinValidSeconds)) then
    Exit(True);
  try
    // Ein Neustart nach einem unklaren Single-Use-Austausch darf das alte Token
    // nicht erneut verwenden. Der Marker bleibt bei Transportfehlern erhalten.
    FRevocationPending := True;
    PersistTokens;
    if not FApi.RefreshAccessToken then
      Exit;
    FRevocationPending := False;
    try
      PersistTokens;
    except
      Log('Erneuerte Tokens konnten nicht gespeichert werden; Verbindung wird widerrufen.', lkError);
      TryRevokeTokens;
      Exit;
    end;
    Result := (FApi.AccessToken <> '') and
      (FApi.AccessTokenExpiresAt >= IncSecond(Now, AMinValidSeconds));
    if not Result then
      Log('Access-Token reicht nicht für die angeforderte Restlaufzeit.', lkWarning);
  except
    on E: ETraffiqxTokenError do
    begin
      FConnected := False;
      if E.IsInvalidGrant then
      begin
        ClearTokens;
        Log('Nicht verbunden – bitte neu verbinden. DATEV hat das Refresh-Token verworfen (invalid_grant).', lkWarning);
      end
      else
        Log('Token-Erneuerung fehlgeschlagen (HTTP ' + IntToStr(E.HttpStatus) +
          '). Widerruf ausstehend; bitte Verbindung trennen und neu verbinden.', lkError);
    end;
    on E: Exception do
    begin
      FConnected := False;
      Log('Token-Erneuerung oder Speicherung fehlgeschlagen. Widerruf ausstehend; ' +
        'Verbindung und Schreibrechte prüfen, dann Verbindung trennen.', lkError);
    end;
  end;
end;

function TMiniAppService.EnsureAccessToken(AMinValidSeconds: Integer): Boolean;
begin
  RequireMainThread;
  if AMinValidSeconds < 0 then
    raise EArgumentOutOfRangeException.Create('Restlaufzeit darf nicht negativ sein.');
  Result := False;
  if FBusy then
    Exit;
  SetBusy(True);
  try
    Result := EnsureAccessTokenCore(AMinValidSeconds);
  finally
    SetBusy(False);
  end;
end;

function TMiniAppService.CheckConnectionCore: Boolean;
var
  LError: TTraffiqxError;
  LUserInfo: TTraffiqxUserInfo;
begin
  Result := False;
  FConnected := False;
  if not EnsureAccessTokenCore(60) then
  begin
    // Auch ein nicht mehr nutzbares Token darf nach einem Check-Versuch keine
    // scheinbar aktive Verbindung hinterlassen. Ausstehende Widerrufe nachholen.
    if not FStorageBlocked and (HasTokens or FRevocationPending) then
      TryRevokeTokens;
    Exit;
  end;
  LError := nil;
  try
    try
      if not FApi.CheckConnectionAccess(LError) then
      begin
        ShowApiError('Verbindungscheck fehlgeschlagen', LError);
        TryRevokeTokens;
        Exit;
      end;
    except
      Log('Verbindungscheck fehlgeschlagen; Tokens werden widerrufen.', lkError);
      TryRevokeTokens;
      Exit;
    end;
  finally
    LError.Free;
  end;
  FConnected := True;
  Result := True;
  Log('Verbunden: Inbox und Outbox antworten jeweils mit HTTP 200.');
  LError := nil;
  try
    try
      if FApi.GetUserInfo(LUserInfo, LError) then
      begin
        FUserName := SafeText(LUserInfo.Name);
        PersistTokens;
        if FUserName = '' then
          Log('Userinfo enthält keinen Namen. Scope profile in der DATEV-Konfiguration prüfen.', lkWarning);
      end
      else
        ShowApiError('Name konnte nicht über Userinfo gelesen werden', LError);
    except
      Log('Name konnte nicht gelesen oder gespeichert werden. Verbindung erneut prüfen.', lkWarning);
    end;
  finally
    LError.Free;
  end;
end;

function TMiniAppService.CheckConnection: Boolean;
begin
  RequireMainThread;
  Result := False;
  if FBusy or FConnecting or FStorageBlocked or FRevocationPending or FLoginUnconfirmed then
    Exit;
  SetBusy(True);
  try
    Result := CheckConnectionCore;
  finally
    SetBusy(False);
  end;
end;

function TMiniAppService.GetConnected: Boolean;
begin
  Result := FConnected and not FRevocationPending and not FLoginUnconfirmed and
    not FStorageBlocked and
    (FApi.RefreshToken <> '') and (FApi.RefreshTokenExpiresAt > Now);
end;

function TMiniAppService.GetHasTokens: Boolean;
begin
  Result := (FApi.AccessToken <> '') or (FApi.RefreshToken <> '');
end;

function TMiniAppService.GetCanChangeEnvironment: Boolean;
begin
  Result := not (FBusy or FConnecting or HasTokens or FRevocationPending or
    FLoginUnconfirmed or FStorageBlocked);
end;

function TMiniAppService.GetRefreshExpiresAt: TDateTime;
begin
  Result := FApi.RefreshTokenExpiresAt;
end;

function TMiniAppService.GetTraffiqxID: string;
begin
  Result := FApi.TRAFFIQXId;
end;

procedure TMiniAppService.SetEnvironment(AEnvironment: TMiniAppEnvironment);
begin
  RequireMainThread;
  if not CanChangeEnvironment then
    raise EInvalidOperation.Create('Vor dem Umgebungswechsel die Verbindung trennen.');
  FEnvironment := AEnvironment;
  if AEnvironment = meSandbox then
    FApi.Environment := teSandbox
  else
    FApi.Environment := teProduction;
  Changed;
end;

end.
