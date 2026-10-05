<?php

declare(strict_types=1);

use function Landrix\OAuth2\Support\errorResponse;
use function Landrix\OAuth2\Support\optionalArray;
use function Landrix\OAuth2\Support\requireString;

function normalizeScope(mixed $scope): string
{
    if (is_array($scope)) {
        $scope = implode(' ', array_map('trim', $scope));
    }

    $scope = trim((string)$scope);
    $scope = preg_replace('/\s+/', ' ', $scope) ?? '';

    return $scope;
}

function extractProviderSetup(array $payload): array
{
    $extraParams = optionalArray($payload, 'extraParams');
    $sanitizedExtras = [];
    foreach ($extraParams as $key => $value) {
        if (!is_string($key)) {
            continue;
        }
        if (is_scalar($value)) {
            $sanitizedExtras[$key] = (string)$value;
        }
    }

    $setup = [
        'clientId' => requireString($payload, 'providerClientId'),
        'clientSecret' => requireString($payload, 'providerClientSecret'),
        'redirectUri' => requireString($payload, 'providerRedirectUri'),
        'authorizationUri' => requireString($payload, 'providerAuthorizationUri'),
        'accessTokenUri' => requireString($payload, 'providerAccessTokenUri'),
        'scope' => normalizeScope($payload['providerScope'] ?? ''),
        'tenantId' => requireString($payload, 'providerTenantOrAccountId'),
        'apiBaseUrl' => requireString($payload, 'providerApiBaseUrl'),
        'extraParams' => $sanitizedExtras,
    ];

    // Den Token-Endpunkt ruft der Broker selbst auf (SSRF), den Autorisierungs-
    // Endpunkt nur der Browser; beide muessen trotzdem zum Provider gehoeren.
    $checks = [
        'providerAuthorizationUri' => [$setup['authorizationUri'], true],
        'providerAccessTokenUri' => [$setup['accessTokenUri'], true],
        'providerApiBaseUrl' => [$setup['apiBaseUrl'], false],
        'providerRedirectUri' => [$setup['redirectUri'], false],
    ];
    foreach ($checks as $key => [$url, $isProviderEndpoint]) {
        $problem = $isProviderEndpoint
            ? providerEndpointProblem($url)
            : urlSyntaxProblem($url, $key === 'providerRedirectUri');
        if ($problem !== null) {
            errorResponse(400, 'invalid_parameter', 'Parameter ' . $key . ': ' . $problem);
        }
    }

    return $setup;
}

/**
 * Prueft Form und Schema einer URL. Erlaubt ist nur https, beim Redirect fuer
 * lokale Tests zusaetzlich http auf localhost/127.0.0.1.
 */
function urlSyntaxProblem(string $url, bool $allowLocalHttp = false): ?string
{
    $parts = parse_url($url);
    if ($parts === false || empty($parts['scheme']) || empty($parts['host'])) {
        return 'keine gueltige URL.';
    }
    if (isset($parts['user']) || isset($parts['pass'])) {
        return 'Zugangsdaten in der URL sind nicht erlaubt.';
    }

    $scheme = strtolower($parts['scheme']);
    $host = strtolower($parts['host']);
    if ($scheme === 'https') {
        return null;
    }
    if ($allowLocalHttp && $scheme === 'http' && in_array($host, ['localhost', '127.0.0.1', '[::1]'], true)) {
        return null;
    }

    return 'nur https ist erlaubt.';
}

/**
 * Prueft einen Provider-Endpunkt, den der Broker selbst aufruft. Ist in der
 * Konfiguration `providerHosts` gesetzt, muss der Host darauf stehen (exakt oder
 * als Subdomain eines Eintrags mit fuehrendem Punkt, z. B. ".datev.de").
 * Ohne Liste werden zumindest Hosts abgewiesen, die auf private, Loopback- oder
 * reservierte Adressen zeigen.
 */
function providerEndpointProblem(string $url): ?string
{
    $problem = urlSyntaxProblem($url);
    if ($problem !== null) {
        return $problem;
    }

    $host = strtolower((string)parse_url($url, PHP_URL_HOST));
    $port = parse_url($url, PHP_URL_PORT);
    if ($port !== null && $port !== 443) {
        return 'nur Port 443 ist erlaubt.';
    }

    $allowedHosts = appConfig()['providerHosts'] ?? [];
    if (!empty($allowedHosts)) {
        foreach ($allowedHosts as $allowed) {
            $allowed = strtolower(trim((string)$allowed));
            if ($allowed === '') {
                continue;
            }
            if ($host === ltrim($allowed, '.')
                || (str_starts_with($allowed, '.') && str_ends_with($host, $allowed))) {
                return null;
            }
        }
        return 'Host ist nicht freigegeben (providerHosts).';
    }

    $ipHost = trim($host, '[]');
    $addresses = filter_var($ipHost, FILTER_VALIDATE_IP) ? [$ipHost] : resolveHostAddresses($host);
    if (empty($addresses)) {
        return 'Host ist nicht aufloesbar.';
    }
    foreach ($addresses as $address) {
        if (!filter_var($address, FILTER_VALIDATE_IP, FILTER_FLAG_NO_PRIV_RANGE | FILTER_FLAG_NO_RES_RANGE)) {
            return 'Host zeigt auf eine interne Adresse.';
        }
    }

    return null;
}

function resolveHostAddresses(string $host): array
{
    $addresses = [];
    $records = @dns_get_record($host, DNS_A | DNS_AAAA) ?: [];
    foreach ($records as $record) {
        if (!empty($record['ip'])) {
            $addresses[] = $record['ip'];
        }
        if (!empty($record['ipv6'])) {
            $addresses[] = $record['ipv6'];
        }
    }
    if (empty($addresses)) {
        $addresses = @gethostbynamel($host) ?: [];
    }

    return $addresses;
}
