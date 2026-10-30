# Plan: Sample 2 – eine kleine Anwendung mit DATEV-Anbindung

Stand 29.10.2026, Entscheidungen E1–E5 getroffen.

## 1. Ziel

Das bestehende Sample (`client/Delphi/Sample`) ist eine Testbank: ein Knopf je API-Aufruf, die
Sandbox-Szenarien fest eingebaut. Sample 2 zeigt dagegen, **wie eine Anwendung um die Bibliothek
herum aussehen muss**, damit sie die DATEV-Abnahme besteht und im Alltag nichts verliert:

- Stammdaten (eigener Rechnungssteller, einige Kunden)
- Verbindung mit DATEV herstellen, prüfen und trennen
- Ausgangsrechnung aus den Stammdaten erzeugen und versenden, bis zum archivierten Original
- Posteingang abrufen, ohne Dokumente zu verlieren
- Protokoll und Fehleranzeige mit Hilfe-URL

Sample 2 ist zugleich eine Vorlage für den Abnahmetermin: Jeder MUST aus [`Abnahme.md`](Abnahme.md)
hat eine sichtbare Stelle (Abschnitt 5).

**Nicht** Ziel: ZUGFeRD-PDF, mehrere Benutzer, Mahnwesen, Druck, Server-Betrieb. Wer einen Server
baut, liest [`Integration.md`](Integration.md) Abschnitt 3; Sample 2 bleibt eine Desktop-Anwendung
mit lokal verschlüsselten Tokens.

## 2. Aufbau

Ordner `client/Delphi/Sample2`, Projekt `TIAMiniApp.dpr`. Wenige Units mit klarer Trennung, damit
das Sample bei Bibliotheksänderungen leicht nachzuziehen ist:

| Unit | Inhalt | kennt UI? |
|---|---|---|
| `MiniApp.Model` | Records für Rechnungssteller, Kunde, Testposition; Laden/Speichern als JSON | nein |
| `MiniApp.Storage` | Datenordner, Ablage je Rechnung und je Eingangsdokument, Offen-Liste, Tokens (DPAPI) | nein |
| `MiniApp.InvoiceBuilder` | `TInvoice` aus Stammdaten → XRechnung (UBL) über `XRechnung-for-Delphi`; Belegbild = feste Platzhalter-PDF (E1) | nein |
| `MiniApp.Service` | alle TIA-Abläufe: Verbindung, Refresh, Versand, Status, nach `sent`, Posteingang. Meldungen über einen Protokoll-Callback | nein |
| `MiniApp.MainForm` | Oberfläche mit Reitern (Abschnitt 4) | ja |

Die Service-Unit ist der Teil, den ein Integrator in seine Anwendung übernimmt. Sie ist später auch
der Ort für ein Login-Fenster (V3) und eine einfache Token-Verwaltung (V6).

## 3. Datenablage

Ein Datenordner (Vorgabe: `Daten` neben der EXE, in den Einstellungen änderbar):

```
Daten\
  stammdaten.json          Rechnungssteller, Kunden, Testpositionen, Einstellungen
  tokens.dat               Access-/Refresh-Token, DPAPI-verschlüsselt (MUST)
  httplog\                 technisches HTTP-Protokoll, 14 Tage (TTraffiqxHttpLog, MUST)
  ausgang\<RgNr>\
    rechnung.xml           erzeugte XRechnung (unverändert)
    belegbild.pdf          Kopie der Platzhalter-PDF (Sichtkomponente)
    outbox.json            document_id, Status, Kanal soll/ist, Metadaten, Zeitstempel
    original\              von DATEV erzeugtes Original nach "sent"
  eingang\<document_id>\   entpackte Dateien + metadata.json
  eingang-offen.txt        vorgemerkte IDs (R4-Muster)
```

`outbox.json` wird **vor** dem Warten auf `sent` geschrieben (atomar über Temp-Datei). Steht dort
eine `document_id` mit einem anderen Status als `error`/`deleted`, ist „Senden“ gesperrt. Eine
Rechnungsnummer wird nie wiederverwendet.

## 4. Oberfläche

Ein Hauptfenster mit fünf Reitern:

1. **Verbindung** – Umgebung (Sandbox/Produktion), TRAFFIQX-ID, Knopf „Mit DATEV verbinden“, Ampel,
   Ablauf des Refresh-Tokens (`TT.MM.JJJJ HH:MM`), Name aus Userinfo, „Verbindung prüfen“,
   „Verbindung trennen“ (Revoke), Link auf „Verbundene Anwendungen“.
2. **Stammdaten** – eigener Rechnungssteller (Name, Anschrift, USt-IdNr., Bank, Kontakt), Kunden-Liste
   mit Versandweg je Kunde: E-Mail, Leitweg-ID oder TRAFFIQX-ID. Drei Beispielkunden sind vorbelegt.
3. **Ausgang** – Liste der Rechnungen mit Nummer, Kunde, Betrag, `document_id`, Status, Versandkanal.
   Knöpfe: „Neue Testrechnung“ (Kunde wählen, Positionen aus den Stammdaten), „Senden“,
   „Status abfragen“, „Original anzeigen“. Unten ein Detailbereich mit allen Feldern aus `outbox.json`.
4. **Eingang** – Liste mit `document_id`, Absender, Eingang, Format, EN-16931-Gültigkeit (ungültige
   rot). Knöpfe: „Posteingang abrufen“, „Dokument anzeigen“. Hinweis auf den Ort der Archivierung.
5. **Protokoll** – Meldungen des Service mit Zeit und Art, Hilfe-URL anklickbar; Fehlerquote der
   letzten 14 Tage.

Netzwerkaufrufe laufen in einem Worker-Thread (`TTask`), Meldungen kommen per `TThread.Queue` in die
Oberfläche. Das Login-Polling bleibt, wie die Bibliothek es verlangt, im Hauptthread.

## 5. Abnahme-MUSTs und wo sie sichtbar werden

| MUST (Abnahme.md) | Stelle in Sample 2 |
|---|---|
| Anmeldung über Schaltfläche, Ampel, Ablaufdatum, Name der Person, Link „Verbundene Anwendungen“, TRAFFIQX-ID | Reiter Verbindung |
| Vor neuer Anmeldung widerrufen, nie mehr als ein Refresh-Token | Service: `Connect` widerruft zuerst |
| Verbindungscheck mit HTTP 200, bei Fehler Tokens widerrufen | „Verbindung prüfen“, auch direkt nach der Anmeldung |
| Tokens verschlüsselt, nie anzeigen oder protokollieren | `tokens.dat` per DPAPI, Protokoll ohne Tokens |
| HTTP-Protokoll 14 Tage, Fehlerquote | `httplog\`, Reiter Protokoll |
| Hilfe-URL bei 4xx | Protokoll und Fehlerdialoge |
| `document_id` und Status für den Kunden sichtbar | Ausgang- und Eingang-Liste |
| Alle Statuswerte verarbeiten, Polling auf Token-Laufzeit begrenzt | Service: `WaitForOutboxDocumentSent` 8 s / 60 s, Token vorher erneuert |
| Metadaten und Download erst nach `sent`, Kanal soll/ist prüfen | Service: Ablauf nach `sent`, `TraffiqxChannelMatches` |
| Dokumente visualisieren, Ort der GoBD-Archivierung nennen | „Original anzeigen“, „Dokument anzeigen“, Hinweistexte |
| Posteingang initial abgleichen und synchron halten, kein Dauer-Polling | „Posteingang abrufen“ auf Knopfdruck, Offen-Liste |
| `document_format`, `en_16931_compliant` anzeigen, ungültige melden | Eingang-Liste, Sammelhinweis nach dem Abruf |

## 6. Abläufe

**Senden** (Service, Worker-Thread):
1. Sperre prüfen (`outbox.json` mit aktiver `document_id` → abbrechen).
2. Access-Token erneuern, wenn es nicht mehr mindestens 2 Minuten gilt; neue Tokens sofort speichern.
3. XML laden; in der Sandbox `PrepareSandboxXml` mit `SBSZ:110` bzw. `SBSZ:210` (Peppol).
4. `UploadStructuredData`. Bei Erfolg sofort `outbox.json` mit `document_id`, `status=inProcess`,
   Kanal soll, Uploadzeit schreiben. Bei `#PARSE` nach HTTP 201: nicht erneut senden, Hinweis.
5. `WaitForOutboxDocumentSent` mit Fortschritt ins Protokoll; Status nachtragen.
6. Bei `sent`: Metadaten holen, Kanal prüfen, Original herunterladen und ablegen.

**Status abfragen** wiederholt 5–6 für Rechnungen, die noch nicht abgeschlossen sind.

**Posteingang abrufen**: vorgemerkte IDs zuerst, dann neue (`AUseDownloadedFilter`); je Dokument
vormerken → Download → ZIP vollständig lesen → ablegen → Metadaten → austragen; 404 trägt aus.

## 7. Entscheidungen (29.10.2026)

- **E1 Versand und Sicht-PDF.** Nur XRechnung (UBL) über `UploadStructuredData`, kein ZUGFeRD. Als
  Belegbild (Sichtkomponente) dient eine feste, neutrale Platzhalter-PDF `Belegbild-Platzhalter.pdf`
  im Sample-Ordner („Testrechnung – Belegbild (Platzhalter)“). Lehnt DATEV sie ab, wird eine der
  vorhandenen PDFs aus `testdata` genommen.
- **E2 Datenordner.** `Daten` neben der EXE.
- **E3 Umgebung.** Sandbox voreingestellt, Produktion umschaltbar mit Warnhinweis.
- **E4 Rechnungsnummern.** Fortlaufend in `stammdaten.json` (`TEST-0001` …), nie wiederverwendet.
- **E5 Client-Daten.** Client-ID, Broker-URL und API-Key wie im Sample aus einer INI-Datei, die nicht
  eingecheckt wird.

## 8. Scheiben

| Scheibe | Inhalt | ohne DATEV testbar? | Status | Commit-Hinweis |
|---|---|---|---|---|
| S1 | Gerüst, `Model`, `Storage`, Reiter Stammdaten, Beispieldaten | ja | umgesetzt | d79dcbd |
| S2 | `InvoiceBuilder`: XRechnung aus Stammdaten, Platzhalter-PDF, optional KoSIT-Validierung | ja | umgesetzt | ec0c9db |
| S3 | Reiter Verbindung: Anmelden, Prüfen, Trennen, Userinfo, Token-Ablage | Sandbox | umgesetzt | ec9e4da |
| S4 | Senden und Status bis `sent`, `outbox.json`, Sperre gegen doppeltes Senden | Sandbox | umgesetzt | f3b26f5 (gemeinsam mit S5) |
| S5 | Nach `sent`: Metadaten, Kanalprüfung, Original | Sandbox | umgesetzt | f3b26f5 (gemeinsam mit S4) |
| S6 | Posteingang mit Offen-Liste und Gültigkeitsanzeige | Sandbox | umgesetzt | 0efda25 |
| S7 | Reiter Protokoll, Fehlerquote, README-Abschnitt, Abgleich mit Abnahme.md | – | umgesetzt | Arbeitsstand; auf Wunsch nicht committet |

Geschätzt 3–5 Arbeitstage. Jede Scheibe einzeln gebaut, geprüft und committet.
