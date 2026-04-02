#!/bin/bash
# Launch Claude Code with a local model, pre-loaded with handoff context.
# The local model maintains HANDOFF.md just like Claude does, so context
# survives across sessions in both directions:
#
#   Claude (API) ──writes HANDOFF.md──▶ Local model
#   Local model  ──writes HANDOFF.md──▶ Claude (API) / itself (new session)
#
# Usage: ./claude-local.sh [optional prompt]
#
# Prerequisites:
#   - A local model server running (Ollama, LM Studio, etc.)
#   - Configure the variables below to match your setup

# ── Configure these for your local model ──────────────────────────
LOCAL_BASE_URL="${LOCAL_BASE_URL:-http://localhost:11434}"
LOCAL_API_KEY="${LOCAL_API_KEY:-ollama}"
LOCAL_MODEL="${LOCAL_MODEL:-gpt-oss:20b}"
MODEL_FILE="local_ollama_model"
# ──────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HANDOFF="$SCRIPT_DIR/HANDOFF.md"

# ── System instructions injected into every local model session ───
SYSTEM_INSTRUCTIONS="## CRITICAL: Session Handoff Protocol

You are continuing work from a previous session (either Claude API or a prior local session). You MUST follow these rules:

### Maintaining HANDOFF.md
You MUST keep HANDOFF.md in the project root updated throughout your session. This file is your lifeline — it's how context survives between sessions, whether handing back to Claude when API limits refresh, handing off to a fresh instance of yourself when your context window fills up, or resuming after a restart.

Update HANDOFF.md after every significant step: implementing a feature, fixing a bug, making a decision, or changing approach. Overwrite the entire file each time — it's a snapshot, not a log.

Use this structure:

\`\`\`markdown
# Session Handoff

## Task
What is being worked on and why.

## Approach
The strategy/plan being followed.

## Progress
What's been done so far — files changed, key decisions, what worked/didn't.

## Current State
Where things stand RIGHT NOW — what's working, what's broken, what's in-progress.

## Next Steps
What remains to be done, in priority order.

## Key Context
Non-obvious decisions, gotchas, constraints, or domain knowledge needed to continue.
Any warnings about tricky areas or failed approaches that shouldn't be retried.
\`\`\`

### When to update
- Immediately after reviewing the handoff context at session start (confirm you understand)
- After completing each significant unit of work
- Before any operation that might be your last (if context is getting large, update HANDOFF.md preemptively)
- When changing approach or making a non-obvious decision

### Quality bar
Write HANDOFF.md as if the next reader has ZERO context about this conversation. They only have the code and this file. Be specific: name files, functions, line numbers. Don't say \"the bug\" — say \"the off-by-one error in parse_header() at src/parser.py:142\"."

# ── Build the prompt ──────────────────────────────────────────────
if [ ! -f "$HANDOFF" ]; then
    echo "No HANDOFF.md found — starting fresh session."
    PROMPT="$SYSTEM_INSTRUCTIONS

---

No prior handoff context found. ${1:-What would you like to work on?}"
else
    echo "Loading handoff context from HANDOFF.md..."
    HANDOFF_CONTENT=$(cat "$HANDOFF")
    if [ -n "$1" ]; then
        PROMPT="$SYSTEM_INSTRUCTIONS

---

Here is the handoff context from the previous session:

$HANDOFF_CONTENT

---

Additional instruction: $1"
    else
        PROMPT="$SYSTEM_INSTRUCTIONS

---

Here is the handoff context from the previous session:

$HANDOFF_CONTENT

---

Please review the handoff, confirm your understanding of where things stand, update HANDOFF.md to reflect that you've taken over, and continue with the next steps."
    fi
fi

# ── Launch ────────────────────────────────────────────────────────
ANTHROPIC_BASE_URL="$LOCAL_BASE_URL" \
ANTHROPIC_API_KEY="$LOCAL_API_KEY" \
ANTHROPIC_MODEL="$LOCAL_MODEL" \

echo "FROM $LOCAL_MODEL" > $MODEL_FILE
echo "SYSTEM \"$PROMPT\"" >>  $MODEL_FILE

ollama create custom-claude -f $MODEL_FILE

ollama launch claude --model custom-claude
