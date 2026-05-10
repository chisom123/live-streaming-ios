/**
 * challengeFunctions.js
 *
 * Add to index.js:
 *   const challenge = require('./challengeFunctions');
 *   exports.assignChallenge = challenge.assignChallenge;
 *
 * ─────────────────────────────────────────────────────────────
 * CHALLENGE LIFECYCLE
 * ─────────────────────────────────────────────────────────────
 *
 * 1. Called from BonusViewPage after user authenticates
 * 2. Reads user doc to get totalWinnings and challengeTier
 * 3. Reads active challenge_templates ordered by priority
 * 4. Evaluates conditions against user fields
 * 5. Writes matching template to user_challenges/{userId}
 * 6. Returns challenge to web
 *
 * Idempotent — if user already has a pending or accepted
 * challenge, returns it without creating a new one.
 *
 * Challenges never expire — they persist until completed
 * or the template is retired (isActive: false).
 *
 * ─────────────────────────────────────────────────────────────
 * DATA MODEL
 * ─────────────────────────────────────────────────────────────
 *
 * challenge_templates/{templateId}
 *   title: string
 *   description: string
 *   completionTrigger: string
 *   targetValue: number
 *   priority: number
 *   isActive: boolean
 *   conditions: {
 *     [fieldName]: { operator: "lt"|"gt"|"eq"|"gte"|"lte", value: number }
 *   }
 *
 * user_challenges/{userId}
 *   userId: string
 *   templateId: string
 *   title: string
 *   description: string
 *   completionTrigger: string
 *   targetValue: number
 *   currentValue: number
 *   status: "pending" | "accepted" | "completed"
 *   acceptedAt: timestamp | null
 *   completedAt: timestamp | null
 *   createdAt: timestamp
 */

const { onCall } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const logger = require('firebase-functions/logger');

let _db;
const getDb = () => {
  if (!_db) _db = admin.firestore();
  return _db;
};

// ─────────────────────────────────────────────────────────────
// HELPER — evaluate a single template's conditions
// against the user's tracking fields
// ─────────────────────────────────────────────────────────────

function evaluateConditions(conditions, userData) {
  for (const [field, condition] of Object.entries(conditions)) {
    const userValue = userData[field] ?? 0;
    const { operator, value } = condition;

    switch (operator) {
      case 'lt':  if (!(userValue <  value)) return false; break;
      case 'gt':  if (!(userValue >  value)) return false; break;
      case 'eq':  if (!(userValue == value)) return false; break;
      case 'gte': if (!(userValue >= value)) return false; break;
      case 'lte': if (!(userValue <= value)) return false; break;
      default:
        logger.warn(`assignChallenge: unknown operator "${operator}" on field "${field}"`);
        return false;
    }
  }
  return true;
}

// ─────────────────────────────────────────────────────────────
// assignChallenge
// ─────────────────────────────────────────────────────────────

exports.assignChallenge = onCall({
  cors: ['*'],
  maxInstances: 50,
  minInstances: 1
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const userId = request.auth.uid;
  const db = getDb();

  // ── Step 1: Check for existing pending/accepted challenge ─────────────────
  const existingDoc = await db.collection('user_challenges').doc(userId).get();

  if (existingDoc.exists) {
    const existing = existingDoc.data();
    const isLive = existing.status === 'pending' || existing.status === 'accepted';

    if (isLive) {
      logger.info(`assignChallenge: returning existing challenge for ${userId} — status: ${existing.status}`);
      return {
        success: true,
        challenge: {
          ...existing,
          acceptedAt:  existing.acceptedAt?.toDate?.()?.toISOString() ?? null,
          completedAt: existing.completedAt?.toDate?.()?.toISOString() ?? null,
          createdAt:   existing.createdAt?.toDate?.()?.toISOString() ?? null
        }
      };
    }
  }

  // ── Step 2: Read user doc ─────────────────────────────────────────────────
  const userDoc = await db.collection('users').doc(userId).get();
  const userData = userDoc.data() ?? {};

  logger.info(`assignChallenge: evaluating templates for ${userId}`, {
    totalWinnings:  userData.totalWinnings  ?? 0,
    challengeTier:  userData.challengeTier  ?? 0
  });

  // ── Step 3: Read active templates ordered by priority ─────────────────────
  const templatesSnap = await db.collection('challenge_templates')
    .where('isActive', '==', true)
    .orderBy('priority', 'asc')
    .get();

  if (templatesSnap.empty) {
    logger.warn(`assignChallenge: no active templates found`);
    return { success: false, reason: 'no_templates' };
  }

  // ── Step 4: Find first matching template ──────────────────────────────────
  let matchedTemplate = null;
  let matchedTemplateId = null;

  for (const doc of templatesSnap.docs) {
    const template = doc.data();
    const conditions = template.conditions ?? {};

    if (evaluateConditions(conditions, userData)) {
      matchedTemplate = template;
      matchedTemplateId = doc.id;
      break;
    }
  }

  if (!matchedTemplate) {
    logger.info(`assignChallenge: no matching template for ${userId}`);
    return { success: false, reason: 'no_match' };
  }

  // ── Step 5: Write user_challenges document ────────────────────────────────
  const now = new Date();

  const challenge = {
    userId,
    templateId:        matchedTemplateId,
    title:             matchedTemplate.title,
    description:       matchedTemplate.description,
    completionTrigger: matchedTemplate.completionTrigger,
    targetValue:       matchedTemplate.targetValue,
    currentValue:      userData.totalWinnings ?? 0,  // start from current winnings
    status:            'pending',
    acceptedAt:        null,
    completedAt:       null,
    createdAt:         admin.firestore.FieldValue.serverTimestamp()
  };

  await db.collection('user_challenges').doc(userId).set(challenge);

  logger.info(`assignChallenge: assigned "${matchedTemplate.title}" to ${userId}`);

  return {
    success: true,
    challenge: {
      ...challenge,
      acceptedAt:  null,
      completedAt: null,
      createdAt:   now.toISOString()
    }
  };
});
