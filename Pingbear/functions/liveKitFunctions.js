/**
 * liveKitFunctions.js
 *
 * Cloud Functions for LiveKit voice call integration.
 *
 * Add to index.js:
 *   const livekit = require('./liveKitFunctions');
 *   exports.getLiveKitToken  = livekit.getLiveKitToken;
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
 * One LiveKit room per session.
 * Room name = sessionId — simple and collision-free.
 * LiveKit creates the room automatically on first join.
 * Room closes automatically when last participant leaves.
 *
 * ─────────────────────────────────────────────────────────────
 * TOKEN MODEL
 * ─────────────────────────────────────────────────────────────
 *
 * Each user gets a signed JWT granting access to their session's
 * room. Token valid for 24 hours. Identity = userId.
 * Metadata = JSON with username and profilePictureUrl so the
 * Swift client can display participant info without extra reads.
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
// Called from Swift when a user answers a call or starts one.
// Verifies session participation then returns a signed LiveKit JWT.
//
// Usage from Swift:
//   Functions.functions().httpsCallable("getLiveKitToken").call([
//     "sessionId": "abc123"
//   ])
//
// Returns:
//   { token: "eyJ...", url: "wss://...", roomName: "abc123" }
// ─────────────────────────────────────────────────────────────

exports.getLiveKitToken = onCall({
  cors: ['*'],
  maxInstances: 50,
  minInstances: 1,
  secrets: ['LIVEKIT_API_KEY', 'LIVEKIT_API_SECRET', 'LIVEKIT_URL']
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId      = request.auth.uid;
  const { sessionId } = request.data;

  if (!sessionId) throw new Error('sessionId is required');

  const db = getDb();

  // Verify session participation
  const sessionDoc = await db.collection('sessions').doc(sessionId).get();
  if (!sessionDoc.exists) throw new Error('Session not found');

  const participantIds = sessionDoc.data().participant_ids ?? [];
  if (!participantIds.includes(userId)) {
    throw new Error('You are not a participant in this session');
  }

  // Fetch user profile for metadata
  const userDoc  = await db.collection('users').doc(userId).get();
  const userData = userDoc.data() ?? {};
  const username = userData.name             ?? 'Unknown';
  const photoUrl = userData.profilePictureUrl ?? null;

  // Build LiveKit access token
  const apiKey    = process.env.LIVEKIT_API_KEY;
  const apiSecret = process.env.LIVEKIT_API_SECRET;
  const lkUrl     = process.env.LIVEKIT_URL;

  if (!apiKey || !apiSecret || !lkUrl) {
    throw new Error('LiveKit credentials not configured');
  }

  const roomName = sessionId; // one room per session

  const token = new AccessToken(apiKey, apiSecret, {
    identity: userId,
    ttl:      '24h',
    metadata: JSON.stringify({ username, profilePictureUrl: photoUrl })
  });

  token.addGrant({
    roomJoin:       true,
    room:           roomName,
    canPublish:     true,
    canSubscribe:   true,
    canPublishData: true
  });

  const jwt = await token.toJwt();

  logger.info(`getLiveKitToken: token issued for ${userId} in room ${roomName}`);

  return { token: jwt, url: lkUrl, roomName };
});
