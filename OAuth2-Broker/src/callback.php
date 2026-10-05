<?php

declare(strict_types=1);

require_once __DIR__ . '/bootstrap.php';

use Landrix\OAuth2\LandrixOAuthProvider;
use League\OAuth2\Client\Provider\Exception\IdentityProviderException;

$rawState = $_GET['state'] ?? null;
if ($rawState === null || $rawState === '') {
    renderCallbackView(false, 'State fehlt.');
}

// state hat die Form "<sessionId>.<token>"; der sessionId-Teil findet die Session.
$sessionId = validateSessionId(explode('.', $rawState, 2)[0]);

$store = sessionStore();
$session = $store->read($sessionId);

if ($session === null) {
    renderCallbackView(false, 'Session wurde nicht gefunden oder ist abgelaufen.');
}

if (!is_string($session['state'] ?? null) || !hash_equals($session['state'], (string)$rawState)) {
    renderCallbackView(false, 'Ungültiger state.');
}

// Nur eine offene, nicht abgelaufene Session darf den Callback verarbeiten.
// Das periodische Aufraeumen allein reicht nicht, und ein zweiter Aufruf darf
// ein bereits gespeichertes Ergebnis nicht ueberschreiben.
if (($session['status'] ?? null) !== 'pending') {
    renderCallbackView(false, 'Diese Anmeldung wurde bereits abgeschlossen.');
}
$sessionExpiresAt = isset($session['expiresAt']) ? strtotime((string)$session['expiresAt']) : false;
if ($sessionExpiresAt === false || $sessionExpiresAt < time()) {
    $store->delete($sessionId);
    renderCallbackView(false, 'Session wurde nicht gefunden oder ist abgelaufen.');
}

if (!empty($_GET['error'])) {
    $session['status'] = 'error';
    $session['error'] = [
        'code' => limitText((string)$_GET['error'], 64),
        'description' => limitText((string)($_GET['error_description'] ?? '')),
    ];
    $session['updatedAt'] = gmdate('c');
    $store->write($session);
    renderCallbackView(false, 'Der Provider hat einen Fehler gemeldet: ' . $session['error']['description']);
}

if (empty($_GET['code'])) {
    $session['status'] = 'error';
    $session['error'] = [
        'code' => 'missing_code',
        'description' => 'Autorisierungscode fehlt.',
    ];
    $session['updatedAt'] = gmdate('c');
    $store->write($session);
    renderCallbackView(false, 'Autorisierungscode fehlt.');
}

try {
    $providerConfig = $session['provider'];

    // Zwischen /start und Callback kann sich die DNS-Aufloesung geaendert haben.
    $endpointProblem = providerEndpointProblem((string)$providerConfig['accessTokenUri']);
    if ($endpointProblem !== null) {
        throw new \RuntimeException('Token-Endpunkt abgewiesen: ' . $endpointProblem);
    }

    $oauthProvider = new LandrixOAuthProvider([
        'clientId' => $providerConfig['clientId'],
        'clientSecret' => $providerConfig['clientSecret'],
        'redirectUri' => $providerConfig['redirectUri'],
        'urlAuthorize' => $providerConfig['authorizationUri'],
        'urlAccessToken' => $providerConfig['accessTokenUri'],
        'urlResourceOwnerDetails' => $providerConfig['apiBaseUrl'],
    ]);

    $accessToken = $oauthProvider->getAccessToken('authorization_code', [
        'code' => $_GET['code'],
        'code_verifier' => $session['pkce']['verifier'] ?? '',
    ]);

    $tokenExpiresAt = $accessToken->getExpires();

    // Refresh-Token-Ablauf aus refresh_expires_in ableiten (z. B. DATEV liefert
    // diesen Wert mit). So kennt der Client die Restlaufzeit bereits nach dem Login.
    $tokenValues = $accessToken->getValues();
    $refreshExpiresIn = isset($tokenValues['refresh_expires_in']) ? (int)$tokenValues['refresh_expires_in'] : 0;

    $session['status'] = 'success';
    $session['tokens'] = [
        'accessToken' => $accessToken->getToken(),
        'refreshToken' => $accessToken->getRefreshToken(),
        'expiresAt' => $tokenExpiresAt ? gmdate('c', (int)$tokenExpiresAt) : null,
        'refreshTokenExpiresAt' => $refreshExpiresIn > 0 ? gmdate('c', time() + $refreshExpiresIn) : null,
        'values' => $tokenValues,
    ];
    // Session-Laufzeit an die Token-Gültigkeit koppeln (Option A)
    $session['expiresAt'] = $tokenExpiresAt ? gmdate('c', (int)$tokenExpiresAt) : $session['expiresAt'];
    $session['error'] = null;
    $session['updatedAt'] = gmdate('c');

    $store->write($session);

    renderCallbackView(true, appConfig()['callback']['successMessage'] ?? 'Vorgang abgeschlossen.');
} catch (IdentityProviderException $e) {
    // Die Meldung stammt aus der Fehlerantwort des Providers (z. B. "invalid_grant")
    // und hilft dem Client; gekuerzt, damit keine langen Antwortinhalte durchgehen.
    $session['status'] = 'error';
    $session['error'] = [
        'code' => 'identity_provider_error',
        'description' => limitText($e->getMessage()),
    ];
    $session['updatedAt'] = gmdate('c');
    $store->write($session);
    renderCallbackView(false, 'Token konnte nicht abgeholt werden.');
} catch (\Throwable $e) {
    // Interne Details (Pfade, Netzwerkfehler) nur ins Server-Log, nicht zum Client.
    error_log('OAuth2-Broker callback ' . $sessionId . ': ' . $e->getMessage());
    $session['status'] = 'error';
    $session['error'] = [
        'code' => 'unexpected_error',
        'description' => 'Der Token-Abruf beim Provider ist fehlgeschlagen.',
    ];
    $session['updatedAt'] = gmdate('c');
    $store->write($session);
    renderCallbackView(false, 'Unerwarteter Fehler.');
}

function renderCallbackView(bool $success, string $message): void
{
    $title = $success ? 'Fertig' : 'Fehler';
    $defaultText = $success
        ? (appConfig()['callback']['successMessage'] ?? 'Authentifizierung abgeschlossen. Sie können dieses Fenster schließen.')
        : (appConfig()['callback']['errorMessage'] ?? 'Fehler beim OAuth2-Flow.');

    $text = $message !== '' ? $message : $defaultText;

    http_response_code($success ? 200 : 400);
    header('Content-Type: text/html; charset=utf-8');
    header('Cache-Control: no-store');
    header('Referrer-Policy: no-referrer');
    echo '<!DOCTYPE html><html lang="de"><head><meta charset="utf-8"><title>' . htmlspecialchars($title) . '</title>';
    echo '<meta name="viewport" content="width=device-width, initial-scale=1">';
    echo '<style>body{font-family:Segoe UI,Arial,sans-serif;background:#f4f4f4;margin:0;padding:2rem;}';
    echo '.panel{max-width:480px;margin:2rem auto;padding:2rem;background:#fff;border-radius:8px;box-shadow:0 2px 8px rgba(0,0,0,0.1);}';
    echo '.panel h1{margin-top:0;font-size:1.4rem;}';
    echo '.panel p{line-height:1.4;}';
    echo '</style></head><body><div class="panel"><h1>' . htmlspecialchars($title) . '</h1><p>' . htmlspecialchars($text) . '</p></div></body></html>';
    exit;
}

/** Kuerzt Text zeichenweise (UTF-8-sicher, ohne mbstring). */
function limitText(string $text, int $max = 200): string
{
    if (preg_match('/^.{0,' . $max . '}/us', $text, $m) !== 1) {
        return '';
    }

    return $m[0];
}

function validateSessionId(string $value): string
{
    $trimmed = trim($value);
    if ($trimmed === '' || !preg_match('/^[A-Za-z0-9\-_]{8,128}$/', $trimmed)) {
        renderCallbackView(false, 'Ungültige SessionId.');
    }

    return $trimmed;
}