<?php

declare(strict_types=1);

namespace Landrix\OAuth2\Support;

use RuntimeException;

/**
 * Persistiert Sitzungsdaten als JSON-Dateien außerhalb des Webroots.
 */
class SessionStore
{
    private string $directory;
    private int $defaultTtlSeconds;
    private int $cleanupAfterSeconds;

    public function __construct(string $directory, int $defaultTtlSeconds, int $cleanupAfterSeconds)
    {
        $this->directory = rtrim($directory, DIRECTORY_SEPARATOR);
        $this->defaultTtlSeconds = max(60, $defaultTtlSeconds);
        $this->cleanupAfterSeconds = max(300, $cleanupAfterSeconds);
        $this->ensureDirectory();
    }

    public function defaultTtlSeconds(): int
    {
        return $this->defaultTtlSeconds;
    }

    public function pathFor(string $sessionId): string
    {
        return $this->directory . DIRECTORY_SEPARATOR . $sessionId . '.json';
    }

    public function exists(string $sessionId): bool
    {
        return is_file($this->pathFor($sessionId));
    }

    public function read(string $sessionId): ?array
    {
        $path = $this->pathFor($sessionId);
        if (!is_file($path)) {
            return null;
        }

        $json = file_get_contents($path);
        if ($json === false) {
            throw new RuntimeException('Session-Datei konnte nicht gelesen werden.');
        }

        return json_decode($json, true, 512, JSON_THROW_ON_ERROR);
    }

    public function write(array $session): void
    {
        if (empty($session['sessionId'])) {
            throw new RuntimeException('SessionId fehlt.');
        }

        $payload = json_encode($session, JSON_PRETTY_PRINT | JSON_THROW_ON_ERROR);
        $result = file_put_contents($this->pathFor($session['sessionId']), $payload, LOCK_EX);
        if ($result === false) {
            throw new RuntimeException('Session-Datei konnte nicht geschrieben werden.');
        }
    }

    public function delete(string $sessionId): void
    {
        $path = $this->pathFor($sessionId);
        if (is_file($path)) {
            @unlink($path);
        }
    }

    /**
     * Beansprucht eine Session atomar und liefert ihren Inhalt genau einmal.
     * Der erste Aufrufer gewinnt das atomare rename(), alle weiteren erhalten null.
     * Schützt die einmalige Token-Auslieferung gegen parallele /poll-Requests.
     */
    public function claim(string $sessionId): ?array
    {
        $path = $this->pathFor($sessionId);
        $tmp = $path . '.claim-' . bin2hex(random_bytes(8));

        if (!@rename($path, $tmp)) {
            return null;
        }

        try {
            $json = file_get_contents($tmp);
            if ($json === false) {
                return null;
            }

            return json_decode($json, true, 512, JSON_THROW_ON_ERROR);
        } finally {
            @unlink($tmp);
        }
    }

    public function cleanup(): int
    {
        $removed = 0;
        $now = time();
        $globPattern = $this->directory . DIRECTORY_SEPARATOR . '*.json';
        foreach (glob($globPattern) as $file) {
            $content = file_get_contents($file);
            if ($content === false) {
                continue;
            }

            try {
                $data = json_decode($content, true, 512, JSON_THROW_ON_ERROR);
            } catch (\Throwable $e) {
                @unlink($file);
                $removed++;
                continue;
            }

            $expiresAt = isset($data['expiresAt']) ? strtotime((string)$data['expiresAt']) : null;
            $updatedAt = isset($data['updatedAt']) ? strtotime((string)$data['updatedAt']) : null;
            $isExpired = $expiresAt !== null && $expiresAt < $now;
            $tooOld = $updatedAt !== null && ($now - $updatedAt) > $this->cleanupAfterSeconds;

            if ($isExpired || $tooOld) {
                @unlink($file);
                $removed++;
            }
        }

        @touch($this->markerPath());
        return $removed;
    }

    public function cleanupIfDue(): void
    {
        $marker = $this->markerPath();
        // Drosselung ueber die mtime der Marker-Datei – wirkt requestuebergreifend,
        // da der Zustand im Dateisystem und nicht nur im Objekt liegt.
        if (is_file($marker) && (time() - (int)@filemtime($marker)) < $this->cleanupAfterSeconds) {
            return;
        }

        // Marker sofort setzen, damit parallele Requests nicht gleichzeitig scannen.
        @touch($marker);
        $this->cleanup();
    }

    private function markerPath(): string
    {
        return $this->directory . DIRECTORY_SEPARATOR . '.last-cleanup';
    }

    private function ensureDirectory(): void
    {
        if (!is_dir($this->directory) && !mkdir($this->directory, 0700, true) && !is_dir($this->directory)) {
            throw new RuntimeException('Session-Verzeichnis konnte nicht erstellt werden: ' . $this->directory);
        }
    }
}
