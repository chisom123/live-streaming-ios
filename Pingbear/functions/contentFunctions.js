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
 * REQUEST (payer asks, creator records):
 *   sendTransaction          → escrow reward from payer (bonus spent first) → pending_acceptance
 *   cancelRequest            → refund payer (bonus/real restored proportionally) → cancelled
 *   respondToTransaction (decline) → refund payer (bonus/real restored proportionally) → declined
 *   respondToTransaction (accept)  → accepted
 *   fulfillRequest           → pay creator 80%, platform 20% → fulfilled
 *   markTransactionViewed    → completed (no money)
 *   rateTransaction          → updates creator avg rating (no status change)
 *
 * OFFER (creator records mystery video upfront, payer unlocks):
 *   sendTransaction          → pending_acceptance (no money moved, video already attached)
 *   respondToTransaction (decline) → declined (nothing to refund)
 *   respondToTransaction (accept)  → pay creator 80%, platform 20% (bonus spent first) → completed
 *   rateTransaction          → updates creator avg rating (no status change)
 *
 * BONUS MONEY
 * ───────────
 * Every debit (request escrow, offer payment) spends bonus_balance
 * before real money — see walletHelpers.splitDebit. Each
 * content_transaction doc stores funded_bonus_amount /
 * funded_real_amount so refunds and payouts can trace back to their
 * funding source. Creator payouts are always real money regardless of
 * funding source — payCreator never touches the recipient's
 * bonus_balance. platform_revenue records the split too, so
 * bonus-funded fee revenue can be excluded from "real" revenue
 * reporting via real_revenue_fee.
 */

const { onCall } = require('firebase-functions/v2/https');
const admin      = require('firebase-admin');
const logger     = require('firebase-functions/logger');
const { round2, splitDebit } = require('./walletHelpers');

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

async function recordPlatformRevenue(db, {
  txId, fromUserId, toUserId, grossAmount, platformFee, creatorPayout, type,
  bonusFundedAmount = 0, realFundedAmount = null, realRevenueFee = null
}) {
  const realFunded = realFundedAmount ?? grossAmount;
  const realFee     = realRevenueFee ?? platformFee;
  await db.collection('platform_revenue').doc().set({
    transaction_id:      txId,
    from_user_id:        fromUserId,
    to_user_id:          toUserId,
    type,
    gross_amount:        grossAmount,
    platform_fee:        platformFee,
    creator_payout:      creatorPayout,
    bonus_funded_amount: bonusFundedAmount,
    real_funded_amount:  realFunded,
    // Only this portion is real, collected revenue. The rest of
    // platform_fee was generated from bonus money the platform itself
    // funded — exclude it when reporting actual revenue.
    real_revenue_fee:    realFee,
    collected_at:        admin.firestore.FieldValue.serverTimestamp()
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
  const platformFee   = round2(price * PLATFORM_FEE_RATE);
  const creatorPayout = round2(price - platformFee);
  return { platformFee, creatorPayout };
}

async function getUserName(db, userId) {
  const doc = await db.collection('users').doc(userId).get();
  return doc.data()?.name ?? 'Someone';
}

// Creator payout is always real money for the recipient — their
// bonus_balance is never touched here, regardless of how the payer
// funded the original transaction.
async function payCreator(db, { txId, creatorId, fromUserId, toUserId, price, type, bonusFundedAmount = 0, realFundedAmount = null }) {
  const { platformFee, creatorPayout } = calcFees(price);
  const realFunded = realFundedAmount ?? round2(price - bonusFundedAmount);

  await db.runTransaction(async (t) => {
    const creatorRef = db.collection('users').doc(creatorId);
    const creatorDoc = await t.get(creatorRef);
    const creatorBal = creatorDoc.data()?.wallet_balance ?? 0;
    const newBal      = round2(creatorBal + creatorPayout);
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
      metadata:      {
        gross_amount: price, platform_fee: platformFee, transaction_type: type,
        funded_by_bonus: bonusFundedAmount, funded_by_real: realFunded
      },
      balanceBefore: creatorBal,
      balanceAfter:  newBal
    });
  });

  const realRevenueFee = price > 0 ? round2(platformFee * (realFunded / price)) : 0;

  await recordPlatformRevenue(db, {
    txId, fromUserId, toUserId,
    grossAmount: price, platformFee, creatorPayout, type,
    bonusFundedAmount, realFundedAmount: realFunded, realRevenueFee
  });
}

// ─────────────────────────────────────────────────────────────
// sendTransaction
//
// REQUEST: escrow reward × recipient count upfront (bonus spent
//          first), splits the bonus used evenly across recipients
//          and stores it per-doc for later refund/payout tracing.
// OFFER:   video required upfront, no money moves until accepted.
// ─────────────────────────────────────────────────────────────

exports.sendTransaction = onCall({ cors: ['*'], maxInstances: 50 }, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId = request.auth.uid;
  const {
    type,
    onAppRecipientIds    = [],
    offAppPhoneHashes    = [],
    offAppRecipientNames = {},
    price,
    description = '',
    photoUrl = null   // video URL — required for offers, ignored for requests
  } = request.data;

  if (!['request', 'offer'].includes(type))             throw new Error('Invalid type');
  if (!price || price < MIN_PRICE || price > MAX_PRICE) throw new Error(`Price must be between $${MIN_PRICE} and $${MAX_PRICE}`);

  if (type === 'request') {
    if (!description || description.trim().length === 0) throw new Error('Description is required');
    if (description.trim().length > 120)                  throw new Error('Description max 120 chars');
  }
  if (type === 'offer' && !photoUrl) throw new Error('A video is required for offers');

  const db          = getDb();
  const validOnApp  = onAppRecipientIds.filter(id => id !== userId);
  const validOffApp = [...new Set(offAppPhoneHashes)];
  const totalCount  = validOnApp.length + validOffApp.length;

  if (totalCount === 0) throw new Error('At least one recipient required');

  const { platformFee, creatorPayout } = calcFees(price);
  const senderName = await getUserName(db, userId);

  // Requests escrow the full reward upfront, bonus spent first.
  // Offers don't move money on send.
  let bonusUsedTotal = 0;
  if (type === 'request') {
    const totalEscrow = round2(price * totalCount);
    await db.runTransaction(async (t) => {
      const userRef = db.collection('users').doc(userId);
      const userDoc = await t.get(userRef);
      const balance = userDoc.data()?.wallet_balance ?? 0;
      const bonus   = userDoc.data()?.bonus_balance ?? 0;
      if (balance < totalEscrow) throw new Error(`Insufficient funds. Need $${totalEscrow.toFixed(2)}, balance $${balance.toFixed(2)}`);

      const split = splitDebit(bonus, totalEscrow);
      bonusUsedTotal = split.bonusUsed;

      const newBalance = round2(balance - totalEscrow);
      t.set(userRef, {
        wallet_balance: admin.firestore.FieldValue.increment(-totalEscrow),
        bonus_balance:  admin.firestore.FieldValue.increment(-split.bonusUsed)
      }, { merge: true });
      await recordWalletTx(t, {
        userId,
        type:          'debit',
        amount:        totalEscrow,
        reason:        'request_escrow',
        metadata:      { recipient_count: totalCount, bonus_used: split.bonusUsed, real_used: split.realUsed },
        balanceBefore: balance,
        balanceAfter:  newBalance
      });
    });
  }

  // Split the bonus used evenly across recipients (each owes the
  // same `price`), giving any rounding remainder to the last one so
  // the per-recipient amounts always sum back to the total escrowed.
  let bonusRemaining  = bonusUsedTotal;
  let recipientsSoFar = 0;
  function nextFundingSplit() {
    recipientsSoFar++;
    const isLast = recipientsSoFar === totalCount;
    let bonusShare;
    if (isLast) {
      bonusShare = bonusRemaining;
    } else {
      bonusShare = round2(Math.min(price, bonusUsedTotal / totalCount));
      bonusRemaining = round2(bonusRemaining - bonusShare);
    }
    return { bonusShare, realShare: round2(price - bonusShare) };
  }

  const createdTxIds = [];
  const txBase = {
    type,
    from_user_id:   userId,
    price,
    platform_fee:   platformFee,
    creator_payout: creatorPayout,
    description:    type === 'request' ? description.trim() : '',
    status:         'pending_acceptance',
    photo_url:      type === 'offer' ? photoUrl : null,
    rating:         null,
    dismissed_by:   [],
    // Set here for requests (escrowed now); set at accept-time for offers.
    funded_bonus_amount: null,
    funded_real_amount:  null,
    created_at:     admin.firestore.FieldValue.serverTimestamp(),
    accepted_at:    null,
    fulfilled_at:   null,
    completed_at:   null
  };

  // On-app recipients
  for (const recipientId of validOnApp) {
    const txRef   = db.collection('content_transactions').doc();
    const funding = type === 'request' ? nextFundingSplit() : { bonusShare: null, realShare: null };
    await txRef.set({
      ...txBase, id: txRef.id, to_user_id: recipientId, pending_phone_hash: null, pending_name: null,
      funded_bonus_amount: funding.bonusShare,
      funded_real_amount:  funding.realShare
    });
    createdTxIds.push(txRef.id);
  }

  // Off-app recipients
  const inviterDoc  = await db.collection('users').doc(userId).get();
  const inviterHash = inviterDoc.data()?.phoneNumberHash ?? '';

  for (const phoneHash of validOffApp) {
    const txRef        = db.collection('content_transactions').doc();
    const pendingName  = offAppRecipientNames[phoneHash] ?? null;
    const funding      = type === 'request' ? nextFundingSplit() : { bonusShare: null, realShare: null };
    await txRef.set({
      ...txBase,
      id:                  txRef.id,
      to_user_id:          null,
      status:              'pending_signup',
      pending_phone_hash:  phoneHash,
      pending_name:        pendingName,
      funded_bonus_amount: funding.bonusShare,
      funded_real_amount:  funding.realShare
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
    const notifTitle = type === 'request'
      ? `${senderName} wants a video from you!`
      : `${senderName} sent you a mystery video!`;
    const notifBody = type === 'request'
      ? `Your reward is $${price.toFixed(2)} — accept their request`
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
// REQUEST — accept → accepted, decline → refund (bonus/real restored) → declined
// OFFER   — accept → debit payer (bonus spent first), pay creator → completed
//           decline → declined (nothing to refund)
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

  if (tx.to_user_id !== userId)           throw new Error('You are not the recipient');
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
        const fromRef      = db.collection('users').doc(tx.from_user_id);
        const balance       = fromDoc.data()?.wallet_balance ?? 0;
        const bonusPortion  = tx.funded_bonus_amount ?? 0;
        const realPortion   = tx.funded_real_amount ?? tx.price;
        const refundAmount  = round2(bonusPortion + realPortion);
        const newBal        = round2(balance + refundAmount);

        // Restore each pool to where it came from — bonus money goes
        // back into bonus_balance (still non-withdrawable).
        t.set(fromRef, {
          wallet_balance: admin.firestore.FieldValue.increment(refundAmount),
          bonus_balance:  admin.firestore.FieldValue.increment(bonusPortion)
        }, { merge: true });

        await recordWalletTx(t, {
          userId:        tx.from_user_id,
          type:          'credit',
          amount:        refundAmount,
          reason:        'escrow_refund',
          txId:          transactionId,
          metadata:      { reason: 'recipient_declined', bonus_restored: bonusPortion, real_restored: realPortion },
          balanceBefore: balance,
          balanceAfter:  newBal
        });
      }
    });

    await sendPush(db, [tx.from_user_id], {
      title: `${recipientName} declined your ${tx.type}`,
      body:  tx.type === 'request' ? 'Your funds have been refunded' : `${recipientName} passed on your offer`,
      data:  { type: 'transaction_declined', transaction_id: transactionId }
    });

    logger.info(`respondToTransaction: ${userId} declined ${tx.type} ${transactionId}`);
    return { success: true };
  }

  // ── Accept — Request ──────────────────────────────────────
  if (tx.type === 'request') {
    await txRef.update({
      status:      'accepted',
      accepted_at: admin.firestore.FieldValue.serverTimestamp()
    });

    await sendPush(db, [tx.from_user_id], {
      title: `${recipientName} accepted your request!`,
      body:  "They're working on your video now",
      data:  { type: 'request_accepted', transaction_id: transactionId }
    });

    logger.info(`respondToTransaction: ${userId} accepted request ${transactionId}`);
    return { success: true };
  }

  // ── Accept — Offer (money moves here, bonus spent first) ───
  let offerBonusUsed = 0;
  let offerRealUsed  = 0;

  await db.runTransaction(async (t) => {
    const payerRef = db.collection('users').doc(userId);
    const payerDoc = await t.get(payerRef);
    const balance  = payerDoc.data()?.wallet_balance ?? 0;
    const bonus    = payerDoc.data()?.bonus_balance ?? 0;

    if (balance < tx.price) {
      throw new Error(`Insufficient funds. Balance: $${balance.toFixed(2)}, Required: $${tx.price.toFixed(2)}`);
    }

    const split = splitDebit(bonus, tx.price);
    offerBonusUsed = split.bonusUsed;
    offerRealUsed  = split.realUsed;

    const newBalance = round2(balance - tx.price);
    t.set(payerRef, {
      wallet_balance: admin.firestore.FieldValue.increment(-tx.price),
      bonus_balance:  admin.firestore.FieldValue.increment(-split.bonusUsed)
    }, { merge: true });

    t.update(txRef, {
      status:              'completed',
      accepted_at:         admin.firestore.FieldValue.serverTimestamp(),
      completed_at:        admin.firestore.FieldValue.serverTimestamp(),
      funded_bonus_amount: split.bonusUsed,
      funded_real_amount:  split.realUsed
    });

    await recordWalletTx(t, {
      userId,
      type:          'debit',
      amount:        tx.price,
      reason:        'offer_payment',
      txId:          transactionId,
      metadata:      { from_user_id: tx.from_user_id, bonus_used: split.bonusUsed, real_used: split.realUsed },
      balanceBefore: balance,
      balanceAfter:  newBalance
    });
  });

  await payCreator(db, {
    txId:              transactionId,
    creatorId:         tx.from_user_id,
    fromUserId:        tx.from_user_id,
    toUserId:          userId,
    price:             tx.price,
    type:              'offer',
    bonusFundedAmount: offerBonusUsed,
    realFundedAmount:  offerRealUsed
  });

  const payerName = await getUserName(db, userId);

  await sendPush(db, [tx.from_user_id], {
    title: `${payerName} unlocked your offer!`,
    body:  `You earned $${tx.creator_payout.toFixed(2)}!`,
    data:  { type: 'offer_accepted', transaction_id: transactionId }
  });

  await sendPush(db, [userId], {
    title: `You unlocked ${senderName}'s video`,
    body:  'Tap to see what they sent you',
    data:  { type: 'offer_unlocked', transaction_id: transactionId }
  });

  logger.info(`respondToTransaction: ${userId} accepted offer ${transactionId}`);
  return { success: true };
});

// ─────────────────────────────────────────────────────────────
// fulfillRequest — creator uploads video, gets paid (requests only)
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

  if (tx.type !== 'request')    throw new Error('Can only fulfill requests');
  if (tx.to_user_id !== userId) throw new Error('You are not the creator');
  if (tx.status !== 'accepted') throw new Error(`Cannot fulfill status: ${tx.status}`);

  await txRef.update({
    status:       'fulfilled',
    photo_url:    photoUrl,
    fulfilled_at: admin.firestore.FieldValue.serverTimestamp()
  });

  await payCreator(db, {
    txId:              transactionId,
    creatorId:         userId,
    fromUserId:        tx.from_user_id,
    toUserId:          userId,
    price:             tx.price,
    type:              'request',
    bonusFundedAmount: tx.funded_bonus_amount ?? 0,
    realFundedAmount:  tx.funded_real_amount ?? tx.price
  });

  const creatorName = await getUserName(db, userId);

  await sendPush(db, [tx.from_user_id], {
    title: `${creatorName} sent your video!`,
    body:  'Tap to see what they sent you',
    data:  { type: 'request_fulfilled', transaction_id: transactionId }
  });

  logger.info(`fulfillRequest: ${userId} fulfilled ${transactionId}`);
  return { success: true };
});

// ─────────────────────────────────────────────────────────────
// markTransactionViewed — unchanged
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
  if (tx.type !== 'request')      return { success: true };
  if (tx.status !== 'fulfilled')  return { success: true };

  await txRef.update({
    status:       'completed',
    completed_at: admin.firestore.FieldValue.serverTimestamp()
  });

  logger.info(`markTransactionViewed: ${userId} viewed ${transactionId}`);
  return { success: true };
});

// ─────────────────────────────────────────────────────────────
// rateTransaction — unchanged
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

  const isCorrectUser = tx.type === 'request'
    ? tx.from_user_id === userId
    : tx.to_user_id   === userId;

  if (!isCorrectUser)            throw new Error('You cannot rate this transaction');
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
    const newAvg     = round2((oldAvg * oldCount + rating) / newCount);
    t.set(creatorRef, { ratingCount: newCount, averageRating: newAvg }, { merge: true });
    t.update(txRef, { rating });
  });

  const payerName = await getUserName(db, userId);
  await sendPush(db, [creatorId], {
    title: `${payerName} rated your video ${rating}⭐`,
    body:  rating >= 4 ? 'They loved it!' : 'Keep it up!',
    data:  { type: 'content_rated', transaction_id: transactionId }
  });

  logger.info(`rateTransaction: ${userId} rated ${transactionId} with ${rating}`);
  return { success: true };
});

// ─────────────────────────────────────────────────────────────
// cancelRequest — payer cancels before fulfilled, refund restores
// bonus/real proportionally based on the original funding split
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
  if (tx.type !== 'request')      throw new Error('Only requests can be cancelled');

  const cancellable = ['pending_signup', 'pending_acceptance', 'accepted'];
  if (!cancellable.includes(tx.status)) throw new Error('Cannot cancel — request already fulfilled');

  await db.runTransaction(async (t) => {
    const userRef       = db.collection('users').doc(userId);
    const userDoc        = await t.get(userRef);
    const balance        = userDoc.data()?.wallet_balance ?? 0;
    const bonusPortion   = tx.funded_bonus_amount ?? 0;
    const realPortion    = tx.funded_real_amount ?? tx.price;
    const refundAmount   = round2(bonusPortion + realPortion);
    const newBal         = round2(balance + refundAmount);

    t.set(userRef, {
      wallet_balance: admin.firestore.FieldValue.increment(refundAmount),
      bonus_balance:  admin.firestore.FieldValue.increment(bonusPortion)
    }, { merge: true });
    t.update(txRef, { status: 'cancelled' });
    await recordWalletTx(t, {
      userId,
      type:          'credit',
      amount:        refundAmount,
      reason:        'escrow_refund',
      txId:          transactionId,
      metadata:      { reason: 'request_cancelled_by_sender', bonus_restored: bonusPortion, real_restored: realPortion },
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
// resolveInviteTransaction — unchanged
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

  const notifTitle = tx.type === 'request'
    ? `${senderName} wants a video from you!`
    : `${senderName} sent you a mystery video!`;
  const notifBody = tx.type === 'request'
    ? `Your reward is $${tx.price.toFixed(2)} — open SocialStar to respond`
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
// dismissTransaction — unchanged
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
