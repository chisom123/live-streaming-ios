/**
 * roundFunctions.js
 *
 * EXPORTS — index.js:
 *   exports.createSession = round.createSession;
 *   exports.joinSession   = round.joinSession;
 *   exports.endSession    = round.endSession;
 *   exports.inviteMore    = round.inviteMore;
 *   exports.createRound   = round.createRound;
 *   exports.joinRound     = round.joinRound;
 *   exports.leaveRound    = round.leaveRound;
 *   exports.startRound    = round.startRound;
 *
 * Secrets required:
 *   GEMINI_API_KEY  — set via: firebase functions:secrets:set GEMINI_API_KEY
 *
 * ─────────────────────────────────────────────────────────────
 * SESSION LIFECYCLE
 * ─────────────────────────────────────────────────────────────
 *
 *   active → ended
 *
 * Sessions are never deleted. last_completed_round_id is written
 * atomically with round completion so clients always have a
 * reliable pointer to the latest result.
 *
 * ─────────────────────────────────────────────────────────────
 * ROUND LIFECYCLE
 * ─────────────────────────────────────────────────────────────
 *
 *   waiting → judging → complete
 *              ↓
 *           failed
 *
 *   Any round in waiting can also go → cancelled
 *   (last player leaves, or a new round supersedes it)
 *
 * waiting   : Lobby open. Players join by submitting a photo and
 *             optional entry fee. Pre-scoring runs in background
 *             immediately after joinRound so startRound is fast.
 *
 * judging   : Triggered when any participant presses Start Round
 *             (requires 2+ submissions). Submissions locked.
 *             Uses pre-scored results where valid, scores live
 *             as fallback.
 *
 * complete  : All scores written. Winner(s) determined.
 *             90% of pot paid to winner(s). 10% platform fee.
 *             Session doc updated with last_completed_round_id.
 *
 * cancelled : Round abandoned (last player left). Safe to ignore.
 *             Never deleted — keeps audit trail intact.
 *
 * ─────────────────────────────────────────────────────────────
 * DATA MODEL
 * ─────────────────────────────────────────────────────────────
 *
 * sessions/{sessionId}
 *   status                  : "active" | "ended"
 *   created_by              : string
 *   participant_ids         : string[]
 *   invited_ids             : string[]
 *   last_completed_round_id : string | null   ← reliable results pointer
 *   round_seq               : number          ← server-side counter, avoids collection scan
 *   created_at              : timestamp
 *   ended_at                : timestamp | null
 *
 * sessions/{sessionId}/rounds/{roundId}
 *   status            : "waiting" | "judging" | "complete" | "failed" | "cancelled"
 *   round_number      : number
 *   total_pot         : number
 *   platform_fee      : number
 *   round_reward      : number
 *   winner_ids        : string[]
 *   participant_count : number
 *   created_by        : string
 *   created_at        : timestamp
 *   started_at        : timestamp | null
 *   ended_at          : timestamp | null
 *
 * sessions/{sessionId}/rounds/{roundId}/submissions/{userId}
 *   user_id        : string
 *   photo_url      : string
 *   entry_fee      : number
 *   is_from_camera : boolean
 *   ai_score       : number | null
 *   ai_reason      : string | null
 *   submitted_at   : timestamp
 */

const { onCall } = require('firebase-functions/v2/https');
const admin      = require('firebase-admin');
const logger     = require('firebase-functions/logger');

let _db;
const getDb = () => {
  if (!_db) _db = admin.firestore();
  return _db;
};

const PLATFORM_FEE_RATE    = 0.10;
const MIN_ENTRY_FEE        = 0.20;
const MAX_ENTRY_FEE        = 5.00;
const GEMINI_MODEL         = 'gemini-2.5-flash';
const GEMINI_ENDPOINT      = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;
const GEMINI_MAX_ATTEMPTS  = 5;
const GEMINI_BASE_DELAY_MS = 1000;


// ─────────────────────────────────────────────────────────────
// HELPER — verify session participation
// ─────────────────────────────────────────────────────────────

async function verifyParticipant(db, sessionId, userId) {
  const sessionDoc = await db.collection('sessions').doc(sessionId).get();
  if (!sessionDoc.exists) throw new Error('Session not found');
  const participantIds = sessionDoc.data().participant_ids ?? [];
  if (!participantIds.includes(userId)) throw new Error('You are not a participant in this session');
  return sessionDoc;
}


// ─────────────────────────────────────────────────────────────
// HELPER — build Gemini scoring prompt (no themes)
// ─────────────────────────────────────────────────────────────

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

TONE — this is the most important part:
- Witty and entertaining always, regardless of score. A brutal verdict should still make people laugh.
- Think: the funniest most brutally honest friend in the group who pulls no punches but is never mean-spirited.
- For bad photos: roast them, but make it funny not cruel.
- For good photos: hype them up with genuine energy, not corporate positivity.
- Never be bland. Never say things like nice photo or good effort. Every verdict should feel written specifically for this photo.
- One punchy sentence. No filler. Just the verdict.

Respond with ONLY this JSON, nothing else before or after it:
{"score": <number>, "reason": "<one punchy sentence>"}`;
}


// ─────────────────────────────────────────────────────────────
// HELPER — score a single photo with Gemini
// ─────────────────────────────────────────────────────────────

async function scorePhotoWithGemini(photoUrl, apiKey) {
  logger.info(`scorePhotoWithGemini: fetching ${photoUrl.substring(0, 80)}...`);

  let base64Image;
  let contentType = 'image/jpeg';

  try {
    const imageResponse = await fetch(photoUrl);
    if (!imageResponse.ok) {
      throw new Error(`Photo fetch failed: ${imageResponse.status} ${imageResponse.statusText}`);
    }
    contentType   = (imageResponse.headers.get('content-type') || 'image/jpeg').split(';')[0].trim();
    const buffer  = await imageResponse.arrayBuffer();
    base64Image   = Buffer.from(buffer).toString('base64');
    logger.info(`scorePhotoWithGemini: fetched OK — ${buffer.byteLength} bytes`);
  } catch (err) {
    throw new Error(`Failed to fetch photo: ${err.message}`);
  }

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

  if (!response.ok) {
    throw new Error(`Gemini API error ${response.status}: ${responseText}`);
  }

  let data;
  try { data = JSON.parse(responseText); }
  catch { throw new Error(`Gemini response not valid JSON: ${responseText.substring(0, 200)}`); }

  if (!data.candidates?.length) throw new Error('Gemini returned no candidates');

  const candidate = data.candidates[0];
  if (candidate.finishReason === 'SAFETY') throw new Error('Content blocked by safety filter');

  const rawText = candidate?.content?.parts?.[0]?.text ?? '';
  if (!rawText) throw new Error(`Gemini returned empty text. Finish reason: ${candidate.finishReason}`);

  const cleaned = rawText.replace(/```json/gi, '').replace(/```/g, '').trim();

  let parsed;
  try {
    parsed = JSON.parse(cleaned);
  } catch {
    // JSON was truncated — try extracting score and reason via regex
    // so a long reason field doesn't silently fall back to 5.0
    const scoreMatch  = cleaned.match(/"score"\s*:\s*([0-9.]+)/);
    const reasonMatch = cleaned.match(/"reason"\s*:\s*"([^"]+)/);
    if (scoreMatch && reasonMatch) {
      parsed = { score: parseFloat(scoreMatch[1]), reason: reasonMatch[1] };
      logger.warn(`scorePhotoWithGemini: JSON truncated, recovered via regex — score=${parsed.score}`);
    } else {
      throw new Error(`Could not parse Gemini JSON: ${rawText.substring(0, 150)}`);
    }
  }

  if (typeof parsed.score === 'undefined' || typeof parsed.reason === 'undefined') {
    throw new Error(`Gemini response missing score or reason: ${JSON.stringify(parsed)}`);
  }

  const score  = Math.min(9.9, Math.max(1.0, parseFloat(parsed.score) || 5.0));
  const reason = typeof parsed.reason === 'string' && parsed.reason.length > 0
    ? parsed.reason
    : 'A solid effort.';

  logger.info(`scorePhotoWithGemini: scored ${score} — "${reason}"`);
  return { score, reason };
}


// ─────────────────────────────────────────────────────────────
// HELPER — score with exponential backoff retry
// ─────────────────────────────────────────────────────────────

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
        logger.warn(`scoreWithRetry: attempt ${attempt}/${GEMINI_MAX_ATTEMPTS} failed — retrying in ${delay}ms`);
        await new Promise(resolve => setTimeout(resolve, delay));
      }
    }
  }
  throw lastError;
}


// ─────────────────────────────────────────────────────────────
// HELPER — pre-score a submission in the background
//
// Fire-and-forget. Checks that the round is still waiting before
// writing — if judging has started the score will be computed
// live instead, so we skip the write to avoid a stale update.
// ─────────────────────────────────────────────────────────────

async function preScoreSubmission(submissionRef, roundRef, photoUrl, apiKey) {
  try {
    logger.info(`preScoreSubmission: scoring ${submissionRef.id}`);
    const { score, reason } = await scoreWithRetry(photoUrl, apiKey);

    // Only write if round is still waiting — otherwise startRound is
    // already running and we'd create a write conflict on the submission
    const roundDoc = await roundRef.get();
    if (!roundDoc.exists || roundDoc.data().status !== 'waiting') {
      logger.info(`preScoreSubmission: round no longer waiting, skipping write for ${submissionRef.id}`);
      return;
    }

    await submissionRef.update({ ai_score: score, ai_reason: reason });
    logger.info(`preScoreSubmission: wrote score ${score} for ${submissionRef.id}`);
  } catch (err) {
    logger.error(`preScoreSubmission: failed for ${submissionRef.id}: ${err.message}`);
  }
}


// ─────────────────────────────────────────────────────────────
// HELPER — update staking progress
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
      if (!userData?.bonus_credited)               return;
      if (userData?.welcome_bonus_unlocked === true) return;

      const totalLocked = userData?.total_locked_credits ?? 5.00;
      const stakedSoFar = userData?.total_round_staked   ?? 0;
      const newStaked   = parseFloat((stakedSoFar + entryFee).toFixed(2));
      const nowUnlocked = newStaked >= totalLocked;

      const update = { total_round_staked: admin.firestore.FieldValue.increment(entryFee) };
      if (nowUnlocked) {
        update.welcome_bonus_unlocked = true;
        logger.info(`updateStakingProgress: bonus unlocked for ${userId}`);
      }
      t.set(userRef, update, { merge: true });
    });
  }
}


// ─────────────────────────────────────────────────────────────
// createSession
// ─────────────────────────────────────────────────────────────

exports.createSession = onCall({
  cors: ['*'], maxInstances: 50, minInstances: 1
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId              = request.auth.uid;
  const { friendIds = [] }  = request.data;
  const db                  = getDb();
  const sessionRef          = db.collection('sessions').doc();
  const invitedIds          = [userId, ...friendIds.filter(id => id !== userId)];

  await sessionRef.set({
    status:                  'active',
    created_by:              userId,
    participant_ids:         [userId],
    invited_ids:             invitedIds,
    last_completed_round_id: null,
    round_seq:               0,
    created_at:              admin.firestore.FieldValue.serverTimestamp(),
    ended_at:                null
  });

  logger.info(`createSession: ${sessionRef.id} by ${userId}, invited ${invitedIds.length}`);
  return { success: true, session_id: sessionRef.id };
});


// ─────────────────────────────────────────────────────────────
// joinSession
// ─────────────────────────────────────────────────────────────

exports.joinSession = onCall({
  cors: ['*'], maxInstances: 50, minInstances: 1
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId      = request.auth.uid;
  const { sessionId } = request.data;
  if (!sessionId) throw new Error('sessionId is required');

  const db         = getDb();
  const sessionRef = db.collection('sessions').doc(sessionId);
  const sessionDoc = await sessionRef.get();

  if (!sessionDoc.exists)                      throw new Error('Session not found');
  if (sessionDoc.data().status === 'ended')    throw new Error('Session has ended');

  await sessionRef.update({
    participant_ids: admin.firestore.FieldValue.arrayUnion(userId)
  });

  logger.info(`joinSession: ${userId} joined ${sessionId}`);
  return { success: true };
});


// ─────────────────────────────────────────────────────────────
// endSession
// ─────────────────────────────────────────────────────────────

exports.endSession = onCall({
  cors: ['*'], maxInstances: 50, minInstances: 1
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const { sessionId } = request.data;
  if (!sessionId) throw new Error('sessionId is required');

  const db = getDb();
  await db.collection('sessions').doc(sessionId).update({
    status:   'ended',
    ended_at: admin.firestore.FieldValue.serverTimestamp()
  });

  logger.info(`endSession: ${sessionId} ended`);
  return { success: true };
});


// ─────────────────────────────────────────────────────────────
// inviteMore
// ─────────────────────────────────────────────────────────────

exports.inviteMore = onCall({
  cors: ['*'], maxInstances: 50, minInstances: 1
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const { sessionId, friendIds = [] } = request.data;
  if (!sessionId)          throw new Error('sessionId is required');
  if (!friendIds.length)   throw new Error('friendIds is required');

  const db         = getDb();
  const sessionRef = db.collection('sessions').doc(sessionId);
  const sessionDoc = await sessionRef.get();

  if (!sessionDoc.exists)                   throw new Error('Session not found');
  if (sessionDoc.data().status === 'ended') throw new Error('Session has ended');

  await sessionRef.update({
    invited_ids: admin.firestore.FieldValue.arrayUnion(...friendIds)
  });

  logger.info(`inviteMore: ${friendIds.length} added to ${sessionId}`);
  return { success: true };
});


// ─────────────────────────────────────────────────────────────
// createRound
//
// Idempotent — returns existing waiting/judging round if one
// exists. Uses server-side round_seq counter on the session doc
// to assign round numbers without scanning the collection.
// ─────────────────────────────────────────────────────────────

exports.createRound = onCall({
  cors: ['*'], maxInstances: 50, minInstances: 1
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId      = request.auth.uid;
  const { sessionId } = request.data;
  if (!sessionId) throw new Error('sessionId is required');

  const db         = getDb();
  const sessionRef = db.collection('sessions').doc(sessionId);

  await verifyParticipant(db, sessionId, userId);

  // Return any active round — never interrupt judging, never
  // create a second lobby on top of an existing one
  const activeSnap = await sessionRef.collection('rounds')
    .where('status', 'in', ['waiting', 'judging'])
    .limit(1)
    .get();

  if (!activeSnap.empty) {
    const existing = activeSnap.docs[0];
    logger.info(`createRound: returning existing ${existing.data().status} round ${existing.id}`);
    return { success: true, round_id: existing.id, created: false };
  }

  // Increment round_seq atomically on session doc
  let roundNumber;
  await db.runTransaction(async (t) => {
    const sessionDoc = await t.get(sessionRef);
    const currentSeq = sessionDoc.data()?.round_seq ?? 0;
    roundNumber      = currentSeq + 1;
    t.update(sessionRef, { round_seq: roundNumber });
  });

  const roundRef = sessionRef.collection('rounds').doc();
  await roundRef.set({
    status:            'waiting',
    round_number:      roundNumber,
    total_pot:         0,
    platform_fee:      0,
    round_reward:      0,
    winner_ids:        [],
    participant_count: 0,
    created_by:        userId,
    created_at:        admin.firestore.FieldValue.serverTimestamp(),
    started_at:        null,
    ended_at:          null
  });

  logger.info(`createRound: created round ${roundRef.id} (#${roundNumber}) in ${sessionId}`);
  return { success: true, round_id: roundRef.id, created: true };
});


// ─────────────────────────────────────────────────────────────
// joinRound
//
// Submits a photo and optional entry fee.
// Deducts fee atomically. Kicks off background pre-scoring.
// Returns the round's current state so the client is in sync.
// ─────────────────────────────────────────────────────────────

exports.joinRound = onCall({
  cors: ['*'], maxInstances: 50, minInstances: 1,
  secrets: ['GEMINI_API_KEY']
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId                          = request.auth.uid;
  const { sessionId, roundId, photoUrl, entryFee, isFromCamera } = request.data;

  if (!sessionId) throw new Error('sessionId is required');
  if (!roundId)   throw new Error('roundId is required');
  if (!photoUrl)  throw new Error('photoUrl is required');

  const fee = typeof entryFee === 'number' ? entryFee : 0;
  if (fee < 0)                          throw new Error('Entry fee cannot be negative');
  if (fee > 0 && fee < MIN_ENTRY_FEE)   throw new Error(`Minimum paid entry is $${MIN_ENTRY_FEE.toFixed(2)}`);
  if (fee > MAX_ENTRY_FEE)              throw new Error(`Maximum entry fee is $${MAX_ENTRY_FEE.toFixed(2)}`);

  const db       = getDb();
  await verifyParticipant(db, sessionId, userId);

  const roundRef = db.collection('sessions').doc(sessionId).collection('rounds').doc(roundId);

  await db.runTransaction(async (t) => {
    const roundDoc = await t.get(roundRef);
    if (!roundDoc.exists)                        throw new Error('Round not found');
    if (roundDoc.data().status !== 'waiting')    throw new Error('This round has already started');

    const submissionRef     = roundRef.collection('submissions').doc(userId);
    const existingSubmission = await t.get(submissionRef);
    if (existingSubmission.exists)               throw new Error('You have already joined this round');

    if (fee > 0) {
      const userRef        = db.collection('users').doc(userId);
      const userDoc        = await t.get(userRef);
      const currentBalance = userDoc.exists ? (userDoc.data().wallet_balance ?? 0) : 0;
      if (currentBalance < fee) {
        throw new Error(`Insufficient funds. Balance: $${currentBalance.toFixed(2)}, Required: $${fee.toFixed(2)}`);
      }
      const newBalance = parseFloat((currentBalance - fee).toFixed(2));
      t.set(userRef, { wallet_balance: admin.firestore.FieldValue.increment(-fee) }, { merge: true });
      const txRef = db.collection('wallet_transactions').doc();
      t.set(txRef, {
        user_id:        userId,
        type:           'debit',
        amount:         fee,
        reason:         'round_entry_fee',
        session_id:     sessionId,
        metadata:       { round_id: roundId },
        balance_before: currentBalance,
        balance_after:  newBalance,
        created_at:     admin.firestore.FieldValue.serverTimestamp()
      });
    }

    t.set(submissionRef, {
      user_id:        userId,
      photo_url:      photoUrl,
      entry_fee:      fee,
      is_from_camera: isFromCamera === true,
      ai_score:       null,
      ai_reason:      null,
      submitted_at:   admin.firestore.FieldValue.serverTimestamp()
    });

    t.update(roundRef, {
      total_pot:         admin.firestore.FieldValue.increment(fee),
      participant_count: admin.firestore.FieldValue.increment(1)
    });
  });

  logger.info(`joinRound: ${userId} joined round ${roundId} with fee $${fee}`);

  // Pre-score in background — fire and forget
  const apiKey = process.env.GEMINI_API_KEY;
  if (apiKey) {
    const submissionRef = roundRef.collection('submissions').doc(userId);
    preScoreSubmission(submissionRef, roundRef, photoUrl, apiKey);
  }

  return { success: true };
});


// ─────────────────────────────────────────────────────────────
// leaveRound
//
// Removes user from round and refunds their entry fee.
// If the last player leaves, the round is marked cancelled
// rather than deleted — avoids listener gaps and write conflicts
// when two players leave simultaneously.
// ─────────────────────────────────────────────────────────────

exports.leaveRound = onCall({
  cors: ['*'], maxInstances: 50, minInstances: 1
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId      = request.auth.uid;
  const { sessionId, roundId } = request.data;
  if (!sessionId) throw new Error('sessionId is required');
  if (!roundId)   throw new Error('roundId is required');

  const db       = getDb();
  const roundRef = db.collection('sessions').doc(sessionId).collection('rounds').doc(roundId);

  let entryFee       = 0;
  let remainingCount = 0;

  await db.runTransaction(async (t) => {
    const roundDoc = await t.get(roundRef);
    if (!roundDoc.exists)                     throw new Error('Round not found');
    if (roundDoc.data().status !== 'waiting') throw new Error('Cannot leave a round that has already started');

    const submissionRef = roundRef.collection('submissions').doc(userId);
    const submissionDoc = await t.get(submissionRef);
    if (!submissionDoc.exists)                throw new Error('You are not in this round');

    entryFee       = submissionDoc.data().entry_fee ?? 0;
    remainingCount = (roundDoc.data().participant_count ?? 1) - 1;

    if (entryFee > 0) {
      const userRef        = db.collection('users').doc(userId);
      const userDoc        = await t.get(userRef);
      const currentBalance = userDoc.exists ? (userDoc.data().wallet_balance ?? 0) : 0;
      const newBalance     = parseFloat((currentBalance + entryFee).toFixed(2));
      t.set(userRef, { wallet_balance: admin.firestore.FieldValue.increment(entryFee) }, { merge: true });
      const txRef = db.collection('wallet_transactions').doc();
      t.set(txRef, {
        user_id:        userId,
        type:           'credit',
        amount:         entryFee,
        reason:         'round_entry_refund',
        session_id:     sessionId,
        metadata:       { round_id: roundId },
        balance_before: currentBalance,
        balance_after:  newBalance,
        created_at:     admin.firestore.FieldValue.serverTimestamp()
      });
    }

    t.delete(submissionRef);

    if (remainingCount <= 0) {
      // Cancel the round rather than deleting it — avoids listener
      // gaps and concurrent-delete conflicts
      t.update(roundRef, {
        status:   'cancelled',
        ended_at: admin.firestore.FieldValue.serverTimestamp()
      });
    } else {
      t.update(roundRef, {
        total_pot:         admin.firestore.FieldValue.increment(-entryFee),
        participant_count: admin.firestore.FieldValue.increment(-1)
      });
    }
  });

  logger.info(`leaveRound: ${userId} left ${roundId}. Refunded $${entryFee}. Remaining: ${remainingCount}`);
  return { success: true, refund_amount: entryFee, round_cancelled: remainingCount <= 0 };
});


// ─────────────────────────────────────────────────────────────
// startRound
//
// Locks submissions, scores all photos, determines winner(s),
// pays out winnings, marks round complete, and atomically
// updates last_completed_round_id on the session document.
//
// The atomic session update is the key fix — clients watch
// last_completed_round_id rather than inferring completion
// from a listener disappearing, eliminating the race condition.
// ─────────────────────────────────────────────────────────────

exports.startRound = onCall({
  cors: ['*'], maxInstances: 50, minInstances: 1,
  secrets: ['GEMINI_API_KEY'],
  timeoutSeconds: 120
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId      = request.auth.uid;
  const { sessionId, roundId } = request.data;
  if (!sessionId) throw new Error('sessionId is required');
  if (!roundId)   throw new Error('roundId is required');

  const db       = getDb();
  await verifyParticipant(db, sessionId, userId);

  const sessionRef = db.collection('sessions').doc(sessionId);
  const roundRef   = sessionRef.collection('rounds').doc(roundId);

  // Atomically flip to judging — validates state and participant count
  await db.runTransaction(async (t) => {
    const roundDoc = await t.get(roundRef);
    if (!roundDoc.exists)                     throw new Error('Round not found');
    if (roundDoc.data().status !== 'waiting') throw new Error('Round has already started');

    const count = roundDoc.data().participant_count ?? 0;
    if (count < 2) throw new Error('Need at least 2 players to start');

    const submissionRef = roundRef.collection('submissions').doc(userId);
    const submissionDoc = await t.get(submissionRef);
    if (!submissionDoc.exists) throw new Error('You must submit a photo before starting the round');

    t.update(roundRef, {
      status:     'judging',
      started_at: admin.firestore.FieldValue.serverTimestamp()
    });
  });

  logger.info(`startRound: round ${roundId} flipped to judging`);

  try {
    const submissionsSnap = await roundRef.collection('submissions').get();
    const totalPot        = (await roundRef.get()).data().total_pot ?? 0;

    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) throw new Error('GEMINI_API_KEY secret not configured');

    // Score all submissions — use pre-scores where available
    const scoringPromises = submissionsSnap.docs.map(async (doc) => {
      const submissionUserId = doc.id;
      const photoUrl         = doc.data().photo_url;
      const existingScore    = doc.data().ai_score;
      const existingReason   = doc.data().ai_reason;

      // Pre-score is valid if it exists (no theme matching needed anymore)
      if (existingScore !== null && existingScore !== undefined) {
        logger.info(`startRound: using pre-score ${existingScore} for ${submissionUserId}`);
        return { userId: submissionUserId, score: existingScore, reason: existingReason, entryFee: doc.data().entry_fee ?? 0 };
      }

      logger.info(`startRound: no pre-score for ${submissionUserId}, scoring live`);
      try {
        const { score, reason } = await scoreWithRetry(photoUrl, apiKey);
        await doc.ref.update({ ai_score: score, ai_reason: reason });
        return { userId: submissionUserId, score, reason, entryFee: doc.data().entry_fee ?? 0 };
      } catch (err) {
        logger.error(`startRound: scoring failed for ${submissionUserId}: ${err.message}`);
        const fallbackScore  = 5.0;
        const fallbackReason = "Couldn't fully analyse this photo — neutral score given.";
        await doc.ref.update({ ai_score: fallbackScore, ai_reason: fallbackReason });
        return { userId: submissionUserId, score: fallbackScore, reason: fallbackReason, entryFee: doc.data().entry_fee ?? 0 };
      }
    });

    const results = await Promise.all(scoringPromises);

    const highScore       = Math.max(...results.map(r => r.score));
    const winners         = results.filter(r => r.score === highScore);
    const winnerIds       = winners.map(w => w.userId);
    const platformFee     = parseFloat((totalPot * PLATFORM_FEE_RATE).toFixed(2));
    const roundReward     = parseFloat((totalPot - platformFee).toFixed(2));
    const payoutPerWinner = winners.length > 0 && roundReward > 0
      ? parseFloat((roundReward / winners.length).toFixed(2))
      : 0;

    // Pay out winners
    for (const winner of winners) {
      if (payoutPerWinner <= 0) break;
      const winnerUserRef = db.collection('users').doc(winner.userId);
      await db.runTransaction(async (t) => {
        const winnerDoc      = await t.get(winnerUserRef);
        const currentBalance = winnerDoc.exists ? (winnerDoc.data().wallet_balance ?? 0) : 0;
        const newBalance     = parseFloat((currentBalance + payoutPerWinner).toFixed(2));
        t.set(winnerUserRef, { wallet_balance: admin.firestore.FieldValue.increment(payoutPerWinner) }, { merge: true });
        const txRef = db.collection('wallet_transactions').doc();
        t.set(txRef, {
          user_id:        winner.userId,
          type:           'credit',
          amount:         payoutPerWinner,
          reason:         'round_win',
          session_id:     sessionId,
          metadata:       { round_id: roundId, ai_score: winner.score, total_winners: winners.length },
          balance_before: currentBalance,
          balance_after:  newBalance,
          created_at:     admin.firestore.FieldValue.serverTimestamp()
        });
      });
    }

    // Log platform revenue
    if (platformFee > 0) {
      await db.collection('platform_revenue').doc().set({
        round_id:     roundId,
        session_id:   sessionId,
        fee_amount:   platformFee,
        total_pot:    totalPot,
        round_reward: roundReward,
        winner_ids:   winnerIds,
        num_players:  results.length,
        collected_at: admin.firestore.FieldValue.serverTimestamp()
      });
    }

    await updateStakingProgress(submissionsSnap.docs, db);

    // Mark round complete AND update session pointer atomically.
    // This is the single event clients watch for results — no
    // inference from listener disappearing needed.
    const batch = db.batch();
    batch.update(roundRef, {
      status:       'complete',
      winner_ids:   winnerIds,
      platform_fee: platformFee,
      round_reward: roundReward,
      ended_at:     admin.firestore.FieldValue.serverTimestamp()
    });
    batch.update(sessionRef, {
      last_completed_round_id: roundId
    });
    await batch.commit();

    logger.info(`startRound: round ${roundId} complete. Winners: ${winnerIds.join(', ')}. Pot: $${totalPot}`);

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
    await roundRef.update({ status: 'failed', ended_at: admin.firestore.FieldValue.serverTimestamp() });
    throw error;
  }
});
