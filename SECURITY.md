# Sicherheit / Security

[Deutsch](#deutsch) | [English](#english)

## Deutsch

Stand: 2. Oktober 2026

### Eine Schwachstelle melden

Bitte melden Sie mögliche Sicherheitslücken in Open-TRAFFIQX-Client-for-Delphi (Delphi-Bibliothek,
Sample oder OAuth2-Broker) an den bestehenden Projektkontakt **[info@landrix.de](mailto:info@landrix.de)**,
mit dem Betreff `[Security] Open-TRAFFIQX-Client-for-Delphi: kurze Beschreibung`.
Bitte eröffnen Sie für noch nicht behobene Schwachstellen zunächst kein öffentliches Issue
und veröffentlichen Sie keine ausnutzbaren Beispiele.

Hilfreich sind:

- Betroffener Teil (Bibliothek, Sample oder Broker), möglichst Git-Commit sowie Angaben zu eigenen Änderungen.
- Delphi-Version beziehungsweise PHP-Version und Webserver, Betriebssystem und Architektur.
- Betroffener Aufruf oder Endpunkt, Umgebung (Sandbox oder Produktion) und relevante Konfiguration ohne Secrets.
- Schritte zur Reproduktion, erwartetes und beobachtetes Verhalten sowie mögliche Auswirkungen.
- Geschwärzte Protokollauszüge mit künstlichen Daten; keine Tokens, Client-Secrets, API-Keys,
  echten Rechnungen oder personenbezogenen Daten.
- Hinweise auf eine bekannte aktive Ausnutzung und eine erreichbare Kontaktadresse, soweit möglich.

Für sensible Details zunächst nur eine kurze Beschreibung senden und einen geeigneten
Übertragungsweg abstimmen. Die E-Mail-Adresse ist ein privater Kontaktweg, keine Zusage einer
Ende-zu-Ende-verschlüsselten Übertragung oder einer rund um die Uhr besetzten Meldestelle.
Eine Meldung an das Projekt ersetzt keine gegebenenfalls erforderliche Behördenmeldung.

Wurde ein Token, Client-Secret oder API-Key veröffentlicht, widerrufen beziehungsweise rotieren
Sie es bitte sofort, unabhängig von der Meldung an uns.

### Unterstützte Versionen und Bearbeitung

Im Repository ist zum oben genannten Stand keine verbindliche Tabelle mit Sicherheits-Supportzeiträumen
oder End-of-Support-Daten je Release veröffentlicht. Eine ältere Version oder der aktuelle
Entwicklungsstand darf daher nicht allein aufgrund ihrer Verfügbarkeit als sicherheitsgepflegt
eingeordnet werden.

Meldungen können auch ältere Versionen betreffen. Bitte nennen Sie immer den genauen Stand.
Es werden hier keine festen Reaktionszeiten, Behebungsfristen oder Rückportierungen zugesagt.
Vertragliche Rechte und gesetzliche Pflichten bleiben unberührt; insbesondere ändert dieses
Dokument nicht die Lizenzbedingungen oder bestehende Updateberechtigungen.

Zur Bearbeitung einer Meldung sollten Betroffenheit, Reproduzierbarkeit, Schweregrad, mögliche
Abhilfe und die koordinierte Veröffentlichung geklärt werden. Ein verbindlicher interner Ablauf
mit Zuständigkeiten und Vertretung ist noch gesondert festzulegen; diese Beschreibung ist kein
Nachweis eines bereits eingerichteten Incident-Response-Prozesses.

### Hinweise zur Integration

Hersteller der einbindenden Anwendung sind für den Schutz ihrer Zugangsdaten und Tokens selbst
verantwortlich. Insbesondere:

- Access- und Refresh-Tokens nur verschlüsselt speichern (zum Beispiel mit `intf.TRAFFIQXTokenProtection`)
  und nie protokollieren.
- Den OAuth2-Broker nur über HTTPS betreiben, eigene API-Keys setzen und Verzeichnisse für
  Konfiguration und Sessions vor Webzugriff schützen.
- Das technische HTTP-Protokoll vor unbefugtem Zugriff schützen. Bekannte Header und Felder mit Tokens
  und Secrets werden gefiltert; das Protokoll kann dennoch sensible Inhalte enthalten, etwa in Fehlertexten
  der Plattform. Auszüge vor einer Weitergabe deshalb prüfen.
- Antworten der Plattform und heruntergeladene Rechnungen als nicht vertrauenswürdige Eingaben behandeln.

Weitere Vorgaben stehen in [`Integration.md`](Integration.md) und [`Abnahme.md`](Abnahme.md).

## English

As of 2 October 2026

### Reporting a vulnerability

Please report potential security vulnerabilities in Open-TRAFFIQX-Client-for-Delphi (Delphi library,
sample or OAuth2 broker) to the existing project contact **[info@landrix.de](mailto:info@landrix.de)**,
using the subject `[Security] Open-TRAFFIQX-Client-for-Delphi: short description`.
Please do not initially open a public issue for an unresolved vulnerability or publish
examples that demonstrate how to exploit it.

Useful information includes:

- Affected part (library, sample or broker), preferably the Git commit, together with details of local modifications.
- Delphi version or PHP version and web server, operating system and architecture.
- Affected API call or endpoint, environment (sandbox or production) and relevant configuration without secrets.
- Reproduction steps, expected and observed behaviour, and potential impact.
- Redacted log excerpts with synthetic data; no tokens, client secrets, API keys,
  real invoices or personal data.
- Any known active exploitation and a contact address, where possible.

For sensitive details, initially send only a brief description and agree on a suitable
transfer method. The email address is a private contact channel, not a promise of end-to-end
encrypted transmission or a reporting service staffed around the clock.
Reporting to the project does not replace any required report to authorities.

If a token, client secret or API key has been published, please revoke or rotate it immediately,
regardless of your report to us.

### Supported versions and handling

As of the date above, the repository does not publish a binding table of security support periods
or end-of-support dates per release. Availability alone therefore does not establish security
maintenance for an older version or the current development revision.

Reports may also concern older versions. Please always identify the exact revision.
This document does not promise fixed response times, remediation deadlines or backports.
Contractual rights and statutory obligations remain unaffected; in particular, this document
does not change licence terms or existing update entitlements.

Handling a report should establish affected versions, reproducibility, severity, possible
remediation and coordinated disclosure. A binding internal procedure with responsibilities and
backup contacts still needs to be defined separately; this description is not evidence of an
incident response process already being in place.

### Integration guidance

Manufacturers integrating the library are responsible for protecting their credentials and tokens.
In particular:

- Store access and refresh tokens only in encrypted form (for example with `intf.TRAFFIQXTokenProtection`)
  and never log them.
- Run the OAuth2 broker over HTTPS only, set your own API keys and protect the configuration and
  session directories from web access.
- Protect the technical HTTP log from unauthorised access. Known headers and fields containing tokens
  and secrets are filtered; the log may still contain sensitive content, for example in error messages
  returned by the platform. Review excerpts before sharing them.
- Treat platform responses and downloaded invoices as untrusted input.

Further requirements are described in [`Integration.md`](Integration.md) and [`Abnahme.md`](Abnahme.md).
