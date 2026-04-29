Du bist der Claude Time Tracker. Verarbeite diesen Befehl: `$ARGUMENTS`

Bestimme anhand des Arguments welche Aktion ausgeführt werden soll:

## Aktionen

### Zeitangabe (z.B. `5m`, `10m`, `30m`, `1h`) oder leer
Wenn das Argument eine Zeitangabe ist ODER leer ist (Standard: `10m`):

1. **Sofort** einen Status-Check durchführen: Führe `bash ~/.claude-time-tracker/loop-prompt.sh` aus, um den Prompt zu erhalten, und führe dann die darin beschriebenen Prüfungen aus (git log, session log, etc.). Gib den Report kompakt aus (wie bei `status`).
2. **Danach** den Loop starten: Nutze den `/loop` Skill mit dem Intervall und dem Prompt aus `~/.claude-time-tracker/loop-prompt.sh`. Sage dem Nutzer kurz: `Loop gestartet -- naechster Check in ZEIT.`

### `status`
Führe einen einmaligen Status-Check durch. Nutze `~/.claude-time-tracker/loop-prompt.sh` um den Prompt zu generieren und führe die darin beschriebenen Prüfungen aus (git log, session log, etc.). Gib den Report kompakt aus.

### `today`
Führe dieses Skript aus und formatiere die Ausgabe als Balkendiagramm:
```bash
bash ~/.claude-time-tracker/track-today.sh
```
Formatiere die Ausgabe so:
```
[Zeit] Uebersicht — DD.MM.YYYY

  PROJEKTNAME        ====================  XXm  (N Sessions)
  ...

  Gesamt: XXm (N Sessions)
```
Die Balken sollen proportional zur laengsten Zeit sein (max 20 Zeichen). Nutze `=` fuer gefuellt und `-` fuer leer.

### `week`
Führe dieses Skript aus und formatiere als Wochentabelle:
```bash
bash ~/.claude-time-tracker/track-week.sh
```
Formatiere die Ausgabe so:
```
[Woche] DD.MM. -- DD.MM.YYYY

  Projekt             Mo   Di   Mi   Do   Fr   Sa   So   Summe
  ---------------------------------------------------------------
  PROJEKTNAME         XXm  XXm  --   XXm  --   --   --   XXXm
  ...
  ---------------------------------------------------------------
  Gesamt              XXm  XXm  XXm  XXm  XXm  XXm  XXm  XXXm
```

### `projects`
Lese `~/.claude-projects` und zeige die Projektliste. Pruefe fuer jeden Pfad ob er existiert (OK oder FEHLT).
```
[Projekte] Registrierte Projekte:

  1. NAME              PFAD                   OK/FEHLT

  Bearbeite ~/.claude-projects um Projekte hinzuzufuegen/zu entfernen.
```

### `log`
Führe aus:
```bash
bash ~/.claude-time-tracker/track-log.sh
```
Formatiere als:
```
[Log] Letzte 10 Sessions:

  HH:MM  PROJEKT        START/END  [Dauer]
  ...
```

### `help`
Zeige diese Hilfe:
```
Claude Time Tracker -- Befehle

  /track           Loop starten (Standard: 10m)
  /track 5m        Loop mit 5-Minuten-Intervall
  /track status    Einmal-Report aller Projekte
  /track today     Tagesuebersicht mit Zeitbalken
  /track week      Wochenuebersicht als Tabelle
  /track projects  Registrierte Projekte anzeigen
  /track log       Letzte 10 Sessions anzeigen
  /track help      Diese Hilfe
```

### Unbekannter Befehl
Zeige die Hilfe (wie bei `help`).
