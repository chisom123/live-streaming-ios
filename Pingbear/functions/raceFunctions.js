/**
 * raceFunctions.js
 *
 * All race-related Cloud Functions.
 *
 * Add to index.js:
 *   const race = require('./raceFunctions');
 *   exports.contributeToRace = race.contributeToRace;
 *   exports.closeRaces       = race.closeRaces;
 *   exports.setRaceDuration  = race.setRaceDuration;
 *
 * AND REMOVE from index.js:
 *   exports.closePots
 *   exports.awardLeaderboardPoints
 *
 * ─────────────────────────────────────────────────────────────
 * RACE LIFECYCLE
 * ─────────────────────────────────────────────────────────────
 *
 * Race starts when EITHER:
 *   - First photo is posted (handled in RaceManager.swift)
 *   - First contribution is made (handled in contributeToRace below)
 *
 * Race ends automatically after 7 days (weekly) or 1 day (daily).
 * closeRaces runs every minute and catches ended races.
 *
 * On close:
 *   - If total_pot == 0 → close with no payouts
 *   - If total_stars == 0 → refund all contributors
 *   - Otherwise → proportional payout to participants by stars earned
 *
 * ─────────────────────────────────────────────────────────────
 * DATA MODEL
 * ─────────────────────────────────────────────────────────────
 *
 * competitions/{competitionId}
 *   race_duration: "weekly" | "daily"    ← default "weekly"
 *
 * competition_races/{raceId}
 *   competition_id: string
 *   status: "active" | "closed"
 *   duration: "weekly" | "daily"
 *   start_date: timestamp
 *   end_date: timestamp
 *   total_pot: number                    ← sum of all contributions in USD
 *   total_stars: number
 *   participant_count: number
 *   payout_complete: boolean
 *   created_at: timestamp
 *
 *   /race_participants/{userId}
 *     user_id: string
 *     total_stars: number
 *     joined_at: timestamp
 *     payout_amount: number             ← set when race closes
 *
 *   /contributions/{contributionId}
 *     user_id: string
 *     amount: number
 *     contributed_at: timestamp
 */

const { onCall, onRequest } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');
const logger = require('firebase-functions/logger');

let _db;
const getDb = () => {
  if (!_db) _db = admin.firestore();
  return _db;
};

const RACE_DURATIONS = {
  weekly: 7 * 24 * 60 * 60 * 1000,   // 7 days in ms
  daily:  1 * 24 * 60 * 60 * 1000    // 1 day in ms
};

const DEFAULT_DURATION = 'weekly';

// ─────────────────────────────────────────────────────────────
// HELPER — unlock welcome bonus for participants who earned stars
// Called after each race closes
// ─────────────────────────────────────────────────────────────

async function unlockBonusForParticipants(raceId, raceRef, db) {
  const participantsSnap = await raceRef
    .collection('race_participants')
    .get();

  if (participantsSnap.empty) return;

  for (const doc of participantsSnap.docs) {
    const userId = doc.id;
    const stars  = doc.data().total_stars ?? 0;

    // Only unlock for participants who actually earned stars
    if (stars === 0) continue;

    const userRef = db.collection('users').doc(userId);
    const userDoc = await userRef.get();
    const userData = userDoc.data();

    // Skip if no bonus credited or already unlocked
    if (!userData?.bonus_credited) continue;
    if (userData?.welcome_bonus_unlocked === true) continue;

    await userRef.set({
      welcome_bonus_unlocked: true
    }, { merge: true });

    logger.info(`unlockBonusForParticipants: bonus unlocked for ${userId} on race ${raceId} completion`);
  }
}

// ─────────────────────────────────────────────────────────────
// HELPER — get or create an active race for a competition
// Used by both contributeToRace and RaceManager.swift (Swift side)
// ─────────────────────────────────────────────────────────────

async function getOrCreateRace(db, competitionId) {
  // Check for existing active race
  const activeRaceSnap = await db.collection('competition_races')
    .where('competition_id', '==', competitionId)
    .where('status', '==', 'active')
    .limit(1)
    .get();

  if (!activeRaceSnap.empty) {
    const doc = activeRaceSnap.docs[0];
    const data = doc.data();

    // Verify not expired
    if (data.end_date.toMillis() > Date.now()) {
      return { raceId: doc.id, created: false };
    }
  }

  // No active race — read duration from competition and create one
  const competitionDoc = await db.collection('competitions').doc(competitionId).get();
  const duration = competitionDoc.data()?.race_duration || DEFAULT_DURATION;
  const durationMs = RACE_DURATIONS[duration] || RACE_DURATIONS[DEFAULT_DURATION];

  const now = new Date();
  const endDate = new Date(now.getTime() + durationMs);

  const raceRef = db.collection('competition_races').doc();

  await raceRef.set({
    competition_id:    competitionId,
    status:            'active',
    duration:          duration,
    start_date:        admin.firestore.Timestamp.fromDate(now),
    end_date:          admin.firestore.Timestamp.fromDate(endDate),
    total_pot:         0,
    total_stars:       0,
    participant_count: 0,
    payout_complete:   false,
    created_at:        admin.firestore.FieldValue.serverTimestamp()
  });

  logger.info(`getOrCreateRace: created new ${duration} race ${raceRef.id} for competition ${competitionId}`);
  return { raceId: raceRef.id, created: true };
}


// ─────────────────────────────────────────────────────────────
// contributeToRace
//
// Called from Swift when a user puts money into a race pot.
// Deducts from their wallet and adds to the race pot.
// Creates a race if none is active for this competition.
// Users can contribute multiple times during a race.
//
// Usage from Swift:
//   Functions.functions().httpsCallable("contributeToRace").call([
//     "competitionId": "comp_abc123",
//     "amount": 5.00
//   ])
// ─────────────────────────────────────────────────────────────

exports.contributeToRace = onCall({
  cors: ['*'],
  maxInstances: 50
}, async (request) => {
  if (!request.auth) {
    throw new Error('User must be authenticated');
  }

  const userId = request.auth.uid;
  const { competitionId, amount } = request.data;

  if (!competitionId) throw new Error('competitionId is required');
  if (!amount || typeof amount !== 'number' || amount <= 0) {
    throw new Error('Invalid amount');
  }

  const db = getDb();

  // Verify user is a member of this competition
  const memberDoc = await db
    .collection('competitions').doc(competitionId)
    .collection('members').doc(userId)
    .get();

  if (!memberDoc.exists) {
    throw new Error('You are not a member of this competition');
  }

  // Get or create active race
  const { raceId } = await getOrCreateRace(db, competitionId);
  const raceRef = db.collection('competition_races').doc(raceId);

  // Verify race is still active and not expired
  const raceDoc = await raceRef.get();
  const raceData = raceDoc.data();

  if (!raceData || raceData.status !== 'active') {
    throw new Error('No active race for this competition');
  }
  if (raceData.end_date.toMillis() <= Date.now()) {
    throw new Error('This race has already ended');
  }

  // Deduct from wallet using a transaction to ensure atomicity
  const userRef = db.collection('users').doc(userId);

  await db.runTransaction(async (t) => {
    const userDoc = await t.get(userRef);
    const currentBalance = userDoc.exists ? (userDoc.data().wallet_balance ?? 0) : 0;

    if (currentBalance < amount) {
      throw new Error(
        `Insufficient funds. Balance: $${currentBalance.toFixed(2)}, Required: $${amount.toFixed(2)}`
      );
    }

    const newBalance = parseFloat((currentBalance - amount).toFixed(2));

    // Deduct wallet balance
    t.set(userRef, {
      wallet_balance: admin.firestore.FieldValue.increment(-amount)
    }, { merge: true });

    // Add contribution record
    const contributionRef = raceRef.collection('contributions').doc();
    t.set(contributionRef, {
      user_id:        userId,
      amount:         amount,
      contributed_at: admin.firestore.FieldValue.serverTimestamp()
    });

    // Increment race total_pot
    t.update(raceRef, {
      total_pot: admin.firestore.FieldValue.increment(amount)
    });

    // Wallet transaction audit trail
    const txRef = db.collection('wallet_transactions').doc();
    t.set(txRef, {
      user_id:        userId,
      type:           'debit',
      amount:         amount,
      reason:         'race_contribution',
      competition_id: competitionId,
      metadata:       { race_id: raceId },
      balance_before: currentBalance,
      balance_after:  newBalance,
      created_at:     admin.firestore.FieldValue.serverTimestamp()
    });
  });

  logger.info(`contributeToRace: $${amount} contributed by ${userId} to race ${raceId}`);
  return { success: true, race_id: raceId };
});


// ─────────────────────────────────────────────────────────────
// setRaceDuration
//
// Called from Swift to set the race duration for a competition.
// Any member can call this, but only before a race is active.
//
// Usage from Swift:
//   Functions.functions().httpsCallable("setRaceDuration").call([
//     "competitionId": "comp_abc123",
//     "duration": "daily"   // or "weekly"
//   ])
// ─────────────────────────────────────────────────────────────

exports.setRaceDuration = onCall({
  cors: ['*'],
  maxInstances: 20
}, async (request) => {
  if (!request.auth) {
    throw new Error('User must be authenticated');
  }

  const userId = request.auth.uid;
  const { competitionId, duration } = request.data;

  if (!competitionId) throw new Error('competitionId is required');
  if (!['daily', 'weekly'].includes(duration)) {
    throw new Error('duration must be "daily" or "weekly"');
  }

  const db = getDb();

  // Verify user is a member
  const memberDoc = await db
    .collection('competitions').doc(competitionId)
    .collection('members').doc(userId)
    .get();

  if (!memberDoc.exists) {
    throw new Error('You are not a member of this competition');
  }

  // Check no active race exists — can't change duration mid-race
  const activeRaceSnap = await db.collection('competition_races')
    .where('competition_id', '==', competitionId)
    .where('status', '==', 'active')
    .limit(1)
    .get();

  if (!activeRaceSnap.empty) {
    const raceData = activeRaceSnap.docs[0].data();
    if (raceData.end_date.toMillis() > Date.now()) {
      throw new Error('Cannot change duration while a race is active');
    }
  }

  // Update competition document
  await db.collection('competitions').doc(competitionId).set({
    race_duration: duration
  }, { merge: true });

  logger.info(`setRaceDuration: ${duration} set for competition ${competitionId} by ${userId}`);
  return { success: true, duration };
});


// ─────────────────────────────────────────────────────────────
// closeRaces
//
// Runs every minute. Finds all active races that have ended
// and processes payouts.
//
// Payout logic:
//   - total_pot == 0 → close with no payouts
//   - total_stars == 0 → refund all contributors
//   - Otherwise → proportional payout by stars earned
//
// Winners' money goes straight into their wallet_balance.
// ─────────────────────────────────────────────────────────────

exports.closeRaces = onSchedule({
  schedule: 'every 1 minutes',
  timeZone: 'UTC'
}, async (event) => {
  const db = getDb();
  const now = admin.firestore.Timestamp.now();

  const endedRacesSnap = await db.collection('competition_races')
    .where('end_date', '<=', now)
    .where('status', '==', 'active')
    .get();

  if (endedRacesSnap.empty) {
    logger.info('closeRaces: no races to close');
    return null;
  }

  logger.info(`closeRaces: closing ${endedRacesSnap.size} race(s)`);

  const promises = endedRacesSnap.docs.map(doc =>
    closeRace(doc.id, doc.data(), db)
  );

  await Promise.all(promises);
  logger.info('closeRaces: all races processed');
  return null;
});


// ─────────────────────────────────────────────────────────────
// closeRace — processes a single ended race
// ─────────────────────────────────────────────────────────────

async function closeRace(raceId, raceData, db) {
  logger.info(`closeRace: processing race ${raceId}`);

  const raceRef = db.collection('competition_races').doc(raceId);
  const competitionId = raceData.competition_id;
  const totalPot = raceData.total_pot || 0;

  try {
    // ── Get all participants ordered by stars ─────────────────
    const participantsSnap = await raceRef
      .collection('race_participants')
      .orderBy('total_stars', 'desc')
      .get();

    const totalStars = raceData.total_stars || 0;

    // ── Case 1: No money in pot ───────────────────────────────
    // Just close the race, no payouts needed
    if (totalPot === 0) {
      await unlockBonusForParticipants(raceId, raceRef, db);
      await raceRef.update({
        status:           'closed',
        closed_at:        admin.firestore.FieldValue.serverTimestamp(),
        payout_complete:  true,
        total_winners:    0
      });
      logger.info(`closeRace: race ${raceId} closed with no pot`);
      return;
    }

    // ── Case 2: Money in pot but nobody earned stars ──────────
    // Refund all contributors
    if (totalStars === 0) {
      await refundContributors(raceId, raceRef, competitionId, db);
      await raceRef.update({
        status:          'closed',
        closed_at:       admin.firestore.FieldValue.serverTimestamp(),
        payout_complete: true,
        total_winners:   0,
        refunded:        true
      });
      logger.info(`closeRace: race ${raceId} closed with full refund (no stars earned)`);
      return;
    }

    // ── Case 3: Normal payout — proportional by stars ─────────
    const winners = [];

    for (const doc of participantsSnap.docs) {
      const data = doc.data();
      const userId = doc.id;
      const stars = data.total_stars || 0;

      if (stars === 0) continue;

      // Calculate proportional payout
      // payout = (participant stars / total stars) × total pot
      const share = stars / totalStars;
      const payout = parseFloat((share * totalPot).toFixed(2));

      if (payout <= 0) continue;

      winners.push({ userId, stars, payout, ref: doc.ref });
    }

    // Credit each winner's wallet
    for (const winner of winners) {
      await creditWinner(
        winner.userId,
        winner.payout,
        winner.stars,
        totalStars,
        raceId,
        competitionId,
        db
      );

      // Record payout amount on participant doc
      await winner.ref.update({
        payout_amount: winner.payout
      });
    }
    
    await unlockBonusForParticipants(raceId, raceRef, db);
      
    // Mark race as closed
    await raceRef.update({
      status:          'closed',
      closed_at:       admin.firestore.FieldValue.serverTimestamp(),
      payout_complete: true,
      total_winners:   winners.length
    });

    logger.info(`closeRace: race ${raceId} closed — $${totalPot} distributed to ${winners.length} winners`);

  } catch (error) {
    logger.error(`closeRace: error processing race ${raceId}:`, error);
    throw error;
  }
}


// ─────────────────────────────────────────────────────────────
// creditWinner — credits a single winner's wallet
// ─────────────────────────────────────────────────────────────

async function creditWinner(userId, amount, stars, totalStars, raceId, competitionId, db) {
  const userRef = db.collection('users').doc(userId);

  await db.runTransaction(async (t) => {
    const userDoc = await t.get(userRef);
    const currentBalance = userDoc.exists ? (userDoc.data().wallet_balance ?? 0) : 0;
    const newBalance = parseFloat((currentBalance + amount).toFixed(2));

    // Credit wallet
    t.set(userRef, {
      wallet_balance: admin.firestore.FieldValue.increment(amount)
    }, { merge: true });

    // Audit trail
    const txRef = db.collection('wallet_transactions').doc();
    t.set(txRef, {
      user_id:        userId,
      type:           'credit',
      amount:         amount,
      reason:         'race_win',
      competition_id: competitionId,
      metadata: {
        race_id:      raceId,
        stars:        stars,
        total_stars:  totalStars,
        share:        parseFloat((stars / totalStars).toFixed(4))
      },
      balance_before: currentBalance,
      balance_after:  newBalance,
      created_at:     admin.firestore.FieldValue.serverTimestamp()
    });
  });

  logger.info(`creditWinner: $${amount} credited to user ${userId} (${stars}/${totalStars} stars)`);
}


// ─────────────────────────────────────────────────────────────
// refundContributors — refunds all contributors when no stars earned
// ─────────────────────────────────────────────────────────────

async function refundContributors(raceId, raceRef, competitionId, db) {
  // Get all contributions
  const contributionsSnap = await raceRef.collection('contributions').get();

  if (contributionsSnap.empty) return;

  // Aggregate total refund per user
  // (a user may have contributed multiple times)
  const refundMap = {};

  contributionsSnap.docs.forEach(doc => {
    const { user_id, amount } = doc.data();
    refundMap[user_id] = (refundMap[user_id] || 0) + amount;
  });

  // Refund each contributor
  for (const [userId, amount] of Object.entries(refundMap)) {
    const userRef = db.collection('users').doc(userId);

    await db.runTransaction(async (t) => {
      const userDoc = await t.get(userRef);
      const currentBalance = userDoc.exists ? (userDoc.data().wallet_balance ?? 0) : 0;
      const newBalance = parseFloat((currentBalance + amount).toFixed(2));

      t.set(userRef, {
        wallet_balance: admin.firestore.FieldValue.increment(amount)
      }, { merge: true });

      const txRef = db.collection('wallet_transactions').doc();
      t.set(txRef, {
        user_id:        userId,
        type:           'credit',
        amount:         amount,
        reason:         'race_refund',
        competition_id: competitionId,
        metadata:       { race_id: raceId },
        balance_before: currentBalance,
        balance_after:  newBalance,
        created_at:     admin.firestore.FieldValue.serverTimestamp()
      });
    });

    logger.info(`refundContributors: $${amount} refunded to user ${userId} for race ${raceId}`);
  }
}


// Export getOrCreateRace so RaceManager.swift can trigger it
// indirectly via a Cloud Function call when a photo is posted
exports.getOrCreateRaceForCompetition = onCall({
  cors: ['*'],
  maxInstances: 50
}, async (request) => {
  if (!request.auth) {
    throw new Error('User must be authenticated');
  }

  const userId = request.auth.uid;
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

  const { raceId, created } = await getOrCreateRace(db, competitionId);

  return { success: true, race_id: raceId, created };
});
