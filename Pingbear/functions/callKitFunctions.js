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
 *
 * NOTE: sandbox = true for development builds.
 * Change to false before submitting to App Store.
 *
 * ─────────────────────────────────────────────────────────────
 * SELF-NOTIFICATION PREVENTION
 * ─────────────────────────────────────────────────────────────
 *
 * The caller is always excluded from the recipient list server-side.
 * This is the primary guard — it means the push is never sent to
 * the caller's device at all, regardless of client-side auth state.
 *
 * A per-caller cooldown (INVITE_COOLDOWN_MS) is also enforced so
 * rapid reconnects (LiveKit drop + rejoin) can't spam the group
 * with repeated CallKit banners.
 *
 * getVoipTokensForMembers already accepts excludeUserId — the
 * caller's uid is passed here explicitly, matching the existing
 * nudge pattern in liveKitFunctions.js.
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

// Cooldown between call invites from the same caller in the same competition.
// Prevents a rapid LiveKit drop+rejoin from ringing everyone's phones twice.
const INVITE_COOLDOWN_MS = 5000; // 5 seconds

// ─────────────────────────────────────────────────────────────
// HELPER — load p12 cert and extract PEM key + cert
// ─────────────────────────────────────────────────────────────

function loadP12Credentials() {
  const base64Cert = process.env.APNS_VOIP_CERT_BASE64;
  const password   = process.env.APNS_VOIP_CERT_PASSWORD;

  if (!base64Cert || !password) {
    throw new Error('APNS credentials not configured');
  }

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

  if (!certPem || !keyPem) {
    throw new Error('Could not extract cert or key from p12');
  }

  return { certPem, keyPem };
}

// ─────────────────────────────────────────────────────────────
// HELPER — send a single VoIP push via APNs HTTP/2
// ─────────────────────────────────────────────────────────────

async function sendVoipPush({ deviceToken, payload, bundleId, certPem, keyPem, sandbox }) {
  const host = sandbox ? APNS_VOIP_HOST_DEV : APNS_VOIP_HOST_PROD;

  return new Promise((resolve, reject) => {
    const client = http2.connect(`https://${host}`, {
      cert: certPem,
      key:  keyPem
    });

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

    req.on('response', (responseHeaders) => {
      responseStatus = responseHeaders[':status'];
    });

    req.on('data', (chunk) => {
      responseData += chunk;
    });

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
// HELPER — fetch VoIP push tokens for competition members
//
// excludeUserId is always the caller — they are excluded here
// server-side so the push is never delivered to their device,
// regardless of what the client-side auth state is at push
// receipt time. This is the primary self-notification guard.
// ─────────────────────────────────────────────────────────────

async function getVoipTokensForMembers(db, competitionId, excludeUserId) {
  const membersSnap = await db
    .collection('competitions').doc(competitionId)
    .collection('members')
    .get();

  const memberIds = membersSnap.docs
    .map(doc => doc.id)
    .filter(id => id !== excludeUserId); // caller always excluded

  if (memberIds.length === 0) return [];

  const chunkSize = 30;
  const tokens    = [];

  for (let i = 0; i < memberIds.length; i += chunkSize) {
    const chunk     = memberIds.slice(i, i + chunkSize);
    const usersSnap = await db.collection('users')
      .where(admin.firestore.FieldPath.documentId(), 'in', chunk)
      .get();

    usersSnap.docs.forEach(doc => {
      const token = doc.data()?.voipPushToken;
      if (token) {
        tokens.push({
          userId:      doc.id,
          deviceToken: token,
          username:    doc.data()?.name ?? 'Someone'
        });
      }
    });
  }

  return tokens;
}

// ─────────────────────────────────────────────────────────────
// HELPER — enforce per-caller invite cooldown
//
// Returns true if the cooldown has not elapsed (caller should
// be rate-limited). Returns false if the invite can proceed,
// and updates the timestamp as a side effect.
//
// Key: call_invite_{callerId}_{competitionId}
// Stored in the rate_limits collection, consistent with
// the pattern used in liveKitFunctions.js (notifyCallJoined).
// ─────────────────────────────────────────────────────────────

async function isInviteCooldownActive(db, callerId, competitionId) {
  const key     = `call_invite_${callerId}_${competitionId}`;
  const ref     = db.collection('rate_limits').doc(key);
  const doc     = await ref.get();

  if (doc.exists) {
    const lastSent = doc.data()?.sent_at?.toMillis() ?? 0;
    if (Date.now() - lastSent < INVITE_COOLDOWN_MS) {
      logger.info(`sendCallInvite: cooldown active for ${callerId} in ${competitionId}`);
      return true;
    }
  }

  // Update timestamp — fire-and-forget, don't block the send
  ref.set({ sent_at: admin.firestore.FieldValue.serverTimestamp() }).catch(err => {
    logger.warn(`sendCallInvite: failed to write cooldown for ${callerId}: ${err.message}`);
  });

  return false;
}

// ─────────────────────────────────────────────────────────────
// sendCallInvite
// ─────────────────────────────────────────────────────────────

exports.sendCallInvite = onCall({
  cors: ['*'],
  maxInstances: 50,
  minInstances: 1,
  secrets: [
    'APNS_VOIP_CERT_BASE64',
    'APNS_VOIP_CERT_PASSWORD',
    'APNS_BUNDLE_ID',
    'APNS_TEAM_ID'
  ]
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId = request.auth.uid;
  const { competitionId, competitionName, roomName } = request.data;

  if (!competitionId) throw new Error('competitionId is required');

  const db = getDb();

  // ── Per-caller cooldown ───────────────────────────────────
  // Suppresses duplicate invites from rapid LiveKit drop+rejoin.
  const rateLimited = await isInviteCooldownActive(db, userId, competitionId);
  if (rateLimited) {
    return { success: true, sent: 0, reason: 'cooldown' };
  }

  const callerDoc  = await db.collection('users').doc(userId).get();
  const callerName = callerDoc.data()?.name ?? 'Someone';

  // ── Fetch tokens, excluding the caller server-side ────────
  // userId (the caller) is passed as excludeUserId so they
  // never receive their own CallKit invite regardless of
  // client-side auth state at push receipt time.
  const memberTokens = await getVoipTokensForMembers(db, competitionId, userId);

  if (memberTokens.length === 0) {
    return { success: true, sent: 0, reason: 'no_voip_tokens' };
  }

  const { certPem, keyPem } = loadP12Credentials();
  const bundleId            = process.env.APNS_BUNDLE_ID;

  // true = sandbox (development builds)
  // Change to false before submitting to App Store
  const sandbox = false

  const payload = {
    competitionId:   competitionId,
    competitionName: competitionName ?? 'Your Competition',
    roomName:        roomName ?? competitionId,
    callerName:      callerName,
    callerId:        userId,
    action:          'call_invite'
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

  logger.info(`sendCallInvite: ${sent} sent, ${failed} failed for competition ${competitionId}`);
  return { success: true, sent, failed };
});

// ─────────────────────────────────────────────────────────────
// sendCallEnded
// ─────────────────────────────────────────────────────────────

exports.sendCallEnded = onCall({
  cors: ['*'],
  maxInstances: 50,
  minInstances: 1,
  secrets: [
    'APNS_VOIP_CERT_BASE64',
    'APNS_VOIP_CERT_PASSWORD',
    'APNS_BUNDLE_ID',
    'APNS_TEAM_ID'
  ]
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId          = request.auth.uid;
  const { competitionId } = request.data;

  if (!competitionId) throw new Error('competitionId is required');

  const db           = getDb();
  const memberTokens = await getVoipTokensForMembers(db, competitionId, userId);

  if (memberTokens.length === 0) {
    return { success: true, sent: 0 };
  }

  const { certPem, keyPem } = loadP12Credentials();
  const bundleId            = process.env.APNS_BUNDLE_ID;

  // true = sandbox (development builds)
  // Change to false before submitting to App Store
  const sandbox = false

  const payload = {
    competitionId: competitionId,
    action:        'call_ended'
  };

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
