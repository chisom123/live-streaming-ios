/**
 * walletFunctions.js
 *
 * EXPORTS — index.js:
 *   exports.creditWelcomeBonus = wallet.creditWelcomeBonus;
 *   exports.deductBalance      = wallet.deductBalance;
 *   exports.creditBalance      = wallet.creditBalance;
 *   exports.adminCreditBalance = wallet.adminCreditBalance;
 *   exports.requestWithdrawal  = wallet.requestWithdrawal;
 *   exports.approveWithdrawal  = wallet.approveWithdrawal;
 *   exports.rejectWithdrawal   = wallet.rejectWithdrawal;
 *   exports.createTopUpIntent  = wallet.createTopUpIntent;
 *   exports.confirmTopUpIntent = wallet.confirmTopUpIntent;
 *
 * ─────────────────────────────────────────────────────────────
 * BONUS UNLOCK SYSTEM
 * ─────────────────────────────────────────────────────────────
 *
 * Users receive locked credits (welcome bonus, promo injections)
 * that cannot be withdrawn until they have staked an equivalent
 * amount in rounds.
 *
 * User doc fields:
 *   bonus_credited          : bool   — true once welcome bonus credited
 *   welcome_bonus_unlocked  : bool   — true once staking threshold met
 *   total_locked_credits    : number — total locked amount (welcome + promo)
 *   total_round_staked      : number — cumulative entry fees from completed rounds
 *
 * Unlock fires in startRound (roundFunctions.js) after each round
 * completes — it increments total_round_staked by each participant's
 * entry_fee and flips welcome_bonus_unlocked when
 * total_round_staked >= total_locked_credits.
 *
 * maxWithdrawable = balance - total_locked_credits  (if still locked)
 *                = balance                          (if unlocked)
 */

const { onCall } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const logger = require('firebase-functions/logger');

let _db;
const getDb = () => {
  if (!_db) _db = admin.firestore();
  return _db;
};

const WELCOME_BONUS_AMOUNT = 5.00;
const MIN_WITHDRAWAL       = 5.00;
const CURRENCY             = 'USD';


// ─────────────────────────────────────────────────────────────
// HELPER — record a wallet transaction
// ─────────────────────────────────────────────────────────────

async function recordTransaction(t, {
  userId, type, amount, reason,
  competitionId, metadata, balanceBefore, balanceAfter
}) {
  const db = getDb();
  const txRef = db.collection('wallet_transactions').doc();
  t.set(txRef, {
    user_id:        userId,
    type,
    amount,
    reason,
    competition_id: competitionId ?? null,
    metadata:       metadata ?? {},
    balance_before: balanceBefore,
    balance_after:  balanceAfter,
    created_at:     admin.firestore.FieldValue.serverTimestamp()
  });
}


// ─────────────────────────────────────────────────────────────
// creditWelcomeBonus
//
// Called from NameEntryView.swift after username saved.
// Credits $5 welcome bonus and sets total_locked_credits to 5.00.
// Idempotent — safe to call multiple times.
// ─────────────────────────────────────────────────────────────

exports.creditWelcomeBonus = onCall({
  cors: ['*'],
  maxInstances: 50
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId = request.auth.uid;
  const db = getDb();
  const userRef = db.collection('users').doc(userId);

  await db.runTransaction(async (t) => {
    const userDoc = await t.get(userRef);

    if (userDoc.data()?.bonus_credited === true) {
      logger.info(`creditWelcomeBonus: already credited for ${userId}`);
      return;
    }

    const currentBalance = userDoc.exists ? (userDoc.data().wallet_balance ?? 0) : 0;
    const newBalance = parseFloat((currentBalance + WELCOME_BONUS_AMOUNT).toFixed(2));

    t.set(userRef, {
      wallet_balance:         admin.firestore.FieldValue.increment(WELCOME_BONUS_AMOUNT),
      welcome_bonus_unlocked: false,
      bonus_credited:         true,
      total_locked_credits:   WELCOME_BONUS_AMOUNT,
      total_round_staked:     0
    }, { merge: true });

    await recordTransaction(t, {
      userId,
      type:          'credit',
      amount:        WELCOME_BONUS_AMOUNT,
      reason:        'welcome_bonus',
      balanceBefore: currentBalance,
      balanceAfter:  newBalance
    });
  });

  logger.info(`creditWelcomeBonus: $${WELCOME_BONUS_AMOUNT} credited to ${userId}`);
  return { success: true };
});


// ─────────────────────────────────────────────────────────────
// deductBalance
// ─────────────────────────────────────────────────────────────

exports.deductBalance = onCall({
  cors: ['*'],
  maxInstances: 50
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId = request.auth.uid;
  const { amount, reason, competitionId, metadata } = request.data;

  if (!amount || typeof amount !== 'number' || amount <= 0) throw new Error('Invalid amount');
  if (!reason) throw new Error('reason is required');

  const db = getDb();
  const userRef = db.collection('users').doc(userId);

  const result = await db.runTransaction(async (t) => {
    const userDoc = await t.get(userRef);
    const currentBalance = userDoc.exists ? (userDoc.data().wallet_balance ?? 0) : 0;

    if (currentBalance < amount) {
      throw new Error(`Insufficient funds. Balance: $${currentBalance.toFixed(2)}, Required: $${amount.toFixed(2)}`);
    }

    const newBalance = parseFloat((currentBalance - amount).toFixed(2));
    t.set(userRef, { wallet_balance: admin.firestore.FieldValue.increment(-amount) }, { merge: true });
    await recordTransaction(t, { userId, type: 'debit', amount, reason, competitionId, metadata, balanceBefore: currentBalance, balanceAfter: newBalance });
    return { success: true, new_balance: newBalance };
  });

  logger.info(`deductBalance: $${amount} from ${userId}`);
  return result;
});


// ─────────────────────────────────────────────────────────────
// creditBalance
// ─────────────────────────────────────────────────────────────

exports.creditBalance = onCall({
  cors: ['*'],
  maxInstances: 50
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId = request.auth.uid;
  const { amount, reason, competitionId, metadata } = request.data;

  if (!amount || typeof amount !== 'number' || amount <= 0) throw new Error('Invalid amount');
  if (!reason) throw new Error('reason is required');

  const db = getDb();
  const userRef = db.collection('users').doc(userId);

  await db.runTransaction(async (t) => {
    const userDoc = await t.get(userRef);
    const currentBalance = userDoc.exists ? (userDoc.data().wallet_balance ?? 0) : 0;
    const newBalance = parseFloat((currentBalance + amount).toFixed(2));
    t.set(userRef, { wallet_balance: admin.firestore.FieldValue.increment(amount) }, { merge: true });
    await recordTransaction(t, { userId, type: 'credit', amount, reason, competitionId, metadata, balanceBefore: currentBalance, balanceAfter: newBalance });
  });

  logger.info(`creditBalance: $${amount} to ${userId}`);
  return { success: true };
});


// ─────────────────────────────────────────────────────────────
// adminCreditBalance
// ─────────────────────────────────────────────────────────────

exports.adminCreditBalance = onCall({
  cors: ['*'],
  maxInstances: 20
}, async (request) => {
  if (!request.auth?.token?.admin) throw new Error('Admin access required');

  const { userId, amount, reason, competitionId, metadata } = request.data;
  if (!userId) throw new Error('userId is required');
  if (!amount || typeof amount !== 'number' || amount <= 0) throw new Error('Invalid amount');
  if (!reason) throw new Error('reason is required');

  const db = getDb();
  const userRef = db.collection('users').doc(userId);

  await db.runTransaction(async (t) => {
    const userDoc = await t.get(userRef);
    const currentBalance = userDoc.exists ? (userDoc.data().wallet_balance ?? 0) : 0;
    const newBalance = parseFloat((currentBalance + amount).toFixed(2));
    t.set(userRef, { wallet_balance: admin.firestore.FieldValue.increment(amount) }, { merge: true });
    await recordTransaction(t, { userId, type: 'credit', amount, reason, competitionId, metadata, balanceBefore: currentBalance, balanceAfter: newBalance });
  });

  logger.info(`adminCreditBalance: $${amount} to ${userId}`);
  return { success: true };
});


// ─────────────────────────────────────────────────────────────
// requestWithdrawal
//
// maxWithdrawable = balance - total_locked_credits (if locked)
//                = balance                         (if unlocked)
//
// Enforced both pre-check and inside the transaction.
// ─────────────────────────────────────────────────────────────

exports.requestWithdrawal = onCall({
  cors: ['*'],
  maxInstances: 20
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId = request.auth.uid;
  const { amount, paypalEmail } = request.data;

  if (!amount || typeof amount !== 'number' || amount <= 0) throw new Error('Invalid amount');
  if (amount < MIN_WITHDRAWAL) throw new Error(`Minimum withdrawal is $${MIN_WITHDRAWAL.toFixed(2)}`);
  if (!paypalEmail || typeof paypalEmail !== 'string') throw new Error('PayPal email is required');

  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(paypalEmail.trim())) throw new Error('Invalid PayPal email address');

  const db       = getDb();
  const userRef  = db.collection('users').doc(userId);
  const userSnap = await userRef.get();
  const userData = userSnap.data();

  const currentBalance   = userData?.wallet_balance        ?? 0;
  const bonusCredited    = userData?.bonus_credited        === true;
  const bonusUnlocked    = userData?.welcome_bonus_unlocked === true;
  const bonusLocked      = bonusCredited && !bonusUnlocked;
  const totalLocked      = userData?.total_locked_credits  ?? (bonusCredited ? WELCOME_BONUS_AMOUNT : 0);
  const stakedSoFar      = userData?.total_round_staked    ?? 0;

  // Only hold back the outstanding locked amount (what they still need to stake),
  // not the full total_locked_credits which can exceed balance after playing.
  const outstanding     = Math.max(0, parseFloat((totalLocked - stakedSoFar).toFixed(2)));
  const effectiveLocked = Math.min(outstanding, currentBalance);
  const maxWithdrawable = bonusLocked
    ? Math.max(0, parseFloat((currentBalance - effectiveLocked).toFixed(2)))
    : currentBalance;

  if (amount > maxWithdrawable) {
    if (bonusLocked && maxWithdrawable <= 0) {
      throw new Error(
        `You need to stake $${totalLocked.toFixed(2)} in rounds before you can withdraw. ` +
        `Enter your bonus into rounds to unlock it.`
      );
    } else if (bonusLocked) {
      throw new Error(
        `You can withdraw up to $${maxWithdrawable.toFixed(2)} right now. ` +
        `Stake $${totalLocked.toFixed(2)} in rounds to unlock the rest.`
      );
    } else {
      throw new Error(
        `Insufficient funds. Available: $${currentBalance.toFixed(2)}, Requested: $${amount.toFixed(2)}`
      );
    }
  }

  const withdrawalRef = db.collection('withdrawals').doc();

  await db.runTransaction(async (t) => {
    const freshSnap        = await t.get(userRef);
    const freshData        = freshSnap.data();
    const freshBalance     = freshData?.wallet_balance         ?? 0;
    const freshUnlocked    = freshData?.welcome_bonus_unlocked === true;
    const freshCredited    = freshData?.bonus_credited         === true;
    const freshLocked      = freshCredited && !freshUnlocked;
    const freshTotalLocked = freshData?.total_locked_credits   ?? (freshCredited ? WELCOME_BONUS_AMOUNT : 0);
    const freshStaked      = freshData?.total_round_staked     ?? 0;
    const freshOutstanding = Math.max(0, parseFloat((freshTotalLocked - freshStaked).toFixed(2)));
    const freshEffective   = Math.min(freshOutstanding, freshBalance);

    const freshMax = freshLocked
      ? Math.max(0, parseFloat((freshBalance - freshEffective).toFixed(2)))
      : freshBalance;

    if (amount > freshMax) {
      throw new Error(`Insufficient withdrawable funds. Available: $${freshMax.toFixed(2)}`);
    }

    const newBalance = parseFloat((freshBalance - amount).toFixed(2));

    t.set(userRef, {
      wallet_balance: admin.firestore.FieldValue.increment(-amount)
    }, { merge: true });

    t.set(withdrawalRef, {
      user_id:          userId,
      amount,
      currency:         CURRENCY,
      payment_method:   'paypal',
      paypal_email:     paypalEmail.trim().toLowerCase(),
      status:           'pending',
      requested_at:     admin.firestore.FieldValue.serverTimestamp(),
      processed_at:     null,
      rejection_reason: null,
      payout_reference: null,
      refunded:         false
    });

    await recordTransaction(t, {
      userId,
      type:    'debit',
      amount,
      reason:  'withdrawal_request',
      metadata: {
        withdrawal_id: withdrawalRef.id,
        paypal_email:  paypalEmail.trim().toLowerCase()
      },
      balanceBefore: freshBalance,
      balanceAfter:  newBalance
    });
  });

  logger.info(`requestWithdrawal: $${amount} for ${userId}`);
  return { success: true, withdrawal_id: withdrawalRef.id };
});


// ─────────────────────────────────────────────────────────────
// approveWithdrawal
// ─────────────────────────────────────────────────────────────

exports.approveWithdrawal = onCall({
  cors: ['*'],
  maxInstances: 10
}, async (request) => {
  if (!request.auth?.token?.admin) throw new Error('Admin access required');

  const { withdrawalId } = request.data;
  if (!withdrawalId) throw new Error('withdrawalId is required');

  const db = getDb();
  const withdrawalRef = db.collection('withdrawals').doc(withdrawalId);
  const withdrawalDoc = await withdrawalRef.get();

  if (!withdrawalDoc.exists) throw new Error('Withdrawal not found');
  const withdrawal = withdrawalDoc.data();
  if (withdrawal.status !== 'pending') throw new Error(`Cannot approve: ${withdrawal.status}`);

  await withdrawalRef.update({
    status:       'completed',
    processed_at: admin.firestore.FieldValue.serverTimestamp(),
    approved_by:  request.auth.uid
  });

  logger.info(`approveWithdrawal: ${withdrawalId} approved by ${request.auth.uid} — manual PayPal payment required to ${withdrawal.paypal_email} for $${withdrawal.amount}`);

  return {
    success:      true,
    paypal_email: withdrawal.paypal_email,
    amount:       withdrawal.amount,
    currency:     withdrawal.currency || CURRENCY
  };
});


// ─────────────────────────────────────────────────────────────
// rejectWithdrawal
// ─────────────────────────────────────────────────────────────

exports.rejectWithdrawal = onCall({
  cors: ['*'],
  maxInstances: 10
}, async (request) => {
  if (!request.auth?.token?.admin) throw new Error('Admin access required');

  const { withdrawalId, reason } = request.data;
  if (!withdrawalId) throw new Error('withdrawalId is required');
  if (!reason || reason.trim().length === 0) throw new Error('Rejection reason is required');

  const db = getDb();

  await db.runTransaction(async (t) => {
    const withdrawalRef = db.collection('withdrawals').doc(withdrawalId);
    const withdrawalDoc = await t.get(withdrawalRef);
    if (!withdrawalDoc.exists) throw new Error('Withdrawal not found');

    const withdrawal = withdrawalDoc.data();
    if (withdrawal.status !== 'pending') throw new Error(`Cannot reject: ${withdrawal.status}`);

    const { user_id, amount } = withdrawal;
    const userRef = db.collection('users').doc(user_id);
    const userDoc = await t.get(userRef);
    const currentBalance = userDoc.exists ? (userDoc.data().wallet_balance ?? 0) : 0;
    const newBalance = parseFloat((currentBalance + amount).toFixed(2));

    t.set(userRef, { wallet_balance: admin.firestore.FieldValue.increment(amount) }, { merge: true });
    t.update(withdrawalRef, {
      status:           'rejected',
      processed_at:     admin.firestore.FieldValue.serverTimestamp(),
      rejection_reason: reason.trim(),
      refunded:         true,
      rejected_by:      request.auth.uid
    });
    await recordTransaction(t, {
      userId:        user_id,
      type:          'credit',
      amount,
      reason:        'withdrawal_rejected',
      metadata:      { withdrawal_id: withdrawalId, rejection_reason: reason.trim() },
      balanceBefore: currentBalance,
      balanceAfter:  newBalance
    });
  });

  return { success: true };
});


// ─────────────────────────────────────────────────────────────
// createTopUpIntent
// ─────────────────────────────────────────────────────────────

exports.createTopUpIntent = onCall({
  cors: ['*'],
  maxInstances: 50,
  minInstances: 1,
  secrets: ['STRIPE_SECRET_KEY']
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId = request.auth.uid;
  const { amount, currency } = request.data;
  if (!amount || typeof amount !== 'number' || amount <= 0) throw new Error('Invalid amount');

  const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

  const paymentIntent = await stripe.paymentIntents.create({
    amount,
    currency:             currency || 'usd',
    payment_method_types: ['card'],
    metadata: {
      user_id:       userId,
      platform:      'ios_apple_pay',
      top_up:        'true',
      amount_pounds: (amount / 100).toFixed(2)
    }
  });

  logger.info(`createTopUpIntent: created ${paymentIntent.id} for ${userId}`);
  return { clientSecret: paymentIntent.client_secret };
});


// ─────────────────────────────────────────────────────────────
// confirmTopUpIntent
// ─────────────────────────────────────────────────────────────

exports.confirmTopUpIntent = onCall({
  cors: ['*'],
  maxInstances: 50,
  minInstances: 1,
  secrets: ['STRIPE_SECRET_KEY']
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId = request.auth.uid;
  const { paymentIntentId, clientSecret, applePayTokenData, transactionId } = request.data;

  if (!paymentIntentId)   throw new Error('paymentIntentId is required');
  if (!applePayTokenData) throw new Error('applePayTokenData is required');

  const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

  const tokenBuffer = Buffer.from(applePayTokenData, 'base64');
  const tokenJson   = JSON.parse(tokenBuffer.toString('utf8'));

  const token = await stripe.tokens.create({
    pk_token:                 JSON.stringify(tokenJson),
    pk_token_instrument_name: 'Apple Pay',
    pk_token_transaction_id:  transactionId
  });

  logger.info(`confirmTopUpIntent: created token ${token.id} for ${userId}`);

  const intent = await stripe.paymentIntents.confirm(paymentIntentId, {
    payment_method_data: {
      type: 'card',
      card: { token: token.id }
    },
    client_secret: clientSecret
  });

  if (intent.status !== 'succeeded') {
    throw new Error(`Payment not completed: ${intent.status}`);
  }

  logger.info(`confirmTopUpIntent: ${paymentIntentId} succeeded for ${userId}`);
  return { success: true };
});
