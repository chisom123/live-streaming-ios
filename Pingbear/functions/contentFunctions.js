/**
 * contentFunctions.js
 *
 * EXPORTS — index.js:
 *   exports.sendTransaction          = content.sendTransaction;
 *   exports.respondToTransaction     = content.respondToTransaction;
 *   exports.fulfillRequest           = content.fulfillRequest;
 *   exports.markTransactionViewed    = content.markTransactionViewed;
 *   exports.rateTransaction          = content.rateTransaction;
 *   exports.cancelRequest            = content.cancelRequest;
 *   exports.resolveInviteTransaction = content.resolveInviteTransaction;
 *   exports.dismissTransaction       = content.dismissTransaction;
 *
 * FLOW
 * ────
 * REQUEST:
 *   sendTransaction          → escrow price from payer → pending_acceptance
 *   cancelRequest            → refund payer → cancelled  (before fulfilled)
 *   respondToTransaction (decline) → refund payer → declined
 *   respondToTransaction (accept)  → accepted
 *   fulfillRequest           → pay creator 80%, platform 20% → fulfilled
 *   markTransactionViewed    → completed (no money)
 *   rateTransaction          → updates creator avg rating (no status change)
 */

const { onCall } = require('firebase-functions/v2/https');
const admin      = require('firebase-admin');
const logger     = require('firebase-functions/logger');

let _db;
const getDb = () => { if (!_db) _db = admin.firestore(); return _db; };

const PLATFORM_FEE_RATE = 0.20;
const MIN_PRICE         = 0.50;
const MAX_PRICE         = 20.00;

// ─────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────

async function recordWalletTx(t, { userId, type, amount, reason, txId, metadata, balanceBefore, balanceAfter }) {
  const db  = getDb();
  const ref = db.collection('wallet_transactions').doc();
  t.set(ref, {
    user_id:        userId,
    type,
    amount,
    reason,
    session_id:     txId ?? null,
    metadata:       metadata ?? {},
    balance_before: balanceBefore,
    balance_after:  balanceAfter,
    created_at:     admin.firestore.FieldValue.serverTimestamp()
  });
}

async function recordPlatformRevenue(db, { txId, fromUserId, toUserId, grossAmount, platformFee, creatorPayout }) {
  await db.collection('platform_revenue').doc().set({
    transaction_id:  txId,
    from_user_id:    fromUserId,
    to_user_id:      toUserId,
    type:            'request',
    gross_amount:    grossAmount,
    platform_fee:    platformFee,
    creator_payout:  creatorPayout,
    collected_at:    admin.firestore.FieldValue.serverTimestamp()
  });
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

function calcFees(price) {
  const platformFee   = parseFloat((price * PLATFORM_FEE_RATE).toFixed(2));
  const creatorPayout = parseFloat((price - platformFee).toFixed(2));
  return { platformFee, creatorPayout };
}

async function getUserName(db, userId) {
  const doc = await db.collection('users').doc(userId).get();
  return doc.data()?.name ?? 'Someone';
}

async function payCreator(db, { txId, creatorId, fromUserId, toUserId, price }) {
  const { platformFee, creatorPayout } = calcFees(price);
  await db.runTransaction(async (t) => {
    const creatorRef = db.collection('users').doc(creatorId);
    const creatorDoc = await t.get(creatorRef);
    const creatorBal = creatorDoc.data()?.wallet_balance ?? 0;
    const newBal     = parseFloat((creatorBal + creatorPayout).toFixed(2));
    t.set(creatorRef, {
      wallet_balance: admin.firestore.FieldValue.increment(creatorPayout),
      totalEarned:    admin.firestore.FieldValue.increment(creatorPayout)
    }, { merge: true });
    await recordWalletTx(t, {
      userId:        creatorId,
      type:          'credit',
      amount:        creatorPayout,
      reason:        'creator_payout',
      txId,
      metadata:      { gross_amount: price, platform_fee: platformFee },
      balanceBefore: creatorBal,
      balanceAfter:  newBal
    });
  });
  await recordPlatformRevenue(db, {
    txId, fromUserId, toUserId,
    grossAmount: price, platformFee: calcFees(price).platformFee, creatorPayout: calcFees(price).creatorPayout
  });
}

// ─────────────────────────────────────────────────────────────
// sendTransaction — escrow price × recipient count upfront
// ─────────────────────────────────────────────────────────────

exports.sendTransaction = onCall({ cors: ['*'], maxInstances: 50 }, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId = request.auth.uid;
  const {
    onAppRecipientIds    = [],
    offAppPhoneHashes    = [],
    offAppRecipientNames = {},
    price,
    description
  } = request.data;

  if (!price || price < MIN_PRICE || price > MAX_PRICE) throw new Error(`Price must be between $${MIN_PRICE} and $${MAX_PRICE}`);
  if (!description || description.trim().length === 0)  throw new Error('Description is required');
  if (description.trim().length > 120)                  throw new Error('Description max 120 chars');

  const db          = getDb();
  const validOnApp  = onAppRecipientIds.filter(id => id !== userId);
  const validOffApp = [...new Set(offAppPhoneHashes)];
  const totalCount  = validOnApp.length + validOffApp.length;

  if (totalCount === 0) throw new Error('At least one recipient required');

  const { platformFee, creatorPayout } = calcFees(price);
  const totalEscrow = parseFloat((price * totalCount).toFixed(2));
  const senderName  = await getUserName(db, userId);

  // Escrow total upfront
  await db.runTransaction(async (t) => {
    const userRef  = db.collection('users').doc(userId);
    const userDoc  = await t.get(userRef);
    const balance  = userDoc.data()?.wallet_balance ?? 0;
    if (balance < totalEscrow) throw new Error(`Insufficient funds. Need $${totalEscrow.toFixed(2)}, balance $${balance.toFixed(2)}`);
    const newBalance = parseFloat((balance - totalEscrow).toFixed(2));
    t.set(userRef, { wallet_balance: admin.firestore.FieldValue.increment(-totalEscrow) }, { merge: true });
    await recordWalletTx(t, {
      userId,
      type:          'debit',
      amount:        totalEscrow,
      reason:        'request_escrow',
      metadata:      { recipient_count: totalCount },
      balanceBefore: balance,
      balanceAfter:  newBalance
    });
  });

  const createdTxIds = [];
  const txBase = {
    type:           'request',
    from_user_id:   userId,
    price,
    platform_fee:   platformFee,
    creator_payout: creatorPayout,
    description:    description.trim(),
    status:         'pending_acceptance',
    photo_url:      null,
    rating:         null,
    dismissed_by:   [],
    created_at:     admin.firestore.FieldValue.serverTimestamp(),
    accepted_at:    null,
    fulfilled_at:   null,
    completed_at:   null
  };

  // On-app recipients
  for (const recipientId of validOnApp) {
    const txRef = db.collection('content_transactions').doc();
    await txRef.set({ ...txBase, id: txRef.id, to_user_id: recipientId, pending_phone_hash: null, pending_name: null });
    createdTxIds.push(txRef.id);
  }

  // Off-app recipients
  const inviterDoc  = await db.collection('users').doc(userId).get();
  const inviterHash = inviterDoc.data()?.phoneNumberHash ?? '';

  for (const phoneHash of validOffApp) {
    const txRef       = db.collection('content_transactions').doc();
    const pendingName = offAppRecipientNames[phoneHash] ?? null;
    await txRef.set({
      ...txBase,
      id:                  txRef.id,
      to_user_id:          null,
      status:              'pending_signup',
      pending_phone_hash:  phoneHash,
      pending_name:        pendingName
    });
    createdTxIds.push(txRef.id);
    const allHashes = [phoneHash];
    if (inviterHash) allHashes.push(inviterHash);
    await db.collection('invite_groups').doc().set({
      memberHashes:          allHashes,
      memberUserIds:         inviterHash ? { [inviterHash]: userId } : {},
      pendingTransactionIds: [txRef.id],
      createdAt:             admin.firestore.FieldValue.serverTimestamp()
    });
  }

  if (validOnApp.length > 0) {
    await sendPush(db, validOnApp, {
      title: `${senderName} wants a photo from you 📸`,
      body:  `They'll pay you $${price.toFixed(2)} — accept their request!`,
      data:  { type: 'request_received' }
    });
  }

  logger.info(`sendTransaction: ${userId} sent request to ${totalCount} recipients, $${price} each`);
  return { success: true, transactionIds: createdTxIds };
});

// ─────────────────────────────────────────────────────────────
// respondToTransaction
// accept → accepted | decline → refund → declined
// ─────────────────────────────────────────────────────────────

exports.respondToTransaction = onCall({ cors: ['*'], maxInstances: 50 }, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId = request.auth.uid;
  const { transactionId, accept } = request.data;

  if (!transactionId)              throw new Error('transactionId is required');
  if (typeof accept !== 'boolean') throw new Error('accept must be boolean');

  const db    = getDb();
  const txRef = db.collection('content_transactions').doc(transactionId);
  const txDoc = await txRef.get();

  if (!txDoc.exists) throw new Error('Transaction not found');
  const tx = txDoc.data();

  if (tx.type !== 'request')              throw new Error('Only requests can be responded to here');
  if (tx.to_user_id !== userId)           throw new Error('You are not the recipient');
  if (tx.status !== 'pending_acceptance') throw new Error(`Cannot respond to status: ${tx.status}`);

  const recipientName = await getUserName(db, userId);

  // ── Decline — refund payer ────────────────────────────────
  if (!accept) {
    await db.runTransaction(async (t) => {
      const fromRef = db.collection('users').doc(tx.from_user_id);
      const fromDoc = await t.get(fromRef);
      const balance = fromDoc.data()?.wallet_balance ?? 0;
      const newBal  = parseFloat((balance + tx.price).toFixed(2));
      t.set(fromRef, { wallet_balance: admin.firestore.FieldValue.increment(tx.price) }, { merge: true });
      t.update(txRef, { status: 'declined' });
      await recordWalletTx(t, {
        userId:        tx.from_user_id,
        type:          'credit',
        amount:        tx.price,
        reason:        'escrow_refund',
        txId:          transactionId,
        metadata:      { reason: 'recipient_declined' },
        balanceBefore: balance,
        balanceAfter:  newBal
      });
    });

    await sendPush(db, [tx.from_user_id], {
      title: `${recipientName} declined your request`,
      body:  'Your funds have been refunded',
      data:  { type: 'request_declined', transaction_id: transactionId }
    });

    logger.info(`respondToTransaction: ${userId} declined ${transactionId}`);
    return { success: true };
  }

  // ── Accept ────────────────────────────────────────────────
  await txRef.update({
    status:      'accepted',
    accepted_at: admin.firestore.FieldValue.serverTimestamp()
  });

  await sendPush(db, [tx.from_user_id], {
    title: `${recipientName} accepted your request! 🎉`,
    body:  "They're working on your photo now",
    data:  { type: 'request_accepted', transaction_id: transactionId }
  });

  logger.info(`respondToTransaction: ${userId} accepted ${transactionId}`);
  return { success: true };
});

// ─────────────────────────────────────────────────────────────
// fulfillRequest — creator uploads photo, gets paid
// ─────────────────────────────────────────────────────────────

exports.fulfillRequest = onCall({ cors: ['*'], maxInstances: 50 }, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId = request.auth.uid;
  const { transactionId, photoUrl } = request.data;

  if (!transactionId) throw new Error('transactionId is required');
  if (!photoUrl)      throw new Error('photoUrl is required');

  const db    = getDb();
  const txRef = db.collection('content_transactions').doc(transactionId);
  const txDoc = await txRef.get();

  if (!txDoc.exists) throw new Error('Transaction not found');
  const tx = txDoc.data();

  if (tx.to_user_id !== userId) throw new Error('You are not the creator');
  if (tx.status !== 'accepted') throw new Error(`Cannot fulfill status: ${tx.status}`);

  await txRef.update({
    status:       'fulfilled',
    photo_url:    photoUrl,
    fulfilled_at: admin.firestore.FieldValue.serverTimestamp()
  });

  await payCreator(db, {
    txId:       transactionId,
    creatorId:  userId,
    fromUserId: tx.from_user_id,
    toUserId:   userId,
    price:      tx.price
  });

  const creatorName = await getUserName(db, userId);

  await sendPush(db, [tx.from_user_id], {
    title: `${creatorName} sent your photo 👀`,
    body:  'Tap to see what they sent you!',
    data:  { type: 'request_fulfilled', transaction_id: transactionId }
  });

  logger.info(`fulfillRequest: ${userId} fulfilled ${transactionId}`);
  return { success: true };
});

// ─────────────────────────────────────────────────────────────
// markTransactionViewed — payer views photo → completed
// ─────────────────────────────────────────────────────────────

exports.markTransactionViewed = onCall({ cors: ['*'], maxInstances: 50 }, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId = request.auth.uid;
  const { transactionId } = request.data;

  if (!transactionId) throw new Error('transactionId is required');

  const db    = getDb();
  const txRef = db.collection('content_transactions').doc(transactionId);
  const txDoc = await txRef.get();

  if (!txDoc.exists) throw new Error('Transaction not found');
  const tx = txDoc.data();

  if (tx.from_user_id !== userId) throw new Error('Only the requester can mark as viewed');
  if (tx.status !== 'fulfilled')  return { success: true };

  await txRef.update({
    status:       'completed',
    completed_at: admin.firestore.FieldValue.serverTimestamp()
  });

  logger.info(`markTransactionViewed: ${userId} viewed ${transactionId}`);
  return { success: true };
});

// ─────────────────────────────────────────────────────────────
// rateTransaction
// ─────────────────────────────────────────────────────────────

exports.rateTransaction = onCall({ cors: ['*'], maxInstances: 50 }, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId = request.auth.uid;
  const { transactionId, rating } = request.data;

  if (!transactionId)                                                    throw new Error('transactionId is required');
  if (!rating || rating < 1 || rating > 5 || !Number.isInteger(rating)) throw new Error('Rating must be 1–5');

  const db    = getDb();
  const txRef = db.collection('content_transactions').doc(transactionId);
  const txDoc = await txRef.get();

  if (!txDoc.exists) throw new Error('Transaction not found');
  const tx = txDoc.data();

  if (tx.from_user_id !== userId) throw new Error('Only the requester can rate');
  if (tx.status !== 'completed')  throw new Error('Can only rate completed transactions');
  if (tx.rating !== null && tx.rating !== undefined) throw new Error('Already rated');

  const creatorId = tx.to_user_id;

  await db.runTransaction(async (t) => {
    const creatorRef = db.collection('users').doc(creatorId);
    const creatorDoc = await t.get(creatorRef);
    const data       = creatorDoc.data() ?? {};
    const oldCount   = data.ratingCount   ?? 0;
    const oldAvg     = data.averageRating ?? 0;
    const newCount   = oldCount + 1;
    const newAvg     = parseFloat(((oldAvg * oldCount + rating) / newCount).toFixed(2));
    t.set(creatorRef, { ratingCount: newCount, averageRating: newAvg }, { merge: true });
    t.update(txRef, { rating });
  });

  const payerName = await getUserName(db, userId);
  await sendPush(db, [creatorId], {
    title: `${payerName} rated your photo ${rating}⭐`,
    body:  rating >= 4 ? 'They loved it! 🔥' : 'Keep it up!',
    data:  { type: 'content_rated', transaction_id: transactionId }
  });

  logger.info(`rateTransaction: ${userId} rated ${transactionId} with ${rating}`);
  return { success: true };
});

// ─────────────────────────────────────────────────────────────
// cancelRequest — payer cancels, gets refunded
// ─────────────────────────────────────────────────────────────

exports.cancelRequest = onCall({ cors: ['*'], maxInstances: 50 }, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId = request.auth.uid;
  const { transactionId } = request.data;

  if (!transactionId) throw new Error('transactionId is required');

  const db    = getDb();
  const txRef = db.collection('content_transactions').doc(transactionId);
  const txDoc = await txRef.get();

  if (!txDoc.exists) throw new Error('Transaction not found');
  const tx = txDoc.data();

  if (tx.from_user_id !== userId) throw new Error('Only the sender can cancel');

  const cancellable = ['pending_signup', 'pending_acceptance', 'accepted'];
  if (!cancellable.includes(tx.status)) throw new Error('Cannot cancel — request already fulfilled');

  await db.runTransaction(async (t) => {
    const userRef = db.collection('users').doc(userId);
    const userDoc = await t.get(userRef);
    const balance = userDoc.data()?.wallet_balance ?? 0;
    const newBal  = parseFloat((balance + tx.price).toFixed(2));
    t.set(userRef, { wallet_balance: admin.firestore.FieldValue.increment(tx.price) }, { merge: true });
    t.update(txRef, { status: 'cancelled' });
    await recordWalletTx(t, {
      userId,
      type:          'credit',
      amount:        tx.price,
      reason:        'escrow_refund',
      txId:          transactionId,
      metadata:      { reason: 'request_cancelled_by_sender' },
      balanceBefore: balance,
      balanceAfter:  newBal
    });
  });

  if (tx.to_user_id) {
    const senderName = await getUserName(db, userId);
    await sendPush(db, [tx.to_user_id], {
      title: `${senderName} cancelled their request`,
      body:  'The request has been withdrawn',
      data:  { type: 'request_cancelled', transaction_id: transactionId }
    });
  }

  logger.info(`cancelRequest: ${userId} cancelled ${transactionId}`);
  return { success: true };
});

// ─────────────────────────────────────────────────────────────
// resolveInviteTransaction
// ─────────────────────────────────────────────────────────────

exports.resolveInviteTransaction = onCall({ cors: ['*'], maxInstances: 50 }, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId            = request.auth.uid;
  const { transactionId } = request.data;

  if (!transactionId) throw new Error('transactionId is required');

  const db    = getDb();
  const txRef = db.collection('content_transactions').doc(transactionId);
  const txDoc = await txRef.get();

  if (!txDoc.exists) { logger.info(`resolveInviteTransaction: not found, skipping`); return { success: true, skipped: true }; }

  const tx = txDoc.data();
  if (tx.status !== 'pending_signup') return { success: true, skipped: true };

  await txRef.update({ to_user_id: userId, status: 'pending_acceptance' });

  const senderName = await getUserName(db, tx.from_user_id);
  await sendPush(db, [userId], {
    title: `${senderName} wants a photo from you 📸`,
    body:  `They'll pay you $${tx.price.toFixed(2)} — open SocialStar to respond!`,
    data:  { type: 'request_received', transaction_id: transactionId }
  });

  logger.info(`resolveInviteTransaction: resolved ${transactionId} for ${userId}`);
  return { success: true, skipped: false };
});

// ─────────────────────────────────────────────────────────────
// dismissTransaction
// ─────────────────────────────────────────────────────────────

exports.dismissTransaction = onCall({ cors: ['*'], maxInstances: 50 }, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId            = request.auth.uid;
  const { transactionId } = request.data;

  if (!transactionId) throw new Error('transactionId is required');

  const db    = getDb();
  const txRef = db.collection('content_transactions').doc(transactionId);
  const txDoc = await txRef.get();

  if (!txDoc.exists) throw new Error('Transaction not found');
  const tx = txDoc.data();

  if (tx.from_user_id !== userId && tx.to_user_id !== userId) throw new Error('You are not a party to this transaction');

  await txRef.update({ dismissed_by: admin.firestore.FieldValue.arrayUnion(userId) });
  logger.info(`dismissTransaction: ${userId} dismissed ${transactionId}`);
  return { success: true };
});
