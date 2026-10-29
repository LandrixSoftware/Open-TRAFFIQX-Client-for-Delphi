# TIA Mini-Anwendung – Scheiben S1 bis S3

Eigenständiges VCL-Projekt `TIAMiniApp.dproj` für Win32/Win64, jeweils Debug/Release.
Der Umfang folgt [`Sample2.md`](../../../Sample2.md): Stammdaten, JSON-Ablage und
Fenstergerüst, lokale XRechnung-Erzeugung mit Ausgangsliste und DATEV-Verbindung.
Versand und Eingang folgen in S4–S6, die erweiterte Protokollauswertung in S7.
S3 führt TIA-Aufrufe für Anmeldung, Check, Userinfo, Refresh und Widerruf aus.

## Start und Bedienung

Das Projekt direkt in Delphi öffnen; es ist noch nicht in der Projektgruppe
eingetragen. Die EXE liegt wie beim bisherigen Sample unter
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
`tokens.dat` enthält ab S3 die geschützten Tokens; `eingang-offen.txt` ist für S6 vorgesehen.
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

`TMiniAppService` besitzt genau eine API-Instanz und verwendet sie ausschließlich
im Hauptthread. Die synchronen Abläufe zeigen eine Sanduhr; Netzstörungen können
die Oberfläche bis zum HTTP-Timeout blockieren. Worker für weitere Abläufe gehören
zu S4. Abschluss- und Anzeige-Callbacks warten nicht auf Threads und rufen weder
`ProcessMessages` noch `CheckSynchronize` auf. Nur das Ereignis
`OnConfirmLoginUnconfirmed` darf vor einem neuen Login ohne laufendes Polling eine
modale Rückfrage öffnen; der Service bleibt ohne VCL-Abhängigkeit. Der statische
`TTraffiqxHttpLog`
schreibt auch die Polling-Anfragen threadsicher nach `Daten/httplog/`, mit 14 Tagen
Aufbewahrung. Er hält keine Referenz auf das Fenster oder den Service.

`EnsureAccessToken(AMinValidSeconds)` steht für die folgenden Scheiben bereit:
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
keine `outbox.json` existiert; vorhandene Textfelder `document_id` und `status`
werden daraus gelesen. S2 schreibt diese Versanddatei noch nicht.

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

Build sowie Delphi-/DATEV-/KoSIT-Laufzeittests sind gemäß Auftrag nicht ausgeführt.
