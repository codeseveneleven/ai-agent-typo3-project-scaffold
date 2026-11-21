# Regeln für Claude in diesem Projekt

## Git
1. **Committe niemals selbstständig.** Commits, Pushes, Merges, Rebases und Tags nur auf ausdrückliche Anweisung.
2. Keine destruktiven Git-Befehle (`reset --hard`, `checkout -- .`, `clean -f`, `push --force`, Branch löschen) ohne Rückfrage.
3. Wenn ein Commit gewünscht ist: Format `[BUGFIX] …`, `[TASK] …`, `[FEATURE] …` (englisch, Imperativ); `[skip-ci]` nur auf Anweisung. Benutze das das offizielle TYPO3 Template wie es hier definiert ist: `https://docs.typo3.org/m/typo3/reference-coreapi/main/en-us/ApiOverview/VersionControl/Index.md`. Falls der PHPStorm MCP Server konfiguriert ist schau im Task Context nach der Ticket ID und verwende diese als Referenz.

## Arbeitsweise
4. Nur das ändern, worum gebeten wurde – kein ungefragtes Refactoring, keine Umformatierung fremden Codes.
5. Vor größeren oder mehrere Dateien betreffenden Änderungen kurz den Plan nennen.
6. Keine Dateien unter `vendor/`, `var/` oder generierte Dateien (z. B. kompilierte CSS) direkt bearbeiten – Änderungen gehören in `packages/*` bzw. die Sass-Quellen.
7. Kein `composer update` / `composer require` und keine neuen Abhängigkeiten ohne Rückfrage.

## Umgebung & Daten
8. Falls DDEV benutzt wird: Befehle (PHP, TYPO3-CLI, Composer, Tests) über DDEV ausführen (`ddev exec …`, `ddev typo3 …`, `ddev composer …`).
9. Falls es eine klassische composer basierte Umgebung ist: Befehle (PHP, TYPO3-CLI, Composer, Tests) über die jeweilige Kommandozeile ausführen.
10. Keine Datenbankänderungen (Migrationen, Löschungen, Imports) und keine Snapshots überschreiben ohne Rückfrage.
11. Keine Aktionen gegen externe Systeme (Sewobe, Mailversand, Zahlungsanbieter, Stage/Produktion, Deployer) ohne ausdrückliche Freigabe.
12. `.env`, `.env.local` und Zugangsdaten niemals ausgeben, committen oder an externe Dienste weitergeben.

## Qualität
13. Code für PHP 8.4 / TYPO3 schreiben, den bestehenden Stil der jeweiligen Extension übernehmen.
14. Nach Änderungen PHPStan und php-cs-fixer auf die geänderten Dateien laufen lassen und das Ergebnis ehrlich berichten (auch Fehler).
15. Bei Bugfixes nach Möglichkeit einen Test ergänzen oder beschreiben, wie der Fix verifiziert wurde.

## Kommunikation
16. Antworte in der Sprache, in welcher du angesprochen wurdest; Code, Kommentare und Commit-Messages *immer* auf Englisch.
17. Bei Unklarheiten nachfragen statt raten.
