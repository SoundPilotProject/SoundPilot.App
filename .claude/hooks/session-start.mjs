// .claude/hooks/session-start.mjs
//
// SessionStart hook: brings the checkout up to date and reports the repo state
// (the "session start" check of CLAUDE.md §9), so it happens every time.

import { execFileSync } from 'node:child_process';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');

/** Runs a command in the repo root; returns trimmed stdout, or null on error. */
function run(cmd, args, timeout = 20000) {
  try {
    return execFileSync(cmd, args, {
      cwd: root,
      encoding: 'utf8',
      timeout,
      stdio: ['ignore', 'pipe', 'pipe'],
    }).trim();
  } catch {
    return null;
  }
}

const lines = [];
const notes = [];

const fetched = run('git', ['fetch', '--prune']) !== null;
if (!fetched) notes.push('git fetch failed (offline?) - state below may be stale');

const branch = run('git', ['rev-parse', '--abbrev-ref', 'HEAD']) ?? '?';
const dirty = run('git', ['status', '--porcelain']) ?? '';
const behindOf = (ref) =>
  Number(run('git', ['rev-list', '--count', `HEAD..${ref}`]) ?? 0);

lines.push(`Branch: ${branch}`);

if (branch === 'main') {
  const behind = behindOf('origin/main');
  if (behind > 0 && dirty) {
    notes.push(`main is ${behind} commit(s) behind origin, NOT pulled: uncommitted changes`);
  } else if (behind > 0) {
    const pulled = run('git', ['pull', '--ff-only', '--prune'], 60000) !== null;
    notes.push(pulled
      ? `Pulled ${behind} new commit(s) from origin/main`
      : `main is ${behind} commit(s) behind origin, pull --ff-only FAILED (diverged?)`);
  } else {
    lines.push('main is up to date with origin');
  }
} else {
  const upstream = run('git', ['rev-parse', '--abbrev-ref', '@{u}']);
  if (upstream && behindOf(upstream) > 0) {
    notes.push(`${branch} is ${behindOf(upstream)} commit(s) behind ${upstream} (not pulled automatically)`);
  }
  const mainAhead = Number(run('git', ['rev-list', '--count', 'HEAD..origin/main']) ?? 0);
  if (mainAhead > 0) {
    notes.push(`origin/main has ${mainAhead} commit(s) this branch does not have yet`);
  }
}

if (dirty) {
  notes.push('Uncommitted changes:\n' + dirty.split('\n').map((l) => '  ' + l).join('\n'));
}

// Local branches whose remote was deleted, or that are already merged.
const gone = (run('git', ['branch', '-vv']) ?? '')
  .split('\n')
  .filter((l) => l.includes(': gone]'))
  .map((l) => l.replace(/^\*?\s+/, '').split(/\s+/)[0]);
const merged = (run('git', ['branch', '--merged', 'origin/main', '--format=%(refname:short)']) ?? '')
  .split('\n')
  .filter((b) => b && b !== 'main' && b !== branch && !gone.includes(b));
if (gone.length) notes.push(`Local branches whose remote is gone: ${gone.join(', ')}`);
if (merged.length) notes.push(`Local branches already merged into main: ${merged.join(', ')}`);

// Open PRs (optional: needs the GitHub CLI and a login).
const prsJson = run('gh', ['pr', 'list', '--state', 'open', '--json', 'number,title,headRefName,mergeable']);
if (prsJson) {
  const prs = JSON.parse(prsJson);
  if (prs.length) {
    notes.push('Open PRs:\n' + prs
      .map((p) => `  #${p.number} ${p.title} (${p.headRefName}, ${p.mergeable})`)
      .join('\n'));
  }
}

const report = [...lines, ...notes].join('\n');

process.stdout.write(JSON.stringify({
  systemMessage: notes.length
    ? `Repo check: ${notes.map((n) => n.split('\n')[0]).join(' | ')}`
    : `Repo check: ${branch}, up to date, clean`,
  hookSpecificOutput: {
    hookEventName: 'SessionStart',
    additionalContext:
      'Automatic repo check (SessionStart hook). Report this to the user at ' +
      'the start of your first reply; ask before deleting branches or ' +
      'discarding changes.\n' + report,
  },
}));
