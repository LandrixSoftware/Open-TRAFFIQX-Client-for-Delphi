<?php

declare(strict_types=1);

return [
    // Registrierte API-Keys pro Client/Umgebung. Unbedingt anpassen!
    'apiKeys' => [
        'default' => 'CHANGE_ME',
    ],

    'sessionStore' => [
        'path' => dirname(__DIR__) . '/session-store',
        'defaultTtlSeconds' => 15 * 60,
        'cleanupAfterSeconds' => 60 * 60,
    ],

    'callback' => [
        'successMessage' => 'Authentifizierung abgeschlossen. Sie können dieses Fenster schließen.',
        'errorMessage' => 'Es ist ein Fehler aufgetreten. Bitte schließen Sie dieses Fenster und prüfen Sie den Desktop-Client.',
    ],
];
