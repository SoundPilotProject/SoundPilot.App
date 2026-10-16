// firebase/rules-tests/firestore.rules.test.mjs
//
// Tests firebase/firestore.rules against the Firestore emulator: what a
// signed-in client may read and write, and that everything else is denied.
// Run with `npm test` (starts the emulator) or `npm run test:running`.

import {readFileSync} from 'node:fs';
import {after, before, beforeEach, describe, it} from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  deleteField,
  doc,
  FieldPath,
  getDoc,
  getDocs,
  serverTimestamp,
  setDoc,
  setLogLevel,
  updateDoc,
} from 'firebase/firestore';

const OWNER = 'owner-uid';
const OTHER = 'other-uid';
const HEADPHONE = 'AA:BB:CC:DD:EE:FF';

let env;

/** The document as `createUserDoc` writes it, with one device in it. */
function userDoc(uid) {
  return {
    uid,
    email: `${uid}@example.com`,
    displayName: 'New User',
    providers: ['password'],
    createdAt: serverTimestamp(),
    schemaVersion: 1,
    settings: {language: 'system', theme: 'system'},
    calibration: {
      headphones: {[HEADPHONE]: {modelId: 'x', volLeft: 0.5, volRight: 0.5}},
      belts: {},
    },
  };
}

/** Firestore of a signed-in user, or of nobody for `null`. */
function dbOf(uid) {
  return uid === null ?
    env.unauthenticatedContext().firestore() :
    env.authenticatedContext(uid).firestore();
}

/** The field path of one device, the way FirestoreDeviceRepository writes. */
function devicePath(type, key) {
  return new FieldPath('calibration', type, key);
}

before(async () => {
  // The SDK logs every denied write as a warning; denials are expected here.
  setLogLevel('silent');
  env = await initializeTestEnvironment({
    projectId: 'demo-soundpilot',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url),
        'utf8'),
    },
  });
});

after(async () => {
  await env?.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  // Seeding stands in for the cloud function (Admin SDK, ignores the rules).
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users', OWNER), userDoc(OWNER));
    await setDoc(doc(db, 'users', OTHER), userDoc(OTHER));
  });
});

// ── Read ────────────────────────────────────────────────────────────────────

describe('read users/{uid}', () => {
  it('allows the owner', async () => {
    await assertSucceeds(getDoc(doc(dbOf(OWNER), 'users', OWNER)));
  });

  it('denies another user', async () => {
    await assertFails(getDoc(doc(dbOf(OTHER), 'users', OWNER)));
  });

  it('denies a signed-out client', async () => {
    await assertFails(getDoc(doc(dbOf(null), 'users', OWNER)));
  });

  it('denies a query over the whole collection', async () => {
    await assertFails(getDocs(collection(dbOf(OWNER), 'users')));
  });
});

// ── Create and delete ───────────────────────────────────────────────────────

describe('create and delete users/{uid}', () => {
  it('denies creating the own document', async () => {
    const uid = 'new-uid';
    await assertFails(setDoc(doc(dbOf(uid), 'users', uid), userDoc(uid)));
  });

  it('denies deleting the own document', async () => {
    await assertFails(deleteDoc(doc(dbOf(OWNER), 'users', OWNER)));
  });

  it('denies overwriting the own document as a whole', async () => {
    await assertFails(
      setDoc(doc(dbOf(OWNER), 'users', OWNER), userDoc(OWNER)));
  });
});

// ── Update ──────────────────────────────────────────────────────────────────

describe('update users/{uid}', () => {
  const ownRef = () => doc(dbOf(OWNER), 'users', OWNER);

  it('allows putting a headphone with an address key', async () => {
    await assertSucceeds(updateDoc(ownRef(),
      devicePath('headphones', '11:22:33:44:55:66'),
      {modelId: 'y', volLeft: 0.7, volRight: 0.3}));
  });

  it('allows changing one volume', async () => {
    await assertSucceeds(updateDoc(ownRef(),
      new FieldPath('calibration', 'headphones', HEADPHONE, 'volLeft'), 0.9));
  });

  it('allows putting a belt', async () => {
    await assertSucceeds(updateDoc(ownRef(),
      devicePath('belts', 'dummy_mac_1'), {modelId: 'belt'}));
  });

  it('allows removing a device', async () => {
    await assertSucceeds(updateDoc(ownRef(),
      devicePath('headphones', HEADPHONE), deleteField()));
  });

  it('allows adding several devices in one update (import)', async () => {
    await assertSucceeds(updateDoc(ownRef(),
      devicePath('headphones', '11:22:33:44:55:66'), {modelId: 'a'},
      devicePath('belts', 'dummy_mac_2'), {modelId: 'b'}));
  });

  it('allows changing a setting', async () => {
    await assertSucceeds(updateDoc(ownRef(), 'settings.language', 'de'));
  });

  for (const field of ['uid', 'email', 'displayName', 'createdAt',
    'providers', 'schemaVersion']) {
    it(`denies changing ${field}`, async () => {
      await assertFails(updateDoc(ownRef(), field, 'changed'));
    });
  }

  it('denies a new top-level field', async () => {
    await assertFails(updateDoc(ownRef(), 'isAdmin', true));
  });

  it('denies a device change together with a read-only field', async () => {
    await assertFails(updateDoc(ownRef(),
      devicePath('belts', 'dummy_mac_1'), {modelId: 'belt'},
      'displayName', 'Mallory'));
  });

  it('denies another user', async () => {
    await assertFails(updateDoc(doc(dbOf(OTHER), 'users', OWNER),
      devicePath('belts', 'dummy_mac_1'), {modelId: 'belt'}));
  });

  it('denies a signed-out client', async () => {
    await assertFails(updateDoc(doc(dbOf(null), 'users', OWNER),
      'settings.language', 'de'));
  });

  it('denies a document that does not exist yet', async () => {
    // Right after registration, before createUserDoc has run (§6).
    const uid = 'new-uid';
    await assertFails(updateDoc(doc(dbOf(uid), 'users', uid),
      devicePath('belts', 'dummy_mac_1'), {modelId: 'belt'}));
  });
});

// ── Everything else ─────────────────────────────────────────────────────────

describe('other paths', () => {
  it('denies a subcollection of the own document', async () => {
    const ref = doc(dbOf(OWNER), 'users', OWNER, 'private', 'x');
    await assertFails(setDoc(ref, {a: 1}));
    await assertFails(getDoc(ref));
  });

  it('denies another collection', async () => {
    const ref = doc(dbOf(OWNER), 'devices', 'x');
    await assertFails(setDoc(ref, {a: 1}));
    await assertFails(getDoc(ref));
  });
});
