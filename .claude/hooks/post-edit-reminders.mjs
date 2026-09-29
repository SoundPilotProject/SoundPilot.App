// .claude/hooks/post-edit-reminders.mjs
//
// PostToolUse hook: after an edit, reminds Claude of the team rules that tie
// several files together (CLAUDE.md §8), so the second half is not forgotten.

let raw = '';
for await (const chunk of process.stdin) raw += chunk;
const input = JSON.parse(raw || '{}');
const path = String(input.tool_input?.file_path ?? '').replace(/\\/g, '/');

let reminder = '';

if (/(^|\/)CLAUDE\.md$/.test(path)) {
  reminder = 'CLAUDE.md changed: if §1–§8 changed, apply the same change to ' +
    'docs/PROJECT_CONTEXT.md in the same commit. Claude-specific content ' +
    'belongs in §9 only; PROJECT_CONTEXT.md must not mention Claude.';
} else if (/(^|\/)docs\/PROJECT_CONTEXT\.md$/.test(path)) {
  reminder = 'docs/PROJECT_CONTEXT.md changed: apply the same change to ' +
    '§1–§8 of CLAUDE.md in the same commit, and keep anything about Claude ' +
    'out of PROJECT_CONTEXT.md.';
} else if (/firebase\/firestore\.rules$|firebase\/functions\/src\/index\.ts$|lib\/models\/user_model\.dart$/.test(path)) {
  reminder = 'Firestore schema file changed. If the schema changed, update ' +
    'all three places: Cloud Function defaults (index.ts), Dart model ' +
    '(fromMap/toMap) and firestore.rules; bump schemaVersion in index.ts ' +
    'and UserModel.currentSchemaVersion; re-test the rules in the emulator.';
}

if (reminder) {
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: { hookEventName: 'PostToolUse', additionalContext: reminder },
  }));
}
