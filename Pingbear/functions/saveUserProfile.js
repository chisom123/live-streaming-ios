// saveUserProfile — pingbear-96b4c functions
//
// Drop-in replacement for the existing saveUserProfile in index.js.
// Added: checks user_photo_ratings in ss-web-rate for a battle win,
// credits $2 locked promo if userWon: true and prizeIssued: false.
// Guard: web_battle_prizes collection keyed {userId}_{linkDocId} — idempotent.
//
// Also returns isNewUser so RevealPage can show $5 welcome bonus message.

const { onCall }   = require('firebase-functions/v2/https');
const admin        = require('firebase-admin');
const logger       = require('firebase-functions/logger');

// ── ss-web-rate Firestore (second project) ─────────────────────────────────
// The admin SDK can access other projects in the same GCP org by initialising
// a named app with the target projectId. Credentials are inherited from the
// default service account which has cross-project Firestore access.
let _marketingApp;
let _marketingDb;

function getMarketingDb() {
  if (!_marketingDb) {
    try {
      _marketingApp = admin.app('marketing');
    } catch {
      _marketingApp = admin.initializeApp(
        { projectId: 'ss-web-rate' },
        'marketing'
      );
    }
    _marketingDb = admin.firestore(_marketingApp);
  }
  return _marketingDb;
}

const BATTLE_PRIZE_AMOUNT = 2.00;

exports.saveUserProfile = onCall({
  cors: ['*'],
  maxInstances: 20,
  minInstances: 0
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const { phoneNumberHash, linkId, fingerprint } = request.data;
  const userId = request.auth.uid;

  if (!phoneNumberHash) throw new Error('phoneNumberHash is required');

  const db = admin.firestore(); // pingbear Firestore

  try {
    const userRef = db.collection('users').doc(userId);
    const userDoc = await userRef.get();
    const isNewUser = !userDoc.exists;

    if (!isNewUser) {
      await userRef.set({
        userId,
        phoneNumberHash,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        ...(linkId && fingerprint && {
          webRatingLinkId:       linkId,
          webFingerprint:        fingerprint,
          webRatingOpenedApp:    false,
          webRatingAttributedAt: admin.firestore.FieldValue.serverTimestamp()
        })
      }, { merge: true });
      logger.info(`saveUserProfile: updated existing user ${userId}`);
    } else {
      await userRef.set({
        userId,
        phoneNumberHash,
        createdFromWeb:  true,
        createdAt:       admin.firestore.FieldValue.serverTimestamp(),
        lastActiveAt:    admin.firestore.FieldValue.serverTimestamp(),
        ...(linkId && fingerprint && {
          webRatingLinkId:       linkId,
          webFingerprint:        fingerprint,
          webRatingOpenedApp:    false,
          webRatingAttributedAt: admin.firestore.FieldValue.serverTimestamp()
        })
      });
      logger.info(`saveUserProfile: created new user ${userId}`);
    }

    // ── Battle prize check ─────────────────────────────────────────────────
    // Only attempt if we have both linkId and fingerprint for the lookup key
    let prizeIssued = false;

    if (linkId && fingerprint) {
      try {
        prizeIssued = await checkAndIssueBattlePrize(userId, linkId, fingerprint, db);
      } catch (err) {
        // Non-fatal — prize check failure must never break the auth flow
        logger.error(`saveUserProfile: battle prize check failed for ${userId}: ${err.message}`);
      }
    }

    return { success: true, userId, isNewUser, prizeIssued };

  } catch (error) {
    logger.error('saveUserProfile: error', { error: error.message, userId });
    throw new Error(error.message);
  }
});


// ─────────────────────────────────────────────────────────────
// checkAndIssueBattlePrize
//
// 1. Reads user_photo_ratings from ss-web-rate Firestore
// 2. If userWon: true and prizeIssued: false:
//    a. Checks web_battle_prizes in pingbear (idempotency guard)
//    b. Credits $2 locked promo to pingbear users collection
//       (same pattern as seedPromoCredit.js)
//    c. Writes prizeIssued: true + prizeUserId to ss-web-rate rating doc
//    d. Writes guard doc to web_battle_prizes
// 3. Returns true if prize was issued this call, false otherwise
// ─────────────────────────────────────────────────────────────

async function checkAndIssueBattlePrize(userId, linkId, fingerprint, pingbearDb) {
  const marketingDb = getMarketingDb();

  // Resolve linkDocId from linkId string in ss-web-rate
  const linksSnap = await marketingDb.collection('rating_links')
    .where('linkId', '==', linkId).limit(1).get();
  if (linksSnap.empty) {
    logger.info(`checkAndIssueBattlePrize: link ${linkId} not found in ss-web-rate`);
    return false;
  }
  const linkDocId = linksSnap.docs[0].id;

  // Read battle result from ss-web-rate
  const ratingDocId  = `${linkDocId}_${fingerprint}`;
  const ratingDocRef = marketingDb.collection('user_photo_ratings').doc(ratingDocId);
  const ratingDoc    = await ratingDocRef.get();

  if (!ratingDoc.exists) {
    logger.info(`checkAndIssueBattlePrize: no rating doc ${ratingDocId}`);
    return false;
  }

  const ratingData = ratingDoc.data();

  if (!ratingData.userWon) {
    logger.info(`checkAndIssueBattlePrize: user did not win on ${ratingDocId}`);
    return false;
  }

  if (ratingData.prizeIssued) {
    logger.info(`checkAndIssueBattlePrize: prize already issued for ${ratingDocId}`);
    return false;
  }

  // ── Idempotency guard in pingbear ──────────────────────────
  // Key: {userId}_{linkDocId} — one prize per user per link
  const guardDocId  = `${userId}_${linkDocId}`;
  const guardRef    = pingbearDb.collection('web_battle_prizes').doc(guardDocId);
  const guardDoc    = await guardRef.get();

  if (guardDoc.exists) {
    logger.info(`checkAndIssueBattlePrize: guard exists — already credited for ${guardDocId}`);
    // Still mark prizeIssued in ss-web-rate in case it was missed
    await ratingDocRef.update({ prizeIssued: true, prizeUserId: userId });
    return false;
  }

  // ── Credit $2 locked promo — same pattern as seedPromoCredit ──
  const userRef = pingbearDb.collection('users').doc(userId);

  await pingbearDb.runTransaction(async (t) => {
    const freshUser    = await t.get(userRef);
    const freshData    = freshUser.data() || {};
    const freshBalance = freshData.wallet_balance       ?? 0;
    const freshLocked  = freshData.total_locked_credits ?? 0;
    const newBalance   = parseFloat((freshBalance + BATTLE_PRIZE_AMOUNT).toFixed(2));
    const newLocked    = parseFloat((freshLocked  + BATTLE_PRIZE_AMOUNT).toFixed(2));

    // Credit wallet + increment locked credits (same as seedPromoCredit)
    t.set(userRef, {
      wallet_balance:         admin.firestore.FieldValue.increment(BATTLE_PRIZE_AMOUNT),
      total_locked_credits:   newLocked,
      welcome_bonus_unlocked: false
    }, { merge: true });

    // Wallet transaction audit record
    const txRef = pingbearDb.collection('wallet_transactions').doc();
    t.set(txRef, {
      user_id:        userId,
      type:           'credit',
      amount:         BATTLE_PRIZE_AMOUNT,
      reason:         'web_battle_win',
      competition_id: null,
      metadata:       { linkId, fingerprint, ratingDocId },
      balance_before: freshBalance,
      balance_after:  newBalance,
      created_at:     admin.firestore.FieldValue.serverTimestamp()
    });

    // Write idempotency guard doc
    t.set(guardRef, {
      userId,
      linkId,
      linkDocId,
      fingerprint,
      amount:    BATTLE_PRIZE_AMOUNT,
      issuedAt:  admin.firestore.FieldValue.serverTimestamp()
    });
  });

  // ── Mark prizeIssued in ss-web-rate (outside pingbear transaction) ──
  // Non-fatal if this fails — the guard doc in pingbear is the true source
  try {
    await ratingDocRef.update({
      prizeIssued: true,
      prizeUserId: userId,
      prizeIssuedAt: admin.firestore.FieldValue.serverTimestamp()
    });
  } catch (err) {
    logger.warn(`checkAndIssueBattlePrize: could not update prizeIssued in ss-web-rate: ${err.message}`);
  }

  logger.info(`checkAndIssueBattlePrize: $${BATTLE_PRIZE_AMOUNT} credited to ${userId} for link ${linkDocId}`);
  return true;
}
