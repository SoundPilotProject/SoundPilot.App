import * as functions from "firebase-functions/v1";
import {initializeApp} from "firebase-admin/app";
import {getFirestore, FieldValue} from "firebase-admin/firestore";

initializeApp();
const db = getFirestore();

// Runs automatically for every new user:
// eslint-disable-next-line max-len
export const createUserDoc = functions.region("europe-central2").auth.user().onCreate(async (user) => {
  const ref = db.doc(`users/${user.uid}`);

  const data = {
    email: user.email,
    providers: (user.providerData || []).map((p) => p.providerId),
    createdAt: FieldValue.serverTimestamp(),
    settings: {
      language: "de",
      theme: "system",
    },
  };

  await ref.set(data, {merge: true});
});

// eslint-disable-next-line max-len
export const deleteUserDoc = functions.region("europe-central2").auth.user().onDelete(async (user) => {
  const ref = db.doc(`users/${user.uid}`);
  await ref.delete();
  console.log(`User-Document ${user.uid} deleted.`);
});


