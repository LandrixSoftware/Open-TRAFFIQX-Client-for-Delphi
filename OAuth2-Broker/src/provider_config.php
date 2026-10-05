<?php

declare(strict_types=1);

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

    return [
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
}
