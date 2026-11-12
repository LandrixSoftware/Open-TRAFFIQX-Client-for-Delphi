# TIA Mini-Anwendung – Sample 2

Sample 2 zeigt eine kleine Windows-Desktop-Anwendung um die Delphi-Bibliothek:
Stammdaten pflegen, XRechnungen erzeugen, DATEV verbinden, Rechnungen bis zum
Original versenden und den Posteingang ohne Verlust abholen. Es dient als
Integrationsvorlage und zur Vorbereitung der DATEV-Abnahme. Das bisherige
[Sample](../Sample/) bleibt die Testbank für einzelne API-Aufrufe.

Die Scheiben S1–S7 aus [Sample2.md](../../../Sample2.md) sind implementiert.
Das ist keine Bestätigung einer DATEV-Abnahme. Für einen eigenen Integrationslauf
stehen unten eine Sandbox-Prüfliste und die Zuordnung der Abnahme-MUSTs.

## Start, Konfiguration und Datenordner

1. `TIAMiniApp.dproj` oder `../DelphiProjectGroup.groupproj` in Delphi öffnen.
   Win32/Win64 und Debug/Release sind eingerichtet. Der Suchpfad erwartet die
   TIA-Units im übergeordneten Ordner und `src-XRechnung-for-Delphi` als
   benachbartes Repository. WebView2 wird nicht benötigt.
2. Bauen und die EXE unter `Win32|Win64/Debug|Release` starten. Delphi/MSBuild
   erzeugt die lokale `.res` aus den Projektinformationen; ein direkter
   Compileraufruf nur auf die `.dpr` ersetzt diesen Ressourcenschritt nicht.
3. Für DATEV eine nicht versionierte `.env` neben der EXE ablegen. Fehlt sie,
   wird in der Standard-Ausgabestruktur die `.env` der Repository-Wurzel gelesen
   (fünf Ebenen oberhalb der EXE). Eine lokale Datei ersetzt die gesamte
   Repository-Konfiguration. Ohne `.env` sind Stammdaten und Rechnungserzeugung nutzbar.
4. Die Vorgabe ist **Sandbox**. Die Beispieldaten sind fiktiv. USt-ID und IBAN
   sind öffentliche Dokumentationsbeispiele mit formal gültiger Prüfziffer, damit
   die Validierung durchläuft; sie gehören zu keinem echten Unternehmen bzw. Konto.
   Die Daten sind keine Vorlage für Produktion.

Die Konfiguration verwendet einfache `NAME=WERT`-Zeilen:

| Schlüssel | Zweck |
|---|---|
| `PROVIDER_TPDATEV_CLIENT_ID`, `PROVIDER_TPDATEV_CLIENT_SECRET` | DATEV-Client-Konfiguration |
| `PROVIDER_TPDATEV_TRAFFIQX_ID` | Zugeordneter Datenbestand; wird im Reiter Verbindung angezeigt |
| `PROVIDER_TPDATEV_SCOPE` | Benötigte Scopes; für den Namen einschließlich `profile` |
| `PROVIDER_TPDATEV_APP_NAME` | Anwendungsname |
| `OAUTH2_BROKER_CALLBACK_URI`, `OAUTH2_BROKER_API_KEY` | Broker-Anbindung |
| `XRECHNUNG_DISTRIBUTION_DIR` (optional) | Distribution für KoSIT mit `java`, `validator`, `validator-configuration30x` |

Relative Distributionspfade beziehen sich auf die verwendete `.env`. Konfigurationswerte
werden nicht protokolliert. Die TRAFFIQX-ID wird beim Start geladen; zum Ändern
zuerst trennen, `.env` anpassen und neu starten. Nur nötige Scopes konfigurieren;
das Sample erweitert sie nicht automatisch. Zugangsdaten gehören niemals ins Git.

Der Datenordner ist fest **`Daten` neben der EXE**; eine Ordnerauswahl aus dem Plan
ist nicht implementiert. Der Programmordner muss beschreibbar sein. Jede
Build-Konfiguration besitzt damit einen eigenen Bestand. Für getrennte
Umgebungen/Datenbestände getrennte Programmkopien verwenden.

```text
Daten/
  stammdaten.json          Rechnungssteller, Kunden, Positionen, Zähler, Umgebung
  stammdaten.json.lock     Exklusiver Handle verhindert eine zweite Instanz
  tokens.dat              DPAPI-geschützte Tokens und Verbindungszustand
  httplog/                Technisches HTTP-Protokoll, 14 Tage
  ausgang/<Nummer>/
    rechnung.xml          Erzeugte XRechnung (UBL), beim Versand unverändert
    belegbild.pdf         Neutrale Platzhalter-PDF
    rechnung.json         Momentaufnahme von Kunde, Kanal, Datum und Betrag
    outbox.json           ID, Status, Sperre, Versanddaten, Originalablage
    original/             Alle von DATEV gelieferten Originaldateien
  eingang/<document_id>/  Dokumentdateien, archive.complete, metadata.json
  eingang-offen.txt       Vor dem Download dauerhaft vorgemerkte IDs
  eingang-kontext.json    Bindung des Eingangs an Umgebung und TRAFFIQX-ID
```

JSON und Offen-Liste werden über Temp-Datei, Flush und atomaren Dateiaustausch
gesichert. Unlesbare Bestände werden nicht durch leere oder neue Beispieldaten
ersetzt. Die Sperrdatei darf nach Programmende liegen bleiben; der offene Handle
entscheidet über die Sperre. Den Rechnungszähler niemals zurücksetzen oder alte
Stammdaten über einen aktiven Rechnungsbestand spielen.

`Belegbild-Platzhalter.pdf` wird neben der EXE gesucht, alternativ im Sample2-Ordner
zwei Ebenen darüber. Die PDF wird unverändert kopiert und zeigt keine aktuellen
Rechnungspositionen. Fehlende PDF und bereits belegte Rechnungsordner führen zum Fehler.

## Reiter und Abläufe

### Verbindung

**Mit DATEV verbinden** speichert zuerst die Stammdaten, widerruft bestehende
Tokens und startet erst danach den Browser-Login. **Abbrechen** beendet das lokale
Polling; eine offene Browser-Anmeldung ebenfalls schließen. Abbruch, Timeout oder
unklarer Polling-Fehler hinterlassen einen dauerhaften gelben Anmeldemarker.
Vor einer neuen Anmeldung muss unter **Verbundene Anwendungen** geprüft und eine
eventuelle alte Verbindung entfernt werden; das Öffnen des Links bestätigt dies
nicht automatisch. Eine erfolgreiche Antwort im Abbruchrennen wird widerrufen.

Nach dem Login werden Tokens sofort gespeichert. Erst Inbox **und** Outbox mit
HTTP 200 ergeben die grüne Ampel. Name aus Userinfo, Refresh-Ablauf in lokaler Zeit
(`TT.MM.JJJJ HH:MM`) und TRAFFIQX-ID sind sichtbar. Fehlender Name führt zu einem
Hinweis; Scope `profile` prüfen. Nach Neustart bleibt die Verbindung bis
**Verbindung prüfen** ungeprüft. Dieser Knopf wiederholt Check und Userinfo;
bei fehlgeschlagenem Check wird ein Widerruf versucht.

**Verbindung trennen** widerruft bei DATEV und entfernt die lokalen Tokens.
Ein fehlgeschlagener Widerruf bleibt gelb und sperrt Token-Nutzung/Refresh und
neue Anmeldung; mit Verbinden oder Trennen erneut versuchen. Der Link
**Verbundene Anwendungen** öffnet die DATEV-Verwaltung der Verbindungen.
Ein Umgebungswechsel ist erst nach Trennen möglich, Produktion zusätzlich mit Warnung.

Access- und Refresh-Token sind in `tokens.dat` per DPAPI an den Windows-Benutzer
gebunden. Client-ID, Umgebung und TRAFFIQX-ID müssen zur gespeicherten Verbindung
passen. Bei unlesbarer/fremder Ablage bleiben Datei und bestehende Verbindung
unangetastet; ursprüngliche Konfiguration/Benutzer wiederherstellen oder zuerst
bei DATEV widerrufen und die lokale Datei gesichert bereinigen.
Vor dem Single-Use-Refresh wird ein Widerrufmarker gesichert, neue Tokens werden
sofort gespeichert. Bei unklarem Tokenaustausch erfolgt keine weitere normale Nutzung.

### Stammdaten

Rechnungssteller bearbeiten, Kunden und Testpositionen auswählen oder mit **Neu**
anlegen. **Übernehmen** aktualisiert den Arbeitsspeicher, **Löschen** entfernt den
Eintrag, **Speichern** übernimmt auch offene Editoren und schreibt alles auf Platte.
Beim Wechsel oder Schließen mit Änderungen wird nachgefragt. Zahlen folgen dem
lokalen Windows-Format; das JSON-Format ist davon unabhängig.

Ein neuer Bestand enthält vier Beispielkunden (E-Mail, Leitweg-ID, TRAFFIQX, Peppol),
zwei Positionen und den Zähler `TEST-0001`. Alte Bestände werden nicht automatisch
um fehlende Beispielkunden ergänzt. Kundenänderungen ändern keine bereits erzeugte Rechnung.

### Ausgang

1. Kunden wählen und **Neue Testrechnung** anklicken. Der Zähler wird vor der
   Erzeugung dauerhaft erhöht; Fehler dürfen Nummernlücken hinterlassen. UBL-XRechnung,
   Platzhalter-PDF und Kunden-Momentaufnahme werden exklusiv im Rechnungsordner abgelegt.
2. **XML anzeigen** bzw. **Ordner öffnen** verwenden. **Prüfen (KoSIT)** ist nur
   mit konfigurierter Distribution aktiv; Berichte liegen als `pruefbericht.xml` und
   `pruefbericht.html` im Ordner. Den Bericht lesen, der Prozessstatus alleine
   bestätigt keine fachliche Gültigkeit. Nach fehlgeschlagener Wiederholungsprüfung
   können alte Berichte verbleiben; maßgeblich ist das aktuelle Protokoll.
3. Verbindung prüfen, Rechnung markieren, **Senden** wählen. Der Upload verwendet
   in der Sandbox eine XML-Kopie mit `SBSZ:210` für Peppol, sonst `SBSZ:110`.
   Die gespeicherte `rechnung.xml` bleibt unverändert.
4. ID und Status beobachten. Die erste Statusabfrage erfolgt sofort, danach alle
   8 Sekunden, höchstens 60 Sekunden bis zum Start der letzten zulässigen Abfrage.
   Ein laufender HTTP-Aufruf kann länger dauern. Bei Timeout mit **Status abfragen**
   fortsetzen; kein erneuter Upload. Vorher werden mindestens 120 Sekunden
   Access-Restlaufzeit gesichert; der Worker führt keinen Refresh aus.
5. Erst nach `sent` werden Metadaten, Soll-/Ist-Kanal und Original geholt.
   Kanalabweichungen warnen, verhindern aber nicht die Ablage. HTTP 202 bedeutet
   „noch nicht bereit“: später **Status abfragen**. **Original anzeigen** öffnet
   den Originalordner, einzelne Dateien im zugeordneten Standardprogramm öffnen.

| Versandweg | BT-10 | BT-49 / Schema |
|---|---|---|
| TRAFFIQX | `TX:` + normalisierte Empfänger-ID | Kontakt-E-Mail / `EM` |
| Leitweg-ID | Leitweg-ID | Kontakt-E-Mail / `EM` |
| Peppol | `non-existent` | elektronische Adresse / gespeichertes Schema |
| E-Mail | `non-existent` | Kontakt-E-Mail / `EM` |

Rechnungen verwenden EUR, 14 Tage Zahlungsziel und SEPA-Überweisung. Positionen
werden kaufmännisch auf Cent gerundet, Steuer je Steuersatz auf die Summe der
gerundeten Positionen. Null Prozent entspricht Kategorie Z; Steuerbefreiung und
Reverse Charge sind nicht modelliert. Unbekannte Einheiten/fehlende Pflichtfelder
werden abgewiesen; eine vollständige fachliche Prüfung erfolgt erst durch KoSIT.

`outbox.json` erhält **vor dem POST** einen dauerhaften Upload-Marker und bei
Erfolg sofort die ID und `inProcess`, bevor das Polling beginnt. Unklare Annahme
(Transportabbruch, 201 ohne lesbare ID, unklare Serverfehler) bleibt auch nach
Neustart gesperrt: **NICHT ERNEUT SENDEN**, Stand bei DATEV und im HTTP-Protokoll klären.
Eindeutige 4xx-Ablehnungen erlauben nach Behebung einen neuen Versuch.
Nur `error`/`deleted` erlauben einen ausdrücklich bestätigten Neuversand; frühere
IDs bleiben in `previous_document_ids`. Statuswerte fallen für dieselbe ID nicht
zurück; unbekannte Rohwerte werden angezeigt und erlauben keinen Neuversand.

Der Detailbereich zeigt `document_id`, Status, Sollkanal, Upload-/Prüfzeit,
Format, Versanddatum, Istkanal/-adresse, `channel_matches`, `metadata_at`,
`archived_at`, `last_error`, `upload_unconfirmed` und frühere IDs.
Metadaten und Download werden anhand ihrer Abschlussmarker wiederaufgenommen.

### Eingang

**Alle abgleichen** führt den Erstabgleich aller Dokumente aus, auch bereits bei
DATEV heruntergeladener. **Posteingang abrufen** fragt nur neue Dokumente ab.
Beide Vorgänge bearbeiten zuerst die dauerhaft vorgemerkten IDs. Es gibt keinen
automatischen Abruf beim Start, Reiterwechsel oder durch einen Timer.

Vor jedem Download wird die ID atomar in `eingang-offen.txt` gesichert.
Download-/ZIP-/Schreibfehler lassen sie dort für den nächsten Abruf stehen;
HTTP 404 entfernt die Vormerkung mit Protokollhinweis. Erst vollständig abgelegte
Dateien samt `archive.complete` erlauben das Austragen. Nach einem Absturz wird
eine bereits veröffentlichte Ablage übernommen, ohne erneut herunterzuladen.

Metadaten ergänzen Absender, Eingangsdatum, `document_format` und
`en_16931_compliant`. Ein Metadatenfehler verliert kein Dokument; die Vormerkung
wird nach vollständiger Dokumentablage entfernt. **Metadaten nachholen** ergänzt
die ausgewählte lokale Rechnung. Fehlende Metadaten heißen **ungeprüft**, gültige
**ja**, ungültige **nein** in Rot; nach dem Abruf erscheint ein Sammelhinweis.
**Dokument anzeigen** öffnet die erste Datei in ZIP-Reihenfolge,
**Ordner öffnen** alle Dateien, auch ohne Verbindung.

Der lokale Eingangsbestand ist dauerhaft an Umgebung und TRAFFIQX-ID gebunden
(`eingang-kontext.json`). Bei Abweichung erfolgen keine Inbox-Aufrufe; Vormerkungen
bleiben erhalten. Für Wiederaufnahme zur ursprünglichen Konfiguration zurückkehren.
Defekte/verlorene Kontextdateien aus passender Sicherung wiederherstellen.
Altbestände ohne Kontext erfordern nach Sicherung eine manuelle Herkunftsprüfung:
nur bei eindeutig einheitlicher Herkunft UTF-8-JSON mit
`format="MiniApp.InboxContext.v1"`, `environment="sandbox"` oder `"production"`
und ursprünglicher `traffiqx_id` als Text anlegen. Unklare Bestände zuerst zuordnen;
Vormerkungen niemals zum Umgehen der Sperre löschen.

### Protokoll

Sitzungsmeldungen zeigen lokale Zeit und Art (**Info**, **Warnung**, **Fehler**).
Doppelklick auf eine Zeile öffnet deren erste HTTP(S)-URL im Standardbrowser;
andere URI-Schemata werden nicht geöffnet. Der separate Hilfelink führt zum
letzten API-Fehler. Hilfe-URLs aus Versand und Eingang bleiben zusätzlich in
der zugehörigen Meldung erhalten. **Protokoll leeren** entfernt nur die sichtbaren
Sitzungsmeldungen; technische HTTP-Dateien und Fehlerquote bleiben erhalten.
Sitzungsmeldungen selbst werden beim Neustart nicht wiederhergestellt.

Beim Öffnen des Reiters oder mit **Fehlerquote aktualisieren** liest
`TTraffiqxHttpLog.GetErrorRate` im Worker die letzten **14 × 24 Stunden**.
Die Anzeige lautet **„x % Fehler bei n Anfragen“** mit Auswertungszeitpunkt.
Gezählt werden DATEV-Domains (`datev.de` und Subdomains), ohne Broker;
Quote = HTTP-Fehler (4xx/5xx) / Anfragen × 100. Transportfehler werden separat
genannt. Ziel nach Produktionsfreigabe: **unter 10 %**.
Keine Anfragen ergeben „nicht bestimmbar“. Nicht lesbare Tagesdateien werden als
unvollständige Auswertung gemeldet, ein unerreichbarer Ordner als nicht verfügbar.

Der HTTP-Schreiber arbeitet verzögert; unmittelbar nach einem Aufruf später erneut
aktualisieren. Die Quote umfasst alle DATEV-Anfragen im Datenordner, einschließlich
Sandbox/Produktion und verschiedener Verbindungen, soweit dort vorhanden. Für eine
getrennte Produktionsquote ist ein eigener Datenordner erforderlich.
Während Login oder laufendem Service-Vorgang ist die Aktualisierung gesperrt;
anschließend den Knopf verwenden. Es gibt weder Netzwerkaufruf noch Dauer-Polling
für die Quote. HTTP-Rohdaten werden in der Oberfläche nicht angezeigt.

## Abnahme-MUST → Stelle in Sample 2

Zuordnung aus [Sample2.md, Abschnitt 5](../../../Sample2.md#5-abnahme-musts-und-wo-sie-sichtbar-werden),
angepasst an den tatsächlichen Stand; Grundlage ist [Abnahme.md](../../../Abnahme.md).

| Abnahme-MUST | Stelle in Sample 2 |
|---|---|
| Anmeldeknopf, Ampel, Ablaufdatum, Person, Verbundene Anwendungen, TRAFFIQX-ID | Reiter Verbindung; Name benötigt Scope `profile` |
| Vor neuer Anmeldung widerrufen, nie mehr als ein gültiges Refresh-Token | `TMiniAppService.Connect`, Widerruf-/Anmeldemarker; unklare Browser-/Refresh-Ergebnisse bei DATEV klären |
| Verbindungscheck HTTP 200; bei Fehler widerrufen | Direkt nach Login und **Verbindung prüfen**, Inbox und Outbox |
| Tokens verschlüsseln, weder anzeigen noch protokollieren | DPAPI in `tokens.dat`, gefilterte Servicemeldungen/HTTP-Traces; Klartext-Client-Secret in `.env` ist eine offene Integrationsgrenze |
| HTTP-Protokoll mindestens 14 Tage, Fehlerquote unter 10 % | `TTraffiqxHttpLog` in `Daten/httplog`, Reiter Protokoll mit Worker-Auswertung; kundenseitig unsichtbare Ablage muss die Zielanwendung gewährleisten |
| Hilfe-URL bei 4xx | Hilfelink in Verbindung/Protokoll und Doppelklick auf Meldung; keine modalen Dialoge aus dem Polling-Callback |
| `document_id` und Status sichtbar | Ausgangsliste und Details; Eingangsliste zeigt ID, Format, Gültigkeit und Ablage |
| Alle Statuswerte behandeln, Polling auf Token-Laufzeit begrenzen | Service, `WaitForOutboxDocumentSent`, 8-s-Abstand/60-s-Grenze, Tokenreserve vor dem Worker, unbekannte Werte sichtbar und gesperrt |
| Metadaten/Download erst nach `sent`, Soll-/Ist-Kanal prüfen | Ausgang, `TraffiqxChannelMatches`, Warnung bei Abweichung |
| Dokumente visualisieren, GoBD-Archivierungsort nennen | **Original anzeigen**, **Dokument anzeigen**, Ordner und Hinweistexte; externe Anzeigeprogramme und echtes Archiv erforderlich |
| Posteingang initial/synchron abgleichen, kein Dauer-Polling | **Alle abgleichen**, **Posteingang abrufen**, persistente Offen-Liste |
| `document_format`, `en_16931_compliant` anzeigen, ungültige melden | Eingangsliste, rote Zeilen/Sammelhinweis, **Metadaten nachholen** |

## Architektur und bekannte Grenzen

`MiniApp.Model` hält Stammdaten, `MiniApp.Storage` Pfade und sichere Ablagen,
`MiniApp.InvoiceBuilder` erzeugt UBL, `MiniApp.Service` steuert DATEV und Worker,
`MiniApp.MainForm` enthält die VCL-Oberfläche. Hybridarchitektur: Broker für den
Tokenaustausch, Desktop für Dokumentdaten. Eine Rechnungsnummer ist die lokale
Entität, `document_id` die zugehörige DATEV-Entität; erneuter Versand erhält eine
neue ID mit Historie.

- Login-Polling, Verbindungscheck, Userinfo, Revoke und Refresh bleiben im Hauptthread.
  Synchrones Netz und die optionale KoSIT-Prüfung (60-s-Prozesslimit) können die
  Oberfläche blockieren. Versand/Eingang verwenden jeweils eine eigene API im
  Worker; Quote nur Dateizugriffe. Ein Service-Vorgang zur Zeit, Anzeigen per
  `TThread.Queue`. Beim Schließen kann auf den Abschluss gewartet werden;
  direktes Freigeben löst das Queue-Ziel und wartet auf den Worker.
- `.env` speichert ein konfiguriertes Client-Secret/API-Key im Klartext.
  Das Sample erfüllt damit nicht allein sämtliche Anforderungen an geschützte
  Client-Konfiguration. Die integrierende Anwendung muss diese Werte schützen.
  Name, Client-ID und TRAFFIQX-ID in `tokens.dat` sind ebenfalls Klartext;
  Access-/Refresh-Token sind DPAPI-verschlüsselt.
- HTTP-Dateien liegen lokal sichtbar; für eine Kundenanwendung ist eine geschützte,
  nicht für Kunden sichtbare Diagnoseablage nötig. Grenzen der Schwärzung siehe
  [Repository-README](../../../README.md). Die Fehlerquote ist keine Verfügbarkeitsmessung.
- Bei verlorenem Refresh-Ergebnis kann DATEV ein lokal unbekanntes neues Token
  besitzen. Der Widerruf des alten Tokens beweist nicht dessen Entfernung;
  unter **Verbundene Anwendungen** prüfen. Dasselbe gilt für abgebrochene Browser-Logins.
- Unklare Uploads haben keine automatische Entsperrung. Unlesbare/abweichende
  Bestände müssen gesichert und manuell geprüft werden, bevor Änderungen erfolgen.
- ZIPs werden vollständig im Speicher geprüft, einschließlich CRC; maximal
  256 MiB entpackt. Dateinamen werden bereinigt, Unterordner abgeflacht und Namen
  nummeriert. Erst vollständiges Schreiben/Flush veröffentlicht den Ordner.
  Unvollständige temporäre Ordner bleiben zur Diagnose; bestehende abweichende
  Ablagen werden nicht überschrieben.
- Die DATEV E-Rechnungsplattform archiviert nicht GoBD-konform. `original` und
  `eingang` sind lokale Ablagen; Unveränderbarkeit, Aufbewahrung und Sicherung
  benötigen ein geeignetes Archiv. XML/PDF-Anzeige erfolgt über externe Programme,
  das Sample enthält keinen eigenen Rechnungsviewer.
- Kein ZUGFeRD, Mehrbenutzerbetrieb, Mahnwesen, Druck oder Serverbetrieb.
  Weitere Build-Konfigurationen, DATEV-, KoSIT- und interaktive DPI-Prüfungen
  sind durch einen erfolgreichen Win32-Debug-Build nicht nachgewiesen.

## Prüfliste für einen Sandbox-Durchlauf

Nur fiktive, für die Sandbox geeignete Daten und einen separaten Bestand verwenden.
Keine produktiven Rechnungen für diesen Durchlauf senden.

1. **Start:** Sandbox, vier Kunden/zwei Positionen, lokale `.env` und eigener
   Datenordner. Stammdaten speichern, neu starten und Werte/Zähler prüfen.
2. **Verbinden:** Browser-Anmeldung abschließen. Inbox/Outbox jeweils HTTP 200,
   grüne Ampel, Name, Ablauf und TRAFFIQX-ID prüfen. Neustart und **Verbindung prüfen**.
3. **Je Kanal senden:** E-Mail, Leitweg-ID, TRAFFIQX und Peppol jeweils mit einer
   neuen Testrechnung. XML/PDF prüfen, optional KoSIT. **Senden**, persistierte
   ID/Status beobachten, erforderlichenfalls **Status abfragen** bis `sent`.
   Peppol-Upload verwendet `SBSZ:210`, übrige `SBSZ:110`; lokale XML bleibt unverändert.
   Zweiter Upload derselben aktiven Rechnung muss gesperrt sein, auch nach Neustart.
4. **Original:** Erst nach `sent` Metadaten, Soll-/Ist-Kanal und Original prüfen.
   Bei 202 später fortsetzen. **Original anzeigen**, alle Dateien öffnen und
   den genannten Archivierungsort mit der Ablage vergleichen.
5. **Posteingang:** Zuerst **Alle abgleichen**, danach **Posteingang abrufen**.
   ID, Absender, Datum, Format, Gültigkeit und Sammelwarnung prüfen. Dokument/Ordner
   öffnen, gegebenenfalls Metadaten nachholen. Erneuter Abgleich darf nicht doppelt ablegen.
6. **Protokoll:** Zeit/Art, Hilfe-Link und Doppelklick auf HTTP(S)-URL prüfen.
   Quote aktualisieren: Zeitraum, Anzahl, 4xx/5xx und Ziel < 10 % vergleichen.
   Leeren entfernt nur Sitzungsmeldungen; Quote und HTTP-Dateien bleiben bestehen.
7. **Trennen:** DATEV-Widerruf, lokal entfernte Tokens und rote Ampel prüfen.
   Erneuter Start darf keine aktive Verbindung zeigen. Kein Dauer-Polling im Leerlauf.
8. **Darstellung:** Fenster verkleinern und 100/150/200 Prozent DPI prüfen;
   Knöpfe, Listen, Hinweise und Protokoll müssen erreichbar bleiben.

Weitere Fehler-, Abbruch-, Wiederaufnahme- und Bestandsprüfungen sowie bisherige
Testergebnisse stehen in [PRUEFLISTE.md](PRUEFLISTE.md).
