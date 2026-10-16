# CLAUDE.md — SoundPilot

The project context (§1–§8: overview, accessibility requirements, commands,
data model, Cloud Functions, security rules, open points, team conventions)
lives in `docs/PROJECT_CONTEXT.md` and is imported here:

@docs/PROJECT_CONTEXT.md

## 9. Claude Code

Only in `CLAUDE.md`; this is everything that is specific to Claude.

### Where project knowledge goes

- `docs/PROJECT_CONTEXT.md` is the single source for §1–§8. Edit it there;
  it is imported above, so there is nothing to copy. It must not mention
  Claude, so it stays readable on its own for the team.
- Claude-specific content (hooks, session start, workflows below) goes into
  this §9 only.
- Code comments and other docs refer to `docs/PROJECT_CONTEXT.md`, not to
  `CLAUDE.md`. Keep its section numbers stable; code refers to them.
- Describe the current state, not its history (that is in git and the PRs).
  Keep a lesson only as a rule ("do not cap the text scale").

### Hooks (`.claude/settings.json`)

Shared hooks enforce the rules of §8 for everyone who uses Claude Code in this
repo. They are Node scripts in `.claude/hooks/` (Node is already required for
the Cloud Functions), so they work the same on Windows, macOS and Linux.

| Hook | Script | What it does |
|---|---|---|
| `SessionStart` (startup) | `session-start.mjs` | `git fetch --prune`; on a clean `main` that is behind, `git pull --ff-only`; on any other branch, fast-forwards the local `main` without switching (`git fetch origin main:main`, never touches the current branch); reports uncommitted changes, stale/merged local branches and open PRs |
| `PreToolUse` (shell, file edits) | `pre-tool-guard.mjs` | **blocks** `--no-verify`, deleting `main` on GitHub, and edits to credentials (`google-services.json`, `GoogleService-Info.plist`, `.env*`, service-account JSON, keystores) and the generated `firebase_options.dart`; **asks first** for commits/pushes to `main`, force pushes, `firebase deploy`, and commands that throw away work (`reset --hard`, `clean -f`, `checkout -- .`, `restore .`, `branch -D`, `stash drop/clear`, `rm -rf`) |
| `PostToolUse` (file edits) | `post-edit-reminders.mjs` | reminds to keep Claude out of `docs/PROJECT_CONTEXT.md`, and to update all three schema places when `firestore.rules`, `index.ts` or `user_model.dart` change |

- The guards check the command text; they are a safety net against mistakes,
  not a security boundary.
- An "ask" action that is really intended (e.g. a force push to your own
  branch) is confirmed in the permission prompt. To change a rule, edit the
  script through a PR like any other code.
- Review or temporarily disable hooks with `/hooks` in Claude Code.
- **When a hook blocks or questions a command, never work around it** (other
  wording, a script, another tool). Tell the user what was blocked and why. If
  it is a false positive (e.g. a trigger word inside a commit message or
  heredoc), say so and suggest fixing the rule in the script.

### Run logs

When the user reports an error from running the app, read the newest file in
`frontend/soundpilot_application/logs/` (see §3) before asking them to paste
output. Check its header: the branch and commit it was run from may not be
the current ones.

### Session start

The `SessionStart` hook (see Hooks above) already runs the fetch/pull and
collects the state below; its report is in the context at the start of a
session. Report it to the user, and still check the points it does not cover
(leftover remote branches of merged PRs).

Before starting any task, check the state of the repo and report it:

- **Pull:** `git fetch --prune`, then check whether `main` (or the current
  branch) is behind `origin`; if so, pull before working.
- **Clean up:**
  - uncommitted changes (`git status`)
  - local branches that are merged or whose remote branch is gone
  - leftover remote branches of merged PRs
  - open PRs that still wait for a merge
- **Plans:** if there are "Plan:" sections at the end of this file, report
  where the user's own plans stand and which step comes next; only list
  the titles and owners of the other plans.

Ask before deleting anything or discarding changes.

### Plans that span several branches

Claude has no memory between sessions or devices, so a plan that needs more
than one branch/PR is written down here until it is done:

- Before the first branch, add a section `### Plan: <title> (@<owner>)` at
  the end of this file: the goal, the steps (one per branch, with the branch
  name), and decisions made with the user. `<owner>` is the GitHub login of
  the user (`gh api user --jq .login`).
- Several people can have plans at the same time, one section each. Work
  only on your user's own plans; change someone else's plan only if your user
  asks for it, and say whose it is.
- Commit it with the first branch. Each later branch marks its step done
  (with the PR number) and adjusts the remaining steps if the plan changed.
- Keep the status per step on its own line, so parallel branches do not
  conflict in the same line.
- The last branch of the plan removes the section.

### Before pushing / opening a PR

- Run the checks CI runs, for the parts you changed (see §3):
  `flutter analyze --no-fatal-infos` and `flutter test` in
  `frontend/soundpilot_application/`; `npm run lint` and `npm run build` in
  `firebase/functions/`; `npm test` in `firebase/rules-tests/` when
  `firestore.rules` changed. Report failures with their output; do not push
  known-red code.
- Leave unrelated local changes out of the commit, e.g. a `pubspec.lock` that
  only a local `flutter pub get` changed (see §3), or the generated plugin
  registrants under `linux/`, `macos/` and `windows/` that it rewrites with
  other line endings. Stage files by name, not with `git add -A`.
- PR description: what changed and why, how it was tested (commands and
  results), and anything the reviewer has to decide. Do not merge the PR
  yourself; the user merges (admins via the ruleset bypass, see §8).

### Merge conflicts in a PR

- Merge `main` into the PR branch (`git merge main`); do not rebase, because
  that needs a force push and rewrites commits teammates may have pulled.
- Understand both sides first (`git diff <merge-base> main -- <file>` and the
  same for the branch). Often one side restructured a file and the other
  changed its logic; keep the restructured version and re-apply the logic
  change on top, rather than picking one side.
- After resolving: `flutter analyze` and `flutter test` (plus the functions
  checks if `firebase/` is involved), and search for leftover `<<<<<<<` markers.
- Ask before pushing to a branch another person owns, and name the decisions
  you made (e.g. something left duplicated on purpose).

### After a PR is merged

When the user says a PR was merged:

1. `git checkout main` and `git pull --prune`. If local changes block the
   checkout, find out where they come from before discarding anything.
2. Check CI for the merge commit (`gh run list --branch main --limit 1`). It
   includes the automatic deploy of rules and functions; report a failure
   with a link to the run. A run can take a moment to appear.
3. Delete the merged local branch (`git branch -d`, which refuses unmerged
   work) after asking, and check for other merged or orphaned branches and
   open PRs, as at session start.
4. If the PR was a step of one of the user's plans, name the next step.
