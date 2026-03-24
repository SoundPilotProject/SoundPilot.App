import * as functions from "firebase-functions/v1";
import {initializeApp} from "firebase-admin/app";
import {getFirestore, FieldValue} from "firebase-admin/firestore";
import {logger} from "firebase-functions";

initializeApp();
const db = getFirestore();

/**
 * Automatically creates a Firestore document when a new user is registered.
 * Region: europe-central2 (Germany/Poland)
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
