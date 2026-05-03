/**
 * walletFunctions.js
 *
 * EXPORTS — update index.js:
 *   exports.creditWelcomeBonus = wallet.creditWelcomeBonus;
 *   exports.recordStarsEarned  = wallet.recordStarsEarned;
 *   exports.unlockBonus        = wallet.unlockBonus;        // keep but no longer called from Swift
 *   exports.contributeToRace   = wallet.contributeToRace;
 *   exports.deductBalance      = wallet.deductBalance;
 *   exports.creditBalance      = wallet.creditBalance;
 *   exports.adminCreditBalance = wallet.adminCreditBalance;
 *   exports.requestWithdrawal  = wallet.requestWithdrawal;
 *   exports.approveWithdrawal  = wallet.approveWithdrawal;
 *   exports.rejectWithdrawal   = wallet.rejectWithdrawal;
 *   exports.simulateTopUp      = wallet.simulateTopUp;
 */

const { onCall, onRequest } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const logger = require('firebase-functions/logger');
const provider = require('./providers/index');

let _db;
const getDb = () => {
  if (!_db) _db = admin.firestore();
  return _db;
};

const WELCOME_BONUS_AMOUNT    = 5.00;
const MIN_TOP_UP_AMOUNT       = 1.00;
const MIN_WITHDRAWAL          = 5.00;
const CURRENCY                = 'USD';


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
// HELPER — check both unlock conditions and flip
//          welcome_bonus_unlocked if both are met
// ─────────────────────────────────────────────────────────────

async function checkAndUnlock(userId) {
  // Unlock now handled by closeRaces when competition ends
  // Kept for backwards compatibility — no longer triggers unlock
  const db = getDb();
  const userRef = db.collection('users').doc(userId);
  const userDoc = await userRef.get();
  const data    = userDoc.data();

  if (!data || !data.bonus_credited) return;
  if (data.welcome_bonus_unlocked === true) return;

  // No longer unlocking here — closeRaces handles it
  logger.info(`checkAndUnlock: unlock pending race completion for ${userId}`);
}


// ─────────────────────────────────────────────────────────────
// creditWelcomeBonus
//
// Called directly from NameEntryView.swift after username saved.
// Credits $5 welcome bonus. Idempotent — safe to call multiple times.
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
      has_earned_stars:       false,
      total_contributed:      0,
      bonus_credited:         true
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
// recordStarsEarned
//
// Called from RaceManager.swift after a photo owner earns stars.
// Sets has_earned_stars: true on the photo owner's document.
// Uses admin privileges so any authenticated user can trigger
// this for another user's document — Firestore rules block
// cross-user writes from the client.
//
// Usage from Swift (after stars written to race):
//   Functions.functions().httpsCallable("recordStarsEarned").call([
//     "photoOwnerId": "abc123"
//   ])
// ─────────────────────────────────────────────────────────────

exports.recordStarsEarned = onCall({
  cors: ['*'],
  maxInstances: 50
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const { photoOwnerId } = request.data;
  if (!photoOwnerId) throw new Error('photoOwnerId is required');

  const db = getDb();
  const userRef = db.collection('users').doc(photoOwnerId);
  const userDoc = await userRef.get();
  const data    = userDoc.data();

  if (!data?.bonus_credited) {
    return { success: true, reason: 'no_bonus' };
  }

  if (data?.has_earned_stars === true) {
    return { success: true, reason: 'already_recorded' };
  }

  // Just set the flag — unlock fires when race completes
  await userRef.set({ has_earned_stars: true }, { merge: true });

  logger.info(`recordStarsEarned: has_earned_stars set for ${photoOwnerId}`);
  return { success: true };
});


// ─────────────────────────────────────────────────────────────
// unlockBonus — kept for backwards compatibility
// No longer called from Swift — recordStarsEarned replaces it
// ─────────────────────────────────────────────────────────────

exports.unlockBonus = onCall({
  cors: ['*'],
  maxInstances: 50
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId = request.auth.uid;
  const db = getDb();
  const userRef = db.collection('users').doc(userId);
  const userDoc = await userRef.get();
  const data = userDoc.data();

  if (!data?.bonus_credited) return { success: true, reason: 'no_bonus' };
  if (data?.welcome_bonus_unlocked === true) return { success: true, already_unlocked: true };

  if (data?.has_earned_stars !== true) {
    await userRef.set({ has_earned_stars: true }, { merge: true });
  }

  await checkAndUnlock(userId);

  const updatedDoc = await userRef.get();
  return { success: true, unlocked: updatedDoc.data()?.welcome_bonus_unlocked === true };
});


// ─────────────────────────────────────────────────────────────
// contributeToRace
// ─────────────────────────────────────────────────────────────

exports.contributeToRace = onCall({
  cors: ['*'],
  maxInstances: 50
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId = request.auth.uid;
  const { competitionId, amount } = request.data;

  if (!competitionId) throw new Error('competitionId is required');
  if (!amount || typeof amount !== 'number' || amount <= 0) throw new Error('Invalid amount');

  const db = getDb();

  const memberDoc = await db
    .collection('competitions').doc(competitionId)
    .collection('members').doc(userId)
    .get();

  if (!memberDoc.exists) throw new Error('You are not a member of this competition');

  const { raceId } = await getOrCreateRace(db, competitionId);
  const raceRef = db.collection('competition_races').doc(raceId);
  const raceDoc = await raceRef.get();
  const raceData = raceDoc.data();

  if (!raceData || raceData.status !== 'active') throw new Error('No active race');
  if (raceData.end_date.toMillis() <= Date.now()) throw new Error('Race has ended');

  const userRef = db.collection('users').doc(userId);

  await db.runTransaction(async (t) => {
    const userDoc = await t.get(userRef);
    const currentBalance = userDoc.exists ? (userDoc.data().wallet_balance ?? 0) : 0;

    if (currentBalance < amount) {
      throw new Error(`Insufficient funds. Balance: $${currentBalance.toFixed(2)}, Required: $${amount.toFixed(2)}`);
    }

    const newBalance = parseFloat((currentBalance - amount).toFixed(2));

    t.set(userRef, {
      wallet_balance:    admin.firestore.FieldValue.increment(-amount),
      total_contributed: admin.firestore.FieldValue.increment(amount)
    }, { merge: true });

    const contributionRef = raceRef.collection('contributions').doc();
    t.set(contributionRef, {
      user_id:        userId,
      amount,
      contributed_at: admin.firestore.FieldValue.serverTimestamp()
    });

    t.update(raceRef, { total_pot: admin.firestore.FieldValue.increment(amount) });

    const txRef = db.collection('wallet_transactions').doc();
    t.set(txRef, {
      user_id:        userId,
      type:           'debit',
      amount,
      reason:         'race_contribution',
      competition_id: competitionId,
      metadata:       { race_id: raceId },
      balance_before: currentBalance,
      balance_after:  newBalance,
      created_at:     admin.firestore.FieldValue.serverTimestamp()
    });
  });

  logger.info(`contributeToRace: $${amount} by ${userId} to race ${raceId}`);
  return { success: true, race_id: raceId };
});


// ─────────────────────────────────────────────────────────────
// getOrCreateRace helper
// ─────────────────────────────────────────────────────────────

const DEFAULT_DURATION = 'weekly';
const RACE_DURATIONS = {
  weekly: 7 * 24 * 60 * 60 * 1000,
  daily:  1 * 24 * 60 * 60 * 1000
};

async function getOrCreateRace(db, competitionId) {
  const activeRaceSnap = await db.collection('competition_races')
    .where('competition_id', '==', competitionId)
    .where('status', '==', 'active')
    .limit(1)
    .get();

  if (!activeRaceSnap.empty) {
    const doc = activeRaceSnap.docs[0];
    if (doc.data().end_date.toMillis() > Date.now()) {
      return { raceId: doc.id, created: false };
    }
  }

  const competitionDoc = await db.collection('competitions').doc(competitionId).get();
  const duration = competitionDoc.data()?.race_duration || DEFAULT_DURATION;
  const durationMs = RACE_DURATIONS[duration] || RACE_DURATIONS[DEFAULT_DURATION];

  const now = new Date();
  const endDate = new Date(now.getTime() + durationMs);
  const raceRef = db.collection('competition_races').doc();

  await raceRef.set({
    competition_id:    competitionId,
    status:            'active',
    duration,
    start_date:        admin.firestore.Timestamp.fromDate(now),
    end_date:          admin.firestore.Timestamp.fromDate(endDate),
    total_pot:         0,
    total_stars:       0,
    participant_count: 0,
    payout_complete:   false,
    created_at:        admin.firestore.FieldValue.serverTimestamp()
  });

  return { raceId: raceRef.id, created: true };
}


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

  const db          = getDb();
  const userRef     = db.collection('users').doc(userId);
  const userSnapshot = await userRef.get();
  const userData    = userSnapshot.data();

  const currentBalance = userData?.wallet_balance ?? 0;
  const bonusCredited  = userData?.bonus_credited === true;
  const bonusUnlocked  = userData?.welcome_bonus_unlocked === true;
  const bonusLocked    = bonusCredited && !bonusUnlocked;

  // Simple rule — if bonus locked, $5 is not withdrawable
  const maxWithdrawable = bonusLocked
    ? Math.max(0, currentBalance - WELCOME_BONUS_AMOUNT)
    : currentBalance;

  if (amount > maxWithdrawable) {
    if (bonusLocked && maxWithdrawable <= 0) {
      throw new Error(
        `Your $${WELCOME_BONUS_AMOUNT.toFixed(2)} welcome bonus unlocks once you complete your first competition.`
      );
    } else if (bonusLocked) {
      throw new Error(
        `You can withdraw up to $${maxWithdrawable.toFixed(2)} right now. Your $${WELCOME_BONUS_AMOUNT.toFixed(2)} welcome bonus unlocks after your first competition.`
      );
    } else {
      throw new Error(
        `Insufficient funds. Available: $${currentBalance.toFixed(2)}, Requested: $${amount.toFixed(2)}`
      );
    }
  }

  const withdrawalRef = db.collection('withdrawals').doc();

  await db.runTransaction(async (t) => {
    const freshUserDoc   = await t.get(userRef);
    const freshBalance   = freshUserDoc.data()?.wallet_balance ?? 0;
    const freshBonusLocked = (freshUserDoc.data()?.bonus_credited === true) &&
                             (freshUserDoc.data()?.welcome_bonus_unlocked !== true);

    const freshMax = freshBonusLocked
      ? Math.max(0, freshBalance - WELCOME_BONUS_AMOUNT)
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

  // Mark as completed — actual PayPal payment sent manually
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
      status: 'rejected', processed_at: admin.firestore.FieldValue.serverTimestamp(),
      rejection_reason: reason.trim(), refunded: true, rejected_by: request.auth.uid
    });
    await recordTransaction(t, {
      userId: user_id, type: 'credit', amount, reason: 'withdrawal_rejected',
      metadata: { withdrawal_id: withdrawalId, rejection_reason: reason.trim() },
      balanceBefore: currentBalance, balanceAfter: newBalance
    });
  });

  return { success: true };
});

// ─────────────────────────────────────────────────────────────
// createTopUpIntent
//
// Creates a Stripe PaymentIntent server-side and returns
// the client secret to the app to confirm with Apple Pay.
// ─────────────────────────────────────────────────────────────

exports.createTopUpIntent = onCall({
  cors: ['*'],
  maxInstances: 50,
  minInstances: 1,
  secrets: ['STRIPE_SECRET_KEY']
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId           = request.auth.uid;
  const { amount, currency } = request.data;
  if (!amount || typeof amount !== 'number' || amount <= 0) throw new Error('Invalid amount');

  const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

  const paymentIntent = await stripe.paymentIntents.create({
    amount,
    currency:             currency || 'usd',
    payment_method_types: ['card'],
    metadata: {
      user_id:      userId,
      platform:     'ios_apple_pay',
      top_up:       'true',          // ← flag so webhook knows this is a wallet top-up
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

  if (!paymentIntentId) throw new Error('paymentIntentId is required');
  if (!applePayTokenData) throw new Error('applePayTokenData is required');

  const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

  // Decode base64 Apple Pay token data into JSON object
  const tokenBuffer = Buffer.from(applePayTokenData, 'base64');
  const tokenJson   = JSON.parse(tokenBuffer.toString('utf8'));

  // 1. Create Stripe token from Apple Pay payment data
  const token = await stripe.tokens.create({
    pk_token:                JSON.stringify(tokenJson),
    pk_token_instrument_name: 'Apple Pay',
    pk_token_transaction_id:  transactionId
  });

  logger.info(`confirmTopUpIntent: created token ${token.id} for ${userId}`);

  // 2. Confirm the PaymentIntent with the token
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
