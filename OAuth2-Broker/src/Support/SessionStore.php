<?php

declare(strict_types=1);

namespace Landrix\OAuth2\Support;

use JsonException;
use RuntimeException;

/** Persistiert Sitzungsdaten als JSON-Dateien außerhalb des Webroots. */
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
        return $this->withLock(LOCK_SH, fn(): bool => is_file($this->pathFor($sessionId)));
    }

    public function read(string $sessionId): ?array
    {
        return $this->withLock(LOCK_SH, fn(): ?array => $this->readUnlocked($sessionId));
    }

    public function write(array $session): void
    {
        $this->withLock(LOCK_EX, function () use ($session): void {
            $this->writeUnlocked($session);
        });
    }

    /** Auch parallele /start-Aufrufe dürfen keine bestehende Session ersetzen. */
    public function create(array $session): bool
    {
        return $this->withLock(LOCK_EX, function () use ($session): bool {
            if (is_file($this->pathFor($session['sessionId']))) {
                return false;
            }
            $this->writeUnlocked($session);
            return true;
        });
    }

    /** Prüfen und Übernehmen sind atomar; der HTTP-Token-Tausch folgt ohne Sperre. */
    public function beginProcessing(string $sessionId, string $state): ?array
    {
        return $this->withLock(LOCK_EX, function () use ($sessionId, $state): ?array {
            $session = $this->readUnlocked($sessionId);
            if ($session === null || ($session['status'] ?? null) !== 'pending'
                || !is_string($session['state'] ?? null) || !hash_equals($session['state'], $state)) {
                return null;
            }
            $expiresAt = strtotime((string)($session['expiresAt'] ?? ''));
            if ($expiresAt === false || $expiresAt < time()) {
                $this->removeFile($this->pathFor($sessionId));
                return null;
            }

            $session['status'] = 'processing';
            $session['processingToken'] = bin2hex(random_bytes(32));
            $session['updatedAt'] = gmdate('c');
            $this->writeUnlocked($session);
            return $session;
        });
    }

    /** Nur der aktuelle Bearbeiter darf abschließen; niemals eine Datei neu anlegen. */
    public function completeProcessing(array $session): bool
    {
        return $this->withLock(LOCK_EX, function () use ($session): bool {
            $current = $this->readUnlocked($session['sessionId']);
            if ($current === null || ($current['status'] ?? null) !== 'processing'
                || !is_string($current['processingToken'] ?? null)
                || !is_string($session['processingToken'] ?? null)
                || !hash_equals($current['processingToken'], $session['processingToken'])
                || !in_array($session['status'] ?? null, ['success', 'error'], true)) {
                return false;
            }
            unset($session['processingToken']);
            $this->writeUnlocked($session);
            return true;
        });
    }

    /** Mit Vergleichswert keine inzwischen geänderte oder neu gestartete Session löschen. */
    public function delete(string $sessionId, ?array $expected = null): bool
    {
        return $this->withLock(LOCK_EX, function () use ($sessionId, $expected): bool {
            if ($expected !== null && $this->readUnlocked($sessionId) !== $expected) {
                return false;
            }
            return $this->removeFile($this->pathFor($sessionId));
        });
    }

    /** Terminale Sessions genau einmal abholen; pending/processing bleiben bestehen. */
    public function claim(string $sessionId, ?array $expected = null): ?array
    {
        return $this->withLock(LOCK_EX, function () use ($sessionId, $expected): ?array {
            $session = $this->readUnlocked($sessionId);
            if ($session === null || ($expected !== null && $session !== $expected)
                || !in_array($session['status'] ?? null, ['success', 'error'], true)) {
                return null;
            }
            $expiresAt = strtotime((string)($session['expiresAt'] ?? ''));
            if ($expiresAt === false || $expiresAt < time()) {
                return null;
            }

            $path = $this->pathFor($sessionId);
            $claimedPath = $path . '.claim-' . bin2hex(random_bytes(8));
            if (!rename($path, $claimedPath)) {
                throw new RuntimeException('Session konnte nicht abgeholt werden.');
            }
            // Bei einem Prozessabbruch entfernt cleanup() die verwaiste Claim-Datei.
            @unlink($claimedPath);
            return $session;
        });
    }

    public function cleanup(): int
    {
        return $this->withLock(LOCK_EX, fn(): int => $this->cleanupUnlocked());
    }

    public function cleanupIfDue(): void
    {
        $this->withLock(LOCK_EX, function (): void {
            $marker = $this->markerPath();
            // Prüfung und Marker-Update unter derselben Sperre: nur ein Scanner.
            if (is_file($marker) && (time() - (int)filemtime($marker)) < $this->cleanupAfterSeconds) {
                return;
            }
            $this->cleanupUnlocked();
        });
    }

    /** Alle *Unlocked-Helfer ausschließlich innerhalb von withLock() aufrufen. */
    private function readUnlocked(string $sessionId): ?array
    {
        $path = $this->pathFor($sessionId);
        if (!is_file($path)) {
            return null;
        }
        $json = file_get_contents($path);
        if ($json === false) {
            throw new RuntimeException('Session-Datei konnte nicht gelesen werden.');
        }
        $session = json_decode($json, true, 512, JSON_THROW_ON_ERROR);
        if (!is_array($session)) {
            throw new JsonException('Session-Datei enthält kein Objekt.');
        }
        return $session;
    }

    private function writeUnlocked(array $session): void
    {
        if (empty($session['sessionId'])) {
            throw new RuntimeException('SessionId fehlt.');
        }
        $payload = json_encode($session, JSON_PRETTY_PRINT | JSON_THROW_ON_ERROR);
        $path = $this->pathFor($session['sessionId']);
        $temporaryPath = $path . '.tmp-' . bin2hex(random_bytes(8));
        $file = $this->openPrivateFile($temporaryPath, 'x+b');
        try {
            if (fwrite($file, $payload) !== strlen($payload) || !fflush($file)) {
                throw new RuntimeException('Session-Datei konnte nicht geschrieben werden.');
            }
            // Vor rename schließen, insbesondere für Windows. Niemals vorher unlink:
            // Schlägt der Austausch fehl, bleibt die bisherige Session erhalten.
            fclose($file);
            $file = null;
            if (!rename($temporaryPath, $path)) {
                throw new RuntimeException('Session-Datei konnte nicht ersetzt werden.');
            }
        } finally {
            if (is_resource($file)) {
                fclose($file);
            }
            if (is_file($temporaryPath)) {
                @unlink($temporaryPath);
            }
        }
    }

    private function cleanupUnlocked(): int
    {
        $removed = 0;
        $now = time();
        foreach (glob($this->directory . DIRECTORY_SEPARATOR . '*.json') ?: [] as $file) {
            try {
                $data = $this->readUnlocked(basename($file, '.json'));
            } catch (JsonException $e) {
                // Unter exklusiver Sperre gelesen: kein halbfertiger Schreiber.
                $removed += (int)$this->removeFile($file);
                continue;
            }
            $expiresAt = strtotime((string)($data['expiresAt'] ?? ''));
            $updatedAt = strtotime((string)($data['updatedAt'] ?? ''));
            if (($expiresAt !== false && $expiresAt < $now)
                || ($updatedAt !== false && ($now - $updatedAt) > $this->cleanupAfterSeconds)) {
                $removed += (int)$this->removeFile($file);
            }
        }

        // Keine aktiven Dateioperationen unter LOCK_EX. Junge Überreste trotzdem
        // schonen; alte Temp-/Claim-Dateien enthalten möglicherweise Tokens.
        foreach (['*.json.tmp-*', '*.json.claim-*'] as $pattern) {
            foreach (glob($this->directory . DIRECTORY_SEPARATOR . $pattern) ?: [] as $file) {
                $modifiedAt = filemtime($file);
                if ($modifiedAt !== false && ($now - $modifiedAt) > $this->cleanupAfterSeconds) {
                    $removed += (int)$this->removeFile($file);
                }
            }
        }
        $marker = $this->openPrivateFile($this->markerPath(), 'c+b');
        fclose($marker);
        touch($this->markerPath());
        return $removed;
    }

    private function removeFile(string $path): bool
    {
        if (!is_file($path)) {
            return false;
        }
        if (!unlink($path)) {
            throw new RuntimeException('Session-Datei konnte nicht gelöscht werden.');
        }
        return true;
    }

    /**
     * Stabile Store-Sperre für alle Dateioperationen, keine Netzaufrufe darunter.
     * Die Lock-Datei nie löschen/ersetzen: Wartende könnten sonst verschiedene
     * Inodes sperren. Es entstehen keine verwaisten Locks pro Session.
     */
    private function withLock(int $mode, callable $operation): mixed
    {
        $lock = $this->openPrivateFile($this->directory . DIRECTORY_SEPARATOR . '.store.lock', 'c+b');
        try {
            if (!flock($lock, $mode)) {
                throw new RuntimeException('Session-Store konnte nicht gesperrt werden.');
            }
            // PHPs Stat-Cache darf nach dem Warten keine alten Dateidaten liefern.
            clearstatcache();
            return $operation();
        } finally {
            flock($lock, LOCK_UN);
            fclose($lock);
        }
    }

    /** Restriktive Rechte schon bei der Anlage, auch für Lock-/Temp-/Marker-Dateien. */
    private function openPrivateFile(string $path, string $mode)
    {
        $previousMask = umask(0077);
        try {
            $file = fopen($path, $mode);
        } finally {
            umask($previousMask);
        }
        if ($file === false) {
            throw new RuntimeException('Session-Store-Datei konnte nicht geöffnet werden.');
        }
        if (!chmod($path, 0600)) {
            fclose($file);
            throw new RuntimeException('Session-Dateirechte konnten nicht gesetzt werden.');
        }
        return $file;
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
        if (!chmod($this->directory, 0700)) {
            throw new RuntimeException('Session-Verzeichnisrechte konnten nicht gesetzt werden.');
        }
    }
}
