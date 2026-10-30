# Sample 2 – ergänzende Regressionstests und bisherige Prüfergebnisse

Die aktuelle Bedienung und der Sandbox-Durchlauf stehen in [README.md](README.md).
Die folgenden Prüffälle decken insbesondere Fehler und Wiederaufnahme ab.

## Ressourcen und manuelle Prüfung

Eine vorhandene `.res` wird nicht benötigt: Die Delphi-IDE beziehungsweise
`CodeGear.Delphi.Targets` erzeugt sie beim Projektbuild über `BuildVersionResource`
aus den Versionsinformationen und dem Standardmanifest der `.dproj`.
`PerMonitorV2` ist für alle vier Konfigurationen gesetzt. Der direkte Aufruf von
`dcc32`/`dcc64` nur auf die `.dpr` führt diesen Ressourcenschritt nicht aus.
Die generierte `.res` bleibt lokal. Das Text-DFM verwendet Align, Anchors,
prozentuale Grid-Spalten/-Zeilen und Scrollboxen für kleinere Fenster.

Manuelle Prüfung in einem separaten Testbestand:

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
   `TTraffiqxHttpLog.RETENTION_DAYS` (14 Tage), Fehlerquote im Reiter **Protokoll** prüfen (siehe README).

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

### Prüfliste S7

1. Protokoll öffnen: Zeit und Art je Meldung, Hinweis auf 14 Tage und Zielwert
   unter 10 Prozent, Quote samt Zeitpunkt. Ohne Anfragen keine Erfolgsquote behaupten.
2. Mit lokalen Testdaten 200, 4xx, 5xx, Transportfehler, Broker-Anfragen und
   Einträge älter als 14 Tage prüfen. Nur DATEV-Anfragen im Zeitraum zählen;
   Transportfehler erscheinen separat. Gesperrte Tagesdatei: Auswertung als
   unvollständig melden; unerreichbarer Ordner: keine verfügbare Quote behaupten.
3. Während der Auswertung bleibt die Oberfläche bedienbar; erneute Auswertung
   und Netzwerkaktionen sind gesperrt. Beim Schließen Abschluss abwarten;
   direktes Freigeben mit eingereihten Meldungen darf keine freigegebenen Objekte aufrufen.
4. Hilfe-URLs aus Verbindung, Versand und Eingang per Doppelklick öffnen, auch
   ältere Meldungen nach einem weiteren Fehler. Nur HTTP(S), keine Datei-/anderen
   URI-Schemata. Je Zeile wird die erste HTTP(S)-URL geöffnet. Browseraufruf und
   Lesbarkeit bei 100/150/200 Prozent DPI interaktiv prüfen.
5. „Protokoll leeren“ entfernt ausschließlich Sitzungsmeldungen. HTTP-Dateien
   bleiben unverändert und die Fehlerquote bleibt sichtbar; erneutes Aktualisieren
   funktioniert. Neue Meldungen werden nach dem Leeren wieder angezeigt.

S7-Prüfung am 30.10.2026: Der vorgegebene Win32-Debug-Build endet mit ExitCode 0,
keine neuen Warnungen/Hinweise in Sample2-Units. Die bekannten Registry-, Suchpfad-
und Bibliothekshinweise bleiben bestehen. Isolierter Delphi-Laufzeittest im
Scratchpad: 20 Prüfungen erfolgreich, einschließlich leerer Protokolle,
4xx/5xx-Quote, Broker-/Zeitfilter, separater Transportfehler, gesperrter Tagesdatei,
DFM-Ereignisse, Zeit/Art, Worker-Ergebnisanzeige, Leeren ohne Dateiverlust,
Ignorieren von Nicht-HTTP-Zeilen und Service-/Formularfreigabe mit laufendem Worker.
DATEV-/Browser-/interaktive DPI-Prüfungen und weitere Build-Konfigurationen bleiben
offen; der Formular-Smoke-Test ersetzt keine interaktive Sichtprüfung.
