# Globale Claude Code Anweisungen

## Dotclaude-Repo (Selbstpflege)
`~/.claude/` wird über das dotclaude-Repo gepflegt. Lokaler Checkout: `$DOTCLAUDE_REPO` falls gesetzt, sonst `~/dotclaude` oder `~/claude-dotfiles`. Mapping inline-getrackter Dateien: `<repo>/home/<x>` ⇄ `~/.claude/<x>`.

**Inline getrackt** (kommen via `git pull` + `./install.sh`): `CLAUDE.md`, `settings.json`, `.omc-config.json`, `commands/`, `skills/dotclaude-lab/`, `hud/`.

**Per Registry referenziert** (kommen via `claude plugin install` / `git clone` / `npm i -g`): alle Skills, Plugins, Repos und npm-Globals in `<repo>/registry.json`. Updates dieser Sachen laufen über `/dotclaude-lab update`.

**Regel:** Wird lokal eine inline-getrackte Datei in `~/.claude/` geändert, **muss** die Änderung in den Repo-Checkout kopiert, committet und gepusht werden — sonst veraltet das Repo. Vor dem Committen: `cd <repo> && git status`. Pushen nur nach expliziter User-Bestätigung.

**Skills/Plugins/Repos hinzufügen oder kuratieren:** über den `dotclaude-lab` Skill — `/dotclaude-lab list|try|add|recommend|promote|demote|remove|update`. Drei Stati: `required` (überall auto-installiert), `recommended` (per `--with-recommended` opt-in), `optional` (nur lab/`try`). Mutationen werden committet und (sofern `settings.autoPush` in `registry.json` nicht abgeschaltet ist) auch gepusht. Niemals von Hand in `~/.claude/skills/` rumeditieren wenn das Ziel ein registrierter Upstream-Skill ist; stattdessen `registry.json` ändern und `update` laufen lassen.

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

Bei passenden Aufgaben an die globalen Skills denken (welche tatsächlich da sind, hängt von `registry.json` ab — `/dotclaude-lab list` zeigt den aktuellen Stand):

- **Webseite anschauen, testen, Screenshot, Formular ausfüllen, Seite prüfen** → `browser-use` (required)
- **UI bauen, Webseite gestalten, Frontend, Komponente, Landing Page** → `frontend-design` (required, plugin)
- **Diagramme, Architektur-Übersichten, Diff-Reviews, Tabellen, visuelle Erklärungen** → `visual-explainer` (optional — `/dotclaude-lab try visual-explainer`)
- **Video, Animation, Demo, Screencast** → `remotion-best-practices` (optional)
- **dotclaude-Registry verwalten** (Skills/Plugins/Repos installieren, promoten, updaten) → `dotclaude-lab`
- **MCP-Token sparen bei vielen Tools (80+)** → mcp2cli für on-demand Tool-Discovery
- **Context-Window schonen** → Context Mode (MCP-Server, läuft automatisch) routet große Tool-Outputs durch Subprozesse
