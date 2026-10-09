// tool/run_with_log.mjs
//
// Runs `flutter run` and writes everything it prints into a new log file in
// `logs/` (one per start, the newest 5 are kept). For development only: an
// installed APK never writes these files.
//
// Usage (from frontend/soundpilot_application/):
//   node tool/run_with_log.mjs [flutter run arguments, e.g. -d <device>]

import { execFileSync, spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

/** How many log files are kept, including the new one. */
const KEEP = 5;

const appDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const logDir = path.join(appDir, 'logs');
const args = process.argv.slice(2);

// ── Log file ──────────────────────────────────────────────────────────────

const pad = (n, width = 2) => String(n).padStart(width, '0');

/** Local time as `2026-10-09_14-03-07` (sorts by name = by time). */
function fileStamp(d) {
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}_` +
    `${pad(d.getHours())}-${pad(d.getMinutes())}-${pad(d.getSeconds())}`;
}

/** Local time as `14:03:07.123`, written in front of every line. */
function lineStamp(d) {
  return `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}.` +
    pad(d.getMilliseconds(), 3);
}

fs.mkdirSync(logDir, { recursive: true });

// Delete the oldest files so that, with the new one, KEEP remain.
const existing = fs.readdirSync(logDir)
  .filter((f) => /^run-.*\.log$/.test(f))
  .sort();
for (const f of existing.slice(0, Math.max(0, existing.length - (KEEP - 1)))) {
  fs.rmSync(path.join(logDir, f), { force: true });
}

const started = new Date();
const logFile = path.join(logDir, `run-${fileStamp(started)}.log`);
const log = fs.createWriteStream(logFile);

/** `git <args>` in the app folder, or `unknown` (e.g. no git installed). */
function git(...gitArgs) {
  try {
    return execFileSync('git', gitArgs, { cwd: appDir, encoding: 'utf8' }).trim();
  } catch {
    return 'unknown';
  }
}

log.write(
  `# flutter run ${args.join(' ')}\n` +
  `# started  ${started.toString()}\n` +
  `# branch   ${git('rev-parse', '--abbrev-ref', 'HEAD')} ` +
  `(${git('rev-parse', '--short', 'HEAD')}` +
  `${git('status', '--porcelain') ? ', uncommitted changes' : ''})\n\n`,
);

// ── Output ────────────────────────────────────────────────────────────────

// Colour and cursor codes; shown in the console, removed in the file.
const ANSI = /\x1b\[[0-9;?]*[ -/]*[@-~]/g;

/** Copies [stream] to [target] unchanged and to the log line by line. */
function tee(stream, target) {
  let rest = '';
  stream.setEncoding('utf8');
  stream.on('data', (chunk) => {
    target.write(chunk);
    const lines = (rest + chunk).split(/\r?\n/);
    rest = lines.pop();
    for (const line of lines) {
      log.write(`${lineStamp(new Date())} ${line.replace(ANSI, '')}\n`);
    }
  });
  stream.on('end', () => {
    if (rest) log.write(`${lineStamp(new Date())} ${rest.replace(ANSI, '')}\n`);
  });
}

console.log(`Log: ${path.relative(process.cwd(), logFile)}`);

// NOTE: stdin stays the terminal, so flutter's keys (r, R, q) keep working.
// `shell` is needed on Windows, where flutter is a .bat file.
const flutter = spawn('flutter', ['run', ...args], {
  cwd: appDir,
  stdio: ['inherit', 'pipe', 'pipe'],
  shell: process.platform === 'win32',
});
tee(flutter.stdout, process.stdout);
tee(flutter.stderr, process.stderr);

// Ctrl+C also reaches flutter, which then quits the app. Wait for it, so the
// end of its output still gets into the log.
process.on('SIGINT', () => {});

flutter.on('close', (code, signal) => {
  log.end(`\n# ended    ${new Date().toString()} ` +
    `(exit code ${code ?? '-'}${signal ? `, signal ${signal}` : ''})\n`);
  process.exitCode = code ?? 1;
});

flutter.on('error', (e) => {
  log.end(`\n# could not start flutter: ${e.message}\n`);
  console.error(`Could not start flutter: ${e.message}`);
  process.exitCode = 1;
});
