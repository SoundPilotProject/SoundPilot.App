// firebase/functions/test/index.test.mjs
//
// Tests the compiled Cloud Functions (lib/index.js) against the Firestore
// emulator: the document createUserDoc writes, that a retry keeps the user's
// data, and that deleteUserDoc removes it. Run with `npm test` (builds, starts
// the emulator) or `npm run test:running`.

import {createRequire} from 'node:module';
import {after, describe, it} from 'node:test';
import assert from 'node:assert/strict';

// Never talk to a real project: `emulators:exec` sets this, `test:running`
// falls back to the default emulator port.
process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';

const require = createRequire(import.meta.url);

// NOTE: firebase-functions-test has to be initialised before lib/index.js is
// loaded, because index.js calls initializeApp() when it is loaded.
const fft = require('firebase-functions-test')({projectId: 'demo-soundpilot'});
const {createUserDoc, deleteUserDoc} = require('../lib/index.js');
const {getFirestore, FieldPath, Timestamp} =
  require('firebase-admin/firestore');

const db = getFirestore();
const createUser = fft.wrap(createUserDoc);
const deleteUser = fft.wrap(deleteUserDoc);
const HEADPHONE = 'AA:BB:CC:DD:EE:FF';

let counter = 0;

/** A fresh UID per test, so the tests do not share documents. */
function newUid() {
  return `user-${Date.now()}-${counter++}`;
}

/** An auth user record as the trigger receives it. */
function userRecord(uid, fields = {}) {
  return fft.auth.makeUserRecord({uid, ...fields});
}

async function readUser(uid) {
  return db.doc(`users/${uid}`).get();
}

after(() => fft.cleanup());

describe('createUserDoc', () => {
  it('creates the default document', async () => {
    const uid = newUid();
    await createUser(userRecord(uid, {
      email: 'a@example.com',
      displayName: 'Anna',
      providerData: [{providerId: 'password'}, {providerId: 'google.com'}],
    }));

    const data = (await readUser(uid)).data();
    assert.ok(data.createdAt instanceof Timestamp);
    delete data.createdAt;
    assert.deepEqual(data, {
      uid,
      email: 'a@example.com',
      displayName: 'Anna',
      providers: ['password', 'google.com'],
      schemaVersion: 1,
      settings: {language: 'system', theme: 'system'},
      calibration: {headphones: {}, belts: {}},
    });
  });

  it('falls back when the account has no e-mail, name or providers',
    async () => {
      const uid = newUid();
      await createUser(userRecord(uid));

      const data = (await readUser(uid)).data();
      assert.equal(data.email, null);
      assert.equal(data.displayName, 'New User');
      assert.deepEqual(data.providers, []);
    });

  it('keeps devices, settings and createdAt on a retry', async () => {
    const uid = newUid();
    const user = userRecord(uid, {email: 'b@example.com'});
    await createUser(user);
    const createdAt = (await readUser(uid)).get('createdAt');

    // What the app writes (field paths, see FirestoreDeviceRepository).
    await db.doc(`users/${uid}`).update(
      new FieldPath('calibration', 'headphones', HEADPHONE),
      {modelId: 'x', volLeft: 0.7, volRight: 0.3},
      new FieldPath('calibration', 'belts', 'dummy_mac_1'),
      {modelId: 'belt'},
      'settings.language', 'de',
    );

    // A retry of the same event must succeed and leave the document alone.
    await createUser(user);

    const data = (await readUser(uid)).data();
    assert.deepEqual(data.calibration, {
      headphones: {[HEADPHONE]: {modelId: 'x', volLeft: 0.7, volRight: 0.3}},
      belts: {dummy_mac_1: {modelId: 'belt'}},
    });
    assert.equal(data.settings.language, 'de');
    assert.ok(data.createdAt.isEqual(createdAt));
  });
});

describe('deleteUserDoc', () => {
  it('deletes the document', async () => {
    const uid = newUid();
    const user = userRecord(uid);
    await createUser(user);
    assert.ok((await readUser(uid)).exists);

    await deleteUser(user);

    assert.equal((await readUser(uid)).exists, false);
  });

  it('succeeds on a retry when the document is already gone', async () => {
    const uid = newUid();
    await deleteUser(userRecord(uid));
    assert.equal((await readUser(uid)).exists, false);
  });
});
