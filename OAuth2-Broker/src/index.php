<?php

declare(strict_types=1);

require_once __DIR__ . '/bootstrap.php';

use function Landrix\OAuth2\Support\jsonResponse;

$config = appConfig();
$storePath = $config['sessionStore']['path'] ?? (dirname(__DIR__) . '/session-store');

jsonResponse(200, [
    'service' => 'oauth2-broker',
    'status' => 'ok',
    // Kein absoluter Pfad nach aussen – nur die diagnostisch relevante Schreibbarkeit.
    'sessionStoreWritable' => is_dir($storePath) && is_writable($storePath),
    'endpoints' => [
        'POST /start',
        'GET /callback',
        'GET /poll',
    ],
]);