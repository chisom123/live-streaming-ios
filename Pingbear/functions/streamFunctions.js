/**
 * streamFunctions.js
 *
 * EXPORTS — index.js:
 *   exports.createStream            = stream.createStream;
 *   exports.startStreamRecording    = stream.startStreamRecording;
 *   exports.endStream               = stream.endStream;
 *   exports.joinStream              = stream.joinStream;
 *   exports.sendStreamRequest       = stream.sendStreamRequest;
 *   exports.respondToStreamRequest  = stream.respondToStreamRequest;
 *   exports.completeStreamRequest   = stream.completeStreamRequest;
 *   exports.resolveInviteStream     = stream.resolveInviteStream;
 *   exports.livekitWebhook          = stream.livekitWebhook;
 *
 * STREAM REQUEST MONEY FLOW
 * ─────────────────────────
 * sendStreamRequest       → escrow viewer wallet (bonus first via splitDebit) → status: pending
 * respondToStreamRequest  → accept: status: accepted (still escrowed)
 *                         → decline: refund viewer (bonus/real restored) → status: declined
 * completeStreamRequest   → pay streamer 80%, platform 20% → status: completed
 * endStream               → sweeps all pending + accepted → full refund each → status: refunded
 *
 * VIEWER COUNT
 * ────────────
 * viewer_ids is managed exclusively by the livekitWebhook function.
 * LiveKit fires participant_joined / participant_left for every connect and
 * disconnect — including crashes and network drops — so the count is always
 * accurate. joinStream no longer touches viewer_ids.
 *
 * RECORDING
 * ─────────
 * Controlled by RECORDING_ENABLED secret (set to 'true' to enable).
 * When enabled, createStream starts a LiveKit RoomComposite egress that
 * records the stream to GCS as an MP4 at recordings/{streamId}.mp4.
 * endStream stops the egress cleanly. Toggle off by setting
 * RECORDING_ENABLED=false and redeploying — zero cost when disabled.
 */

const { onCall }  = require('firebase-functions/v2/https');
const { onRequest } = require('firebase-functions/v2/https');
const admin  = require('firebase-admin');
const logger = require('firebase-functions/logger');
const { AccessToken, EgressClient, EncodedFileOutput, GCPUpload, WebhookReceiver } = require('livekit-server-sdk');
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

// ─────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────

function calcFees(price) {
  const platformFee   = round2(price * PLATFORM_FEE_RATE);
  const creatorPayout = round2(price - platformFee);
  return { platformFee, creatorPayout };
}

function makeLivekitToken({ identity, name, roomName, canPublish, canSubscribe }) {
  const at = new AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET, {
    identity,
    name,
    ttl: '4h'
  });
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
  const doc = await db.collection('users').doc(userId).get();
  const data = doc.data();
  return {
    name: data?.name ?? 'Someone',
    avatarUrl: data?.profilePictureUrl ?? null
  };
}

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
      user_id:        req.from_user_id,
      type:           'credit',
      amount:         refundAmount,
      reason:         'stream_request_refund',
      session_id:     requestId,
      metadata:       {
        stream_id:       req.stream_id,
        refund_reason:   'stream_ended',
        bonus_restored:  bonusPortion,
        real_restored:   realPortion
      },
      balance_before: balance,
      balance_after:  newBal,
      created_at:     admin.firestore.FieldValue.serverTimestamp()
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
      user_id:        streamerId,
      type:           'credit',
      amount:         creatorPayout,
      reason:         'stream_request_payout',
      session_id:     requestId,
      metadata:       {
        gross_amount:     price,
        platform_fee:     platformFee,
        transaction_type: 'stream_request',
        funded_by_bonus:  bonusFundedAmount,
        funded_by_real:   realFunded
      },
      balance_before: bal,
      balance_after:  newBal,
      created_at:     admin.firestore.FieldValue.serverTimestamp()
    });
  });

  await db.collection('platform_revenue').doc().set({
    transaction_id:      requestId,
    from_user_id:        fromUserId,
    to_user_id:          streamerId,
    type:                'stream_request',
    gross_amount:        price,
    platform_fee:        platformFee,
    creator_payout:      creatorPayout,
    bonus_funded_amount: bonusFundedAmount,
    real_funded_amount:  realFunded,
    real_revenue_fee:    realFee,
    collected_at:        admin.firestore.FieldValue.serverTimestamp()
  });
}

// ─────────────────────────────────────────────────────────────
// createStream
// ─────────────────────────────────────────────────────────────

exports.createStream = onCall({
  cors: ['*'], maxInstances: 50,
  secrets: ['LIVEKIT_API_KEY', 'LIVEKIT_API_SECRET', 'LIVEKIT_WS_URL']
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId = request.auth.uid;
  const {
    onAppInvitedIds    = [],
    offAppPhoneHashes  = [],
    offAppInviteeNames = {}
  } = request.data;

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
    await sendPush(db, validOnApp, {
      title: `${streamerName} is live now!`,
      body:  'Tap to join',
      data:  { type: 'stream_live', stream_id: streamRef.id }
    });
  }

  const token = await makeLivekitToken({
    identity:     userId,
    name:         streamerName,
    roomName,
    canPublish:   true,
    canSubscribe: false
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

  const userId       = request.auth.uid;
  const { streamId } = request.data;
  if (!streamId) throw new Error('streamId is required');

  const db   = getDb();
  const ref  = db.collection('streams').doc(streamId);
  const snap = await ref.get();
  if (!snap.exists) throw new Error('Stream not found');

  const stream = snap.data();
  if (stream.streamer_id !== userId) throw new Error('Not the streamer');
  if (stream.status !== 'live')      throw new Error('Stream is not live');

  await ref.update({
    status:     'ended',
    ended_at:   admin.firestore.FieldValue.serverTimestamp(),
    viewer_ids: []   // clear viewer list on end so count reads 0
  });

  if (RECORDING_ENABLED && stream.egress_id) {
    try {
      const egressClient = makeEgressClient();
      await egressClient.stopEgress(stream.egress_id);
      logger.info(`endStream: recording stopped, egressId: ${stream.egress_id}`);
    } catch (err) {
      logger.warn(`endStream: failed to stop recording: ${err.message}`);
    }
  }

  const openRequests = await db.collection('stream_requests')
    .where('stream_id', '==', streamId)
    .where('status', 'in', ['pending', 'accepted'])
    .get();

  await Promise.all(openRequests.docs.map(doc => refundStreamRequest(db, doc.id)));

  if (openRequests.size > 0) {
    const viewerIds = [...new Set(openRequests.docs.map(d => d.data().from_user_id))];
    await sendPush(db, viewerIds, {
      title: 'Your request was refunded',
      body:  `${stream.streamer_name} ended the stream — your money is back`,
      data:  { type: 'stream_request_refunded', stream_id: streamId }
    });
  }

  logger.info(`endStream: ${userId} ended ${streamId}, refunded ${openRequests.size} requests`);
  return { success: true };
});

// ─────────────────────────────────────────────────────────────
// joinStream
//
// viewer_ids is now managed by livekitWebhook — this function
// no longer touches it. It still handles auth, the join chat
// message, push notification to the streamer, and token generation.
// ─────────────────────────────────────────────────────────────

exports.joinStream = onCall({
  cors: ['*'], maxInstances: 100,
  secrets: ['LIVEKIT_API_KEY', 'LIVEKIT_API_SECRET', 'LIVEKIT_WS_URL']
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId       = request.auth.uid;
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

  const userInfo = await getUserInfo(db, userId);

  // Post join chat message and notify streamer only on first join.
  // Use a lightweight read of viewer_ids for the "first time" check —
  // the authoritative count update happens via livekitWebhook.
  const alreadySeen = (stream.viewer_ids ?? []).includes(userId);
  if (!alreadySeen && stream.streamer_id !== userId) {
    await db.collection('stream_chat').doc(streamId).collection('messages').doc().set({
      user_id:    userId,
      name:       userInfo.name,
      avatar_url: userInfo.avatarUrl,
      text:       `${userInfo.name} joined`,
      type:       'join_event',
      request_id: null,
      created_at: admin.firestore.FieldValue.serverTimestamp()
    });

    await sendPush(db, [stream.streamer_id], {
      title: `${userInfo.name} joined your stream`,
      body:  'Someone just tuned in',
      data:  { type: 'stream_viewer_joined', stream_id: streamId }
    });
  }

  const token = await makeLivekitToken({
    identity:     userId,
    name:         userInfo.name,
    roomName:     stream.livekit_room_name,
    canPublish:   false,
    canSubscribe: true
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

  if (!streamId)              throw new Error('streamId is required');
  if (!description?.trim())   throw new Error('Description is required');
  if (description.trim().length > 120) throw new Error('Description max 120 chars');
  if (!price || price < MIN_PRICE || price > MAX_PRICE) {
    throw new Error(`Price must be between $${MIN_PRICE} and $${MAX_PRICE}`);
  }

  const db        = getDb();
  const streamRef = db.collection('streams').doc(streamId);
  const streamSnap = await streamRef.get();
  if (!streamSnap.exists)            throw new Error('Stream not found');
  const stream = streamSnap.data();
  if (stream.status !== 'live')      throw new Error('Stream is not live');
  if (stream.streamer_id === userId) throw new Error('Streamer cannot send requests to themselves');

  const { platformFee, creatorPayout } = calcFees(price);
  let bonusUsed = 0;
  let realUsed  = 0;

  await db.runTransaction(async (t) => {
    const userRef  = db.collection('users').doc(userId);
    const userDoc  = await t.get(userRef);
    const balance  = userDoc.data()?.wallet_balance ?? 0;
    const bonus    = userDoc.data()?.bonus_balance  ?? 0;

    if (balance < price) throw new Error(`Insufficient funds. Need $${price.toFixed(2)}, balance $${balance.toFixed(2)}`);

    const split   = splitDebit(bonus, price);
    bonusUsed     = split.bonusUsed;
    realUsed      = split.realUsed;
    const newBal  = round2(balance - price);

    t.set(userRef, {
      wallet_balance: admin.firestore.FieldValue.increment(-price),
      bonus_balance:  admin.firestore.FieldValue.increment(-bonusUsed)
    }, { merge: true });

    const txRef = db.collection('wallet_transactions').doc();
    t.set(txRef, {
      user_id:        userId,
      type:           'debit',
      amount:         price,
      reason:         'stream_request_escrow',
      session_id:     null,
      metadata:       { stream_id: streamId, bonus_used: bonusUsed, real_used: realUsed },
      balance_before: balance,
      balance_after:  newBal,
      created_at:     admin.firestore.FieldValue.serverTimestamp()
    });
  });

  const requestRef   = db.collection('stream_requests').doc();
  const fromUserInfo = await getUserInfo(db, userId);

  await requestRef.set({
    stream_id:            streamId,
    from_user_id:         userId,
    from_user_name:       fromUserInfo.name,
    from_user_image_url:  fromUserInfo.avatarUrl,
    streamer_id:          stream.streamer_id,
    description:          description.trim(),
    price,
    platform_fee:         platformFee,
    creator_payout:       creatorPayout,
    status:               'pending',
    funded_bonus_amount:  bonusUsed,
    funded_real_amount:   realUsed,
    created_at:           admin.firestore.FieldValue.serverTimestamp(),
    accepted_at:          null,
    completed_at:         null
  });

  await streamRef.update({ request_count: admin.firestore.FieldValue.increment(1) });

  await db.collection('stream_chat').doc(streamId).collection('messages').doc().set({
    user_id:    userId,
    name:       fromUserInfo.name,
    avatar_url: fromUserInfo.avatarUrl,
    text:       `${description.trim()} · $${price.toFixed(2)}`,
    type:       'request_event',
    request_id: requestRef.id,
    created_at: admin.firestore.FieldValue.serverTimestamp()
  });

  await sendPush(db, [stream.streamer_id], {
    title: `${fromUserInfo.name} wants: "${description.trim().slice(0, 50)}"`,
    body:  `$${price.toFixed(2)} — tap to respond`,
    data:  { type: 'stream_request_received', request_id: requestRef.id, stream_id: streamId }
  });

  logger.info(`sendStreamRequest: ${userId} → ${stream.streamer_id}, $${price}, stream ${streamId}`);
  return { success: true, requestId: requestRef.id };
});

// ─────────────────────────────────────────────────────────────
// respondToStreamRequest
// ─────────────────────────────────────────────────────────────

exports.respondToStreamRequest = onCall({ cors: ['*'], maxInstances: 100 }, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId                 = request.auth.uid;
  const { requestId, accept }  = request.data;
  if (!requestId)              throw new Error('requestId is required');
  if (typeof accept !== 'boolean') throw new Error('accept must be boolean');

  const db   = getDb();
  const ref  = db.collection('stream_requests').doc(requestId);
  const snap = await ref.get();
  if (!snap.exists) throw new Error('Request not found');

  const req = snap.data();
  if (req.streamer_id !== userId) throw new Error('Not the streamer');
  if (req.status !== 'pending')   throw new Error(`Cannot respond to status: ${req.status}`);

  const streamSnap = await db.collection('streams').doc(req.stream_id).get();
  if (!streamSnap.exists || streamSnap.data().status !== 'live') {
    throw new Error('Stream is no longer live');
  }

  const streamerInfo = await getUserInfo(db, userId);

  if (!accept) {
    await refundStreamRequest(db, requestId);
    
    // 🔥 ADDED: Chat message for decline
    await db.collection('stream_chat').doc(req.stream_id).collection('messages').doc().set({
      user_id:    userId,
      name:       streamerInfo.name,
      avatar_url: streamerInfo.avatarUrl,
      text:       `declined request: "${req.description.slice(0, 60)}"`,
      type:       'request_declined',
      request_id: requestId,
      created_at: admin.firestore.FieldValue.serverTimestamp()
    });

    await sendPush(db, [req.from_user_id], {
      title: `${streamerInfo.name} declined your request`,
      body:  'Your money has been refunded',
      data:  { type: 'stream_request_refunded', request_id: requestId, stream_id: req.stream_id }
    });
    logger.info(`respondToStreamRequest: ${userId} declined ${requestId}`);
    return { success: true };
  }

  await ref.update({ status: 'accepted', accepted_at: admin.firestore.FieldValue.serverTimestamp() });
  
  // 🔥 ADDED: Chat message for acceptance
  await db.collection('stream_chat').doc(req.stream_id).collection('messages').doc().set({
    user_id:    userId,
    name:       streamerInfo.name,
    avatar_url: streamerInfo.avatarUrl,
    text:       `accepted "${req.description.slice(0, 60)}"`,
    type:       'request_accepted',
    request_id: requestId,
    created_at: admin.firestore.FieldValue.serverTimestamp()
  });

  await sendPush(db, [req.from_user_id], {
    title: `${streamerInfo.name} accepted your request!`,
    body:  `"${req.description.slice(0, 60)}" — they're on it`,
    data:  { type: 'stream_request_accepted', request_id: requestId, stream_id: req.stream_id }
  });

  logger.info(`respondToStreamRequest: ${userId} accepted ${requestId}`);
  return { success: true };
});

// ─────────────────────────────────────────────────────────────
// completeStreamRequest
// ─────────────────────────────────────────────────────────────

exports.completeStreamRequest = onCall({ cors: ['*'], maxInstances: 100 }, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId        = request.auth.uid;
  const { requestId } = request.data;
  if (!requestId) throw new Error('requestId is required');

  const db   = getDb();
  const ref  = db.collection('stream_requests').doc(requestId);
  const snap = await ref.get();
  if (!snap.exists) throw new Error('Request not found');

  const req = snap.data();
  if (req.streamer_id !== userId) throw new Error('Not the streamer');
  if (req.status !== 'accepted')  throw new Error(`Cannot complete status: ${req.status}`);

  await ref.update({
    status:       'completed',
    completed_at: admin.firestore.FieldValue.serverTimestamp()
  });

  await payStreamer(db, {
    requestId,
    streamerId:         userId,
    fromUserId:         req.from_user_id,
    price:              req.price,
    bonusFundedAmount:  req.funded_bonus_amount ?? 0,
    realFundedAmount:   req.funded_real_amount  ?? req.price
  });

  await db.collection('streams').doc(req.stream_id).update({
    total_earned: admin.firestore.FieldValue.increment(req.creator_payout)
  });

  // 🔥 ADDED: Chat message for completion
  const streamerInfo = await getUserInfo(db, userId);
  await db.collection('stream_chat').doc(req.stream_id).collection('messages').doc().set({
    user_id:    userId,
    name:       streamerInfo.name,
    avatar_url: streamerInfo.avatarUrl,
    text:       `completed request: "${req.description.slice(0, 60)}" ✅`,
    type:       'request_completed',
    request_id: requestId,
    created_at: admin.firestore.FieldValue.serverTimestamp()
  });

  await sendPush(db, [req.from_user_id], {
    title: `${streamerInfo.name} completed your request!`,
    body:  `"${req.description.slice(0, 60)}"`,
    data:  { type: 'stream_request_completed', request_id: requestId, stream_id: req.stream_id }
  });

  logger.info(`completeStreamRequest: ${userId} completed ${requestId}, payout $${req.creator_payout}`);
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

  const userId       = request.auth.uid;
  const { streamId } = request.data;
  if (!streamId) throw new Error('streamId is required');

  if (!RECORDING_ENABLED) {
    return { success: true, skipped: true };
  }

  const db   = getDb();
  const ref  = db.collection('streams').doc(streamId);
  const snap = await ref.get();
  if (!snap.exists) throw new Error('Stream not found');

  const stream = snap.data();
  if (stream.streamer_id !== userId) throw new Error('Not the streamer');
  if (stream.status !== 'live')      throw new Error('Stream is not live');
  if (stream.egress_id)              return { success: true, skipped: true };

  try {
    const egressClient = makeEgressClient();
    const egress = await egressClient.startRoomCompositeEgress(stream.livekit_room_name, {
      file: new EncodedFileOutput({
        filepath: `recordings/${streamId}.mp4`,
        output:   {
          case:  'gcp',
          value: new GCPUpload({
            credentials: GCS_CREDENTIALS,
            bucket:      GCS_BUCKET
          })
        }
      })
    });
    await ref.update({ egress_id: egress.egressId });
    logger.info(`startStreamRecording: recording started for ${streamId}, egressId: ${egress.egressId}`);
    return { success: true, skipped: false };
  } catch (err) {
    logger.error(`startStreamRecording: failed for ${streamId}: ${err.message}`);
    throw new Error(`Failed to start recording: ${err.message}`);
  }
});

// ─────────────────────────────────────────────────────────────
// resolveInviteStream
// ─────────────────────────────────────────────────────────────

exports.resolveInviteStream = onCall({ cors: ['*'], maxInstances: 50 }, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId       = request.auth.uid;
  const { streamId } = request.data;
  if (!streamId) throw new Error('streamId is required');

  const db   = getDb();
  const ref  = db.collection('streams').doc(streamId);
  const snap = await ref.get();

  if (!snap.exists) {
    logger.info(`resolveInviteStream: stream ${streamId} not found, skipping`);
    return { success: true, skipped: true };
  }

  const stream = snap.data();
  if (stream.status !== 'live') {
    logger.info(`resolveInviteStream: stream ${streamId} status is ${stream.status}, skipping`);
    return { success: true, skipped: true };
  }

  await ref.update({
    invited_user_ids: admin.firestore.FieldValue.arrayUnion(userId)
  });

  logger.info(`resolveInviteStream: added ${userId} to invited_user_ids on stream ${streamId}`);
  return { success: true, skipped: false };
});

// ─────────────────────────────────────────────────────────────
// livekitWebhook
//
// Receives signed participant_joined / participant_left events
// directly from LiveKit and updates viewer_ids accordingly.
// This is the single source of truth for viewer count — it handles
// normal leaves, app crashes, and network drops alike.
//
// Setup: deploy this function, then register its URL in the
// LiveKit dashboard under your project → Webhooks.
// ─────────────────────────────────────────────────────────────

exports.livekitWebhook = onRequest({
  cors: false,
  maxInstances: 50,
  rawBody: true,
  secrets: ['LIVEKIT_API_KEY', 'LIVEKIT_API_SECRET', 'RECORDING_ENABLED']
}, async (req, res) => {
  if (req.method !== 'POST') {
    res.sendStatus(405);
    return;
  }

  // LiveKit signs every webhook with LIVEKIT_API_SECRET.
  // WebhookReceiver must receive the raw unparsed body string —
  // Cloud Functions v2 parses req.body automatically, so we use
  // req.rawBody (available when rawBody: true is set above).
  const receiver = new WebhookReceiver(LIVEKIT_API_KEY, LIVEKIT_API_SECRET);
  let event;
  try {
    const rawBody = req.rawBody?.toString() ?? JSON.stringify(req.body);
    event = await receiver.receive(rawBody, req.headers['authorization']);
  } catch (err) {
    logger.warn(`livekitWebhook: invalid signature — ${err.message}`);
    res.sendStatus(401);
    return;
  }

  const eventName  = event?.event;
  const roomName   = event?.room?.name;
  const userId     = event?.participant?.identity;
  const canPublish = event?.participant?.permission?.canPublish === true;

  // Ignore everything except participant join/leave
  if (!['participant_joined', 'participant_left'].includes(eventName)
      || !roomName
      || !userId) {
    res.sendStatus(200);
    return;
  }

  const db = getDb();

  const streamSnap = await db.collection('streams')
    .where('livekit_room_name', '==', roomName)
    .where('status', '==', 'live')
    .limit(1)
    .get();

  if (streamSnap.empty) {
    res.sendStatus(200);
    return;
  }

  const streamRef  = streamSnap.docs[0].ref;
  const streamData = streamSnap.docs[0].data();
  const streamId   = streamSnap.docs[0].id;

  // ── Streamer left (canPublish) → end the stream ──────────────
  if (canPublish && eventName === 'participant_left') {
    await streamRef.update({
      status:     'ended',
      ended_at:   admin.firestore.FieldValue.serverTimestamp(),
      viewer_ids: []
    });

    // Stop the recording egress if one was running
    if (RECORDING_ENABLED && streamData.egress_id) {
      try {
        const egressClient = makeEgressClient();
        await egressClient.stopEgress(streamData.egress_id);
        logger.info(`livekitWebhook: stopped egress ${streamData.egress_id} for stream ${streamId}`);
      } catch (err) {
        // Non-fatal — LiveKit may have already stopped it when the room emptied
        logger.warn(`livekitWebhook: failed to stop egress: ${err.message}`);
      }
    }

    const openRequests = await db.collection('stream_requests')
      .where('stream_id', '==', streamId)
      .where('status', 'in', ['pending', 'accepted'])
      .get();

    await Promise.all(openRequests.docs.map(doc => refundStreamRequest(db, doc.id)));

    if (openRequests.size > 0) {
      const viewerIds = [...new Set(openRequests.docs.map(d => d.data().from_user_id))];
      await sendPush(db, viewerIds, {
        title: 'Your request was refunded',
        body:  `${streamData.streamer_name} ended the stream — your money is back`,
        data:  { type: 'stream_request_refunded', stream_id: streamId }
      });
    }

    logger.info(`livekitWebhook: streamer left — auto-ended stream ${streamId}, refunded ${openRequests.size} requests`);
    res.sendStatus(200);
    return;
  }

  // ── Streamer joined → ignore (not a viewer) ──────────────────
  if (canPublish && eventName === 'participant_joined') {
    res.sendStatus(200);
    return;
  }

  // ── Viewer joined / left → update viewer_ids ─────────────────
  if (eventName === 'participant_joined') {
    await streamRef.update({
      viewer_ids: admin.firestore.FieldValue.arrayUnion(userId)
    });
    logger.info(`livekitWebhook: +1 viewer ${userId} on room ${roomName}`);
  } else {
    await streamRef.update({
      viewer_ids: admin.firestore.FieldValue.arrayRemove(userId)
    });
    logger.info(`livekitWebhook: -1 viewer ${userId} on room ${roomName}`);
  }

  res.sendStatus(200);
});
