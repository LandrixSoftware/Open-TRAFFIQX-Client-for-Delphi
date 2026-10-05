<?php

declare(strict_types=1);

namespace Landrix\OAuth2\Support;

use Throwable;

function jsonResponse(int $statusCode, array $payload): void
{
    http_response_code($statusCode);
    header('Content-Type: application/json');
    // Antworten (insbesondere die Tokens aus /poll) nie zwischenspeichern
    header('Cache-Control: no-store');
    header('Pragma: no-cache');
    echo json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR);
    exit;
}

function errorResponse(int $statusCode, string $error, string $message, array $meta = []): void
{
    $body = array_merge([
        'error' => $error,
        'message' => $message,
    ], $meta);
    jsonResponse($statusCode, $body);
}

function readJsonBody(): array
{
    $content = file_get_contents('php://input');
    if ($content === false || $content === '') {
        return [];
    }

    try {
        $decoded = json_decode($content, true, 512, JSON_THROW_ON_ERROR);
        return is_array($decoded) ? $decoded : [];
    } catch (Throwable $e) {
        errorResponse(400, 'invalid_json', 'Request-Body konnte nicht geparst werden.');
    }
}

function readFormData(): array
{
    if (!empty($_POST)) {
        return $_POST;
    }

    $content = file_get_contents('php://input');
    if ($content === false || $content === '') {
        return [];
    }

    $data = [];
    parse_str($content, $data);
    return is_array($data) ? $data : [];
}

function requestPayload(): array
{
    $contentType = $_SERVER['CONTENT_TYPE'] ?? '';

    if (str_contains($contentType, 'application/json')) {
        return readJsonBody();
    }

    if (str_contains($contentType, 'application/x-www-form-urlencoded')) {
        return readFormData();
    }

    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        return $_GET;
    }

    return readJsonBody();
}

function requireString(array $payload, string $key, bool $allowEmpty = false): string
{
    if (!array_key_exists($key, $payload)) {
        errorResponse(400, 'missing_parameter', 'Parameter ' . $key . ' fehlt.');
    }

    $value = is_string($payload[$key]) ? trim($payload[$key]) : (string)$payload[$key];
    if (!$allowEmpty && $value === '') {
        errorResponse(400, 'invalid_parameter', 'Parameter ' . $key . ' darf nicht leer sein.');
    }

    return $value;
}

function optionalArray(array $payload, string $key): array
{
    if (!array_key_exists($key, $payload)) {
        return [];
    }

    $value = $payload[$key];
    if (is_array($value)) {
        return $value;
    }

    return [];
}

function getHeader(string $name): ?string
{
    $normalized = 'HTTP_' . str_replace('-', '_', strtoupper($name));
    if (isset($_SERVER[$normalized])) {
        return trim((string)$_SERVER[$normalized]);
    }

    $alt = strtoupper($name);
    return $_SERVER[$alt] ?? null;
}
