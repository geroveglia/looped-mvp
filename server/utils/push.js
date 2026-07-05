/**
 * FCM push notifications via the HTTP v1 API.
 *
 * No firebase-admin dependency: google-auth-library (already used for
 * Google Sign-In) mints the OAuth2 access token from a service account.
 *
 * Env:
 *   FIREBASE_SERVICE_ACCOUNT — the full service-account JSON, pasted as a
 *     single-line env var (Firebase console → Project settings →
 *     Service accounts → Generate new private key).
 *
 * If unset, every function is a silent no-op so the rest of the app
 * works without Firebase.
 */

const { GoogleAuth } = require('google-auth-library');
const User = require('../models/User');

let _auth = null;
let _projectId = null;

function _init() {
    if (_auth) return true;
    const raw = process.env.FIREBASE_SERVICE_ACCOUNT;
    if (!raw) return false;
    try {
        const credentials = JSON.parse(raw);
        _projectId = credentials.project_id;
        _auth = new GoogleAuth({
            credentials,
            scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
        });
        return true;
    } catch (err) {
        console.error('[push] Invalid FIREBASE_SERVICE_ACCOUNT JSON:', err.message);
        return false;
    }
}

function isConfigured() {
    return _init();
}

/** Sends one notification to one device token. Returns true on success. */
async function sendToToken(token, { title, body, data }) {
    if (!_init()) return false;
    try {
        const accessToken = await _auth.getAccessToken();
        const res = await fetch(
            `https://fcm.googleapis.com/v1/projects/${_projectId}/messages:send`,
            {
                method: 'POST',
                headers: {
                    Authorization: `Bearer ${accessToken}`,
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    message: {
                        token,
                        notification: { title, body },
                        ...(data ? { data } : {}),
                    },
                }),
            }
        );
        if (res.status === 404 || res.status === 410) return 'stale';
        return res.ok;
    } catch (err) {
        console.error('[push] send failed:', err.message);
        return false;
    }
}

/**
 * Sends a notification to every registered device of the given users.
 * Stale tokens (uninstalled app) are pruned from the user documents.
 * Fire-and-forget friendly: never throws.
 */
async function pushToUsers(userIds, { title, body, data }) {
    if (!_init() || !userIds || userIds.length === 0) return;
    try {
        const users = await User.find({
            _id: { $in: userIds },
            fcm_tokens: { $exists: true, $ne: [] },
        }).select('fcm_tokens');

        for (const user of users) {
            const stale = [];
            for (const token of user.fcm_tokens) {
                const result = await sendToToken(token, { title, body, data });
                if (result === 'stale') stale.push(token);
            }
            if (stale.length > 0) {
                await User.updateOne(
                    { _id: user._id },
                    { $pull: { fcm_tokens: { $in: stale } } }
                );
            }
        }
    } catch (err) {
        console.error('[push] pushToUsers failed:', err.message);
    }
}

module.exports = { isConfigured, pushToUsers };
