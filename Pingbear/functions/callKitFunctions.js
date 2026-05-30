/**
 * callKitFunctions.js
 *
 * Sends VoIP push notifications via Apple APNs directly.
 * VoIP pushes bypass FCM and trigger the native iOS call UI via CallKit.
 *
 * Add to index.js:
 *   const callkit = require('./callKitFunctions');
 *   exports.sendCallInvite = callkit.sendCallInvite;
 *   exports.sendCallEnded  = callkit.sendCallEnded;
 *
 * Secrets required:
 *   APNS_VOIP_CERT_BASE64    — base64 encoded .p12 certificate
 *   APNS_VOIP_CERT_PASSWORD  — .p12 certificate password
 *   APNS_BUNDLE_ID           — com.pordio.Chay
 *   APNS_TEAM_ID             — 27J5KH92LA
 *   APNS_SANDBOX             — "true" for dev builds, "false" for App Store
 *
 * Set sandbox mode via:
 *   firebase functions:secrets:set APNS_SANDBOX
 *   > true          ← development / TestFlight
 *   > false         ← App Store production
 *
 * No code changes needed when switching environments.
 *
 * ─────────────────────────────────────────────────────────────
 * SELF-NOTIFICATION PREVENTION
 * ─────────────────────────────────────────────────────────────
 *
 * The caller's userId is never in the friendIds list they pass in,
 * so self-notification cannot happen server-side.
 * The client-side guards in CallKitManager.swift remain as a
 * secondary defence for edge cases.
 *
 * ─────────────────────────────────────────────────────────────
 * INVITE MODEL
 * ─────────────────────────────────────────────────────────────
 *
 * The caller selects friends on the home screen and taps call.
 * The client passes the selected friendIds explicitly.
 * This is simpler and more intentional than looking up all
 * competition members — you ring exactly who you chose.
 */

const { onCall } = require('firebase-functions/v2/https');
const admin      = require('firebase-admin');
const logger     = require('firebase-functions/logger');
const http2      = require('http2');
const forge      = require('node-forge');

let _db;
const getDb = () => {
  if (!_db) _db = admin.firestore();
  return _db;
};

const APNS_VOIP_HOST_PROD = 'api.push.apple.com';
const APNS_VOIP_HOST_DEV  = 'api.sandbox.push.apple.com';
const INVITE_COOLDOWN_MS  = 5000;


// ─────────────────────────────────────────────────────────────
// HELPER — load p12 cert and extract PEM key + cert
// ─────────────────────────────────────────────────────────────

function loadP12Credentials() {
  const base64Cert = process.env.APNS_VOIP_CERT_BASE64;
  const password   = process.env.APNS_VOIP_CERT_PASSWORD;

  if (!base64Cert || !password) throw new Error('APNS credentials not configured');

  const p12Buffer = Buffer.from(base64Cert, 'base64');
  const p12Asn1   = forge.asn1.fromDer(p12Buffer.toString('binary'));
  const p12       = forge.pkcs12.pkcs12FromAsn1(p12Asn1, false, password);

  let certPem = null;
  let keyPem  = null;

  for (const safeContent of p12.safeContents) {
    for (const safeBag of safeContent.safeBags) {
      if (safeBag.type === forge.pki.oids.certBag) {
        certPem = forge.pki.certificateToPem(safeBag.cert);
      } else if (
        safeBag.type === forge.pki.oids.pkcs8ShroudedKeyBag ||
        safeBag.type === forge.pki.oids.keyBag
      ) {
        keyPem = forge.pki.privateKeyToPem(safeBag.key);
      }
    }
  }

  if (!certPem || !keyPem) throw new Error('Could not extract cert or key from p12');
  return { certPem, keyPem };
}


// ─────────────────────────────────────────────────────────────
// HELPER — send a single VoIP push via APNs HTTP/2
// ─────────────────────────────────────────────────────────────

async function sendVoipPush({ deviceToken, payload, bundleId, certPem, keyPem, sandbox }) {
  const host = sandbox ? APNS_VOIP_HOST_DEV : APNS_VOIP_HOST_PROD;

  return new Promise((resolve, reject) => {
    const client = http2.connect(`https://${host}`, { cert: certPem, key: keyPem });

    client.on('error', (err) => {
      reject(new Error(`APNs connection error: ${err.message}`));
    });

    const payloadString = JSON.stringify(payload);

    const headers = {
      ':method':         'POST',
      ':path':           `/3/device/${deviceToken}`,
      ':scheme':         'https',
      ':authority':      host,
      'apns-topic':      `${bundleId}.voip`,
      'apns-push-type':  'voip',
      'apns-priority':   '10',
      'apns-expiration': '0',
      'content-type':    'application/json',
      'content-length':  Buffer.byteLength(payloadString).toString()
    };

    const req = client.request(headers);
    let responseData   = '';
    let responseStatus = 0;

    req.on('response', (responseHeaders) => { responseStatus = responseHeaders[':status']; });
    req.on('data', (chunk) => { responseData += chunk; });
    req.on('end', () => {
      client.close();
      if (responseStatus === 200) {
        resolve({ success: true });
      } else {
        reject(new Error(`APNs error ${responseStatus}: ${responseData}`));
      }
    });
    req.on('error', (err) => {
      client.close();
      reject(new Error(`APNs request error: ${err.message}`));
    });

    req.write(payloadString);
    req.end();
  });
}


// ─────────────────────────────────────────────────────────────
// HELPER — fetch VoIP tokens for a specific list of user IDs
//
// The caller passes friendIds explicitly — no member list lookup.
// This means you ring exactly who you selected, nothing more.
// ─────────────────────────────────────────────────────────────

async function getVoipTokensForUsers(db, userIds) {
  if (userIds.length === 0) return [];

  const chunkSize = 30;
  const tokens    = [];

  for (let i = 0; i < userIds.length; i += chunkSize) {
    const chunk     = userIds.slice(i, i + chunkSize);
    const usersSnap = await db.collection('users')
      .where(admin.firestore.FieldPath.documentId(), 'in', chunk)
      .get();

    usersSnap.docs.forEach(doc => {
      const token = doc.data()?.voipPushToken;
      if (token) {
        tokens.push({
          userId:      doc.id,
          deviceToken: token
        });
      }
    });
  }

  return tokens;
}


// ─────────────────────────────────────────────────────────────
// HELPER — enforce per-caller invite cooldown
// ─────────────────────────────────────────────────────────────

async function isInviteCooldownActive(db, callerId, sessionId) {
  const key = `call_invite_${callerId}_${sessionId}`;
  const ref = db.collection('rate_limits').doc(key);

  // Use a transaction so concurrent invocations can't both pass the check.
  // Without this, two simultaneous calls both read "no doc exists",
  // both write the timestamp, and both send the push — causing duplicates.
  try {
    const cooldownActive = await db.runTransaction(async (t) => {
      const doc = await t.get(ref);

      if (doc.exists) {
        const lastSent = doc.data()?.sent_at?.toMillis() ?? 0;
        if (Date.now() - lastSent < INVITE_COOLDOWN_MS) {
          logger.info(`sendCallInvite: cooldown active for ${callerId}`);
          return true; // blocked
        }
      }

      // Claim the slot atomically
      t.set(ref, { sent_at: admin.firestore.FieldValue.serverTimestamp() });
      return false; // allowed
    });

    return cooldownActive;
  } catch (err) {
    logger.warn(`sendCallInvite: cooldown transaction failed: ${err.message}`);
    return false; // allow on error to avoid blocking legitimate calls
  }
}


// ─────────────────────────────────────────────────────────────
// sendCallInvite
//
// Called from Swift immediately after createSession.
// Rings exactly the friends the caller selected — no more, no less.
//
// Usage from Swift:
//   Functions.functions().httpsCallable("sendCallInvite").call([
//     "sessionId": "abc123",
//     "friendIds": ["uid1", "uid2"]
//   ])
// ─────────────────────────────────────────────────────────────

exports.sendCallInvite = onCall({
  cors: ['*'],
  maxInstances: 50,
  minInstances: 1,
  secrets: [
    'APNS_VOIP_CERT_BASE64',
    'APNS_VOIP_CERT_PASSWORD',
    'APNS_BUNDLE_ID',
    'APNS_TEAM_ID',
  ]
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId = request.auth.uid;
  const { sessionId, friendIds } = request.data;

  if (!sessionId)                           throw new Error('sessionId is required');
  if (!Array.isArray(friendIds) || friendIds.length === 0) throw new Error('friendIds is required');

  const sandbox = false; // true = sandbox (dev), false = production (App Store)

  // Safety — caller can never be in their own friendIds list,
  // but filter just in case
  const recipientIds = friendIds.filter(id => id !== userId);
  if (recipientIds.length === 0) return { success: true, sent: 0 };

  const db = getDb();

  const rateLimited = await isInviteCooldownActive(db, userId, sessionId);
  if (rateLimited) return { success: true, sent: 0, reason: 'cooldown' };

  // Fetch caller name for the CallKit banner
  const callerDoc  = await db.collection('users').doc(userId).get();
  const callerName = callerDoc.data()?.name ?? 'Someone';

  const memberTokens = await getVoipTokensForUsers(db, recipientIds);

  if (memberTokens.length === 0) {
    return { success: true, sent: 0, reason: 'no_voip_tokens' };
  }

  const { certPem, keyPem } = loadP12Credentials();
  const bundleId            = process.env.APNS_BUNDLE_ID;

  const payload = {
    sessionId,
    callerName,
    callerId: userId,
    action:   'call_invite'
  };

  let sent   = 0;
  let failed = 0;

  await Promise.all(memberTokens.map(async ({ userId: memberId, deviceToken }) => {
    try {
      await sendVoipPush({ deviceToken, payload, bundleId, certPem, keyPem, sandbox });
      sent++;
      logger.info(`sendCallInvite: sent VoIP push to ${memberId}`);
    } catch (err) {
      failed++;
      logger.error(`sendCallInvite: failed for ${memberId}: ${err.message}`);
    }
  }));

  logger.info(`sendCallInvite: ${sent} sent, ${failed} failed for session ${sessionId}`);
  return { success: true, sent, failed };
});


// ─────────────────────────────────────────────────────────────
// sendCallEnded
//
// Called when the last person leaves the call.
// Sends a VoIP push to dismiss the CallKit UI on any devices
// that are still showing the incoming call screen.
//
// Usage from Swift:
//   Functions.functions().httpsCallable("sendCallEnded").call([
//     "sessionId": "abc123",
//     "friendIds": ["uid1", "uid2"]
//   ])
// ─────────────────────────────────────────────────────────────

exports.sendCallEnded = onCall({
  cors: ['*'],
  maxInstances: 50,
  minInstances: 1,
  secrets: [
    'APNS_VOIP_CERT_BASE64',
    'APNS_VOIP_CERT_PASSWORD',
    'APNS_BUNDLE_ID',
    'APNS_TEAM_ID',
  ]
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId = request.auth.uid;
  const { sessionId, friendIds } = request.data;

  if (!sessionId) throw new Error('sessionId is required');

  const sandbox = false; // true = sandbox (dev), false = production (App Store)
  const recipientIds = (friendIds ?? []).filter(id => id !== userId);
  if (recipientIds.length === 0) return { success: true, sent: 0 };

  const db           = getDb();
  const memberTokens = await getVoipTokensForUsers(db, recipientIds);

  if (memberTokens.length === 0) return { success: true, sent: 0 };

  const { certPem, keyPem } = loadP12Credentials();
  const bundleId            = process.env.APNS_BUNDLE_ID;

  const payload = { sessionId, action: 'call_ended' };

  let sent = 0;

  await Promise.all(memberTokens.map(async ({ userId: memberId, deviceToken }) => {
    try {
      await sendVoipPush({ deviceToken, payload, bundleId, certPem, keyPem, sandbox });
      sent++;
    } catch (err) {
      logger.error(`sendCallEnded: failed for ${memberId}: ${err.message}`);
    }
  }));

  return { success: true, sent };
});
