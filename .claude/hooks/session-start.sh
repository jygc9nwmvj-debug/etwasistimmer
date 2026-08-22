#!/bin/bash
# Repariert eine wiederholt beobachtete Umgebungs-Eigenart dieses Projekts:
# die Arbeitskopie fiel mehrfach zwischen Konversations-Turns auf einen
# alten, laengst ueberholten Commit zurueck (vermutlich haengt das mit
# Container-Neustarts/-Snapshots dieser Remote-Session zusammen, nicht mit
# einem Git-Fehler) -- sichtbar u.a. daran, dass style.css?v=-Cache-Buster,
# Dateien wie datenschutz.html/impressum.html oder ganze Commits ploetzlich
# wieder fehlten, obwohl sie laengst gepusht waren.
#
# Laeuft bei jedem Session-Start/-Resume und gleicht HEAD hart gegen den
# tatsaechlichen Stand von origin/<branch> ab -- nur wenn KEINE
# uncommitteten Aenderungen vorliegen (Sicherheitsnetz: nie echte, noch
# ungesicherte Arbeit ueberschreiben). Nicht destruktiv gegenueber origin
# selbst, nur gegenueber dem lokalen, ggf. veralteten Snapshot.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

REPO_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$REPO_DIR" 2>/dev/null || exit 0

if [ ! -d .git ]; then
  exit 0
fi

BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
if [ -z "$BRANCH" ] || [ "$BRANCH" = "HEAD" ]; then
  exit 0
fi

# FETCH_HEAD statt origin/$BRANCH: ein gezielter "git fetch origin <branch>"
# aktualisiert nicht zuverlaessig den lokalen Remote-Tracking-Branch
# origin/<branch> (der existiert ggf. noch gar nicht), sondern nur
# FETCH_HEAD -- derselbe Kniff, der sich in diesem Projekt schon fuer die
# manuelle Wiederherstellung bewaehrt hat.
git fetch origin "$BRANCH" --quiet 2>/dev/null || exit 0

REMOTE_SHA="$(git rev-parse FETCH_HEAD 2>/dev/null || true)"
LOCAL_SHA="$(git rev-parse HEAD 2>/dev/null || true)"

if [ -n "$REMOTE_SHA" ] && [ "$LOCAL_SHA" != "$REMOTE_SHA" ]; then
  if [ -z "$(git status --porcelain)" ]; then
    git checkout -B "$BRANCH" FETCH_HEAD --quiet
    echo "Arbeitskopie war veraltet (lokal $LOCAL_SHA) -- auf origin/$BRANCH ($REMOTE_SHA) zurueckgesetzt." >&2
  else
    echo "WARNUNG: Arbeitskopie weicht von origin/$BRANCH ab (lokal $LOCAL_SHA, remote $REMOTE_SHA), aber es liegen uncommittete Aenderungen vor -- kein automatischer Reset, bitte manuell pruefen." >&2
  fi
fi
