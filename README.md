# Claude Code ↔ Local Model Handoff System

Seamless continuity between Claude Code (API) and a local model so you never lose momentum when you hit your token limit.

```
Claude (API)  ──updates HANDOFF.md──▶  Local model picks it up
Local model   ──updates HANDOFF.md──▶  Claude picks it up when limits refresh
Local model   ──updates HANDOFF.md──▶  Itself (fresh session when context fills)
```

## How It Works

Three files make this work:

| File | Purpose |
|---|---|
| `CLAUDE.md` | Instructs Claude Code to maintain `HANDOFF.md` during every session |
| `HANDOFF.md` | Running snapshot of current task, progress, decisions, and next steps |
| `claude-local.sh` | Launches Claude Code pointed at your local model, feeding it the handoff context |

## Prerequisites

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed
- A local model server running one of:
  - [Ollama](https://ollama.ai) (default, easiest)
  - [LM Studio](https://lmstudio.ai)
  - [llama.cpp server](https://github.com/ggerganov/llama.cpp)
  - Any OpenAI-compatible API endpoint

## Quick Start (Single Project)

1. Copy the three files into your project root:

```bash
cp CLAUDE.md HANDOFF.md claude-local.sh /path/to/your/project/
```

2. Edit `claude-local.sh` to match your local setup (model name, port, etc.):

```bash
LOCAL_BASE_URL="${LOCAL_BASE_URL:-http://localhost:11434/v1}"
LOCAL_API_KEY="${LOCAL_API_KEY:-ollama}"
LOCAL_MODEL="${LOCAL_MODEL:-gemma3}"
```

3. Work normally with `claude`. When you hit your limit, switch:

```bash
./claude-local.sh
```

4. When your API limits refresh, just run `claude` again — it reads the `HANDOFF.md` the local model left behind.

## Setup for All Projects (No Copying Files)

### Option A: Global CLAUDE.md + shell alias (recommended)

Claude Code supports a global `CLAUDE.md` that applies to every project:

```bash
# Add the handoff instructions to your global CLAUDE.md
cat >> ~/.claude/CLAUDE.md << 'EOF'

# Session Handoff

At the start of every session and after completing any significant step (implementing a feature, fixing a bug, making an architectural decision, etc.), update `HANDOFF.md` in the project root.

The handoff file should always reflect the **current state** of work so that a different model can pick up where you left off. Include:

- **Task**: What is being worked on and why
- **Approach**: The strategy/plan being followed
- **Progress**: What's been done so far (files changed, key decisions made)
- **Current State**: Where things stand right now — what's working, what's broken
- **Next Steps**: What remains to be done, in priority order
- **Key Context**: Any non-obvious decisions, gotchas, constraints, or domain knowledge needed to continue

Keep it concise but complete enough that someone with no prior context could continue the work. Overwrite the file each update — it's a snapshot, not a log.
EOF
```

Then put `claude-local.sh` somewhere on your PATH:

```bash
# Install the script globally
cp claude-local.sh ~/.local/bin/claude-local
chmod +x ~/.local/bin/claude-local
```

Now from any project directory:

```bash
claude           # normal session — auto-maintains HANDOFF.md
claude-local     # switch to local model — reads and maintains HANDOFF.md
```

### Option B: Git init template (auto-include in new repos)

Set up a [git template directory](https://git-scm.com/docs/git-init#_template_directory) so every new repo gets the files automatically:

```bash
# Create the template
mkdir -p ~/.git-templates/template
cp CLAUDE.md HANDOFF.md ~/.git-templates/template/

# Tell git to use it
git config --global init.templateDir ~/.git-templates/template
```

Now every `git init` or `git clone` drops `CLAUDE.md` and `HANDOFF.md` into the repo. Combine with the global `claude-local` script from Option A.

### Option C: Dotfiles / chezmoi

If you manage dotfiles with chezmoi, stow, or a bare git repo, add these to your dotfile manager:

```bash
# Example with chezmoi
chezmoi add ~/.local/bin/claude-local
chezmoi add ~/.claude/CLAUDE.md
```

This keeps your setup portable across machines.

## Configuration

### Environment variables

Override defaults without editing the script:

```bash
# In your .bashrc / .zshrc
export LOCAL_BASE_URL="http://localhost:1234/v1"   # LM Studio default port
export LOCAL_MODEL="deepseek-coder-v2:16b"
export LOCAL_API_KEY="lm-studio"
```

### Per-project model overrides

Some projects benefit from specific models. Override per-invocation:

```bash
LOCAL_MODEL="codellama:34b" claude-local
```

Or add a `.env` at the project root and source it in the script.

### Useful shell aliases

```bash
# Add to .bashrc / .zshrc
alias cl='claude-local'
alias cl-resume='claude-local "Review HANDOFF.md and continue where you left off."'
alias cl-status='cat HANDOFF.md'
```

## The Workflow

### Normal day

```
1. Start working:              claude
2. Claude maintains:           HANDOFF.md (automatic, per CLAUDE.md instructions)
3. Hit token limit:            ./claude-local.sh
4. Local model reads:          HANDOFF.md, picks up where Claude left off
5. Local model maintains:      HANDOFF.md (per injected system instructions)
6. Context window fills up:    exit, run ./claude-local.sh again
7. New local session reads:    HANDOFF.md, continues seamlessly
8. Next day, limits refresh:   claude
9. Claude reads:               HANDOFF.md left by local model, keeps going
```

### Tips

- **Don't `.gitignore` HANDOFF.md** if you want handoff context to survive branch switches. Do `.gitignore` it if you don't want work-in-progress context in your commits.
- **Check the handoff before switching** — run `cat HANDOFF.md` to verify it has useful context before starting a local session.
- **Pass extra instructions** when switching: `./claude-local.sh "Focus on the test failures first"`
- **Model quality matters** — the local model needs to be capable enough to follow the handoff protocol. 14B+ parameter models work best. Smaller models may ignore the instructions to update HANDOFF.md.

## File Reference

### CLAUDE.md

Instructs Claude Code (API) to maintain `HANDOFF.md`. Placed in project root or `~/.claude/CLAUDE.md` for global effect.

### HANDOFF.md

The running context snapshot. Structure:

```markdown
# Session Handoff

## Task
## Approach
## Progress
## Current State
## Next Steps
## Key Context
```

### claude-local.sh

Launcher script. Reads `HANDOFF.md`, injects system instructions telling the local model to maintain it, and starts Claude Code against your local model server.
