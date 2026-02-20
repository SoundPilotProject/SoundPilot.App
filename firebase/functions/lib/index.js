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
(0, app_1.initializeApp)();
const db = (0, firestore_1.getFirestore)();
/**
 * Automatically creates a Firestore document when a new user is registered.
 * Region: europe-central2 (Germany/Poland)
 */
exports.createUserDoc = functions
    .region("europe-central2")
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
            settings: {
                language: "system",
                theme: "system",
            },
        };
        // Using { merge: true } to prevent accidental overwrites
        await userRef.set(data, { merge: true });
        firebase_functions_1.logger.info(`Successfully created Firestore document for UID: ${uid}`);
    }
    catch (error) {
        // This will show up as a red error in your Firebase Logs
        firebase_functions_1.logger.error(`Error creating document for UID: ${uid}`, error);
    }
});
/**
 * Automatically deletes the Firestore document when a user account is deleted.
 */
exports.deleteUserDoc = functions
    .region("europe-central2")
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
    }
});
//# sourceMappingURL=index.js.map