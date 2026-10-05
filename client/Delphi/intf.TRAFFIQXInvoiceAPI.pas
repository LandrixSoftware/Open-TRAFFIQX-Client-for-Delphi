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

unit intf.TRAFFIQXInvoiceAPI;

interface

uses
  System.SysUtils,System.Classes,System.Types,System.Contnrs,System.StrUtils
  ,System.NetEncoding, System.SyncObjs, System.Math, Winapi.ShellAPI, Winapi.Windows
  ,System.JSON, System.Net.HttpClient, System.Net.URLClient,System.TypInfo
  ,System.Net.HttpClientComponent,System.IOUtils, System.Zip, System.Threading
  ,System.Generics.Collections,System.DateUtils,System.Net.Mime
  ,System.RegularExpressions
  ;

type
  TTraffiqxProviderType = (
    tpNotSet,
    tpB4Value,
    tpBundesdruckerei,
    tpBeCloud,
    tpDatev,
    tpExelaAsterion,
    tpQuadient,
    tpSGHService,
    tpRicoh,
    tpDatevSmartTransfer
  );

  TTraffiqxEnvironment = (teProduction, teSandbox);

  TTraffiqxProviderEndpoints = record
    WellKnownUri: String;
    OAuthUri: string;
    TokenUri: string;
    ApiBaseUri: string;
  end;

  TTraffiqxProviderConfig = record
    Production: TTraffiqxProviderEndpoints;
    Sandbox: TTraffiqxProviderEndpoints;
  end;

  TTraffiqxPollStatus = (psPending, psSuccess, psError, psCancelled, psTimeout);

  TTraffiqxDocumentStatus = (
    dsUnknown,
    dsInProcess,
    dsSent,
    dsError,
    dsDeleted,
    dsUserAction
  );

  TTraffiqxPollResult = record
    Status: TTraffiqxPollStatus;
    AccessToken: string;
    RefreshToken: string;
    AccessTokenExpiresAt : TDateTime;
    RefreshTokenExpiresAt : TDateTime;
    // Dieselben Zeitpunkte in UTC (0 = unbekannt), direkt aus den Angaben des
    // Brokers - ohne Umweg ueber die in der Herbststunde mehrdeutige Ortszeit.
    AccessTokenExpiresAtUtc : TDateTime;
    RefreshTokenExpiresAtUtc : TDateTime;
    ErrorCode: string;
    ErrorDescription: string;
    class function Pending: TTraffiqxPollResult; static;
    class function Success(const AAccessToken, ARefreshToken: string; AAccessTokenExpiresAt, ARefreshTokenExpiresAt : TDateTime): TTraffiqxPollResult; static;
    class function Fail(const ACode, ADescription: string): TTraffiqxPollResult; static;
    class function Cancelled: TTraffiqxPollResult; static;
    class function Timeout: TTraffiqxPollResult; static;
    function IsSuccess: Boolean;
  end;

  TTraffiqxPreferedFormat = (pfNone, pfXRechnung, pfZUGFeRD);

  // Optionale Auslieferungsparameter fuer den Upload. DATEV 1.0 unterstuetzt
  // hier nur noch preferred_format, daher wird kein E-Mail-Fallback mehr modelliert.
  TTraffiqxDeliveryParamameter = record
    PreferredFormat : TTraffiqxPreferedFormat; //Sollte gleich dem hochgeladenen Format sein.
    function ToJsonString : String;
  end;

  TTraffiqxError = class
  public
    Title: string;
    Status: Integer;
    Detail: string;
    // ProblemDetails "type" (RFC 7807): URI mit Hilfe zum Fehlertyp; leer
    // bzw. "about:blank", wenn die API keine Hilfe-URL mitliefert.
    TypeUri: string;
    constructor Create(const ATitle: string; const AStatus: Integer;
      const ADetail: string);
    class function FromJson(const AJson: TJSONObject): TTraffiqxError; static;
    function ToJson: TJSONObject;
  end;

  // Angaben des Userinfo-Endpunkts zur Person, die das Token ausgestellt hat.
  // Name/GivenName/FamilyName nur mit Scope "profile", Email nur mit "email".
  TTraffiqxUserInfo = record
    Sub: string;
    Name: string;
    GivenName: string;
    FamilyName: string;
    Email: string;
  end;

  // Ergebnis des Introspection-Endpunkts (RFC 7662).
  TTraffiqxTokenIntrospection = record
    Active: Boolean;
    ExpiresAt: TDateTime; // lokale Zeit, 0 = unbekannt
    ExpiresAtUtc: TDateTime; // derselbe Zeitpunkt in UTC, 0 = unbekannt
    Scope: string;
  end;

  TTraffiqxInboxErrorHelper = record
  public
    class function ExtractErrorCode(const AText: string): string; static;
    class function ErrorCode(const AError: TTraffiqxError): string; static;
    class function HelpUrlForErrorCode(const AErrorCode: string): string; static;
    class function DescribeHttpStatus(const AStatus: Integer): string; static;
    class function DescribeErrorCode(const AErrorCode: string): string; static;
    class function BuildUserMessage(const AError: TTraffiqxError): string; static;
    // Hilfe-URL zum Fehler: bekannte TIA-Fehlercodes, sonst "type" der Antwort.
    class function HelpUrl(const AError: TTraffiqxError): string; static;
    // Einzeiliger Fehlertext fuer Protokolle: Detail, Beschreibung und Hilfe-URL.
    class function ErrorText(const AError: TTraffiqxError): string; static;
  end;

  TTraffiqxInboxDocument = class
  public
    DocumentId: string;
    Downloaded: Boolean;
    Href: string;
    constructor Create(const ADocumentId: string; const ADownloaded: Boolean;
      const AHref: string);
    class function FromJson(const AJson: TJSONObject): TTraffiqxInboxDocument; static;
  end;

  TTraffiqxInboxDocumentMetadata = class
  public
    InvoiceDate: TDate;
    InvoiceNumber: string;
    GrossTotal: Double;
    CurrencyCode: string;
    SellerName: string;
    BuyerName: string;
    InvoiceType: string;
    DocumentFormat: string;
    DateOfReceipt: TDateTime;
    EN16931Compliant: Boolean;
    Downloaded: Boolean;
    constructor Create(const AInvoiceDate: TDate; const AInvoiceNumber: string;
      const AGrossTotal: Double; const ACurrencyCode, ASellerName, ABuyerName, AInvoiceType,
      ADocumentFormat: string; const ADateOfReceipt: TDateTime;
      const AEN16931Compliant, ADownloaded: Boolean);
    class function FromJson(const AJson: TJSONObject): TTraffiqxInboxDocumentMetadata; static;
    function ToJson: TJSONObject;
  end;

  TTraffiqxDeliveryChannel = class
  public
    Name: string;
    Address: string;
    class function FromJson(const AJson: TJSONObject): TTraffiqxDeliveryChannel; static;
  end;

  TTraffiqxDocumentStatusHelper = record
  public
    class function FromRawStatus(const ARawStatus: string): TTraffiqxDocumentStatus; static;
    class function ToDisplayString(const AStatus: TTraffiqxDocumentStatus): string; static;
    class function DescribeStatus(const AStatus: TTraffiqxDocumentStatus): string; static;
    class function DescribeErrorCode(const AErrorCode: string): string; static;
    class function DescribeErrorDetails(const AErrorDetails: string): string; static;
  end;

  TTraffiqxInboxDocumentStatusInfo = class
  public
    Status: string;
    ErrorCode: string;
    ErrorDetails: string;
    Downloaded: Boolean;
    class function FromJson(const AJson: TJSONObject): TTraffiqxInboxDocumentStatusInfo; static;
    function ParsedStatus: TTraffiqxDocumentStatus;
    function IsSuccessful: Boolean;
    function IsTerminal: Boolean;
    function HasProcessingError: Boolean;
  end;

  TTraffiqxUploadResult = class
  public
    DocumentId: string;
    Href: string;
    class function FromJson(const AJson: TJSONObject): TTraffiqxUploadResult; static;
  end;

  TTraffiqxOutboxDocument = class
  public
    DocumentId: string;
    Status: string;
    Downloaded: Boolean;
    Href: string;
    class function FromJson(const AJson: TJSONObject): TTraffiqxOutboxDocument; static;
    function ParsedStatus: TTraffiqxDocumentStatus;
  end;

  TTraffiqxOutboxMetadata = class
  public
    InvoiceDate: TDate;
    InvoiceNumber: string;
    GrossTotal: Double;
    CurrencyCode: string;
    SellerName: string;
    BuyerName: string;
    InvoiceType: string;
    DocumentFormat: string;
    SendDate: TDateTime;
    DeliveryChannel: TTraffiqxDeliveryChannel;
    StatusInfo: TTraffiqxInboxDocumentStatusInfo;
    constructor Create; overload;
    destructor Destroy; override;
    class function FromJson(const AJson: TJSONObject): TTraffiqxOutboxMetadata; static;
  end;

  TTraffiqxInboxDocumentList = TObjectList<TTraffiqxInboxDocument>;
  TTraffiqxOutboxDocumentList = TObjectList<TTraffiqxOutboxDocument>;

  TTraffiqxHelper = class
  public
    class function ExtractFirstFileFromZip(const AZipStream: TStream;
      out AContent: TMemoryStream; out AError: TTraffiqxError): Boolean; static;
  end;

const
  TRAFFIQX_PROVIDER_CONFIG: array[TTraffiqxProviderType] of TTraffiqxProviderConfig = (
    //not set
    (
      Production: (WellKnownUri: ''; OAuthUri: ''; TokenUri: ''; ApiBaseUri: '');
      Sandbox:    (WellKnownUri: ''; OAuthUri: ''; TokenUri: ''; ApiBaseUri: '')
    ),
    // b4value.net GmbH
    (
      Production: (
        WellKnownUri: 'https://login.b4value.net/realms/prod/.well-known/openid-configuration';
        OAuthUri: 'https://login.b4value.net/realms/prod/protocol/openid-connect/auth';
        TokenUri: 'https://login.b4value.net/realms/prod/protocol/openid-connect/token';
        ApiBaseUri: 'https://portal.b4value.net/tia/v1'
      );
      Sandbox:    (
        WellKnownUri: 'https://login.qs.b4value.net/realms/qs/.well-known/openid-configuration';
        OAuthUri: 'https://login.qs.b4value.net/realms/qs/protocol/openid-connect/auth';
        TokenUri: 'https://login.qs.b4value.net/realms/qs/protocol/openid-connect/token';
        ApiBaseUri: 'https://portal.qs.b4value.net/tia/v0.9' //dev qs
      )
    ),
    // Bundesdruckerei GmbH
    (
      Production: (
        WellKnownUri: 'https://login.bdr-businessportal.de/realms/prod/.well-known/openid-configuration';
        OAuthUri: 'https://login.bdr-businessportal.de/realms/prod/protocol/openid-connect/auth';
        TokenUri: 'https://login.bdr-businessportal.de/realms/prod/protocol/openid-connect/token';
        ApiBaseUri: 'https://www.bdr-businessportal.de/tia/v1'
      );
      Sandbox:    (WellKnownUri: ''; OAuthUri: ''; TokenUri: ''; ApiBaseUri: '')
    ),
    // BeCloud srl (noch ohne Endpunkte)
    (
      Production: (WellKnownUri: ''; OAuthUri: ''; TokenUri: ''; ApiBaseUri: '');
      Sandbox:    (WellKnownUri: ''; OAuthUri: ''; TokenUri: ''; ApiBaseUri: '')
    ),
    // DATEV eG
    (
      Production: (
        WellKnownUri: 'https://signin.datev.de/datevam/oauth2/realms/root/realms/user/.well-known/openid-configuration';
        OAuthUri: 'https://signin.datev.de/datevam/oauth2/realms/root/realms/user/authorize';
        TokenUri: 'https://signin.datev.de/datevam/oauth2/realms/root/realms/user/access_token';
        ApiBaseUri: 'https://traffiqx-invoice.api.datev.de/platform/v1'
      );
      Sandbox: (
        WellKnownUri: 'https://signin.datev.de/datevam/oauth2/realms/root/realms/user/.well-known/openid-configuration';
        OAuthUri: 'https://signin.datev.de/datevam/oauth2/realms/root/realms/user/authorize';
        TokenUri: 'https://signin.datev.de/datevam/oauth2/realms/root/realms/user/access_token';
        ApiBaseUri: 'https://traffiqx-invoice.api.datev.de/platform-sandbox/v1'
      )
    ),
    // Exela Asterion GmbH (noch ohne Endpunkte)
    (
      Production: (WellKnownUri: ''; OAuthUri: ''; TokenUri: ''; ApiBaseUri: '');
      Sandbox:    (WellKnownUri: ''; OAuthUri: ''; TokenUri: ''; ApiBaseUri: '')
    ),
    // Quadient CXM Germany GmbH
    (
      Production: (
        WellKnownUri: 'https://login.quadient-eservices.com/realms/prod/.well-known/openid-configuration';
        OAuthUri: 'https://login.quadient-eservices.com/realms/prod/protocol/openid-connect/auth';
        TokenUri: 'https://login.quadient-eservices.com/realms/prod/protocol/openid-connect/token';
        ApiBaseUri: 'https://www.quadient-eservices.com/tia/v1'
      );
      Sandbox:    (WellKnownUri: ''; OAuthUri: ''; TokenUri: ''; ApiBaseUri: '')
    ),
    // SGH Service GmbH
    (
      Production: (
        WellKnownUri: 'https://login.ivi.sgh-net.de/realms/prod/.well-known/openid-configuration';
        OAuthUri: 'https://login.ivi.sgh-net.de/realms/prod/protocol/openid-connect/auth';
        TokenUri: 'https://login.ivi.sgh-net.de/realms/prod/protocol/openid-connect/token';
        ApiBaseUri: 'https://ivi.sgh-net.de/tia/v1'
      );
      Sandbox:    (WellKnownUri: ''; OAuthUri: ''; TokenUri: ''; ApiBaseUri: '')
    ),
    // RICOH Deutschland GmbH
    (
      Production: (
        WellKnownUri: 'https://login.ricoh-idx.net/realms/prod/.well-known/openid-configuration';
        OAuthUri: 'https://login.ricoh-idx.net/realms/prod/protocol/openid-connect/auth';
        TokenUri: 'https://login.ricoh-idx.net/realms/prod/protocol/openid-connect/token';
        ApiBaseUri: 'https://www.ricoh-idx.net/tia/v1'
      );
      Sandbox:    (WellKnownUri: ''; OAuthUri: ''; TokenUri: ''; ApiBaseUri: '')
    ),
    // DATEV SmartTransfer
    (
      Production: (
        WellKnownUri: 'https://login.smarttransfer.datev.de/realms/prod/.well-known/openid-configuration';
        OAuthUri: 'https://login.smarttransfer.datev.de/realms/prod/protocol/openid-connect/auth';
        TokenUri: 'https://login.smarttransfer.datev.de/realms/prod/protocol/openid-connect/token';
        ApiBaseUri: 'https://smarttransfer.datev.de/tia/v1'
      );
      Sandbox:    (WellKnownUri: ''; OAuthUri: ''; TokenUri: ''; ApiBaseUri: '')
    )
  );

// Bereinigt eine TRAFFIQX-ID fuer die API: Leerraum entfernen und das in
// Portalen angezeigte Praefix "TX:" abschneiden. Die API erwartet nur die
// Ziffernfolge (13 bis 15 Zeichen, z.B. 0042000711688).
function TraffiqxNormalizeId(const AValue: string): string;

type
  TTRAFFIQXInvoiceAPI = class;

  TTraffiqxPollCompletedEvent = reference to procedure(const AResult: TTraffiqxPollResult; _Sender : TTRAFFIQXInvoiceAPI);

  // Optionaler Hook: ist er gesetzt, oeffnet StartAuth die Autorisierungs-URL
  // nicht im externen Browser (ShellExecute), sondern uebergibt sie an diesen
  // Callback (z.B. fuer ein eingebettetes WebView2-Fenster).
  TTraffiqxOpenAuthUrlEvent = reference to procedure(const AUrl: string);

  // Technisches HTTP-Protokoll (DATEV-Abnahme). OnHttpTrace kommt je Anfrage
  // zweimal mit derselben RequestId: vor dem Senden (htkRequest) und nach der
  // Antwort oder dem Transportfehler (htkResponse). Folgt der Client einer
  // Weiterleitung, kommen Zwischenantwort und Folgeanfrage mit RequestId ".1"
  // usw. Die Header Authorization, X-Api-Key und Cookies fehlen, geheime
  // Parameter in URL und Headern maskiert RedactUrl. Anfrage-Bodies werden nie
  // uebergeben, Antwort-Bodies nur bei Fehlern und Statusabfragen und dann
  // durch RedactSecrets maskiert. Texte und Header, die ein Token an seiner
  // Form erkennen lassen ("Bearer ...", "Basic ...", JWT), werden verworfen.
  // Achtung: Das Polling der Anmeldung laeuft in einem Hintergrund-Thread und
  // ruft OnHttpTrace von dort auf; der Empfaenger muss threadsicher sein.
  // OnHttpTrace vor dem ersten Aufruf setzen und danach nicht mehr aendern.
  TTraffiqxHttpTraceKind = (htkRequest, htkResponse);

  TTraffiqxHttpTrace = record
    Kind: TTraffiqxHttpTraceKind;
    RequestId: string;
    TimestampUtc: TDateTime;
    Method: string;
    Url: string;
    Headers: TNetHeaders;   // Anfrage- bzw. Antwort-Header
    StatusCode: Integer;    // 0 = keine Antwort (Transportfehler)
    StatusText: string;
    Body: string;           // nur Antwort
    ErrorMessage: string;   // Transportfehler
    DurationMs: Int64;      // nur Antwort
  end;

  TTraffiqxHttpTraceEvent = reference to procedure(const AEntry: TTraffiqxHttpTrace);

  // Wann der Antwort-Body ins Protokoll geht: bei HTTP-Fehlern (>= 400),
  // zusaetzlich bei 202 (Download noch nicht bereit, Body = Status) oder immer
  // (Statusabfrage).
  TTraffiqxTraceBody = (tbOnError, tbOnErrorOrPending, tbAlways);

  TTRAFFIQXInvoiceAPI = class(TObject)
  private
    FAccessToken: string;
    FAccessTokenExpiresAt: TDateTime;
    FRefreshToken: string;
    FRefreshTokenExpiresAt: TDateTime;
    FClientId: String;
    FClientSecret: String;
    FOAuth2BrokerCallbackUri: String;
    FOAuth2BrokerApiKey: String;
    FProviderType: TTraffiqxProviderType;
    FEnvironment: TTraffiqxEnvironment;
    FTRAFFIQXId: String;
    FAppDisplayName: String;
    FScope: String;
    FAccessTokenUri: String;
    FOAuthUri: String;
    FApiBaseUri: String;
    FCurrentSessionId: String;
    FPollFuture: IFuture<TTraffiqxPollResult>;
    FPollCancelFlag: Integer;
    FOnPollingCompleted: TTraffiqxPollCompletedEvent;
    FOnOpenAuthUrl: TTraffiqxOpenAuthUrlEvent;
    FOnHttpTrace: TTraffiqxHttpTraceEvent;
    FWellKnownUri: String;
    FRevocationUri: String;
    FUserInfoUri: String;
    FIntrospectionUri: String;
    FLastRawContentReceived: String;
    function MakeError(const ATitle: string; const AStatus: Integer;
      const ADetail: string): TTraffiqxError;
    function ScopeContainsOfflineAccess: Boolean;
    procedure ApplyProviderConfig;
    procedure SetProviderType(const Value: TTraffiqxProviderType);
    procedure SetEnvironment(const Value: TTraffiqxEnvironment);
    procedure SetTRAFFIQXId(const Value: String);
    function BuildBrokerEndpoint(const AEndpoint: string): string;
    function BuildOutboxBase: string;
    function BuildInboxBase: string;
    procedure ApplyAuthHeaders(AClient: TNetHTTPClient);
    // Alle HTTP-Aufrufe laufen hierueber, damit OnHttpTrace jede Anfrage sieht.
    // Transportfehler werden nach dem Protokollieren unveraendert weitergeworfen.
    function TraceExecute(AClient: TNetHTTPClient; const AMethod, AUrl: string;
      const AHeaders: TNetHeaders; ABody: TTraffiqxTraceBody;
      const ASend: TFunc<IHTTPResponse>): IHTTPResponse;
    procedure FireHttpTrace(const ATrace: TTraffiqxHttpTraceEvent; const AEntry: TTraffiqxHttpTrace);
    procedure FillTraceResponse(var AEntry: TTraffiqxHttpTrace; const AResponse: IHTTPResponse;
      ABody: TTraffiqxTraceBody);
    function HttpGet(AClient: TNetHTTPClient; const AUrl: string; AContent: TStream;
      const AHeaders: TNetHeaders; ABody: TTraffiqxTraceBody): IHTTPResponse;
    function HttpPost(AClient: TNetHTTPClient; const AUrl: string; ASource: TStream;
      const AHeaders: TNetHeaders; ABody: TTraffiqxTraceBody): IHTTPResponse;
    function HttpPostForm(AClient: TNetHTTPClient; const AUrl: string;
      AForm: TMultipartFormData; ABody: TTraffiqxTraceBody): IHTTPResponse;
  public
    // Maskiert Tokens und Secrets in einem Antwort-Body: JSON wird geparst und
    // die Werte geheimer Schluessel (jeden Typs) durch "***" ersetzt; sonst
    // werden Formular-Parameter maskiert, und bleibt ein verdaechtiger
    // Schluessel uebrig, wird der Body gar nicht uebernommen.
    class function RedactSecrets(const AText: string): string; static;
    // Maskiert geheime Parameter in URLs und Header-Werten (Token, code,
    // sessionId, state ...): name=*** .
    class function RedactUrl(const AText: string): string; static;
  public
    constructor Create;
    destructor Destroy; override;
    function TryFetchWellKnownEndpoints: Boolean;
    function SetProviderByConfigurationToken(const AJson: string): Boolean;
    function StartAuth : Boolean;
    function BeginPolling(const AIntervalMs: Cardinal = 3000;
      const ATimeoutMs: Cardinal = 600000): IFuture<TTraffiqxPollResult>;
    procedure CancelPolling;
    function RefreshAccessToken : Boolean;//(const _RefreshToken : String; out _NewAccessToken : String; out _NewRefreshToken : String) : Boolean;
    function RevokeTokens(out AError: TTraffiqxError): Boolean;
    function CheckConnectionAccess(out AError: TTraffiqxError): Boolean;
    // Userinfo-Endpunkt (OIDC) mit dem aktuellen Access-Token.
    function GetUserInfo(out AUserInfo: TTraffiqxUserInfo; out AError: TTraffiqxError): Boolean;
    // Introspection-Endpunkt: prueft ein Token ("access_token" oder
    // "refresh_token") am Identity Provider und liefert u.a. dessen Ablauf.
    function IntrospectToken(const AToken, ATokenTypeHint: string;
      out AResult: TTraffiqxTokenIntrospection; out AError: TTraffiqxError): Boolean;
    // Ablauf eines neu ausgestellten Refresh-Tokens, wenn der Provider ihn
    // nicht mitliefert: DATEV 11 Stunden, mit offline_access 6 Monate ab
    // Anmeldung. Die Laufzeit verlaengert sich beim Erneuern nicht.
    function DefaultRefreshTokenExpiresAt(const AIssuedAt: TDateTime): TDateTime;

    function DownloadInboxDocument(const ADocumentId: string;
      out AContent: TMemoryStream; out AError: TTraffiqxError): Boolean;

    function GetInboxDocumentMetadata(const ADocumentId: string;
      out AMetadata: TTraffiqxInboxDocumentMetadata; out AError: TTraffiqxError): Boolean;

    function GetInboxDocumentIds(out ADocuments: TTraffiqxInboxDocumentList; out AError: TTraffiqxError;
      const AUseDownloadedFilter: Boolean = False; const ADownloaded: Boolean = False;
      const AFromDate: TDateTime = 0; const AToDate: TDateTime = 0): Boolean;

    function UploadZugferdData(const AData: TStream; const ADataFileName: string;
      const ADeliveryParamsJson: string; out AResult: TTraffiqxUploadResult; out AError: TTraffiqxError): Boolean;

    function UploadStructuredData(const ADataXml, AViewPdf: TStream; const ADataFileName, AViewFileName: string;
      const ADeliveryParamsJson: string; out AResult: TTraffiqxUploadResult; out AError: TTraffiqxError): Boolean;

    function GetOutboxDocumentIds(out ADocuments: TTraffiqxOutboxDocumentList; out AError: TTraffiqxError;
      const AUseDownloadedFilter: Boolean = False; const ADownloaded: Boolean = False;
      const AUseStatusFilter: Boolean = False; const AStatus: string = ''): Boolean;

    function GetOutboxDocumentMetadata(const ADocumentId: string;
      out AMetadata: TTraffiqxOutboxMetadata; out AError: TTraffiqxError): Boolean;

    function GetOutboxDocumentStatus(const ADocumentId: string;
      out AStatus: TTraffiqxInboxDocumentStatusInfo; out AError: TTraffiqxError): Boolean;

    // Wartet auf den fachlichen Zielstatus "sent". Standard: fester Abstand
    // von 8 Sekunden, hoechstens 1 Minute (Vorgabe aus der DATEV-Abnahme).
    function WaitForOutboxDocumentSent(const ADocumentId: string;
      out AStatus: TTraffiqxInboxDocumentStatusInfo; out AError: TTraffiqxError;
      const AInitialIntervalMs: Cardinal = 8000; const AMaxIntervalMs: Cardinal = 8000;
      const ATimeoutMs: Cardinal = 60000): Boolean;

    function DownloadOutboxDocument(const ADocumentId: string;
      out AContent: TMemoryStream; out APendingStatus: TTraffiqxInboxDocumentStatusInfo; out AError: TTraffiqxError): Boolean;
  public
    property AccessToken: string read FAccessToken write FAccessToken;
    property AccessTokenExpiresAt : TDateTime read FAccessTokenExpiresAt write FAccessTokenExpiresAt;
    property RefreshToken: string read FRefreshToken write FRefreshToken;
    property RefreshTokenExpiresAt : TDateTime read FRefreshTokenExpiresAt write FRefreshTokenExpiresAt;
  public
    property LastRawContentReceived : String read FLastRawContentReceived;
  public
    property ClientId : String read FClientId write FClientId;
    property ClientSecret : String read FClientSecret write FClientSecret;
    property TRAFFIQXId : String read FTRAFFIQXId write SetTRAFFIQXId;
    property AppDisplayName : String read FAppDisplayName write FAppDisplayName;
    property Scope : String read FScope write FScope;
    property OAuth2BrokerCallbackUri : String read FOAuth2BrokerCallbackUri write FOAuth2BrokerCallbackUri;
    property OAuth2BrokerApiKey : String read FOAuth2BrokerApiKey write FOAuth2BrokerApiKey;
    property WellKnownUri : String read FWellKnownUri;
    property OAuthUri : String read FOAuthUri;
    property AccessTokenUri : String read FAccessTokenUri;
    property RevocationUri : String read FRevocationUri;
    property UserInfoUri : String read FUserInfoUri;
    property IntrospectionUri : String read FIntrospectionUri;
    property ApiBaseUri : String read FApiBaseUri;
    property CurrentSessionId : String read FCurrentSessionId;
    property PollFuture : IFuture<TTraffiqxPollResult> read FPollFuture;
  public
    property ProviderType : TTraffiqxProviderType read FProviderType write SetProviderType;
    property Environment : TTraffiqxEnvironment read FEnvironment write SetEnvironment;
    property OnPollingCompleted: TTraffiqxPollCompletedEvent read FOnPollingCompleted write FOnPollingCompleted;
    property OnOpenAuthUrl: TTraffiqxOpenAuthUrlEvent read FOnOpenAuthUrl write FOnOpenAuthUrl;
    property OnHttpTrace: TTraffiqxHttpTraceEvent read FOnHttpTrace write FOnHttpTrace;
  end;

implementation

function TraffiqxNormalizeId(const AValue: string): string;
var
  i: Integer;
begin
  Result := '';
  for i := 1 to Length(AValue) do
    if not CharInSet(AValue[i], [' ', #9, #10, #13, #160]) then
      Result := Result + AValue[i];
  if StartsText('TX:', Result) then
    Delete(Result, 1, 3);
end;

{ TTraffiqxPollResult }

class function TTraffiqxPollResult.Pending: TTraffiqxPollResult;
begin
  Result := Default(TTraffiqxPollResult);
  Result.Status := psPending;
  Result.AccessToken := '';
  Result.RefreshToken := '';
  Result.AccessTokenExpiresAt := 0;
  Result.RefreshTokenExpiresAt := 0;
  Result.ErrorCode := '';
  Result.ErrorDescription := '';
end;

class function TTraffiqxPollResult.Success(const AAccessToken,
  ARefreshToken: string; AAccessTokenExpiresAt, ARefreshTokenExpiresAt : TDateTime): TTraffiqxPollResult;
begin
  Result := Default(TTraffiqxPollResult);
  Result.Status := psSuccess;
  Result.AccessToken := AAccessToken;
  Result.RefreshToken := ARefreshToken;
  Result.AccessTokenExpiresAt := AAccessTokenExpiresAt;
  Result.RefreshTokenExpiresAt := ARefreshTokenExpiresAt;
  Result.ErrorCode := '';
  Result.ErrorDescription := '';
end;

class function TTraffiqxPollResult.Fail(const ACode,
  ADescription: string): TTraffiqxPollResult;
begin
  Result := Default(TTraffiqxPollResult);
  Result.Status := psError;
  Result.AccessToken := '';
  Result.RefreshToken := '';
  Result.AccessTokenExpiresAt := 0;
  Result.RefreshTokenExpiresAt := 0;
  Result.ErrorCode := ACode;
  Result.ErrorDescription := ADescription;
end;

class function TTraffiqxPollResult.Cancelled: TTraffiqxPollResult;
begin
  Result := Default(TTraffiqxPollResult);
  Result.Status := psCancelled;
  Result.AccessToken := '';
  Result.RefreshToken := '';
  Result.AccessTokenExpiresAt := 0;
  Result.RefreshTokenExpiresAt := 0;
  Result.ErrorCode := 'cancelled';
  Result.ErrorDescription := 'Polling wurde abgebrochen.';
end;

class function TTraffiqxPollResult.Timeout: TTraffiqxPollResult;
begin
  Result := Default(TTraffiqxPollResult);
  Result.Status := psTimeout;
  Result.AccessToken := '';
  Result.RefreshToken := '';
  Result.AccessTokenExpiresAt := 0;
  Result.RefreshTokenExpiresAt := 0;
  Result.ErrorCode := 'timeout';
  Result.ErrorDescription := 'Polling hat das Zeitlimit überschritten.';
end;

function TTraffiqxPollResult.IsSuccess: Boolean;
begin
  Result := Status = psSuccess;
end;

{ TTraffiqxError }

constructor TTraffiqxError.Create(const ATitle: string; const AStatus: Integer;
  const ADetail: string);
begin
  Title := ATitle;
  Status := AStatus;
  Detail := ADetail;
end;

class function TTraffiqxError.FromJson(const AJson: TJSONObject): TTraffiqxError;
var
  LTitle, LDetail, LStatusStr: string;
  LStatus: Integer;
begin
  LTitle := '';
  LDetail := '';
  LStatus := 0;

  AJson.TryGetValue<string>('title', LTitle);
  if not AJson.TryGetValue<Integer>('status', LStatus) then
  begin
    if AJson.TryGetValue<string>('status', LStatusStr) then
      LStatus := StrToIntDef(LStatusStr, 0);
  end;
  if not AJson.TryGetValue<string>('detail', LDetail) then
    LDetail := AJson.ToJSON;

  Result := TTraffiqxError.Create(LTitle, LStatus, LDetail);
  AJson.TryGetValue<string>('type', Result.TypeUri);
end;

function TTraffiqxError.ToJson: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('title', Title);
  Result.AddPair('status', TJSONNumber.Create(Status));
  Result.AddPair('detail', Detail);
end;

{ TTraffiqxInboxErrorHelper }

class function TTraffiqxInboxErrorHelper.ExtractErrorCode(
  const AText: string): string;
var
  LText: string;
  LStart: Integer;
  LEnd: Integer;
begin
  Result := '';
  LText := UpperCase(AText);
  LStart := Pos('#TIA', LText);
  if LStart = 0 then
    Exit;

  LEnd := LStart + 4;
  while (LEnd <= Length(LText)) and CharInSet(LText[LEnd], ['0'..'9']) do
    Inc(LEnd);

  Result := Copy(AText, LStart, LEnd - LStart);
end;

class function TTraffiqxInboxErrorHelper.ErrorCode(
  const AError: TTraffiqxError): string;
begin
  Result := '';
  if AError = nil then
    Exit;

  Result := ExtractErrorCode(AError.Title);
  if Result = '' then
    Result := ExtractErrorCode(AError.Detail);
end;

class function TTraffiqxInboxErrorHelper.HelpUrlForErrorCode(
  const AErrorCode: string): string;
begin
  if SameText(AErrorCode, '#TIA40000') then
    Exit('https://apps.datev.de/help-center/documents/1038619');

  if SameText(AErrorCode, '#TIA10000') or SameText(AErrorCode, '#TIA10030') then
    Exit('https://apps.datev.de/help-center/documents/1038620');

  if SameText(AErrorCode, '#TIA30000') or SameText(AErrorCode, '#TIA30010')
    or SameText(AErrorCode, '#TIA40010') then
    Exit('https://apps.datev.de/help-center/documents/1038621');

  if SameText(AErrorCode, '#TIA40020') then
    Exit('https://apps.datev.de/help-center/documents/1038622');

  if SameText(AErrorCode, '#TIA10020') or SameText(AErrorCode, '#TIA30020')
    or SameText(AErrorCode, '#TIA10170') or SameText(AErrorCode, '#TIA10130')
    or SameText(AErrorCode, '#TIA10140') or SameText(AErrorCode, '#TIA10150') then
    Exit('https://apps.datev.de/help-center/documents/1038625');

  if SameText(AErrorCode, '#TIA10010') or SameText(AErrorCode, '#TIA10040')
    or SameText(AErrorCode, '#TIA10070') then
    Exit('https://apps.datev.de/help-center/documents/1038626');

  Result := '';
end;

class function TTraffiqxInboxErrorHelper.DescribeHttpStatus(
  const AStatus: Integer): string;
begin
  case AStatus of
    400:
      Result := 'Die Anfrage wurde als fehlerhaft erkannt. Pruefen Sie Dokumenten-ID, Query-Parameter und unzulaessige Zeichen.';
    401:
      Result := 'Die Autorisierung ist fehlgeschlagen. Pruefen Sie Client-Zugangsdaten, Bestand und ob die verwendeten Tokens noch gueltig sind.';
    403:
      Result := 'Fuer die angeforderte Ressource fehlt die Berechtigung oder die Ressource ist fuer diesen Bestand nicht erreichbar.';
    404:
      Result := 'Die angeforderte Ressource wurde nicht gefunden. Pruefen Sie insbesondere Dokumenten-ID und Verfuegbarkeit der Eingangsrechnung.';
    500:
      Result := 'Beim Verarbeiten der Anfrage ist ein unerwarteter Serverfehler aufgetreten. Pruefen Sie bei anhaltenden Fehlern den DATEV-Status.';
    503:
      Result := 'Der Dienst ist voruebergehend nicht verfuegbar oder ueberlastet. Wiederholen Sie die Anfrage nach einer angemessenen Wartezeit.';
  else
    Result := '';
  end;
end;

class function TTraffiqxInboxErrorHelper.DescribeErrorCode(
  const AErrorCode: string): string;
begin
  if SameText(AErrorCode, '#TIA40000') then
    Exit('Die Anfrage wurde wegen ungueltiger Eingaben abgelehnt. Typische Ursachen sind eine ungueltige Dokumenten-ID, falsch verwendete Query-Parameter oder unzulaessige Zeichen.');

  if SameText(AErrorCode, '#TIA10000') or SameText(AErrorCode, '#TIA10030') then
    Exit('Die Anmeldung oder Autorisierung wurde abgelehnt. Pruefen Sie die Anmeldeinformationen der Anwendung, den Bestand und die Gueltigkeit des Access-Tokens.');

  if SameText(AErrorCode, '#TIA30000') or SameText(AErrorCode, '#TIA30010') then
    Exit('Es besteht keine ausreichende Berechtigung fuer die angeforderte Ressource, oder die Ressource ist unter der angegebenen TRAFFIQX-ID nicht vorhanden.');

  if SameText(AErrorCode, '#TIA40010') then
    Exit('Der Zugriff auf das E-Rechnungspostfach Eingang ist fuer den angegebenen Bestand nicht erlaubt. Pruefen Sie TRAFFIQX-ID, Bestandsberechtigung und Postfachberechtigung.');

  if SameText(AErrorCode, '#TIA40020') then
    Exit('Die angeforderte Eingangsrechnung wurde nicht gefunden. Pruefen Sie die Dokumenten-ID; die Rechnung kann auch durch Zeitablauf oder Benutzeraktion geloescht worden sein.');

  if SameText(AErrorCode, '#TIA10020') or SameText(AErrorCode, '#TIA30020')
    or SameText(AErrorCode, '#TIA10170') or SameText(AErrorCode, '#TIA10130')
    or SameText(AErrorCode, '#TIA10140') or SameText(AErrorCode, '#TIA10150') then
    Exit('Es ist ein unerwarteter Fehler beim Abarbeiten der Anfrage aufgetreten. Die Anfrage kann derzeit nicht bearbeitet werden; pruefen Sie bei Dauerstoerungen den DATEV-Status.');

  if SameText(AErrorCode, '#TIA10010') or SameText(AErrorCode, '#TIA10040')
    or SameText(AErrorCode, '#TIA10070') then
    Exit('Die Anfrage kann zurzeit nicht bearbeitet werden, meist wegen einer temporaeren Stoerung oder Ueberlastung. Wiederholen Sie die Anfrage nach einer Wartezeit.');

  Result := '';
end;

class function TTraffiqxInboxErrorHelper.BuildUserMessage(
  const AError: TTraffiqxError): string;
var
  LErrorCode: string;
  LDescription: string;
  LHelpUrl: string;
begin
  Result := '';
  if AError = nil then
    Exit;

  LErrorCode := ErrorCode(AError);
  if LErrorCode <> '' then
    LDescription := DescribeErrorCode(LErrorCode)
  else
    LDescription := '';

  if LDescription = '' then
    LDescription := DescribeHttpStatus(AError.Status);

  if (LErrorCode <> '') and (LDescription <> '') then
    Result := LErrorCode + ': ' + LDescription
  else
    Result := LDescription;

  // DATEV-Vorgabe: bei 4xx mindestens die Hilfe-URL anzeigen - auch dann,
  // wenn zum Fehler keine Beschreibung hinterlegt ist.
  LHelpUrl := HelpUrl(AError);
  if LHelpUrl <> '' then
  begin
    if Result <> '' then
      Result := Result + sLineBreak;
    Result := Result + 'DATEV-Hilfe: ' + LHelpUrl;
  end;

  if (AError.Status = 500) or (AError.Status = 503) then
  begin
    if Result <> '' then
      Result := Result + sLineBreak;
    Result := Result + 'DATEV-Status: https://www.datev-status.de/';
  end;
end;

class function TTraffiqxInboxErrorHelper.HelpUrl(
  const AError: TTraffiqxError): string;
begin
  Result := '';
  if AError = nil then
    Exit;

  Result := HelpUrlForErrorCode(ErrorCode(AError));
  if (Result = '') and (StartsText('http://', AError.TypeUri) or StartsText('https://', AError.TypeUri)) then
    Result := AError.TypeUri;
end;

class function TTraffiqxInboxErrorHelper.ErrorText(
  const AError: TTraffiqxError): string;
var
  LUserMessage: string;
begin
  Result := '';
  if AError = nil then
    Exit;

  Result := AError.Detail;
  if Result = '' then
    Result := AError.Title;

  LUserMessage := BuildUserMessage(AError);
  if LUserMessage <> '' then
    Result := Result + '  ' + LUserMessage;

  // Den ganzen Text einzeilig machen - auch Detail/Title koennen Umbrueche
  // enthalten, und zwar als CRLF, CR oder LF.
  Result := StringReplace(Result, #13#10, '  ', [rfReplaceAll]);
  Result := StringReplace(Result, #13, '  ', [rfReplaceAll]);
  Result := Trim(StringReplace(Result, #10, '  ', [rfReplaceAll]));
end;

{ TTraffiqxInboxDocument }

constructor TTraffiqxInboxDocument.Create(const ADocumentId: string;
  const ADownloaded: Boolean; const AHref: string);
begin
  DocumentId := ADocumentId;
  Downloaded := ADownloaded;
  Href := AHref;
end;

class function TTraffiqxInboxDocument.FromJson(const AJson: TJSONObject): TTraffiqxInboxDocument;
var
  LId, LHref: string;
  LDownloaded: Boolean;
begin
  LId := '';
  LHref := '';
  LDownloaded := False;

  AJson.TryGetValue<string>('document_id', LId);
  AJson.TryGetValue<Boolean>('downloaded', LDownloaded);
  AJson.TryGetValue<string>('href', LHref);

  Result := TTraffiqxInboxDocument.Create(LId, LDownloaded, LHref);
end;

{ TTraffiqxInboxDocumentMetadata }

constructor TTraffiqxInboxDocumentMetadata.Create(const AInvoiceDate: TDate;
  const AInvoiceNumber: string; const AGrossTotal: Double;
  const ACurrencyCode, ASellerName, ABuyerName, AInvoiceType, ADocumentFormat: string;
  const ADateOfReceipt: TDateTime; const AEN16931Compliant, ADownloaded: Boolean);
begin
  InvoiceDate := AInvoiceDate;
  InvoiceNumber := AInvoiceNumber;
  GrossTotal := AGrossTotal;
  CurrencyCode := ACurrencyCode;
  SellerName := ASellerName;
  BuyerName := ABuyerName;
  InvoiceType := AInvoiceType;
  DocumentFormat := ADocumentFormat;
  DateOfReceipt := ADateOfReceipt;
  EN16931Compliant := AEN16931Compliant;
  Downloaded := ADownloaded;
end;

class function TTraffiqxInboxDocumentMetadata.FromJson(
  const AJson: TJSONObject): TTraffiqxInboxDocumentMetadata;
var
  LInvoiceDateStr, LDateOfReceiptStr: string;
  LInvoiceDate, LDateOfReceipt: TDateTime;
  LInvoiceNumber, LCurrencyCode, LSellerName, LBuyerName, LInvoiceType, LDocumentFormat: string;
  LGrossTotal: Double;
  LEN16931Compliant, LDownloaded: Boolean;
begin
  LInvoiceDateStr := '';
  LDateOfReceiptStr := '';
  LInvoiceDate := 0;
  LDateOfReceipt := 0;
  LInvoiceNumber := '';
  LCurrencyCode := '';
  LSellerName := '';
  LBuyerName := '';
  LInvoiceType := '';
  LDocumentFormat := '';
  LGrossTotal := 0;
  LEN16931Compliant := False;
  LDownloaded := False;

  AJson.TryGetValue<string>('invoice_date', LInvoiceDateStr);
  if not TryISO8601ToDate(LInvoiceDateStr, LInvoiceDate, False) then
    LInvoiceDate := 0
  else
    LInvoiceDate := Trunc(LInvoiceDate);

  AJson.TryGetValue<string>('date_of_receipt', LDateOfReceiptStr);
  if not TryISO8601ToDate(LDateOfReceiptStr, LDateOfReceipt, False) then
    LDateOfReceipt := 0;

  AJson.TryGetValue<string>('invoice_number', LInvoiceNumber);
  AJson.TryGetValue<Double>('gross_total', LGrossTotal);
  AJson.TryGetValue<string>('currency_code', LCurrencyCode);
  AJson.TryGetValue<string>('seller_name', LSellerName);
  AJson.TryGetValue<string>('buyer_name', LBuyerName);
  AJson.TryGetValue<string>('invoice_type', LInvoiceType);
  AJson.TryGetValue<string>('document_format', LDocumentFormat);
  AJson.TryGetValue<Boolean>('en_16931_compliant', LEN16931Compliant);
  AJson.TryGetValue<Boolean>('downloaded', LDownloaded);

  Result := TTraffiqxInboxDocumentMetadata.Create(LInvoiceDate, LInvoiceNumber, LGrossTotal,
    LCurrencyCode, LSellerName, LBuyerName, LInvoiceType, LDocumentFormat, LDateOfReceipt,
    LEN16931Compliant, LDownloaded);
end;

function TTraffiqxInboxDocumentMetadata.ToJson: TJSONObject;
begin
  Result := TJSONObject.Create;
  if InvoiceDate <> 0 then
    Result.AddPair('invoice_date', DateToISO8601(InvoiceDate, False))
  else
    Result.AddPair('invoice_date', '');
  Result.AddPair('invoice_number', InvoiceNumber);
  Result.AddPair('gross_total', TJSONNumber.Create(GrossTotal));
  Result.AddPair('currency_code', CurrencyCode);
  Result.AddPair('seller_name', SellerName);
  Result.AddPair('buyer_name', BuyerName);
  Result.AddPair('invoice_type', InvoiceType);
  Result.AddPair('document_format', DocumentFormat);
  if DateOfReceipt <> 0 then
    Result.AddPair('date_of_receipt', DateToISO8601(DateOfReceipt, False))
  else
    Result.AddPair('date_of_receipt', '');
  Result.AddPair('en_16931_compliant', TJSONBool.Create(EN16931Compliant));
  Result.AddPair('downloaded', TJSONBool.Create(Downloaded));
end;

{ TTraffiqxDeliveryChannel }

class function TTraffiqxDeliveryChannel.FromJson(const AJson: TJSONObject): TTraffiqxDeliveryChannel;
begin
  Result := nil;
  if AJson = nil then
    Exit;
  Result := TTraffiqxDeliveryChannel.Create;
  AJson.TryGetValue<string>('name', Result.Name);
  AJson.TryGetValue<string>('address', Result.Address);
end;

{ TTraffiqxDocumentStatusHelper }

class function TTraffiqxDocumentStatusHelper.FromRawStatus(
  const ARawStatus: string): TTraffiqxDocumentStatus;
var
  LNormalized: string;
begin
  LNormalized := LowerCase(Trim(ARawStatus));
  LNormalized := StringReplace(LNormalized, ' ', '', [rfReplaceAll]);
  LNormalized := StringReplace(LNormalized, '_', '', [rfReplaceAll]);
  LNormalized := StringReplace(LNormalized, '-', '', [rfReplaceAll]);

  if LNormalized = 'inprocess' then
    Exit(dsInProcess);
  if LNormalized = 'sent' then
    Exit(dsSent);
  if LNormalized = 'error' then
    Exit(dsError);
  if LNormalized = 'deleted' then
    Exit(dsDeleted);
  if LNormalized = 'useraction' then
    Exit(dsUserAction);

  Result := dsUnknown;
end;

class function TTraffiqxDocumentStatusHelper.ToDisplayString(
  const AStatus: TTraffiqxDocumentStatus): string;
begin
  case AStatus of
    dsInProcess: Result := 'InProcess';
    dsSent: Result := 'Sent';
    dsError: Result := 'Error';
    dsDeleted: Result := 'Deleted';
    dsUserAction: Result := 'UserAction';
  else
    Result := 'Unknown';
  end;
end;

class function TTraffiqxDocumentStatusHelper.DescribeStatus(
  const AStatus: TTraffiqxDocumentStatus): string;
begin
  case AStatus of
    dsInProcess:
      Result := 'Die Verarbeitung laeuft noch. Es liegt noch kein Endergebnis vor.';
    dsSent:
      Result := 'Die Verarbeitung wurde erfolgreich abgeschlossen.';
    dsError:
      Result := 'Die Verarbeitung wurde fachlich oder technisch abgelehnt.';
    dsDeleted:
      Result := 'Das Dokument ist nicht mehr verfuegbar oder wurde verworfen.';
    dsUserAction:
      Result := 'Die Verarbeitung wartet auf eine manuelle oder fachliche Rueckmeldung.';
  else
    Result := 'Unbekannter oder vom Client noch nicht interpretierter Status.';
  end;
end;

class function TTraffiqxDocumentStatusHelper.DescribeErrorCode(
  const AErrorCode: string): string;
begin
  if SameText(AErrorCode, 'VALIDATION_VIRUS_FOUND') then
    Exit('Die Datei oder ein Anhang wurde wegen eines Virenfunds oder weil der Inhalt nicht scanbar war abgelehnt. Das Dokument kann nicht weiter verarbeitet werden.');

  if SameText(AErrorCode, 'VALIDATION_VIEW_COMPONENT_ERROR') then
    Exit('Die Sichtkomponente wurde abgelehnt. Gemeint ist in der Regel das mitgelieferte PDF, nicht die XML-Rechnungsdaten.');

  if SameText(AErrorCode, 'VALIDATION_DRAFT_ERROR') then
    Exit('Die hochgeladene Rechnungsdatei (Entwurf) wurde bei der Eingangspruefung abgelehnt.');

  if SameText(AErrorCode, 'VALIDATION_STRUCTURED_DATA_ERROR') then
    Exit('Die strukturierten Rechnungsdaten wurden bei der EN-16931-/Formatpruefung abgelehnt.');

  if SameText(AErrorCode, 'VALIDATION_DELIVERY_INFORMATION_ERROR') then
    Exit('Die Routing- oder Empfaengerangaben passen nicht zur erwarteten Sandbox-Adressierung.');

  if SameText(AErrorCode, 'CREATION_DOCUMENT_ERROR') then
    Exit('Aus den gelieferten Rechnungsdaten konnte kein gueltiges Ausgangsdokument erstellt werden. Ursache ist typischerweise ein unbekanntes Format, ein Parse-Fehler oder ein nicht unterstuetzter Rechnungstyp.');

  if SameText(AErrorCode, 'SHIPPING_ORIGINAL_ERROR') then
    Exit('Die Verarbeitung oder der simulierte Versand des Originaldokuments ist fehlgeschlagen. Das betrifft typischerweise die hochgeladene Originaldatei bzw. deren fachliche Weiterverarbeitung und nicht primaer die Routing-Angaben.');

  if SameText(AErrorCode, 'SHIPPING_TRAFFIQX_ERROR') then
    Exit('Die Zustellung der E-Rechnung ueber den TRAFFIQX-Kanal ist fehlgeschlagen.');

  if SameText(AErrorCode, 'SHIPPING_PEPPOL_ERROR') then
    Exit('Die Zustellung der E-Rechnung ueber den Peppol-Kanal ist fehlgeschlagen.');

  if SameText(AErrorCode, 'SHIPPING_EMAIL_ERROR') then
    Exit('Die Zustellung der E-Rechnung per E-Mail ist fehlgeschlagen. Ursache kann insbesondere eine ungueltige Empfaengeradresse sein.');

  if SameText(AErrorCode, 'PROCESS_TIMED_OUT') then
    Exit('Die Verarbeitung hat das zulassige Zeitfenster ueberschritten und wurde mit Timeout beendet.');

  if SameText(AErrorCode, 'PROCESS_NO_MEMBERSHIP') then
    Exit('Fuer die Verarbeitung oder Zustellung liegt keine passende Mitgliedschaft oder Freischaltung fuer den Ausgangskanal vor.');

  if SameText(AErrorCode, 'PROCESS_CANCELED') then
    Exit('Die Verarbeitung wurde vorzeitig abgebrochen, entweder durch den Mandanten oder systemseitig.');

  Result := '';
end;

class function TTraffiqxDocumentStatusHelper.DescribeErrorDetails(
  const AErrorDetails: string): string;
begin
  if SameText(AErrorDetails, 'DRAFT_INFECTED') then
    Exit('Die eigentliche Rechnungsdatei wurde beim Virenscan als infiziert erkannt und deshalb verworfen.');

  if SameText(AErrorDetails, 'VIEW_COMPONENT_INFECTED') then
    Exit('Die Sichtkomponente wurde beim Virenscan als infiziert erkannt und deshalb verworfen.');

  if SameText(AErrorDetails, 'ATTACHMENT_INFECTED') then
    Exit('Ein Anhang wurde beim Virenscan als infiziert erkannt und deshalb verworfen.');

  if SameText(AErrorDetails, 'DRAFT_NOT_SCANNABLE') then
    Exit('Die Datei konnte nicht auf Schadsoftware geprueft werden, typischerweise weil sie verschluesselt oder nicht lesbar ist.');

  if SameText(AErrorDetails, 'DRAFT_UNSUPPORTED_FORMAT') then
    // Text laut DATEV-Business-Dokumentation (Fehlercodes Postausgang)
    // Beobachtet (Produktion 09/2026): auch eine als XRechnung-Extension
    // deklarierte Rechnung wird mit diesem Code abgelehnt.
    Exit('Die Datei entspricht nicht dem zulaessigen E-Rechnungsformat. Zulaessige Formate: XML CII, XML UBL, ZUGFeRD EN16931, ZUGFeRD XRechnung, XRechnung, Peppol BIS Billing. '
      + 'Beobachtet: Auch eine als XRechnung-Extension deklarierte Rechnung (CustomizationID mit "extension:xrechnung") wird abgelehnt.');

  // Beobachtet (Produktion 09/2026, nicht in der Business-Dokumentation):
  // RECEIVER_IS_SENDER_TRAFFIQXID bei einer Rechnung an die eigene TRAFFIQX-ID.
  if StartsText('RECEIVER_IS_SENDER', AErrorDetails) then
    Exit('Rechnungsempfaenger und Absender sind identisch (' + AErrorDetails + '). Eine Rechnung an den eigenen Bestand wird nicht versendet - '
      + 'bitte die Empfaengerangaben der Rechnung pruefen (z.B. TRAFFIQX-ID in BT-10).');

  if SameText(AErrorDetails, 'DRAFT_DRAFT_TOO_LARGE') or SameText(AErrorDetails, 'DRAFT_TOO_LARGE') then
    Exit('Die hochgeladene Rechnungsdatei ueberschreitet die zulaessige Dateigroesse von 100 MB.');

  if SameText(AErrorDetails, 'VIEW_COMPONENT_UNSUPPORTED_FORMAT') then
    Exit('Das PDF der Sichtkomponente hat kein unterstuetztes Format. Fuer UBL/CII erwartet DATEV hier typischerweise ein gueltiges PDF/A-3 ohne unzulaessige Anhaenge.');

  if SameText(AErrorDetails, 'VIEW_COMPONENT_FORBIDDEN') then
    Exit('Im Entwurf ist bereits eine Sichtkomponente vorhanden. Eine zusaetzliche oder separate Sichtkomponente ist in diesem Fall nicht zulaessig.');

  if SameText(AErrorDetails, 'VIEW_COMPONENT_TOO_LARGE') then
    Exit('Die Sichtkomponente ueberschreitet die zulaessige Dateigroesse von 20 MB.');

  if SameText(AErrorDetails, 'VIEW_COMPONENT_MISSING') then
    Exit('Zur strukturierten Rechnung fehlt die verpflichtende Sichtkomponente als PDF/A-3.');

  if SameText(AErrorDetails, 'DATA_FORMAT_UNKNOWN') then
    Exit('Die Datei konnte nicht als bekanntes E-Rechnungsformat erkannt werden.');

  if SameText(AErrorDetails, 'DATA_FORMAT_NOT_PARSEABLE') then
    Exit('Die Datei enthaelt ungueltige oder nicht lesbare Rechnungsdaten und konnte deshalb nicht verarbeitet werden.');

  if SameText(AErrorDetails, 'NATIVE_PDF_NOT_SUPPORTED') then
    Exit('Eine reine PDF-Datei ohne eingebettete E-Rechnungsdaten wird fuer dieses Szenario nicht unterstuetzt.');

  if SameText(AErrorDetails, 'INVOICE_TYPE_CODE_UNKNOWN') then
    Exit('Der Rechnungstyp der Datei ist nicht zulaessig oder konnte nicht als unterstuetzter Typ erkannt werden.');

  if SameText(AErrorDetails, 'GENERAL_SHIPPING_ERROR_TRAFFIQX') then
    Exit('Bei der Zustellung ueber TRAFFIQX ist ein allgemeiner Versandfehler aufgetreten.');

  if SameText(AErrorDetails, 'GENERAL_SHIPPING_ERROR_PEPPOL') then
    Exit('Bei der Zustellung ueber Peppol ist ein allgemeiner Versandfehler aufgetreten.');

  if SameText(AErrorDetails, 'SHIPPING_ERROR_EMAIL_RECIPIENT_INVALID') then
    Exit('Die E-Mail-Zustellung ist fehlgeschlagen, weil die Empfaengeradresse des Kaeufers ungueltig ist.');

  if SameText(AErrorDetails, 'GENERAL_SHIPPING_ERROR_EMAIL') then
    Exit('Bei der Zustellung per E-Mail ist ein allgemeiner Versandfehler aufgetreten.');

  if SameText(AErrorDetails, 'SERVICE_DOWN') then
    Exit('Die Verarbeitung konnte nicht abgeschlossen werden, weil ein beteiligter Dienst aktuell nicht verfuegbar ist.');

  if SameText(AErrorDetails, 'NO_MEMBERSHIP_OUTBOX') then
    Exit('Fuer den Postausgang liegt keine passende Mitgliedschaft oder Aktivierung vor.');

  if SameText(AErrorDetails, 'CANCELED_BY_TENANT') then
    Exit('Die Verarbeitung wurde vom Mandanten oder Auftraggeber aktiv abgebrochen.');

  if SameText(AErrorDetails, 'CANCELED_BY_SYSTEM') then
    Exit('Die Verarbeitung wurde systemseitig abgebrochen.');

  if SameText(AErrorDetails, 'VALIDATION_FAILED') then
    Exit('Im nachgelagerten Validierungsschritt wurde das Originaldokument abgelehnt. Ursachen sind haeufig inhaltliche oder formatbezogene Probleme des Ursprungsdokuments, obwohl Upload und erste Statuspruefung bereits funktioniert haben.');

  Result := '';
end;

{ TTraffiqxInboxDocumentStatusInfo }

class function TTraffiqxInboxDocumentStatusInfo.FromJson(const AJson: TJSONObject): TTraffiqxInboxDocumentStatusInfo;
begin
  Result := nil;
  if AJson = nil then
    Exit;
  Result := TTraffiqxInboxDocumentStatusInfo.Create;
  AJson.TryGetValue<string>('status', Result.Status);
  AJson.TryGetValue<string>('error_code', Result.ErrorCode);
  AJson.TryGetValue<string>('error_details', Result.ErrorDetails);
  AJson.TryGetValue<Boolean>('downloaded', Result.Downloaded);
end;

function TTraffiqxInboxDocumentStatusInfo.ParsedStatus: TTraffiqxDocumentStatus;
begin
  Result := TTraffiqxDocumentStatusHelper.FromRawStatus(Status);
end;

function TTraffiqxInboxDocumentStatusInfo.IsSuccessful: Boolean;
begin
  Result := ParsedStatus = dsSent;
end;

function TTraffiqxInboxDocumentStatusInfo.IsTerminal: Boolean;
begin
  Result := ParsedStatus in [dsSent, dsError, dsDeleted, dsUserAction];
end;

function TTraffiqxInboxDocumentStatusInfo.HasProcessingError: Boolean;
begin
  Result := ParsedStatus in [dsError, dsDeleted, dsUserAction];
end;

{ TTraffiqxUploadResult }

class function TTraffiqxUploadResult.FromJson(const AJson: TJSONObject): TTraffiqxUploadResult;
begin
  Result := nil;
  if AJson = nil then
    Exit;
  Result := TTraffiqxUploadResult.Create;
  AJson.TryGetValue<string>('document_id', Result.DocumentId);
  AJson.TryGetValue<string>('href', Result.Href);
end;

{ TTraffiqxOutboxDocument }

class function TTraffiqxOutboxDocument.FromJson(const AJson: TJSONObject): TTraffiqxOutboxDocument;
begin
  Result := nil;
  if AJson = nil then
    Exit;
  Result := TTraffiqxOutboxDocument.Create;
  AJson.TryGetValue<string>('document_id', Result.DocumentId);
  AJson.TryGetValue<string>('status', Result.Status);
  AJson.TryGetValue<Boolean>('downloaded', Result.Downloaded);
  AJson.TryGetValue<string>('href', Result.Href);
end;

function TTraffiqxOutboxDocument.ParsedStatus: TTraffiqxDocumentStatus;
begin
  Result := TTraffiqxDocumentStatusHelper.FromRawStatus(Status);
end;

{ TTraffiqxOutboxMetadata }

constructor TTraffiqxOutboxMetadata.Create;
begin
  inherited Create;
  DeliveryChannel := nil;
  StatusInfo := nil;
end;

destructor TTraffiqxOutboxMetadata.Destroy;
begin
  DeliveryChannel.Free;
  StatusInfo.Free;
  inherited;
end;

class function TTraffiqxOutboxMetadata.FromJson(const AJson: TJSONObject): TTraffiqxOutboxMetadata;
var
  LInvoiceDateStr, LSendDateStr: string;
  LInvoiceDate, LSendDate: TDateTime;
  LChannel: TJSONObject;
  LStatus: TJSONObject;
begin
  Result := nil;
  if AJson = nil then
    Exit;

  Result := TTraffiqxOutboxMetadata.Create;
  LInvoiceDate := 0;
  LSendDate := 0;

  AJson.TryGetValue<string>('invoice_date', LInvoiceDateStr);
  if not TryISO8601ToDate(LInvoiceDateStr, LInvoiceDate, False) then
    LInvoiceDate := 0
  else
    LInvoiceDate := Trunc(LInvoiceDate);
  Result.InvoiceDate := LInvoiceDate;

  AJson.TryGetValue<string>('invoice_number', Result.InvoiceNumber);
  AJson.TryGetValue<Double>('gross_total', Result.GrossTotal);
  AJson.TryGetValue<string>('currency_code', Result.CurrencyCode);
  AJson.TryGetValue<string>('seller_name', Result.SellerName);
  AJson.TryGetValue<string>('buyer_name', Result.BuyerName);
  AJson.TryGetValue<string>('invoice_type', Result.InvoiceType);
  AJson.TryGetValue<string>('document_format', Result.DocumentFormat);

  AJson.TryGetValue<string>('send_date', LSendDateStr);
  if not TryISO8601ToDate(LSendDateStr, LSendDate, False) then
    LSendDate := 0;
  Result.SendDate := LSendDate;

  LChannel := AJson.Values['delivery_channel'] as TJSONObject;
  if LChannel <> nil then
    Result.DeliveryChannel := TTraffiqxDeliveryChannel.FromJson(LChannel);

  LStatus := AJson.Values['status'] as TJSONObject;
  if LStatus <> nil then
    Result.StatusInfo := TTraffiqxInboxDocumentStatusInfo.FromJson(LStatus);
end;

{ TTraffiqxHelper }

class function TTraffiqxHelper.ExtractFirstFileFromZip(const AZipStream: TStream;
  out AContent: TMemoryStream; out AError: TTraffiqxError): Boolean;
var
  lZip: TZipFile;
  lLocalHeader : TZipHeader;
  lStream : TStream;
begin
  Result := False;
  AContent := nil;
  AError := nil;

  if (AZipStream = nil) or (AZipStream.Size = 0) then
  begin
    AError := TTraffiqxError.Create('#ZIP', 0, 'Zip-Stream ist leer.');
    Exit;
  end;

  lZip := TZipFile.Create;
  try
    try
      AZipStream.Position := 0;
      lZip.Open(AZipStream, zmRead);
    except
      on E: Exception do
      begin
        AError := TTraffiqxError.Create('#ZIP', 0, 'Zip konnte nicht geöffnet werden: ' + E.Message);
        Exit;
      end;
    end;

    if lZip.FileCount = 0 then
    begin
      AError := TTraffiqxError.Create('#ZIP', 0, 'Zip enthält keine Dateien.');
      Exit;
    end;

    AContent := TMemoryStream.Create;
    lStream := nil;
    try
      lZip.Read(0, lStream, lLocalHeader);
      try
        lStream.Position := 0;
        AContent.LoadFromStream(lStream);
        AContent.Position := 0;
        Result := True;
      finally
        lStream.Free;
      end;
    except
      on E: Exception do
      begin
        FreeAndNil(AContent);
        AError := TTraffiqxError.Create('#ZIP', 0, 'Zip-Datei konnte nicht gelesen werden: ' + E.Message);
      end;
    end;
  finally
    lZip.Free;
  end;
end;

function TTRAFFIQXInvoiceAPI.SetProviderByConfigurationToken(const AJson: string): Boolean;
var
  LJsonValue: TJSONValue;
  LJson: TJSONObject;
  LWellKnownUri, LApiUrl, LTraffiqxId, LProviderId: string;
  function MapProviderId(const AProviderId, AWellKnownUri, AApiUrl: string): TTraffiqxProviderType;
  var
    LProviderHint: string;
  begin
    LProviderHint := LowerCase(AProviderId + ' ' + AWellKnownUri + ' ' + AApiUrl);

    if ContainsText(LProviderHint, 'smarttransfer') then
      Exit(tpDatevSmartTransfer);
    if ContainsText(LProviderHint, 'datev') then
      Exit(tpDatev);
    if ContainsText(LProviderHint, 'b4value') then
      Exit(tpB4Value);
    if ContainsText(LProviderHint, 'bundesdruckerei')
      or ContainsText(LProviderHint, 'bdr-businessportal') then
      Exit(tpBundesdruckerei);
    if ContainsText(LProviderHint, 'becloud') then
      Exit(tpBeCloud);
    if ContainsText(LProviderHint, 'exela') or ContainsText(LProviderHint, 'asterion') then
      Exit(tpExelaAsterion);
    if ContainsText(LProviderHint, 'quadient') then
      Exit(tpQuadient);
    if ContainsText(LProviderHint, 'sgh') or ContainsText(LProviderHint, 'ivi.sgh-net') then
      Exit(tpSGHService);
    if ContainsText(LProviderHint, 'ricoh') then
      Exit(tpRicoh);
    Result := FProviderType;
  end;
  function NormalizeApiBaseUri(const AApiUrl: string): string;
  var
    LSlashPos: Integer;
    LLastSegment: string;
  begin
    Result := Trim(AApiUrl);
    while Result.EndsWith('/') do
      Delete(Result, Length(Result), 1);

    if Result = '' then
      Exit;

    LSlashPos := Result.LastDelimiter('/');
    if LSlashPos > 0 then
      LLastSegment := LowerCase(Copy(Result, LSlashPos + 1, MaxInt))
    else
      LLastSegment := LowerCase(Result);

    if (Length(LLastSegment) >= 2) and (LLastSegment[1] = 'v')
      and CharInSet(LLastSegment[2], ['0'..'9']) then
      Exit;

    Result := Result + '/v1';
  end;
begin
  Result := False;
  LJsonValue := nil;
  LJson := nil;

  LJsonValue := TJSONObject.ParseJSONValue(AJson);
  try
    if not (LJsonValue is TJSONObject) then
      Exit;

    LJson := TJSONObject(LJsonValue);

    LWellKnownUri := '';
    LApiUrl := '';
    LTraffiqxId := '';
    LProviderId := '';

    LJson.TryGetValue<string>('well_known_url', LWellKnownUri);
    LJson.TryGetValue<string>('api_url', LApiUrl);
    LJson.TryGetValue<string>('traffiqx_id', LTraffiqxId);
    LJson.TryGetValue<string>('provider_id', LProviderId);

    if (LProviderId <> '') or (LWellKnownUri <> '') or (LApiUrl <> '') then
      FProviderType := MapProviderId(LProviderId, LWellKnownUri, LApiUrl);

    if (LApiUrl <> '') and ContainsText(LApiUrl, 'sandbox') then
      FEnvironment := teSandbox
    else if LApiUrl <> '' then
      FEnvironment := teProduction;

    // Standardwerte für Provider/Umgebung laden, dann ggf. per Token überschreiben
    ApplyProviderConfig;

    if LWellKnownUri <> '' then
      FWellKnownUri := LWellKnownUri;
    if LApiUrl <> '' then
      FApiBaseUri := NormalizeApiBaseUri(LApiUrl);
    if LTraffiqxId <> '' then
      TRAFFIQXId := LTraffiqxId;

    TryFetchWellKnownEndpoints;

    Result := True;
  finally
    LJsonValue.Free;
  end;
end;

{ TTRAFFIQXInvoiceAPI }

constructor TTRAFFIQXInvoiceAPI.Create;
begin
  FClientId := '';
  FClientSecret := '';
  FTRAFFIQXId := '';
  FAppDisplayName := '';
  FScope := 'openid traffiqx:invoice';
  FOAuth2BrokerCallbackUri := '';
  FOAuth2BrokerApiKey := '';
  FAccessTokenUri := '';
  FWellKnownUri := '';
  FRevocationUri := '';
  FUserInfoUri := '';
  FIntrospectionUri := '';
  FOAuthUri := '';
  FApiBaseUri := '';
  FCurrentSessionId := '';
  FPollFuture := nil;
  FPollCancelFlag := 0;
  FOnPollingCompleted := nil;
  FOnOpenAuthUrl := nil;
  FOnHttpTrace := nil;

  FProviderType := tpNotSet;
  FEnvironment := teSandbox;

  ApplyProviderConfig;
end;

destructor TTRAFFIQXInvoiceAPI.Destroy;
begin
  CancelPolling;
  inherited;
end;

procedure TTRAFFIQXInvoiceAPI.ApplyProviderConfig;
var
  lEndpoints: TTraffiqxProviderEndpoints;
begin
  // Stellt je nach Provider/Umgebung die bekannten Standardendpunkte bereit
  case FEnvironment of
    teSandbox:    lEndpoints := TRAFFIQX_PROVIDER_CONFIG[FProviderType].Sandbox;
  else
    lEndpoints := TRAFFIQX_PROVIDER_CONFIG[FProviderType].Production;
  end;

  FWellKnownUri := lEndpoints.WellKnownUri;
  FOAuthUri := lEndpoints.OAuthUri;
  FAccessTokenUri := lEndpoints.TokenUri;
  FRevocationUri := '';
  FUserInfoUri := '';
  FIntrospectionUri := '';
  FApiBaseUri := lEndpoints.ApiBaseUri;
end;

procedure TTRAFFIQXInvoiceAPI.SetTRAFFIQXId(const Value: String);
begin
  FTRAFFIQXId := TraffiqxNormalizeId(Value);
end;

function TTRAFFIQXInvoiceAPI.TryFetchWellKnownEndpoints: Boolean;
var
  LHttpClient: TNetHTTPClient;
  LResponse: IHTTPResponse;
  LJson: TJSONObject;
  LAuthEndpoint, LTokenEndpoint, LRevocationEndpoint: string;
  LUserInfoEndpoint, LIntrospectionEndpoint: string;
begin
  Result := False;

  if FWellKnownUri = '' then
    Exit;

  LHttpClient := TNetHTTPClient.Create(nil);
  try
    try
      LResponse := HttpGet(LHttpClient, FWellKnownUri, nil, nil, tbOnError);
    except
      Exit;
    end;

    if (LResponse = nil) or (LResponse.StatusCode < 200) or (LResponse.StatusCode >= 400) then
      Exit;

    LJson := TJSONObject.ParseJSONValue(LResponse.ContentAsString(TEncoding.UTF8)) as TJSONObject;
    if LJson = nil then
      Exit;

    try
      LAuthEndpoint := '';
      LTokenEndpoint := '';
      LRevocationEndpoint := '';
      LJson.TryGetValue<string>('authorization_endpoint', LAuthEndpoint);
      LJson.TryGetValue<string>('token_endpoint', LTokenEndpoint);
      LJson.TryGetValue<string>('revocation_endpoint', LRevocationEndpoint);
      LUserInfoEndpoint := '';
      LIntrospectionEndpoint := '';
      LJson.TryGetValue<string>('userinfo_endpoint', LUserInfoEndpoint);
      LJson.TryGetValue<string>('introspection_endpoint', LIntrospectionEndpoint);

      if LAuthEndpoint <> '' then
        FOAuthUri := LAuthEndpoint;
      if LTokenEndpoint <> '' then
        FAccessTokenUri := LTokenEndpoint;
      if LRevocationEndpoint <> '' then
        FRevocationUri := LRevocationEndpoint;
      if LUserInfoEndpoint <> '' then
        FUserInfoUri := LUserInfoEndpoint;
      if LIntrospectionEndpoint <> '' then
        FIntrospectionUri := LIntrospectionEndpoint;

      Result := (LAuthEndpoint <> '') and (LTokenEndpoint <> '');
    finally
      LJson.Free;
    end;
  finally
    LHttpClient.Free;
  end;
end;

procedure TTRAFFIQXInvoiceAPI.CancelPolling;
begin
  TInterlocked.Exchange(FPollCancelFlag, 1);

  if Assigned(FPollFuture) and (FPollFuture.Status in
    [TTaskStatus.Running, TTaskStatus.WaitingToRun, TTaskStatus.Created]) then
    FPollFuture.Cancel;

  FPollFuture := nil;
end;

function TTRAFFIQXInvoiceAPI.CheckConnectionAccess(
  out AError: TTraffiqxError): Boolean;
var
  LHttpClient: TNetHTTPClient;
  LResponse: IHTTPResponse;
  LJsonValue: TJSONValue;

  function BuildHttpError(const AArea: string; AResponse: IHTTPResponse): TTraffiqxError;
  var
    LResponseText: string;
  begin
    LResponseText := AResponse.ContentAsString(TEncoding.UTF8);
    LJsonValue := TJSONObject.ParseJSONValue(LResponseText);
    if LJsonValue is TJSONObject then
      Result := TTraffiqxError.FromJson(TJSONObject(LJsonValue))
    else
      Result := MakeError('#HTTP' + AResponse.StatusCode.ToString,
        AResponse.StatusCode, LResponseText);

    if Result.Detail <> '' then
      Result.Detail := AArea + '-Verbindungscheck fehlgeschlagen: ' + Result.Detail
    else
      Result.Detail := AArea + '-Verbindungscheck fehlgeschlagen. HTTP-Status: '
        + AResponse.StatusCode.ToString;
  end;

  function CheckStatusEndpoint(const AArea, AUrl: string): Boolean;
  begin
    Result := False;
    try
      LResponse := HttpGet(LHttpClient, AUrl, nil, nil, tbOnError);
    except
      on E: Exception do
      begin
        AError := MakeError('#TRANSPORT', 0,
          AArea + '-Verbindungscheck fehlgeschlagen: ' + E.Message);
        Exit;
      end;
    end;

    if LResponse.StatusCode <> 200 then
    begin
      AError := BuildHttpError(AArea, LResponse);
      Exit;
    end;

    Result := True;
  end;
begin
  Result := False;
  AError := nil;

  if (FApiBaseUri = '') or (FTRAFFIQXId = '') or (FAccessToken = '') or (FClientId = '') then
  begin
    AError := MakeError('#LOCAL', 0, 'Ungültige oder fehlende Konfiguration.');
    Exit;
  end;
  if (FProviderType in [tpDatev,tpDatevSmartTransfer]) and (FAppDisplayName = '') then
  begin
    AError := MakeError('#LOCAL', 0, 'Fehlender App-Display-Name.');
    Exit;
  end;

  LHttpClient := TNetHTTPClient.Create(nil);
  LJsonValue := nil;
  try
    ApplyAuthHeaders(LHttpClient);

    if not CheckStatusEndpoint('Inbox', BuildInboxBase + '?from_date=') then
      Exit;
    LJsonValue.Free;
    LJsonValue := nil;

    // Abnahme-Vorgabe: Outbox-Status mit status=inProcess filtern (kleine Payload).
    if not CheckStatusEndpoint('Outbox', BuildOutboxBase + '?status=inProcess') then
      Exit;
  finally
    LJsonValue.Free;
    LHttpClient.Free;
  end;

  Result := True;
end;

function TTRAFFIQXInvoiceAPI.ScopeContainsOfflineAccess: Boolean;
begin
  Result := ContainsText(' ' + Trim(FScope) + ' ', ' offline_access ');
end;

function TTRAFFIQXInvoiceAPI.DefaultRefreshTokenExpiresAt(
  const AIssuedAt: TDateTime): TDateTime;
begin
  Result := 0;
  if not (FProviderType in [tpDatev,tpDatevSmartTransfer]) then
    Exit;
  if ScopeContainsOfflineAccess then
    Result := IncMonth(AIssuedAt, 6)
  else
    Result := IncHour(AIssuedAt, 11);
end;

function TTRAFFIQXInvoiceAPI.GetUserInfo(out AUserInfo: TTraffiqxUserInfo;
  out AError: TTraffiqxError): Boolean;
var
  LHttpClient: TNetHTTPClient;
  LResponse: IHTTPResponse;
  LResponseText: string;
  LJsonValue: TJSONValue;
  LJson: TJSONObject;
begin
  Result := False;
  AError := nil;
  AUserInfo := Default(TTraffiqxUserInfo);

  if FAccessToken = '' then
  begin
    AError := MakeError('#LOCAL', 0, 'Kein Access-Token vorhanden.');
    Exit;
  end;
  if (FUserInfoUri = '') and not TryFetchWellKnownEndpoints then
  begin
    AError := MakeError('#LOCAL', 0, 'well-known-Endpunkte nicht abrufbar.');
    Exit;
  end;
  if FUserInfoUri = '' then
  begin
    AError := MakeError('#LOCAL', 0, 'Der Identity Provider liefert keinen userinfo_endpoint.');
    Exit;
  end;

  LHttpClient := TNetHTTPClient.Create(nil);
  try
    LHttpClient.CustomHeaders['Authorization'] := 'Bearer ' + FAccessToken;
    try
      LResponse := HttpGet(LHttpClient, FUserInfoUri, nil, nil, tbOnError);
    except
      on E: Exception do
      begin
        AError := MakeError('#TRANSPORT', 0, 'Userinfo: ' + E.Message);
        Exit;
      end;
    end;

    LResponseText := LResponse.ContentAsString(TEncoding.UTF8);
    if LResponse.StatusCode <> 200 then
    begin
      AError := MakeError('#HTTP' + LResponse.StatusCode.ToString, LResponse.StatusCode,
        'Userinfo: ' + LResponseText);
      Exit;
    end;

    // Erst als TJSONValue uebernehmen: "[]" oder "null" sind gueltiges
    // JSON, aber kein Objekt (ein "as" wuerde werfen und die Instanz verlieren).
    LJsonValue := TJSONObject.ParseJSONValue(LResponseText);
    if not (LJsonValue is TJSONObject) then
    begin
      LJsonValue.Free;
      AError := MakeError('#JSON', LResponse.StatusCode, 'Userinfo: Antwort ist kein JSON-Objekt.');
      Exit;
    end;
    LJson := TJSONObject(LJsonValue);
    try
      LJson.TryGetValue<string>('sub', AUserInfo.Sub);
      LJson.TryGetValue<string>('name', AUserInfo.Name);
      LJson.TryGetValue<string>('given_name', AUserInfo.GivenName);
      LJson.TryGetValue<string>('family_name', AUserInfo.FamilyName);
      LJson.TryGetValue<string>('email', AUserInfo.Email);
      if AUserInfo.Name = '' then
        AUserInfo.Name := Trim(AUserInfo.GivenName + ' ' + AUserInfo.FamilyName);
    finally
      LJson.Free;
    end;
    Result := True;
  finally
    LHttpClient.Free;
  end;
end;

function TTRAFFIQXInvoiceAPI.IntrospectToken(const AToken, ATokenTypeHint: string;
  out AResult: TTraffiqxTokenIntrospection; out AError: TTraffiqxError): Boolean;
var
  LHttpClient: TNetHTTPClient;
  LRequestStream: TStringStream;
  LResponse: IHTTPResponse;
  LResponseText: string;
  LHeaders: TNetHeaders;
  LBase64NoBreaks: TBase64Encoding;
  LJsonValue: TJSONValue;
  LJson: TJSONObject;
  LExp: Int64;
  LExpiresIn: Int64;
begin
  Result := False;
  AError := nil;
  AResult := Default(TTraffiqxTokenIntrospection);

  if AToken = '' then
  begin
    AError := MakeError('#LOCAL', 0, 'Kein Token zum Pruefen vorhanden.');
    Exit;
  end;
  if (FIntrospectionUri = '') and not TryFetchWellKnownEndpoints then
  begin
    AError := MakeError('#LOCAL', 0, 'well-known-Endpunkte nicht abrufbar.');
    Exit;
  end;
  if FIntrospectionUri = '' then
  begin
    AError := MakeError('#LOCAL', 0, 'Der Identity Provider liefert keinen introspection_endpoint.');
    Exit;
  end;

  LHttpClient := TNetHTTPClient.Create(nil);
  LRequestStream := TStringStream.Create('', TEncoding.UTF8);
  LBase64NoBreaks := TBase64Encoding.Create(0);
  try
    // DATEV: Client-ID und Client-Secret als Basic Auth
    if FClientSecret <> '' then
      LHttpClient.CustomHeaders['Authorization'] := 'Basic '
        + LBase64NoBreaks.Encode(FClientId + ':' + FClientSecret);

    LRequestStream.WriteString('token=' + TNetEncoding.URL.Encode(AToken)
      + '&token_type_hint=' + TNetEncoding.URL.Encode(ATokenTypeHint)
      + IfThen(FClientSecret = '', '&client_id=' + TNetEncoding.URL.Encode(FClientId), ''));
    LRequestStream.Position := 0;

    SetLength(LHeaders, 1);
    LHeaders[0] := TNameValuePair.Create('Content-Type', 'application/x-www-form-urlencoded');

    try
      LResponse := HttpPost(LHttpClient, FIntrospectionUri, LRequestStream, LHeaders, tbOnError);
    except
      on E: Exception do
      begin
        AError := MakeError('#TRANSPORT', 0, 'Introspection: ' + E.Message);
        Exit;
      end;
    end;

    LResponseText := LResponse.ContentAsString(TEncoding.UTF8);
    if LResponse.StatusCode <> 200 then
    begin
      AError := MakeError('#HTTP' + LResponse.StatusCode.ToString, LResponse.StatusCode,
        'Introspection: ' + LResponseText);
      Exit;
    end;

    // Erst als TJSONValue uebernehmen: "[]" oder "null" sind gueltiges
    // JSON, aber kein Objekt (ein "as" wuerde werfen und die Instanz verlieren).
    LJsonValue := TJSONObject.ParseJSONValue(LResponseText);
    if not (LJsonValue is TJSONObject) then
    begin
      LJsonValue.Free;
      AError := MakeError('#JSON', LResponse.StatusCode, 'Introspection: Antwort ist kein JSON-Objekt.');
      Exit;
    end;
    LJson := TJSONObject(LJsonValue);
    try
      LJson.TryGetValue<Boolean>('active', AResult.Active);
      LJson.TryGetValue<string>('scope', AResult.Scope);
      // "exp" = Ablauf in Sekunden seit 1970 (UTC), ersatzweise "expires_in"
      LExp := 0;
      LExpiresIn := 0;
      if LJson.TryGetValue<Int64>('exp', LExp) and (LExp > 0) then
      begin
        AResult.ExpiresAt := UnixToDateTime(LExp, False);
        // Direkt aus "exp", ohne Umweg ueber die in der Herbststunde mehrdeutige Ortszeit
        AResult.ExpiresAtUtc := UnixToDateTime(LExp, True);
      end
      else if LJson.TryGetValue<Int64>('expires_in', LExpiresIn) and (LExpiresIn > 0) then
      begin
        AResult.ExpiresAt := IncSecond(Now, LExpiresIn);
        AResult.ExpiresAtUtc := IncSecond(TDateTime.NowUTC, LExpiresIn);
      end;
    finally
      LJson.Free;
    end;
    Result := True;
  finally
    LBase64NoBreaks.Free;
    LRequestStream.Free;
    LHttpClient.Free;
  end;
end;

function TTRAFFIQXInvoiceAPI.RevokeTokens(out AError: TTraffiqxError): Boolean;
var
  LHttpClient: TNetHTTPClient;
  LRequestStream: TStringStream;
  LResponse: IHTTPResponse;
  LHeaders: TNetHeaders;
  LBase64NoBreaks: TBase64Encoding;

  function RevokeToken(const AToken, ATokenTypeHint: string): Boolean;
  var
    LFormBody: string;
    LResponseText: string;
  begin
    Result := True;
    if AToken = '' then
      Exit;

    LFormBody := 'token=' + TNetEncoding.URL.Encode(AToken)
      + '&token_type_hint=' + TNetEncoding.URL.Encode(ATokenTypeHint);
    if FClientSecret = '' then
      LFormBody := LFormBody + '&client_id=' + TNetEncoding.URL.Encode(FClientId);

    LRequestStream.Size := 0;
    LRequestStream.Position := 0;
    LRequestStream.WriteString(LFormBody);
    LRequestStream.Position := 0;

    try
      LResponse := HttpPost(LHttpClient, FRevocationUri, LRequestStream, LHeaders, tbOnError);
    except
      on E: Exception do
      begin
        AError := MakeError('#REVOCATION_TRANSPORT', 0, E.Message);
        Exit(False);
      end;
    end;

    if (LResponse.StatusCode < 200) or (LResponse.StatusCode >= 300) then
    begin
      LResponseText := LResponse.ContentAsString(TEncoding.UTF8);
      AError := MakeError('#REVOCATION_HTTP' + LResponse.StatusCode.ToString,
        LResponse.StatusCode, LResponseText);
      Exit(False);
    end;
  end;

begin
  Result := False;
  AError := nil;

  if (FAccessToken = '') and (FRefreshToken = '') then
    Exit(True);

  if FRevocationUri = '' then
  begin
    if not TryFetchWellKnownEndpoints then
    begin
      AError := MakeError('#REVOCATION_UNAVAILABLE', 0,
        'Der Identity Provider liefert keinen bekannten revocation_endpoint. Tokens koennen nicht automatisch widerrufen werden.');
      Exit;
    end;
  end;

  if FRevocationUri = '' then
  begin
    AError := MakeError('#REVOCATION_UNAVAILABLE', 0,
      'Der Identity Provider liefert keinen revocation_endpoint. Tokens koennen nicht automatisch widerrufen werden.');
    Exit;
  end;

  LHttpClient := TNetHTTPClient.Create(nil);
  LRequestStream := TStringStream.Create('', TEncoding.UTF8);
  LBase64NoBreaks := TBase64Encoding.Create(0);
  try
    if FClientSecret <> '' then
      LHttpClient.CustomHeaders['Authorization'] := 'Basic '
        + LBase64NoBreaks.Encode(FClientId + ':' + FClientSecret);

    SetLength(LHeaders, 1);
    LHeaders[0] := TNameValuePair.Create('Content-Type', 'application/x-www-form-urlencoded');

    if not RevokeToken(FRefreshToken, 'refresh_token') then
      Exit;
    if not RevokeToken(FAccessToken, 'access_token') then
      Exit;

    FAccessToken := '';
    FRefreshToken := '';
    FAccessTokenExpiresAt := 0;
    FRefreshTokenExpiresAt := 0;
    Result := True;
  finally
    LBase64NoBreaks.Free;
    LRequestStream.Free;
    LHttpClient.Free;
  end;
end;

procedure TTRAFFIQXInvoiceAPI.SetEnvironment(const Value: TTraffiqxEnvironment);
begin
  if FEnvironment = Value then
    Exit;

  FEnvironment := Value;
  ApplyProviderConfig;
end;

procedure TTRAFFIQXInvoiceAPI.SetProviderType(const Value: TTraffiqxProviderType);
begin
  if FProviderType = Value then
    Exit;

  FProviderType := Value;
  ApplyProviderConfig;
end;

function TTRAFFIQXInvoiceAPI.BuildBrokerEndpoint(const AEndpoint: string): string;
var
  LUri: TURI;
  LPath, LBase, LResource, LExt: string;
  LSlash: Integer;
begin
  Result := '';
  if FOAuth2BrokerCallbackUri = '' then
    Exit;

  LUri := TURI.Create(FOAuth2BrokerCallbackUri);
  LPath := LUri.Path;
  if LPath = '' then
    LPath := '/';

  LSlash := LPath.LastDelimiter('/');
  if LSlash > 0 then
  begin
    LBase := Copy(LPath, 1, LSlash);
    LResource := Copy(LPath, LSlash + 1, MaxInt);
  end
  else
  begin
    LBase := '/';
    LResource := LPath;
  end;

  if (LBase = '') or (LBase[Length(LBase)] <> '/') then
    LBase := LBase + '/';

  LExt := ExtractFileExt(LResource);

  Result := LUri.Scheme + '://' + LUri.Host;
  if LUri.Port <> 0 then
    Result := Result + ':' + LUri.Port.ToString;
  Result := Result + LBase + AEndpoint + LExt;
end;

function TTRAFFIQXInvoiceAPI.MakeError(const ATitle: string;
  const AStatus: Integer; const ADetail: string): TTraffiqxError;
begin
  Result := TTraffiqxError.Create(ATitle, AStatus, ADetail);
end;

function TTRAFFIQXInvoiceAPI.BuildInboxBase: string;
begin
  Result := FApiBaseUri + ifthen(FApiBaseUri.EndsWith('/'), '', '/')
    + 'traffiqx-clients/' + TNetEncoding.URL.Encode(FTRAFFIQXId) + '/inbox-documents';
end;

function TTRAFFIQXInvoiceAPI.BuildOutboxBase: string;
begin
  Result := FApiBaseUri + ifthen(FApiBaseUri.EndsWith('/'), '', '/')
    + 'traffiqx-clients/' + TNetEncoding.URL.Encode(FTRAFFIQXId) + '/outbox-documents';
end;

procedure TTRAFFIQXInvoiceAPI.ApplyAuthHeaders(AClient: TNetHTTPClient);
begin
  AClient.CustomHeaders['Authorization'] := 'Bearer ' + FAccessToken;
  if (FProviderType in [tpDatev,tpDatevSmartTransfer]) then
    AClient.CustomHeaders['X-Datev-Client-ID'] := FClientId
  else
    AClient.CustomHeaders['X-traffiqx-Client-ID'] := FClientId;
  if (FProviderType in [tpDatev,tpDatevSmartTransfer]) and (FAppDisplayName <> '') then
    AClient.CustomHeaders['X-App-Display-Name'] := FAppDisplayName;
end;

const
  TRACE_MAX_BODY_CHARS = 65536;
  // Schluessel, deren Werte nie ins Protokoll duerfen. Verglichen wird nach
  // URL-Dekodierung ohne Gross-/Kleinschreibung, "_" und "-"
  // (access_token = accessToken = access%5Ftoken).
  // "code" gilt immer als geheim: DATEV liefert Fehlercodes als "error_code".
  TRACE_SECRET_KEYS: array[0..15] of string = (
    'accesstoken', 'refreshtoken', 'idtoken', 'idtokenhint', 'token', 'code',
    'codeverifier', 'clientsecret', 'providerclientsecret', 'secret',
    'password', 'apikey', 'xapikey', 'sessionid', 'clientassertion',
    'authorization');
  TRACE_BODY_DROPPED = '(Body nicht protokolliert: enthaelt moeglicherweise Tokens)';

// AWithState: In URLs und Formularen ist auch "state" geheim (beim
// Broker-Login sessionId plus Zufallswert), in JSON-Daten nicht (Adressen).
function TraceIsSecretKey(const AKey: string; AWithState: Boolean): Boolean;
var
  LKey, LSecret: string;
begin
  LKey := LowerCase(AKey.Replace('_', '').Replace('-', ''));
  if AWithState and (LKey = 'state') then
    Exit(True);
  for LSecret in TRACE_SECRET_KEYS do
    if LKey = LSecret then
      Exit(True);
  Result := False;
end;

// Freitext wird nicht maskiert, sondern nur geprueft: Folgt auf irgendein
// Wort, das ein geheimer Schluessel ist, (nach Leerraum, Anfuehrungszeichen
// oder Backslashes) ein ":" oder "=", koennte ein Geheimnis dahinter stehen,
// egal wie der Wert aussieht. Werte in beliebigem Text lassen sich nicht
// verlaesslich abgrenzen, deshalb wird dann der ganze Text verworfen.
function TraceMentionsSecret(const AText: string): Boolean;
var
  LMatch: TMatch;
  LName: string;
  i, n: Integer;
begin
  Result := False;
  n := Length(AText);
  for LMatch in TRegEx.Matches(AText, '[A-Za-z0-9_%\-]+') do
  begin
    i := LMatch.Index + LMatch.Length;
    while (i <= n) and CharInSet(AText[i], ['"', '''', '\', ' ', #9, #10, #13]) do
      Inc(i);
    if (i > n) or not CharInSet(AText[i], [':', '=']) then
      Continue;
    LName := LMatch.Value;
    try
      LName := TNetEncoding.URL.Decode(LName);
    except
    end;
    if TraceIsSecretKey(LName, True) then
      Exit(True);
  end;
end;

// Erkennt Tokens an ihrer Form statt am Schluessel davor: Anmeldedaten nach
// "Bearer" oder "Basic" (etwa ein Fehlertext, der den Authorization-Header
// wiedergibt) und JWT-foermige Zeichenketten ("eyJ..." mit Punkt-Segmenten).
// Undurchsichtige Tokens ohne erkennbare Form bleiben auf die Pruefung der
// Schluessel angewiesen.
// - Nach "Bearer" oder "Basic" gilt ein Wort ab 16 Zeichen als Token, damit
//   Fehlertexte wie "Bearer token required" oder "Basic authentication
//   failed" lesbar bleiben. Laengere Woerter (etwa "Basic Authentifizierung
//   fehlgeschlagen") gelten dennoch als Token - lieber zu viel weglassen als
//   ein Token protokollieren. Kuerzere Bearer-Tokens werden nicht erkannt.
// - Kuerzere Werte nach "Basic" gelten als Zugangsdaten, wenn sie sich als
//   Base64 zu druckbarem Text mit ":" dekodieren lassen ("dTpw" = "u:p").
// - Das JWT-Muster beginnt nur am Anfang eines Laufs (Lookbehind); sonst
//   wuerde jede "eyJ"-Stelle innerhalb eines langen Laufs neu ansetzen und die
//   Pruefung grosser Bodies quadratisch teuer.
const
  TRACE_JWT_PATTERN = '(?<![A-Za-z0-9_\-])eyJ[A-Za-z0-9_\-]{4,}\.[A-Za-z0-9_\-]{4,}(?:\.[A-Za-z0-9_\-]*)?';
  TRACE_AUTH_PATTERN = '(?i)\b(?:bearer|basic)\s+[A-Za-z0-9\-._~+/]{16,}';
  TRACE_BASIC_PATTERN = '(?i)\bbasic\s+([A-Za-z0-9+/]{2,}={0,2})(?![A-Za-z0-9+/=])';

function TraceIsBasicCredential(const AValue: string): Boolean;
var
  LBytes: TBytes;
  LByte: Byte;
begin
  Result := False;
  if Length(AValue) mod 4 <> 0 then
    Exit;
  try
    LBytes := TNetEncoding.Base64.DecodeStringToBytes(AValue);
  except
    Exit;
  end;
  for LByte in LBytes do
    if (LByte < 32) or (LByte = 127) then
      Exit;
  for LByte in LBytes do
    if LByte = Ord(':') then
      Exit(True);
end;

function TraceHasTokenShape(const AText: string): Boolean;
var
  LMatch: TMatch;
begin
  if TRegEx.IsMatch(AText, TRACE_AUTH_PATTERN) or TRegEx.IsMatch(AText, TRACE_JWT_PATTERN) then
    Exit(True);
  for LMatch in TRegEx.Matches(AText, TRACE_BASIC_PATTERN) do
    if TraceIsBasicCredential(LMatch.Groups[1].Value) then
      Exit(True);
  Result := False;
end;

// AKeepPlus: "+" bleibt erhalten (im URL-Pfad ein woertliches Plus), sonst
// wird es wie im Query-String zum Leerzeichen.
function TraceUrlDecode(const AText: string; AKeepPlus: Boolean = False): string;
begin
  try
    if AKeepPlus then
      Result := TNetEncoding.URL.Decode(AText.Replace('+', '%2B'))
    else
      Result := TNetEncoding.URL.Decode(AText);
  except
    Result := AText;
  end;
end;

// Prueft den Text wie er ist und, wenn er URL-kodiert sein koennte, auch in
// beiden dekodierten Varianten ("Bearer%20...", "Basic%20ODo+").
function TraceContainsToken(const AText: string): Boolean;
begin
  Result := TraceHasTokenShape(AText);
  if not Result and ((Pos('%', AText) > 0) or (Pos('+', AText) > 0)) then
    Result := TraceHasTokenShape(TraceUrlDecode(AText))
      or TraceHasTokenShape(TraceUrlDecode(AText, True));
end;

// Ersetzt Tokens, die an ihrer Form erkennbar sind, durch "***" (fuer URLs
// und Fehlermeldungen, die lesbar bleiben sollen).
function TraceMaskTokens(const AText: string): string;
var
  LBuilder: TStringBuilder;
  LMatch: TMatch;
  LPos: Integer;
begin
  Result := TRegEx.Replace(AText, TRACE_JWT_PATTERN, '***');
  Result := TRegEx.Replace(Result, TRACE_AUTH_PATTERN, '***');
  // Nach "Basic" nur die Werte ersetzen, die sich als Zugangsdaten dekodieren
  // lassen; "Basic authentication failed" bleibt stehen.
  LBuilder := TStringBuilder.Create;
  try
    LPos := 1;
    for LMatch in TRegEx.Matches(Result, TRACE_BASIC_PATTERN) do
      if TraceIsBasicCredential(LMatch.Groups[1].Value) then
      begin
        LBuilder.Append(Result, LPos - 1, LMatch.Groups[1].Index - LPos);
        LBuilder.Append('***');
        LPos := LMatch.Groups[1].Index + LMatch.Groups[1].Length;
      end;
    if LPos > 1 then
    begin
      LBuilder.Append(Result, LPos - 1, Length(Result) - LPos + 1);
      Result := LBuilder.ToString;
    end;
  finally
    LBuilder.Free;
  end;
end;

class function TTRAFFIQXInvoiceAPI.RedactUrl(const AText: string): string;
var
  LBuilder: TStringBuilder;
  LMatch: TMatch;
  LName: string;
  LPos: Integer;
  LText: string;
  LDecoded: string;
begin
  // Zuerst Tokens maskieren, die an ihrer Form erkennbar sind (siehe
  // TraceContainsToken), auch ausserhalb von name=wert.
  LText := TraceMaskTokens(AText);
  // Jedes name=wert nach einem Trenner pruefen; der Name wird vor dem
  // Vergleich URL-dekodiert.
  LBuilder := TStringBuilder.Create;
  try
    LPos := 1;
    for LMatch in TRegEx.Matches(LText, '(?<=^|[&?#;\s"])([^=&?#;\s"]+)=("[^"]*"|[^&#;\s"]*)') do
    begin
      LName := LMatch.Groups[1].Value;
      try
        LName := TNetEncoding.URL.Decode(LName);
      except
      end;
      // Leere Werte bleiben stehen; sonst saehe "token= SECRET" danach wie
      // maskiert aus. Werte unter anderen Namen werden dekodiert auf Tokens
      // geprueft ("detail=Bearer%20...").
      if (LMatch.Groups[2].Value <> '***') and (LMatch.Groups[2].Value <> '')
        and (TraceIsSecretKey(LName, True)
          or TraceContainsToken(LMatch.Groups[2].Value)) then
      begin
        LBuilder.Append(LText, LPos - 1, LMatch.Groups[2].Index - LPos);
        LBuilder.Append('***');
        LPos := LMatch.Groups[2].Index + LMatch.Groups[2].Length;
      end;
    end;
    LBuilder.Append(LText, LPos - 1, Length(LText) - LPos + 1);
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;

  // Steckt dekodiert noch ein Token im Text (etwa URL-kodiert im Pfad), wird
  // der dekodierte Text maskiert ausgegeben; gelingt das nicht, gar nichts.
  // Erst mit woertlichem "+" maskieren (Pfad), dann "+" als Leerzeichen
  // (Query-String) erneut.
  if TraceContainsToken(Result) then
  begin
    LDecoded := TraceMaskTokens(TraceUrlDecode(Result, True));
    LDecoded := TraceMaskTokens(LDecoded.Replace('+', ' '));
    if TraceContainsToken(LDecoded) then
      LDecoded := '(nicht protokolliert: enthaelt moeglicherweise Tokens)';
    Result := LDecoded;
  end;
end;

// Freitext pruefen (siehe TraceMentionsSecret und TraceContainsToken);
// \u-Escapes gelten ebenfalls als unsicher. False = der Text darf nicht ins
// Protokoll.
function TraceRedactText(const AText: string; out ARedacted: string): Boolean;
begin
  ARedacted := AText;
  Result := (Pos('\u', AText) = 0) and not TraceMentionsSecret(AText)
    and not TraceContainsToken(AText);
end;

// Maskiert JSON strukturell: Werte geheimer Schluessel (jeden Typs) werden
// "***"; jeder andere Stringwert wird als Freitext geprueft und notfalls
// ganz durch "***" ersetzt (etwa eine Callback-URL mit code= in
// error_description).
procedure TraceRedactJson(AValue: TJSONValue);

  function RedactString(AString: TJSONValue; out ANew: TJSONValue): Boolean;
  var
    LText: string;
  begin
    ANew := nil;
    if not (AString is TJSONString) then
      Exit(False);
    if not TraceRedactText(TJSONString(AString).Value, LText) then
      LText := '***';
    Result := LText <> TJSONString(AString).Value;
    if Result then
      ANew := TJSONString.Create(LText);
  end;

var
  LPair: TJSONPair;
  LArray: TJSONArray;
  LItems: TArray<TJSONValue>;
  LNew: TJSONValue;
  LChanged: Boolean;
  i: Integer;
begin
  if AValue is TJSONObject then
  begin
    for LPair in TJSONObject(AValue) do
      if TraceIsSecretKey(LPair.JsonString.Value, False) then
        LPair.JsonValue := TJSONString.Create('***')
      else if RedactString(LPair.JsonValue, LNew) then
        LPair.JsonValue := LNew
      else
        TraceRedactJson(LPair.JsonValue);
  end
  else if AValue is TJSONArray then
  begin
    // Array-Elemente lassen sich nicht ersetzen: bei Bedarf neu aufbauen.
    LArray := TJSONArray(AValue);
    SetLength(LItems, LArray.Count);
    LChanged := False;
    for i := 0 to LArray.Count - 1 do
    begin
      if RedactString(LArray.Items[i], LNew) then
      begin
        LItems[i] := LNew;
        LChanged := True;
      end
      else
      begin
        LItems[i] := LArray.Items[i];
        TraceRedactJson(LItems[i]);
      end;
    end;
    if LChanged then
    begin
      for i := LArray.Count - 1 downto 0 do
      begin
        LNew := LArray.Remove(i);
        if LNew <> LItems[i] then
          LNew.Free;
      end;
      for i := 0 to High(LItems) do
        LArray.AddElement(LItems[i]);
    end;
  end;
end;

class function TTRAFFIQXInvoiceAPI.RedactSecrets(const AText: string): string;
var
  LJson: TJSONValue;
  LTrimmed: string;
begin
  Result := AText;
  LTrimmed := Trim(AText);
  if LTrimmed = '' then
    Exit;

  // JSON wird geparst und strukturell maskiert: Der Parser dekodiert
  // \u-Escapes in Schluesseln und Werten, geprueft wird der dekodierte Text.
  LJson := nil;
  try
    LJson := TJSONValue.ParseJSONValue(AText);
  except
    LJson := nil;
  end;
  if LJson <> nil then
  try
    // Ein einzelner String auf oberster Ebene ist Freitext.
    if (LJson is TJSONString) and not TraceRedactText(TJSONString(LJson).Value, LTrimmed) then
      Exit(TRACE_BODY_DROPPED);
    TraceRedactJson(LJson);
    Exit(LJson.ToJSON);
  finally
    LJson.Free;
  end;

  // Sieht nach JSON aus, ist aber nicht lesbar (etwa abgeschnitten): nicht
  // sicher zu maskieren, also weglassen.
  if CharInSet(LTrimmed[1], ['{', '[']) then
    Exit(TRACE_BODY_DROPPED);

  // Sonst (Text, HTML): unveraendert oder ganz weglassen. Das trifft auch
  // harmlose Texte wie "Status code: 401" - lieber zu viel weglassen als ein
  // Token protokollieren.
  if not TraceRedactText(AText, Result) then
    Result := TRACE_BODY_DROPPED;
end;

procedure TTRAFFIQXInvoiceAPI.FireHttpTrace(const ATrace: TTraffiqxHttpTraceEvent;
  const AEntry: TTraffiqxHttpTrace);
begin
  // Ein Fehler im Protokoll darf den eigentlichen Aufruf nie stoeren.
  try
    ATrace(AEntry);
  except
  end;
end;

procedure TraceAddHeader(var AEntry: TTraffiqxHttpTrace; const AName, AValue: string);
begin
  if SameText(AName, 'Authorization') or SameText(AName, 'X-Api-Key')
    or SameText(AName, 'Cookie') or SameText(AName, 'Set-Cookie')
    or SameText(AName, 'Proxy-Authorization') then
    Exit;
  // Ein Header, der ein Token wiedergibt, wird ganz maskiert.
  if TraceContainsToken(AValue) then
    AEntry.Headers := AEntry.Headers + [TNetHeader.Create(AName, '***')]
  else
    AEntry.Headers := AEntry.Headers
      + [TNetHeader.Create(AName, TTRAFFIQXInvoiceAPI.RedactUrl(AValue))];
end;

procedure TTRAFFIQXInvoiceAPI.FillTraceResponse(var AEntry: TTraffiqxHttpTrace;
  const AResponse: IHTTPResponse; ABody: TTraffiqxTraceBody);
var
  LHeader: TNetHeader;
  LWithBody: Boolean;
  LStream: TStream;
  LPos: Int64;
begin
  AEntry.Kind := htkResponse;
  AEntry.Headers := nil;
  AEntry.Body := '';
  AEntry.ErrorMessage := '';
  AEntry.StatusCode := AResponse.StatusCode;
  // Wie Freitext: Token-Form oder geheimer Schluessel vor ":"/"=" -> "***".
  if not TraceRedactText(AResponse.StatusText, AEntry.StatusText) then
    AEntry.StatusText := '***';
  for LHeader in AResponse.Headers do
    TraceAddHeader(AEntry, LHeader.Name, LHeader.Value);

  case ABody of
    tbAlways: LWithBody := True;
    tbOnErrorOrPending: LWithBody := (AResponse.StatusCode >= 400) or (AResponse.StatusCode = 202);
  else
    LWithBody := AResponse.StatusCode >= 400;
  end;
  if not LWithBody then
    Exit;

  // ContentAsString liest den Stream; die Position wird fuer den Aufrufer
  // wiederhergestellt (sonst liest er bei komprimierten Antworten nichts).
  LStream := AResponse.ContentStream;
  LPos := 0;
  if LStream <> nil then
    LPos := LStream.Position;
  try
    try
      AEntry.Body := RedactSecrets(AResponse.ContentAsString(TEncoding.UTF8));
      if Length(AEntry.Body) > TRACE_MAX_BODY_CHARS then
        AEntry.Body := Copy(AEntry.Body, 1, TRACE_MAX_BODY_CHARS)
          + ' ... (gekuerzt, ' + Length(AEntry.Body).ToString + ' Zeichen)';
    except
      on E: Exception do
        AEntry.Body := '(Body nicht lesbar: ' + E.Message + ')';
    end;
  finally
    if LStream <> nil then
      LStream.Position := LPos;
  end;
end;

type
  // Automatische Weiterleitungen fuehren mehrere HTTP-Anfragen in einem
  // Aufruf aus. Jede Zwischenantwort und jede Folgeanfrage wird einzeln
  // gemeldet; die RequestId bekommt dafuer ".1", ".2" usw.
  TTraffiqxRedirectTracer = class
  public
    Api: TTRAFFIQXInvoiceAPI;
    Trace: TTraffiqxHttpTraceEvent;
    BaseRequestId: string;
    Request: TTraffiqxHttpTrace;
    Started: UInt64;
    procedure HandleRedirect(const Sender: TObject; const ARequest: IHTTPRequest;
      const AResponse: IHTTPResponse; ARedirections: Integer; var AAllow: Boolean);
  end;

procedure TTraffiqxRedirectTracer.HandleRedirect(const Sender: TObject;
  const ARequest: IHTTPRequest; const AResponse: IHTTPResponse;
  ARedirections: Integer; var AAllow: Boolean);
var
  LEntry: TTraffiqxHttpTrace;
  LToGet: Boolean;
  LWithGet: THTTPRedirectsWithGET;
  LHeaders: TNetHeaders;
  LHeader: TNetHeader;
begin
  LEntry := Request;
  Api.FillTraceResponse(LEntry, AResponse, tbOnError);
  LEntry.TimestampUtc := TDateTime.NowUTC;
  LEntry.DurationMs := TThread.GetTickCount64 - Started;
  Api.FireHttpTrace(Trace, LEntry);

  // Folgeanfrage so, wie die RTL sie baut: Location relativ zur bisherigen
  // URL, POST je nach RedirectsWithGET als GET ohne Inhaltsheader. Die
  // Bibliothek sendet nur GET und POST.
  Request.RequestId := BaseRequestId + '.' + ARedirections.ToString;
  try
    Request.Url := TTRAFFIQXInvoiceAPI.RedactUrl(
      TURI.PathRelativeToAbs(AResponse.HeaderValue['Location'], ARequest.URL));
  except
    Request.Url := TTRAFFIQXInvoiceAPI.RedactUrl(AResponse.HeaderValue['Location']);
  end;

  LToGet := False;
  if SameText(Request.Method, 'POST') and (Sender is TNetHTTPClient) then
  begin
    LWithGet := TNetHTTPClient(Sender).RedirectsWithGET;
    case AResponse.StatusCode of
      301: LToGet := THTTPRedirectWithGET.Post301 in LWithGet;
      302: LToGet := THTTPRedirectWithGET.Post302 in LWithGet;
      303: LToGet := THTTPRedirectWithGET.Post303 in LWithGet;
      307: LToGet := THTTPRedirectWithGET.Post307 in LWithGet;
      308: LToGet := THTTPRedirectWithGET.Post308 in LWithGet;
    end;
  end;
  if LToGet then
  begin
    Request.Method := 'GET';
    LHeaders := nil;
    for LHeader in Request.Headers do
      if not SameText(LHeader.Name, 'Content-Type') and not SameText(LHeader.Name, 'Content-Length') then
        LHeaders := LHeaders + [LHeader];
    Request.Headers := LHeaders;
  end;

  Request.TimestampUtc := TDateTime.NowUTC;
  Api.FireHttpTrace(Trace, Request);
  Started := TThread.GetTickCount64;
end;

function TTRAFFIQXInvoiceAPI.TraceExecute(AClient: TNetHTTPClient;
  const AMethod, AUrl: string; const AHeaders: TNetHeaders;
  ABody: TTraffiqxTraceBody; const ASend: TFunc<IHTTPResponse>): IHTTPResponse;
var
  LTrace: TTraffiqxHttpTraceEvent;
  LTracer: TTraffiqxRedirectTracer;
  LEntry: TTraffiqxHttpTrace;
  LHeader: TNetHeader;
  LGuid: TGUID;
  LOldRedirect: THTTPRedirectEvent;
begin
  // Den Handler genau einmal lesen: Anfrage und Antwort gehen an denselben
  // Empfaenger, auch wenn OnHttpTrace waehrenddessen umgesetzt wird.
  LTrace := FOnHttpTrace;
  if not Assigned(LTrace) then
    Exit(ASend());

  LTracer := TTraffiqxRedirectTracer.Create;
  try
    LEntry := Default(TTraffiqxHttpTrace);
    CreateGUID(LGuid);
    LEntry.RequestId := LowerCase(Copy(GUIDToString(LGuid), 2, 13));
    LEntry.Kind := htkRequest;
    LEntry.Method := AMethod;
    LEntry.Url := RedactUrl(AUrl);
    for LHeader in AClient.CustHeaders do
      TraceAddHeader(LEntry, LHeader.Name, LHeader.Value);
    for LHeader in AHeaders do
      TraceAddHeader(LEntry, LHeader.Name, LHeader.Value);
    LEntry.TimestampUtc := TDateTime.NowUTC;
    FireHttpTrace(LTrace, LEntry);

    LTracer.Api := Self;
    LTracer.Trace := LTrace;
    LTracer.BaseRequestId := LEntry.RequestId;
    LTracer.Request := LEntry;
    LTracer.Started := TThread.GetTickCount64;

    LOldRedirect := AClient.OnRedirect;
    AClient.OnRedirect := LTracer.HandleRedirect;
    try
      try
        Result := ASend();
      except
        on E: Exception do
        begin
          LEntry := LTracer.Request;
          LEntry.Kind := htkResponse;
          LEntry.Headers := nil;
          LEntry.TimestampUtc := TDateTime.NowUTC;
          LEntry.DurationMs := TThread.GetTickCount64 - LTracer.Started;
          if TraceContainsToken(E.Message) then
            LEntry.ErrorMessage := E.ClassName
              + ': (Meldung nicht protokolliert: enthaelt moeglicherweise Tokens)'
          else
            LEntry.ErrorMessage := RedactUrl(E.ClassName + ': ' + E.Message);
          FireHttpTrace(LTrace, LEntry);
          raise;
        end;
      end;
    finally
      AClient.OnRedirect := LOldRedirect;
    end;

    LEntry := LTracer.Request;
    if Result <> nil then
      FillTraceResponse(LEntry, Result, ABody)
    else
    begin
      LEntry.Kind := htkResponse;
      LEntry.Headers := nil;
    end;
    LEntry.TimestampUtc := TDateTime.NowUTC;
    LEntry.DurationMs := TThread.GetTickCount64 - LTracer.Started;
    FireHttpTrace(LTrace, LEntry);
  finally
    LTracer.Free;
  end;
end;

function TTRAFFIQXInvoiceAPI.HttpGet(AClient: TNetHTTPClient; const AUrl: string;
  AContent: TStream; const AHeaders: TNetHeaders; ABody: TTraffiqxTraceBody): IHTTPResponse;
begin
  Result := TraceExecute(AClient, 'GET', AUrl, AHeaders, ABody,
    function: IHTTPResponse
    begin
      Result := AClient.Get(AUrl, AContent, AHeaders);
    end);
end;

function TTRAFFIQXInvoiceAPI.HttpPost(AClient: TNetHTTPClient; const AUrl: string;
  ASource: TStream; const AHeaders: TNetHeaders; ABody: TTraffiqxTraceBody): IHTTPResponse;
begin
  Result := TraceExecute(AClient, 'POST', AUrl, AHeaders, ABody,
    function: IHTTPResponse
    begin
      Result := AClient.Post(AUrl, ASource, nil, AHeaders);
    end);
end;

function TTRAFFIQXInvoiceAPI.HttpPostForm(AClient: TNetHTTPClient; const AUrl: string;
  AForm: TMultipartFormData; ABody: TTraffiqxTraceBody): IHTTPResponse;
begin
  // Den Content-Type mit Boundary setzt die RTL erst beim Senden; fuer das
  // Protokoll wird er hier vorab eingetragen.
  Result := TraceExecute(AClient, 'POST', AUrl,
    [TNetHeader.Create('Content-Type', AForm.MimeTypeHeader)], ABody,
    function: IHTTPResponse
    begin
      Result := AClient.Post(AUrl, AForm);
    end);
end;

function TTRAFFIQXInvoiceAPI.StartAuth: Boolean;
var
  LSessionId: string;
  LStartUrl: string;
  LPayload: string;
  LHttpClient: TNetHTTPClient;
  LHeaders: TNetHeaders;
  LResponse: IHTTPResponse;
  LBody: TStringStream;
  LLocation: string;

  function GenerateSessionId: string;
  var
    LGUID: TGUID;
    LValue: string;
  begin
    CreateGUID(LGUID);
    LValue := GUIDToString(LGUID);
    LValue := StringReplace(LValue, '{', '', [rfReplaceAll]);
    LValue := StringReplace(LValue, '}', '', [rfReplaceAll]);
    Result := LowerCase(LValue);
  end;

  function BuildStartPayload(const ASessionId: string): string;
  var
    LPayload, LExtra: TJSONObject;
    LScope: string;
  begin
    LPayload := TJSONObject.Create;
    try
      LScope := FScope;
      if LScope = '' then
        raise Exception.Create('Scope ist nicht konfiguriert.');

      LPayload.AddPair('sessionId', ASessionId);
      LPayload.AddPair('providerClientId', FClientId);
      LPayload.AddPair('providerClientSecret', FClientSecret);
      LPayload.AddPair('providerRedirectUri', FOAuth2BrokerCallbackUri);
      LPayload.AddPair('providerAuthorizationUri', FOAuthUri);
      LPayload.AddPair('providerAccessTokenUri', FAccessTokenUri);
      LPayload.AddPair('providerScope', LScope);
      LPayload.AddPair('providerTenantOrAccountId', FTRAFFIQXId);
      LPayload.AddPair('providerApiBaseUrl', FApiBaseUri);

      LExtra := TJSONObject.Create;
      if not (FProviderType in [tpDatev,tpDatevSmartTransfer]) then
        LExtra.AddPair('enableWindowsSso', 'true');
      // applicationDisplayName wird vom Broker im Autorisierungs-Flow nicht
      // weitergereicht; fuer DATEV-API-Calls dient der Header X-App-Display-Name.
      LPayload.AddPair('extraParams', LExtra);

      Result := LPayload.ToJSON;
    finally
      LPayload.Free;
    end;
  end;

begin
  Result := False;

  if (FOAuthUri = '') or (FApiBaseUri = '') or (FAccessTokenUri = '') then
    Exit;
  if (FClientId = '') or (FClientSecret = '') or (FTRAFFIQXId = '') then
    Exit;
  if (FOAuth2BrokerCallbackUri = '') or (FOAuth2BrokerApiKey = '') then
    Exit;

  FAccessToken := '';
  FRefreshToken := '';
  FAccessTokenExpiresAt := 0;
  FRefreshTokenExpiresAt := 0;
  FCurrentSessionId := '';

  try
    LSessionId := GenerateSessionId;
    LStartUrl := BuildBrokerEndpoint('start');
    if LStartUrl = '' then
      Exit;

    LPayload := BuildStartPayload(LSessionId);

    LHttpClient := TNetHTTPClient.Create(nil);
    try
      LHttpClient.HandleRedirects := False;

      LBody := TStringStream.Create(LPayload, TEncoding.UTF8);
      try
        SetLength(LHeaders, 2);
        LHeaders[0] := TNameValuePair.Create('Content-Type', 'application/json');
        LHeaders[1] := TNameValuePair.Create('X-Api-Key', FOAuth2BrokerApiKey);

        LResponse := HttpPost(LHttpClient, LStartUrl, LBody, LHeaders, tbOnError);
      finally
        LBody.Free;
      end;

      // Fehlerkoerper des Brokers fuer die Diagnose ueber LastRawContentReceived
      // bereitstellen und den Grund nicht stillschweigend verschlucken.
      if (LResponse.StatusCode < 200) or (LResponse.StatusCode >= 400) then
      begin
        FLastRawContentReceived := LResponse.ContentAsString(TEncoding.UTF8);
        raise Exception.Create('Broker /start fehlgeschlagen (HTTP '
          + LResponse.StatusCode.ToString + '): ' + FLastRawContentReceived);
      end;

      LLocation := LResponse.HeaderValue['Location'];
      if LLocation = '' then
        raise Exception.Create('Broker /start lieferte keinen Location-Header.');

      // Ist ein OpenAuthUrl-Hook gesetzt (z.B. eingebettetes WebView2-Fenster),
      // wird die URL dorthin uebergeben statt im externen Browser geoeffnet.
      if Assigned(FOnOpenAuthUrl) then
      begin
        FCurrentSessionId := LSessionId;
        Result := True;
        FOnOpenAuthUrl(LLocation);
      end
      else if ShellExecute(0, 'open', PChar(LLocation), nil, nil, SW_SHOWNORMAL) > 32 then
      begin
        FCurrentSessionId := LSessionId;
        Result := True;
      end;
    finally
      LHttpClient.Free;
    end;
  except
    on E: Exception do
    begin
      OutputDebugString(PChar('StartAuth failed: ' + E.Message));
      Result := False;
    end;
  end;
end;

// Startet das Polling auf den Broker asynchron und liefert ein Future zur Auswertung.
function TTRAFFIQXInvoiceAPI.BeginPolling(const AIntervalMs,
  ATimeoutMs: Cardinal): IFuture<TTraffiqxPollResult>;
var
  LPollUrl: string;
  LSessionId: string;
  LApiKey: string;
  LActiveFuture: IFuture<TTraffiqxPollResult>;
begin
  if FCurrentSessionId = '' then
    raise Exception.Create('Es existiert keine aktive Session zum Polling.');
  if FOAuth2BrokerApiKey = '' then
    raise Exception.Create('API-Key ist nicht gesetzt.');
  if AIntervalMs = 0 then
    raise Exception.Create('Polling-Intervall darf nicht 0 sein.');

  LPollUrl := BuildBrokerEndpoint('poll');
  if LPollUrl = '' then
    raise Exception.Create('Poll-Endpunkt konnte nicht ermittelt werden.');

  LSessionId := FCurrentSessionId;
  LApiKey := FOAuth2BrokerApiKey;

  CancelPolling;
  TInterlocked.Exchange(FPollCancelFlag, 0);

  Result := TTask.Future<TTraffiqxPollResult>(
    function: TTraffiqxPollResult
    var
      LHttpClient: TNetHTTPClient;
      LHeaders: TNetHeaders;
      LResponse: IHTTPResponse;
      LJson: TJSONObject;
      LStatus: string;
      LTokens: TJSONObject;
      LAccessToken, LRefreshToken: string;
      LAccessTokenExpiresAt, LRefreshTokenExpiresAt : TDateTime;
      LAccessTokenExpiresAtUtc, LRefreshTokenExpiresAtUtc : TDateTime;
      LPollResult: TTraffiqxPollResult;
      LExpiresAtStr: string;
      LRefreshExpiresAtStr: string;
      LErrorObj: TJSONObject;
      LErrorCode, LErrorDescription: string;
      LPollUri: string;
      LStartTick: UInt64;
      LElapsed: UInt64;
    begin
      Result := TTraffiqxPollResult.Pending;
      LHttpClient := TNetHTTPClient.Create(nil);
      try
        SetLength(LHeaders, 1);
        LHeaders[0] := TNameValuePair.Create('X-Api-Key', LApiKey);
        LPollUri := LPollUrl + '?sessionId=' + TNetEncoding.URL.Encode(LSessionId);
        LStartTick := TThread.GetTickCount64;

        while True do
        begin
          if (TInterlocked.CompareExchange(FPollCancelFlag, 0, 0) <> 0) then
            Exit(TTraffiqxPollResult.Cancelled);

          if ATimeoutMs > 0 then
          begin
            LElapsed := TThread.GetTickCount64 - LStartTick;
            if LElapsed >= ATimeoutMs then
              Exit(TTraffiqxPollResult.Timeout);
          end;

          try
            LResponse := HttpGet(LHttpClient, LPollUri, nil, LHeaders, tbOnError);
          except
            on E: Exception do
            begin
              Result := TTraffiqxPollResult.Fail('transport_error', E.Message);
              Exit(Result);
            end;
          end;

          if (LResponse.StatusCode < 200) or (LResponse.StatusCode >= 400) then
            Exit(TTraffiqxPollResult.Fail(
              'http_' + LResponse.StatusCode.ToString,
              LResponse.ContentAsString(TEncoding.UTF8)));

          LJson := TJSONObject.ParseJSONValue(
            LResponse.ContentAsString(TEncoding.UTF8)) as TJSONObject;
          try
            if LJson = nil then
              Exit(TTraffiqxPollResult.Fail('invalid_json', 'Antwort konnte nicht gelesen werden.'));

            if not LJson.TryGetValue<string>('status', LStatus) then
              LStatus := '';

            if SameText(LStatus, 'pending') then
            begin
              TThread.Sleep(AIntervalMs);
              Continue;
            end;

            if SameText(LStatus, 'success') then
            begin
              LTokens := LJson.Values['tokens'] as TJSONObject;
              LAccessToken := '';
              LRefreshToken := '';
              LAccessTokenExpiresAt := 0;
              LRefreshTokenExpiresAt := 0;
              LAccessTokenExpiresAtUtc := 0;
              LRefreshTokenExpiresAtUtc := 0;
              LExpiresAtStr := '';
              LRefreshExpiresAtStr := '';
              if LTokens <> nil then
              begin
                LTokens.TryGetValue<string>('accessToken', LAccessToken);
                LTokens.TryGetValue<string>('refreshToken', LRefreshToken);
                if LTokens.TryGetValue<string>('expiresAt', LExpiresAtStr) then
                begin
                  TryISO8601ToDate(LExpiresAtStr, LAccessTokenExpiresAt, False);
                  if not TryISO8601ToDate(LExpiresAtStr, LAccessTokenExpiresAtUtc, True) then
                    LAccessTokenExpiresAtUtc := 0;
                end;
                if LTokens.TryGetValue<string>('refreshTokenExpiresAt', LRefreshExpiresAtStr) then
                begin
                  TryISO8601ToDate(LRefreshExpiresAtStr, LRefreshTokenExpiresAt, False);
                  if not TryISO8601ToDate(LRefreshExpiresAtStr, LRefreshTokenExpiresAtUtc, True) then
                    LRefreshTokenExpiresAtUtc := 0;
                end;
              end;

              if LAccessToken = '' then
                Exit(TTraffiqxPollResult.Fail('missing_access_token', 'Antwort enthält kein access_token.'));

              // DATEV liefert die Laufzeit des Refresh-Tokens nicht mit. Sie
              // zaehlt ab der Anmeldung, also ab jetzt.
              if (LRefreshToken <> '') and (LRefreshTokenExpiresAt = 0) then
              begin
                LRefreshTokenExpiresAt := DefaultRefreshTokenExpiresAt(Now);
                LRefreshTokenExpiresAtUtc := DefaultRefreshTokenExpiresAt(TDateTime.NowUTC);
              end;

              TMonitor.Enter(Self);
              try
                FAccessToken := LAccessToken;
                FRefreshToken := LRefreshToken;
                FAccessTokenExpiresAt := LAccessTokenExpiresAt;
                FRefreshTokenExpiresAt := LRefreshTokenExpiresAt;
                FCurrentSessionId := '';
              finally
                TMonitor.Exit(Self);
              end;

              LPollResult := TTraffiqxPollResult.Success(LAccessToken, LRefreshToken, LAccessTokenExpiresAt, LRefreshTokenExpiresAt);
              LPollResult.AccessTokenExpiresAtUtc := LAccessTokenExpiresAtUtc;
              LPollResult.RefreshTokenExpiresAtUtc := LRefreshTokenExpiresAtUtc;
              Exit(LPollResult);
            end;

            if SameText(LStatus, 'error') then
            begin
              LErrorObj := LJson.Values['error'] as TJSONObject;
              if LErrorObj <> nil then
              begin
                if not LErrorObj.TryGetValue<string>('code', LErrorCode) then
                  LErrorCode := 'poll_error';
                if not LErrorObj.TryGetValue<string>('description', LErrorDescription) then
                  LErrorDescription := 'Unbekannter Fehler.';
                TMonitor.Enter(Self);
                try
                  FCurrentSessionId := '';
                finally
                  TMonitor.Exit(Self);
                end;
                Exit(TTraffiqxPollResult.Fail(LErrorCode, LErrorDescription));
              end
              else
              begin
                TMonitor.Enter(Self);
                try
                  FCurrentSessionId := '';
                finally
                  TMonitor.Exit(Self);
                end;
                Exit(TTraffiqxPollResult.Fail('poll_error', 'Provider meldete einen Fehler.'));
              end;
            end;

            Exit(TTraffiqxPollResult.Fail('unknown_status', 'Status: ' + LStatus));
          finally
            LJson.Free;
          end;
        end;
      finally
        LHttpClient.Free;
      end;
    end);

  FPollFuture := Result;
  LActiveFuture := Result;

  TThread.CreateAnonymousThread(
    procedure
    var
      LPollResult: TTraffiqxPollResult;
    begin
      try
        LPollResult := LActiveFuture.Value;
      except
        on E: EOperationCancelled do
          LPollResult := TTraffiqxPollResult.Cancelled;
        on E: Exception do
          LPollResult := TTraffiqxPollResult.Fail('poll_future_error', E.Message);
      end;

      TMonitor.Enter(Self);
      try
        if FPollFuture = LActiveFuture then
          FPollFuture := nil;
      finally
        TMonitor.Exit(Self);
      end;

      if not Assigned(FOnPollingCompleted) then
        Exit;

      TThread.Queue(nil,
        procedure
        begin
          if Assigned(FOnPollingCompleted) then
            FOnPollingCompleted(LPollResult,self);
        end);
    end).Start;
end;

function TTRAFFIQXInvoiceAPI.RefreshAccessToken : Boolean;//(const _RefreshToken: String;
//  out _NewAccessToken, _NewRefreshToken: String): Boolean;
var
  HttpClient: TNetHTTPClient;
  RequestStream: TStringStream;
  Response: IHTTPResponse;
  ResponseJSON: TJSONObject;
  Headers: TNetHeaders;
  Base64NoBreaks: TBase64Encoding;
  LResponseText: string;

  function BuildFormBody: string;
  begin
    Result := 'grant_type=refresh_token'
      + '&refresh_token=' + TNetEncoding.URL.Encode(FRefreshToken);

    // Wenn kein ClientSecret hinterlegt ist, muessen wir client_id im Body mitsenden
    if FClientSecret = '' then
      Result := Result + '&client_id=' + TNetEncoding.URL.Encode(FClientId);
  end;

  function BuildRefreshTokenExpiredMessage(const AExpiredAt: TDateTime): string;
  begin
    if AExpiredAt > 0 then
      Result := 'Das Refresh-Token ist abgelaufen (gültig bis ' + DateTimeToStr(AExpiredAt)
        + '). DATEV-Refresh-Tokens gelten ab der Anmeldung 11 Stunden, mit offline_access 6 Monate. '
        + 'Bitte die Anmeldung erneut durchführen.'
    else
      Result := 'Das Refresh-Token ist nicht mehr gültig. DATEV-Refresh-Tokens gelten ab der Anmeldung '
        + '11 Stunden, mit offline_access 6 Monate, und sind Single-Use. Bitte die Anmeldung erneut durchführen.';
  end;

  function BuildRefreshErrorMessage(const AResponseText: string): string;
  var
    LJson: TJSONObject;
    LErrorCode: string;
    LErrorDescription: string;
  begin
    Result := 'Fehler beim Abrufen des Access Tokens: ' + AResponseText;

    LJson := TJSONObject.ParseJSONValue(AResponseText) as TJSONObject;
    if LJson = nil then
      Exit;
    try
      LErrorCode := '';
      LErrorDescription := '';
      LJson.TryGetValue<string>('error', LErrorCode);
      LJson.TryGetValue<string>('error_description', LErrorDescription);

      if SameText(LErrorCode, 'invalid_grant') then
      begin
        if (FRefreshTokenExpiresAt > 0) and (FRefreshTokenExpiresAt <= Now) then
          Exit(BuildRefreshTokenExpiredMessage(FRefreshTokenExpiresAt));

        if (FProviderType in [tpDatev,tpDatevSmartTransfer]) then
        begin
          Result := 'Das Refresh-Token ist laut DATEV nicht mehr gültig (`invalid_grant`). '
            + 'Mögliche Ursachen sind: Ablauf der Laufzeit ab Anmeldung (11 Stunden, mit offline_access 6 Monate), '
            + 'bereits erfolgte Verwendung des Single-Use-Refresh-Tokens oder ein inzwischen '
            + 'ersetztes Refresh-Token. Bitte die Anmeldung erneut durchführen.';

          if LErrorDescription <> '' then
            Result := Result + ' Provider-Detail: ' + LErrorDescription;
          Exit;
        end;
      end;
    finally
      LJson.Free;
    end;
  end;
begin
  Result := false;

  if FRefreshToken = '' then
    raise Exception.Create('Es ist kein Refresh-Token vorhanden. Bitte die Anmeldung erneut durchführen.');

  if (FRefreshTokenExpiresAt > 0) and (FRefreshTokenExpiresAt <= Now) then
    raise Exception.Create(BuildRefreshTokenExpiredMessage(FRefreshTokenExpiresAt));

  HttpClient := TNetHTTPClient.Create(nil);
  RequestStream := TStringStream.Create('', TEncoding.UTF8);
  Base64NoBreaks := TBase64Encoding.Create(0);
  ResponseJSON := nil;
  try
    // DATEV erwartet Basic Auth fuer den Token-Endpoint
    if FClientSecret <> '' then
      HttpClient.CustomHeaders['Authorization'] := 'Basic '
        + Base64NoBreaks.Encode(FClientId + ':' + FClientSecret);

    RequestStream.Size := 0;
    RequestStream.Position := 0;
    RequestStream.WriteString(BuildFormBody);
    RequestStream.Position := 0;

    SetLength(Headers, 1);
    Headers[0] := TNameValuePair.Create('Content-Type', 'application/x-www-form-urlencoded');

    Response := HttpPost(HttpClient, FAccessTokenUri, RequestStream, Headers, tbOnError);
    LResponseText := Response.ContentAsString(TEncoding.UTF8);

    // Überprüfe den HTTP-Statuscode
    if Response.StatusCode = 200 then
    begin
      // Parse die JSON-Antwort
      ResponseJSON := TJSONObject.ParseJSONValue(LResponseText) as TJSONObject;
      if ResponseJSON = nil then
        raise Exception.Create('Antwort des Token-Endpoints konnte nicht als JSON gelesen werden: ' + LResponseText);

      // Sicher auslesen
      if ResponseJSON.TryGetValue<string>('access_token', FAccessToken)
         and ResponseJSON.TryGetValue<string>('refresh_token', FRefreshToken) then
      begin
        var LExpiresIn: Integer := 0;
        var LRefreshExpiresIn: Integer := 0;
        ResponseJSON.TryGetValue<Integer>('expires_in', LExpiresIn);
        ResponseJSON.TryGetValue<Integer>('refresh_expires_in', LRefreshExpiresIn);
        if LExpiresIn > 0 then
          FAccessTokenExpiresAt := IncSecond(Now, LExpiresIn)
        else
          FAccessTokenExpiresAt := 0;
        // Laut DATEV behaelt das neue Refresh-Token die urspruengliche Laufzeit
        // seit der Anmeldung. Ohne refresh_expires_in bleibt das beim Login
        // ermittelte Ablaufdatum deshalb unveraendert - auch ein unbekanntes
        // (0): Anmeldezeitpunkt und gewaehrter Scope sind dann nicht bekannt,
        // eine Schaetzung ab "jetzt" waere zu lang. Klaerung per Introspection.
        if LRefreshExpiresIn > 0 then
          FRefreshTokenExpiresAt := IncSecond(Now, LRefreshExpiresIn);
        Result := True;
      end;
    end
    else
      raise Exception.Create(BuildRefreshErrorMessage(LResponseText));

      //400 {"error":"invalid_grant","error_description":"Maximum allowed refresh token reuse exceeded"}

  finally
    ResponseJSON.Free;
    Base64NoBreaks.Free;
    RequestStream.Free;
    HttpClient.Free;
  end;
end;

function TTRAFFIQXInvoiceAPI.DownloadInboxDocument(const ADocumentId: string;
  out AContent: TMemoryStream; out AError: TTraffiqxError): Boolean;
var
  HttpClient: TNetHTTPClient;
  Response: IHTTPResponse;
  lUrl: string;
  lJSONValue: TJSONValue;
begin
  AContent := nil;
  AError := nil;
  Result := False;
  lJSONValue := nil;

  if (FApiBaseUri = '') or (FTRAFFIQXId = '') or (FAccessToken = '') or (FClientId = '') then
  begin
    AError := MakeError('#LOCAL', 0, 'Ungültige oder fehlende Konfiguration.');
    Exit;
  end;

  if (FProviderType in [tpDatev,tpDatevSmartTransfer]) and (FAppDisplayName = '') then
  begin
    AError := MakeError('#LOCAL', 0, 'Fehlender App-Display-Name.');
    Exit;
  end;

  if ADocumentId = '' then
  begin
    AError := MakeError('#LOCAL', 0, 'DocumentId darf nicht leer sein.');
    Exit;
  end;

  HttpClient := TNetHTTPClient.Create(nil);
  try
    HttpClient.CustomHeaders['Authorization'] := 'Bearer ' + FAccessToken;
    if (FProviderType in [tpDatev,tpDatevSmartTransfer]) then
      HttpClient.CustomHeaders['X-Datev-Client-ID'] := FClientId
    else
      HttpClient.CustomHeaders['X-traffiqx-Client-ID'] := FClientId;
    if (FProviderType in [tpDatev,tpDatevSmartTransfer]) and (FAppDisplayName <> '') then
      HttpClient.CustomHeaders['X-App-Display-Name'] := FAppDisplayName;

    lUrl := FApiBaseUri + ifthen(FApiBaseUri.EndsWith('/'), '', '/')
      + 'traffiqx-clients/' + TNetEncoding.URL.Encode(FTRAFFIQXId)
      + '/inbox-documents/' + TNetEncoding.URL.Encode(ADocumentId);

    AContent := TMemoryStream.Create;
    try
      try
        Response := HttpGet(HttpClient, lUrl, AContent, nil, tbOnError);
      except
        on E: Exception do
        begin
          AError := MakeError('#TRANSPORT', 0, E.Message);
          FreeAndNil(AContent);
          Exit;
        end;
      end;

      if Response.StatusCode <> 200 then
      begin
        AContent.Clear;
        AContent.Size := 0;
        if ContainsText(Response.HeaderValue['Content-Type'], 'application/problem+json') then
        begin
          lJSONValue := TJSONObject.ParseJSONValue(Response.ContentAsString(TEncoding.UTF8));
          if lJSONValue is TJSONObject then
            AError := TTraffiqxError.FromJson(TJSONObject(lJSONValue));
        end
        else
          AError := MakeError('#HTTP' + Response.StatusCode.ToString,
            Response.StatusCode, Response.ContentAsString(TEncoding.UTF8));

        if AError = nil then
          AError := MakeError('#HTTP' + Response.StatusCode.ToString,
            Response.StatusCode, Response.ContentAsString(TEncoding.UTF8));
        FreeAndNil(AContent);
        Exit;
      end;

      AContent.Position := 0;
      Result := True;
    except
      on E: Exception do
      begin
        FreeAndNil(AContent);
        AError := MakeError('#STREAM', 0, E.Message);
      end;
    end;
  finally
    lJSONValue.Free;
    HttpClient.Free;
  end;
end;

function TTRAFFIQXInvoiceAPI.GetInboxDocumentMetadata(const ADocumentId: string;
  out AMetadata: TTraffiqxInboxDocumentMetadata; out AError: TTraffiqxError): Boolean;
var
  HttpClient: TNetHTTPClient;
  Response: IHTTPResponse;
  lUrl: string;
  lJSONValue: TJSONValue;
begin
  AMetadata := nil;
  AError := nil;
  Result := False;

  if (FApiBaseUri = '') or (FTRAFFIQXId = '') or (FAccessToken = '') or (FClientId = '') then
  begin
    AError := MakeError('#LOCAL', 0, 'Ungültige oder fehlende Konfiguration.');
    Exit;
  end;

  if (FProviderType in [tpDatev,tpDatevSmartTransfer]) and (FAppDisplayName = '') then
  begin
    AError := MakeError('#LOCAL', 0, 'Fehlender App-Display-Name.');
    Exit;
  end;

  if ADocumentId = '' then
  begin
    AError := MakeError('#LOCAL', 0, 'DocumentId darf nicht leer sein.');
    Exit;
  end;

  HttpClient := TNetHTTPClient.Create(nil);
  lJSONValue := nil;
  try
    HttpClient.CustomHeaders['Authorization'] := 'Bearer ' + FAccessToken;
    if (FProviderType in [tpDatev,tpDatevSmartTransfer]) then
      HttpClient.CustomHeaders['X-Datev-Client-ID'] := FClientId
    else
      HttpClient.CustomHeaders['X-traffiqx-Client-ID'] := FClientId;
    if (FProviderType in [tpDatev,tpDatevSmartTransfer]) and (FAppDisplayName <> '') then
      HttpClient.CustomHeaders['X-App-Display-Name'] := FAppDisplayName;

    lUrl := FApiBaseUri + ifthen(FApiBaseUri.EndsWith('/'), '', '/')
      + 'traffiqx-clients/' + TNetEncoding.URL.Encode(FTRAFFIQXId)
      + '/inbox-documents/' + TNetEncoding.URL.Encode(ADocumentId)
      + '/metadata';

    try
      Response := HttpGet(HttpClient, lUrl, nil, nil, tbOnError);
    except
      on E: Exception do
      begin
        AError := MakeError('#TRANSPORT', 0, E.Message);
        Exit;
      end;
    end;

    if Response.StatusCode <> 200 then
    begin
      lJSONValue := TJSONObject.ParseJSONValue(Response.ContentAsString(TEncoding.UTF8));
      if lJSONValue is TJSONObject then
        AError := TTraffiqxError.FromJson(TJSONObject(lJSONValue))
      else
        AError := MakeError('#HTTP' + Response.StatusCode.ToString,
          Response.StatusCode, Response.ContentAsString(TEncoding.UTF8));
      Exit;
    end;

    lJSONValue := TJSONObject.ParseJSONValue(Response.ContentAsString(TEncoding.UTF8));
    if lJSONValue is TJSONObject then
    begin
      AMetadata := TTraffiqxInboxDocumentMetadata.FromJson(TJSONObject(lJSONValue));
      Result := True;
    end
    else
      AError := MakeError('#PARSE', 0, 'Antwort enthält kein JSON-Objekt.');
  finally
    lJSONValue.Free;
    HttpClient.Free;
  end;
end;

function TTRAFFIQXInvoiceAPI.GetInboxDocumentIds(out ADocuments: TTraffiqxInboxDocumentList;
  out AError: TTraffiqxError; const AUseDownloadedFilter: Boolean;
  const ADownloaded: Boolean; const AFromDate, AToDate: TDateTime): Boolean;
var
  HttpClient: TNetHTTPClient;
  Response: IHTTPResponse;
  lQuery: TStringBuilder;
  lUrl: string;
  lJSONValue: TJSONValue;
  lArray: TJSONArray;
  lItem: TJSONValue;
  lObj: TJSONObject;

  procedure AddQueryParam(const AName, AValue: string);
  begin
    if AValue = '' then
      Exit;

    if lQuery.Length > 0 then
      lQuery.Append('&');

    lQuery.Append(AName);
    lQuery.Append('=');
    lQuery.Append(TNetEncoding.URL.Encode(AValue));
  end;

  function FormatIso8601Utc(const ADate: TDateTime): string;
  var
    LUtc: TDateTime;
  begin
    if ADate = 0 then
      Exit('');

    LUtc := TTimeZone.Local.ToUniversalTime(ADate);
    Result := FormatDateTime('yyyy"-"mm"-"dd"T"HH":"nn":"ss"Z"', LUtc);
  end;

begin
  ADocuments := nil;
  AError := nil;
  Result := False;

  if (FApiBaseUri = '') or (FTRAFFIQXId = '') or (FAccessToken = '') or (FClientId = '') then
  begin
    AError := MakeError('#LOCAL', 0, 'Ungültige oder fehlende Konfiguration.');
    Exit;
  end;

  if (FProviderType in [tpDatev,tpDatevSmartTransfer]) and (FAppDisplayName = '') then
  begin
    AError := MakeError('#LOCAL', 0, 'Fehlender App-Display-Name.');
    Exit;
  end;

  HttpClient := TNetHTTPClient.Create(nil);
  lQuery := TStringBuilder.Create;
  lJSONValue := nil;
  try
    HttpClient.CustomHeaders['Authorization'] := 'Bearer ' + FAccessToken;
    if (FProviderType in [tpDatev,tpDatevSmartTransfer]) then
      HttpClient.CustomHeaders['X-Datev-Client-ID'] := FClientId
    else
      HttpClient.CustomHeaders['X-traffiqx-Client-ID'] := FClientId;
    if (FProviderType in [tpDatev,tpDatevSmartTransfer]) and (FAppDisplayName <> '') then
      HttpClient.CustomHeaders['X-App-Display-Name'] := FAppDisplayName;

    if AUseDownloadedFilter then
      AddQueryParam('downloaded', LowerCase(BoolToStr(ADownloaded, True)));
    if AFromDate > 100 then
      AddQueryParam('from_date', FormatIso8601Utc(AFromDate));
    if AToDate > 100 then
      AddQueryParam('to_date', FormatIso8601Utc(AToDate));

    lUrl := BuildInboxBase;
    if lQuery.Length > 0 then
      lUrl := lUrl + '?' + lQuery.ToString;

    try
      Response := HttpGet(HttpClient, lUrl, nil, nil, tbOnError);
    except
      on E: Exception do
      begin
        AError := MakeError('#TRANSPORT', 0, E.Message);
        Exit;
      end;
    end;

    if Response.StatusCode <> 200 then
    begin
      lJSONValue := TJSONObject.ParseJSONValue(Response.ContentAsString(TEncoding.UTF8));
      if lJSONValue is TJSONObject then
        AError := TTraffiqxError.FromJson(TJSONObject(lJSONValue))
      else
        AError := MakeError('#HTTP' + Response.StatusCode.ToString,
          Response.StatusCode, Response.ContentAsString(TEncoding.UTF8));
      Exit;
    end;

    lJSONValue := TJSONObject.ParseJSONValue(Response.ContentAsString(TEncoding.UTF8));
    if lJSONValue is TJSONArray then
    begin
      lArray := TJSONArray(lJSONValue);
      ADocuments := TTraffiqxInboxDocumentList.Create(True);
      for lItem in lArray do
      begin
        if lItem is TJSONObject then
        begin
          lObj := TJSONObject(lItem);
          ADocuments.Add(TTraffiqxInboxDocument.FromJson(lObj));
        end;
      end;
      Result := True;
    end
    else
      AError := MakeError('#PARSE', 0, 'Antwort enthält kein JSON-Array.');
  finally
    lJSONValue.Free;
    lQuery.Free;
    HttpClient.Free;
  end;
end;

function TTRAFFIQXInvoiceAPI.UploadZugferdData(const AData: TStream; const ADataFileName: string;
  const ADeliveryParamsJson: string; out AResult: TTraffiqxUploadResult; out AError: TTraffiqxError): Boolean;
var
  HttpClient: TNetHTTPClient;
  LForm: TMultipartFormData;
  Response: IHTTPResponse;
  LUrl: string;
  LJson: TJSONObject;
begin
  Result := False; AResult := nil; AError := nil;
  if (FApiBaseUri = '') or (FTRAFFIQXId = '') or (FAccessToken = '') or (FClientId = '') then
  begin AError := MakeError('#LOCAL', 0, 'Ungültige oder fehlende Konfiguration.'); Exit; end;
  if (FProviderType in [tpDatev,tpDatevSmartTransfer]) and (FAppDisplayName = '') then
  begin AError := MakeError('#LOCAL', 0, 'Fehlender App-Display-Name.'); Exit; end;
  if (AData = nil) or (AData.Size = 0) then
  begin AError := MakeError('#LOCAL', 0, 'ZUGFeRD-Daten fehlen.'); Exit; end;

  HttpClient := TNetHTTPClient.Create(nil);
  LForm := TMultipartFormData.Create;
  try
    ApplyAuthHeaders(HttpClient);
    LForm.AddStream('data', AData, false, ADataFileName, 'application/pdf');
    if ADeliveryParamsJson <> '' then
      LForm.AddField('delivery_params', ADeliveryParamsJson, 'application/json');

    LUrl := FApiBaseUri + ifthen(FApiBaseUri.EndsWith('/'), '', '/')
      + 'traffiqx-clients/' + TNetEncoding.URL.Encode(FTRAFFIQXId)
      + '/outbox/zugferd-data';

    Response := HttpPostForm(HttpClient, LUrl, LForm, tbOnError);
    if Response.StatusCode <> 201 then
    begin
      LJson := TJSONObject.ParseJSONValue(Response.ContentAsString(TEncoding.UTF8)) as TJSONObject;
      try
        if LJson is TJSONObject then
          AError := TTraffiqxError.FromJson(LJson)
        else
          AError := MakeError('#HTTP' + Response.StatusCode.ToString, Response.StatusCode, Response.ContentAsString(TEncoding.UTF8));
      finally
        LJson.Free;
      end;
      Exit;
    end;

    LJson := TJSONObject.ParseJSONValue(Response.ContentAsString(TEncoding.UTF8)) as TJSONObject;
    try
      AResult := TTraffiqxUploadResult.FromJson(LJson);
      Result := AResult <> nil;
    finally
      LJson.Free;
    end;
  finally
    LForm.Free;
    HttpClient.Free;
  end;
end;

function TTRAFFIQXInvoiceAPI.UploadStructuredData(const ADataXml, AViewPdf: TStream; const ADataFileName, AViewFileName: string;
  const ADeliveryParamsJson: string; out AResult: TTraffiqxUploadResult; out AError: TTraffiqxError): Boolean;
var
  HttpClient: TNetHTTPClient;
  LForm: TMultipartFormData;
  Response: IHTTPResponse;
  LUrl: string;
  LJson: TJSONObject;
begin
  Result := False; AResult := nil; AError := nil;
  if (FApiBaseUri = '') or (FTRAFFIQXId = '') or (FAccessToken = '') or (FClientId = '') then
  begin AError := MakeError('#LOCAL', 0, 'Ungültige oder fehlende Konfiguration.'); Exit; end;
  if (FProviderType in [tpDatev,tpDatevSmartTransfer]) and (FAppDisplayName = '') then
  begin AError := MakeError('#LOCAL', 0, 'Fehlender App-Display-Name.'); Exit; end;
  if (ADataXml = nil) or (ADataXml.Size = 0) or (AViewPdf = nil) or (AViewPdf.Size = 0) then
  begin AError := MakeError('#LOCAL', 0, 'XML oder PDF fehlt.'); Exit; end;

  HttpClient := TNetHTTPClient.Create(nil);
  LForm := TMultipartFormData.Create;
  try
    ApplyAuthHeaders(HttpClient);
    LForm.AddStream('data', ADataXml, false, ADataFileName, 'application/xml');
    LForm.AddStream('view_component', AViewPdf, false, AViewFileName, 'application/pdf');
    if ADeliveryParamsJson <> '' then
      LForm.AddField('delivery_params', ADeliveryParamsJson, 'application/json');

    LUrl := FApiBaseUri + ifthen(FApiBaseUri.EndsWith('/'), '', '/')
      + 'traffiqx-clients/' + TNetEncoding.URL.Encode(FTRAFFIQXId)
      + '/outbox/structured-data';

    Response := HttpPostForm(HttpClient, LUrl, LForm, tbOnError);
    if Response.StatusCode <> 201 then
    begin
      LJson := TJSONObject.ParseJSONValue(Response.ContentAsString(TEncoding.UTF8)) as TJSONObject;
      try
        if LJson is TJSONObject then
          AError := TTraffiqxError.FromJson(LJson)
        else
          AError := MakeError('#HTTP' + Response.StatusCode.ToString, Response.StatusCode, Response.ContentAsString(TEncoding.UTF8));
      finally
        LJson.Free;
      end;
      Exit;
    end;

    LJson := TJSONObject.ParseJSONValue(Response.ContentAsString(TEncoding.UTF8)) as TJSONObject;
    try
      AResult := TTraffiqxUploadResult.FromJson(LJson);
      Result := AResult <> nil;
    finally
      LJson.Free;
    end;
  finally
    LForm.Free;
    HttpClient.Free;
  end;
end;

function TTRAFFIQXInvoiceAPI.GetOutboxDocumentIds(out ADocuments: TTraffiqxOutboxDocumentList; out AError: TTraffiqxError;
  const AUseDownloadedFilter: Boolean; const ADownloaded: Boolean; const AUseStatusFilter: Boolean; const AStatus: string): Boolean;
var
  HttpClient: TNetHTTPClient;
  Response: IHTTPResponse;
  lQuery: TStringBuilder;
  lUrl: string;
  lJSONValue: TJSONValue;
  lArray: TJSONArray;
  lItem: TJSONValue;

  procedure AddQueryParam(const AName, AValue: string);
  begin
    if AValue = '' then Exit;
    if lQuery.Length > 0 then lQuery.Append('&');
    lQuery.Append(AName).Append('=').Append(TNetEncoding.URL.Encode(AValue));
  end;
begin
  Result := False; ADocuments := nil; AError := nil; FLastRawContentReceived := '';
  if (FApiBaseUri = '') or (FTRAFFIQXId = '') or (FAccessToken = '') or (FClientId = '') then
  begin AError := MakeError('#LOCAL', 0, 'Ungültige oder fehlende Konfiguration.'); Exit; end;
  if (FProviderType in [tpDatev,tpDatevSmartTransfer]) and (FAppDisplayName = '') then
  begin AError := MakeError('#LOCAL', 0, 'Fehlender App-Display-Name.'); Exit; end;

  HttpClient := TNetHTTPClient.Create(nil);
  lQuery := TStringBuilder.Create;
  lJSONValue := nil;
  try
    ApplyAuthHeaders(HttpClient);
    if AUseDownloadedFilter then
      AddQueryParam('downloaded', LowerCase(BoolToStr(ADownloaded, True)));
    if AUseStatusFilter and (AStatus <> '') then
      AddQueryParam('status', AStatus);

    lUrl := BuildOutboxBase;
    if lQuery.Length > 0 then
      lUrl := lUrl + '?' + lQuery.ToString;

    Response := HttpGet(HttpClient, lUrl, nil, nil, tbOnError);

    FLastRawContentReceived := Response.ContentAsString(TEncoding.UTF8);

    if Response.StatusCode <> 200 then
    begin
      lJSONValue := TJSONObject.ParseJSONValue(Response.ContentAsString(TEncoding.UTF8));
      if lJSONValue is TJSONObject then
        AError := TTraffiqxError.FromJson(TJSONObject(lJSONValue))
      else
        AError := MakeError('#HTTP' + Response.StatusCode.ToString, Response.StatusCode, Response.ContentAsString(TEncoding.UTF8));
      Exit;
    end;

    lJSONValue := TJSONObject.ParseJSONValue(Response.ContentAsString(TEncoding.UTF8));
    if lJSONValue is TJSONArray then
    begin
      lArray := TJSONArray(lJSONValue);
      ADocuments := TTraffiqxOutboxDocumentList.Create(True);
      for lItem in lArray do
        if lItem is TJSONObject then
          ADocuments.Add(TTraffiqxOutboxDocument.FromJson(TJSONObject(lItem)));
      Result := True;
    end
    else
      AError := MakeError('#PARSE', 0, 'Antwort enthält kein JSON-Array.');
  finally
    lJSONValue.Free;
    lQuery.Free;
    HttpClient.Free;
  end;
end;

function TTRAFFIQXInvoiceAPI.GetOutboxDocumentMetadata(const ADocumentId: string;
  out AMetadata: TTraffiqxOutboxMetadata; out AError: TTraffiqxError): Boolean;
var
  HttpClient: TNetHTTPClient;
  Response: IHTTPResponse;
  lUrl: string;
  lJSONValue: TJSONValue;
begin
  Result := False; AMetadata := nil; AError := nil; FLastRawContentReceived := '';
  if (FApiBaseUri = '') or (FTRAFFIQXId = '') or (FAccessToken = '') or (FClientId = '') then
  begin AError := MakeError('#LOCAL', 0, 'Ungültige oder fehlende Konfiguration.'); Exit; end;
  if (FProviderType in [tpDatev,tpDatevSmartTransfer]) and (FAppDisplayName = '') then
  begin AError := MakeError('#LOCAL', 0, 'Fehlender App-Display-Name.'); Exit; end;
  if ADocumentId = '' then
  begin AError := MakeError('#LOCAL', 0, 'DocumentId darf nicht leer sein.'); Exit; end;

  HttpClient := TNetHTTPClient.Create(nil);
  lJSONValue := nil;
  try
    ApplyAuthHeaders(HttpClient);
    lUrl := BuildOutboxBase + '/' + TNetEncoding.URL.Encode(ADocumentId) + '/metadata';
    Response := HttpGet(HttpClient, lUrl, nil, nil, tbOnError);

    FLastRawContentReceived := Response.ContentAsString(TEncoding.UTF8);

    if Response.StatusCode <> 200 then
    begin
      lJSONValue := TJSONObject.ParseJSONValue(Response.ContentAsString(TEncoding.UTF8));
      if lJSONValue is TJSONObject then
        AError := TTraffiqxError.FromJson(TJSONObject(lJSONValue))
      else
        AError := MakeError('#HTTP' + Response.StatusCode.ToString, Response.StatusCode, Response.ContentAsString(TEncoding.UTF8));
      Exit;
    end;

    lJSONValue := TJSONObject.ParseJSONValue(Response.ContentAsString(TEncoding.UTF8));
    if lJSONValue is TJSONObject then
    begin
      AMetadata := TTraffiqxOutboxMetadata.FromJson(TJSONObject(lJSONValue));
      Result := True;
    end
    else
      AError := MakeError('#PARSE', 0, 'Antwort enthält kein JSON-Objekt.');
  finally
    lJSONValue.Free;
    HttpClient.Free;
  end;
end;

function TTRAFFIQXInvoiceAPI.GetOutboxDocumentStatus(const ADocumentId: string;
  out AStatus: TTraffiqxInboxDocumentStatusInfo; out AError: TTraffiqxError): Boolean;
var
  HttpClient: TNetHTTPClient;
  Response: IHTTPResponse;
  lUrl: string;
  lJSONValue: TJSONValue;
begin
  Result := False; AStatus := nil; AError := nil;
  if (FApiBaseUri = '') or (FTRAFFIQXId = '') or (FAccessToken = '') or (FClientId = '') then
  begin AError := MakeError('#LOCAL', 0, 'Ungültige oder fehlende Konfiguration.'); Exit; end;
  if (FProviderType in [tpDatev,tpDatevSmartTransfer]) and (FAppDisplayName = '') then
  begin AError := MakeError('#LOCAL', 0, 'Fehlender App-Display-Name.'); Exit; end;
  if ADocumentId = '' then
  begin AError := MakeError('#LOCAL', 0, 'DocumentId darf nicht leer sein.'); Exit; end;

  HttpClient := TNetHTTPClient.Create(nil);
  lJSONValue := nil;
  try
    ApplyAuthHeaders(HttpClient);
    lUrl := BuildOutboxBase + '/' + TNetEncoding.URL.Encode(ADocumentId) + '/status';
    Response := HttpGet(HttpClient, lUrl, nil, nil, tbAlways);
    if Response.StatusCode <> 200 then
    begin
      lJSONValue := TJSONObject.ParseJSONValue(Response.ContentAsString(TEncoding.UTF8));
      if lJSONValue is TJSONObject then
        AError := TTraffiqxError.FromJson(TJSONObject(lJSONValue))
      else
        AError := MakeError('#HTTP' + Response.StatusCode.ToString, Response.StatusCode, Response.ContentAsString(TEncoding.UTF8));
      Exit;
    end;

    lJSONValue := TJSONObject.ParseJSONValue(Response.ContentAsString(TEncoding.UTF8));
    if lJSONValue is TJSONObject then
    begin
      AStatus := TTraffiqxInboxDocumentStatusInfo.FromJson(TJSONObject(lJSONValue));
      Result := AStatus <> nil;
    end
    else
      AError := MakeError('#PARSE', 0, 'Antwort enthält kein JSON-Objekt.');
  finally
    lJSONValue.Free;
    HttpClient.Free;
  end;
end;

function TTRAFFIQXInvoiceAPI.WaitForOutboxDocumentSent(const ADocumentId: string;
  out AStatus: TTraffiqxInboxDocumentStatusInfo; out AError: TTraffiqxError;
  const AInitialIntervalMs, AMaxIntervalMs, ATimeoutMs: Cardinal): Boolean;
var
  LCurrentStatus: TTraffiqxInboxDocumentStatusInfo;
  LCurrentError: TTraffiqxError;
  LPollIntervalMs: Cardinal;
  LStartedAt: UInt64;

  function BuildTerminalStatusError: TTraffiqxError;
  var
    LDetail: string;
  begin
    LDetail := 'Outbox-Dokument ist nicht versandbereit. Status: '
      + TTraffiqxDocumentStatusHelper.ToDisplayString(AStatus.ParsedStatus)
      + ' (' + AStatus.Status + ')';
    if AStatus.ErrorCode <> '' then
      LDetail := LDetail + ', ErrorCode: ' + AStatus.ErrorCode;
    if AStatus.ErrorDetails <> '' then
      LDetail := LDetail + ', ErrorDetails: ' + AStatus.ErrorDetails;
    Result := MakeError('#OUTBOX_STATUS', 0, LDetail);
  end;

begin
  Result := False;
  AStatus := nil;
  AError := nil;
  LPollIntervalMs := AInitialIntervalMs;
  if LPollIntervalMs = 0 then
    LPollIntervalMs := 1000;
  if AMaxIntervalMs > 0 then
    LPollIntervalMs := Min(LPollIntervalMs, AMaxIntervalMs);

  LStartedAt := TThread.GetTickCount64;
  while True do
  begin
    LCurrentStatus := nil;
    LCurrentError := nil;
    if not GetOutboxDocumentStatus(ADocumentId, LCurrentStatus, LCurrentError) then
    begin
      AError := LCurrentError;
      Exit(False);
    end;

    FreeAndNil(AStatus);
    AStatus := LCurrentStatus;

    if AStatus.IsSuccessful then
      Exit(True);

    if AStatus.HasProcessingError then
    begin
      AError := BuildTerminalStatusError;
      Exit(False);
    end;

    if (ATimeoutMs > 0) and ((TThread.GetTickCount64 - LStartedAt) >= ATimeoutMs) then
    begin
      AError := MakeError('#TIMEOUT', 0,
        'Timeout beim Warten auf den Outbox-Status "sent". Letzter Status: '
        + TTraffiqxDocumentStatusHelper.ToDisplayString(AStatus.ParsedStatus)
        + ' (' + AStatus.Status + ')');
      Exit(False);
    end;

    TThread.Sleep(LPollIntervalMs);
    if (AMaxIntervalMs > 0) and (LPollIntervalMs < AMaxIntervalMs) then
      LPollIntervalMs := Min(LPollIntervalMs * 2, AMaxIntervalMs);
  end;
end;

function TTRAFFIQXInvoiceAPI.DownloadOutboxDocument(const ADocumentId: string;
  out AContent: TMemoryStream; out APendingStatus: TTraffiqxInboxDocumentStatusInfo; out AError: TTraffiqxError): Boolean;
var
  HttpClient: TNetHTTPClient;
  Response: IHTTPResponse;
  lUrl: string;
  lJSONValue: TJSONValue;
begin
  Result := False; AContent := nil; APendingStatus := nil; AError := nil;
  if (FApiBaseUri = '') or (FTRAFFIQXId = '') or (FAccessToken = '') or (FClientId = '') then
  begin AError := MakeError('#LOCAL', 0, 'Ungültige oder fehlende Konfiguration.'); Exit; end;
  if (FProviderType in [tpDatev,tpDatevSmartTransfer]) and (FAppDisplayName = '') then
  begin AError := MakeError('#LOCAL', 0, 'Fehlender App-Display-Name.'); Exit; end;
  if ADocumentId = '' then
  begin AError := MakeError('#LOCAL', 0, 'DocumentId darf nicht leer sein.'); Exit; end;

  HttpClient := TNetHTTPClient.Create(nil);
  lJSONValue := nil;
  try
    ApplyAuthHeaders(HttpClient);
    lUrl := BuildOutboxBase + '/' + TNetEncoding.URL.Encode(ADocumentId);
    AContent := TMemoryStream.Create;
    try
      Response := HttpGet(HttpClient, lUrl, AContent, nil, tbOnErrorOrPending);
    except
      on E: Exception do
      begin
        FreeAndNil(AContent);
        AError := MakeError('#TRANSPORT', 0, E.Message);
        Exit;
      end;
    end;

    if Response.StatusCode = 200 then
    begin
      AContent.Position := 0;
      Result := True;
      Exit;
    end;

    // 202: Status zurückliefern, kein Download
    if Response.StatusCode = 202 then
    begin
      AContent.Free; AContent := nil;
      lJSONValue := TJSONObject.ParseJSONValue(Response.ContentAsString(TEncoding.UTF8));
      if lJSONValue is TJSONObject then
        APendingStatus := TTraffiqxInboxDocumentStatusInfo.FromJson(TJSONObject(lJSONValue))
      else
        AError := MakeError('#PARSE', 0, 'Antwort enthält kein JSON-Objekt.');
      Exit;
    end;

    // Fehlerfall
    AContent.Free; AContent := nil;
    lJSONValue := TJSONObject.ParseJSONValue(Response.ContentAsString(TEncoding.UTF8));
    if lJSONValue is TJSONObject then
      AError := TTraffiqxError.FromJson(TJSONObject(lJSONValue))
    else
      AError := MakeError('#HTTP' + Response.StatusCode.ToString, Response.StatusCode, Response.ContentAsString(TEncoding.UTF8));
  finally
    lJSONValue.Free;
    HttpClient.Free;
  end;
end;

{ TTraffiqxDeliveryParamameter }

function TTraffiqxDeliveryParamameter.ToJsonString: String;
var
  LObj: TJSONObject;
  LFormat: string;
begin
  // Liefert leeren String, wenn keine Parameter gesetzt sind; sonst kompaktes JSON.
  if PreferredFormat = pfNone then
    Exit('');

  LObj := TJSONObject.Create;
  try
    case PreferredFormat of
      pfXRechnung: LFormat := 'XRechnung';
      pfZUGFeRD:   LFormat := 'ZUGFeRD';
    else
      LFormat := '';
    end;

    if LFormat <> '' then
      LObj.AddPair('preferred_format', LFormat);

    Result := LObj.ToJSON;
  finally
    LObj.Free;
  end;
end;

end.

