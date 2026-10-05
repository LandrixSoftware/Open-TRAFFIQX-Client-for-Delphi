<?php

declare(strict_types=1);

require_once __DIR__ . '/bootstrap.php';

use Landrix\OAuth2\LandrixOAuthProvider;
use function Landrix\OAuth2\Support\errorResponse;
use function Landrix\OAuth2\Support\requestPayload;
use function Landrix\OAuth2\Support\requireString;
use function Landrix\OAuth2\Support\requireApiKey;
use function Landrix\OAuth2\Support\sanitizeSessionId;

$payload = requestPayload();
$apiKeyMeta = requireApiKey(appConfig()['apiKeys'] ?? []);
$sessionId = sanitizeSessionId(requireString($payload, 'sessionId'));
$provider = extractProviderSetup($payload);

$store = sessionStore();
if ($store->exists($sessionId)) {
    errorResponse(409, 'session_exists', 'SessionId ist bereits vergeben.');
}

try {
    $pkce = generatePkcePair();
    // Unvorhersehbarer state-Token gegen CSRF/Authorization-Code-Injection.
    // Aufbau: "<sessionId>.<token>" – der sessionId-Teil dient dem Callback zum
    // Auffinden der Session, der Token-Teil wird per hash_equals geprueft.
    $state = $sessionId . '.' . bin2hex(random_bytes(32));

    $sessionRecord = [
        'sessionId' => $sessionId,
        'status' => 'pending',
        'createdAt' => gmdate('c'),
        'updatedAt' => gmdate('c'),
        'expiresAt' => gmdate('c', time() + $store->defaultTtlSeconds()),
        'apiKeyId' => $apiKeyMeta['id'],
        'provider' => $provider,
        'pkce' => $pkce,
        'state' => $state,
        'tokens' => null,
        'error' => null,
    ];

    $store->write($sessionRecord);

    $extraParams = $provider['extraParams'];
    $enableWindowsSso = $extraParams['enableWindowsSso'] ?? null;
    unset($extraParams['enableWindowsSso'], $extraParams['applicationDisplayName']);

    $authorizationParams = [
        'scope' => $provider['scope'],
        'state' => $state,
        'code_challenge' => $pkce['challenge'],
        'code_challenge_method' => 'S256',
    ];

    $enableWindowsSsoFlag = null;
    if ($enableWindowsSso !== null) {
        $enableWindowsSsoFlag = filter_var($enableWindowsSso, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
    }

    if ($enableWindowsSsoFlag === true) {
        $authorizationParams['enableWindowsSso'] = 'true';
    }

    $authorizationParams = array_merge($authorizationParams, $extraParams);

    $oauthProvider = new LandrixOAuthProvider([
        'clientId' => $provider['clientId'],
        'clientSecret' => $provider['clientSecret'],
        'redirectUri' => $provider['redirectUri'],
        'urlAuthorize' => $provider['authorizationUri'],
        'urlAccessToken' => $provider['accessTokenUri'],
        'urlResourceOwnerDetails' => $provider['apiBaseUrl'],
    ]);

    $authorizationUrl = $oauthProvider->getAuthorizationUrl($authorizationParams);

    header('Location: ' . $authorizationUrl, true, 302);
    exit;
} catch (\Throwable $e) {
    $store->delete($sessionId);
    errorResponse(500, 'start_failed', 'Start konnte nicht vorbereitet werden: ' . $e->getMessage());
}

function generatePkcePair(): array
{
    $verifier = rtrim(strtr(base64_encode(random_bytes(64)), '+/', '-_'), '=');
    $challenge = rtrim(strtr(base64_encode(hash('sha256', $verifier, true)), '+/', '-_'), '=');

    return [
        'verifier' => $verifier,
        'challenge' => $challenge,
    ];
}
