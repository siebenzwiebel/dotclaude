# Globale Claude Code Anweisungen

## Dotclaude-Repo (Selbstpflege)
Diese Datei und der gesamte Inhalt von `~/.claude/` werden im Git-Repo `http://git.drewers.dev/Steven/dotclaude` gepflegt. Lokaler Checkout: `~/claude-dotfiles/`. Das Mapping ist: `~/claude-dotfiles/home/<x>` ⇄ `~/.claude/<x>` (siehe `install.sh`).

**Regel:** Sobald lokal an einer Datei unter `~/.claude/` etwas geändert wird, die im Repo (`~/claude-dotfiles/home/`) getrackt ist, **muss** die Änderung dorthin kopiert, committet und gepusht werden — sonst veraltet das Repo. Vor dem Committen: `cd ~/claude-dotfiles && git status` prüfen, dann gezielt die geänderten Pfade stagen. Pushen nur nach expliziter User-Bestätigung (Standardregel), außer der User hat das Syncen explizit mitbeauftragt.

Getrackte Beispiele: `CLAUDE.md`, `settings.json`, `commands/`, `hooks/`, `skills/`, `hud/`, `.omc-config.json`.
Nicht getrackt: Dateien außerhalb von `~/.claude/` (z. B. `~/.bashrc`) — dafür ist separat ein Ziel zu klären, falls sie versioniert werden sollen.

## Read-before-Edit (Token-Sparregel)
Vor jedem `Edit` oder `Write` auf eine bestehende Datei muss diese zuerst mit `Read` gelesen werden. Vor Änderungen an einer Funktion/Methode/Export: mit `Grep` alle Aufrufer suchen. Research vor Edit — blindes Editieren führt zu Retries und verbrannten Tokens. Angestrebtes Verhältnis: mindestens 4 Reads pro Edit.

## Nach Feature-Abschluss
Nach Abschluss eines Features oder einer größeren Aufgabe proaktiv darauf hinweisen, dass `/compact` ausgeführt werden sollte, bevor die nächste Aufgabe beginnt. Formulierung: „Feature abgeschlossen — empfehle `/compact` um den Kontext zu bereinigen bevor wir weitermachen."

## Gemini-Delegation (Token-Sparregel)

Nutze `/oh-my-claudecode:ask gemini "..."` für die folgenden Aufgabentypen, um Claude-Tokens zu sparen. Die Regel gilt nur wenn die Gemini CLI installiert ist.

### MUSS an Gemini delegiert werden
Diese Aufgaben rechtfertigen den Orchestrierungs-Overhead, weil der generierte Output lang ist:
- **Dokumentation schreiben** — README, AGENTS.md, JSDoc-Blöcke, Inline-Kommentare für ganze Dateien
- **Code-Review** — Review eines Diffs oder einer Datei (Ergebnis als Text, keine Tool-Aufrufe nötig)
- **Zusammenfassungen** — Dateiinhalte, PR-Diffs, Git-Logs zusammenfassen
- **Boilerplate generieren** — HTML-Templates, Config-Strukturen, Testgerüste die danach nur eingefügt werden

### KANN an Gemini delegiert werden (Ermessensentscheidung)
Nur delegieren wenn der erwartete Output >20 Zeilen ist, sonst selbst machen:
- Fehlermeldungen erklären / recherchieren
- Commit-Messages für große Changesets formulieren
- Regex, SQL, Shell-Kommandos generieren

### NICHT an Gemini delegieren
- Alles was Tool-Zugriff braucht (Dateien lesen/editieren, Tests laufen lassen)
- Planung & Architektur (Claude ist hier besser)
- Debugging mit Codebase-Kontext
- Kurze Antworten (<20 Zeilen) — Overhead lohnt sich nicht

### Ablauf bei Delegation
1. `/oh-my-claudecode:ask gemini "<präziser Prompt mit allem nötigen Kontext>"` aufrufen
2. Ergebnis lesen und in die Zieldatei schreiben oder dem User zeigen
3. Nicht nachbearbeiten außer bei offensichtlichen Fehlern

## Skill-Hints

Folgende globale Skills sind installiert. Bei passenden Aufgaben an sie denken:

- **Video, Animation, Demo, Screencast** → Remotion-Skill nutzen (`remotion-best-practices`)
- **Webseite anschauen, testen, Screenshot, Formular ausfüllen, Seite prüfen** → Browser-Skill nutzen (`browser-use`)
- **UI bauen, Webseite gestalten, Frontend, Komponente, Landing Page** → Frontend-Design-Skill nutzen (`frontend-design`)
- **Diagramme, Architektur-Übersichten, Diff-Reviews, Tabellen, visuelle Erklärungen** → Visual-Explainer nutzen (`visual-explainer`) — HTML statt ASCII bei 4+ Zeilen / 3+ Spalten
- **Sessions als HTML-Replay teilen/dokumentieren** → claude-replay nutzen (`claude-replay`)
- **MCP-Token sparen bei vielen Tools (80+)** → mcp2cli für on-demand Tool-Discovery statt nativer MCP-Schema-Injection
- **Context-Window schonen** → Context Mode (MCP-Server, läuft automatisch) routet große Tool-Outputs durch Subprozesse
