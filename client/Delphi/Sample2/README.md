# TIA Mini-Anwendung – Scheiben S1 und S2

Eigenständiges VCL-Projekt `TIAMiniApp.dproj` für Win32/Win64, jeweils Debug/Release.
Der Umfang folgt [`Sample2.md`](../../../Sample2.md): Stammdaten, JSON-Ablage und
Fenstergerüst sowie lokale XRechnung-Erzeugung mit Ausgangsliste. Verbindung,
Versand und Eingang folgen in S3–S6, die erweiterte Protokollauswertung in S7.
S1/S2 führen keine TIA-Aufrufe aus.

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
Warnhinweis gewählt werden. Die fiktiven Beispieldaten enthalten bewusst ungültige
Bank- und Steuerkennungen und sind keine versandfertige Rechnungsvorlage.

## Ablage und Konfiguration

`MiniApp.Storage` liefert Pfade unter `Daten` neben der EXE. Beim Start werden
`Daten`, `ausgang`, `eingang` und `httplog` angelegt. `InvoiceDirectory` und
`IncomingDocumentDirectory` liefern sichere Unterpfade ohne sie anzulegen.
`tokens.dat` und `eingang-offen.txt` sind nur vorgesehene Pfade; S1 schreibt sie nicht.
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

Build und Delphi-/KoSIT-Laufzeittests sind gemäß Auftrag nicht ausgeführt.
