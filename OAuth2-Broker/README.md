# OAuth2 Broker (DATEV/TRAFFIQX)

Der Dienst agiert als zentraler OAuth2-Broker zwischen Desktop-Clients, z. B. dem Delphi-Client, und DATEV/TRAFFIQX. Der Flow wird über die Endpunkte `/start`, `/callback` und `/poll` orchestriert. Die OAuth2-Provider-Daten werden pro Start-Request übergeben, Tokens werden serverseitig im `session-store` zwischengespeichert und beim erfolgreichen Polling einmalig an den berechtigten Client ausgeliefert.

## Voraussetzungen

- PHP 8.2 bis 8.5 (Bereich, den die Pakete aus `composer.lock` unterstützen).
- Composer, entweder global als `composer` oder lokal als `composer.phar`.
- Webserver mit PHP-Unterstützung. Apache kann die mitgelieferte `src/.htaccess` nutzen; bei nginx/IIS müssen die Routen auf die PHP-Dateien im Verzeichnis `src/` zeigen.
- Schreibrechte für den PHP-Prozess auf `session-store/`.
- OAuth2-Client beim Provider mit Redirect-URI auf `/callback`, z. B. `https://example.test/callback`.

## Installation

1. Repository auschecken und in den Broker wechseln:

```bash
cd /path/to/src-OAuth2-TIA/OAuth2-Broker
```

2. Abhängigkeiten installieren:

```bash
composer install --no-dev
```

Falls Composer nicht global installiert ist, kann eine lokale `composer.phar` verwendet werden. Diese Datei wird nicht ins Repository eingecheckt.

```bash
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php
php -r "unlink('composer-setup.php');"
php composer.phar install --no-dev
```

3. Konfiguration für die Zielumgebung anlegen:

```bash
cp config/app.php config/app.local.php
```

Unter Windows PowerShell:

```powershell
Copy-Item config/app.php config/app.local.php
```

4. `config/app.local.php` bearbeiten und mindestens eigene API-Keys setzen. Die Datei ist absichtlich nicht im Git enthalten. Die Liste `apiKeys` aus `app.local.php` ersetzt die aus `app.php` vollständig. Leere Werte und die Platzhalter aus den Beispielen (`CHANGE_ME…`, `EIN_LANGER_…`) nimmt der Broker nicht an; ohne einen echten Key antwortet er mit `500 configuration_error`. Einen Key erzeugt z. B. `php -r "echo bin2hex(random_bytes(32));"`.

```php
<?php

declare(strict_types=1);

return [
                'apiKeys' => [
                                'desktop-client' => 'EIN_LANGER_ZUFAELLIGER_API_KEY',
                ],
];
```

5. `session-store/` prüfen. Das Verzeichnis liegt im Repository als Platzhalter mit `.gitignore`; die darin entstehenden JSON-Dateien bleiben lokal und dürfen nicht committed werden.

```bash
mkdir -p session-store
chmod 700 session-store
```

Unter Windows muss der Benutzer, unter dem PHP läuft, Schreibrechte auf `OAuth2-Broker/session-store` haben.

6. Webroot auf `OAuth2-Broker/src` setzen. Der Webserver darf `config/`, `vendor/` und `session-store/` nicht direkt ausliefern.

## Konfiguration

Die Basiskonfiguration liegt in `config/app.php`. Produktive Werte gehören in `config/app.local.php`, weil diese Datei lokale Secrets enthält und von Git ignoriert wird.

- `apiKeys`: Mapping aus Client-ID zu Secret für Desktop-Clients. Der Client sendet das Secret im Header `X-Api-Key`.
- `providerHosts`: Hosts, deren Autorisierungs- und Token-Endpunkte der Broker annimmt; exakt (`login.example.com`) oder mit führendem Punkt für die Domain samt Subdomains (`.example.com`). Ist die Liste leer, nimmt der Broker jeden öffentlich erreichbaren https-Host auf Port 443 an und weist nur Hosts ab, die auf private, Loopback- oder reservierte Adressen zeigen. Für den Produktivbetrieb sollte die Liste gesetzt sein. Für die im Delphi-Client hinterlegten Provider passt:

```php
'providerHosts' => ['.datev.de', '.b4value.net', '.bdr-businessportal.de', '.sgh-net.de', '.quadient-eservices.com', '.ricoh-idx.net'],
```

- `sessionStore.path`: Speicherort für temporäre Session-Dateien. Standard ist `OAuth2-Broker/session-store`.
- `sessionStore.defaultTtlSeconds`: Lebensdauer einer begonnenen OAuth2-Session, bevor sie ohne Provider-Antwort abläuft.
- `sessionStore.cleanupAfterSeconds`: Intervall und Altersgrenze für das Aufräumen veralteter JSON-Dateien.
- `callback.successMessage` und `callback.errorMessage`: Texte für die Browser-Seite nach dem Provider-Callback.

## Endpunkte

### `GET /`

Health- und Diagnose-Endpunkt. Er liefert den Service-Status, ob der Session-Store beschreibbar ist (`sessionStoreWritable`) und die verfügbaren Endpunkte. Der absolute Pfad wird bewusst nicht ausgegeben.

```bash
curl https://example.test/
```

### `POST /start`

Startet eine OAuth2-Session und leitet den Browser per HTTP 302 zur Provider-Autorisierung weiter. Der Request muss den Header `X-Api-Key` enthalten. Als Body werden JSON oder `application/x-www-form-urlencoded` akzeptiert.

```bash
curl -i -X POST https://example.test/start \
        -H "Content-Type: application/json" \
        -H "X-Api-Key: EIN_LANGER_ZUFAELLIGER_API_KEY" \
        -d '{
                "sessionId": "demo-session-001",
                "providerClientId": "PROVIDER_CLIENT_ID",
                "providerClientSecret": "PROVIDER_CLIENT_SECRET",
                "providerRedirectUri": "https://example.test/callback",
                "providerAuthorizationUri": "https://provider.example/oauth/authorize",
                "providerAccessTokenUri": "https://provider.example/oauth/token",
                "providerScope": "openid profile offline_access",
                "providerTenantOrAccountId": "tenant-or-account",
                "providerApiBaseUrl": "https://api.provider.example",
                "extraParams": {
                        "enableWindowsSso": "true"
                }
        }'
```

Wichtige Felder:

- `sessionId`: Eindeutige ID des Desktop-Clients, 8 bis 128 Zeichen, erlaubt sind Buchstaben, Zahlen, `-` und `_`. Die ID wird unverändert als Dateiname im `session-store` verwendet; Zeichen wie `:` sind deshalb nicht zulässig (NTFS-Alternate-Data-Streams).
- `providerClientId` und `providerClientSecret`: OAuth2-Clientdaten des Providers. Sie werden nur in der temporären Session-Datei gespeichert.
- `providerRedirectUri`: Muss exakt zur beim Provider registrierten Callback-URL passen.
- `providerAuthorizationUri` und `providerAccessTokenUri`: Provider-Endpunkte für Authorization Code Flow mit PKCE.
- `providerScope`: Leerzeichengetrennte Scopes oder Array von Scopes.
- `extraParams`: Optionale zusätzliche Provider-Parameter. `enableWindowsSso=true` wird gesondert unterstützt.

Alle URLs müssen `https` verwenden (`providerRedirectUri` für lokale Tests auch `http://localhost` bzw. `http://127.0.0.1`). Autorisierungs- und Token-Endpunkt prüft der Broker zusätzlich gegen `providerHosts` bzw. auf interne Adressen, denn den Token-Endpunkt ruft er im Callback selbst auf. Weiterleitungen des Token-Endpunkts folgt er nicht.

### `GET /callback`

Wird vom OAuth2-Provider nach der Anmeldung aufgerufen. Der Broker prüft `state`, ob die Session noch offen (`pending`) und nicht abgelaufen ist, tauscht `code` gegen Tokens und speichert das Ergebnis im `session-store`. Ein zweiter Aufruf für dieselbe Session wird abgewiesen. Bei technischen Fehlern erhält der Client nur eine neutrale Meldung, die Einzelheiten landen im PHP-Fehlerlog des Servers. Dieser Endpunkt wird normalerweise nicht manuell aufgerufen.

### `GET /poll?sessionId=...`

Liefert den aktuellen Status einer Session. Der Request muss denselben `X-Api-Key` verwenden, mit dem `/start` aufgerufen wurde.

```bash
curl -s "https://example.test/poll?sessionId=demo-session-001" \
        -H "X-Api-Key: EIN_LANGER_ZUFAELLIGER_API_KEY"
```

Antwort während der Anmeldung:

```json
{
        "sessionId": "demo-session-001",
        "status": "pending",
        "updatedAt": "2026-04-30T12:00:00+00:00"
}
```

Antwort nach erfolgreicher Anmeldung:

```json
{
        "sessionId": "demo-session-001",
        "status": "success",
        "tokens": {
                "accessToken": "...",
                "refreshToken": "...",
                "expiresAt": "2026-04-30T13:00:00+00:00",
                "refreshTokenExpiresAt": "2026-05-01T13:00:00+00:00",
                "values": {}
        },
        "provider": {
                "tenantId": "tenant-or-account",
                "apiBaseUrl": "https://api.provider.example",
                "scope": "openid profile offline_access"
        },
        "updatedAt": "2026-04-30T12:01:00+00:00"
}
```

Nach `success` oder `error` löscht `/poll` die Session-Datei. Tokens werden dadurch nur einmal ausgeliefert.

## Fehlerfälle

Fehlerantworten sind JSON-Objekte mit `error` und `message`. Alle JSON-Antworten tragen `Cache-Control: no-store`.

- `401 missing_api_key`: Header `X-Api-Key` fehlt.
- `401 invalid_api_key`: API-Key passt zu keinem Eintrag in `apiKeys`.
- `400 missing_parameter`: Pflichtfeld im `/start`-Request fehlt.
- `400 invalid_parameter`: Feld ist leer oder eine URL wird abgewiesen (kein https, anderer Port als 443, Host nicht in `providerHosts` oder interne Adresse).
- `500 start_failed`: Der Flow konnte nicht vorbereitet werden; Details stehen im PHP-Fehlerlog.
- `400 invalid_session_id`: `sessionId` ist leer oder enthält nicht erlaubte Zeichen.
- `409 session_exists`: Eine Session mit dieser ID existiert bereits.
- `404 unknown_session`: `/poll` findet keine Session für die ID.
- `403 forbidden`: `/poll` wurde mit einem anderen API-Key als `/start` aufgerufen.
- `410 session_expired`: Session ist abgelaufen und wurde gelöscht.

## Sicherheit und Git-Hygiene

- `config/app.local.php` enthält echte API-Keys und darf nicht committed werden.
- `session-store/*.json` enthält temporär Provider-Clientdaten und Tokens. Diese Dateien dürfen nicht committed und nicht vom Webserver ausgeliefert werden.
- `vendor/` und `composer.phar` werden lokal erzeugt und nicht committed. Die reproduzierbare Dependency-Basis ist `composer.lock`.
- Webroot muss auf `src/` zeigen. So bleiben `config/`, `session-store/` und `vendor/` außerhalb des direkt erreichbaren Webbereichs.
- API-Keys sollten lang, zufällig und pro Client getrennt sein. Bei Verdacht auf Offenlegung Key austauschen und laufende Sessions löschen.

## Updates

Vor Updates prüfen, welche Pakete betroffen sind:

```bash
composer outdated
```

Pakete aktualisieren und anschließend testen:

```bash
composer update
```

Bei lokaler `composer.phar` entsprechend:

```bash
php composer.phar self-update
php composer.phar audit
php composer.phar outdated
php composer.phar update
```

## Kurzer Funktionstest

Für einen lokalen Smoke-Test kann PHPs eingebauter Server verwendet werden. Der produktive Betrieb sollte über den Ziel-Webserver erfolgen.

```bash
php -S 127.0.0.1:8080 -t src
```

Dann den Health-Endpunkt prüfen:

```bash
curl http://127.0.0.1:8080/
```

Erwartet wird eine JSON-Antwort mit `"status":"ok"`. Für einen vollständigen OAuth2-Test muss der Provider die lokale oder öffentliche Callback-URL erreichen können und die Redirect-URI exakt registriert sein.