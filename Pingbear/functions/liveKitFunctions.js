/**
 * liveKitFunctions.js
 *
 * Cloud Functions for LiveKit voice call integration.
 *
 * Add to index.js:
 *   const livekit = require('./liveKitFunctions');
 *   exports.getLiveKitToken    = livekit.getLiveKitToken;
 *   exports.notifyCallJoined   = livekit.notifyCallJoined;
 *
 * Secrets required:
 *   LIVEKIT_API_KEY     — set via: firebase functions:secrets:set LIVEKIT_API_KEY
 *   LIVEKIT_API_SECRET  — set via: firebase functions:secrets:set LIVEKIT_API_SECRET
 *   LIVEKIT_URL         — set via: firebase functions:secrets:set LIVEKIT_URL
 *
 * ─────────────────────────────────────────────────────────────
 * ROOM MODEL
 * ─────────────────────────────────────────────────────────────
 *
 * One persistent voice room per competition.
 * Room name = competitionId — simple and collision-free.
 * LiveKit creates the room automatically on first participant join.
 * Room closes automatically when last participant leaves.
 * No room management needed server-side.
 *
 * ─────────────────────────────────────────────────────────────
 * TOKEN MODEL
 * ─────────────────────────────────────────────────────────────
 *
 * Each user gets a signed JWT granting them access to their
 * competition's room. Token is valid for 24 hours.
 * Identity = userId so participants are identifiable.
 * Metadata = JSON with username and profilePictureUrl so
 * the Swift client can display participant info without
 * extra Firestore reads.
 */

const { onCall } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const logger = require('firebase-functions/logger');
const { AccessToken } = require('livekit-server-sdk');

let _db;
const getDb = () => {
  if (!_db) _db = admin.firestore();
  return _db;
};

// ─────────────────────────────────────────────────────────────
// getLiveKitToken
//
// Called from Swift when a user wants to join a competition
// voice room. Verifies competition membership then returns
// a signed LiveKit JWT.
//
// Usage from Swift:
//   Functions.functions().httpsCallable("getLiveKitToken").call([
//     "competitionId": "comp_abc123"
//   ])
//
// Returns:
//   { token: "eyJ...", url: "wss://...", roomName: "comp_abc123" }
// ─────────────────────────────────────────────────────────────

exports.getLiveKitToken = onCall({
  cors: ['*'],
  maxInstances: 50,
  minInstances: 1,
  secrets: ['LIVEKIT_API_KEY', 'LIVEKIT_API_SECRET', 'LIVEKIT_URL']
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId        = request.auth.uid;
  const { competitionId } = request.data;

  if (!competitionId) throw new Error('competitionId is required');

  const db = getDb();

  // Verify membership
  const memberDoc = await db
    .collection('competitions').doc(competitionId)
    .collection('members').doc(userId)
    .get();

  if (!memberDoc.exists) {
    throw new Error('You are not a member of this competition');
  }

  // Fetch user profile for metadata
  const userDoc  = await db.collection('users').doc(userId).get();
  const userData = userDoc.data() ?? {};
  const username = userData.name            ?? 'Unknown';
  const photoUrl = userData.profilePictureUrl ?? null;

  // Build LiveKit access token
  const apiKey    = process.env.LIVEKIT_API_KEY;
  const apiSecret = process.env.LIVEKIT_API_SECRET;
  const lkUrl     = process.env.LIVEKIT_URL;

  if (!apiKey || !apiSecret || !lkUrl) {
    throw new Error('LiveKit credentials not configured');
  }

  const roomName = competitionId; // one room per competition

  const token = new AccessToken(apiKey, apiSecret, {
    identity: userId,
    ttl:      '24h',
    // Metadata is available to all participants in the room
    // Swift client reads this to show name and avatar
    metadata: JSON.stringify({
      username,
      profilePictureUrl: photoUrl
    })
  });

  token.addGrant({
    roomJoin:     true,
    room:         roomName,
    canPublish:   true,   // can send audio
    canSubscribe: true,   // can receive audio
    canPublishData: true  // can send data messages if needed later
  });

  const jwt = await token.toJwt();

  logger.info(`getLiveKitToken: token issued for ${userId} in room ${roomName}`);

  return {
    token:    jwt,
    url:      lkUrl,
    roomName: roomName
  };
});


// ─────────────────────────────────────────────────────────────
// notifyCallJoined
//
// Called from Swift when a user joins a competition voice call.
// Sends a push notification to all other competition members
// who have an FCM token.
//
// Rate limited — one notification per user per competition
// per 5 minutes to avoid spam if they disconnect and reconnect.
//
// Usage from Swift:
//   Functions.functions().httpsCallable("notifyCallJoined").call([
//     "competitionId":   "comp_abc123",
//     "competitionName": "The Lads 📸"
//   ])
// ─────────────────────────────────────────────────────────────

exports.notifyCallJoined = onCall({
  cors: ['*'],
  maxInstances: 50,
  minInstances: 1
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId = request.auth.uid;
  const { competitionId, competitionName } = request.data;

  if (!competitionId) throw new Error('competitionId is required');

  const db = getDb();

  // ── Rate limit — 5 minutes per user per competition ───────
  const rateLimitKey  = `call_joined_${userId}_${competitionId}`;
  const rateLimitRef  = db.collection('rate_limits').doc(rateLimitKey);
  const rateLimitDoc  = await rateLimitRef.get();
  const COOLDOWN_MS   = 5 * 60 * 1000;

  if (rateLimitDoc.exists) {
    const lastSent = rateLimitDoc.data()?.sent_at?.toMillis() ?? 0;
    if (Date.now() - lastSent < COOLDOWN_MS) {
      logger.info(`notifyCallJoined: rate limited for ${userId} in ${competitionId}`);
      return { success: true, sent: 0, reason: 'rate_limited' };
    }
  }

  // Update rate limit timestamp
  await rateLimitRef.set({
    sent_at: admin.firestore.FieldValue.serverTimestamp()
  });

  // ── Fetch joining user's name ─────────────────────────────
  const joiningUserDoc  = await db.collection('users').doc(userId).get();
  const joiningUserName = joiningUserDoc.data()?.name ?? 'Someone';

  // ── Fetch all competition members except the caller ───────
  const membersSnap = await db
    .collection('competitions').doc(competitionId)
    .collection('members')
    .get();

  const memberIds = membersSnap.docs
    .map(doc => doc.id)
    .filter(id => id !== userId);

  if (memberIds.length === 0) {
    return { success: true, sent: 0 };
  }

  // ── Batch fetch FCM tokens ────────────────────────────────
  const chunkSize = 30;
  const chunks    = [];
  for (let i = 0; i < memberIds.length; i += chunkSize) {
    chunks.push(memberIds.slice(i, i + chunkSize));
  }

  const fcmTokens = [];
  for (const chunk of chunks) {
    const usersSnap = await db.collection('users')
      .where(admin.firestore.FieldPath.documentId(), 'in', chunk)
      .get();

    usersSnap.docs.forEach(doc => {
      const token = doc.data()?.fcmToken;
      if (token) fcmTokens.push(token);
    });
  }

  if (fcmTokens.length === 0) {
    logger.info(`notifyCallJoined: no FCM tokens for competition ${competitionId}`);
    return { success: true, sent: 0 };
  }

  // ── Send notifications ────────────────────────────────────
  const compName = competitionName ?? 'your competition';

  const batchResponse = await admin.messaging().sendEachForMulticast({
    notification: {
      title: `${joiningUserName} joined the call 📞`,
      body:  `Hop on in ${compName}`
    },
    data: {
      type:          'call_joined',
      competitionId: competitionId
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
          badge: 1
        }
      }
    },
    tokens: fcmTokens
  });

  logger.info(`notifyCallJoined: sent ${batchResponse.successCount}/${fcmTokens.length} for competition ${competitionId}`);

  return {
    success: true,
    sent:    batchResponse.successCount,
    failed:  batchResponse.failureCount
  };
});
