<?php

declare(strict_types=1);

namespace Landrix\OAuth2\Support;

use function hash_equals;

function requireApiKey(array $registeredKeys): array
{
    // Leere Werte und Platzhalter aus den Beispielen (CHANGE_ME, EIN_LANGER_...) gelten
    // nicht als Key. Ohne einen echten Key bleibt der Broker geschlossen.
    $usableKeys = array_filter(
        $registeredKeys,
        static fn($value): bool => is_string($value)
            && $value !== ''
            && stripos($value, 'CHANGE_ME') !== 0
            && stripos($value, 'EIN_LANGER_') !== 0
    );

    if (empty($usableKeys)) {
        errorResponse(500, 'configuration_error', 'Keine API-Keys konfiguriert.');
    }

    $provided = getHeader('X-Api-Key');
    if ($provided === null || $provided === '') {
        errorResponse(401, 'missing_api_key', 'X-Api-Key Header fehlt.');
    }

    foreach ($usableKeys as $keyId => $value) {
        if (hash_equals($value, $provided)) {
            return ['id' => (string)$keyId, 'value' => $value];
        }
    }

    errorResponse(401, 'invalid_api_key', 'API-Key ist ungültig.');
}

function sanitizeSessionId(string $sessionId): string
{
    $trimmed = trim($sessionId);
    if ($trimmed === '') {
        errorResponse(400, 'invalid_session_id', 'SessionId darf nicht leer sein.');
    }

    if (!preg_match('/^[A-Za-z0-9\-_]{8,128}$/', $trimmed)) {
        errorResponse(400, 'invalid_session_id', 'SessionId hat ein ungültiges Format.');
    }

    return $trimmed;
}
