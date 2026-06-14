/**
 * contentFunctions.js
 *
 * EXPORTS — index.js:
 *   exports.sendTransaction          = content.sendTransaction;
 *   exports.respondToTransaction     = content.respondToTransaction;
 *   exports.fulfillRequest           = content.fulfillRequest;
 *   exports.rateTransaction          = content.rateTransaction;
 *   exports.cancelRequest            = content.cancelRequest;
 *   exports.resolveInviteTransaction = content.resolveInviteTransaction;
 *   exports.markTransactionViewed    = content.markTransactionViewed;
 *
 * FLOW
 * ────
 * REQUEST:
 *   sendTransaction     → escrow price from A → pending_acceptance
 *   cancelRequest       → refund A → cancelled          (allowed until fulfilled)
 *   respondToTransaction (decline) → refund A → declined
 *   respondToTransaction (accept)  → accepted
 *   fulfillRequest      → pay creator 80%, platform 20% → fulfilled
 *   markTransactionViewed → completed (pure UX, no money)
 *   rateTransaction     → updates creator avg rating only (no status change)
 *
 * OFFER:
 *   sendTransaction     → pending_acceptance (no money)
 *   respondToTransaction (decline) → declined (nothing to refund)
 *   respondToTransaction (accept)  → pay creator 80%, platform 20% → completed
 *   markTransactionViewed → no-op (already completed, photo available in history)
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

// ─────────────────────────────────────────────────────────────
// HELPER — record wallet transaction
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

// ─────────────────────────────────────────────────────────────
// HELPER — record platform revenue
// ─────────────────────────────────────────────────────────────

async function recordPlatformRevenue(db, { txId, fromUserId, toUserId, grossAmount, platformFee, creatorPayout, type }) {
  await db.collection('platform_revenue').doc().set({
    transaction_id:  txId,
    from_user_id:    fromUserId,
    to_user_id:      toUserId,
    type,
    gross_amount:    grossAmount,
    platform_fee:    platformFee,
    creator_payout:  creatorPayout,
    collected_at:    admin.firestore.FieldValue.serverTimestamp()
  });
}

// ─────────────────────────────────────────────────────────────
// HELPER — send FCM push
// ─────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────
// HELPER — fee calculation
// ─────────────────────────────────────────────────────────────

function calcFees(price) {
  const platformFee   = parseFloat((price * PLATFORM_FEE_RATE).toFixed(2));
  const creatorPayout = parseFloat((price - platformFee).toFixed(2));
  return { platformFee, creatorPayout };
}

// ─────────────────────────────────────────────────────────────
// HELPER — get user name
// ─────────────────────────────────────────────────────────────

async function getUserName(db, userId) {
  const doc = await db.collection('users').doc(userId).get();
  return doc.data()?.name ?? 'Someone';
}

// ─────────────────────────────────────────────────────────────
// HELPER — pay out creator and record platform revenue
// ─────────────────────────────────────────────────────────────

async function payCreator(db, { txId, creatorId, fromUserId, toUserId, price, type }) {
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
    grossAmount:   price,
    platformFee,
    creatorPayout,
    type
  });
}

// ─────────────────────────────────────────────────────────────
// sendTransaction
// ─────────────────────────────────────────────────────────────

exports.sendTransaction = onCall({
  cors: ['*'],
  maxInstances: 50
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId = request.auth.uid;
  const {
    type,
    onAppRecipientIds = [],
    offAppPhoneHashes = [],
    price,
    description,
    photoUrl = null
  } = request.data;

  if (!['request', 'offer'].includes(type))              throw new Error('Invalid type');
  if (!price || price < MIN_PRICE || price > MAX_PRICE)  throw new Error(`Price must be between $${MIN_PRICE} and $${MAX_PRICE}`);
  if (!description || description.trim().length === 0)   throw new Error('Description is required');
  if (description.trim().length > 120)                   throw new Error('Description max 120 chars');
  if (type === 'offer' && !photoUrl)                     throw new Error('photoUrl is required for offers');

  const db         = getDb();
  const validOnApp = onAppRecipientIds.filter(id => id !== userId);
  const validOffApp = [...new Set(offAppPhoneHashes)];
  const totalCount = validOnApp.length + validOffApp.length;

  if (totalCount === 0) throw new Error('At least one recipient required');

  const { platformFee, creatorPayout } = calcFees(price);
  const senderName = await getUserName(db, userId);

  // Requests: escrow price × totalCount upfront
  if (type === 'request') {
    const totalEscrow = parseFloat((price * totalCount).toFixed(2));

    await db.runTransaction(async (t) => {
      const userRef  = db.collection('users').doc(userId);
      const userDoc  = await t.get(userRef);
      const balance  = userDoc.data()?.wallet_balance ?? 0;

      if (balance < totalEscrow) {
        throw new Error(`Insufficient funds. Need $${totalEscrow.toFixed(2)} for ${totalCount} friends. Balance: $${balance.toFixed(2)}`);
      }

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
  }

  const createdTxIds = [];
  const txBase = {
    type,
    from_user_id:   userId,
    price,
    platform_fee:   platformFee,
    creator_payout: creatorPayout,
    description:    description.trim(),
    status:         'pending_acceptance',
    photo_url:      photoUrl,
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
    await txRef.set({ ...txBase, id: txRef.id, to_user_id: recipientId, pending_phone_hash: null });
    createdTxIds.push(txRef.id);
  }

  // Off-app recipients
  const inviterDoc  = await db.collection('users').doc(userId).get();
  const inviterHash = inviterDoc.data()?.phoneNumberHash ?? '';

  for (const phoneHash of validOffApp) {
    const txRef = db.collection('content_transactions').doc();
    await txRef.set({
      ...txBase,
      id:                  txRef.id,
      to_user_id:          null,
      status:              'pending_signup',
      pending_phone_hash:  phoneHash
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

  // Push to on-app recipients
  if (validOnApp.length > 0) {
    const notifTitle = type === 'request'
      ? `${senderName} wants a photo from you 📸`
      : `${senderName} sent you a mystery drop 🎁`;
    const notifBody = type === 'request'
      ? `They'll pay you $${price.toFixed(2)} — accept their request!`
      : `Pay $${price.toFixed(2)} to unlock what they sent you`;

    await sendPush(db, validOnApp, {
      title: notifTitle,
      body:  notifBody,
      data:  { type: type === 'request' ? 'request_received' : 'offer_received' }
    });
  }

  logger.info(`sendTransaction: ${userId} sent ${type} to ${totalCount} recipients, $${price} each`);
  return { success: true, transactionIds: createdTxIds };
});

// ─────────────────────────────────────────────────────────────
// respondToTransaction
//
// REQUEST — accept → accepted, decline → refund → declined
// OFFER   — accept → pay creator → completed, decline → declined
// ─────────────────────────────────────────────────────────────

exports.respondToTransaction = onCall({
  cors: ['*'],
  maxInstances: 50
}, async (request) => {
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

  if (tx.to_user_id !== userId)        throw new Error('You are not the recipient');
  if (tx.status !== 'pending_acceptance') throw new Error(`Cannot respond to status: ${tx.status}`);

  const senderName    = await getUserName(db, tx.from_user_id);
  const recipientName = await getUserName(db, userId);

  // ── Decline ───────────────────────────────────────────────
  if (!accept) {
    await db.runTransaction(async (t) => {
      // ALL READS FIRST
      let fromDoc = null;
      if (tx.type === 'request') {
        const fromRef = db.collection('users').doc(tx.from_user_id);
        fromDoc = await t.get(fromRef);
      }

      // THEN ALL WRITES
      t.update(txRef, { status: 'declined' });

      if (tx.type === 'request' && fromDoc) {
        const fromRef  = db.collection('users').doc(tx.from_user_id);
        const balance  = fromDoc.data()?.wallet_balance ?? 0;
        const newBal   = parseFloat((balance + tx.price).toFixed(2));

        t.set(fromRef, { wallet_balance: admin.firestore.FieldValue.increment(tx.price) }, { merge: true });
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
      }
    });

    await sendPush(db, [tx.from_user_id], {
      title: `${recipientName} declined your ${tx.type}`,
      body:  tx.type === 'request' ? 'Your escrow has been refunded' : `${recipientName} passed on your offer`,
      data:  { type: 'transaction_declined', transaction_id: transactionId }
    });

    logger.info(`respondToTransaction: ${userId} declined ${transactionId}`);
    return { success: true };
  }

  // ── Accept — Request ──────────────────────────────────────
  if (tx.type === 'request') {
    await txRef.update({
      status:      'accepted',
      accepted_at: admin.firestore.FieldValue.serverTimestamp()
    });

    await sendPush(db, [tx.from_user_id], {
      title: `${recipientName} accepted your request! 🎉`,
      body:  "They're working on your photo now",
      data:  { type: 'request_accepted', transaction_id: transactionId }
    });

    logger.info(`respondToTransaction: ${userId} accepted request ${transactionId}`);
    return { success: true };
  }

  // ── Accept — Offer ────────────────────────────────────────
  // Escrow from payer, pay creator immediately, set completed
  await db.runTransaction(async (t) => {
    const payerRef  = db.collection('users').doc(userId);
    const payerDoc  = await t.get(payerRef);
    const balance   = payerDoc.data()?.wallet_balance ?? 0;

    if (balance < tx.price) {
      throw new Error(`Insufficient funds. Balance: $${balance.toFixed(2)}, Required: $${tx.price.toFixed(2)}`);
    }

    const newBalance = parseFloat((balance - tx.price).toFixed(2));
    t.set(payerRef, { wallet_balance: admin.firestore.FieldValue.increment(-tx.price) }, { merge: true });

    t.update(txRef, {
      status:      'completed',
      accepted_at: admin.firestore.FieldValue.serverTimestamp(),
      completed_at: admin.firestore.FieldValue.serverTimestamp()
    });

    await recordWalletTx(t, {
      userId,
      type:          'debit',
      amount:        tx.price,
      reason:        'offer_escrow',
      txId:          transactionId,
      metadata:      { from_user_id: tx.from_user_id },
      balanceBefore: balance,
      balanceAfter:  newBalance
    });
  });

  // Pay creator outside the payer transaction
  await payCreator(db, {
    txId:       transactionId,
    creatorId:  tx.from_user_id,
    fromUserId: tx.from_user_id,
    toUserId:   userId,
    price:      tx.price,
    type:       'offer'
  });

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

// ─────────────────────────────────────────────────────────────
// fulfillRequest
//
// Creator uploads photo → pay creator → status: fulfilled
// Money moves here. A views photo via markTransactionViewed.
// ─────────────────────────────────────────────────────────────

exports.fulfillRequest = onCall({
  cors: ['*'],
  maxInstances: 50
}, async (request) => {
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

  if (tx.type !== 'request')    throw new Error('Can only fulfill requests');
  if (tx.to_user_id !== userId) throw new Error('You are not the creator');
  if (tx.status !== 'accepted') throw new Error(`Cannot fulfill status: ${tx.status}`);

  // Update transaction — fulfilled, photo attached
  await txRef.update({
    status:       'fulfilled',
    photo_url:    photoUrl,
    fulfilled_at: admin.firestore.FieldValue.serverTimestamp()
  });

  // Pay creator now — money moves at fulfillment
  await payCreator(db, {
    txId:       transactionId,
    creatorId:  userId,
    fromUserId: tx.from_user_id,
    toUserId:   userId,
    price:      tx.price,
    type:       'request'
  });

  const creatorName = await getUserName(db, userId);

  await sendPush(db, [tx.from_user_id], {
    title: `${creatorName} sent your photo 👀`,
    body:  'Tap to see what they sent you!',
    data:  { type: 'request_fulfilled', transaction_id: transactionId }
  });

  logger.info(`fulfillRequest: ${userId} fulfilled ${transactionId}, creator paid $${tx.creator_payout}`);
  return { success: true };
});

// ─────────────────────────────────────────────────────────────
// markTransactionViewed
//
// Called when payer opens and views the photo.
// Pure UX — no money moves. Sets status to completed.
// ─────────────────────────────────────────────────────────────

exports.markTransactionViewed = onCall({
  cors: ['*'],
  maxInstances: 50
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId = request.auth.uid;
  const { transactionId } = request.data;

  if (!transactionId) throw new Error('transactionId is required');

  const db    = getDb();
  const txRef = db.collection('content_transactions').doc(transactionId);
  const txDoc = await txRef.get();

  if (!txDoc.exists) throw new Error('Transaction not found');

  const tx = txDoc.data();

  // Only the payer (requester) marks as viewed on requests
  if (tx.from_user_id !== userId) throw new Error('Only the requester can mark as viewed');
  if (tx.type !== 'request')      throw new Error('Only requests need marking as viewed');
  if (tx.status !== 'fulfilled')  {
    // Already completed or wrong state — silent success
    return { success: true };
  }

  await txRef.update({
    status:       'completed',
    completed_at: admin.firestore.FieldValue.serverTimestamp()
  });

  logger.info(`markTransactionViewed: ${userId} viewed ${transactionId}`);
  return { success: true };
});

// ─────────────────────────────────────────────────────────────
// rateTransaction
//
// Optional. Updates creator's average rating only.
// No status change — transaction stays completed.
// Can be called from history view at any time after completion.
// ─────────────────────────────────────────────────────────────

exports.rateTransaction = onCall({
  cors: ['*'],
  maxInstances: 50
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId = request.auth.uid;
  const { transactionId, rating } = request.data;

  if (!transactionId)                                       throw new Error('transactionId is required');
  if (!rating || rating < 1 || rating > 5 || !Number.isInteger(rating))
    throw new Error('Rating must be an integer between 1 and 5');

  const db    = getDb();
  const txRef = db.collection('content_transactions').doc(transactionId);
  const txDoc = await txRef.get();

  if (!txDoc.exists) throw new Error('Transaction not found');

  const tx = txDoc.data();

  // Payer rates — different for request vs offer
  const isCorrectUser = tx.type === 'request'
    ? tx.from_user_id === userId   // requester rates
    : tx.to_user_id   === userId;  // offer recipient rates

  if (!isCorrectUser) throw new Error('You cannot rate this transaction');

  if (tx.status !== 'completed') throw new Error('Can only rate completed transactions');
  if (tx.rating !== null && tx.rating !== undefined) throw new Error('Already rated');

  const creatorId = tx.type === 'request' ? tx.to_user_id : tx.from_user_id;

  await db.runTransaction(async (t) => {
    const creatorRef = db.collection('users').doc(creatorId);
    const creatorDoc = await t.get(creatorRef);
    const data       = creatorDoc.data() ?? {};
    const oldCount   = data.ratingCount   ?? 0;
    const oldAvg     = data.averageRating ?? 0;
    const newCount   = oldCount + 1;
    const newAvg     = parseFloat(((oldAvg * oldCount + rating) / newCount).toFixed(2));

    t.set(creatorRef, {
      ratingCount:   newCount,
      averageRating: newAvg
    }, { merge: true });

    // Store rating on transaction but don't change status
    t.update(txRef, { rating });
  });

  const payerName = await getUserName(db, userId);

  await sendPush(db, [creatorId], {
    title: `${payerName} rated your photo ${rating}⭐`,
    body:  rating >= 4 ? 'They loved it! 🔥' : 'Keep it up!',
    data:  { type: 'content_rated', transaction_id: transactionId }
  });

  logger.info(`rateTransaction: ${userId} rated ${transactionId} with ${rating} stars`);
  return { success: true };
});

// ─────────────────────────────────────────────────────────────
// cancelRequest
//
// Sender cancels a request before creator fulfills it.
// Allowed in: pending_signup, pending_acceptance, accepted
// Blocked in: fulfilled, completed (creator already did the work)
// ─────────────────────────────────────────────────────────────

exports.cancelRequest = onCall({
  cors: ['*'],
  maxInstances: 50
}, async (request) => {
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
  if (tx.type !== 'request')      throw new Error('Only requests can be cancelled');

  const cancellable = ['pending_signup', 'pending_acceptance', 'accepted'];
  if (!cancellable.includes(tx.status)) {
    throw new Error(`Cannot cancel — creator has already fulfilled this request`);
  }

  // Refund escrow
  await db.runTransaction(async (t) => {
    // Read first
    const userRef = db.collection('users').doc(userId);
    const userDoc = await t.get(userRef);
    const balance = userDoc.data()?.wallet_balance ?? 0;
    const newBal  = parseFloat((balance + tx.price).toFixed(2));

    // Then write
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

  // Notify recipient if already on app
  if (tx.to_user_id) {
    const senderName = await getUserName(db, userId);
    await sendPush(db, [tx.to_user_id], {
      title: `${senderName} cancelled their request`,
      body:  'The request has been withdrawn',
      data:  { type: 'request_cancelled', transaction_id: transactionId }
    });
  }

  logger.info(`cancelRequest: ${userId} cancelled ${transactionId}, $${tx.price} refunded`);
  return { success: true };
});

// ─────────────────────────────────────────────────────────────
// resolveInviteTransaction
//
// Called from NameEntryView after signup.
// Finds pending transactions for this user's phone hash,
// fills in toUserId, moves to pending_acceptance, sends push.
// ─────────────────────────────────────────────────────────────

exports.resolveInviteTransaction = onCall({
  cors: ['*'],
  maxInstances: 50
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId            = request.auth.uid;
  const { transactionId } = request.data;

  if (!transactionId) throw new Error('transactionId is required');

  const db    = getDb();
  const txRef = db.collection('content_transactions').doc(transactionId);
  const txDoc = await txRef.get();

  if (!txDoc.exists) {
    logger.info(`resolveInviteTransaction: ${transactionId} not found, skipping`);
    return { success: true, skipped: true };
  }

  const tx = txDoc.data();

  if (tx.status !== 'pending_signup') {
    return { success: true, skipped: true };
  }

  await txRef.update({
    to_user_id: userId,
    status:     'pending_acceptance'
  });

  const senderName = await getUserName(db, tx.from_user_id);

  const notifTitle = tx.type === 'request'
    ? `${senderName} wants a photo from you 📸`
    : `${senderName} sent you a mystery drop 🎁`;
  const notifBody = tx.type === 'request'
    ? `They'll pay you $${tx.price.toFixed(2)} — open SocialStar to respond!`
    : `Pay $${tx.price.toFixed(2)} to unlock what they sent you`;

  await sendPush(db, [userId], {
    title: notifTitle,
    body:  notifBody,
    data:  { type: tx.type === 'request' ? 'request_received' : 'offer_received', transaction_id: transactionId }
  });

  logger.info(`resolveInviteTransaction: resolved ${transactionId} for ${userId}`);
  return { success: true, skipped: false };
});


// ─────────────────────────────────────────────────────────────
// dismissTransaction
//
// Appends currentUserId to dismissed_by array on the transaction.
// Each user independently controls their own inbox view.
// The other party is completely unaffected.
// ─────────────────────────────────────────────────────────────

exports.dismissTransaction = onCall({
  cors: ['*'],
  maxInstances: 50
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId            = request.auth.uid;
  const { transactionId } = request.data;

  if (!transactionId) throw new Error('transactionId is required');

  const db    = getDb();
  const txRef = db.collection('content_transactions').doc(transactionId);
  const txDoc = await txRef.get();

  if (!txDoc.exists) throw new Error('Transaction not found');

  const tx = txDoc.data();

  // Verify user is a party to this transaction
  if (tx.from_user_id !== userId && tx.to_user_id !== userId) {
    throw new Error('You are not a party to this transaction');
  }

  await txRef.update({
    dismissed_by: admin.firestore.FieldValue.arrayUnion(userId)
  });

  logger.info(`dismissTransaction: ${userId} dismissed ${transactionId}`);
  return { success: true };
});
