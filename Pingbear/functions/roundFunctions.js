/**
 * roundFunctions.js
 *
 * All round-related Cloud Functions for the synchronous photo competition system.
 *
 * Add to index.js:
 *   const round = require('./roundFunctions');
 *   exports.createRound      = round.createRound;
 *   exports.updateRoundTheme = round.updateRoundTheme;
 *   exports.joinRound        = round.joinRound;
 *   exports.leaveRound       = round.leaveRound;
 *   exports.startRound       = round.startRound;
 *   exports.sendRoundNudge   = round.sendRoundNudge;
 *
 * Secrets required:
 *   GEMINI_API_KEY  — set via: firebase functions:secrets:set GEMINI_API_KEY
 *
 * ─────────────────────────────────────────────────────────────
 * ROUND LIFECYCLE
 * ─────────────────────────────────────────────────────────────
 *
 *   waiting → judging → complete
 *
 * waiting  : Lobby is open. Players join by submitting a photo and
 *            optional entry fee. Anyone can leave and get refunded.
 *            Theme can be changed by any participant.
 *            Round deletes itself if the last player leaves.
 *
 *            PRE-SCORING: Each photo is scored by Gemini in the
 *            background immediately after joinRound completes.
 *            scored_for_theme tracks which theme it was scored for.
 *            If the theme changes (updateRoundTheme), all existing
 *            scores are nulled out so they are re-scored at start time.
 *
 * judging  : Triggered when any participant presses Start Round
 *            (requires 2+ submissions). Submissions locked.
 *            startRound checks each submission:
 *              - ai_score != null AND scored_for_theme == current theme → use it
 *              - otherwise → score now with Gemini (fallback path)
 *            Scores written to submission documents one by one
 *            so the UI can reveal them in real time.
 *
 * complete : All scores written. Winner(s) determined.
 *            90% of pot paid to winner(s). 10% platform fee logged.
 *            Stats written to competitions/{id}/members/{userId}
 *            so leaderboards are competition-scoped.
 *            Each participant's entry_fee added to total_round_staked.
 *            welcome_bonus_unlocked flips when
 *            total_round_staked >= total_locked_credits.
 *
 * ─────────────────────────────────────────────────────────────
 * DATA MODEL
 * ─────────────────────────────────────────────────────────────
 *
 * rounds/{roundId}
 *   competition_id    : string
 *   status            : "waiting" | "judging" | "complete"
 *   theme_id          : string
 *   theme_name        : string
 *   created_by        : string (userId)
 *   total_pot         : number
 *   platform_fee      : number
 *   round_reward      : number
 *   winner_ids        : string[]
 *   participant_count : number
 *   created_at        : timestamp
 *   started_at        : timestamp
 *   ended_at          : timestamp
 *   last_nudge_sent   : timestamp
 *
 * rounds/{roundId}/submissions/{userId}
 *   user_id           : string
 *   photo_url         : string
 *   entry_fee         : number
 *   is_from_camera    : boolean
 *   ai_score          : number | null   — null until pre-score completes
 *   ai_reason         : string | null
 *   scored_for_theme  : string | null   — theme name the score was generated for
 *   submitted_at      : timestamp
 *
 * competitions/{competitionId}/members/{userId}
 *   rounds_won            : number  — scoped to this competition
 *   rounds_played         : number  — scoped to this competition
 *   total_round_winnings  : number  — scoped to this competition
 *
 * platform_revenue/{docId}
 *   round_id          : string
 *   competition_id    : string
 *   fee_amount        : number
 *   total_pot         : number
 *   round_reward      : number
 *   winner_ids        : string[]
 *   num_players       : number
 *   collected_at      : timestamp
 */

const { onCall } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const logger = require('firebase-functions/logger');

let _db;
const getDb = () => {
  if (!_db) _db = admin.firestore();
  return _db;
};

const PLATFORM_FEE_RATE  = 0.10;
const MIN_ENTRY_FEE      = 0.20;
const MAX_ENTRY_FEE      = 5.00;
const NUDGE_COOLDOWN_MS  = 2 * 60 * 1000;
const GEMINI_MODEL       = 'gemini-2.5-flash';
const GEMINI_ENDPOINT    = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;

// Retry config for Gemini scoring
const GEMINI_MAX_ATTEMPTS  = 3;
const GEMINI_BASE_DELAY_MS = 1000; // 1s, 2s between attempts


// ─────────────────────────────────────────────────────────────
// HELPER — verify competition membership
// ─────────────────────────────────────────────────────────────

async function verifyMembership(db, competitionId, userId) {
  const memberDoc = await db
    .collection('competitions').doc(competitionId)
    .collection('members').doc(userId)
    .get();

  if (!memberDoc.exists) {
    throw new Error('You are not a member of this competition');
  }
}


// ─────────────────────────────────────────────────────────────
// HELPER — score a single photo with Gemini
// ─────────────────────────────────────────────────────────────

async function scorePhotoWithGemini(photoUrl, themeName, apiKey) {
  logger.info(`scorePhotoWithGemini: fetching photo from ${photoUrl.substring(0, 80)}...`);

  let base64Image;
  let contentType = 'image/jpeg';

  try {
    const imageResponse = await fetch(photoUrl);
    if (!imageResponse.ok) {
      throw new Error(`Photo fetch failed: ${imageResponse.status} ${imageResponse.statusText}`);
    }
    contentType = imageResponse.headers.get('content-type') || 'image/jpeg';
    contentType = contentType.split(';')[0].trim();
    const imageBuffer = await imageResponse.arrayBuffer();
    base64Image = Buffer.from(imageBuffer).toString('base64');
    logger.info(`scorePhotoWithGemini: image fetched OK, size=${imageBuffer.byteLength} bytes, type=${contentType}`);
  } catch (fetchErr) {
    throw new Error(`Failed to fetch photo for Gemini: ${fetchErr.message}`);
  }

  const prompt = `You are judging a photo competition between friends. These are casual, personal photos — outfits, selfies, food pics, pet photos, whatever friends share with each other or dig out of their camera roll.

    Theme: "${themeName}"

    Your job is to judge this photo on TWO things:

    1. THEME FIT — Does this photo actually match the theme? If it's way off topic, score it low regardless of quality.

    2. QUALITY & EFFORT — Assuming it's on theme, how good is it really? For outfits: is the fit actually good or kinda weak? For selfies: is it a genuinely good selfie or a lazy one? For food pics: does it look appetizing or unappealing? For views: is it stunning or just a random window shot? Be honest. A photo can be on theme and still be bad.

    SCORING:
    - Score from 1.0 to 9.9
    - 1.0–3.9: Off theme, or on theme but genuinely bad execution
    - 4.0–6.5: On theme, decent, nothing special
    - 6.6–8.5: On theme, clearly good, some effort and quality
    - 8.6–9.9: On theme and exceptional — would stand out in any group chat
    - DO NOT default to the middle. Use the full range. Be decisive.

    TONE:
    Be honest and conversational, like a friend who's genuinely judging their mate's entry. Hype it up if it deserves it. A little teasing is fine if it misses. But always explain WHY — what specifically works or doesn't.

    Respond with ONLY this JSON, nothing else before or after it:
    {"score": <number>, "reason": "<one punchy sentence, max 15 words>"}`;

  const requestBody = {
    contents: [{
      parts: [
        {
          inline_data: {
            mime_type: contentType,
            data: base64Image
          }
        },
        { text: prompt }
      ]
    }],
    generationConfig: {
      temperature: 0.7,
      maxOutputTokens: 1024
    }
  };

  logger.info(`scorePhotoWithGemini: calling Gemini API with model ${GEMINI_MODEL}`);

  const response = await fetch(`${GEMINI_ENDPOINT}?key=${apiKey}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(requestBody)
  });

  const responseText = await response.text();

  if (!response.ok) {
    logger.error(`scorePhotoWithGemini: Gemini API error ${response.status}: ${responseText}`);
    throw new Error(`Gemini API error ${response.status}: ${responseText}`);
  }

  logger.info(`scorePhotoWithGemini: Gemini raw response: ${responseText.substring(0, 500)}`);

  let data;
  try {
    data = JSON.parse(responseText);
  } catch {
    throw new Error(`Gemini response was not valid JSON: ${responseText.substring(0, 200)}`);
  }

  if (!data.candidates || data.candidates.length === 0) {
    logger.warn(`scorePhotoWithGemini: no candidates in response. Full response: ${responseText}`);
    throw new Error('Gemini returned no candidates');
  }

  const candidate = data.candidates[0];

  if (candidate.finishReason === 'SAFETY') {
    logger.warn(`scorePhotoWithGemini: content blocked by safety filter`);
    throw new Error('Content blocked by safety filter');
  }

  const rawText = candidate?.content?.parts?.[0]?.text ?? '';
  logger.info(`scorePhotoWithGemini: extracted text: ${rawText}`);

  if (!rawText) {
    throw new Error(`Gemini returned empty text. Finish reason: ${candidate.finishReason}`);
  }

  const cleaned = rawText
    .replace(/```json/gi, '')
    .replace(/```/g, '')
    .trim();

  let parsed;
  try {
    parsed = JSON.parse(cleaned);
  } catch (parseErr) {
    logger.error(`scorePhotoWithGemini: JSON parse failed. Raw: "${rawText}", Error: ${parseErr.message}`);
    throw new Error(`Could not parse Gemini response as JSON: ${rawText.substring(0, 100)}`);
  }

  if (typeof parsed.score === 'undefined' || typeof parsed.reason === 'undefined') {
    logger.error(`scorePhotoWithGemini: parsed JSON missing score or reason: ${JSON.stringify(parsed)}`);
    throw new Error(`Gemini response missing score or reason: ${JSON.stringify(parsed)}`);
  }

  const score = Math.min(9.9, Math.max(1.0, parseFloat(parsed.score) || 5.0));
  const reason = typeof parsed.reason === 'string' && parsed.reason.length > 0
    ? parsed.reason
    : 'A solid effort for this theme.';

  logger.info(`scorePhotoWithGemini: scored ${score} — "${reason}"`);
  return { score, reason };
}


// ─────────────────────────────────────────────────────────────
// HELPER — score with exponential backoff retry
//
// Retries transient Gemini failures (network blips, 503/529
// overload responses) up to GEMINI_MAX_ATTEMPTS times.
// Delays: 1s after attempt 1, 2s after attempt 2.
//
// Does NOT retry safety filter blocks — those are permanent
// and retrying would waste time and quota.
// ─────────────────────────────────────────────────────────────

async function scoreWithRetry(photoUrl, themeName, apiKey) {
  let lastError;

  for (let attempt = 1; attempt <= GEMINI_MAX_ATTEMPTS; attempt++) {
    try {
      return await scorePhotoWithGemini(photoUrl, themeName, apiKey);
    } catch (err) {
      lastError = err;

      // Safety blocks are permanent — no point retrying
      if (err.message === 'Content blocked by safety filter') {
        logger.warn(`scoreWithRetry: safety block on attempt ${attempt}, not retrying`);
        throw err;
      }

      if (attempt < GEMINI_MAX_ATTEMPTS) {
        const delay = GEMINI_BASE_DELAY_MS * Math.pow(2, attempt - 1);
        logger.warn(`scoreWithRetry: attempt ${attempt}/${GEMINI_MAX_ATTEMPTS} failed — retrying in ${delay}ms. Error: ${err.message}`);
        await new Promise(resolve => setTimeout(resolve, delay));
      }
    }
  }

  logger.error(`scoreWithRetry: all ${GEMINI_MAX_ATTEMPTS} attempts failed. Last error: ${lastError.message}`);
  throw lastError;
}


// ─────────────────────────────────────────────────────────────
// HELPER — pre-score a submission in the background
//
// Called fire-and-forget from joinRound after the transaction
// completes. Writes ai_score, ai_reason, and scored_for_theme
// to the submission doc. If it fails, the score stays null and
// startRound will score it live as a fallback.
//
// The round status is checked before writing — if the round
// has moved to judging or complete by the time scoring finishes,
// the write is skipped because startRound is already handling it.
// ─────────────────────────────────────────────────────────────

async function preScoreSubmission(submissionRef, roundRef, photoUrl, themeName, apiKey) {
  try {
    logger.info(`preScoreSubmission: scoring ${submissionRef.id} for theme "${themeName}"`);

    const { score, reason } = await scoreWithRetry(photoUrl, themeName, apiKey);

    // Only write if the round is still in waiting — avoids a race
    // where startRound already wrote a definitive score
    const roundDoc = await roundRef.get();
    if (!roundDoc.exists || roundDoc.data().status !== 'waiting') {
      logger.info(`preScoreSubmission: round no longer waiting, skipping write for ${submissionRef.id}`);
      return;
    }

    // Also confirm the theme hasn't changed since we started scoring
    const currentTheme = roundDoc.data().theme_name;
    if (currentTheme !== themeName) {
      logger.info(`preScoreSubmission: theme changed from "${themeName}" to "${currentTheme}", skipping write for ${submissionRef.id}`);
      return;
    }

    await submissionRef.update({
      ai_score:        score,
      ai_reason:       reason,
      scored_for_theme: themeName
    });

    logger.info(`preScoreSubmission: wrote score ${score} for ${submissionRef.id}`);
  } catch (err) {
    // Non-fatal — startRound will handle it
    logger.error(`preScoreSubmission: failed for ${submissionRef.id}: ${err.message}`);
  }
}


// ─────────────────────────────────────────────────────────────
// HELPER — update staking progress and unlock bonus if threshold met
// ─────────────────────────────────────────────────────────────

async function updateStakingProgress(submissionDocs, db) {
  for (const doc of submissionDocs) {
    const userId   = doc.id;
    const entryFee = doc.data().entry_fee ?? 0;

    if (entryFee <= 0) continue;

    const userRef = db.collection('users').doc(userId);

    await db.runTransaction(async (t) => {
      const userDoc  = await t.get(userRef);
      const userData = userDoc.data();

      if (!userData?.bonus_credited) return;
      if (userData?.welcome_bonus_unlocked === true) return;

      const totalLocked = userData?.total_locked_credits ?? 5.00;
      const stakedSoFar = userData?.total_round_staked   ?? 0;
      const newStaked   = parseFloat((stakedSoFar + entryFee).toFixed(2));
      const nowUnlocked = newStaked >= totalLocked;

      const update = {
        total_round_staked: admin.firestore.FieldValue.increment(entryFee)
      };

      if (nowUnlocked) {
        update.welcome_bonus_unlocked = true;
        logger.info(`updateStakingProgress: bonus unlocked for ${userId} — staked $${newStaked} of $${totalLocked}`);
      }

      t.set(userRef, update, { merge: true });
    });
  }
}


// ─────────────────────────────────────────────────────────────
// createRound
// ─────────────────────────────────────────────────────────────

exports.createRound = onCall({
  cors: ['*'],
  maxInstances: 50,
  minInstances: 1
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId = request.auth.uid;
  const { competitionId, themeId, themeName } = request.data;

  if (!competitionId) throw new Error('competitionId is required');
  if (!themeName)     throw new Error('themeName is required');

  const db = getDb();
  await verifyMembership(db, competitionId, userId);

  const activeRoundSnap = await db.collection('rounds')
    .where('competition_id', '==', competitionId)
    .where('status', 'in', ['waiting', 'judging'])
    .limit(1)
    .get();

  if (!activeRoundSnap.empty) {
    const existingRound = activeRoundSnap.docs[0];
    return { success: true, round_id: existingRound.id, created: false };
  }

  const roundRef = db.collection('rounds').doc();

  await roundRef.set({
    competition_id:    competitionId,
    status:            'waiting',
    theme_id:          themeId ?? null,
    theme_name:        themeName,
    created_by:        userId,
    total_pot:         0,
    platform_fee:      0,
    round_reward:      0,
    winner_ids:        [],
    participant_count: 0,
    created_at:        admin.firestore.FieldValue.serverTimestamp(),
    started_at:        null,
    ended_at:          null,
    last_nudge_sent:   null
  });

  logger.info(`createRound: round ${roundRef.id} created for competition ${competitionId} by ${userId}`);
  return { success: true, round_id: roundRef.id, created: true };
});


// ─────────────────────────────────────────────────────────────
// updateRoundTheme
//
// When the theme changes, all existing pre-scores are invalidated
// by nulling out ai_score, ai_reason, and scored_for_theme on
// every submission. This ensures startRound always scores against
// the final theme, not a stale one.
// ─────────────────────────────────────────────────────────────

exports.updateRoundTheme = onCall({
  cors: ['*'],
  maxInstances: 50,
  minInstances: 1,
  secrets: ['GEMINI_API_KEY']
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId = request.auth.uid;
  const { roundId, themeId, themeName } = request.data;

  if (!roundId)   throw new Error('roundId is required');
  if (!themeName) throw new Error('themeName is required');

  const db = getDb();
  const roundRef = db.collection('rounds').doc(roundId);
  const roundDoc = await roundRef.get();

  if (!roundDoc.exists) throw new Error('Round not found');
  if (roundDoc.data().status !== 'waiting') throw new Error('Cannot change theme after round has started');

  const previousTheme = roundDoc.data().theme_name;

  // Only invalidate and re-score if the theme actually changed
  if (previousTheme === themeName) {
    return { success: true };
  }

  // Update the round theme
  await roundRef.update({
    theme_id:   themeId ?? null,
    theme_name: themeName
  });

  logger.info(`updateRoundTheme: theme updated from "${previousTheme}" to "${themeName}" in round ${roundId} by ${userId}`);

  // Null out all existing pre-scores — they were for the old theme
  const submissionsSnap = await roundRef.collection('submissions').get();

  if (!submissionsSnap.empty) {
    const batch = db.batch();
    submissionsSnap.docs.forEach(doc => {
      batch.update(doc.ref, {
        ai_score:         null,
        ai_reason:        null,
        scored_for_theme: null
      });
    });
    await batch.commit();
    logger.info(`updateRoundTheme: invalidated ${submissionsSnap.size} pre-scores for round ${roundId}`);

    // Kick off fresh pre-scoring for all existing submissions against new theme
    const apiKey = process.env.GEMINI_API_KEY;
    if (apiKey) {
      submissionsSnap.docs.forEach(doc => {
        const photoUrl = doc.data().photo_url;
        if (photoUrl) {
          preScoreSubmission(doc.ref, roundRef, photoUrl, themeName, apiKey);
        }
      });
      logger.info(`updateRoundTheme: kicked off re-scoring for ${submissionsSnap.size} submissions`);
    } else {
      logger.warn(`updateRoundTheme: GEMINI_API_KEY not available, skipping re-scoring — startRound will handle it`);
    }
  }

  return { success: true };
});


// ─────────────────────────────────────────────────────────────
// joinRound
//
// After the transaction completes, kicks off background pre-scoring
// so the score is ready by the time startRound is called.
// joinRound itself returns immediately — pre-scoring is fire-and-forget.
// ─────────────────────────────────────────────────────────────

exports.joinRound = onCall({
  cors: ['*'],
  maxInstances: 50,
  minInstances: 1,
  secrets: ['GEMINI_API_KEY']
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId = request.auth.uid;
  const { roundId, competitionId, photoUrl, entryFee, isFromCamera } = request.data;

  if (!roundId)       throw new Error('roundId is required');
  if (!competitionId) throw new Error('competitionId is required');
  if (!photoUrl)      throw new Error('photoUrl is required');

  const fee = typeof entryFee === 'number' ? entryFee : 0;
  if (fee < 0) throw new Error('Entry fee cannot be negative');
  if (fee > 0 && fee < MIN_ENTRY_FEE) {
    throw new Error(`Minimum paid entry is $${MIN_ENTRY_FEE.toFixed(2)}`);
  }
  if (fee > MAX_ENTRY_FEE) {
    throw new Error(`Maximum entry fee is $${MAX_ENTRY_FEE.toFixed(2)}`);
  }

  const db = getDb();
  await verifyMembership(db, competitionId, userId);

  const roundRef = db.collection('rounds').doc(roundId);
  let themeName;

  await db.runTransaction(async (t) => {
    const roundDoc = await t.get(roundRef);

    if (!roundDoc.exists) throw new Error('Round not found');
    if (roundDoc.data().status !== 'waiting') {
      throw new Error('This round has already started');
    }

    themeName = roundDoc.data().theme_name;

    const submissionRef = roundRef.collection('submissions').doc(userId);
    const existingSubmission = await t.get(submissionRef);
    if (existingSubmission.exists) {
      throw new Error('You have already joined this round');
    }

    if (fee > 0) {
      const userRef = db.collection('users').doc(userId);
      const userDoc = await t.get(userRef);
      const currentBalance = userDoc.exists ? (userDoc.data().wallet_balance ?? 0) : 0;

      if (currentBalance < fee) {
        throw new Error(
          `Insufficient funds. Balance: $${currentBalance.toFixed(2)}, Required: $${fee.toFixed(2)}`
        );
      }

      const newBalance = parseFloat((currentBalance - fee).toFixed(2));

      t.set(userRef, {
        wallet_balance: admin.firestore.FieldValue.increment(-fee)
      }, { merge: true });

      const txRef = db.collection('wallet_transactions').doc();
      t.set(txRef, {
        user_id:        userId,
        type:           'debit',
        amount:         fee,
        reason:         'round_entry_fee',
        competition_id: competitionId,
        metadata:       { round_id: roundId },
        balance_before: currentBalance,
        balance_after:  newBalance,
        created_at:     admin.firestore.FieldValue.serverTimestamp()
      });
    }

    const submissionRef2 = roundRef.collection('submissions').doc(userId);
    t.set(submissionRef2, {
      user_id:          userId,
      photo_url:        photoUrl,
      entry_fee:        fee,
      is_from_camera:   isFromCamera === true,
      ai_score:         null,
      ai_reason:        null,
      scored_for_theme: null,
      submitted_at:     admin.firestore.FieldValue.serverTimestamp()
    });

    t.update(roundRef, {
      total_pot:         admin.firestore.FieldValue.increment(fee),
      participant_count: admin.firestore.FieldValue.increment(1)
    });
  });

  logger.info(`joinRound: user ${userId} joined round ${roundId} with entry fee $${fee}`);

  // ── Fire-and-forget pre-scoring ───────────────────────────
  // Do not await — joinRound returns immediately while scoring
  // runs in the background. startRound will use the score if
  // it's ready, or fall back to live scoring if it isn't.
  const apiKey = process.env.GEMINI_API_KEY;
  if (apiKey && themeName) {
    const submissionRef = roundRef.collection('submissions').doc(userId);
    preScoreSubmission(submissionRef, roundRef, photoUrl, themeName, apiKey);
  } else {
    logger.warn(`joinRound: skipping pre-score for ${userId} — apiKey or themeName missing`);
  }

  return { success: true };
});


// ─────────────────────────────────────────────────────────────
// leaveRound
// ─────────────────────────────────────────────────────────────

exports.leaveRound = onCall({
  cors: ['*'],
  maxInstances: 50,
  minInstances: 1
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId = request.auth.uid;
  const { roundId, competitionId } = request.data;

  if (!roundId)       throw new Error('roundId is required');
  if (!competitionId) throw new Error('competitionId is required');

  const db = getDb();
  const roundRef = db.collection('rounds').doc(roundId);

  let entryFee = 0;
  let remainingCount = 0;

  await db.runTransaction(async (t) => {
    const roundDoc = await t.get(roundRef);

    if (!roundDoc.exists) throw new Error('Round not found');
    if (roundDoc.data().status !== 'waiting') {
      throw new Error('Cannot leave a round that has already started');
    }

    const submissionRef = roundRef.collection('submissions').doc(userId);
    const submissionDoc = await t.get(submissionRef);

    if (!submissionDoc.exists) throw new Error('You are not in this round');

    entryFee = submissionDoc.data().entry_fee ?? 0;
    remainingCount = (roundDoc.data().participant_count ?? 1) - 1;

    if (entryFee > 0) {
      const userRef = db.collection('users').doc(userId);
      const userDoc = await t.get(userRef);
      const currentBalance = userDoc.exists ? (userDoc.data().wallet_balance ?? 0) : 0;
      const newBalance = parseFloat((currentBalance + entryFee).toFixed(2));

      t.set(userRef, {
        wallet_balance: admin.firestore.FieldValue.increment(entryFee)
      }, { merge: true });

      const txRef = db.collection('wallet_transactions').doc();
      t.set(txRef, {
        user_id:        userId,
        type:           'credit',
        amount:         entryFee,
        reason:         'round_entry_refund',
        competition_id: competitionId,
        metadata:       { round_id: roundId },
        balance_before: currentBalance,
        balance_after:  newBalance,
        created_at:     admin.firestore.FieldValue.serverTimestamp()
      });
    }

    t.delete(submissionRef);

    if (remainingCount <= 0) {
      t.delete(roundRef);
    } else {
      t.update(roundRef, {
        total_pot:         admin.firestore.FieldValue.increment(-entryFee),
        participant_count: admin.firestore.FieldValue.increment(-1)
      });
    }
  });

  const roundDeleted = remainingCount <= 0;
  logger.info(`leaveRound: user ${userId} left round ${roundId}. Refunded $${entryFee}. Round deleted: ${roundDeleted}`);

  return { success: true, refund_amount: entryFee, round_deleted: roundDeleted };
});


// ─────────────────────────────────────────────────────────────
// startRound
//
// Uses pre-scored results where available. Falls back to live
// Gemini scoring for any submission where:
//   - ai_score is null (pre-score failed or still in flight)
//   - scored_for_theme doesn't match the current theme
//     (theme changed after submission but before updateRoundTheme
//     could null it out — edge case belt-and-braces check)
// ─────────────────────────────────────────────────────────────

exports.startRound = onCall({
  cors: ['*'],
  maxInstances: 50,
  minInstances: 1,
  secrets: ['GEMINI_API_KEY'],
  timeoutSeconds: 120
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId = request.auth.uid;
  const { roundId, competitionId } = request.data;

  if (!roundId)       throw new Error('roundId is required');
  if (!competitionId) throw new Error('competitionId is required');

  const db = getDb();
  const roundRef = db.collection('rounds').doc(roundId);

  // ── Validate and lock into judging ────────────────────────

  await db.runTransaction(async (t) => {
    const roundDoc = await t.get(roundRef);

    if (!roundDoc.exists) throw new Error('Round not found');
    if (roundDoc.data().status !== 'waiting') throw new Error('Round has already started');

    const participantCount = roundDoc.data().participant_count ?? 0;
    if (participantCount < 2) throw new Error('Need at least 2 players to start');

    const submissionRef = roundRef.collection('submissions').doc(userId);
    const submissionDoc = await t.get(submissionRef);
    if (!submissionDoc.exists) throw new Error('You are not in this round');

    t.update(roundRef, {
      status:     'judging',
      started_at: admin.firestore.FieldValue.serverTimestamp()
    });
  });

  logger.info(`startRound: round ${roundId} flipped to judging`);

  try {
    const submissionsSnap = await roundRef.collection('submissions').get();
    const roundDoc        = await roundRef.get();
    const roundData       = roundDoc.data();
    const themeName       = roundData.theme_name ?? 'General Photography';
    const totalPot        = roundData.total_pot  ?? 0;

    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) throw new Error('GEMINI_API_KEY secret not configured');

    // ── Score all photos — use pre-score where valid ──────────
    //
    // For each submission we check two conditions:
    //   1. ai_score is not null — pre-score completed
    //   2. scored_for_theme matches current theme — score is fresh
    //
    // If both pass, skip Gemini entirely for that submission.
    // Otherwise score live, exactly as before.

    const scoringPromises = submissionsSnap.docs.map(async (doc) => {
      const submissionUserId = doc.id;
      const photoUrl         = doc.data().photo_url;
      const existingScore    = doc.data().ai_score;
      const existingReason   = doc.data().ai_reason;
      const scoredForTheme   = doc.data().scored_for_theme;

      const preScoreValid = existingScore !== null
        && existingScore !== undefined
        && scoredForTheme === themeName;

      if (preScoreValid) {
        // Happy path — pre-score is ready, skip Gemini call entirely
        logger.info(`startRound: using pre-score ${existingScore} for ${submissionUserId}`);
        return {
          userId:   submissionUserId,
          score:    existingScore,
          reason:   existingReason,
          entryFee: doc.data().entry_fee ?? 0
        };
      }

      // Fallback — score live (pre-score missed, failed, or theme changed)
      logger.info(`startRound: pre-score not ready for ${submissionUserId}, scoring live`);

      try {
        const { score, reason } = await scoreWithRetry(photoUrl, themeName, apiKey);
        await doc.ref.update({
          ai_score:         score,
          ai_reason:        reason,
          scored_for_theme: themeName
        });
        logger.info(`startRound: live scored ${submissionUserId} → ${score}`);
        return { userId: submissionUserId, score, reason, entryFee: doc.data().entry_fee ?? 0 };
      } catch (err) {
        // All retry attempts exhausted — use neutral fallback so the
        // round can still complete rather than failing entirely.
        logger.error(`startRound: scoring failed for ${submissionUserId} after ${GEMINI_MAX_ATTEMPTS} attempts. Error: ${err.message}`, err);
        const fallbackScore  = 5.0;
        const fallbackReason = "We couldn't fully analyse this photo, so we've given it a neutral score.";
        await doc.ref.update({
          ai_score:         fallbackScore,
          ai_reason:        fallbackReason,
          scored_for_theme: themeName
        });
        return { userId: submissionUserId, score: fallbackScore, reason: fallbackReason, entryFee: doc.data().entry_fee ?? 0 };
      }
    });

    const results = await Promise.all(scoringPromises);

    // ── Determine winner(s) ──────────────────────────────────

    const highScore = Math.max(...results.map(r => r.score));
    const winners   = results.filter(r => r.score === highScore);
    const winnerIds = winners.map(w => w.userId);

    // ── Calculate payouts ────────────────────────────────────

    const platformFee     = parseFloat((totalPot * PLATFORM_FEE_RATE).toFixed(2));
    const roundReward     = parseFloat((totalPot - platformFee).toFixed(2));
    const payoutPerWinner = winners.length > 0 && roundReward > 0
      ? parseFloat((roundReward / winners.length).toFixed(2))
      : 0;

    // ── Credit winner(s) wallets + update competition stats ──

    for (const winner of winners) {
      if (payoutPerWinner <= 0) break;

      const winnerUserRef   = db.collection('users').doc(winner.userId);
      const winnerMemberRef = db.collection('competitions')
        .doc(competitionId)
        .collection('members')
        .doc(winner.userId);

      await db.runTransaction(async (t) => {
        const winnerDoc      = await t.get(winnerUserRef);
        const currentBalance = winnerDoc.exists ? (winnerDoc.data().wallet_balance ?? 0) : 0;
        const newBalance     = parseFloat((currentBalance + payoutPerWinner).toFixed(2));

        t.set(winnerUserRef, {
          wallet_balance: admin.firestore.FieldValue.increment(payoutPerWinner)
        }, { merge: true });

        t.set(winnerMemberRef, {
          rounds_won:           admin.firestore.FieldValue.increment(1),
          total_round_winnings: admin.firestore.FieldValue.increment(payoutPerWinner)
        }, { merge: true });

        const txRef = db.collection('wallet_transactions').doc();
        t.set(txRef, {
          user_id:        winner.userId,
          type:           'credit',
          amount:         payoutPerWinner,
          reason:         'round_win',
          competition_id: competitionId,
          metadata: {
            round_id:      roundId,
            ai_score:      winner.score,
            total_winners: winners.length,
            theme:         themeName
          },
          balance_before: currentBalance,
          balance_after:  newBalance,
          created_at:     admin.firestore.FieldValue.serverTimestamp()
        });
      });

      logger.info(`startRound: $${payoutPerWinner} credited to winner ${winner.userId}`);
    }

    // ── Increment rounds_played for all participants ──────────

    for (const result of results) {
      const memberRef = db.collection('competitions')
        .doc(competitionId)
        .collection('members')
        .doc(result.userId);

      await memberRef.set({
        rounds_played: admin.firestore.FieldValue.increment(1)
      }, { merge: true });
    }

    // ── Log platform revenue ─────────────────────────────────

    if (platformFee > 0) {
      const revenueRef = db.collection('platform_revenue').doc();
      await revenueRef.set({
        round_id:       roundId,
        competition_id: competitionId,
        fee_amount:     platformFee,
        total_pot:      totalPot,
        round_reward:   roundReward,
        winner_ids:     winnerIds,
        num_players:    results.length,
        collected_at:   admin.firestore.FieldValue.serverTimestamp()
      });

      logger.info(`startRound: platform fee $${platformFee} logged for round ${roundId}`);
    }

    // ── Update staking progress + unlock bonus if threshold met

    await updateStakingProgress(submissionsSnap.docs, db);

    // ── Mark round complete ──────────────────────────────────

    await roundRef.update({
      status:       'complete',
      winner_ids:   winnerIds,
      platform_fee: platformFee,
      round_reward: roundReward,
      ended_at:     admin.firestore.FieldValue.serverTimestamp()
    });

    logger.info(`startRound: round ${roundId} complete. Winners: ${winnerIds.join(', ')}. Pot: $${totalPot}. Fee: $${platformFee}. Reward: $${roundReward}`);

    return {
      success:           true,
      winner_ids:        winnerIds,
      high_score:        highScore,
      total_pot:         totalPot,
      platform_fee:      platformFee,
      round_reward:      roundReward,
      payout_per_winner: payoutPerWinner,
      results:           results.map(r => ({
        user_id:   r.userId,
        score:     r.score,
        reason:    r.reason,
        entry_fee: r.entryFee
      }))
    };

  } catch (error) {
    logger.error(`startRound: error during judging of round ${roundId}:`, error);

    await roundRef.update({
      status:   'failed',
      ended_at: admin.firestore.FieldValue.serverTimestamp()
    });

    throw error;
  }
});


// ─────────────────────────────────────────────────────────────
// sendRoundNudge
// ─────────────────────────────────────────────────────────────

exports.sendRoundNudge = onCall({
  cors: ['*'],
  maxInstances: 50
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId = request.auth.uid;
  const { competitionId, competitionName } = request.data;

  if (!competitionId) throw new Error('competitionId is required');

  const db = getDb();
  await verifyMembership(db, competitionId, userId);

  const competitionRef = db.collection('competitions').doc(competitionId);
  const competitionDoc = await competitionRef.get();
  const lastNudge      = competitionDoc.data()?.last_nudge_sent?.toMillis() ?? 0;

  if (Date.now() - lastNudge < NUDGE_COOLDOWN_MS) {
    const secondsLeft = Math.ceil((NUDGE_COOLDOWN_MS - (Date.now() - lastNudge)) / 1000);
    throw new Error(`Please wait ${secondsLeft} seconds before sending another nudge`);
  }

  await competitionRef.set({
    last_nudge_sent: admin.firestore.FieldValue.serverTimestamp()
  }, { merge: true });

  const nudgingUserDoc  = await db.collection('users').doc(userId).get();
  const nudgingUserName = nudgingUserDoc.data()?.name ?? 'Someone';

  const membersSnap = await db
    .collection('competitions').doc(competitionId)
    .collection('members')
    .get();

  const memberIds = membersSnap.docs
    .map(doc => doc.id)
    .filter(id => id !== userId);

  if (memberIds.length === 0) return { success: true, sent: 0 };

  const chunkSize = 30;
  const chunks    = [];
  for (let i = 0; i < memberIds.length; i += chunkSize) {
    chunks.push(memberIds.slice(i, i + chunkSize));
  }

  const fcmTokens = [];

  for (const chunk of chunks) {
    const usersSnap = await db.collection('users')
      .where(admin.firestore.FieldPath.documentId(), 'in', chunk)
      .get();

    usersSnap.docs.forEach(doc => {
      const token = doc.data()?.fcmToken;
      if (token) fcmTokens.push(token);
    });
  }

  if (fcmTokens.length === 0) {
    logger.info(`sendRoundNudge: no FCM tokens found for competition ${competitionId}`);
    return { success: true, sent: 0 };
  }

  const compName = competitionName ?? 'your competition';
  const multicastMessage = {
    notification: {
      title: `${nudgingUserName} wants to play! 🎮`,
      body:  `Join the round in ${compName}`
    },
    data: {
      type:          'round_nudge',
      competitionId: competitionId
    },
    apns: {
      payload: {
        aps: { sound: 'default', badge: 1 }
      }
    },
    tokens: fcmTokens
  };

  const batchResponse = await admin.messaging().sendEachForMulticast(multicastMessage);

  logger.info(`sendRoundNudge: sent ${batchResponse.successCount}/${fcmTokens.length} notifications for competition ${competitionId}`);

  return {
    success: true,
    sent:    batchResponse.successCount,
    failed:  batchResponse.failureCount
  };
});
