<?php

declare(strict_types=1);

require_once __DIR__ . '/bootstrap.php';

use function Landrix\OAuth2\Support\errorResponse;
use function Landrix\OAuth2\Support\jsonResponse;
use function Landrix\OAuth2\Support\requireApiKey;
use function Landrix\OAuth2\Support\sanitizeSessionId;

$apiKeyMeta = requireApiKey(appConfig()['apiKeys'] ?? []);
$sessionId = sanitizeSessionId($_GET['sessionId'] ?? '');

$store = sessionStore();
$session = $store->read($sessionId);

if ($session === null) {
    errorResponse(404, 'unknown_session', 'Session wurde nicht gefunden.');
}

if (($session['apiKeyId'] ?? null) !== $apiKeyMeta['id']) {
    errorResponse(403, 'forbidden', 'API-Key ist für diese Session nicht berechtigt.');
}

$now = time();
$expiresAt = isset($session['expiresAt']) ? strtotime((string)$session['expiresAt']) : null;
if ($expiresAt !== null && $expiresAt < $now) {
    $store->delete($sessionId);
    errorResponse(410, 'session_expired', 'Session ist abgelaufen.');
}

$status = $session['status'] ?? 'pending';

if ($status === 'pending') {
    jsonResponse(200, [
        'sessionId' => $sessionId,
        'status' => 'pending',
        'updatedAt' => $session['updatedAt'] ?? $session['createdAt'] ?? null,
    ]);
}

if ($status !== 'success' && $status !== 'error') {
    errorResponse(409, 'unknown_status', 'Unbekannter Session-Status.');
}

// Terminaler Status: Session atomar beanspruchen, damit parallele Polls die
// Tokens nicht doppelt erhalten. Wer das rename verliert, bekommt 404.
$claimed = $store->claim($sessionId);
if ($claimed === null) {
    errorResponse(404, 'unknown_session', 'Session wurde nicht gefunden.');
}

if (($claimed['status'] ?? null) === 'success') {
    jsonResponse(200, [
        'sessionId' => $sessionId,
        'status' => 'success',
        'tokens' => $claimed['tokens'] ?? null,
        'provider' => [
            'tenantId' => $claimed['provider']['tenantId'] ?? null,
            'apiBaseUrl' => $claimed['provider']['apiBaseUrl'] ?? null,
            'scope' => $claimed['provider']['scope'] ?? null,
        ],
        'updatedAt' => $claimed['updatedAt'] ?? null,
    ]);
}

jsonResponse(200, [
    'sessionId' => $sessionId,
    'status' => 'error',
    'error' => $claimed['error'] ?? null,
    'updatedAt' => $claimed['updatedAt'] ?? null,
]);
