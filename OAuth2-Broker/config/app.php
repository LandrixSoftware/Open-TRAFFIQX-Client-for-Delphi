<?php

declare(strict_types=1);

return [
    // Registrierte API-Keys pro Client/Umgebung. Unbedingt anpassen!
    'apiKeys' => [
        'default' => 'CHANGE_ME',
    ],

    // Hosts, deren Autorisierungs- und Token-Endpunkte der Broker annimmt.
    // Exakter Host ("login.datev.de") oder mit fuehrendem Punkt fuer alle
    // Subdomains (".datev.de"). Leer: jeder oeffentlich erreichbare https-Host,
    // interne/private Adressen werden abgewiesen. Fuer den Produktivbetrieb setzen.
    'providerHosts' => [],

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
