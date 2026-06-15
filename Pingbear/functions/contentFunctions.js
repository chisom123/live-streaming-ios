/**
 * contentFunctions.js
 *
 * EXPORTS — index.js:
 *   exports.sendTransaction          = content.sendTransaction;
 *   exports.respondToTransaction     = content.respondToTransaction;
 *   exports.rateTransaction          = content.rateTransaction;
 *   exports.resolveInviteTransaction = content.resolveInviteTransaction;
 *   exports.markTransactionViewed    = content.markTransactionViewed; (no-op, kept for safety)
 *   exports.dismissTransaction       = content.dismissTransaction;
 *
 * FLOW
 * ────
 * OFFER:
 *   sendTransaction     → pending_acceptance (no money moved)
 *   respondToTransaction (decline) → declined
 *   respondToTransaction (accept)  → pay creator 80%, platform 20% → completed
 *   rateTransaction     → updates creator avg rating only (no status change)
 */

const { onCall }     = require('firebase-functions/v2/https');
const admin          = require('firebase-admin');
const logger         = require('firebase-functions/logger');

let _db;
const getDb = () => {
  if (!_db) _db = admin.firestore();
  return _db;
};

const PLATFORM_FEE_RATE = 0.20;
const MIN_PRICE         = 0.50;
const MAX_PRICE         = 20.00;

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
    type:            'offer',
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
    snap.docs.forEach(doc => {
      const token = doc.data()?.fcmToken;
      if (token) tokens.push(token);
    });
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
  await recordPlatformRevenue(db, { txId, fromUserId, toUserId, grossAmount: price, platformFee: calcFees(price).platformFee, creatorPayout: calcFees(price).creatorPayout });
}

// ─────────────────────────────────────────────────────────────
// sendTransaction
// ─────────────────────────────────────────────────────────────

exports.sendTransaction = onCall({ cors: ['*'], maxInstances: 50 }, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId = request.auth.uid;
  const { onAppRecipientIds = [], offAppPhoneHashes = [], offAppRecipientNames = {}, price, photoUrl } = request.data;

  if (!price || price < MIN_PRICE || price > MAX_PRICE) throw new Error(`Price must be between $${MIN_PRICE} and $${MAX_PRICE}`);
  if (!photoUrl)                                        throw new Error('photoUrl is required');

  const db          = getDb();
  const validOnApp  = onAppRecipientIds.filter(id => id !== userId);
  const validOffApp = [...new Set(offAppPhoneHashes)];
  const totalCount  = validOnApp.length + validOffApp.length;

  if (totalCount === 0) throw new Error('At least one recipient required');

  const { platformFee, creatorPayout } = calcFees(price);
  const senderName = await getUserName(db, userId);

  const createdTxIds = [];
  const txBase = {
    type:           'offer',
    from_user_id:   userId,
    price,
    platform_fee:   platformFee,
    creator_payout: creatorPayout,
    status:         'pending_acceptance',
    photo_url:      photoUrl,
    rating:         null,
    dismissed_by:   [],
    created_at:     admin.firestore.FieldValue.serverTimestamp(),
    accepted_at:    null,
    completed_at:   null
  };

  for (const recipientId of validOnApp) {
    const txRef = db.collection('content_transactions').doc();
    await txRef.set({ ...txBase, id: txRef.id, to_user_id: recipientId, pending_phone_hash: null, pending_name: null });
    createdTxIds.push(txRef.id);
  }

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
      title: `${senderName} sent you a mystery drop 🎁`,
      body:  `Pay $${price.toFixed(2)} to unlock what they sent you`,
      data:  { type: 'offer_received' }
    });
  }

  logger.info(`sendTransaction: ${userId} sent offer to ${totalCount} recipients, $${price} each`);
  return { success: true, transactionIds: createdTxIds };
});

// ─────────────────────────────────────────────────────────────
// respondToTransaction
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

  if (tx.type !== 'offer')                throw new Error('Only offers can be responded to');
  if (tx.to_user_id !== userId)           throw new Error('You are not the recipient');
  if (tx.status !== 'pending_acceptance') throw new Error(`Cannot respond to status: ${tx.status}`);

  const senderName    = await getUserName(db, tx.from_user_id);
  const recipientName = await getUserName(db, userId);

  if (!accept) {
    await txRef.update({ status: 'declined' });
    await sendPush(db, [tx.from_user_id], {
      title: `${recipientName} declined your offer`,
      body:  `${recipientName} passed on your offer`,
      data:  { type: 'transaction_declined', transaction_id: transactionId }
    });
    logger.info(`respondToTransaction: ${userId} declined offer ${transactionId}`);
    return { success: true };
  }

  await db.runTransaction(async (t) => {
    const payerRef = db.collection('users').doc(userId);
    const payerDoc = await t.get(payerRef);
    const balance  = payerDoc.data()?.wallet_balance ?? 0;
    if (balance < tx.price) throw new Error(`Insufficient funds. Balance: $${balance.toFixed(2)}, Required: $${tx.price.toFixed(2)}`);
    const newBalance = parseFloat((balance - tx.price).toFixed(2));
    t.set(payerRef, { wallet_balance: admin.firestore.FieldValue.increment(-tx.price) }, { merge: true });
    t.update(txRef, {
      status:       'completed',
      accepted_at:  admin.firestore.FieldValue.serverTimestamp(),
      completed_at: admin.firestore.FieldValue.serverTimestamp()
    });
    await recordWalletTx(t, {
      userId,
      type:          'debit',
      amount:        tx.price,
      reason:        'offer_payment',
      txId:          transactionId,
      metadata:      { from_user_id: tx.from_user_id },
      balanceBefore: balance,
      balanceAfter:  newBalance
    });
  });

  await payCreator(db, { txId: transactionId, creatorId: tx.from_user_id, fromUserId: tx.from_user_id, toUserId: userId, price: tx.price });

  const payerName = await getUserName(db, userId);
  await sendPush(db, [tx.from_user_id], {
    title: `${payerName} unlocked your offer 💰`,
    body:  `You earned $${tx.creator_payout.toFixed(2)}!`,
    data:  { type: 'offer_accepted', transaction_id: transactionId }
  });
  await sendPush(db, [userId], {
    title: `You unlocked ${senderName}'s photo 🎁`,
    body:  'Tap to see what they sent you',
    data:  { type: 'offer_unlocked', transaction_id: transactionId }
  });

  logger.info(`respondToTransaction: ${userId} accepted offer ${transactionId}`);
  return { success: true };
});

exports.markTransactionViewed = onCall({ cors: ['*'], maxInstances: 50 }, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');
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
  if (!rating || rating < 1 || rating > 5 || !Number.isInteger(rating)) throw new Error('Rating must be an integer between 1 and 5');

  const db    = getDb();
  const txRef = db.collection('content_transactions').doc(transactionId);
  const txDoc = await txRef.get();

  if (!txDoc.exists) throw new Error('Transaction not found');
  const tx = txDoc.data();

  if (tx.to_user_id !== userId)  throw new Error('You cannot rate this transaction');
  if (tx.status !== 'completed') throw new Error('Can only rate completed transactions');
  if (tx.rating !== null && tx.rating !== undefined) throw new Error('Already rated');

  await db.runTransaction(async (t) => {
    const creatorRef = db.collection('users').doc(tx.from_user_id);
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
  await sendPush(db, [tx.from_user_id], {
    title: `${payerName} rated your photo ${rating}⭐`,
    body:  rating >= 4 ? 'They loved it! 🔥' : 'Keep it up!',
    data:  { type: 'content_rated', transaction_id: transactionId }
  });

  logger.info(`rateTransaction: ${userId} rated ${transactionId} with ${rating} stars`);
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

  if (!txDoc.exists) { logger.info(`resolveInviteTransaction: ${transactionId} not found, skipping`); return { success: true, skipped: true }; }

  const tx = txDoc.data();
  if (tx.status !== 'pending_signup') return { success: true, skipped: true };

  await txRef.update({ to_user_id: userId, status: 'pending_acceptance' });

  const senderName = await getUserName(db, tx.from_user_id);
  await sendPush(db, [userId], {
    title: `${senderName} sent you a mystery drop 🎁`,
    body:  `Pay $${tx.price.toFixed(2)} to unlock what they sent you`,
    data:  { type: 'offer_received', transaction_id: transactionId }
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
