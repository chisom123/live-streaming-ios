/**
 * streamFunctions.js
 *
 * VoIP push uses APNs HTTP/2 with JWT auth (.p8 key — never expires).
 *
 * SECRETS REQUIRED
 * ────────────────
 * APNS_KEY_ID      – 10-char key ID  (T7J7CTZU6W)
 * APNS_TEAM_ID     – 10-char team ID (27J5KH92LA)
 * APNS_PRIVATE_KEY – full contents of AuthKey_T7J7CTZU6W.p8
 * APNS_BUNDLE_ID   – com.pordio.Chay
 */

const { onCall }    = require('firebase-functions/v2/https');
const { onRequest } = require('firebase-functions/v2/https');
const admin         = require('firebase-admin');
const logger        = require('firebase-functions/logger');
const http2        = require('http2');
const crypto        = require('crypto');
const {
  AccessToken, EgressClient, EncodedFileOutput,
  GCPUpload, WebhookReceiver
} = require('livekit-server-sdk');
const { round2, splitDebit } = require('./walletHelpers');

let _db;
const getDb = () => { if (!_db) _db = admin.firestore(); return _db; };

const PLATFORM_FEE_RATE  = 0.20;
const MIN_PRICE          = 0.50;
const MAX_PRICE          = 50.00;
const LIVEKIT_API_KEY    = process.env.LIVEKIT_API_KEY;
const LIVEKIT_API_SECRET = process.env.LIVEKIT_API_SECRET;
const LIVEKIT_WS_URL     = process.env.LIVEKIT_WS_URL;
const RECORDING_ENABLED  = process.env.RECORDING_ENABLED === 'true';
const GCS_BUCKET         = process.env.GCS_BUCKET;
const GCS_CREDENTIALS    = process.env.GCS_CREDENTIALS;

// APNs VoIP — .p8 JWT approach
const APNS_KEY_ID      = process.env.APNS_KEY_ID;
const APNS_TEAM_ID     = process.env.APNS_TEAM_ID;
const APNS_PRIVATE_KEY = process.env.APNS_PRIVATE_KEY;
const APNS_BUNDLE_ID   = process.env.APNS_BUNDLE_ID;

// ─────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────

function calcFees(price) {
  const platformFee   = round2(price * PLATFORM_FEE_RATE);
  const creatorPayout = round2(price - platformFee);
  return { platformFee, creatorPayout };
}

function makeLivekitToken({ identity, name, roomName, canPublish, canSubscribe }) {
  const at = new AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET, { identity, name, ttl: '4h' });
  at.addGrant({ roomJoin: true, room: roomName, canPublish, canSubscribe });
  return at.toJwt();
}

function makeEgressClient() {
  return new EgressClient(LIVEKIT_WS_URL, LIVEKIT_API_KEY, LIVEKIT_API_SECRET);
}

async function sendPush(db, userIds, { title, body, data = {} }) {
  if (!userIds?.length) return;
  const tokens = [];
  const chunks = [];
  for (let i = 0; i < userIds.length; i += 30) chunks.push(userIds.slice(i, i + 30));
  for (const chunk of chunks) {
    const snap = await db.collection('users')
      .where(admin.firestore.FieldPath.documentId(), 'in', chunk)
      .get();
    snap.docs.forEach(doc => { const t = doc.data()?.fcmToken; if (t) tokens.push(t); });
  }
  await Promise.all(tokens.map(token =>
    admin.messaging().send({
      token,
      notification: { title, body },
      data,
      apns: { payload: { aps: { sound: 'default', badge: 1 } } }
    }).catch(err => logger.warn(`sendPush failed: ${err.message}`))
  ));
}

async function getUserInfo(db, userId) {
  const doc  = await db.collection('users').doc(userId).get();
  const data = doc.data();
  return { name: data?.name ?? 'Someone', avatarUrl: data?.profilePictureUrl ?? null };
}

// ─────────────────────────────────────────────────────────────
// APNs VoIP push — JWT / .p8 approach
// ─────────────────────────────────────────────────────────────

/**
 * Generates a signed ES256 JWT for APNs authentication.
 * Valid for 60 minutes — fine for our use case since we create
 * one per function invocation and Cloud Functions are short-lived.
 */
function makeApnsJwt() {
  const header  = Buffer.from(JSON.stringify({ alg: 'ES256', kid: APNS_KEY_ID })).toString('base64url');
  const now     = Math.floor(Date.now() / 1000);
  const payload = Buffer.from(JSON.stringify({ iss: APNS_TEAM_ID, iat: now })).toString('base64url');
  const unsigned = `${header}.${payload}`;

  // Normalise any literal \n in the env var to real newlines
  const pem  = APNS_PRIVATE_KEY.replace(/\\n/g, '\n');
  const sign = crypto.createSign('SHA256');
  sign.update(unsigned);
  const sig = sign.sign({ key: pem, dsaEncoding: 'ieee-p1363' }, 'base64url');
  return `${unsigned}.${sig}`;
}

/**
 * Sends a single APNs VoIP push using HTTP/2 (required by APNs).
 * Node's built-in http2 module is used directly — no extra packages needed.
 */
function sendApnsVoipPush(deviceToken, payload) {
  return new Promise((resolve, reject) => {
    const jwt    = makeApnsJwt();
    const body   = JSON.stringify(payload);
    const host   = 'api.push.apple.com'; // switch to api.push.apple.com for production

    const client = http2.connect(`https://${host}`);

    client.on('error', (err) => {
      reject(err);
      client.destroy();
    });

    const req = client.request({
      ':method':         'POST',
      ':path':           `/3/device/${deviceToken}`,
      ':scheme':         'https',
      ':authority':      host,
      'authorization':   `bearer ${jwt}`,
      'apns-topic':      `${APNS_BUNDLE_ID}.voip`,
      'apns-push-type':  'voip',
      'apns-priority':   '10',
      'apns-expiration': '0',
      'content-type':    'application/json',
      'content-length':  Buffer.byteLength(body)
    });

    req.write(body);
    req.end();

    let status;
    let data = '';

    req.on('response', (headers) => {
      status = headers[':status'];
    });

    req.on('data', (chunk) => { data += chunk; });

    req.on('end', () => {
      client.close();
      if (status !== 200) {
        logger.warn(`APNs VoIP push failed: ${status} ${data} token=...${deviceToken.slice(-8)}`);
      }
      resolve(status);
    });

    req.on('error', (err) => {
      client.destroy();
      reject(err);
    });
  });
}

/**
 * Fetches voipTokens for the given user IDs and sends VoIP pushes.
 * Silently skips users with no voipToken (Android / not yet registered).
 */
async function sendVoIPPush(db, userIds, { streamId, streamerId, streamerName }) {
  if (!userIds?.length) return;

  const tokenMap = {};
  const chunks   = [];
  for (let i = 0; i < userIds.length; i += 30) chunks.push(userIds.slice(i, i + 30));

  for (const chunk of chunks) {
    const snap = await db.collection('users')
      .where(admin.firestore.FieldPath.documentId(), 'in', chunk)
      .get();
    snap.docs.forEach(doc => {
      const token = doc.data()?.voipToken;
      if (token) tokenMap[doc.id] = token;
    });
  }

  const voipPayload = {
    aps:           {},           // required by APNs even for VoIP
    stream_id:     streamId,
    streamer_id:   streamerId,
    streamer_name: streamerName
  };

  await Promise.all(
    Object.values(tokenMap).map(token =>
      sendApnsVoipPush(token, voipPayload)
        .catch(err => logger.warn(`sendVoIPPush error: ${err.message}`))
    )
  );

  logger.info(`sendVoIPPush: sent to ${Object.keys(tokenMap).length}/${userIds.length} users for stream ${streamId}`);
}

// ─────────────────────────────────────────────────────────────
// HELPERS: refundStreamRequest, payStreamer
// ─────────────────────────────────────────────────────────────

async function refundStreamRequest(db, requestId) {
  const ref  = db.collection('stream_requests').doc(requestId);
  const snap = await ref.get();
  if (!snap.exists) return;
  const req = snap.data();
  if (['completed', 'declined', 'refunded'].includes(req.status)) return;

  const bonusPortion = req.funded_bonus_amount ?? 0;
  const realPortion  = req.funded_real_amount  ?? req.price;
  const refundAmount = round2(bonusPortion + realPortion);

  await db.runTransaction(async (t) => {
    const userRef  = db.collection('users').doc(req.from_user_id);
    const userDoc  = await t.get(userRef);
    const balance  = userDoc.data()?.wallet_balance ?? 0;
    const newBal   = round2(balance + refundAmount);
    t.set(userRef, {
      wallet_balance: admin.firestore.FieldValue.increment(refundAmount),
      bonus_balance:  admin.firestore.FieldValue.increment(bonusPortion)
    }, { merge: true });
    t.update(ref, { status: 'refunded' });
    const txRef = db.collection('wallet_transactions').doc();
    t.set(txRef, {
      user_id: req.from_user_id, type: 'credit', amount: refundAmount,
      reason: 'stream_request_refund', session_id: requestId,
      metadata: { stream_id: req.stream_id, refund_reason: 'stream_ended', bonus_restored: bonusPortion, real_restored: realPortion },
      balance_before: balance, balance_after: newBal,
      created_at: admin.firestore.FieldValue.serverTimestamp()
    });
  });
}

async function payStreamer(db, { requestId, streamerId, fromUserId, price, bonusFundedAmount, realFundedAmount }) {
  const { platformFee, creatorPayout } = calcFees(price);
  const realFunded = realFundedAmount ?? round2(price - bonusFundedAmount);
  const realFee    = price > 0 ? round2(platformFee * (realFunded / price)) : 0;

  await db.runTransaction(async (t) => {
    const streamerRef = db.collection('users').doc(streamerId);
    const streamerDoc = await t.get(streamerRef);
    const bal         = streamerDoc.data()?.wallet_balance ?? 0;
    const newBal      = round2(bal + creatorPayout);
    t.set(streamerRef, {
      wallet_balance: admin.firestore.FieldValue.increment(creatorPayout),
      totalEarned:    admin.firestore.FieldValue.increment(creatorPayout)
    }, { merge: true });
    const txRef = db.collection('wallet_transactions').doc();
    t.set(txRef, {
      user_id: streamerId, type: 'credit', amount: creatorPayout,
      reason: 'stream_request_payout', session_id: requestId,
      metadata: { gross_amount: price, platform_fee: platformFee, transaction_type: 'stream_request', funded_by_bonus: bonusFundedAmount, funded_by_real: realFunded },
      balance_before: bal, balance_after: newBal,
      created_at: admin.firestore.FieldValue.serverTimestamp()
    });
  });

  await db.collection('platform_revenue').doc().set({
    transaction_id: requestId, from_user_id: fromUserId, to_user_id: streamerId,
    type: 'stream_request', gross_amount: price, platform_fee: platformFee,
    creator_payout: creatorPayout, bonus_funded_amount: bonusFundedAmount,
    real_funded_amount: realFunded, real_revenue_fee: realFee,
    collected_at: admin.firestore.FieldValue.serverTimestamp()
  });
}

// ─────────────────────────────────────────────────────────────
// createStream
// ─────────────────────────────────────────────────────────────

exports.createStream = onCall({
  cors: ['*'], maxInstances: 50,
  secrets: [
    'LIVEKIT_API_KEY', 'LIVEKIT_API_SECRET', 'LIVEKIT_WS_URL',
    'APNS_KEY_ID', 'APNS_TEAM_ID', 'APNS_PRIVATE_KEY', 'APNS_BUNDLE_ID'
  ]
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId = request.auth.uid;
  const { onAppInvitedIds = [], offAppPhoneHashes = [], offAppInviteeNames = {} } = request.data;

  const db           = getDb();
  const roomName     = `stream_${Date.now()}_${userId}`;
  const streamRef    = db.collection('streams').doc();
  const streamerDoc  = await db.collection('users').doc(userId).get();
  const streamerName = streamerDoc.data()?.name ?? 'Someone';
  const streamerImageUrl = streamerDoc.data()?.profilePictureUrl ?? null;
  const inviterHash  = streamerDoc.data()?.phoneNumberHash ?? '';

  const validOnApp  = onAppInvitedIds.filter(id => id !== userId);
  const validOffApp = [...new Set(offAppPhoneHashes)];

  await streamRef.set({
    streamer_id:        userId,
    streamer_name:      streamerName,
    streamer_image_url: streamerImageUrl,
    status:             'live',
    started_at:         admin.firestore.FieldValue.serverTimestamp(),
    ended_at:           null,
    livekit_room_name:  roomName,
    viewer_ids:         [],
    invited_user_ids:   [userId, ...validOnApp],
    total_earned:       0,
    request_count:      0,
    egress_id:          null,
    created_at:         admin.firestore.FieldValue.serverTimestamp()
  });

  for (const phoneHash of validOffApp) {
    const allHashes = [phoneHash];
    if (inviterHash) allHashes.push(inviterHash);
    await db.collection('invite_groups').doc().set({
      memberHashes:        allHashes,
      memberUserIds:       inviterHash ? { [inviterHash]: userId } : {},
      stream_id:           streamRef.id,
      pending_stream_name: streamerName,
      createdAt:           admin.firestore.FieldValue.serverTimestamp()
    });
  }

  if (validOnApp.length > 0) {
    // VoIP push — full-screen incoming call UI (iOS only)
    await sendVoIPPush(db, validOnApp, {
      streamId:     streamRef.id,
      streamerId:   userId,
      streamerName
    });

    // FCM push — fallback for Android + users without a voipToken
    await sendPush(db, validOnApp, {
      title: `${streamerName} is live now!`,
      body:  'Tap to join',
      data:  { type: 'stream_live', stream_id: streamRef.id }
    });
  }

  const token = await makeLivekitToken({
    identity: userId, name: streamerName, roomName,
    canPublish: true, canSubscribe: false
  });

  logger.info(`createStream: ${userId} created stream ${streamRef.id}`);
  return { success: true, streamId: streamRef.id, livekitUrl: LIVEKIT_WS_URL, token };
});

// ─────────────────────────────────────────────────────────────
// endStream
// ─────────────────────────────────────────────────────────────

exports.endStream = onCall({
  cors: ['*'], maxInstances: 20,
  secrets: ['LIVEKIT_API_KEY', 'LIVEKIT_API_SECRET', 'LIVEKIT_WS_URL', 'RECORDING_ENABLED']
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');
  const userId = request.auth.uid;
  const { streamId } = request.data;
  if (!streamId) throw new Error('streamId is required');
  const db   = getDb();
  const ref  = db.collection('streams').doc(streamId);
  const snap = await ref.get();
  if (!snap.exists) throw new Error('Stream not found');
  const stream = snap.data();
  if (stream.streamer_id !== userId) throw new Error('Not the streamer');
  if (stream.status !== 'live')      throw new Error('Stream is not live');
  await ref.update({ status: 'ended', ended_at: admin.firestore.FieldValue.serverTimestamp(), viewer_ids: [] });
  if (RECORDING_ENABLED && stream.egress_id) {
    try { await makeEgressClient().stopEgress(stream.egress_id); }
    catch (err) { logger.warn(`endStream: failed to stop recording: ${err.message}`); }
  }
  const openRequests = await db.collection('stream_requests')
    .where('stream_id', '==', streamId).where('status', 'in', ['pending', 'accepted']).get();
  await Promise.all(openRequests.docs.map(doc => refundStreamRequest(db, doc.id)));
  if (openRequests.size > 0) {
    const viewerIds = [...new Set(openRequests.docs.map(d => d.data().from_user_id))];
    await sendPush(db, viewerIds, {
      title: 'Your request was refunded',
      body:  `${stream.streamer_name} ended the stream — your money is back`,
      data:  { type: 'stream_request_refunded', stream_id: streamId }
    });
  }
  logger.info(`endStream: ${userId} ended ${streamId}`);
  return { success: true };
});

// ─────────────────────────────────────────────────────────────
// joinStream
// ─────────────────────────────────────────────────────────────

exports.joinStream = onCall({
  cors: ['*'], maxInstances: 100,
  secrets: ['LIVEKIT_API_KEY', 'LIVEKIT_API_SECRET', 'LIVEKIT_WS_URL']
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');
  const userId = request.auth.uid;
  const { streamId } = request.data;
  if (!streamId) throw new Error('streamId is required');
  const db   = getDb();
  const ref  = db.collection('streams').doc(streamId);
  const snap = await ref.get();
  if (!snap.exists) throw new Error('Stream not found');
  const stream = snap.data();
  if (stream.status !== 'live') throw new Error('Stream is not live');
  const isInvited = (stream.invited_user_ids ?? []).includes(userId)
                 || (stream.viewer_ids ?? []).includes(userId)
                 || stream.streamer_id === userId;
  if (!isInvited) throw new Error('You are not invited to this stream');
  const userInfo    = await getUserInfo(db, userId);
  const alreadySeen = (stream.viewer_ids ?? []).includes(userId);
  if (!alreadySeen && stream.streamer_id !== userId) {
    await db.collection('stream_chat').doc(streamId).collection('messages').doc().set({
      user_id: userId, name: userInfo.name, avatar_url: userInfo.avatarUrl,
      text: `${userInfo.name} joined`, type: 'join_event', request_id: null,
      created_at: admin.firestore.FieldValue.serverTimestamp()
    });
    await sendPush(db, [stream.streamer_id], {
      title: `${userInfo.name} joined your stream`, body: 'Someone just tuned in',
      data:  { type: 'stream_viewer_joined', stream_id: streamId }
    });
  }
  const token = await makeLivekitToken({
    identity: userId, name: userInfo.name, roomName: stream.livekit_room_name,
    canPublish: false, canSubscribe: true
  });
  logger.info(`joinStream: ${userId} joined ${streamId}`);
  return { success: true, livekitUrl: LIVEKIT_WS_URL, token };
});

// ─────────────────────────────────────────────────────────────
// sendStreamRequest
// ─────────────────────────────────────────────────────────────

exports.sendStreamRequest = onCall({ cors: ['*'], maxInstances: 100 }, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');
  const userId = request.auth.uid;
  const { streamId, description, price } = request.data;
  if (!streamId)            throw new Error('streamId is required');
  if (!description?.trim()) throw new Error('Description is required');
  if (description.trim().length > 120) throw new Error('Description max 120 chars');
  if (!price || price < MIN_PRICE || price > MAX_PRICE)
    throw new Error(`Price must be between $${MIN_PRICE} and $${MAX_PRICE}`);
  const db = getDb();
  const streamSnap = await db.collection('streams').doc(streamId).get();
  if (!streamSnap.exists) throw new Error('Stream not found');
  const stream = streamSnap.data();
  if (stream.status !== 'live') throw new Error('Stream is not live');
  if (stream.streamer_id === userId) throw new Error('Streamer cannot send requests to themselves');
  const { platformFee, creatorPayout } = calcFees(price);
  let bonusUsed = 0, realUsed = 0;
  await db.runTransaction(async (t) => {
    const userRef  = db.collection('users').doc(userId);
    const userDoc  = await t.get(userRef);
    const balance  = userDoc.data()?.wallet_balance ?? 0;
    const bonus    = userDoc.data()?.bonus_balance  ?? 0;
    if (balance < price) throw new Error('Insufficient funds');
    const split = splitDebit(bonus, price);
    bonusUsed = split.bonusUsed; realUsed = split.realUsed;
    t.set(userRef, {
      wallet_balance: admin.firestore.FieldValue.increment(-price),
      bonus_balance:  admin.firestore.FieldValue.increment(-bonusUsed)
    }, { merge: true });
    const txRef = db.collection('wallet_transactions').doc();
    t.set(txRef, {
      user_id: userId, type: 'debit', amount: price, reason: 'stream_request_escrow',
      session_id: null, metadata: { stream_id: streamId, bonus_used: bonusUsed, real_used: realUsed },
      balance_before: balance, balance_after: round2(balance - price),
      created_at: admin.firestore.FieldValue.serverTimestamp()
    });
  });
  const requestRef   = db.collection('stream_requests').doc();
  const fromUserInfo = await getUserInfo(db, userId);
  await requestRef.set({
    stream_id: streamId, from_user_id: userId, from_user_name: fromUserInfo.name,
    from_user_image_url: fromUserInfo.avatarUrl, streamer_id: stream.streamer_id,
    description: description.trim(), price, platform_fee: platformFee,
    creator_payout: creatorPayout, status: 'pending',
    funded_bonus_amount: bonusUsed, funded_real_amount: realUsed,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
    accepted_at: null, completed_at: null
  });
  await db.collection('streams').doc(streamId).update({ request_count: admin.firestore.FieldValue.increment(1) });
  await db.collection('stream_chat').doc(streamId).collection('messages').doc().set({
    user_id: userId, name: fromUserInfo.name, avatar_url: fromUserInfo.avatarUrl,
    text: `${description.trim()} · $${price.toFixed(2)}`, type: 'request_event',
    request_id: requestRef.id, created_at: admin.firestore.FieldValue.serverTimestamp()
  });
  await sendPush(db, [stream.streamer_id], {
    title: `${fromUserInfo.name} wants: "${description.trim().slice(0, 50)}"`,
    body:  `$${price.toFixed(2)} — tap to respond`,
    data:  { type: 'stream_request_received', request_id: requestRef.id, stream_id: streamId }
  });
  logger.info(`sendStreamRequest: ${userId} → ${stream.streamer_id}, $${price}`);
  return { success: true, requestId: requestRef.id };
});

// ─────────────────────────────────────────────────────────────
// respondToStreamRequest
// ─────────────────────────────────────────────────────────────

exports.respondToStreamRequest = onCall({ cors: ['*'], maxInstances: 100 }, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');
  const userId = request.auth.uid;
  const { requestId, accept } = request.data;
  if (!requestId) throw new Error('requestId is required');
  if (typeof accept !== 'boolean') throw new Error('accept must be boolean');
  const db  = getDb();
  const ref = db.collection('stream_requests').doc(requestId);
  const snap = await ref.get();
  if (!snap.exists) throw new Error('Request not found');
  const req = snap.data();
  if (req.streamer_id !== userId) throw new Error('Not the streamer');
  if (req.status !== 'pending')   throw new Error(`Cannot respond to status: ${req.status}`);
  const streamSnap = await db.collection('streams').doc(req.stream_id).get();
  if (!streamSnap.exists || streamSnap.data().status !== 'live') throw new Error('Stream is no longer live');
  if (!accept) {
    await refundStreamRequest(db, requestId);
    const { name: streamerName } = await getUserInfo(db, userId);
    await sendPush(db, [req.from_user_id], {
      title: `${streamerName} declined your request`, body: 'Your money has been refunded',
      data: { type: 'stream_request_refunded', request_id: requestId, stream_id: req.stream_id }
    });
    return { success: true };
  }
  await ref.update({ status: 'accepted', accepted_at: admin.firestore.FieldValue.serverTimestamp() });
  const { name: streamerName } = await getUserInfo(db, userId);
  await sendPush(db, [req.from_user_id], {
    title: `${streamerName} accepted your request!`,
    body:  `"${req.description.slice(0, 60)}" — they're on it`,
    data:  { type: 'stream_request_accepted', request_id: requestId, stream_id: req.stream_id }
  });
  return { success: true };
});

// ─────────────────────────────────────────────────────────────
// completeStreamRequest
// ─────────────────────────────────────────────────────────────

exports.completeStreamRequest = onCall({ cors: ['*'], maxInstances: 100 }, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');
  const userId = request.auth.uid;
  const { requestId } = request.data;
  if (!requestId) throw new Error('requestId is required');
  const db  = getDb();
  const ref = db.collection('stream_requests').doc(requestId);
  const snap = await ref.get();
  if (!snap.exists) throw new Error('Request not found');
  const req = snap.data();
  if (req.streamer_id !== userId) throw new Error('Not the streamer');
  if (req.status !== 'accepted')  throw new Error(`Cannot complete status: ${req.status}`);
  await ref.update({ status: 'completed', completed_at: admin.firestore.FieldValue.serverTimestamp() });
  await payStreamer(db, {
    requestId, streamerId: userId, fromUserId: req.from_user_id,
    price: req.price, bonusFundedAmount: req.funded_bonus_amount ?? 0,
    realFundedAmount: req.funded_real_amount ?? req.price
  });
  await db.collection('streams').doc(req.stream_id).update({ total_earned: admin.firestore.FieldValue.increment(req.creator_payout) });
  const { name: streamerName } = await getUserInfo(db, userId);
  await sendPush(db, [req.from_user_id], {
    title: `${streamerName} completed your request!`,
    body:  `"${req.description.slice(0, 60)}"`,
    data:  { type: 'stream_request_completed', request_id: requestId, stream_id: req.stream_id }
  });
  return { success: true };
});

// ─────────────────────────────────────────────────────────────
// startStreamRecording
// ─────────────────────────────────────────────────────────────

exports.startStreamRecording = onCall({
  cors: ['*'], maxInstances: 50,
  secrets: ['LIVEKIT_API_KEY', 'LIVEKIT_API_SECRET', 'LIVEKIT_WS_URL', 'RECORDING_ENABLED', 'GCS_BUCKET', 'GCS_CREDENTIALS']
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');
  const userId = request.auth.uid;
  const { streamId } = request.data;
  if (!streamId) throw new Error('streamId is required');
  if (!RECORDING_ENABLED) return { success: true, skipped: true };
  const db  = getDb();
  const ref = db.collection('streams').doc(streamId);
  const snap = await ref.get();
  if (!snap.exists) throw new Error('Stream not found');
  const stream = snap.data();
  if (stream.streamer_id !== userId) throw new Error('Not the streamer');
  if (stream.status !== 'live') throw new Error('Stream is not live');
  if (stream.egress_id) return { success: true, skipped: true };
  try {
    const egressClient = makeEgressClient();
    const egress = await egressClient.startRoomCompositeEgress(stream.livekit_room_name, {
      file: new EncodedFileOutput({
        filepath: `recordings/${streamId}.mp4`,
        output: { case: 'gcp', value: new GCPUpload({ credentials: GCS_CREDENTIALS, bucket: GCS_BUCKET }) }
      })
    });
    await ref.update({ egress_id: egress.egressId });
    return { success: true, skipped: false };
  } catch (err) {
    throw new Error(`Failed to start recording: ${err.message}`);
  }
});

// ─────────────────────────────────────────────────────────────
// resolveInviteStream
// ─────────────────────────────────────────────────────────────

exports.resolveInviteStream = onCall({ cors: ['*'], maxInstances: 50 }, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');
  const userId = request.auth.uid;
  const { streamId } = request.data;
  if (!streamId) throw new Error('streamId is required');
  const db  = getDb();
  const ref = db.collection('streams').doc(streamId);
  const snap = await ref.get();
  if (!snap.exists) return { success: true, skipped: true };
  const stream = snap.data();
  if (stream.status !== 'live') return { success: true, skipped: true };
  await ref.update({ invited_user_ids: admin.firestore.FieldValue.arrayUnion(userId) });
  return { success: true, skipped: false };
});

// ─────────────────────────────────────────────────────────────
// livekitWebhook
// ─────────────────────────────────────────────────────────────

exports.livekitWebhook = onRequest({
  cors: false, maxInstances: 50, rawBody: true,
  secrets: ['LIVEKIT_API_KEY', 'LIVEKIT_API_SECRET', 'RECORDING_ENABLED']
}, async (req, res) => {
  if (req.method !== 'POST') { res.sendStatus(405); return; }
  const receiver = new WebhookReceiver(LIVEKIT_API_KEY, LIVEKIT_API_SECRET);
  let event;
  try {
    const rawBody = req.rawBody?.toString() ?? JSON.stringify(req.body);
    event = await receiver.receive(rawBody, req.headers['authorization']);
  } catch (err) {
    logger.warn(`livekitWebhook: invalid signature — ${err.message}`);
    res.sendStatus(401); return;
  }
  const eventName  = event?.event;
  const roomName   = event?.room?.name;
  const userId     = event?.participant?.identity;
  const canPublish = event?.participant?.permission?.canPublish === true;
  if (!['participant_joined', 'participant_left'].includes(eventName) || !roomName || !userId) {
    res.sendStatus(200); return;
  }
  const db = getDb();
  const streamSnap = await db.collection('streams')
    .where('livekit_room_name', '==', roomName).where('status', '==', 'live').limit(1).get();
  if (streamSnap.empty) { res.sendStatus(200); return; }
  const streamRef  = streamSnap.docs[0].ref;
  const streamData = streamSnap.docs[0].data();
  const streamId   = streamSnap.docs[0].id;
  if (canPublish && eventName === 'participant_left') {
    await streamRef.update({ status: 'ended', ended_at: admin.firestore.FieldValue.serverTimestamp(), viewer_ids: [] });
    if (RECORDING_ENABLED && streamData.egress_id) {
      try { await makeEgressClient().stopEgress(streamData.egress_id); }
      catch (err) { logger.warn(`livekitWebhook: failed to stop egress: ${err.message}`); }
    }
    const openRequests = await db.collection('stream_requests')
      .where('stream_id', '==', streamId).where('status', 'in', ['pending', 'accepted']).get();
    await Promise.all(openRequests.docs.map(doc => refundStreamRequest(db, doc.id)));
    if (openRequests.size > 0) {
      const viewerIds = [...new Set(openRequests.docs.map(d => d.data().from_user_id))];
      await sendPush(db, viewerIds, {
        title: 'Your request was refunded',
        body:  `${streamData.streamer_name} ended the stream — your money is back`,
        data:  { type: 'stream_request_refunded', stream_id: streamId }
      });
    }
    res.sendStatus(200); return;
  }
  if (canPublish && eventName === 'participant_joined') { res.sendStatus(200); return; }
  if (eventName === 'participant_joined') {
    await streamRef.update({ viewer_ids: admin.firestore.FieldValue.arrayUnion(userId) });
  } else {
    await streamRef.update({ viewer_ids: admin.firestore.FieldValue.arrayRemove(userId) });
  }
  res.sendStatus(200);
});
