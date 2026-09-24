"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.deleteUserDoc = exports.createUserDoc = void 0;
const functions = __importStar(require("firebase-functions/v1"));
const app_1 = require("firebase-admin/app");
const firestore_1 = require("firebase-admin/firestore");
const firebase_functions_1 = require("firebase-functions");
// Uses the default credentials of the Cloud Functions environment.
(0, app_1.initializeApp)();
const db = (0, firestore_1.getFirestore)();
/**
 * Version of the `users/{uid}` document schema written by `createUserDoc`.
 * Increase it whenever the default document changes, so outdated documents can
 * be found with a query on `schemaVersion` and migrated.
 * Keep it in sync with `UserModel.currentSchemaVersion` (Dart) and
 * firestore.rules.
 */
const SCHEMA_VERSION = 1;
/**
 * Automatically creates a Firestore document when a new user is registered.
 * Region: europe-central2 (Germany/Poland)
 *
 * NOTE: Deliberately 1st Gen (`firebase-functions/v1`). 2nd Gen has no
 * asynchronous auth `onCreate` trigger (only blocking functions, which need
 * Identity Platform). Do not migrate to 2nd Gen without discussion, see
 * docs/PROJECT_CONTEXT.md.
 *
 * NOTE: `settings.language` is "system" here, while the app UI is German.
 * `displayName` falls back to "New User"; the Dart model (`UserModel`) falls
 * back to "User".
 *
 * NOTE: Errors are rethrown and `failurePolicy: true` enables retries, so a
 * failed write no longer leaves the user without a document. (Before, errors
 * were only logged and nothing retried them.) Retries are repeated for up to
 * 7 days, so the function must stay idempotent. Because of `merge: true`, a
 * retry keeps existing devices, but it rewrites `createdAt`.
 */
exports.createUserDoc = functions
    .region("europe-central2")
    .runWith({ failurePolicy: true })
    .auth.user()
    .onCreate(async (user) => {
    const { uid, email, displayName, providerData } = user;
    const userRef = db.doc(`users/${uid}`);
    try {
        firebase_functions_1.logger.info(`Attempting to create document for user: ${uid}`);
        const data = {
            uid: uid,
            email: email || null,
            displayName: displayName || "New User",
            providers: (providerData || []).map((p) => p.providerId),
            createdAt: firestore_1.FieldValue.serverTimestamp(),
            schemaVersion: SCHEMA_VERSION,
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
        await userRef.set(data, { merge: true });
        // eslint-disable-next-line max-len
        firebase_functions_1.logger.info(`Successfully created Firestore document for UID: ${uid}`);
    }
    catch (error) {
        firebase_functions_1.logger.error(`Error creating document for UID: ${uid}`, error);
        throw error;
    }
});
/**
 * Automatically deletes the Firestore document when a user account is deleted.
 * Region: europe-central2 (same as createUserDoc).
 *
 * NOTE: Only `users/{uid}` is deleted. Subcollections of the document (if any
 * are added later) are not removed by `delete()`.
 *
 * NOTE: Errors are rethrown and retried, see createUserDoc. Deleting a
 * document that does not exist is not an error, so retries are safe.
 */
exports.deleteUserDoc = functions
    .region("europe-central2")
    .runWith({ failurePolicy: true })
    .auth.user()
    .onDelete(async (user) => {
    const userRef = db.doc(`users/${user.uid}`);
    try {
        firebase_functions_1.logger.info(`Attempting to delete document for user: ${user.uid}`);
        await userRef.delete();
        // eslint-disable-next-line max-len
        firebase_functions_1.logger.info(`Successfully deleted Firestore document for UID: ${user.uid}`);
    }
    catch (error) {
        firebase_functions_1.logger.error(`Error deleting document for UID: ${user.uid}`, error);
        throw error;
    }
});
//# sourceMappingURL=index.js.map