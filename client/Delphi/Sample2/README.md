# TIA Mini-Anwendung – Scheibe S1

Eigenständiges VCL-Projekt `TIAMiniApp.dproj` für Win32/Win64, jeweils Debug/Release.
Der Umfang folgt [`Sample2.md`](../../../Sample2.md): Stammdaten, JSON-Ablage und
Fenstergerüst. Verbindung, Rechnungserzeugung, Versand und Eingang folgen in S2–S6,
die erweiterte Protokollauswertung in S7. S1 führt keine TIA-Aufrufe aus.

## Start und Bedienung

Das Projekt direkt in Delphi öffnen; es ist noch nicht in der Projektgruppe
eingetragen. Die EXE liegt wie beim bisherigen Sample unter
`Win32|Win64/Debug|Release`. Der Bibliotheks- und XRechnung-Suchpfad ist übernommen;
S1 verwendet nur RTL und VCL und benötigt weder WebView2 noch Fremdpakete.

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

Fehlt `stammdaten.json`, erzeugt `TMiniAppData.LoadFromFile` drei Kunden, zwei
Testpositionen und den Rechnungszähler `TEST-0001`. Bei unlesbarer oder ungültiger
Datei bricht der Start ab; vorhandene Daten werden nicht zurückgesetzt.
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
`OAUTH2_BROKER_API_KEY` als einfache `NAME=WERT`-Zeilen. Werte werden nicht
protokolliert. Ohne `.env` funktioniert die Stammdatenpflege ebenfalls.

`PlaceholderPdfPath` sieht `Belegbild-Platzhalter.pdf` neben der EXE vor, alternativ
im Sample2-Ordner zwei Ebenen darüber. Die PDF wird in S1 weder benötigt noch
geöffnet oder erzeugt.

## Ressourcen und manuelle Prüfung

Eine vorhandene `.res` wird nicht benötigt: Die Delphi-IDE beziehungsweise
`CodeGear.Delphi.Targets` erzeugt sie beim Projektbuild über `BuildVersionResource`
aus den Versionsinformationen und dem Standardmanifest der `.dproj`.
`PerMonitorV2` ist für alle vier Konfigurationen gesetzt. Der direkte Aufruf von
`dcc32`/`dcc64` nur auf die `.dpr` führt diesen Ressourcenschritt nicht aus.
Die generierte `.res` bleibt lokal. Das Text-DFM verwendet Align, Anchors,
prozentuale Grid-Spalten/-Zeilen und Scrollboxen für kleinere Fenster.

Nach dem Build durch den Auftraggeber prüfen:

1. Erststart ohne Daten: fünf Hauptreiter, drei Kunden, zwei Positionen, Sandbox.
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

Build und Laufzeittests sind für diese Lieferung ausdrücklich nicht ausgeführt.
