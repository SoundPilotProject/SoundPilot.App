import * as functions from "firebase-functions/v1";
import {initializeApp} from "firebase-admin/app";
import {getFirestore, FieldValue} from "firebase-admin/firestore";
import {logger} from "firebase-functions";

// Uses the default credentials of the Cloud Functions environment.
initializeApp();
const db = getFirestore();

/**
 * Automatically creates a Firestore document when a new user is registered.
 * Region: europe-central2 (Germany/Poland)
 *
 * NOTE: Deliberately 1st Gen (`firebase-functions/v1`). 2nd Gen has no
 * asynchronous auth `onCreate` trigger (only blocking functions, which need
 * Identity Platform). Do not migrate to 2nd Gen without discussion, see
 * CLAUDE.md.
 *
 * NOTE: `settings.language` is "system" here, while the app UI is German.
 * `displayName` falls back to "New User"; the Dart model (`UserModel`) falls
 * back to "User".
 *
 * TODO(improve): Errors are only logged and not rethrown, so a failed write
 * leaves the user without a document and nothing retries it. Consider
 * rethrowing so the trigger can be retried.
 */
export const createUserDoc = functions
  .region("europe-central2")
  .auth.user()
  .onCreate(async (user) => {
    const {uid, email, displayName, providerData} = user;
    const userRef = db.doc(`users/${uid}`);

    try {
      logger.info(`Attempting to create document for user: ${uid}`);

      const data = {
        uid: uid,
        email: email || null,
        displayName: displayName || "New User",
        providers: (providerData || []).map((p) => p.providerId),
        createdAt: FieldValue.serverTimestamp(),
        settings: {
          language: "system",
          theme: "system",
        },
        calibration: {
          headphones: {},
          belts: {},
        },
      };

      // Using { merge: true } to prevent accidental overwrites
      await userRef.set(data, {merge: true});

      // eslint-disable-next-line max-len
      logger.info(`Successfully created Firestore document for UID: ${uid}`);
    } catch (error) {
      logger.error(`Error creating document for UID: ${uid}`, error);
    }
  });

/**
 * Automatically deletes the Firestore document when a user account is deleted.
 * Region: europe-central2 (same as createUserDoc).
 *
 * NOTE: Only `users/{uid}` is deleted. Subcollections of the document (if any
 * are added later) are not removed by `delete()`.
 *
 * TODO(improve): Errors are only logged and not rethrown (see createUserDoc).
 */
export const deleteUserDoc = functions
  .region("europe-central2")
  .auth.user()
  .onDelete(async (user) => {
    const userRef = db.doc(`users/${user.uid}`);
    try {
      logger.info(`Attempting to delete document for user: ${user.uid}`);
      await userRef.delete();
      // eslint-disable-next-line max-len
      logger.info(`Successfully deleted Firestore document for UID: ${user.uid}`);
    } catch (error) {
      logger.error(`Error deleting document for UID: ${user.uid}`, error);
    }
  });
