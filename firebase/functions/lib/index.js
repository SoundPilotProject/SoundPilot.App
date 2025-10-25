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
(0, app_1.initializeApp)();
const db = (0, firestore_1.getFirestore)();
// Runs automatically for every new user:
// eslint-disable-next-line max-len
exports.createUserDoc = functions.region("europe-central2").auth.user().onCreate(async (user) => {
    const ref = db.doc(`users/${user.uid}`);
    const data = {
        email: user.email,
        providers: (user.providerData || []).map((p) => p.providerId),
        createdAt: firestore_1.FieldValue.serverTimestamp(),
        settings: {
            language: "de",
            theme: "system",
        },
    };
    await ref.set(data, { merge: true });
});
// eslint-disable-next-line max-len
exports.deleteUserDoc = functions.region("europe-central2").auth.user().onDelete(async (user) => {
    const ref = db.doc(`users/${user.uid}`);
    await ref.delete();
    console.log(`User-Document ${user.uid} deleted.`);
});
//# sourceMappingURL=index.js.map