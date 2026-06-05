/**
 * demoRoundFunctions.js
 *
 * EXPORTS — add to index.js:
 *   const demoRound = require('./demoRoundFunctions');
 *   exports.createDemoRound = demoRound.createDemoRound;
 *   exports.startDemoRound  = demoRound.startDemoRound;
 *
 * ─────────────────────────────────────────────────────────────
 * DEMO ROUND SYSTEM
 * ─────────────────────────────────────────────────────────────
 *
 * Completely standalone from the real round infrastructure.
 * No sessions collection, no round listeners, no participant_ids.
 * The demo bot has no Firebase Auth UID — it is just data.
 *
 * FLOW:
 *   1. Client calls createDemoRound with the user's photo URL
 *      and their chosen entry fee.
 *      - Real debit written atomically to wallet + wallet_transactions
 *      - Demo round document created in demo_rounds/{demoRoundId}
 *      - Bot photo selected randomly from DEMO_BOT_PHOTO_POOL
 *      - Pre-scoring of both photos kicks off in background
 *      - Returns demoRoundId + botPhotoUrl so client can show judging
 *
 *   2. Client shows DemoJudgingView (same as real judging).
 *
 *   3. Client calls startDemoRound with demoRoundId.
 *      - Uses pre-scores if ready, scores live as fallback
 *      - Determines winner
 *      - If user wins: credits winnings to wallet_balance AND
 *        increments total_locked_credits (same as promo credit system)
 *      - Writes wallet_transactions audit records for all movements
 *      - Updates demo_rounds document with full results
 *      - Returns full result payload to client
 *
 * ─────────────────────────────────────────────────────────────
 * SETUP REQUIRED
 * ─────────────────────────────────────────────────────────────
 *
 * Set DEMO_BOT_NAME to whatever name you want displayed in the UI.
 * DEMO_BOT_PHOTO_URL points to Sarah's photo — host it in your own
 * Firebase Storage rather than hotlinking from Pinterest in production.
 *
 * ─────────────────────────────────────────────────────────────
 * MONEY FLOW
 * ─────────────────────────────────────────────────────────────
 *
 * Entry fee    : real debit from user wallet (reason: demo_round_entry)
 * Bot match    : house money — injected into pot math, never touches
 *                a real wallet
 * Total pot    : entryFee * 2
 * Platform fee : 10% of pot
 * Round reward : 90% of pot
 * If user wins : round_reward credited to wallet_balance AND
 *                total_locked_credits incremented by same amount
 *                (reason: demo_round_win)
 * If user loses: entry fee already gone, no further action
 *
 * ─────────────────────────────────────────────────────────────
 * demo_rounds/{demoRoundId} DOCUMENT SCHEMA
 * ─────────────────────────────────────────────────────────────
 *
 *   userId              : string   — searchable owner field
 *   status              : "pending" | "complete" | "failed"
 *   entryFee            : number
 *   botMatchAmount      : number   — mirrors entryFee
 *   totalPot            : number   — entryFee * 2
 *   platformFee         : number
 *   roundReward         : number
 *   userPhotoUrl        : string
 *   botPhotoUrl         : string
 *   botName             : string
 *   userScore           : number | null
 *   botScore            : number | null
 *   userReason          : string | null
 *   botReason           : string | null
 *   userWon             : boolean | null
 *   isTie               : boolean | null
 *   winnings            : number | null   — actual amount credited
 *   winningsLocked      : boolean         — always true if winnings > 0
 *   createdAt           : timestamp
 *   completedAt         : timestamp | null
 */

const { onCall }  = require('firebase-functions/v2/https');
const admin       = require('firebase-admin');
const logger      = require('firebase-functions/logger');

// ── Config ────────────────────────────────────────────────────

const DEMO_BOT_NAME      = 'Sarah';
const DEMO_BOT_PHOTO_URL = 'https://firebasestorage.googleapis.com/v0/b/pingbear-96b4c-us/o/static%2F205d3e3140b88c203608bbb641b19afd.jpg?alt=media&token=9e8f10a7-7b51-4eaa-8a56-a4974df4baac';
const DEMO_BOT_SCORE     = 5.4;
const DEMO_BOT_REASON    = "Dabbing in a dark park like it's 2016 isn't a vibe, it's a historical reenactment.";

const PLATFORM_FEE_RATE    = 0.10;
const MIN_ENTRY_FEE        = 0.20;
const MAX_ENTRY_FEE        = 2.00;
const GEMINI_MODEL         = 'gemini-2.5-flash';
const GEMINI_ENDPOINT      = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;
const GEMINI_MAX_ATTEMPTS  = 5;
const GEMINI_BASE_DELAY_MS = 1000;

let _db;
const getDb = () => {
  if (!_db) _db = admin.firestore();
  return _db;
};

// ── Helpers ───────────────────────────────────────────────────

function buildScoringPrompt() {
  return `You are the judge of a photo competition between friends on a group call. Your job is to give a sharp, witty one-line verdict on each photo — funny and entertaining regardless of whether the photo is good or bad.

SCORING (1.0 to 9.9):
- 1.0–3.9 : Bad. Lazy, blurry, boring, or deeply uninspiring. Most average photos live here.
- 4.0–5.9 : Mediocre. Inoffensive but forgettable. A solid meh.
- 6.0–7.4 : Decent. Something going for it but not remarkable.
- 7.5–8.5 : Genuinely good. Would stop someone scrolling. Has real personality or quality.
- 8.6–9.9 : Exceptional. Rare. Only award this if the photo would genuinely impress anyone.

CRITICAL SCORING RULES:
- The average photo scores between 4.0 and 6.0. Be stingy with 7s, very stingy with 8s, almost never give a 9.
- Do NOT be generous. A mediocre selfie is a 4 not a 7. A blurry photo is a 3 not a 6.
- Be decisive and polarising — if everyone gets 7s the game is boring.

TONE:
- Witty and entertaining always, regardless of score.
- Think: the funniest most brutally honest friend in the group who pulls no punches but is never mean-spirited.
- For bad photos: roast them, but make it funny not cruel.
- For good photos: hype them up with genuine energy, not corporate positivity.
- Never be bland. One punchy sentence. No filler.

Respond with ONLY this JSON, nothing else before or after it:
{"score": <number>, "reason": "<one punchy sentence>"}`;
}

async function scorePhotoWithGemini(photoUrl, apiKey) {
  logger.info(`[demo] scoring photo: ${photoUrl.substring(0, 80)}...`);

  const imageResponse = await fetch(photoUrl);
  if (!imageResponse.ok) throw new Error(`Photo fetch failed: ${imageResponse.status}`);
  const contentType = (imageResponse.headers.get('content-type') || 'image/jpeg').split(';')[0].trim();
  const buffer      = await imageResponse.arrayBuffer();
  const base64Image = Buffer.from(buffer).toString('base64');

  const requestBody = {
    contents: [{
      parts: [
        { inline_data: { mime_type: contentType, data: base64Image } },
        { text: buildScoringPrompt() }
      ]
    }],
    generationConfig: { temperature: 0.7, maxOutputTokens: 2048 }
  };

  const response     = await fetch(`${GEMINI_ENDPOINT}?key=${apiKey}`, {
    method:  'POST',
    headers: { 'Content-Type': 'application/json' },
    body:    JSON.stringify(requestBody)
  });
  const responseText = await response.text();
  if (!response.ok) throw new Error(`Gemini API error ${response.status}: ${responseText}`);

  const data      = JSON.parse(responseText);
  const candidate = data.candidates?.[0];
  if (!candidate)                              throw new Error('Gemini returned no candidates');
  if (candidate.finishReason === 'SAFETY')     throw new Error('Content blocked by safety filter');

  const rawText = candidate?.content?.parts?.[0]?.text ?? '';
  if (!rawText)  throw new Error(`Gemini returned empty text. Finish reason: ${candidate.finishReason}`);

  const cleaned = rawText.replace(/```json/gi, '').replace(/```/g, '').trim();

  let parsed;
  try {
    parsed = JSON.parse(cleaned);
  } catch {
    const scoreMatch  = cleaned.match(/"score"\s*:\s*([0-9.]+)/);
    const reasonMatch = cleaned.match(/"reason"\s*:\s*"([^"]+)/);
    if (scoreMatch && reasonMatch) {
      parsed = { score: parseFloat(scoreMatch[1]), reason: reasonMatch[1] };
      logger.warn(`[demo] JSON truncated, recovered via regex — score=${parsed.score}`);
    } else {
      throw new Error(`Could not parse Gemini JSON: ${rawText.substring(0, 150)}`);
    }
  }

  const score  = Math.min(9.9, Math.max(1.0, parseFloat(parsed.score) || 5.0));
  const reason = typeof parsed.reason === 'string' && parsed.reason.length > 0
    ? parsed.reason : 'A solid effort.';

  logger.info(`[demo] scored ${score} — "${reason}"`);
  return { score, reason };
}

async function scoreWithRetry(photoUrl, apiKey) {
  let lastError;
  for (let attempt = 1; attempt <= GEMINI_MAX_ATTEMPTS; attempt++) {
    try {
      return await scorePhotoWithGemini(photoUrl, apiKey);
    } catch (err) {
      lastError = err;
      if (err.message === 'Content blocked by safety filter') throw err;
      if (attempt < GEMINI_MAX_ATTEMPTS) {
        const delay = GEMINI_BASE_DELAY_MS * Math.pow(2, attempt - 1) + Math.floor(Math.random() * 500);
        logger.warn(`[demo] scoreWithRetry attempt ${attempt}/${GEMINI_MAX_ATTEMPTS} failed — retrying in ${delay}ms`);
        await new Promise(resolve => setTimeout(resolve, delay));
      }
    }
  }
  throw lastError;
}

// Pre-score a photo in background and write result to demo round doc
async function preScoreDemoPhoto(demoRoundRef, field, reasonField, photoUrl, apiKey) {
  try {
    const { score, reason } = await scoreWithRetry(photoUrl, apiKey);

    // Only write if round is still pending
    const doc = await demoRoundRef.get();
    if (!doc.exists || doc.data().status !== 'pending') {
      logger.info(`[demo] preScore: round no longer pending, skipping write for ${field}`);
      return;
    }

    await demoRoundRef.update({ [field]: score, [reasonField]: reason });
    logger.info(`[demo] preScore: wrote ${field}=${score}`);
  } catch (err) {
    logger.error(`[demo] preScore failed for ${field}: ${err.message}`);
  }
}


// ─────────────────────────────────────────────────────────────
// createDemoRound
//
// Called after the user has uploaded their photo via
// RoundUploadManager (same as real rounds — photo already in
// Storage before this function is called).
//
// 1. Validates entry fee ($0.20–$2.00)
// 2. Debits user wallet atomically + writes wallet_transaction
// 3. Creates demo_rounds document
// 4. Kicks off background pre-scoring of both photos
// 5. Returns demoRoundId + botPhotoUrl + bot display info
// ─────────────────────────────────────────────────────────────

exports.createDemoRound = onCall({
  cors:         ['*'],
  maxInstances: 50,
  minInstances: 1,
  secrets:      ['GEMINI_API_KEY']
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId                   = request.auth.uid;
  const { userPhotoUrl, entryFee } = request.data;

  if (!userPhotoUrl)              throw new Error('userPhotoUrl is required');
  if (typeof entryFee !== 'number') throw new Error('entryFee must be a number');
  if (entryFee < MIN_ENTRY_FEE)   throw new Error(`Minimum entry fee is $${MIN_ENTRY_FEE.toFixed(2)}`);
  if (entryFee > MAX_ENTRY_FEE)   throw new Error(`Maximum entry fee is $${MAX_ENTRY_FEE.toFixed(2)}`);

  const db           = getDb();
  const userRef      = db.collection('users').doc(userId);
  const demoRoundRef = db.collection('demo_rounds').doc();

  const botPhotoUrl      = DEMO_BOT_PHOTO_URL;
  const botMatchAmount   = 1.00;
  const totalPot         = parseFloat((entryFee + botMatchAmount).toFixed(2));
  const platformFee      = 0;
  const roundReward      = totalPot;

  // Debit user wallet atomically
  await db.runTransaction(async (t) => {
    const userDoc        = await t.get(userRef);
    if (!userDoc.exists) throw new Error('User not found');

    const currentBalance = userDoc.data().wallet_balance ?? 0;
    if (currentBalance < entryFee) {
      throw new Error(`Insufficient funds. Balance: $${currentBalance.toFixed(2)}, Required: $${entryFee.toFixed(2)}`);
    }

    const newBalance = parseFloat((currentBalance - entryFee).toFixed(2));

    // Debit wallet
    t.set(userRef, {
      wallet_balance: admin.firestore.FieldValue.increment(-entryFee)
    }, { merge: true });

    // Wallet transaction audit record
    const txRef = db.collection('wallet_transactions').doc();
    t.set(txRef, {
      user_id:        userId,
      type:           'debit',
      amount:         entryFee,
      reason:         'practice_round_entry',
      session_id:     null,
      metadata: {
        demo_round_id:   demoRoundRef.id,
        bot_match:       botMatchAmount,
        total_pot:       totalPot
      },
      balance_before: currentBalance,
      balance_after:  newBalance,
      created_at:     admin.firestore.FieldValue.serverTimestamp()
    });

    // Create demo round document
    t.set(demoRoundRef, {
      userId,
      status:           'pending',
      entryFee,
      botMatchAmount,
      totalPot,
      platformFee,
      roundReward,
      userPhotoUrl,
      botPhotoUrl,
      botName:          DEMO_BOT_NAME,
      userScore:        null,
      botScore:         DEMO_BOT_SCORE,
      userReason:       null,
      botReason:        DEMO_BOT_REASON,
      userWon:          null,
      isTie:            null,
      winnings:         null,
      winningsLocked:   false,
      createdAt:        admin.firestore.FieldValue.serverTimestamp(),
      completedAt:      null
    });
  });

  logger.info(`[demo] createDemoRound: ${demoRoundRef.id} for ${userId} fee=$${entryFee}`);

  // Pre-score user photo only — bot score is hardcoded
  const apiKey = process.env.GEMINI_API_KEY;
  if (apiKey) {
    preScoreDemoPhoto(demoRoundRef, 'userScore', 'userReason', userPhotoUrl, apiKey);
  }

  return {
    success:            true,
    demoRoundId:        demoRoundRef.id,
    botPhotoUrl,
    botName:            DEMO_BOT_NAME,
    totalPot,
    platformFee,
    roundReward
  };
});


// ─────────────────────────────────────────────────────────────
// startDemoRound
//
// Called by client after showing judging animation.
// The judging animation runs on the client for a fixed duration
// (e.g. 3-4 seconds) then calls this function.
//
// 1. Fetches demo round document
// 2. Uses pre-scores if both are ready, scores live as fallback
// 3. Determines winner
// 4. If user wins: credits roundReward to wallet_balance AND
//    increments total_locked_credits by same amount
//    (same pattern as seedPromoCredit / welcome bonus)
// 5. Updates demo_rounds document with full results
// 6. Returns complete result payload to client
// ─────────────────────────────────────────────────────────────

exports.startDemoRound = onCall({
  cors:           ['*'],
  maxInstances:   50,
  minInstances:   1,
  secrets:        ['GEMINI_API_KEY'],
  timeoutSeconds: 120
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId        = request.auth.uid;
  const { demoRoundId } = request.data;
  if (!demoRoundId) throw new Error('demoRoundId is required');

  const db           = getDb();
  const demoRoundRef = db.collection('demo_rounds').doc(demoRoundId);
  const demoRoundDoc = await demoRoundRef.get();

  if (!demoRoundDoc.exists)                      throw new Error('Demo round not found');
  const data = demoRoundDoc.data();
  if (data.userId !== userId)                    throw new Error('Not your demo round');
  if (data.status !== 'pending')                 throw new Error('Demo round already completed');

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) throw new Error('GEMINI_API_KEY secret not configured');

  let userScore  = data.userScore;
  let userReason = data.userReason;
  const botScore   = DEMO_BOT_SCORE;
  const botReason  = DEMO_BOT_REASON;

  // Score user live if pre-score didn't complete in time
  if (userScore === null || userScore === undefined) {
    logger.info(`[demo] startDemoRound: no pre-score for user, scoring live`);
    try {
      const r = await scoreWithRetry(data.userPhotoUrl, apiKey);
      userScore  = r.score;
      userReason = r.reason;
    } catch (err) {
      logger.error(`[demo] user scoring failed: ${err.message}`);
      userScore  = 5.0;
      userReason = "Couldn't fully analyse this photo — neutral score given.";
    }
  } else {
    logger.info(`[demo] startDemoRound: using pre-score for user: ${userScore}`);
  }

  const userWon    = userScore > botScore;
  const isTie      = userScore === botScore;
  const winnings   = (userWon || isTie) ? data.roundReward : 0;

  // Pay out if user won or tied
  if (winnings > 0) {
    const userRef = db.collection('users').doc(userId);

    await db.runTransaction(async (t) => {
      const userDoc        = await t.get(userRef);
      const currentBalance = userDoc.exists ? (userDoc.data().wallet_balance       ?? 0) : 0;
      const currentLocked  = userDoc.exists ? (userDoc.data().total_locked_credits ?? 0) : 0;
      const newBalance     = parseFloat((currentBalance + winnings).toFixed(2));
      const newLocked      = parseFloat((currentLocked  + winnings).toFixed(2));

      // Credit wallet balance
      t.set(userRef, {
        wallet_balance:         admin.firestore.FieldValue.increment(winnings),
        // Increment locked credits — same pattern as seedPromoCredit
        total_locked_credits:   newLocked,
        // Keep bonus locked since winnings are locked credits
        welcome_bonus_unlocked: false
      }, { merge: true });

      // Wallet transaction audit record
      const txRef = db.collection('wallet_transactions').doc();
      t.set(txRef, {
        user_id:        userId,
        type:           'credit',
        amount:         winnings,
        reason:         'practice_round_win',
        session_id:     null,
        metadata: {
          demo_round_id: demoRoundId,
          user_score:    userScore,
          bot_score:     botScore,
          is_tie:        isTie,
          total_pot:     data.totalPot,
          platform_fee:  data.platformFee,
          locked:        true
        },
        balance_before: currentBalance,
        balance_after:  newBalance,
        created_at:     admin.firestore.FieldValue.serverTimestamp()
      });

      // Update demo round document with full results
      t.update(demoRoundRef, {
        status:       'complete',
        userScore,
        botScore,
        userReason,
        botReason,
        userWon,
        isTie,
        winnings,
        winningsLocked: true,
        completedAt:  admin.firestore.FieldValue.serverTimestamp()
      });
    });

  } else {
    // User lost — just update the document, no wallet movement
    await demoRoundRef.update({
      status:       'complete',
      userScore,
      botScore,
      userReason,
      botReason,
      userWon:      false,
      isTie:        false,
      winnings:     0,
      winningsLocked: false,
      completedAt:  admin.firestore.FieldValue.serverTimestamp()
    });
  }

  logger.info(`[demo] startDemoRound: ${demoRoundId} complete. userScore=${userScore} botScore=${botScore} userWon=${userWon} winnings=$${winnings}`);

  return {
    success:     true,
    userScore,
    botScore,
    userReason,
    botReason,
    userWon,
    isTie,
    winnings,
    winningsLocked: winnings > 0,
    totalPot:    data.totalPot,
    platformFee: data.platformFee,
    roundReward: data.roundReward,
    botName:     DEMO_BOT_NAME,
    botPhotoUrl: data.botPhotoUrl,
    userPhotoUrl: data.userPhotoUrl
  };
});
