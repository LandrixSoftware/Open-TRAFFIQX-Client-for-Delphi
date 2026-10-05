<?php

declare(strict_types=1);

use Landrix\OAuth2\Support\SessionStore;

require_once dirname(__DIR__) . '/vendor/autoload.php';
require_once __DIR__ . '/Support/SessionStore.php';
require_once __DIR__ . '/Support/Http.php';
require_once __DIR__ . '/Support/Security.php';
require_once __DIR__ . '/LandrixOAuthProvider.php';
require_once __DIR__ . '/provider_config.php';

function appConfig(): array
{
    static $config;
    if ($config !== null) {
        return $config;
    }

    $configPath = dirname(__DIR__) . '/config/app.php';
    if (!is_file($configPath)) {
        throw new RuntimeException('config/app.php wurde nicht gefunden.');
    }

    $config = require $configPath;

    $localPath = dirname(__DIR__) . '/config/app.local.php';
    if (is_file($localPath)) {
        $localConfig = require $localPath;
        if (is_array($localConfig)) {
            $config = array_replace_recursive($config, $localConfig);
            // Die Key-Liste ersetzt die Basiskonfiguration vollständig, sonst bliebe
            // deren Platzhalter-Key neben den eigenen Keys gültig.
            if (isset($localConfig['apiKeys']) && is_array($localConfig['apiKeys'])) {
                $config['apiKeys'] = $localConfig['apiKeys'];
            }
        }
    }

    return $config;
}

function sessionStore(): SessionStore
{
    static $store;
    if ($store !== null) {
        return $store;
    }

    $config = appConfig();
    $sessionConfig = $config['sessionStore'] ?? [];
    $path = $sessionConfig['path'] ?? (dirname(__DIR__) . '/session-store');
    $ttl = (int)($sessionConfig['defaultTtlSeconds'] ?? 900);
    $cleanup = (int)($sessionConfig['cleanupAfterSeconds'] ?? 3600);

    $store = new SessionStore($path, $ttl, $cleanup);
    $store->cleanupIfDue();

    return $store;
}
