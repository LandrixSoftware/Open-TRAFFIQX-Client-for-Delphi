# TIA Mini-Anwendung – Scheiben S1 bis S6

Eigenständiges VCL-Projekt `TIAMiniApp.dproj` für Win32/Win64, jeweils Debug/Release.
Der Umfang folgt [`Sample2.md`](../../../Sample2.md): Stammdaten, JSON-Ablage und
Fenstergerüst, lokale XRechnung-Erzeugung, DATEV-Verbindung und Versand bis zum
abgelegten Original sowie Posteingang mit Wiederaufnahme. Die erweiterte
Protokollauswertung folgt in S7.
S3 führt Anmeldung, Check, Userinfo, Refresh und Widerruf aus; S4/S5 ergänzen Upload,
Status, Versandmetadaten und Originaldownload. S6 ergänzt den manuellen
Posteingangsabruf, Erstabgleich und die Gültigkeitsanzeige.

## Start und Bedienung

Das Projekt direkt in Delphi öffnen. Die EXE liegt wie beim bisherigen Sample unter
`Win32|Win64/Debug|Release`. Der Bibliotheks- und XRechnung-Suchpfad ist übernommen;
S2 verwendet zusätzlich `intf.Invoice`, `intf.XRechnung` und den Java-Prüfhelfer
aus dem benachbarten Repository `src-XRechnung-for-Delphi`. WebView2 wird nicht benötigt.

Im Reiter **Stammdaten** gibt es Rechnungssteller, Kunden und Testpositionen.
**Neu** öffnet einen leeren Editor, **Übernehmen** aktualisiert den Arbeitsspeicher,
**Löschen** entfernt den ausgewählten Eintrag. Beim Wechsel eines bearbeiteten
Eintrags wird nach Übernehmen, Verwerfen oder Abbrechen gefragt. **Speichern**
übernimmt auch offene Editoren und schreibt alle Daten auf die Platte. Beim
Schließen mit Änderungen wird erneut nachgefragt. Zahlen folgen dem lokalen
Windows-Zahlenformat; JSON-Zahlen sind davon unabhängig. Mengen und Geldbeträge
werden mit vier Nachkommastellen (`Currency`) geführt.

Die Umgebung ist zunächst Sandbox. Unter Rechnungssteller kann Produktion mit
Warnhinweis gewählt werden; derselbe Wert steht im Reiter **Verbindung**.
Bei gespeicherten Tokens, ausstehendem Widerruf, ungeklärter oder laufender Anmeldung
ist der Wechsel gesperrt. Die fiktiven Beispieldaten enthalten bewusst ungültige
Bank- und Steuerkennungen und sind keine versandfertige Rechnungsvorlage.

## Ablage und Konfiguration

`MiniApp.Storage` liefert Pfade unter `Daten` neben der EXE. Beim Start werden
`Daten`, `ausgang`, `eingang` und `httplog` angelegt. `InvoiceDirectory` und
`IncomingDocumentDirectory` liefern sichere Unterpfade ohne sie anzulegen.
`tokens.dat` enthält ab S3 die geschützten Tokens; `eingang-offen.txt` sichert ab S6 ausstehende Downloads.
Jede Build-Konfiguration hat damit ihren eigenen Datenbestand.

Fehlt `stammdaten.json`, erzeugt `TMiniAppData.LoadFromFile` vier Kunden, zwei
Testpositionen und den Rechnungszähler `TEST-0001`. Bei unlesbarer oder ungültiger
Datei bricht der Start ab; vorhandene Daten werden nicht zurückgesetzt.
Der vierte Kunde verwendet Peppol mit der fiktiven Kennung `DE000000000` und
Schema `9930`. Bestehende Stammdatendateien werden nicht um diesen Kunden ergänzt.
`SaveToFile` schreibt UTF-8-JSON über eine eindeutige Temp-Datei im selben Ordner,
`FlushFileBuffers` und `MoveFileEx(REPLACE_EXISTING | WRITE_THROUGH)`.

Eine exklusiv geöffnete `stammdaten.json.lock` verhindert konkurrierende Instanzen
auf demselben Bestand. Die leere Sperrdatei darf liegen bleiben; entscheidend ist
der offene Windows-Handle. `TMiniAppData` einmal laden und bis zum Programmende
halten; Modellzugriffe erfolgen im Hauptthread. Speichern ist nur in die beim
Laden gesperrte Datei möglich. `NextInvoiceNumber` erhöht und speichert den Zähler
vor der Rückgabe. Abgebrochene Vorgänge dürfen Nummernlücken hinterlassen. Den
Zähler nicht manuell zurücksetzen und alte Stammdaten nicht über einen aktiven
Rechnungsbestand zurückspielen.

`LoadClientConfig` liest zuerst die `.env` neben der EXE. Fehlt sie, wird bei der
Standard-Ausgabestruktur die `.env` in der Repo-Wurzel verwendet (fünf Ebenen nach
oben). Eine lokale Datei ersetzt die gesamte Repo-Konfiguration. Gelesen werden
wie beim Sample `PROVIDER_TPDATEV_CLIENT_ID`, `_CLIENT_SECRET`, `_TRAFFIQX_ID`,
`_SCOPE`, `_APP_NAME` sowie `OAUTH2_BROKER_CALLBACK_URI` und
`OAUTH2_BROKER_API_KEY` sowie optional `XRECHNUNG_DISTRIBUTION_DIR` als einfache
`NAME=WERT`-Zeilen. Relative Distributionspfade beziehen sich auf den Ordner
der verwendeten `.env`. Konfigurationswerte werden nicht
protokolliert. Ohne `.env` funktioniert die Stammdatenpflege ebenfalls.

`PlaceholderPdfPath` sieht `Belegbild-Platzhalter.pdf` neben der EXE vor, alternativ
im Sample2-Ordner zwei Ebenen darüber. S2 kopiert diese Datei unverändert als
`belegbild.pdf`; sie bildet die aktuellen Rechnungspositionen nicht ab.

## DATEV-Verbindung (S3)

**Mit DATEV verbinden** speichert zunächst die Stammdaten und öffnet die Anmeldung
im Standardbrowser. Provider ist fest DATEV. Die angezeigte TRAFFIQX-ID kommt aus
`PROVIDER_TPDATEV_TRAFFIQX_ID` der beim Start geladenen `.env`; zum Ändern zuerst
trennen, `.env` bearbeiten und neu starten. Für den vollständigen Namen muss der
konfigurierte Scope `profile` enthalten; Scopes werden nicht automatisch erweitert.

Bestehende Tokens werden vor jedem neuen Login widerrufen. Erst nach erfolgreichem
Widerruf startet die neue Anmeldung. **Abbrechen** beendet das lokale Login-Polling;
eine noch offene Browser-Anmeldung ebenfalls schließen. Gewinnt eine erfolgreiche
Rückmeldung das Rennen mit dem Abbruch, widerruft der Service die übernommenen
Tokens. Bei Abbruch, Timeout oder Polling-Fehler wird `login_unconfirmed=true` mit
Zeitpunkt atomar in `tokens.dat` gespeichert; beim Schließen bereits vor dem
Polling-Abbruch, beim direkten Freigeben auch ohne Fenster-Callback. Die Ampel
wird gelb: **Anmeldung abgebrochen – Verbindung bei DATEV prüfen**. Der Marker
bleibt nach einem Neustart erhalten. Vor dem nächsten Login fragt die Oberfläche
nach der Prüfung unter **Verbundene Anwendungen**; ein eigener Knopf öffnet die
DATEV-Seite. Nur **Ja** entfernt den Marker und erlaubt die neue Anmeldung;
**Nein** oder Schließen der Rückfrage lässt ihn erhalten. Ohne Rückfrage-Handler
startet der Service ebenfalls keinen neuen Login. Eine erfolgreiche Anmeldung
oder Trennen entfernt den Marker. Beim Trennen ohne bekannte Tokens wird nur der
lokale Marker entfernt; die mögliche DATEV-Verbindung muss manuell entfernt werden.
Scheitert das Speichern des Markers oder seiner Freigabe, bleibt eine neue Anmeldung
im laufenden Prozess gesperrt. Beim Freigeben werden die Callbacks abgehängt.
Es gibt kein Netzwerk-Polling im Leerlauf.

Nach der Anmeldung speichert der Service die Tokens sofort und prüft Inbox und
Outbox über `CheckConnectionAccess`. Nur zweimal HTTP 200 ergibt eine **grüne
Ampel**. Anschließend wird der Name über `GetUserInfo` gelesen und gespeichert.
Fehlt der Name oder scheitert Userinfo, bleibt das Ergebnis des Verbindungschecks
bestehen; ein Hinweis steht im Protokoll. Der Refresh-Ablauf erscheint als
`TT.MM.JJJJ HH:MM` in lokaler Zeit. Fehlt er im Login-Ergebnis, wird er mit
`DefaultRefreshTokenExpiresAt` ab Anmeldung berechnet. Ein reiner Anzeigetimer
setzt eine abgelaufene Verbindung auf rot.

**Verbindung prüfen** wiederholt Check und Userinfo. Nach einem Neustart bleibt
die Ampel bis zum Check rot (ungeprüft), auch bei lesbaren Tokens. Scheitert der
Check, versucht der Service sofort den Widerruf. **Verbindung trennen** widerruft
ebenfalls bei DATEV und entfernt anschließend alle Tokenwerte atomar aus der
lokalen JSON-Ablage. Scheitert der Widerruf, bleiben die Tokens verschlüsselt mit
`revocation_pending=true` gespeichert: **gelbe Ampel**, keine Token-Nutzung, kein
Refresh, kein neuer Login. **Mit DATEV verbinden** oder **Verbindung trennen**
versucht den Widerruf erneut, auch nach einem Neustart. **Verbundene Anwendungen**
öffnet <https://apps.datev.de/tokrevui> zur Verwaltung bei DATEV.

`TMiniAppService` verwendet seine Verbindungs-API ausschließlich im Hauptthread.
Die synchronen Verbindungsabläufe zeigen eine Sanduhr; Netzstörungen können die
Oberfläche bis zum HTTP-Timeout blockieren. Versand/Status und Posteingang laufen in
`TTask.Run` mit einer eigenen API (siehe S4/S5 unten). Abschluss- und Anzeige-Callbacks
warten nicht auf Threads und rufen weder `ProcessMessages` noch `CheckSynchronize` auf. Nur das Ereignis
`OnConfirmLoginUnconfirmed` darf vor einem neuen Login ohne laufendes Polling eine
modale Rückfrage öffnen; der Service bleibt ohne VCL-Abhängigkeit. Der statische
`TTraffiqxHttpLog`
schreibt auch die Polling-Anfragen threadsicher nach `Daten/httplog/`, mit 14 Tagen
Aufbewahrung. Er hält keine Referenz auf das Fenster oder den Service.

`EnsureAccessToken(AMinValidSeconds)` wird vor Versand/Status mit 120 Sekunden verwendet:
bei zu kurzer Access-Laufzeit Refresh durchführen und die rotierten Tokens sofort
speichern. Vor dem Single-Use-Austausch wird ein Widerrufmarker persistiert, damit
ein Absturz oder unklarer Transportfehler nicht zur erneuten Verwendung des alten
Refresh-Tokens führt. Erst nach erfolgreichem Austausch wird der Marker mit den
neuen Tokens zurückgesetzt. `IsInvalidGrant` verwirft die Tokens und meldet
„nicht verbunden – bitte neu verbinden“. Scheitert das Speichern neuer Tokens,
versucht der Service deren sofortigen Widerruf.

`tokens.dat` ist JSON (`format=MiniApp.Tokens.v1`): `access_token` und
`refresh_token` sind DPAPI-Texte (`dpapi:…`, Bindung `tpsCurrentUser`),
`access_expires_at`/`refresh_expires_at` numerische lokale Delphi-Zeitpunkte
(0 = unbekannt), dazu `revocation_pending`, `login_unconfirmed` und
`login_unconfirmed_at` (lokaler Delphi-Zeitpunkt, 0 ohne Marker), `user_name`,
`environment`, `client_id` und `traffiqx_id`. Ältere v1-Dateien ohne Anmeldemarker
bleiben lesbar. Die letzten drei Felder verhindern die Verwendung mit einer
anderen Konfiguration. Speichern nutzt die atomare Ablage mit Flush und
Dateiaustausch. Klartext-Tokens werden nicht importiert.

Unlesbare, nicht entschlüsselbare oder unpassend gebundene Ablagen bleiben
unverändert. Der Service gilt als nicht verbunden und sperrt neue Anmeldungen,
damit die alte DATEV-Verbindung nicht unbemerkt bestehen bleibt. Ursprünglichen
Windows-Benutzer und ursprüngliche Konfiguration wiederherstellen und neu starten;
alternativ die alte Verbindung in **Verbundene Anwendungen** widerrufen, die
unlesbare Datei manuell sichern/entfernen und neu starten. Bei Schreibfehlern
bleiben erneuerte Tokens im laufenden Prozess für den Widerruf verfügbar; bei
gleichzeitigem Netz- und Plattenausfall ist eine dauerhafte Sicherung nicht möglich.
Nach einem solchen Fehler die Verbindung bei DATEV prüfen, bevor erneut angemeldet
wird. Tokens und Secrets erscheinen weder in Statusfeldern noch in Servicemeldungen.
Die Grenzen der Schwärzung im technischen HTTP-Protokoll sind im
[Repository-README](../../../README.md) beschrieben.

API-Fehler laufen gemeinsam über `TTraffiqxInboxErrorHelper`: verständlicher Text
im Protokoll und ein anklickbarer Hilfelink in **Verbindung** und **Protokoll**.
Bekannte Fehlercodes verwenden ihre Lösungshilfe, sonst die HTTP(S)-`type`-URL;
ohne spezifische URL dient die DATEV-Produktdokumentation als Rückfall. Der Link
öffnet die Hilfe zum letzten API-Fehler. Im Polling-Abschluss werden keine modalen
Dialoge geöffnet.

## Bekannte Grenzen

- Ein lokaler Eingangsbestand gehört dauerhaft zu genau einer Umgebung und
  TRAFFIQX-ID (`eingang-kontext.json`); auch nach Trennen und leerer Offen-Liste
  wird er nicht automatisch umgebunden. Für andere Kombinationen getrennte
  Programmkopien mit eigenem `Daten`-Ordner verwenden. Die lokale Eingangsliste
  bleibt bei einem Verbindungswechsel sichtbar; Netzwerkaktionen für diesen
  Bestand brechen bei abweichender Bindung ab.
- Ältere Eingangsbestände ohne Kontextdatei werden nicht automatisch zugeordnet.
  Vor der Übernahme Anwendung schließen, `Daten` sichern und die ursprüngliche
  Umgebung sowie TRAFFIQX-ID anhand der bisherigen Konfiguration/HTTP-Protokolle
  prüfen. Nur bei eindeutig einheitlicher Herkunft `Daten/eingang-kontext.json`
  als UTF-8-JSON mit `format="MiniApp.InboxContext.v1"`,
  `environment="sandbox"` oder `"production"` und `traffiqx_id` als JSON-Textfeld
  mit der ursprünglichen ID anlegen. Unklare/gemischte Bestände zunächst manuell
  zuordnen; Vormerkungen nicht löschen, um die Sperre zu umgehen. Defekte oder
  verlorene Kontextdateien aus der passenden Sicherung wiederherstellen.
- Eine abgebrochene Anmeldung kann bei DATEV trotzdem eine Verbindung erzeugt
  haben, deren Tokens lokal unbekannt sind. Der gelbe Status und die Rückfrage
  vor einem neuen Login ersetzen keinen Widerruf: offene Browser-Anmeldung schließen
  und unter [Verbundene Anwendungen](https://apps.datev.de/tokrevui) prüfen und
  eine nicht benötigte Verbindung entfernen.
- Geht die Antwort eines Refresh verloren, bleibt das neue Token bei DATEV gültig,
  ist lokal aber unbekannt. Auch hier die Verbindung unter **Verbundene Anwendungen**
  prüfen und entfernen; ein Widerruf des lokal bekannten alten Tokens genügt nicht
  als Nachweis, dass das neue Token entfernt wurde.
- `tokens.dat` enthält den Namen der Person, Client-ID und TRAFFIQX-ID im Klartext;
  die Tokens selbst sind mit DPAPI verschlüsselt.
- Das technische HTTP-Protokoll liegt im Beispiel sichtbar unter `Daten\httplog`.
  Eine echte Anwendung muss es für Kunden nicht sichtbar ablegen.
- Eine zweite Programminstanz auf demselben Datenbestand wird durch die Sperre
  für `stammdaten.json` (`stammdaten.json.lock`) verhindert. Getrennte Datenordner
  teilen diese Sperre nicht.
- Ungeklärte Uploads (etwa nach Transportabbruch oder HTTP 201 ohne lesbare ID)
  bleiben dauerhaft gesperrt. Das Sample bietet keine automatische Auflösung;
  Stand bei DATEV und HTTP-Protokoll müssen vor einer manuellen Reparatur geprüft werden.
- Die Originalablage liest das ZIP vollständig in den Arbeitsspeicher und begrenzt
  die entpackte Gesamtgröße auf 256 MiB. Größere Originale werden nicht archiviert;
  abweichende bereits vorhandene Originale erfordern eine manuelle Prüfung.
- Der lokale Originalordner allein gewährleistet keine GoBD-konforme Archivierung.
  Unveränderbarkeit, Aufbewahrung und Sicherung muss die integrierende Anwendung
  beziehungsweise ein angebundenes Archivsystem gewährleisten.

## Rechnungen erzeugen (S2)

Im Reiter **Ausgang** einen Kunden wählen und **Neue Testrechnung** drücken.
Dabei werden offene Stammdateneditoren übernommen und gespeichert. Die Nummer
wird anschließend dauerhaft reserviert, bevor Ordner und Rechnung entstehen.
**XML anzeigen** öffnet die ausgewählte XML im Standardprogramm, **Ordner öffnen**
die Ablage. Beim Öffnen des Reiters und mit **Aktualisieren** wird die Liste neu gelesen.

`BuildInvoice` in `MiniApp.InvoiceBuilder` liefert ein vom Aufrufer freizugebendes
`TInvoice`. Es übernimmt Rechnungssteller, gewählten Kunden und alle Testpositionen,
setzt EUR, 14 Tage Zahlungsziel und SEPA-Überweisung mit IBAN/BIC. Positionssummen
werden kaufmännisch auf Cent gerundet, danach wird pro Steuersatz die Steuer auf
die Summe dieser Positionsbeträge berechnet und ebenfalls auf Cent gerundet.
Die Berechnung nutzt die ganzzahlige Currency-Darstellung, ohne Zwischenrundung
auf vier Stellen oder Gleitkomma-Toleranz. Zu große Zwischenprodukte werden
mit einer Fehlermeldung abgewiesen. Null Prozent wird als Kategorie Z ausgegeben;
Steuerbefreiungen und Reverse Charge sind im Modell nicht vorgesehen. Unbekannte
Einheiten, Steuersätze mit mehr als zwei Nachkommastellen und fehlende Pflichtangaben
werden verständlich gemeldet. Eine vollständige
fachliche Prüfung erfolgt erst durch KoSIT; insbesondere bleiben die fiktiven Bank-
und Steuerkennungen der Beispiele unverändert.

| Versandweg | BT-10 | BT-49 / Schema |
|---|---|---|
| `traffiqx` | `TX:` + normalisierte Empfänger-ID | Kontakt-E-Mail / `EM` |
| `leitwegid` | Leitweg-ID | Kontakt-E-Mail / `EM` |
| `peppol` | `non-existent` | elektronische Adresse / gespeichertes Schema, z. B. `9930` |
| `email` | `non-existent` | Kontakt-E-Mail / `EM` |

BT-23 bleibt das normale XRechnung-Profil. `PrepareSandboxXml` wird erst beim
Versand in S4 angewendet. `SaveInvoiceXml` schreibt UBL über `XRechnungVersion_30x_UBL`.

`CreateOutboxInvoice` legt exklusiv `Daten/ausgang/<Nummer>/` an. Bereits vorhandene
Ordner führen zum Fehler; Rechnungen werden nie überschrieben. Nach `rechnung.xml`
und `belegbild.pdf` wird `rechnung.json` atomar geschrieben. Es enthält
`invoice_number`, `customer_number`, `customer_name`, `issue_date` (ISO-Datum),
`gross_amount` (JSON-Zahl in EUR) und `delivery_channel`. Das ist eine Momentaufnahme,
die spätere Stammdatenänderungen nicht verändern. Der `out`-Parameter
`AReservedInvoiceNumber` enthält auch bei nachfolgenden Fehlern die verbrauchte Nummer.
Lücken bleiben bestehen; eine Teilablage bleibt zur Diagnose erhalten und erscheint
mit Hinweis in der Liste. Ohne lesbare `rechnung.json` wird keine fertige Rechnung
behauptet. Fehler stehen im Protokoll. `document_id` und Status bleiben leer, solange
keine `outbox.json` existiert. Ab S4/S5 erscheinen zusätzlich Soll-/Ist-Kanal und
alle Versanddetails aus dieser Datei. Die reine Rechnungserzeugung schreibt
`outbox.json` noch nicht.

## Versand und Originalablage (S4/S5)

Im Reiter **Ausgang** eine fertige Testrechnung auswählen und **Senden** wählen.
Voraussetzung ist eine aktuell geprüfte DATEV-Verbindung. Der Sollkanal stammt aus
der beim Erzeugen gespeicherten Kunden-Momentaufnahme in `rechnung.json`.
Spätere Stammdatenänderungen lenken eine bestehende Rechnung nicht um.
Die Sandbox verwendet nur für den Upload eine XML-Kopie mit `SBSZ:210` bei Peppol,
sonst `SBSZ:110`; `rechnung.xml` bleibt unverändert. Produktion überträgt die
unveränderte XML. `UploadStructuredData` sendet XML und `belegbild.pdf` mit den
Dateinamen `rechnung.xml`/`belegbild.pdf` und Wunschformat XRechnung (`pfXRechnung`).

Vor dem Vorgang erneuert `EnsureAccessToken(120)` erforderlichenfalls im Hauptthread
die Tokens und speichert sie. Anschließend wird dort eine separate API mit derselben
Konfiguration, einer Kopie des Access-Tokens und HTTP-Protokollierung angelegt.
Der Worker bekommt kein Refresh-Token und verwendet ausschließlich diese API.
Seine Meldungen und Listenaktualisierungen laufen über `TThread.Queue`.
Immer nur ein Netzwerkvorgang ist möglich; die entsprechenden Knöpfe sind gesperrt.
Beim Schließen kann man auf den Abschluss mit anschließendem automatischem Schließen
warten oder das Fenster offen lassen. Bereits eingereihte Meldungen besitzen ein
referenzgezähltes Ziel, das beim Freigeben abgetrennt wird. Auch direktes Freigeben
des Service wartet auf den Worker, bevor Ressourcen verschwinden.

`outbox.json` wird atomar geschrieben. Ein Upload-Marker wird **vor dem POST**
gespeichert; nach Erfolg werden **sofort**, vor der ersten Statusabfrage,
`document_id`, `inProcess` und `uploaded_at` gesichert. Scheitert diese Speicherung,
meldet das Protokoll die ID ausdrücklich mit **NICHT ERNEUT SENDEN**. Der vorher
gespeicherte Marker schützt auch nach einem Neustart vor Doppelversand.

| Felder in `outbox.json` | Bedeutung |
|---|---|
| `document_id`, `status` | Aktueller Upload und zuletzt erreichter Status |
| `channel_intended`, `uploaded_at`, `checked_at` | Gewollter Kanal, Annahmezeit, letzte erfolgreiche Statusantwort |
| `document_format`, `send_date`, `delivery_channel`, `delivery_address` | Von DATEV bestätigte Versanddaten |
| `channel_matches`, `metadata_at` | Soll/Ist-Prüfung (`null` vor Metadaten), Zeitpunkt des Metadatenabrufs |
| `archived_at`, `last_error` | Zeitpunkt der vollständigen Originalablage, letzte Fehlermeldung |
| `previous_document_ids` | Frühere IDs bei ausdrücklich bestätigtem Neuversand |
| `upload_unconfirmed` | Annahme ungeklärt: weiteren Upload sperren, auch ohne bekannte ID |

Zeitstempel sind ISO-8601-Werte mit Zeitzone. Ein vorhandener Datensatz mit ID
sperrt **Senden**, außer bei `error` oder `deleted`; auch dann ist eine Rückfrage
nötig. Die alte ID bleibt bei einem neuen Versuch erhalten. Der Status fällt für
dieselbe ID nie zurück: `inProcess < userAction < error < deleted < sent`.
Unbekannte Statuswerte werden mit Rohwert und Beschreibung gemeldet; eine ID mit
unbekanntem Status erlaubt keinen Neuversand. Unlesbare Ablagen sperren ebenfalls.

HTTP 201 ohne auswertbare ID (`#PARSE`), Transportfehler und unklare Serverfehler
bleiben als unbestätigter Upload gesperrt. **Nicht erneut senden.** Den Stand mit
HTTP-Protokoll und DATEV-Plattform klären. Das Sample besitzt dafür keinen
„Sperre ignorieren“-Knopf: Eine ermittelte ID muss nach Prüfung in der lokalen
Ablage mit passendem Status zugeordnet und `upload_unconfirmed` aufgehoben werden.
Nur bei eindeutig abgelehntem Upload (4xx oder lokalem Konfigurationsfehler) wird
der vorherige Zustand wiederhergestellt und der Fehler protokolliert.

`WaitForOutboxDocumentSent` fragt sofort und danach alle 8 Sekunden ab, maximal
60 Sekunden (8 s / 8 s / 60 s). Ein bereits laufender HTTP-Aufruf kann länger
dauern. Nach einem langen Upload werden vor dem Polling erneut mindestens
120 Sekunden Access-Restlaufzeit verlangt (60 Sekunden Polling plus Antwortreserve);
sonst später **Status abfragen** wählen.
Vor Metadaten und Download werden jeweils noch 15 Sekunden verlangt.
Alle Statusantworten erscheinen mit `DescribeStatus`; Fehlercodes und Details
werden verständlich übersetzt. Hilfe-URLs erscheinen im Protokoll und, soweit
verfügbar, am vorhandenen Hilfe-Link. Nach Timeout erfolgt kein automatischer
Neuversand. **Status abfragen** setzt denselben Vorgang anhand der gespeicherten ID
fort, auch nach Neustart und erneutem Verbindungscheck.

Erst nach bestätigtem **sent** werden Metadaten und Original abgerufen. Metadaten
werden nur bei leerem `metadata_at` geholt. Format, Versanddatum, Kanal und Adresse
erscheinen im Detailbereich; fehlende Pflichtwerte lassen den Schritt offen.
`TraffiqxChannelMatches` prüft den Soll-/Ist-Kanal. Eine Abweichung steht als Warnung
im Protokoll und in der Ausgangsliste, verhindert aber nicht die Originalablage.
HTTP 202 beim Download bedeutet **noch nicht bereit**; `sent` bleibt erhalten,
`archived_at` bleibt leer und **Status abfragen** holt das Original später nach.

Das ZIP wird vollständig in den Speicher gelesen und durch `System.Zip` geprüft;
zusätzlich wird die CRC gegen das zentrale ZIP-Verzeichnis abgeglichen,
bevor Dateien geschrieben werden. Es werden alle enthaltenen Dateien verwendet,
keine festen Namen erwartet. Unterordner werden abgeflacht, ungültige Zeichen
bereinigt und eindeutige Nummern vorangestellt (auch gegen Windows-Gerätenamen und
Namenskollisionen). Die entpackte Gesamtgröße ist im Sample auf 256 MiB begrenzt.
Erst nach vollständig geschriebenen und gespülten Dateien wird ein temporärer
Nachbarordner als `original` veröffentlicht; danach wird `archived_at` gesetzt.
Teilordner `original.<GUID>.tmp` bleiben bei Schreibfehlern zur Diagnose erhalten.
Ein bereits veröffentlichter, bytegleich passender Originalordner wird nach einem
Absturz vor dem Zeitstempel übernommen; Abweichungen brauchen manuelle Prüfung.
**Original anzeigen** öffnet den Ordner mit allen Dateien zum Öffnen im jeweiligen
Standardprogramm. Ohne geprüfte Verbindung sind die drei neuen Knöpfe deaktiviert;
ein Hinweis erklärt den Grund. Die lokale Rechnungserzeugung bleibt verfügbar.

Der Reiter nennt den Archivierungsort ausdrücklich:
„GoBD-konforme Archivierung: Das Original liegt im Rechnungsordner. Die DATEV
E-Rechnungsplattform archiviert nicht.“ Die lokale Sample-Ablage ersetzt kein
Archivsystem mit Unveränderbarkeit, Aufbewahrung und Sicherung; diese Maßnahmen
bleiben Aufgabe der integrierenden Anwendung.

## Posteingang (S6)

Nach geprüftem DATEV-Login im Reiter **Eingang** zunächst **Alle abgleichen** wählen.
Dieser Erstabgleich liest die Liste mit `AUseDownloadedFilter=False`, einschließlich
bereits bei DATEV heruntergeladener Dokumente. **Posteingang abrufen** verwendet
anschließend `AUseDownloadedFilter=True, ADownloaded=False`. Beide Aktionen sind
manuell; weder der Timer noch das Öffnen des Reiters startet Netzwerkaufrufe.
Die Liste zeigt auch nach einem Neustart lokale Dokumente und vorgemerkte IDs.

Vor dem Worker erneuert `EnsureAccessToken(120)` bei Bedarf die Tokens im
Hauptthread. Der Worker besitzt eine eigene API ohne Refresh-Token. Vor jedem
weiteren API-Aufruf werden mindestens 15 Sekunden Restlaufzeit verlangt; reicht
sie nicht, den Abruf erneut starten. Es läuft immer nur ein Netzwerkvorgang;
Queue-Ziel, Fehlerhilfe und Schließen verwenden denselben Lebenszyklus wie S4/S5.

Vor jedem Abruf, Erstabgleich und Nachholen von Metadaten prüft der Worker
`eingang-kontext.json` auf Umgebung und TRAFFIQX-ID. Bei einem leeren neuen
Bestand wird diese Bindung vor dem ersten Inbox-Aufruf atomar gespeichert.
Eine fremde, unlesbare oder ungültige Bindung sperrt alle Inbox-Aufrufe und
Änderungen der Offen-Liste. Trennen, Umgebungswechsel oder eine andere `.env`
nach Neustart können deshalb keine fremde Vormerkung durch HTTP 404 entfernen.
Für Bestände ohne Bindung siehe **Bekannte Grenzen**.

Der Wiederanlauf verarbeitet **zuerst** `eingang-offen.txt`, erst danach die
API-Liste. Jede neue ID wird vor dem Download atomar mit Flush gespeichert.
Ohne erfolgreiche Vormerkung erfolgt kein Download. Das ZIP wird vollständig
inklusive CRC-Prüfung in den Speicher gelesen (maximal 256 MiB entpackt).
Die mit S5 gemeinsame Ablage bereinigt Dateinamen, flacht Unterordner ab und
stellt eindeutige Nummern voran. Erst nach vollständigem Schreiben und Flush
wird ein temporärer Nachbarordner als `eingang/<document_id>` veröffentlicht.
`archive.complete` enthält die Liste der veröffentlichten Dokumentdateien;
`metadata.json` wird anschließend atomar gespeichert. Beide Verwaltungsdateien
kollidieren dank der nummerierten ZIP-Dateinamen nicht mit Dokumenten.

Erst danach wird die ID ausgetragen. Fehler beim Download, Entpacken oder
Schreiben lassen sie für den nächsten Abruf vorgemerkt; HTTP 404 beim Download
entfernt sie mit einem Protokollhinweis. Ein Absturz nach Veröffentlichung wird
anhand von `archive.complete` und den vorhandenen Dateien erkannt: kein erneuter
Download und keine doppelte Ablage. **Alle abgleichen** überspringt solche lokalen
Dokumente ebenfalls und ergänzt gegebenenfalls fehlende Metadaten. Temporäre
`<document_id>.<GUID>.tmp`-Ordner bleiben bei Fehlern zur Diagnose erhalten, erscheinen
aber nicht als Dokumente. Vorhandene Ordner mit fehlendem Marker oder fehlenden
Dateien werden nicht überschrieben; diese Bestände manuell prüfen und sichern.
Eine unlesbare Offen-Liste bricht den Abruf ab und wird nicht ersetzt.

Metadatenfehler werden als Warnung gemeldet; das Dokument bleibt vollständig
abgelegt und wird aus der Offen-Liste entfernt. **Metadaten nachholen** fragt nur
die Metadaten des ausgewählten lokalen Dokuments erneut ab. Absender, Eingang,
`document_format` und `en_16931_compliant` erscheinen in der Liste. Fehlende oder
unlesbare Metadaten bleiben **ungeprüft**, gültige stehen auf **ja**, ungültige auf
**nein** in Rot. Ein roter Sammelhinweis nach dem Abruf meldet die Anzahl ungültiger
E-Rechnungen; das Ergebnis steht zusätzlich im Protokoll. Beim erneuten Abgleich
zählen auch bereits bekannte ungültige Dokumente zu diesem Hinweis.

**Dokument anzeigen** öffnet die erste Datei in ZIP-Reihenfolge im zugeordneten
Standardprogramm; **Ordner öffnen** zeigt alle Dateien. Beides funktioniert auch
ohne DATEV-Verbindung. Die Oberfläche nennt den Archivierungsort ausdrücklich:
„Die Eingangsrechnungen liegen im Ordner Daten\eingang; die DATEV
E-Rechnungsplattform archiviert nicht GoBD-konform.“ Die Sample-Ablage allein
ersetzt kein GoBD-Archiv mit Unveränderbarkeit, Aufbewahrung und Sicherung.

## Optionale KoSIT-Prüfung

Mit `XRECHNUNG_DISTRIBUTION_DIR` in der beim Start geladenen `.env` wird
**Prüfen (KoSIT)** aktiviert. Erwartet wird die Distribution der XRechnung-Bibliothek
mit `java`, `validator` und `validator-configuration30x`. Ohne Einstellung bleibt
der Knopf deaktiviert. Der lokale Aufruf von `intf.XRechnungValidationHelperJava`
hat ein Prozesszeitlimit von 60 Sekunden; währenddessen wartet die Oberfläche.
Werkzeugausgabe, Fehler und XML-Ergebnis stehen im Protokoll. Verfügbare Berichte
werden als `pruefbericht.xml` und `pruefbericht.html` im Rechnungsordner abgelegt.
Der Rückgabewert des Helfers ist lediglich der Prozessstatus, keine Zusage über
die fachliche Gültigkeit; dafür den Bericht lesen. Erneutes Prüfen ersetzt die
jeweils erzeugten Berichte. Wenn kein neuer Bericht entsteht, können ältere
Berichte noch vorhanden sein; maßgeblich ist dann der Fehler im aktuellen Protokoll.

## Ressourcen und manuelle Prüfung

Eine vorhandene `.res` wird nicht benötigt: Die Delphi-IDE beziehungsweise
`CodeGear.Delphi.Targets` erzeugt sie beim Projektbuild über `BuildVersionResource`
aus den Versionsinformationen und dem Standardmanifest der `.dproj`.
`PerMonitorV2` ist für alle vier Konfigurationen gesetzt. Der direkte Aufruf von
`dcc32`/`dcc64` nur auf die `.dpr` führt diesen Ressourcenschritt nicht aus.
Die generierte `.res` bleibt lokal. Das Text-DFM verwendet Align, Anchors,
prozentuale Grid-Spalten/-Zeilen und Scrollboxen für kleinere Fenster.

Nach dem Build durch den Auftraggeber prüfen:

1. Erststart ohne Daten: fünf Hauptreiter, vier Kunden, zwei Positionen, Sandbox.
2. Alle Rechnungsstellerfelder ändern, Kunden und Positionen anlegen/bearbeiten/
   löschen, speichern, neu starten: Werte und Listen bleiben erhalten.
3. Ungültige Zahlen und doppelte Kundennummern: verständliche Fehlermeldung;
   Wechsel/Schließen abbrechen: Eingaben bleiben im Editor.
4. Fenster verkleinern und zwischen 100/150/200 Prozent DPI wechseln: Felder,
   Listen und Schaltflächen bleiben über Layout beziehungsweise Scrollen erreichbar.
5. Zweite Instanz derselben EXE: Zugriff wird abgelehnt. Nach Ende der ersten
   Instanz ist ein erneuter Start trotz vorhandener `.lock` möglich.
6. In einem separaten Testdatenbestand `NextInvoiceNumber` mehrfach aufrufen,
   Modell freigeben und erneut laden: der persistierte Zähler steigt auch nach
   Neustart. Bei Schreibfehler darf keine Nummer zurückgegeben werden.
7. Nur in einem separaten Testdatenbestand JSON beschädigen: Start meldet den
   Fehler, Datei bleibt erhalten. Ein Clean-Projektbuild ohne `.res` sollte die
   Ressource selbst erzeugen.

Zusätzlich für S2 in einem separaten Testbestand prüfen:

1. Je Versandweg eine Rechnung erstellen, XML und Ordner öffnen, neu starten.
   Standardpositionen: netto 122,50 EUR, Steuer 23,28 EUR, brutto 145,78 EUR.
   BT-10/BT-49 gegen die Tabelle und Fälligkeit gegen Rechnungsdatum + 14 Tage prüfen.
2. Vorhandenen S1-Bestand laden: kein vierter Kunde wird automatisch hinzugefügt.
   Kundenänderungen dürfen die bereits erzeugten Rechnungsinformationen nicht ändern.
3. Rundungsfälle: Menge 1 × Preis 0,005 ergibt 0,01; Menge 0,0001 × Preis 49,99
   ergibt 0,00 (keine doppelte Rundung). Zwei Positionen à 0,03 bei 19 Prozent
   ergeben netto 0,06 und Gruppensteuer 0,01. Zusätzlich gemischte Sätze 0/7/19
   und mehrere Positionen je Satz prüfen; Netto + Gruppensteuern = Brutto = Zahlbetrag.
4. Fehlende Leitweg-ID, nur `TX:` als TRAFFIQX-ID, fehlende Kontakt-E-Mail,
   fehlendes Peppol-Schema, leere Positionen und unbekannte Einheit testen:
   verständliche Fehler, kein XML mit leeren Pflichtangaben oder stiller Ersatzeinheit.
5. PDF an beiden Suchorten fehlen lassen oder den nächsten Rechnungsordner vorab
   anlegen: Fehler, vorhandene Dateien unverändert, reservierte Nummer bleibt auch
   nach Neustart verbraucht. Eine Teilablage wird angezeigt und protokolliert.
6. `rechnung.json` beschädigen bzw. `outbox.json` mit
   `{"document_id":"test-id","status":"inProcess"}` ergänzen: einzelne Fehler
   verhindern nicht die übrige Liste; ID/Status erscheinen nur aus der Versanddatei.
7. Ohne Distribution: Prüfknopf aus. Mit gültiger bzw. fehlender Distribution:
   Berichte bzw. aussagekräftiger Protokollfehler. Anschließend kleine Fenster und
   100/150/200 Prozent DPI auch im Ausgang prüfen.

Zusätzlich für S3 in der Sandbox und einem separaten Testbestand prüfen:

1. `.env` mit DATEV-Client, App-Name, TRAFFIQX-ID, Broker und benötigten Scopes
   (einschließlich `profile`) konfigurieren. Login: Browser öffnet sich, Abbruch
   während des Wartens sichtbar, erst zweimal HTTP 200 schaltet auf grün;
   Name und Ablaufdatum vorhanden. Tokenwerte dürfen nirgends sichtbar sein.
2. Neustart: rot/ungeprüft, **Verbindung prüfen** stellt den Status wieder her.
   Produktion nur nach Trennen und Warnbestätigung auswählbar; Auswahl in beiden
   Reitern identisch und nach Speichern/Neustart erhalten.
3. Erneuter Login: im HTTP-Protokoll muss Revoke vor StartAuth stehen. Trennen
   leert die Tokenwerte. Fehlende Rechte auf Inbox/Outbox: rot, Hilfe anklickbar,
   unmittelbar danach Revoke.
4. Widerruf scheitern lassen (Netz aus): gelb, Marker bleibt über Neustart, kein
   Refresh und kein neuer Login. Netz wiederherstellen: erneuter Klick widerruft
   zuerst und ermöglicht erst danach eine Anmeldung.
5. Access-Ablauf im Testbestand verkürzen und **Verbindung prüfen** wählen:
   Refresh tauscht beide Tokens, neue Ablage sofort vorhanden; Refresh-Ablauf
   wird ohne Providerangabe nicht verlängert. `invalid_grant` simulieren:
   Tokens verworfen, rot und Hinweis zur Neuanmeldung.
6. Beschädigtes JSON, Klartext statt DPAPI, anderer Benutzer, abweichende
   Client-ID/Umgebung/TRAFFIQX-ID und verweigerter Dateizugriff: rot, Hinweis,
   vorhandene Datei unverändert. Schreibfehler bei Rotation und Widerruf ebenfalls
   prüfen; keine weitere Token-Nutzung nach unklarem Austausch.
7. Login abbrechen, mehrfach abbrechen und während des Wartens schließen; auch
   mit verzögerter Brokerantwort und fast gleichzeitigem Erfolg prüfen. Keine
   Warte-/Freigabefehler oder veralteten Callbacks in ein geschlossenes Fenster.
   Ebenso Timeout und Polling-Transportfehler prüfen: gelbe Ampel, Marker samt
   Zeitpunkt in `tokens.dat`, nach Neustart weiterhin gelb. **Mit DATEV verbinden**:
   **Nein**/Dialog schließen erhält Marker und startet keinen Login; Öffnen der
   DATEV-Seite bestätigt nicht automatisch; erst **Ja** entfernt den Marker und
   startet die Anmeldung. Erfolgreicher Login bzw. Trennen entfernt den Marker.
   Schreibfehler beim Setzen/Freigeben des Markers sperren neue Anmeldungen.
   Alte v1-Datei ohne die beiden neuen Felder muss weiterhin geladen werden.
8. Userinfo ohne `profile` bzw. mit Fehler: Hinweis, erneut prüfbar. Fehlerhilfe
   und **Verbundene Anwendungen** öffnen im Browser. Kleine Fenster und
   100/150/200 Prozent DPI: Ampel, Name, Laufzeit und alle Knöpfe erreichbar.
9. HTTP-Dateien auf Anfragen/Antworten einschließlich Login-Polling prüfen;
   Tokenwerte/Secrets dürfen nicht enthalten sein. Aufbewahrung gemäß
   `TTraffiqxHttpLog.RETENTION_DAYS` (14 Tage), Fehlerquote erst S7.

Build am 30.10.2026: Win32 Debug erfolgreich (ExitCode 0), keine Warnungen in
Sample2-Units. Die Build-Umgebung meldet einen fehlenden optionalen Registry-Pfad
und einen nicht vorhandenen TMS-Suchpfad; außerdem bestehen Hinweise in der
unveränderten API-Bibliothek. DATEV-, KoSIT- und interaktive VCL-/DPI-Prüfungen
sowie die weiteren Build-Konfigurationen bleiben offen.

Lokale Delphi-Laufzeitprüfung am 30.10.2026 mit isolierten Scratchpad-Testdaten:
JSON-Rundlauf, monotone Statusfolge, neue ID mit Historie, persistente Uploadsperre,
defektes JSON und ältere `#PARSE`-Marker erfolgreich geprüft. ZIP-Prüfungen für
verschachtelte/ungültige Dateinamen, vollständige Ablage, Wiederaufnahme und den
Schutz vorhandener Originale bestanden; beschädigte Nutzdaten/CRC-Verzeichnisse,
leere/defekte ZIPs und übergroße Einträge wurden vor der Veröffentlichung abgewiesen.

### Prüfliste S4/S5

Win32 Debug wurde gebaut; die folgenden DATEV-/UI-Prüfungen bleiben offen.
Auch Win32 Release und Win64 Debug/Release in einem separaten Testbestand prüfen;
Fehlerantworten gegebenenfalls mit einer kontrollierten Test-API simulieren:

1. Ohne Verbindung: drei neue Knöpfe gesperrt, Hinweis sichtbar; lokale Erzeugung
   funktioniert. Nach Verbindungscheck die ausgewählte Rechnung senden. UI bleibt
   während des Workers bedienbar, kein zweiter Vorgang und kein Umgebungswechsel.
2. Sandbox: Peppol verwendet `SBSZ:210`, übrige Wege `SBSZ:110`; Hash der lokalen
   `rechnung.xml` bleibt gleich. Bei Produktion kein Sandbox-Marker (nur gezielt
   mit geeigneten Daten testen). HTTP-Protokoll enthält Upload und Folgeaufrufe.
3. Nach HTTP 201 muss `outbox.json` die ID und `inProcess` enthalten, **bevor** die
   erste Statusabfrage startet. ID und Status sind in der Liste sichtbar. Zweiter
   Versand und Versand nach Neustart bei aktiver ID bleiben gesperrt.
4. `inProcess`, `userAction`, `error`, `deleted`, `sent` und unbekannten Status
   simulieren; Rohwert, verständliche Beschreibung und Fehlerdetails prüfen.
   Rückläufige Antworten dürfen den gespeicherten Rang nicht senken. Bei
   `error`/`deleted` Rückfrage ablehnen: kein POST. Bestätigen: neue ID, alte ID in
   `previous_document_ids`, Rang beginnt für die neue ID bei `inProcess`.
5. Dauerhaft `inProcess`: sofortige erste Abfrage, 8-s-Abstände, kein neuer Aufruf
   ab 60 s. Danach „Status abfragen“ ohne neuen Upload. Token kurz vor Ablauf und
   sehr langsamen Upload prüfen: Refresh nur vorher im Hauptthread; bei zu wenig
   Restlaufzeit kein neues Polling und späteres Fortsetzen mit derselben ID.
6. 201 mit `{}`, leerer ID oder kaputtem JSON, Netzwerkabbruch sowie 5xx nach
   Annahme simulieren: deutlicher Hinweis, `last_error`, persistente Versandsperre
   auch nach Neustart. 4xx-Ablehnung erlaubt nach Beheben einen neuen Versuch.
7. Schreibfehler vor POST: kein Upload. Schreibfehler direkt nach erfolgreichem
   Upload: Warnung mit ID und „NICHT ERNEUT SENDEN“, kein Statuspolling; persistierter
   Vormarker bleibt wirksam. Fehler bei späterem Statusschreiben: ID nicht verlieren.
   Ungültiges JSON/Zugriff verweigert darf niemals als fehlende Ablage gelten.
8. Vor `sent`: weder Metadata- noch Download-Aufruf. Nach `sent`: Format, Datum,
   Kanal und Adresse sichtbar; Kanalabweichung warnt (auch nach Neustart), Leitweg-ID
   akzeptiert passende TRAFFIQX-/Peppol-Zustellung gemäß Bibliothekshelfer.
9. Download HTTP 202: „noch nicht bereit“, weiter `sent`, kein `archived_at`.
   Späteren Abruf erfolgreich abschließen. Bereits vorhandenes `metadata_at`
   verhindert erneuten Metadatenabruf; vorhandenes `archived_at` verhindert Download.
10. ZIP mit mehreren/verschachtelten Dateien, identischen Basisnamen, `../`,
    absoluten Pfaden, `CON.xml` und ungültigen Zeichen: vollständige, eindeutige
    Ablage ausschließlich in `original`. Leeres/defektes ZIP, CRC-Fehler und mehr
    als 256 MiB: keine Archivierungsmarkierung. Schreibfehler im temporären Ordner
    und Absturz nach Veröffentlichung vor `archived_at`: sichere Wiederaufnahme.
11. Während Upload/Polling/Download schließen: „Nein“ lässt offen, „Ja“ schließt
    nach Abschluss; auch Abschluss während des Dialogs prüfen. Direkte Freigabe
    mit ausstehenden Queue-Meldungen darf keinen Zugriff auf freigegebene Objekte
    verursachen. Fehlerdialoge und Protokoll dürfen keine Tokens enthalten.
12. Bei 100/150/200 Prozent DPI und minimaler Fenstergröße: neue Knöpfe erreichbar,
    Ausgangsliste horizontal scrollbar, Detailbereich scrollbar/teilbar, Hinweis
    zur Archivierung sichtbar. „Original anzeigen“ öffnet die vollständige Ablage.

### Prüfliste S6

In einem separaten Testbestand und mit Sandbox bzw. kontrollierten API-Antworten:

1. **Alle abgleichen** liefert heruntergeladene und neue Dokumente, **Posteingang
   abrufen** nur neue. Zweiter Abgleich legt vorhandene Ordner nicht doppelt an.
   Im HTTP-Protokoll Reihenfolge prüfen: vorgemerkte Downloads vor dem Listenabruf.
2. Vor dem Download `eingang-offen.txt` prüfen. Schreibrechte verweigern: kein
   Download ohne Vormerkung. Download-/ZIP-/Schreibfehler und Neustart simulieren:
   ID bleibt erhalten und wird trotz DATEV-Downloadflag erneut verarbeitet.
3. Abbruch nach Ordnerveröffentlichung, vor Metadaten/Austragen: beim Neustart
   lokale Dateien übernehmen, Metadaten ergänzen, ID austragen, kein Doppeldownload.
   HTTP 404 beim Download entfernt nur die betroffene Vormerkung. Defekte oder
   gesperrte Offen-Liste darf nicht durch eine neue Liste ersetzt werden.
4. ZIP mit Unterordnern, Pfadtraversal, ungültigen/gleichen Namen und Gerätenamen:
   alle Dateien nur unter der ID ablegen. Leeres ZIP, CRC-Fehler, defektes ZIP,
   Größenlimit und Schreibfehler: keine veröffentlichte Teilablage. Vorhandene
   unvollständige Ordner bleiben unverändert und verlangen manuelle Prüfung.
5. Metadatenfehler: Warnung, Dokument weiter sichtbar/öffnbar, ID ausgetragen,
   Gültigkeit **ungeprüft**. **Metadaten nachholen** ergänzt Format, Absender,
   Empfangsdatum und Gültigkeit ohne erneuten Dokumentdownload.
6. Gültige und ungültige Rechnungen gemeinsam abrufen: ja/nein korrekt, ungültige
   Zeilen rot, roter Sammelhinweis mit Anzahl auch bei gemischten Teilerfolgen.
   Nach Neustart bleibt die Gültigkeit sichtbar; beim Abgleich erneut melden.
7. **Dokument anzeigen** öffnet die erste Dokumentdatei, **Ordner öffnen** alle
   Dateien; auch ohne Verbindung. ID und Archivierungshinweis bleiben sichtbar.
8. Während des Abrufs bleiben andere Netzwerkaktionen und Umgebungswechsel
   gesperrt. Tokenablauf im langen Stapel, Schließen mit wartendem Worker und
   eingereihten Ergebnissen sowie 100/150/200 Prozent DPI prüfen. Kein Abruf
   durch Timer, Neustart oder bloßes Öffnen des Reiters.

9. Download erfolgreich, lokale Ablage fehlgeschlagen: Verbindung trennen,
   Umgebung wechseln und abrufen. Kein Inbox-Aufruf, Vormerkung unverändert.
   Zur ursprünglichen Umgebung zurückkehren: Wiederaufnahme weiterhin möglich.
   Dasselbe nach Neustart mit anderer TRAFFIQX-ID in `.env` prüfen, auch für
   **Alle abgleichen** und **Metadaten nachholen**. Fehlende/defekte/gesperrte
   Kontextdatei bei vorhandenem Bestand darf keine automatische Neubindung
   auslösen; Schreibfehler beim ersten Anlegen verhindert jeden Inbox-Aufruf.

DATEV-, interaktive VCL-/DPI-Prüfungen und weitere Build-Konfigurationen bleiben
für S6 offen; die Prüfliste beschreibt die noch auszuführende Integrationsabnahme.

S6-Prüfung am 30.10.2026: Win32 Debug mit dem vorgegebenen Build-Befehl erfolgreich
(ExitCode 0), keine neuen Warnungen oder Hinweise in Sample2-Units. Die bekannten
Umgebungs-/Bibliothekshinweise bleiben bestehen. Isolierte Delphi-Laufzeittests im
Scratchpad bestanden: atomare Offen-Liste einschließlich Sperr-/Lesefehlern,
ZIP-Ablage und sichere Dateinamen, Wiederaufnahme ohne doppelte Ablage,
Metadaten-Rundlauf und Nachholung, fehlende Dateien/unvollständige Ordner sowie
CRC-/Format-/Größenfehler ohne Veröffentlichung. Die S4/S5-Ablagetests wurden
gegen die gemeinsame ZIP-Routine erfolgreich wiederholt. Ein Formular-Smoke-Test
lädt das DFM und prüft Eingangsspalten sowie gesperrte Aktionen ohne Verbindung
und Auswahl; er ersetzt keine interaktive Sicht-/DPI-Prüfung.

S6-Review-Nacharbeit am 30.10.2026: Den hohen Befund zum Verlust vorgemerkter
IDs nach Umgebungswechsel am Code bestätigt und durch die persistente Bindung
an Umgebung/TRAFFIQX-ID behoben. Isolierter Delphi-Laufzeittest: 25 Prüfungen
erfolgreich, darunter unveränderte Vormerkungen bei Kontextwechsel, Wiederaufnahme
im ursprünglichen Kontext, defekte/gesperrte Kontextdateien und gesperrte
Altbestände ohne Zuordnung. Win32 Debug erneut mit dem vorgegebenen Befehl gebaut:
ExitCode 0, keine neuen Warnungen/Hinweise in Sample2-Units. Das Build-Skript
meldet weiterhin den nicht verfügbaren HKCU-Umgebungsschlüssel; die vorhandenen
Umgebungs-/Bibliothekshinweise verhindern den erfolgreichen Build nicht.
