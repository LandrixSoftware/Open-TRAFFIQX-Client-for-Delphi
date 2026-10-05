# Schnittstellenvorgaben

Die TRAFFIQX® Invoice API ermöglicht den bidirektionalen Datenaustausch mit der DATEV E-Rechnungsplattform und weiteren Providern im Traffiqx-Netzwerk.

Hinweis: Für den Freigabeprozess einer Cloud-Integration sind zusätzlich zu den nachfolgenden API-spezifischen Schnittstellenvorgaben noch die [Allgemeinen Schnittstellenvorgaben](https://developer.datev.de/de/guides/interface-requirements#allgemeine-schnittstellenvorgaben) zu beachten.

Wie man diese Vorgaben mit der Bibliothek umsetzt, beschreibt [`Integration.md`](Integration.md) Schritt für Schritt.

## 1. Inbetriebnahme

Bevor Kunden die Integration der 3rd-Party-App nutzen können, müssen vorbereitende Konfigurationen in der 3rd-Party-App erfolgen. Die 3rd-Party-App muss vom Kunden die Information erhalten, welcher TRAFFIQX-Provider und welche TRAFFIQX-ID der Kunde besitzt.

- MUST: Zeigen Sie auf, wo und wie diese Informationen vom Kunden hinterlegt werden können. Als TRAFFIQX-Provider darf die DATEV E-Rechnungsplattform auch fest hinterlegt werden.
- SHOULD: Gestalten Sie die Integration so, dass der Kunde grundsätzlich auch andere TRAFFIQX-Provider erreichen kann ([siehe Dokumentation](https://developer.datev.de/de/product-detail/traffiqx-invoice/documentation/anbindung-weiterer-traffiqxregisteredtrademarkminusprovider)).

Nachdem der Kunde die notwendigen Informationen hinterlegt hat, kann nun die Authentifizierung durchlaufen werden, also die Ausstellung eines Tokens. Direkt nachdem der Kunde die Authentifizierung durchlaufen hat, ist ein neutraler Verbindungscheck durchzuführen, um zu überprüfen, ob der Kunde die nötigen Berechtigungen für die TRAFFIQX-ID besitzt. Für einen neutralen Verbindungscheck ist der Status-Endpunkt von Inbox bzw. Outbox inklusive eines Filters zu nutzen, um die Response-Payload gering zu halten.

```http
GET https://traffiqx-invoice.api.datev.de/platform/v1/traffiqx-clients/{traffiqx_id}/inbox-documents?from_date=""
GET https://traffiqx-invoice.api.datev.de/platform/v1/traffiqx-clients/{traffiqx_id}/outbox-documents?status="inProcess"
```

Erhält man auf diesen Endpunkten jeweils einen HTTP-Statuscode `200`, dann hat das Token bzw. die DATEV-Identität die nötigen Berechtigungen, um auf die Endpunkte zuzugreifen. Tritt ein HTTP-Statuscode `403` auf, hat der Benutzer nicht die nötigen Rechte auf die TRAFFIQX-ID oder den jeweiligen Bereich, also Inbox bzw. Outbox.

- MUST: Je nachdem, welche Use Cases, also Inbox und/oder Outbox, von der 3rd-Party-App unterstützt werden, ist der Verbindungscheck technisch durchzuführen und zu überprüfen, ob die API mit einem HTTP-Statuscode `200` antwortet.
- MUST: Erst wenn die API einen HTTP-Statuscode `200` aufzeigt, darf dem Kunden ein erfolgreicher Verbindungsaufbau mit seiner Inbox und/oder Outbox signalisiert werden.
- MUST: Treten Fehler beim Verbindungscheck auf, ist dem Kunden aufzuzeigen, dass der Verbindungsaufbau nicht erfolgreich war, und die Tokens sind unmittelbar am Identity Provider zu revoken.
- MUST: Der verbindliche Header-Parameter `X-App-Display-Name` muss immer mit dem zur Client-ID dazugehörigen App-Namen aus dem DATEV Developer Portal übereinstimmen.
- SHOULD: Bei Fehlern im Verbindungscheck sollten dem Kunden weitere Hilfemöglichkeiten angeboten werden, zum Beispiel ein eigenes Ticketsystem oder eine Lösungshilfe.

### Challenge

- Zeigen Sie den initialen Verbindungsaufbau mit der 3rd-Party-App auf und welche Informationen der Kunde zuvor bereitstellen muss.

## 2. Use Cases

Folgende Use Cases können mit der API umgesetzt werden:

### Posteingang / Inbox

1. Status vom Posteingang abfragen
2. Metadaten eines Dokuments abfragen
3. Download eines Dokuments

### Postausgang / Outbox

1. Upload eines Dokuments und Verarbeitungsstatus abfragen
2. Download eines Dokuments
3. Metadaten eines Dokuments abfragen
4. Status vom Postausgang abfragen

## 2. Vorgaben für Sandbox

Base URL: `https://traffiqx-invoice.api.datev.de/platform-sandbox/v0` (Stand des DATEV-Dokuments; der Client nutzt API-Version `/v1`: `…/platform-sandbox/v1`)

Die Vorgaben unterscheiden nachfolgend nach Inbox und Outbox. Je nachdem, welche Bereiche die 3rd-Party-App benötigt, sind die entsprechenden Vorgaben einzuhalten. Die Vorgaben umschreiben den typischen API-Workflow im jeweiligen Bereich.

### 2.1. API-Workflow für Inbox

1. Status vom Posteingang abfragen
2. Metadaten eines Dokuments abfragen
3. Download eines Dokuments

#### 2.1.1. Status vom Posteingang abfragen

```http
GET /traffiqx-clients/{traffiqx_id}/inbox-documents
```

Mit diesem Endpunkt kann sich die Drittanwendung einen Überblick über den Posteingang verschaffen, um beispielsweise neu eingegangene Dokumente in die eigene App zu übernehmen.

- MUST: Der Status vom Posteingang ist mit dem Status der Drittanwendung initial bzw. einmalig zu synchronisieren und von da an synchron zu halten.
- MUST: Die `document_id` muss entlang des Lebenszyklus eines Dokuments für den Kunden einsehbar sein.

#### 2.1.2. Metadaten eines Dokuments abfragen

```http
GET /traffiqx-clients/{traffiqx_id}/inbox-documents/{document_id}/metadata
```

Mit diesem Endpunkt kann man ergänzende Informationen wie beispielsweise den Validierungsstatus für ein Dokument einsehen.

- MUST: Der Validierungsstatus von E-Rechnungen, also `document_format` und `en_16931_compliant`, ist dem Kunden präsent anzuzeigen.
- MUST: Dem Kunden muss darüber informiert werden, wenn invalide E-Rechnungen eingegangen sind.

#### 2.1.3. Download eines Dokuments

```http
GET /traffiqx-clients/{traffiqx_id}/inbox-documents/{document_id}
```

Hiermit ist der Download des Dokuments möglich. Die Bereitstellung seitens der API erfolgt immer als ZIP-Datei.

- MUST: Die heruntergeladenen Dokumente müssen dem Kunden visualisiert werden können.
- MUST: Der Kunde muss in irgendeiner Form darüber aufgeklärt werden, wo die GoBD-konforme Langzeitarchivierung seiner Eingangsrechnung stattfindet.

#### Challenges für Inbox

- Zeigen Sie auf, wie in der 3rd-Party-App transparent wird, welche Dokumente im Posteingang der E-Rechnungsplattform eingegangen sind.
- Übernehmen Sie die noch nicht heruntergeladenen Dokumente und zeigen Sie auf, wie der Kunde die Dokumente über Ihre App einsehen kann und welche Informationen aus der API für den Kunden verfügbar gemacht werden.

### 2.2. API-Workflow für Outbox

1. Upload eines Dokuments und Verarbeitungsstatus abfragen
2. Download eines Dokuments
3. Metadaten eines Dokuments abfragen
4. Status vom Postausgang abfragen

#### 2.2.1. Upload eines Dokuments und Verarbeitungsstatus abfragen

```http
POST /traffiqx-clients/{traffiqx_id}/outbox/structured-data
POST /traffiqx-clients/{traffiqx_id}/outbox/zugferd-data
```

Für den Versand stehen zwei Upload-Wege zur Verfügung. Für XRechnung wird eine strukturierte XML-Datei im UBL- oder CII-Format zusammen mit einer PDF-Sichtkomponente übertragen. Für ZUGFeRD wird ein PDF im ZUGFeRD-2.x-Format hochgeladen. Nach erfolgreichem Upload liefert die API eine `document_id` sowie einen Link auf das Dokument zurück.

```http
GET /traffiqx-clients/{traffiqx_id}/outbox-documents/{document_id}/status
```

Nach dem Upload ist der Verarbeitungsstatus des Dokuments zu überwachen. Die API liefert die Statuswerte `inProcess`, `sent`, `error`, `deleted` oder `userAction`.

- MUST: Die Integration muss mindestens einen der beiden Upload-Wege unterstützen und eine erfolgreiche Verarbeitung mit `status=sent` nachweisen können.
- MUST: Die `document_id` aus der Response ist zu speichern und zusammen mit dem Status für den Kunden einsehbar zu machen.
- MUST: Die Integration muss alle Statuswerte verarbeiten können und dem Kunden transparent machen.
- MUST: Pollings am Status-Endpunkt sind auf die Laufzeit eines Access-Tokens zu beschränken.

#### 2.2.2. Download eines Dokuments

```http
GET /traffiqx-clients/{traffiqx_id}/outbox-documents/{document_id}
```

Nach dem erfolgreichen Versand mit `state=sent` muss das Dokument für die GoBD-konforme Langzeitarchivierung der Rechnung heruntergeladen werden.

- MUST: Der Download darf nur dann durchgeführt werden, wenn zuvor der Status `sent` bestätigt wurde.
- MUST: Die heruntergeladenen Dokumente müssen dem Kunden visualisiert werden können.
- MUST: Der Kunde muss in irgendeiner Form darüber aufgeklärt werden, wo die GoBD-konforme Langzeitarchivierung seiner Ausgangsrechnung stattfindet.

#### 2.2.3. Metadaten eines Dokuments abfragen

```http
GET /traffiqx-clients/{traffiqx_id}/outbox-documents/{document_id}/metadata
```

Zu den versendeten Dokumenten können fachliche Metadaten abgerufen werden. Eine wichtige Information ist die Bestätigung des Versandkanals `delivery_channel`.

- MUST: Der Abruf der Metadaten darf nur dann durchgeführt werden, wenn zuvor der Status `sent` bestätigt wurde.
- MUST: Die Integration muss den Versandkanal überprüfen, also gewollt versus tatsächlich, und dem Kunden mindestens Versandformat, Versanddatum, Versandkanal, also E-Mail, Traffiqx oder Peppol, sowie Versandadresse, also E-Mail oder ID, anzeigen.

#### 2.2.4. Status vom Postausgang abfragen

```http
GET /traffiqx-clients/{traffiqx_id}/outbox-documents
```

Der Status vom Postausgang kann für verschiedene Use Cases genutzt werden, zum Beispiel:

- Initialabgleich beim erstmaligen Verbinden mit der Outbox
- Regelmäßige Synchronisierung des Stands zwischen beiden Apps
- Langzeitarchivierung für alle Dokumente, nicht nur für die, die man selbst bereitgestellt hat

#### Challenges für Outbox

- Übertragen Sie mindestens eine E-Rechnung pro Versandkanal, also E-Mail, TRAFFIQX und Peppol, und erreichen Sie den Status `sent`.
- Übertragen Sie mindestens eine E-Rechnung und erreichen Sie den Status `error`. Zeigen Sie, wie die Integration auf den Fehler reagiert.
- Zeigen Sie die übertragenen E-Rechnungen in der 3rd-Party-App und welche Informationen dem Kunden bereitgestellt werden.

## 3. Vorgaben für Produktion

Base URL: `https://traffiqx-invoice.api.datev.de/platform/v0` (Stand des DATEV-Dokuments; der Client nutzt API-Version `/v1`: `…/platform/v1`)

Die Anforderungen aus Abschnitt 2, also den Vorgaben für Sandbox, sind identisch für die Produktion. Für die Produktionsfreigabe wird der DATEV-Berater den Entwickler bzw. Softwarehersteller in einen speziellen Testbestand für die DATEV E-Rechnungsplattform einladen. Mittels dieses Testbestands werden dann die einzelnen Vorgaben und Challenges durchlaufen.

## 4. Umsetzungsnotizen für diese Integration

Diese Repository-Struktur passt grundsätzlich gut zu den DATEV-Vorgaben, weil die Zuständigkeiten klar getrennt sind:

- Der PHP-basierte `OAuth2-Broker` übernimmt den OAuth2 Authorization Code Flow mit PKCE sowie die Übergabe der Tokens an den Desktop-Client.
- Der Delphi-Client deckt Provider-Auswahl, Login, Inbox, Outbox, Upload, Statusabfrage, Metadata und Download ab.
- Die manuelle Sandbox-Erprobung ist bereits vorgesehen und durch die vorhandenen Testdaten gut vorbereitbar.

Für die Abnahme sollte der initiale Verbindungsaufbau in genau dieser Reihenfolge demonstriert werden:

1. Kunde hinterlegt TRAFFIQX-Provider und TRAFFIQX-ID in der Client-Konfiguration bzw. Oberfläche.
2. Desktop-Client startet den OAuth2-Flow über den Broker.
3. Nach erfolgreicher Token-Ausstellung werden die unterstützten Bereiche, also Inbox und/oder Outbox, sofort über die geforderten Status-Endpunkte validiert.
4. Nur bei HTTP `200` wird der Verbindungsstatus im Client als erfolgreich angezeigt.
5. Bei Fehlern, insbesondere HTTP `403`, muss der Verbindungsaufbau als fehlgeschlagen ausgewiesen und das Token unmittelbar widerrufen werden.

Für die eigentliche Vorführung ist wichtig, dass nicht nur technische API-Aufrufe gezeigt werden, sondern auch die Sicht des Kunden in der Anwendung:

- Wo Provider und TRAFFIQX-ID gepflegt werden
- Wo der erfolgreiche oder fehlgeschlagene Verbindungsstatus sichtbar ist
- Wo `document_id`, Status und Validierungsinformationen angezeigt werden
- Wo heruntergeladene Dokumente eingesehen werden können
- Wo kenntlich gemacht wird, wie die GoBD-konforme Langzeitarchivierung organisatorisch gelöst ist

Für Inbox sollte die Demo deutlich machen, dass neue Dokumente übernommen, mit ihrer `document_id` nachvollziehbar angezeigt und über Metadaten fachlich eingeordnet werden. Dazu gehören insbesondere `document_format`, `en_16931_compliant` und ein klarer Hinweis auf invalide E-Rechnungen.

Für Outbox sollte die Demo zeigen, dass die Integration mindestens einen Upload-Weg stabil beherrscht, den Status bis `sent` oder `error` nachvollziehbar verfolgt und die Ergebnisdaten für den Kunden verständlich aufbereitet. Dazu gehören mindestens `document_id`, Verarbeitungsstatus, Versandformat, Versanddatum, Versandkanal und Versandadresse.

Offene Nachweis-Punkte für die Abnahme sollten vorab bewusst vorbereitet werden:

- Ein erfolgreicher Versand pro Kanal, also E-Mail, TRAFFIQX und Peppol
- Mindestens ein bewusst herbeigeführter Fehlerfall mit Status `error`
- Ein sichtbarer Umgang mit Status `userAction`, falls dieser in der Sandbox auftritt
- Eine belastbare Erklärung, wo Eingangs- und Ausgangsdokumente revisionssicher archiviert werden

Praktisch bietet sich für dieses Repository folgende Vorbereitungsbasis an:

- `client/cfg.ini` für lokale Provider- und Umgebungswerte
- `OAuth2-Broker/` für den Browser-basierten Login-Fluss
- `client/Delphi/Sample/` für die geführte manuelle Vorführung
- `testdata/` für strukturierte XML- und ZUGFeRD-Beispiele in der Sandbox

## 6. Ergänzungen für die Produktionsfreigabe

Stand nach dem Sandbox-Freigabetermin (September 2026). Für die Produktionsfreigabe gelten neben den TIA-Vorgaben oben auch die **allgemeinen Schnittstellenvorgaben** (developer.datev.de/de/guides/interface-requirements) und die TIA-Seite **Authentifizierung** (OAuth 2.0 & OIDC). Hier die für diese Integration relevanten Punkte.

### 6.1 Token-Laufzeiten (TIA-Seite Authentifizierung)

- Access-Token: 30 Minuten. Die allgemeine Seite nennt 15 Minuten; für TIA gilt die TIA-Seite.
- Refresh-Token ohne `offline_access`: 11 Stunden ab der Anmeldung.
- Refresh-Token mit Scope `offline_access` (Langzeit-Token, muss für die App bei DATEV beantragt und freigeschaltet sein): 6 Monate ab der Anmeldung. Danach ist eine neue Anmeldung nötig.
- Beim Erneuern behält das neue Refresh-Token die ursprüngliche Laufzeit seit der Anmeldung; es verlängert sich nicht.
- Refresh-Tokens sind nur einmal einlösbar. Wird dasselbe Refresh-Token ein zweites Mal eingelöst, wird die ganze Sitzung ungültig.
- Alle Tokens sind OPAQUE. Die Gültigkeit steht nicht im Token, sie kommt nur über den Introspection-Endpunkt.

### 6.2 Endpunkte des DATEV Identity Providers

- Userinfo (`GET …/userinfo`, Bearer Access-Token): `name`, `given_name`, `family_name` nur mit Scope `profile`, `email` nur mit Scope `email`.
- Introspection (`POST …/introspect`, Basic-Auth mit Client-ID und Client-Secret, Body `token` und `token_type_hint`): prüft ein Access- oder Refresh-Token. Die DATEV-Doku zeigt den Antwort-Body nicht; der Client wertet die Felder nach RFC 7662 aus (`active`, `exp`, ersatzweise `expires_in`).
- Endsession (`GET …/connect/endSession?id_token_hint=…`): beendet die Browsersitzung am DATEV-Login. Braucht das ID-Token.

### 6.3 Anforderungen an die Verbindungs-Oberfläche (allgemeine Vorgaben)

- MUST: Authentifizierung über eine Schaltfläche starten, zum Beispiel „Mit DATEV verbinden“.
- MUST: Verbindungsstatus des Refresh-Tokens schnell ersichtlich, zum Beispiel grüne oder rote Ampel.
- MUST: Refresh-Token über eine Schaltfläche löschbar, zum Beispiel „Verbindung trennen“: Löschung in der App und `/revoke` bei DATEV.
- MUST: errechnetes Ablaufdatum des Refresh-Tokens ersichtlich, mindestens im Format `TT.MM.JJJJ HH:MM`.
- MUST: vollständiger Name der Person ersichtlich, die das Token ausgestellt hat (über den Userinfo-Endpunkt).
- MUST: DATEV-App „Verbundene Anwendungen“ verlinkt (`https://apps.datev.de/tokrevui`).
- MUST beim Langzeit-Token: im Verbindungsstatus anzeigen, für welchen Datenbestand die Verbindung gilt (bei TIA die TRAFFIQX-ID).
- MUST: nie mehr als ein gültiges Refresh-Token bei DATEV. Eine bestehende Verbindung vor einer neuen Anmeldung widerrufen.
- MUST: nur die nötigen Scopes anfordern.

### 6.4 Weitere allgemeine Vorgaben

- MUST: technisches HTTP-Protokoll aller Aufrufe an das DATEV API-Gateway, chronologisch, mindestens 14 Tage aufbewahrt, nicht für Kunden sichtbar. Anfrage: Zeitstempel, Methode und vollständige URL, Header ohne `Authorization`. Antwort: Zeitstempel, HTTP-Code, mindestens die Header `X-Global-Transaction-ID` und `V-Cap-Request-ID`, Body nur bei Fehlern und Statusabfragen.
- DONT: Tokens und Secrets in der Oberfläche anzeigen oder protokollieren.
- MUST: Daten mit höherem Schutzbedarf (Client-Secret, Access- und Refresh-Token) verschlüsselt speichern.
- MUST: bei 4xx-Fehlern mindestens die Hilfe-URL anzeigen. Die TIA-Fehlerantworten sind RFC-7807-ProblemDetails; das Feld `type` enthält die Hilfe-URL.
- MUST nach der Produktionsfreigabe: Fehlerquote unter 10 % (Antworten mit 4xx und 5xx an allen Anfragen).
- DONT: Polling rund um die Uhr ohne konkreten Kundenanlass.
- Aus dem Termin: Statusabfrage nach dem Upload mit festem Abstand von 8 Sekunden, höchstens 1 Minute.
- MUST im Termin: gewählte Architektur darlegen (hier Hybrid: Broker für den Token-Austausch, Desktop für den Datenaustausch) und erklären, wie die eigenen Entitäten mit den DATEV-Entitäten zusammenhängen und wo die Tokens liegen.

### 6.5 Stand im Delphi-Client (`intf.TRAFFIQXInvoiceAPI.pas`)

- `GetUserInfo` und `IntrospectToken` sind vorhanden; `TryFetchWellKnownEndpoints` liest dafür `userinfo_endpoint` und `introspection_endpoint`.
- `DefaultRefreshTokenExpiresAt` berechnet das Ablaufdatum eines neuen Refresh-Tokens ab der Anmeldung (11 Stunden, mit `offline_access` 6 Monate). Beim Erneuern bleibt das Ablaufdatum unverändert.
- `TTraffiqxError.TypeUri` enthält das ProblemDetails-Feld `type`; `TTraffiqxInboxErrorHelper.HelpUrl` und `ErrorText` liefern die Hilfe-URL für Anzeige und Protokoll.
- `WaitForOutboxDocumentSent` wartet standardmäßig mit festem Abstand von 8 Sekunden, höchstens 1 Minute.
- `TraffiqxNormalizeId` und die Property `TRAFFIQXId` entfernen Leerraum und das Präfix `TX:`. Die API erwartet im Pfad nur die Ziffernfolge (13 bis 15 Zeichen); `TX:0012001064105` ergibt HTTP 400 „The request URI was invalid“.
- Achtung, gegenläufig: In der Rechnung (BT-10) steht die TRAFFIQX-ID des Empfängers laut Business-Dokumentation 10.2.1 **mit** Präfix, z.B. `TX:1234567890000`.
- Beobachtet auf Produktion (nicht in der Business-Dokumentation): Eine Rechnung an die eigene TRAFFIQX-ID wird mit `VALIDATION_DRAFT_ERROR` / `RECEIVER_IS_SENDER_TRAFFIQXID` abgelehnt. Für die Challenges werden fremde Empfänger gebraucht. Eine als XRechnung-Extension deklarierte Rechnung wird mit `DRAFT_UNSUPPORTED_FORMAT` abgelehnt. Ein leeres BT-10 (`<cbc:BuyerReference/>`) wird mit `VALIDATION_DRAFT_ERROR` / `DRAFT_NON_COMPLIANT` abgelehnt (EN 16931 verbietet leere Elemente, XRechnung verlangt BT-10). Ohne Leitweg-ID oder TRAFFIQX-ID bleibt deshalb der Platzhalter `non-existent` stehen; nur die Sandbox brach damit ab.
- `OnHttpTrace` meldet jede Anfrage und Antwort einschließlich Well-known, Broker-Start, Polling, Token-Refresh, Revoke, Introspection und Userinfo (Abschnitt 6.4). `Authorization`, `X-Api-Key` und Cookies fehlen, Tokens, `code`, `sessionId` und `state` in URL und Headern sind maskiert, Weiterleitungen werden einzeln gemeldet; Anfrage-Bodies nie, Antwort-Bodies nur bei HTTP-Fehlern, bei der Statusabfrage und bei 202 des Downloads, jeweils maskiert (`RedactSecrets`: JSON strukturell, Freitext mit geheimem Schlüssel vor `:` oder `=` wird ganz verworfen). Ablage, Aufbewahrung von 14 Tagen und Fehlerquote übernimmt `intf.TRAFFIQXHttpLog.pas` (`TTraffiqxHttpLog.Attach`, `GetErrorRate`); die Anwendung legt nur das Verzeichnis fest und zeigt die Quote an.
- `intf.TRAFFIQXTokenProtection.pas` verschlüsselt Tokens per DPAPI, an den Windows-Benutzer oder an den Rechner gebunden; `Fingerprint` ordnet eine gespeicherte Sitzung einer Anmeldung zu. Wo die Tokens liegen und wer sie erneuert, entscheidet die Anwendung (siehe 6.1: nie mehr als ein gültiges Refresh-Token).
- Noch offen: Endsession.

## 5. Kompakte Abnahme-Checkliste

### Inbetriebnahme

- [ ] Es ist im Client klar erkennbar, wo Provider und TRAFFIQX-ID gepflegt werden.
- [ ] Der Header `X-App-Display-Name` ist korrekt zum registrierten App-Namen konfiguriert.
- [ ] Der OAuth2-Login über den Broker funktioniert mit der vorgesehenen Redirect-URI.
- [ ] Direkt nach dem Login wird für alle unterstützten Bereiche ein Verbindungscheck ausgeführt.
- [ ] Erfolg wird nur bei HTTP `200` angezeigt.
- [ ] Fehler beim Verbindungscheck werden sichtbar dargestellt.
- [ ] Tokens werden bei fehlgeschlagenem Verbindungscheck widerrufen.
- [ ] Es gibt eine Hilfestellung für den Kunden bei Verbindungsfehlern.

### Inbox

- [ ] Der Inbox-Status wurde initial synchronisiert.
- [ ] Neue oder vorhandene Inbox-Dokumente sind im Client sichtbar.
- [ ] Die `document_id` ist für jedes Dokument einsehbar.
- [ ] Metadaten können für ein Inbox-Dokument abgerufen werden.
- [ ] `document_format` und `en_16931_compliant` werden sichtbar angezeigt.
- [ ] Invalide E-Rechnungen werden für den Kunden klar gekennzeichnet.
- [ ] Dokumente können als ZIP geladen und für den Kunden visualisiert werden.
- [ ] Die Langzeitarchivierung für Eingangsrechnungen ist fachlich erklärt.

### Outbox

- [ ] Mindestens ein unterstützter Upload-Weg ist produktnah demonstrierbar.
- [ ] Die `document_id` aus dem Upload wird gespeichert und angezeigt.
- [ ] Der Statusabruf verarbeitet `inProcess`, `sent`, `error`, `deleted` und `userAction`.
- [ ] Das Status-Polling ist auf die Laufzeit des Access-Tokens begrenzt.
- [ ] Ein erfolgreicher Versand mit Status `sent` wurde nachgewiesen.
- [ ] Ein Fehlerfall mit Status `error` wurde nachgewiesen.
- [ ] Der Download erfolgt erst nach bestätigtem Status `sent`.
- [ ] Outbox-Metadaten werden erst nach bestätigtem Status `sent` abgefragt.
- [ ] Versandformat, Versanddatum, Versandkanal und Versandadresse werden angezeigt.
- [ ] Der gewünschte Versandkanal wird gegen den tatsächlichen `delivery_channel` geprüft.
- [ ] Die Langzeitarchivierung für Ausgangsrechnungen ist fachlich erklärt.

### Nachweis für die Challenges

- [ ] Inbox-Dokumente werden transparent in der Anwendung dargestellt.
- [ ] Noch nicht geladene Inbox-Dokumente können übernommen werden.
- [ ] Pro Versandkanal wurde mindestens eine E-Rechnung erfolgreich versendet.
- [ ] Die Reaktion der Integration auf einen Versandfehler ist nachvollziehbar dokumentiert.
- [ ] Die in der Anwendung sichtbaren Kundeninformationen sind für Inbox und Outbox vollständig genug für die Abnahme.

### Produktion

- [ ] Es ist dokumentiert, dass die Sandbox-Anforderungen identisch für Produktion gelten.
- [ ] Die Vorführung kann auf den DATEV-Testbestand für die Produktionsfreigabe übertragen werden.
- [ ] Verbindungs-Oberfläche erfüllt Abschnitt 6.3 (Ampel, Name über Userinfo, Datenbestand, Ablaufdatum, Verbinden/Trennen, Link „Verbundene Anwendungen“).
- [ ] Vor einer neuen Anmeldung wird eine bestehende Verbindung widerrufen.
- [ ] Technisches HTTP-Protokoll nach Abschnitt 6.4, ohne Tokens und Secrets, 14 Tage Aufbewahrung (`intf.TRAFFIQXHttpLog.pas`).
- [ ] Fehlerquote unter 10 % auswertbar und im Blick (`TTraffiqxHttpLog.GetErrorRate`).
- [ ] Tokens werden verschlüsselt gespeichert (`intf.TRAFFIQXTokenProtection.pas`).
- [ ] Bei 4xx-Fehlern wird die Hilfe-URL angezeigt.
- [ ] Architektur und Token-Umgang können im Termin erklärt werden.

## Changelog

| Version | Datum | Änderungen |
| --- | --- | --- |
| 1.1 | 2026-04-01 | Veröffentlichung |