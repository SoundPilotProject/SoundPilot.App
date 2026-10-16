// .claude/hooks/post-edit-reminders.mjs
//
// PostToolUse hook: after an edit, reminds Claude of the team rules that tie
// several files together (docs/PROJECT_CONTEXT.md §8), so the second half
// is not forgotten.

let raw = '';
for await (const chunk of process.stdin) raw += chunk;
const input = JSON.parse(raw || '{}');
const path = String(input.tool_input?.file_path ?? '').replace(/\\/g, '/');

let reminder = '';

if (/(^|\/)CLAUDE\.md$/.test(path)) {
  reminder = 'CLAUDE.md changed: it only imports docs/PROJECT_CONTEXT.md ' +
    '(§1–§8) and holds the Claude-only §9. Project knowledge belongs in ' +
    'PROJECT_CONTEXT.md, not here.';
} else if (/(^|\/)docs\/PROJECT_CONTEXT\.md$/.test(path)) {
  reminder = 'docs/PROJECT_CONTEXT.md changed: keep anything about Claude ' +
    'out of it (that goes into §9 of CLAUDE.md), keep the section numbers ' +
    'stable (code refers to them), and describe the current state, not ' +
    'history.';
} else if (/firebase\/firestore\.rules$|firebase\/functions\/src\/index\.ts$|lib\/models\/user_model\.dart$/.test(path)) {
  reminder = 'Firestore schema file changed. If the schema changed, update ' +
    'all three places: Cloud Function defaults (index.ts), Dart model ' +
    '(fromMap/toMap) and firestore.rules; bump schemaVersion in index.ts ' +
    'and UserModel.currentSchemaVersion; add a test for a rules change in ' +
    'firebase/rules-tests and run `npm test` there.';
}

if (reminder) {
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: { hookEventName: 'PostToolUse', additionalContext: reminder },
  }));
}
