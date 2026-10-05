# Leitfaden: die DATEV E-Rechnungsplattform (TIA) in eigene Software einbinden

Dieser Leitfaden richtet sich an Entwickler, die die TRAFFIQX Invoice API (TIA) der DATEV E-Rechnungsplattform mit dieser Bibliothek in ihre eigene Software einbauen und dafür die Produktionsfreigabe bei DATEV brauchen. Er beschreibt die Schritte in der Reihenfolge, in der man sie angeht, und die Stellen, an denen es in der Praxis hakt.

- **Was DATEV verlangt**, steht in [`Abnahme.md`](Abnahme.md) (Vorgaben, MUST/SHOULD/DONT, Checkliste). Dieser Leitfaden verweist darauf, statt es zu wiederholen.
- **Wie der Code aussieht**, zeigen die Units unter `client/Delphi/` und das Sample `client/Delphi/Sample/TIAUnit1.pas`.
- Die Erfahrungen stammen aus einer realen Integration, die die Sandbox-Freigabe durchlaufen hat und auf Produktion läuft.

## Übersicht

| Schritt | Worum es geht | Bausteine |
| --- | --- | --- |
| 1 | App bei DATEV registrieren, Scopes wählen | DATEV Developer Portal |
| 2 | OAuth2-Broker betreiben | `OAuth2-Broker/` |
| 3 | Architektur festlegen: Wo liegen die Tokens? | dieser Leitfaden, Abschnitt 3 |
| 4 | Bibliothek einbinden | `intf.TRAFFIQXInvoiceAPI.pas` |
| 5 | Anmeldung und Verbindungsoberfläche | `StartAuth`, `CheckConnectionAccess`, `GetUserInfo`, `IntrospectToken` |
| 6 | Token-Lebenszyklus | `RefreshAccessToken`, `RevokeTokens`, `intf.TRAFFIQXTokenProtection.pas` |
| 7 | Posteingang | `GetInboxDocumentIds`, `GetInboxDocumentMetadata`, `DownloadInboxDocument` |
| 8 | Postausgang | `UploadStructuredData`, `WaitForOutboxDocumentSent`, `DownloadOutboxDocument` |
| 9 | Fehler anzeigen | `TTraffiqxInboxErrorHelper` |
| 10 | HTTP-Protokoll und Fehlerquote | `intf.TRAFFIQXHttpLog.pas` |
| 11 | Abnahmetermin vorbereiten | [`Abnahme.md`](Abnahme.md), Abschnitt 7 |

## 1. App bei DATEV registrieren

- Im DATEV Developer Portal eine App anlegen. Sie bekommen Client-ID und Client-Secret.
- **App-Name:** Der Header `X-App-Display-Name` muss exakt dem dort registrierten Namen entsprechen (MUST, [`Abnahme.md`](Abnahme.md) Abschnitt 1). Die Bibliothek sendet `AppDisplayName` bei den TIA-Datenaufrufen (Posteingang, Postausgang, Verbindungscheck) mit und lehnt diese ohne ihn schon lokal ab. Anmeldung, Userinfo, Erneuerung und Widerruf prüfen ihn nicht: Ohne App-Namen gelingt also die Anmeldung, und erst der Verbindungscheck scheitert.
- **Redirect-URI:** die `callback`-Adresse Ihres Brokers (Schritt 2).
- **Scopes:** nur die nötigen anfordern (MUST). Bewährt hat sich `openid profile traffiqx:invoice offline_access`:
  - `profile` ist nötig, weil der Name der Person angezeigt werden muss, die das Token ausgestellt hat (Userinfo).
  - `offline_access` liefert das Langzeit-Refresh-Token (6 Monate ab Anmeldung). Es muss bei DATEV für die App beantragt und freigeschaltet sein. Ohne es gilt das Refresh-Token nur 11 Stunden ab der Anmeldung, der Kunde müsste sich also täglich neu anmelden.
- **Umgebungen:** Sandbox (`platform-sandbox`) und Produktion (`platform`). Für die Produktionsfreigabe lädt DATEV in einen Testbestand ein. Mit echten Kundendaten sollte man dort nicht testen.

## 2. OAuth2-Broker betreiben

Diese Bibliothek empfängt den Redirect des OAuth2-Flows nicht im Desktop-Programm selbst (etwa über einen lokalen Loopback-Listener nach RFC 8252, der ist nicht umgesetzt), sondern über einen Broker. Der Broker in `OAuth2-Broker/` übernimmt das: Er startet den Authorization Code Flow mit PKCE, nimmt den Code am `callback` entgegen, tauscht ihn gegen die Tokens und hält sie kurz bereit, bis der Client sie per Polling abholt. Einrichtung und Betrieb stehen in der [README](README.md) und in `OAuth2-Broker/README.md`.

- Jeder Hersteller betreibt einen eigenen Broker unter eigener Domain. Die im Sample hinterlegte Adresse ist nur ein Beispiel.
- Der Broker speichert die Tokens nicht dauerhaft; nach dem Abholen löscht er die Sitzung.
- **Client-Secret:** In der aktuellen Form schickt der Client das Secret beim Start an den Broker, und Token-Erneuerung, Widerruf und Introspection laufen mit Secret vom Client aus. Das Secret steckt damit in der ausgelieferten Software. Wer das vermeiden will, verlagert Token-Austausch, Erneuerung und Widerruf in den eigenen Server bzw. Broker. Das ist in dieser Bibliothek noch nicht umgesetzt.

## 3. Architektur festlegen: Wo liegen die Tokens?

Diese Entscheidung prägt alles Weitere, und DATEV fragt im Termin danach (MUST: Architektur und Token-Ablage erklären, [`Abnahme.md`](Abnahme.md) 6.4). Maßgeblich sind drei Regeln aus 6.1 und 6.3:

1. **Refresh-Tokens sind nur einmal einlösbar.** Löst jemand dasselbe Refresh-Token ein zweites Mal ein, wird die ganze Sitzung ungültig.
2. **Nie mehr als ein gültiges Refresh-Token.** Vor einer neuen Anmeldung die alte Verbindung widerrufen.
3. **Tokens verschlüsselt speichern.**

Daraus folgen zwei tragfähige Varianten:

**A. Einzelplatz.** Ein Programm auf einem Rechner hält die Tokens selbst.
- Ablage verschlüsselt, an den Windows-Benutzer gebunden: `TTraffiqxTokenProtection.ProtectToText(..., tpsCurrentUser)`.
- Erneuern nur aus einem Thread und nur in einer Instanz des Programms.

**B. Mehrere Arbeitsplätze.** Ein zentraler Prozess (Dienst, Anwendungsserver) verwahrt das Refresh-Token und gibt an die Arbeitsplätze nur Access-Tokens aus.
- Ablage verschlüsselt, an den Server-Rechner gebunden (`tpsLocalMachine`). Die Datei bzw. Datenbank per Dateirechten auf das Dienstkonto beschränken: Jeder lokale Benutzer mit Dateizugriff könnte sonst entschlüsseln.
- Erneuern unter einer Sperre: innerhalb der Sperre den gespeicherten Stand neu lesen, erneuern, speichern. So löst nie ein zweiter Aufruf dasselbe Refresh-Token ein.
- Erneuern bei Bedarf, zum Beispiel wenn das Access-Token weniger als 2 Minuten gilt. Kein Dauerabruf.
- Scheitert das Speichern nach einem erfolgreichen Erneuern, das neue Token im Speicher behalten und später nachschreiben. Das alte ist verbraucht und darf nicht wieder geladen werden.
- Ist das Ergebnis eines Erneuerns unklar (Verbindungsabbruch nach dem Senden), das alte Token nicht vorschnell verwerfen. Lehnt DATEV es beim nächsten Versuch mit `invalid_grant` ab, ist eine neue Anmeldung nötig.
- Die Anmeldung mit Browser bleibt am Arbeitsplatz. Er übergibt die Tokens danach an den zentralen Prozess, der eine bestehende Sitzung vorher widerruft.

**Nicht tragfähig:** eine gemeinsame Datei mit dem Refresh-Token, aus der mehrere Programme lesen, erneuern und zurückschreiben. Zwei gleichzeitige Erneuerungen machen die Sitzung ungültig, und eine Dateisperre löst das über Netzlaufwerke nicht verlässlich.

**Zeiten in UTC speichern.** In der Herbststunde ist die Ortszeit mehrdeutig. Die Bibliothek liefert die Ablaufzeiten deshalb zusätzlich in UTC: `TTraffiqxPollResult.AccessTokenExpiresAtUtc` und `RefreshTokenExpiresAtUtc` nach der Anmeldung, `TTraffiqxTokenIntrospection.ExpiresAtUtc` aus der Introspection.

## 4. Bibliothek einbinden

```pascal
uses
  intf.TRAFFIQXInvoiceAPI, intf.TRAFFIQXHttpLog, intf.TRAFFIQXTokenProtection;

// einmal beim Programmstart
TTraffiqxHttpLog.ResolveDirectory :=
  function: String
  begin
    Result := 'X:\Pfad\zum\Protokoll\';   // bei mehreren Arbeitsplaetzen: gemeinsames Verzeichnis
  end;

// je Vorgang
Api := TTRAFFIQXInvoiceAPI.Create;
Api.ClientId := ...;                      // aus dem Developer Portal
Api.ClientSecret := ...;                  // siehe Abschnitt 2
Api.AppDisplayName := ...;                // exakt der registrierte App-Name
Api.Scope := 'openid profile traffiqx:invoice offline_access';
Api.OAuth2BrokerCallbackUri := 'https://ihr-broker.example/callback';
Api.OAuth2BrokerApiKey := ...;
Api.ProviderType := tpDatev;
Api.Environment := teProduction;
Api.TRAFFIQXId := KundenTraffiqxId;       // "TX:" und Leerraum entfernt die Property selbst
TTraffiqxHttpLog.Attach(Api);             // technisches HTTP-Protokoll (Abschnitt 10)
if not Api.TryFetchWellKnownEndpoints then  // liefert Userinfo-, Introspection- und Revoke-Endpunkt
  ...;                                    // ohne sie scheitern GetUserInfo, IntrospectToken, RevokeTokens
```

- **TRAFFIQX-ID:** Die API erwartet im Pfad nur die Ziffernfolge. Mit `TX:0012001064105` antwortet sie mit HTTP 400. `TraffiqxNormalizeId` bzw. die Property `TRAFFIQXId` entfernen das Präfix. In der Rechnung (BT-10) steht die Empfänger-ID dagegen **mit** Präfix (Abschnitt 8).
- **Provider:** DATEV darf fest hinterlegt werden (MUST: zeigen, wo der Kunde Provider und TRAFFIQX-ID pflegt). Andere TRAFFIQX-Provider lassen sich über `SetProviderByConfigurationToken` anbinden (SHOULD).

## 5. Anmeldung und Verbindungsoberfläche

Ablauf einer Anmeldung, wie ihn die Vorgaben verlangen ([`Abnahme.md`](Abnahme.md) 1 und 6.3):

1. **Bestehende Verbindung widerrufen** (`RevokeTokens`), damit nie zwei gültige Refresh-Tokens existieren.
2. **Anmeldung starten:** `StartAuth` öffnet die DATEV-Anmeldung im Standardbrowser. Das ist der empfohlene Weg: RFC 8252 (Abschnitt 8.12) untersagt nativen Anwendungen eingebettete Browser für die OAuth-Anmeldung (MUST NOT), weil die Anwendung dort Eingaben und Sitzungscookies mitlesen könnte. Technisch lässt sich die Adresse über `OnOpenAuthUrl` auch in ein eingebettetes Fenster (etwa WebView2) leiten; das weicht von dieser Vorgabe ab und sollte deshalb nur nach Abstimmung mit DATEV genutzt werden. Danach `BeginPolling`; das Ergebnis kommt über `OnPollingCompleted` im Hauptthread.
3. **Neutraler Verbindungscheck** sofort danach: `CheckConnectionAccess` prüft Inbox und Outbox mit kleinem Filter und gelingt nur, wenn **beide** mit HTTP 200 antworten. Die Vorgabe verlangt den Check nur für die Bereiche, die die Anwendung nutzt. Wer nur den Posteingang oder nur den Postausgang anbindet, prüft deshalb selbst den jeweiligen Status-Endpunkt (`GetInboxDocumentIds` bzw. `GetOutboxDocumentIds` mit Filter), sonst würde eine brauchbare Verbindung wegen fehlender Rechte im anderen Bereich widerrufen.
4. **Scheitert der Check:** den Kunden informieren, Hilfe anbieten (SHOULD) und die Tokens sofort widerrufen (`RevokeTokens`, MUST).
5. **Person und Laufzeit ermitteln:** `GetUserInfo` (Name, braucht Scope `profile`), Ablauf aus dem Polling-Ergebnis (`RefreshTokenExpiresAtUtc`), gegengeprüft mit `IntrospectToken(RefreshToken, 'refresh_token', ...)`. Alle Tokens sind opak; die Gültigkeit kennt nur die Introspection.
6. **Tokens verschlüsselt ablegen** (Abschnitt 6).

Die Verbindungsoberfläche braucht laut [`Abnahme.md`](Abnahme.md) 6.3:

- eine Schaltfläche „Mit DATEV verbinden“ und eine „Verbindung trennen“ (Widerruf bei DATEV, lokale Tokens erst danach löschen),
- einen Status auf einen Blick (Ampel),
- den Namen der Person, die das Token ausgestellt hat,
- das errechnete Ablaufdatum des Refresh-Tokens, mindestens `TT.MM.JJJJ HH:MM`,
- beim Langzeit-Token den Datenbestand, bei TIA die TRAFFIQX-ID,
- einen Link auf „Verbundene Anwendungen“ (`https://apps.datev.de/tokrevui`).

Tokens selbst nie anzeigen (DONT).

**Übergabe an einen zentralen Prozess (Variante B).** Scheitert die Übergabe der frisch erhaltenen Tokens, kommt es auf die Art des Fehlers an:
- Hat der Server eindeutig abgelehnt, widerruft der Arbeitsplatz die Tokens selbst.
- Ist das Ergebnis unklar (Verbindungsabbruch), die Tokens festhalten und nachfragen, ob der Server sie hat.

Dafür eignet sich der Fingerabdruck der Anmeldung (`TTraffiqxTokenProtection.Fingerprint`): Der Server speichert ihn zur Sitzung, der Arbeitsplatz vergleicht, ohne dass ein Token übertragen oder angezeigt wird. Den Fingerabdruck bei der Anmeldung festhalten, denn das Refresh-Token wechselt bei jeder Erneuerung. Bis das geklärt ist, keine neue Anmeldung zulassen.

## 6. Token-Lebenszyklus

- **Laufzeiten** ([`Abnahme.md`](Abnahme.md) 6.1):
  - Access-Token 30 Minuten.
  - Refresh-Token 11 Stunden bzw. mit `offline_access` 6 Monate ab der Anmeldung. Beim Erneuern verlängert es sich nicht.
  - `DefaultRefreshTokenExpiresAt` rechnet das Ablaufdatum ab der Anmeldung aus.
- **Erneuern:** `RefreshAccessToken` tauscht Access- und Refresh-Token aus. Das neue Refresh-Token sofort speichern; das alte ist verbraucht. Bei Ablehnung (`invalid_grant`) ist eine neue Anmeldung nötig.
- **Lange Läufe** (etwa ein Abruf vieler Eingangsrechnungen): vor jedem Dokument prüfen, ob das Access-Token noch reicht.
- **Fehlertexte beim Erneuern** können Rohantworten des Token-Endpunkts enthalten. Nicht ungeprüft anzeigen oder protokollieren, sondern eigene, feste Meldungen verwenden.
- **Ablage:** `TTraffiqxTokenProtection.ProtectToText` / `UnprotectFromText` (DPAPI, Text `dpapi:<Base64>`). Sind die Tokens nicht mehr lesbar (anderer Rechner oder Benutzer), neu anmelden. Achtung bei INI-Dateien: `TIniFile.ReadString` liest höchstens 2047 Zeichen, verschlüsselte Tokens sind länger. Zum Lesen `TMemIniFile` verwenden (siehe Sample, `ReadToken`).
- **Trennen:** `RevokeTokens` widerruft Refresh- und Access-Token. Die lokale Ablage erst nach erfolgreichem Widerruf löschen, sonst bleibt eine Verbindung bei DATEV bestehen, die der Kunde nur noch über „Verbundene Anwendungen“ los wird.
- **Endsession** (Browsersitzung am DATEV-Login beenden) ist in der Bibliothek noch nicht umgesetzt; dafür müsste das ID-Token aufbewahrt werden.

## 7. Posteingang

- **Abgleich:** `GetInboxDocumentIds` liefert den Posteingang, mit `AUseDownloadedFilter` nur noch nicht geladene Dokumente. Einmal initial abgleichen und danach synchron halten (MUST), aber nicht rund um die Uhr abfragen (DONT), sondern bei konkretem Anlass, etwa wenn der Kunde den Posteingang öffnet.
- **Metadaten:** `GetInboxDocumentMetadata` liefert `document_format` und `en_16931_compliant`. Beides dem Kunden anzeigen, ungültige E-Rechnungen deutlich kennzeichnen (MUST).
- **Download:** `DownloadInboxDocument` liefert immer ein ZIP. Die Dokumente muss der Kunde ansehen können (MUST). Die `document_id` bleibt für den Kunden sichtbar.
- **Archivierung:** Die Plattform archiviert nicht GoBD-konform. Den Kunden in der Oberfläche darauf hinweisen, wo seine Eingangsrechnungen archiviert werden (MUST).

## 8. Postausgang

- **Upload:** `UploadStructuredData` (XRechnung als XML plus PDF-Sichtkomponente) oder `UploadZugferdData` (ZUGFeRD-PDF). Die zurückgelieferte `document_id` speichern und dem Kunden zeigen.
- **Status:** `WaitForOutboxDocumentSent` fragt standardmäßig alle 8 Sekunden ab und gibt nach 1 Minute auf (Vorgabe aus dem Termin; beides sind Parameter). Die Zeitgrenze wird jeweils nach einer Abfrage geprüft, die letzte Abfrage kann also kurz nach der Minute liegen. Die Laufzeit des Access-Tokens prüft die Methode nicht: Das Polling muss innerhalb dieser Laufzeit bleiben (MUST), also vor dem Warten sicherstellen, dass das Access-Token noch deutlich länger gilt als die Wartezeit, mit Reserve für ein weiteres Intervall und die Antwortzeit (bei den Voreinstellungen etwa 2 Minuten), und es sonst vorher erneuern. Alle Statuswerte verarbeiten: `inProcess`, `sent`, `error`, `deleted`, `userAction`. Ist nach einer Minute noch nicht `sent` erreicht, den Stand später erneut abfragen, etwa beim nächsten Öffnen der Rechnung.
- **Erst nach `sent`:**
  - `GetOutboxDocumentMetadata` abrufen und Versandformat, Versanddatum, Versandkanal und Versandadresse anzeigen. Dabei den gewollten Kanal gegen den tatsächlichen `delivery_channel` prüfen (MUST).
  - `DownloadOutboxDocument` abrufen: das von der Plattform erzeugte Original für die Archivierung. HTTP 202 heißt „noch nicht bereit“; die Bibliothek liefert dann den Status statt des Inhalts.
- **Original archivieren:** Das Download-ZIP enthält je nach Kanal andere Dateinamen, beim E-Mail-Kanal zum Beispiel die XML unter einem Namen aus Rechnungsnummer und Datum. Nicht auf feste Namen im ZIP verlassen, sondern nach Dateityp suchen und unter eigenem, festem Namen ablegen.

**Stolpersteine bei XRechnung** (auf Produktion beobachtet, siehe [`Abnahme.md`](Abnahme.md) 6.5):

- **BT-10 (Käuferreferenz) nie leer lassen.** Ein leeres `<cbc:BuyerReference/>` lehnt DATEV mit `VALIDATION_DRAFT_ERROR` / `DRAFT_NON_COMPLIANT` ab. Ohne Leitweg-ID oder TRAFFIQX-ID einen Platzhalter wie `non-existent` setzen.
- **Präfix `TX:`:** In BT-10 steht die TRAFFIQX-ID des Empfängers **mit** `TX:`, im API-Pfad **ohne**.
- **Eigene TRAFFIQX-ID:** Eine Rechnung an die eigene TRAFFIQX-ID wird abgelehnt (`RECEIVER_IS_SENDER_TRAFFIQXID`). Für Tests fremde Empfänger verwenden.
- **Keine XRechnung-Extension:** Als Extension deklarierte Rechnungen lehnt die Plattform ab (`DRAFT_UNSUPPORTED_FORMAT`).
- **Vorher validieren:** Die Rechnung vor dem Upload validieren, etwa mit dem KoSIT-Validator. Die Plattform meldet Validierungsfehler nur pauschal.

## 9. Fehler anzeigen

- Die TIA-Fehlerantworten sind RFC-7807-ProblemDetails. Bei 4xx-Fehlern mindestens die Hilfe-URL anzeigen (MUST). `TTraffiqxInboxErrorHelper.HelpUrl(Error)` liefert sie, `BuildUserMessage` einen Text für den Kunden.
- Bei einem fehlgeschlagenen Verbindungscheck zusätzlich eigene Hilfe anbieten, etwa Support-Kontakt oder Anleitung (SHOULD).
- Tokens und Secrets gehören in keine Meldung, keinen Screenshot und kein Protokoll (DONT).

## 10. HTTP-Protokoll und Fehlerquote

DATEV verlangt ein technisches Protokoll aller Aufrufe, mindestens 14 Tage aufbewahrt, ohne Tokens ([`Abnahme.md`](Abnahme.md) 6.4). Nach der Freigabe muss die Fehlerquote unter 10 % bleiben.

- Die Bibliothek meldet jede Anfrage und Antwort über `OnHttpTrace`. Die Tokens sind dabei schon herausgefiltert, einschließlich Anmeldung, Polling, Erneuerung und Widerruf.
- `intf.TRAFFIQXHttpLog.pas` schreibt diese Meldungen in eine Datei pro Tag, räumt nach 14 Tagen auf und wertet die Fehlerquote aus (`GetErrorRate`). Mehrere Programme dürfen in dasselbe Verzeichnis schreiben, das ist bei Variante B der sinnvolle Weg: ein Protokoll für Server und Arbeitsplätze.
- Die Auswertung liest Dateien, gegebenenfalls über das Netz. In einer Oberfläche deshalb im Hintergrund auswerten und das Verzeichnis vorher im Hauptthread bestimmen (siehe Kommentar in der Unit).
- Häufige Ursachen für eine hohe Fehlerquote sind:
  - abgelaufene Access-Tokens, die nicht vorher erneuert wurden (401),
  - falsch formatierte TRAFFIQX-IDs (400),
  - fehlende Rechte des Anmelders auf die TRAFFIQX-ID (403).

## 11. Abnahmetermin vorbereiten

- **Checkliste:** [`Abnahme.md`](Abnahme.md) Abschnitt 7 Punkt für Punkt durchgehen.
- **Challenges im Postausgang:** eine E-Rechnung je Kanal (E-Mail, TRAFFIQX, Peppol) bis `sent` und mindestens eine bis `error`. Dafür werden Empfänger außerhalb des eigenen Datenbestands gebraucht (siehe Abschnitt 8); am einfachsten ein zweiter, eigener DATEV-Bestand mit eigener E-Mail-Empfangsadresse, TRAFFIQX-ID und Peppol-ID.
- **Architektur erklären können.** Bewährt hat sich, diese Punkte schriftlich vorzubereiten:
  - welche Programme es gibt und wo sie laufen,
  - wo die Anmeldung stattfindet und welche Rolle der Broker spielt,
  - wo die Tokens liegen und wie sie verschlüsselt sind,
  - wer sie wann erneuert und wie ein doppeltes Einlösen verhindert wird,
  - wie Tokens im eigenen Netz transportiert werden,
  - was beim Trennen passiert,
  - wo das HTTP-Protokoll liegt.
- **Entitäten:** erklären, wie die eigenen Mandanten bzw. Datenbestände mit TRAFFIQX-IDs und Tokens zusammenhängen, etwa eine Verbindung je Mandant und TRAFFIQX-ID.
- **Kundensicht zeigen:** nicht nur API-Aufrufe vorführen, sondern die Oberfläche. Dazu gehören Verbindungsstatus, `document_id`, Validierungsstatus, Versandinformationen und der GoBD-Hinweis.
