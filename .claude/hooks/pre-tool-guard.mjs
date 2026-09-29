// .claude/hooks/pre-tool-guard.mjs
//
// PreToolUse hook: stops the risky actions the team rules forbid (CLAUDE.md
// §3 and §8) before they run. "deny" blocks outright, "ask" turns the call
// into a permission prompt with the reason shown.

import { execFileSync } from 'node:child_process';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');

let raw = '';
for await (const chunk of process.stdin) raw += chunk;
const input = JSON.parse(raw || '{}');
const tool = input.tool_name ?? '';
const args = input.tool_input ?? {};

function decide(decision, reason) {
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: {
      hookEventName: 'PreToolUse',
      permissionDecision: decision,
      permissionDecisionReason: reason,
    },
  }));
  process.exit(0);
}

function currentBranch() {
  try {
    return execFileSync('git', ['rev-parse', '--abbrev-ref', 'HEAD'], {
      cwd: input.cwd || root,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
  } catch {
    return '';
  }
}

// ── Files ─────────────────────────────────────────────────────────────────

if (['Edit', 'Write', 'NotebookEdit'].includes(tool)) {
  const path = String(args.file_path ?? args.notebook_path ?? '').replace(/\\/g, '/');
  const name = path.split('/').pop() ?? '';

  if (/^(google-services\.json|GoogleService-Info\.plist)$/.test(name) ||
      /^\.env(\..*)?$/.test(name) ||
      /service[-_]?account.*\.json$/i.test(name) ||
      /\.(jks|keystore)$/.test(name) || name === 'key.properties') {
    decide('deny', `${name} holds keys/credentials. Do not edit or create it ` +
      'with Claude (CLAUDE.md §8); change it by hand if really needed.');
  }
  if (name === 'firebase_options.dart') {
    decide('deny', 'firebase_options.dart is generated. Regenerate it with ' +
      '`flutterfire configure` instead of editing it.');
  }
  process.exit(0);
}

// ── Shell commands ────────────────────────────────────────────────────────

if (tool !== 'Bash' && tool !== 'PowerShell') process.exit(0);

const command = String(args.command ?? '');
// Checked one by one, so `git add . && git commit` is caught as well.
const parts = command.split(/&&|\|\||;|\n|\|/).map((s) => s.trim()).filter(Boolean);

for (const part of parts) {
  // Only the command at the start of a segment counts, so text inside a
  // commit message, heredoc or `echo` does not trigger a rule.
  const words = part.replace(/^(sudo|npx)\s+/, '').split(/\s+/);
  const cmd = (words[0] ?? '').split(/[\\/]/).pop().replace(/\.(exe|cmd)$/i, '');
  // Subcommand after git's global options (`git -C <dir> commit`).
  let i = 1;
  while (cmd === 'git' && /^-[Cc]$/.test(words[i] ?? '')) i += 2;
  const gitIdx = cmd === 'git' ? i - 1 : -1;
  const sub = gitIdx >= 0 ? words[gitIdx + 1] : '';

  if (gitIdx >= 0 && words.includes('--no-verify')) {
    decide('deny', '--no-verify skips the git hooks. Fix what the hook ' +
      'reports instead.');
  }

  if (sub === 'commit' && currentBranch() === 'main') {
    decide('ask', 'This commits directly to main. Team rule: work on a ' +
      'branch and merge through a PR (CLAUDE.md §8). Only allow this if the ' +
      'team agreed to it for this change.');
  }

  if (sub === 'push') {
    const rest = words.slice(gitIdx + 2);
    if (rest.some((w) => /^(-f|--force|--force-with-lease.*|\+.+)$/.test(w))) {
      decide('ask', 'Force push rewrites history on GitHub and can delete ' +
        "teammates' commits.");
    }
    const isDelete = rest.includes('--delete') || rest.includes('-d');
    const refs = rest.filter((w) => !w.startsWith('-')).slice(1);
    const targetsMain = refs.length
      ? refs.some((r) => /(^|:)(refs\/heads\/)?main$/.test(r))
      : currentBranch() === 'main';
    if (targetsMain) {
      decide(isDelete ? 'deny' : 'ask', isDelete
        ? 'Deleting main on GitHub is never intended.'
        : 'This pushes to main, which also triggers the automatic deploy. ' +
          'Team rule: push a branch and open a PR (CLAUDE.md §8).');
    }
  }

  if ((sub === 'reset' && /--hard\b/.test(part)) ||
      (sub === 'clean' && /\s-\w*f/.test(part)) ||
      (sub === 'checkout' && /\s--\s+\./.test(part)) ||
      (sub === 'restore' && /\s\.(\s|$)/.test(part)) ||
      (sub === 'branch' && /\s-D\b/.test(part)) ||
      (sub === 'stash' && /\s(drop|clear)\b/.test(part))) {
    decide('ask', 'This throws away local work (uncommitted changes, ' +
      'branches or stashes) and cannot be undone.');
  }

  if (cmd === 'firebase' && words[1] === 'deploy') {
    decide('ask', 'CI deploys rules and functions on every merge to main; a ' +
      'manual deploy is overwritten by the next one (CLAUDE.md §3). Test ' +
      'with the emulators instead, deploy by hand only for things CI does ' +
      'not deploy (e.g. indexes).');
  }

  if ((cmd === 'rm' && words.some((w) => /^-\w*(r\w*f|f\w*r)/.test(w))) ||
      (/^(Remove-Item|rm|rd|rmdir)$/i.test(cmd) && /\s-Recurse\b/i.test(part))) {
    decide('ask', 'Recursive delete: check the path before confirming.');
  }
}

process.exit(0);
