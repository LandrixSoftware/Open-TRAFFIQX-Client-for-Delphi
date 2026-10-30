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
  System.SysUtils, System.Threading, MiniApp.Model, MiniApp.Storage, intf.TRAFFIQXInvoiceAPI;

type
  TMiniAppLogKind = (lkInfo, lkWarning, lkError);
  TMiniAppLogEvent = reference to procedure(const AText: string; AKind: TMiniAppLogKind);
  TMiniAppChangedEvent = reference to procedure;
  TMiniAppInboxResultEvent = reference to procedure(const AText: string; AInvalidCount: Integer);
  TMiniAppConfirmLoginEvent = reference to function: Boolean;

  TMiniAppService = class;

  // Referenzgezähltes Ziel für Queue-Meldungen. Detach macht bereits eingereihte
  // Meldungen beim Freigeben wirkungslos; der Worker hält keine Form-Referenz.
  IMiniAppOutboxSink = interface
    procedure Entry(const AText: string; AKind: TMiniAppLogKind; const AHelpUrl: string);
    procedure Changed;
    procedure InboxResult(const AText: string; AInvalidCount: Integer);
    procedure Finished;
    procedure Detach;
  end;

  // Eine Service-Instanz, ausschließlich im Hauptthread. Callbacks dürfen weder warten
  // noch Nachrichten pumpen. Ausnahme: OnConfirmLoginUnconfirmed wird nur vor
  // einem neuen Login ohne laufendes Polling aufgerufen und darf modal fragen.
  // Versand/Status besitzen eine eigene API ohne Refresh-Token im Worker.
  TMiniAppService = class
  private
    FApi: TTRAFFIQXInvoiceAPI;
    FOperation: ITask;
    FOutboxSink: IMiniAppOutboxSink;
    FOnOutboxChanged: TMiniAppChangedEvent;
    FOnInboxResult: TMiniAppInboxResultEvent;
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
    function CreateWorkerApi: TTRAFFIQXInvoiceAPI;
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
    procedure StartOutbox(const AInvoiceNumber: string; ASend: Boolean;
      AAllowResend: Boolean = False);
    procedure StartInbox(AAll: Boolean; const AMetadataDocumentID: string = '');
    property OnInboxResult: TMiniAppInboxResultEvent read FOnInboxResult write FOnInboxResult;
    property OnOutboxChanged: TMiniAppChangedEvent read FOnOutboxChanged write FOnOutboxChanged;
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
  System.Classes, System.DateUtils, System.NetEncoding, System.IOUtils, System.JSON,
  intf.TRAFFIQXHttpLog;

type
  TMiniAppOutboxSink = class(TInterfacedObject, IMiniAppOutboxSink)
  private
    FOwner: TMiniAppService;
  public
    constructor Create(AOwner: TMiniAppService);
    procedure Entry(const AText: string; AKind: TMiniAppLogKind; const AHelpUrl: string);
    procedure Changed;
    procedure InboxResult(const AText: string; AInvalidCount: Integer);
    procedure Finished;
    procedure Detach;
  end;

constructor TMiniAppOutboxSink.Create(AOwner: TMiniAppService);
begin
  inherited Create;
  FOwner := AOwner;
end;

procedure TMiniAppOutboxSink.Detach;
begin
  FOwner := nil;
end;

procedure TMiniAppOutboxSink.Entry(const AText: string; AKind: TMiniAppLogKind;
  const AHelpUrl: string);
begin
  if FOwner = nil then Exit;
  FOwner.Log(AText, AKind);
  if AHelpUrl.StartsWith('https://', True) or AHelpUrl.StartsWith('http://', True) then
  begin
    FOwner.FHelpUrl := AHelpUrl;
    FOwner.Changed;
  end;
end;

procedure TMiniAppOutboxSink.Changed;
begin
  if (FOwner <> nil) and Assigned(FOwner.FOnOutboxChanged) then
    FOwner.FOnOutboxChanged();
end;

procedure TMiniAppOutboxSink.InboxResult(const AText: string; AInvalidCount: Integer);
begin
  if (FOwner <> nil) and Assigned(FOwner.FOnInboxResult) then
    FOwner.FOnInboxResult(FOwner.SafeText(AText), AInvalidCount);
end;

procedure TMiniAppOutboxSink.Finished;
begin
  if FOwner = nil then Exit;
  FOwner.SetBusy(False);
  Changed;
end;

// Eigener Aufrufrahmen je Meldung: keine veränderliche Schleifenvariable und
// kein kurzlebiges API-Ergebnisobjekt wird in eine Queue-Closure übernommen.
procedure QueueOutboxEntry(const ASink: IMiniAppOutboxSink; const AText: string;
  AKind: TMiniAppLogKind; const AHelpUrl: string = '');
begin
  TThread.Queue(nil,
    procedure
    begin
      ASink.Entry(AText, AKind, AHelpUrl);
    end);
end;

procedure QueueOutboxChanged(const ASink: IMiniAppOutboxSink);
begin
  TThread.Queue(nil,
    procedure
    begin
      ASink.Changed;
    end);
end;

function OutboxTimestamp: string;
begin
  Result := DateToISO8601(Now, False);
end;

function SafeOutboxText(AApi: TTRAFFIQXInvoiceAPI; const AText: string): string;
  procedure Hide(const ASecret: string);
  begin
    if ASecret = '' then Exit;
    Result := StringReplace(Result, ASecret, '[...]', [rfReplaceAll]);
    Result := StringReplace(Result, TNetEncoding.URL.Encode(ASecret), '[...]',
      [rfReplaceAll, rfIgnoreCase]);
  end;
begin
  Result := AText;
  Hide(AApi.AccessToken);
  Hide(AApi.ClientSecret);
  Hide(AApi.OAuth2BrokerApiKey);
  Result := TTRAFFIQXInvoiceAPI.RedactTokenLike(Result);
end;

procedure ApplyOutboxStatus(AApi: TTRAFFIQXInvoiceAPI; const ASink: IMiniAppOutboxSink;
  const AInvoiceNumber: string; var LState: TMiniAppOutboxState;
  AStatus: TTraffiqxInboxDocumentStatusInfo; AElapsedMs: Cardinal);
var
  LMessage: string;
  LKind: TMiniAppLogKind;
begin
  if AStatus = nil then
    raise EConvertError.Create('Statusantwort enthält keinen Status.');
  LState.CheckedAt := OutboxTimestamp;
  if OutboxStatusRank(AStatus.Status) >= OutboxStatusRank(LState.Status) then
    LState.Status := AStatus.Status;
  LMessage := Format('Status nach %.1f s: %s – %s', [AElapsedMs / 1000,
    AStatus.Status, TTraffiqxDocumentStatusHelper.DescribeStatus(AStatus.ParsedStatus)]);
  LKind := lkInfo;
  if AStatus.Status <> LState.Status then
    LMessage := LMessage + ' (gespeicherter Status ' + LState.Status + ' bleibt erhalten)';
  if AStatus.Status = 'userAction' then LKind := lkWarning;
  if (AStatus.Status = 'error') or (AStatus.Status = 'deleted') or
    (OutboxStatusRank(AStatus.Status) < 0) then LKind := lkError;
  if AStatus.ErrorCode <> '' then
  begin
    LMessage := LMessage + '; ' + AStatus.ErrorCode + ': ' +
      TTraffiqxDocumentStatusHelper.DescribeErrorCode(AStatus.ErrorCode);
    LKind := lkError;
  end;
  if AStatus.ErrorDetails <> '' then
    LMessage := LMessage + '; ' + TTraffiqxDocumentStatusHelper.DescribeErrorDetails(AStatus.ErrorDetails);
  if LKind <> lkInfo then
    LState.LastError := SafeOutboxText(AApi, LMessage)
  else if AStatus.Status = LState.Status then
    LState.LastError := '';
  QueueOutboxEntry(ASink, AInvoiceNumber + ': ' + SafeOutboxText(AApi, LMessage), LKind);
  SaveOutbox(AInvoiceNumber, LState);
  QueueOutboxChanged(ASink);
end;

procedure ExecuteOutbox(AApi: TTRAFFIQXInvoiceAPI; const AInvoiceNumber: string;
  ASend, AAllowResend: Boolean; const ASink: IMiniAppOutboxSink);
var
  LState, LPrevious: TMiniAppOutboxState;
  LInfo: TMiniAppInvoiceInfo;
  LXml, LPdf: TFileStream;
  LPrepared, LContent: TMemoryStream;
  LUploadXml: TStream;
  LUpload: TTraffiqxUploadResult;
  LError: TTraffiqxError;
  LStatus, LPending: TTraffiqxInboxDocumentStatusInfo;
  LMetadata: TTraffiqxOutboxMetadata;
  LParams: TTraffiqxDeliveryParamameter;
  LPreparation: TTraffiqxSandboxPreparation;
  LScenario, LText, LPath: string;
  LLoaded, LUploaded: Boolean;

  procedure Report(const AText: string; AKind: TMiniAppLogKind = lkInfo);
  begin
    QueueOutboxEntry(ASink, AInvoiceNumber + ': ' + SafeOutboxText(AApi, AText), AKind);
  end;

  procedure Store;
  begin
    SaveOutbox(AInvoiceNumber, LState);
    QueueOutboxChanged(ASink);
  end;

  procedure ApiFailure(const AContext: string; AError: TTraffiqxError);
  begin
    LState.LastError := SafeOutboxText(AApi, AContext + ': ' + TTraffiqxInboxErrorHelper.ErrorText(AError));
    QueueOutboxEntry(ASink, AInvoiceNumber + ': ' + LState.LastError, lkError,
      SafeOutboxText(AApi, TTraffiqxInboxErrorHelper.HelpUrl(AError)));
    Store;
  end;

  procedure RequireTokenTime(AMinSeconds: Integer);
  begin
    // Der Upload kann lange dauern. Im Worker niemals das Single-Use-Token erneuern.
    if AApi.AccessTokenExpiresAt <= IncSecond(Now, AMinSeconds) then
      raise EInvalidOperation.Create('Access-Token reicht für den nächsten Schritt nicht mehr. ' +
        'Später „Status abfragen“ wählen; nicht erneut senden.');
  end;

begin
  LLoaded := False;
  LXml := nil;
  LPdf := nil;
  LPrepared := nil;
  LContent := nil;
  LUpload := nil;
  LError := nil;
  LStatus := nil;
  LPending := nil;
  LMetadata := nil;
  try
    try
      LState := LoadOutbox(AInvoiceNumber);
      LLoaded := True;
      if ASend then
      begin
        if LState.UploadUnconfirmed then
        begin
          Report('Upload ist ungeklärt. Nicht erneut senden; Stand bei DATEV und HTTP-Protokoll prüfen.', lkError);
          Exit;
        end;
        if LState.DocumentID <> '' then
        begin
          if (LState.Status <> 'error') and (LState.Status <> 'deleted') then
          begin
            Report('Bereits übertragen: ' + LState.DocumentID + ' (' + LState.Status +
              '). Bitte „Status abfragen“ verwenden.', lkWarning);
            Exit;
          end;
          if not AAllowResend then
          begin
            Report('Erneuter Versand nach error/deleted braucht eine ausdrückliche Bestätigung.', lkWarning);
            Exit;
          end;
        end;
        LInfo := LoadInvoiceInfo(AInvoiceNumber);
        LPath := InvoiceDirectory(AInvoiceNumber);
        LXml := TFileStream.Create(TPath.Combine(LPath, 'rechnung.xml'), fmOpenRead or fmShareDenyWrite);
        LPdf := TFileStream.Create(TPath.Combine(LPath, 'belegbild.pdf'), fmOpenRead or fmShareDenyWrite);
        LUploadXml := LXml;
        if AApi.Environment = teSandbox then
        begin
          if LInfo.DeliveryChannel = 'peppol' then LScenario := 'SBSZ:210'
          else LScenario := 'SBSZ:110';
          LPrepared := TTRAFFIQXInvoiceAPI.PrepareSandboxXml(LXml, LScenario, LPreparation);
          if LPreparation.ProfileIdMissing then
            raise EConvertError.Create('Sandbox: cbc:ProfileID fehlt; kein Upload.');
          if LPrepared <> nil then LUploadXml := LPrepared;
          Report('Sandbox-Kopie mit ' + LScenario + '; rechnung.xml bleibt unverändert.');
        end;
        LUploadXml.Position := 0;
        if (LUploadXml.Size = 0) or (LPdf.Size = 0) then
          raise EReadError.Create('XML oder Belegbild ist leer; kein Upload.');
        RequireTokenTime(75);
        LPrevious := LState;
        LState := Default(TMiniAppOutboxState);
        LState.PreviousDocumentIDs := Copy(LPrevious.PreviousDocumentIDs);
        if LPrevious.DocumentID <> '' then
        begin
          SetLength(LState.PreviousDocumentIDs, Length(LState.PreviousDocumentIDs) + 1);
          LState.PreviousDocumentIDs[High(LState.PreviousDocumentIDs)] := LPrevious.DocumentID;
        end;
        LState.ChannelIntended := LInfo.DeliveryChannel;
        LState.UploadUnconfirmed := True;
        LState.LastError := 'Upload begonnen, Ergebnis noch ungeklärt. Nicht erneut senden.';
        Store; // Vor dem POST: ohne sichere Ablage geht nichts ins Netz.
        LParams := Default(TTraffiqxDeliveryParamameter);
        LParams.PreferredFormat := pfXRechnung;
        LUploaded := AApi.UploadStructuredData(LUploadXml, LPdf, 'rechnung.xml',
          'belegbild.pdf', LParams.ToJsonString, LUpload, LError);
        if not LUploaded then
        begin
          if (LError <> nil) and (LError.Status = 201) and (LError.Title = '#PARSE') then
          begin
            LState.UploadedAt := OutboxTimestamp;
            Report('HTTP 201: angenommen, aber keine lesbare document_id. NICHT ERNEUT SENDEN; bei DATEV klären.', lkError);
            ApiFailure('Upload angenommen; nicht erneut senden', LError);
          end
          else
          begin
            // Nur eine eindeutige Ablehnung erlaubt eine Wiederholung. 5xx/Transport
            // können einen serverseitig bereits angenommenen Upload verdecken.
            if (LError <> nil) and (((LError.Status >= 400) and (LError.Status < 500)) or
              (LError.Title = '#LOCAL')) then
              LState := LPrevious;
            ApiFailure('Upload fehlgeschlagen', LError);
            if LState.UploadUnconfirmed then
              Report('Annahme ungeklärt. Nicht erneut senden; zuerst bei DATEV prüfen.', lkError);
          end;
          Exit;
        end;
        LState.DocumentID := LUpload.DocumentId;
        LState.Status := 'inProcess';
        LState.UploadedAt := OutboxTimestamp;
        LState.UploadUnconfirmed := False;
        LState.LastError := '';
        try
          Store; // ID sofort sichern, bevor irgendeine Statusabfrage beginnt.
        except
          Report('UPLOAD ANGENOMMEN, ID NICHT SICHER GESPEICHERT: ' + LState.DocumentID +
            '. NICHT ERNEUT SENDEN! ID sichern und lokale Ablage reparieren.', lkError);
          raise;
        end;
        Report('Upload angenommen: document_id=' + LState.DocumentID);
      end;

      if LState.DocumentID = '' then
      begin
        Report('Keine document_id vorhanden. Bei ungeklärtem Upload zuerst den Stand bei DATEV klären.', lkWarning);
        Exit;
      end;
      if LState.ChannelIntended = '' then
      begin
        LInfo := LoadInvoiceInfo(AInvoiceNumber);
        LState.ChannelIntended := LInfo.DeliveryChannel;
        Store;
      end;
      if LState.Status <> 'sent' then
      begin
        // Nach einem langen Upload erneut volle Pollingzeit plus Antwortreserve verlangen.
        RequireTokenTime(120);
        if not AApi.WaitForOutboxDocumentSent(LState.DocumentID, LStatus, LError,
          8000, 8000, 60000,
          procedure(const AStatus: TTraffiqxInboxDocumentStatusInfo; AElapsedMs: Cardinal)
          begin
            ApplyOutboxStatus(AApi, ASink, AInvoiceNumber, LState, AStatus, AElapsedMs);
          end) then
        begin
          ApiFailure('Statusabfrage nicht abgeschlossen', LError);
          Exit;
        end;
      end;
      // Zwingende Schranke für beide nachfolgenden Endpunkte (auch bei Wiederaufnahme).
      if LState.Status <> 'sent' then Exit;
      if LState.MetadataAt = '' then
      begin
        RequireTokenTime(15);
        if not AApi.GetOutboxDocumentMetadata(LState.DocumentID, LMetadata, LError) then
        begin
          ApiFailure('Metadaten nicht abrufbar', LError);
          Exit;
        end;
        if (LMetadata = nil) or (LMetadata.DeliveryChannel = nil) then
          raise EConvertError.Create('Metadaten enthalten keinen Versandkanal.');
        if (LMetadata.DocumentFormat = '') or (LMetadata.SendDate = 0) or
          (LMetadata.DeliveryChannel.Name = '') or (LMetadata.DeliveryChannel.Address = '') then
          raise EConvertError.Create('Metadaten sind unvollständig; später erneut abfragen.');
        LState.DocumentFormat := LMetadata.DocumentFormat;
        if LMetadata.SendDate <> 0 then
          LState.SendDate := DateToISO8601(LMetadata.SendDate, False);
        LState.DeliveryChannel := LMetadata.DeliveryChannel.Name;
        LState.DeliveryAddress := LMetadata.DeliveryChannel.Address;
        LState.ChannelMatches := TraffiqxChannelMatches(LState.ChannelIntended, LState.DeliveryChannel);
        LState.MetadataAt := OutboxTimestamp;
        LState.LastError := '';
        Store;
      end;
      Report('Format: ' + LState.DocumentFormat + '; Versanddatum: ' + LState.SendDate +
        '; Kanal soll/ist: ' + LState.ChannelIntended + '/' + LState.DeliveryChannel +
        '; Versandadresse: ' + LState.DeliveryAddress);
      if not LState.ChannelMatches then
        Report('Versandkanal weicht ab: gewollt ' + LState.ChannelIntended +
          ', tatsächlich ' + LState.DeliveryChannel + '.', lkWarning);
      if LState.ArchivedAt = '' then
      begin
        RequireTokenTime(15);
        if not AApi.DownloadOutboxDocument(LState.DocumentID, LContent, LPending, LError) then
        begin
          if LPending <> nil then
          begin
            LState.LastError := 'Original noch nicht bereit (HTTP 202). Später „Status abfragen“ wählen.';
            Report(LState.LastError, lkWarning);
            Store; // Pending-Status darf das bereits bestätigte sent nicht zurückstufen.
          end
          else
            ApiFailure('Original nicht abrufbar', LError);
          Exit;
        end;
        ArchiveOutboxOriginal(AInvoiceNumber, LContent);
        LState.ArchivedAt := OutboxTimestamp;
        LState.LastError := '';
        Store;
        Report('Original vollständig abgelegt: ' + TPath.Combine(InvoiceDirectory(AInvoiceNumber), 'original'));
      end;
    except
      on E: Exception do
      begin
        LText := SafeOutboxText(AApi, E.Message);
        Report('Vorgang abgebrochen: ' + LText, lkError);
        if LLoaded then
        begin
          LState.LastError := LText;
          if LState.UploadUnconfirmed then
          begin
            LState.LastError := LState.LastError + ' Upload ungeklärt: NICHT ERNEUT SENDEN.';
            Report(LState.LastError, lkError);
          end;
          try
            Store;
          except
            Report('outbox.json konnte nicht gespeichert werden. document_id=' + LState.DocumentID +
              '. NICHT ERNEUT SENDEN; Ablage und Stand bei DATEV prüfen.', lkError);
          end;
        end;
      end;
    end;
  finally
    LMetadata.Free;
    LPending.Free;
    LStatus.Free;
    LError.Free;
    LUpload.Free;
    LContent.Free;
    LPrepared.Free;
    LPdf.Free;
    LXml.Free;
  end;
end;

procedure TMiniAppService.StartOutbox(const AInvoiceNumber: string; ASend: Boolean;
  AAllowResend: Boolean);
var
  LApi: TTRAFFIQXInvoiceAPI;
  LSink: IMiniAppOutboxSink;
begin
  RequireMainThread;
  if FBusy or FConnecting then Exit;
  if not Connected then
  begin
    Log('Nicht verbunden – zuerst die DATEV-Verbindung herstellen und prüfen.', lkWarning);
    Exit;
  end;
  if not EnsureAccessToken(120) then Exit;
  SetBusy(True);
  LApi := nil;
  try
    LApi := CreateWorkerApi;
    LSink := FOutboxSink;
    FOperation := TTask.Run(
      procedure
      begin
        try
          try
            ExecuteOutbox(LApi, AInvoiceNumber, ASend, AAllowResend, LSink);
          finally
            LApi.Free;
          end;
        finally
          TThread.Queue(nil,
            procedure
            begin
              LSink.Finished;
            end);
        end;
      end);
  except
    LApi.Free;
    SetBusy(False);
    raise;
  end;
end;


function TMiniAppService.CreateWorkerApi: TTRAFFIQXInvoiceAPI;
var
  LApi: TTRAFFIQXInvoiceAPI;
begin
  LApi := nil;
  try
    LApi := TTRAFFIQXInvoiceAPI.Create;
    LApi.ProviderType := FApi.ProviderType;
    LApi.Environment := FApi.Environment;
    LApi.ClientId := FConfig.ClientID;
    LApi.ClientSecret := FConfig.ClientSecret;
    LApi.TRAFFIQXId := FConfig.TraffiqxID;
    LApi.Scope := FConfig.Scope;
    LApi.AppDisplayName := FConfig.AppDisplayName;
    LApi.OAuth2BrokerCallbackUri := FConfig.OAuth2BrokerCallbackUri;
    LApi.OAuth2BrokerApiKey := FConfig.OAuth2BrokerApiKey;
    LApi.AccessToken := FApi.AccessToken;
    LApi.AccessTokenExpiresAt := FApi.AccessTokenExpiresAt;
    TTraffiqxHttpLog.Attach(LApi);
    Result := LApi;
  except
    LApi.Free;
    raise;
  end;
end;

procedure QueueInboxResult(const ASink: IMiniAppOutboxSink; const AText: string;
  AInvalidCount: Integer);
begin
  TThread.Queue(nil,
    procedure
    begin
      ASink.InboxResult(AText, AInvalidCount);
    end);
end;

procedure RequireInboxToken(AApi: TTRAFFIQXInvoiceAPI);
begin
  if AApi.AccessTokenExpiresAt <= IncSecond(Now, 15) then
    raise EInvalidOperation.Create('Access-Token reicht nicht mehr. Posteingang erneut abrufen; ' +
      'offene IDs bleiben vorgemerkt. Fehlende Metadaten separat nachholen.');
end;

procedure ExecuteInbox(AApi: TTRAFFIQXInvoiceAPI; AAll: Boolean;
  const AMetadataDocumentID: string; const ASink: IMiniAppOutboxSink);
var
  LDocuments: TTraffiqxInboxDocumentList;
  LDocument: TTraffiqxInboxDocument;
  LError: TTraffiqxError;
  LSeen: TStringList;
  LID, LSummary: string;
  LCount, LFailures, LInvalid: Integer;

  procedure Report(const AText: string; AKind: TMiniAppLogKind);
  begin
    QueueOutboxEntry(ASink, SafeOutboxText(AApi, AText), AKind);
  end;

  procedure ApiFailure(const AContext: string; AError: TTraffiqxError; AKind: TMiniAppLogKind);
  begin
    Inc(LFailures);
    QueueOutboxEntry(ASink, SafeOutboxText(AApi,
      AContext + ': ' + TTraffiqxInboxErrorHelper.ErrorText(AError)), AKind,
      SafeOutboxText(AApi, TTraffiqxInboxErrorHelper.HelpUrl(AError)));
  end;

  procedure FetchMetadata(const AID: string);
  var
    LMetadata: TTraffiqxInboxDocumentMetadata;
    LMetadataError: TTraffiqxError;
    LJson: TJSONObject;
  begin
    LMetadata := nil;
    LMetadataError := nil;
    try
      try
        RequireInboxToken(AApi);
        if not AApi.GetInboxDocumentMetadata(AID, LMetadata, LMetadataError) then
        begin
          ApiFailure(AID + ': Metadaten fehlen; mit „Metadaten nachholen“ erneut versuchen',
            LMetadataError, lkWarning);
          Exit;
        end;
        if (LMetadata = nil) or (LMetadata.DocumentFormat = '') then
          raise EConvertError.Create('Metadaten enthalten kein Dokumentformat.');
        // Auch bei anschließendem Schreibfehler muss der Kunde vom Befund erfahren.
        if not LMetadata.EN16931Compliant then Inc(LInvalid);
        LJson := LMetadata.ToJson;
        try
          SaveInboxMetadata(AID, LJson.ToJSON);
        finally
          LJson.Free;
        end;
      except
        on E: Exception do
        begin
          Inc(LFailures);
          Report(AID + ': Metadaten nicht gespeichert; Dokument bleibt abgelegt. ' +
            '„Metadaten nachholen“ verwenden. ' + E.Message, lkWarning);
        end;
      end;
    finally
      LMetadata.Free;
      LMetadataError.Free;
    end;
  end;

  procedure ProcessDocument(const AID: string; AMetadataOnly: Boolean);
  var
    LContent: TMemoryStream;
    LDownloadError: TTraffiqxError;
    LInfo: TMiniAppInboxInfo;
    LNeedMetadata: Boolean;
  begin
    LContent := nil;
    LDownloadError := nil;
    try
      try
        if not InboxDocumentStored(AID) then
        begin
          if AMetadataOnly then
            raise EReadError.Create('Dokument ist noch nicht vollständig abgelegt.');
          // Ohne persistierte ID niemals herunterladen: DATEV setzt downloaded sofort.
          MarkInboxPending(AID, True);
          RequireInboxToken(AApi);
          if not AApi.DownloadInboxDocument(AID, LContent, LDownloadError) then
          begin
            if (LDownloadError <> nil) and (LDownloadError.Status = 404) then
            begin
              MarkInboxPending(AID, False);
              ApiFailure(AID + ': bei DATEV nicht mehr vorhanden; aus Offen-Liste entfernt',
                LDownloadError, lkWarning);
            end
            else
              ApiFailure(AID + ': Download fehlgeschlagen; bleibt vorgemerkt', LDownloadError, lkError);
            Exit;
          end;
          ArchiveInboxDocument(AID, LContent);
        end;
        Inc(LCount);
        LNeedMetadata := AMetadataOnly;
        if not LNeedMetadata then
        begin
          try
            LInfo := LoadInboxInfo(AID);
            LNeedMetadata := not LInfo.HasMetadata;
            if LInfo.HasMetadata and not LInfo.EN16931Compliant then Inc(LInvalid);
          except
            // Beschädigte Metadaten lassen sich ohne erneuten Download ersetzen.
            LNeedMetadata := True;
          end;
        end;
        if LNeedMetadata then FetchMetadata(AID);
        // Metadatenfehler hindern die vollständige Dokumentablage nicht.
        MarkInboxPending(AID, False);
        Report(AID + ': vollständig im Eingang abgelegt.', lkInfo);
      except
        on E: Exception do
        begin
          Inc(LFailures);
          Report(AID + ': ' + E.Message + ' Vorhandene Vormerkung bleibt erhalten.', lkError);
        end;
      end;
    finally
      LDownloadError.Free;
      LContent.Free;
    end;
  end;

begin
  LCount := 0;
  LFailures := 0;
  LInvalid := 0;
  LDocuments := nil;
  LError := nil;
  LSeen := TStringList.Create;
  try
    try
      // Vor jeder Inbox-API und jeder Änderung der Offen-Liste prüfen.
      // Trennen oder Neustart mit anderer .env darf keine fremde ID austragen.
      if AApi.Environment = teSandbox then
        EnsureInboxContext(meSandbox, AApi.TRAFFIQXId)
      else
        EnsureInboxContext(meProduction, AApi.TRAFFIQXId);
      LSeen.CaseSensitive := True;
      if AMetadataDocumentID <> '' then
        ProcessDocument(AMetadataDocumentID, True)
      else
      begin
        // Erst den lokalen Wiederanlauf abschließen, danach neue IDs anfragen.
        for LID in LoadPendingInbox do
        begin
          RequireInboxToken(AApi);
          if LSeen.IndexOf(LID) >= 0 then Continue;
          LSeen.Add(LID);
          ProcessDocument(LID, False);
        end;
        RequireInboxToken(AApi);
        if not AApi.GetInboxDocumentIds(LDocuments, LError, not AAll, False) then
          ApiFailure('Posteingangsliste konnte nicht abgerufen werden', LError, lkError)
        else
          for LDocument in LDocuments do
          begin
            RequireInboxToken(AApi);
            if LSeen.IndexOf(LDocument.DocumentId) >= 0 then Continue;
            LSeen.Add(LDocument.DocumentId);
            ProcessDocument(LDocument.DocumentId, False);
          end;
      end;
    except
      on E: Exception do
      begin
        Inc(LFailures);
        Report('Posteingang abgebrochen: ' + E.Message, lkError);
      end;
    end;
  finally
    LSummary := Format('Posteingang: %d Dokumente lokal vorhanden; %d Warnungen/Fehler. ',
      [LCount, LFailures]);
    if LInvalid > 0 then
      LSummary := LSummary + Format('%d ungültige E-Rechnungen (EN-16931: nein)! Bitte prüfen.', [LInvalid])
    else
      LSummary := LSummary + 'Keine ungültigen E-Rechnungen festgestellt; fehlende Metadaten bleiben ungeprüft.';
    if (LInvalid > 0) or (LFailures > 0) then Report(LSummary, lkWarning)
    else Report(LSummary, lkInfo);
    QueueInboxResult(ASink, LSummary, LInvalid);
    LSeen.Free;
    LError.Free;
    LDocuments.Free;
  end;
end;

procedure TMiniAppService.StartInbox(AAll: Boolean; const AMetadataDocumentID: string);
var
  LApi: TTRAFFIQXInvoiceAPI;
  LSink: IMiniAppOutboxSink;
begin
  RequireMainThread;
  if FBusy or FConnecting then Exit;
  if not Connected then
  begin
    Log('Nicht verbunden – zuerst die DATEV-Verbindung herstellen und prüfen.', lkWarning);
    Exit;
  end;
  if not EnsureAccessToken(120) then Exit;
  SetBusy(True);
  LApi := nil;
  try
    LApi := CreateWorkerApi;
    LSink := FOutboxSink;
    FOperation := TTask.Run(
      procedure
      begin
        try
          try
            ExecuteInbox(LApi, AAll, AMetadataDocumentID, LSink);
          finally
            LApi.Free;
          end;
        finally
          TThread.Queue(nil,
            procedure
            begin
              LSink.Finished;
            end);
        end;
      end);
  except
    LApi.Free;
    SetBusy(False);
    raise;
  end;
end;

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
  FOutboxSink := TMiniAppOutboxSink.Create(Self);
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
  // Auch direktes Free außerhalb von FormCloseQuery ist sicher. Erst Queue-Ziel
  // lösen, dann Worker abwarten; er nutzt weder Synchronize noch die Haupt-API.
  if FOutboxSink <> nil then FOutboxSink.Detach;
  if FOperation <> nil then FOperation.Wait;
  FOperation := nil;
  FOutboxSink := nil;
  FOnOutboxChanged := nil;
  FOnInboxResult := nil;
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
