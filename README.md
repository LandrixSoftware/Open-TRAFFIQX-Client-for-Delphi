# TRAFFIQX Invoice API Demo und OAuth2 Broker

Dieses Repository enthält einen Delphi-Client für die TRAFFIQX/DATEV Invoice API und einen kleinen PHP-basierten OAuth2-Broker. Ziel ist eine nachvollziehbare Referenzimplementierung für Anmeldung, Token-Vermittlung, Inbox-/Outbox-Zugriffe und manuelle Sandbox-Tests mit elektronischen Rechnungen.

Wer TIA in die eigene Software einbauen und die DATEV-Produktionsfreigabe erreichen will, beginnt mit [`Integration.md`](Integration.md) (Vorgehen Schritt für Schritt) und [`Abnahme.md`](Abnahme.md) (Vorgaben von DATEV und Checkliste).

## Komponenten

- `OAuth2-Broker/`: PHP-Service für den OAuth2 Authorization Code Flow mit PKCE. Desktop-Clients starten den Flow über `/start`, der Provider ruft `/callback` auf und der Client holt das Ergebnis über `/poll` ab. Details stehen in `OAuth2-Broker/README.md`.
- `client/Delphi/`: Delphi-Clientbibliothek und VCL-Sample für Provider-Auswahl, Login, Token-Refresh, Inbox, Outbox, Upload, Metadata, Download und Statusabfragen.
- `OAuth2-Broker/session-store/`: Lokales Runtime-Verzeichnis für temporäre Broker-Sessions. Nur `.gitignore` gehört ins Repository, die entstehenden JSON-Dateien bleiben lokal.
- `testdata/`: Synthetische Beispielrechnungen (XRechnung UBL/CII, ZUGFeRD) für manuelle Upload-Tests, erzeugt mit `client/Delphi/Sample/XRechnungUnit2TestCases.pas`. Alle Namen, Adressen, Steuernummern und IBANs sind Dummywerte. Einige Fälle enthalten bewusst Fehler (z. B. leere Käuferreferenz BT-10), um die Validierung der Plattform zu prüfen.

## Voraussetzungen

- PHP 8.2 oder neuer für den OAuth2-Broker.
- Composer für die PHP-Abhängigkeiten.
- Webserver mit PHP-Unterstützung oder PHPs eingebauter Server für lokale Smoke-Tests.
- Delphi mit VCL und WebView2-Unterstützung für das Sample-Projekt. Erstellt und getestet mit Delphi 13.2 Florence; die Bibliothek selbst braucht mindestens Delphi 10.3 (Inline-Variablen) und `System.Net.HttpClient`.
- Für das Sample zusätzlich [XRechnung-for-Delphi](https://github.com/LandrixSoftware/XRechnung-for-Delphi) (erzeugt die Testrechnungen). Das Projekt erwartet es als Nachbarverzeichnis `src-XRechnung-for-Delphi` neben diesem Repository; sonst den Suchpfad in `TIAProject.dproj` anpassen. Die Clientbibliothek (`intf.TRAFFIQX*.pas`) selbst hat keine Abhängigkeiten außerhalb der Delphi-RTL.
- Provider-Zugangsdaten und Redirect-URI für DATEV/TRAFFIQX oder einen kompatiblen OAuth2-Provider.

## OAuth2-Broker Einrichten

1. In den Broker wechseln:

```bash
cd OAuth2-Broker
```

2. PHP-Abhängigkeiten installieren:

```bash
composer install --no-dev
```

Falls Composer nur lokal genutzt wird, kann `composer.phar` verwendet werden. Diese Datei wird nicht committed.

3. Lokale Konfiguration erstellen:

```bash
cp config/app.php config/app.local.php
```

Unter Windows PowerShell:

```powershell
Copy-Item config/app.php config/app.local.php
```

4. In `config/app.local.php` eigene API-Keys setzen. Diese Datei enthält Secrets und bleibt lokal.

5. Schreibrechte auf `OAuth2-Broker/session-store/` sicherstellen. Der Broker schreibt dort pro OAuth2-Session eine temporäre JSON-Datei.

6. Webroot auf `OAuth2-Broker/src` setzen. `config/`, `vendor/` und `session-store/` dürfen nicht direkt ausgeliefert werden.

Lokaler Smoke-Test:

```bash
php -S 127.0.0.1:8080 -t src
curl http://127.0.0.1:8080/
```

Erwartet wird eine JSON-Antwort mit `"status":"ok"`.

## Delphi-Client Verwenden

1. `client/Delphi/DelphiProjectGroup.groupproj` oder `client/Delphi/Sample/TIAProject.dproj` in Delphi öffnen.
2. Lokale Zugangsdaten und Provider-Werte in der `.env` im Repository-Wurzelverzeichnis pflegen (ignoriert): je Provider `<PREFIX>_CLIENT_ID`, `_CLIENT_SECRET`, `_TRAFFIQX_ID`, `_SCOPE`, `_APP_NAME`, dazu `OAUTH2_BROKER_CALLBACK_URI` und `OAUTH2_BROKER_API_KEY` des eigenen Brokers sowie fuer das Erzeugen von XRechnung-Testfaellen `XRECHNUNG_DISTRIBUTION_DIR` (Distribution-Verzeichnis von XRechnung-for-Delphi). Das Sample legt Tokens verschluesselt in `client/cfg.ini` ab (ebenfalls ignoriert).
3. Sample starten und den gewünschten Provider bzw. die gewünschte Umgebung auswählen.
4. Login ausführen, anschließend Inbox-/Outbox-Funktionen im Sample testen.

Die zentrale Client-Implementierung liegt in `client/Delphi/intf.TRAFFIQXInvoiceAPI.pas`. Das Sample in `client/Delphi/Sample/` zeigt die Nutzung der API-Klasse inklusive Polling, Metadata-Auswertung, Downloads und Uploads.

### TRAFFIQX-Provider und Verbindungsschluessel

Der Delphi-Client kann Provider entweder ueber die bekannte Provider-Auswahl oder ueber einen TRAFFIQX-Verbindungsschluessel konfigurieren. `TTRAFFIQXInvoiceAPI.SetProviderByConfigurationToken` erwartet den JSON-String des Providers mit `well_known_url`, `api_url`, `traffiqx_id` und `provider_id`. Der Client uebernimmt daraus die TRAFFIQX-ID, ergänzt an der API-Basis-URL die umgesetzte API-Version `/v1`, sofern sie noch kein Versionssegment (`/v0`, `/v1` …) enthält, und liest Auth-/Token-Endpunkte ueber den `.well-known`-Endpunkt nach.

Aktuell sind Produktionsendpunkte fuer DATEV E-Rechnungsplattform, DATEV SmartTransfer, b4value.net, Bundesdruckerei, Quadient, SGH und Ricoh hinterlegt. Nicht-DATEV-Provider nutzen den Header `X-traffiqx-Client-ID`; DATEV E-Rechnungsplattform und DATEV SmartTransfer nutzen `X-Datev-Client-ID` und bei Bedarf `X-App-Display-Name`. Sandbox ist fachlich nur fuer DATEV E-Rechnungsplattform vorgesehen; vorhandene nicht-DATEV-Sandbox-Werte sind Entwicklungs-/Altwerte.

Minimaler Configuration-Token-Test im Delphi-Code:

```pascal
if not TIA.SetProviderByConfigurationToken(ConfigurationTokenJson) then
	raise Exception.Create('Verbindungsschluessel konnte nicht gelesen werden.');
if not TIA.TryFetchWellKnownEndpoints then
	raise Exception.Create('OIDC-Konfiguration konnte nicht gelesen werden.');
```

## Typischer Ablauf

1. Desktop-Client erzeugt eine eindeutige `sessionId`.
2. Client ruft `POST /start` am Broker mit `X-Api-Key` und Provider-Konfiguration auf.
3. Broker legt eine Session im `session-store` an und leitet den Browser zum Provider weiter.
4. Provider ruft `/callback` auf; der Broker tauscht den Code gegen Tokens.
5. Client pollt `/poll?sessionId=...` und erhält `pending`, `success` oder `error`.
6. Nach `success` oder `error` löscht der Broker die Session-Datei.

Nach erfolgreichem Polling fuehrt das Delphi-Sample einen neutralen Verbindungscheck gegen Inbox und Outbox aus. Die Inbox wird mit leerem `from_date`-Filter geprueft, die Outbox mit dem Filter `status=inProcess` (kleine Antwort, DATEV-Vorgabe). Fuer beide Endpunkte gilt ausschliesslich HTTP `200` als erfolgreicher Verbindungsaufbau. Schlaegt dieser Check fehl, versucht der Client die erhaltenen Tokens ueber den per `.well-known` gelieferten `revocation_endpoint` zu widerrufen und loescht sie anschliessend lokal aus UI und `cfg.ini`. Liefert ein Identity Provider keinen `revocation_endpoint`, wird dies als Revocation-Fehler angezeigt und dokumentiert; die lokalen Tokens werden dennoch entfernt.

Nach erfolgreichem Verbindungscheck kann der Client die Person, die das Token ausgestellt hat, ueber `GetUserInfo` abfragen (Scope `profile` noetig) und das Refresh-Token ueber `IntrospectToken` am Identity Provider pruefen. Das Ergebnis liefert den Ablauf in Ortszeit (`ExpiresAt`) und in UTC (`ExpiresAtUtc`); wer Zeiten in UTC speichert, nimmt `ExpiresAtUtc`, weil die Ortszeit in der Herbststunde mehrdeutig ist. Ebenso liefert `TTraffiqxPollResult` nach der Anmeldung `AccessTokenExpiresAtUtc` und `RefreshTokenExpiresAtUtc`. Das Ablaufdatum eines neuen Refresh-Tokens berechnet `DefaultRefreshTokenExpiresAt` ab der Anmeldung: bei DATEV 11 Stunden, mit Scope `offline_access` 6 Monate. Beim Token-Refresh verlaengert es sich nicht. Die Vorgaben der DATEV-Produktionsfreigabe stehen in `Abnahme.md`, Abschnitt 6.

Fuer das technische HTTP-Protokoll meldet `OnHttpTrace` jede Anfrage der Bibliothek zweimal mit derselben `RequestId`: vor dem Senden (`htkRequest`: Zeitstempel in UTC, Methode, vollstaendige URL, Header) und nach der Antwort (`htkResponse`: HTTP-Code, Meldung, alle Antwort-Header, Dauer). Bei einem Transportfehler kommt die Antwort mit `StatusCode = 0` und `ErrorMessage`. Folgt der Client einer Weiterleitung, kommen Zwischenantwort und Folgeanfrage einzeln mit der RequestId `.1`, `.2` usw. Die Header `Authorization`, `X-Api-Key`, `Cookie` und `Set-Cookie` fehlen; geheime Parameter in URL und Headern (Tokens, `code`, `sessionId`, `state`) maskiert `RedactUrl`. Anfrage-Bodies werden nie uebergeben. Antwort-Bodies gibt es nur bei HTTP-Fehlern und Statusabfragen, maskiert durch `RedactSecrets`: JSON wird geparst und die Werte geheimer Schluessel werden zu `***`. Freitext (Nicht-JSON-Bodies und jeder JSON-Stringwert) wird nicht maskiert, sondern verworfen bzw. zu `***`, sobald ein geheimer Schluessel mit `:` oder `=` darin vorkommt; Werte in beliebigem Text lassen sich nicht verlaesslich abgrenzen. Das Ereignis kommt auch aus dem Polling-Thread der Anmeldung, der Empfaenger muss also threadsicher schreiben.

Einen fertigen Empfaenger liefert `intf.TRAFFIQXHttpLog.pas`: `TTraffiqxHttpLog.ResolveDirectory` legt das Verzeichnis fest, `TTraffiqxHttpLog.Attach(Api)` haengt das Protokoll an eine Instanz. Geschrieben wird eine Datei pro Tag (UTC, `TIA-HTTP_yyyy-mm-dd.log`) mit Rechner, Programm und Benutzer je Eintrag; mehrere Prozesse (etwa Server und Arbeitsplaetze) duerfen in dasselbe Verzeichnis schreiben. Ein Hintergrund-Thread schreibt, der HTTP-Aufruf wartet nie auf die Platte; ist die Datei gesperrt oder das Netzlaufwerk weg, wird nachgeschrieben. Dateien aelter als 14 Tage werden geloescht. `TTraffiqxHttpLog.GetErrorRate` wertet die Fehlerquote der letzten 14 Tage aus (Anfragen an `*.datev.de`, Antworten mit 4xx/5xx; DATEV-Vorgabe unter 10 %) und meldet unlesbare Dateien und ein unerreichbares Verzeichnis. Das Sample schreibt nach `client/http-log/` und zeigt die Quote ueber den Knopf "Fehlerquote".

Fuer die verschluesselte Token-Ablage (DATEV-Vorgabe) gibt es `intf.TRAFFIQXTokenProtection.pas`: `Protect`/`Unprotect` nutzen Windows DPAPI, wahlweise an den Windows-Benutzer gebunden (`tpsCurrentUser`, fuer ein Desktop-Programm) oder an den Rechner (`tpsLocalMachine`, fuer einen Dienst, der die Tokens fuer mehrere Arbeitsplaetze verwahrt). `ProtectToText`/`UnprotectFromText` liefern einen Text `dpapi:<Base64>` fuer INI-Dateien; Text ohne dieses Kennzeichen gilt als alte Klartext-Ablage. Grenzen je Bindung: Mit `tpsCurrentUser` kann kein anderer Benutzer die Tokens lesen; mit einem servergespeicherten (Roaming-)Profil kann derselbe Benutzer sie auch auf anderen Rechnern lesen. Mit `tpsLocalMachine` sind sie auf einem anderen Rechner (etwa aus einem Backup) nicht lesbar, fuer jeden lokalen Benutzer mit Dateizugriff aber schon, denn die Entropie steht im Programm; die Ablage gehoert daher per Dateirechten auf das Dienstkonto beschraenkt. Sind Tokens nicht lesbar, ist eine neue Anmeldung noetig. `Fingerprint` bildet aus einem Refresh-Token einen kurzen Fingerabdruck (16 Hex-Zeichen von SHA-256), um eine gespeicherte Sitzung einer Anmeldung zuzuordnen, ohne das Token zu zeigen. Das Sample speichert die Tokens so verschluesselt in `client/cfg.ini`.

## Sicherheit und Git-Hygiene

Nicht committen:

- `OAuth2-Broker/config/app.local.php`
- `OAuth2-Broker/session-store/*.json`
- `OAuth2-Broker/vendor/`
- `OAuth2-Broker/composer.phar`
- `client/cfg.ini`
- `.env*` und andere lokale Secret-Dateien

Committen:

- Broker-Quellen unter `OAuth2-Broker/src/`
- `OAuth2-Broker/config/app.php` mit Platzhaltern
- `OAuth2-Broker/composer.json` und `OAuth2-Broker/composer.lock`
- Delphi-Quellen unter `client/Delphi/`
- `.gitignore`-Platzhalter für Runtime-Verzeichnisse

Provider-Secrets, API-Keys, Access-Tokens und Refresh-Tokens dürfen nicht in Logs, Screenshots, Diffs oder Testdaten landen. Bei Verdacht auf Offenlegung sollten die betroffenen Keys rotiert und laufende Broker-Sessions gelöscht werden.

## Manuelle Tests

Für den Broker reicht als erster Check der Health-Endpunkt `/`. Ein vollständiger OAuth2-Test benötigt eine beim Provider registrierte Redirect-URI, die auf `/callback` zeigt.

Für den Delphi-Client werden die Tests aktuell manuell gegen die Sandbox ausgeführt:

- Login und Token-Refresh prüfen.
- Inbox-Liste, Metadata und Download prüfen.
- Outbox-Liste, Metadata, Status und Download prüfen.
- Strukturierte XML- oder ZUGFeRD-Testrechnung hochladen und Status bis `sent` beobachten.

## Wichtige Dateien

- `OAuth2-Broker/README.md`: Detaildokumentation für Installation, Endpunkte, Fehlerfälle und Broker-Betrieb.
- `OAuth2-Broker/config/app.php`: Basiskonfiguration ohne produktive Secrets.
- `OAuth2-Broker/src/start.php`: Start des OAuth2-Flows.
- `OAuth2-Broker/src/callback.php`: Provider-Callback und Token-Tausch.
- `OAuth2-Broker/src/poll.php`: Polling-Endpunkt für Desktop-Clients.
- `client/Delphi/intf.TRAFFIQXInvoiceAPI.pas`: Delphi-API-Client.
- `client/Delphi/intf.TRAFFIQXHttpLog.pas`: technisches HTTP-Protokoll und Fehlerquote (DATEV-Abnahme).
- `client/Delphi/intf.TRAFFIQXTokenProtection.pas`: verschluesselte Token-Ablage (DPAPI) und Fingerabdruck des Refresh-Tokens.
- `client/Delphi/Sample/TIAUnit1.pas`: VCL-Sample und manuelle Testoberfläche.
- `Integration.md`: Leitfaden fuer die Einbindung in eigene Software.
- `Abnahme.md`: Vorgaben von DATEV und Abnahme-Checkliste.

# Mitwirken / Contributing

Fehlermeldungen, Testfälle, Verbesserungen der Dokumentation und Pull Requests sind willkommen. Die Regeln, insbesondere zu Secrets, Testdaten und zur Lizenzierung von Beiträgen, stehen in [`CONTRIBUTING.md`](CONTRIBUTING.md). Sicherheitslücken bitte nicht als öffentliches Issue, sondern wie in [`SECURITY.md`](SECURITY.md) beschrieben an info@landrix.de melden.

Bug reports, test cases, documentation improvements and pull requests are welcome. Please read [`CONTRIBUTING.md`](CONTRIBUTING.md) first, in particular the rules on secrets, test data and contribution licensing. Please report vulnerabilities privately to info@landrix.de as described in [`SECURITY.md`](SECURITY.md) instead of opening a public issue.

# Lizenz / License

english version below

Die Bibliothek "Open-TRAFFIQX-Client-for-Delphi" unterliegt eine Doppellizenz. Sie können sie kostenlos
unter den Bedingungen der [GPL v3.0](https://www.gnu.org/licenses/gpl-3.0.en.html) verwenden, oder Sie erwerben
eine Lizenz zur kommerziellen Nutzung unter der [Landrix Software Commercial License](commercial.license.md)

Eine kommerzielle Lizenz gewährt Ihnen das Recht, Open-TRAFFIQX-Client-for-Delphi 
in Ihren eigenen Anwendungen zu verwenden. Lizenzfrei und ohne Verpflichtung zur 
Offenlegung Ihres Quellcodes oder Änderungen an die Landrix Software oder einer anderen Partei. 
Eine kommerzielle Lizenz gilt auf Dauer und berechtigt Sie kostenlos zu allen zukünftigen Updates.

Wer die Bibliothek in Anwendungen einsetzen will, die nicht unter der GPL v3.0 stehen, benötigt eine kommerzielle Lizenz. Sie gilt pro Firma.
Die Kosten dafür betragen 990,00 EUR zzgl. MwSt. pro Firma.

Bitte senden Sie eine E-Mail an info@landrix.de, um eine Rechnung mit den Zahlungsinformationen anzufordern.

Support- und Erweiterungsanfragen von lizensierten Benutzern werden bevorzugt behandelt. 
Neue Entwicklungen können abhängig von der für die Implementierung erforderlichen Zeit zusätzliche Kosten verursachen.

english version

The "Open-TRAFFIQX-Client-for-Delphi" library is dual-licensed. You may choose to use it under the restrictions of 
the [GPL v3.0](https://www.gnu.org/licenses/gpl-3.0.en.html) at no cost to you, or you may purchase 
a licence under the [Landrix Software Commercial License](./commercial.license.md)

A commercial licence grants you the right to use Open-TRAFFIQX-Client-for-Delphi in your own applications, 
royalty free, and without any requirement to disclose your source code nor any modifications to
Landrix Software to any other party. A commercial licence lasts into perpetuity, and 
entitles you to all future updates, free of charge.

A commercial licence is required to use the library in applications that are not licensed under the GPL v3.0. It is sold per company. 
The cost is 990,00 EUR plus VAT per company.

Please send an e-mail to info@landrix.de to request an invoice which will contain the bank details.

Support and enhancement requests submitted by users that pay for 
support will be prioritised. New developments may incur additional costs depending on time required for implementation.
