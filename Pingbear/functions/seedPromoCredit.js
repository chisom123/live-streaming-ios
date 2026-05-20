/**
 * seedPromoCredit.js
 *
 * Injects locked promo credits into a user's wallet.
 * The amount is added to wallet_balance AND total_locked_credits,
 * so the user must stake it in rounds before they can withdraw it.
 *
 * Threshold fix:
 *   total_locked_credits is incremented by amount so that existing
 *   locked credits (welcome bonus, previous promos) are preserved
 *   and the new requirement stacks on top correctly.
 *
 * Example:
 *   User has total_locked_credits = $5 (welcome bonus).
 *   You inject $10 promo.
 *   total_locked_credits = $5 + $10 = $15
 *   requestWithdrawal computes outstanding = $15 - total_round_staked.
 *
 * Usage:
 *   node seedPromoCredit.js
 *   > Enter user ID: abc123
 *   > Enter amount (USD): 10
 */

const admin    = require('firebase-admin');
const readline = require('readline');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

const db = admin.firestore();

const REASON = 'Seed Money';

// ─────────────────────────────────────────────────────────────
// prompt helper
// ─────────────────────────────────────────────────────────────

function prompt(question) {
  const rl = readline.createInterface({
    input:  process.stdin,
    output: process.stdout
  });
  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      rl.close();
      resolve(answer.trim());
    });
  });
}

// ─────────────────────────────────────────────────────────────
// seedPromoCredit
// ─────────────────────────────────────────────────────────────

async function seedPromoCredit(userId, amount) {
  console.log('');
  console.log(`User   : ${userId}`);
  console.log(`Amount : $${amount.toFixed(2)}`);
  console.log(`Reason : ${REASON}`);
  console.log('');

  const userRef = db.collection('users').doc(userId);
  const userDoc = await userRef.get();

  if (!userDoc.exists) {
    throw new Error(`User "${userId}" not found in Firestore`);
  }

  const userData         = userDoc.data();
  const currentBalance   = userData.wallet_balance       ?? 0;
  const currentLocked    = userData.total_locked_credits ?? 0;
  const newBalance       = parseFloat((currentBalance + amount).toFixed(2));
  const newLockedCredits = parseFloat((currentLocked + amount).toFixed(2));
  const stakingRemaining = amount; // always exactly the injected amount

  console.log(`  Current balance       : $${currentBalance.toFixed(2)}`);
  console.log(`  Current locked credits: $${currentLocked.toFixed(2)}`);
  console.log(`  New balance           : $${newBalance.toFixed(2)}`);
  console.log(`  New locked credits    : $${newLockedCredits.toFixed(2)}`);
  console.log(`  Must stake to unlock  : $${stakingRemaining.toFixed(2)}`);
  console.log('');

  await db.runTransaction(async (t) => {
    const freshDoc   = await t.get(userRef);
    const freshData  = freshDoc.data();
    const freshBalance = freshData?.wallet_balance       ?? 0;
    const freshLocked  = freshData?.total_locked_credits ?? 0;
    const freshNew     = parseFloat((freshBalance + amount).toFixed(2));

    // Increment existing locked credits by the new amount
    const freshNewLocked = parseFloat((freshLocked + amount).toFixed(2));

    t.set(userRef, {
      wallet_balance:         admin.firestore.FieldValue.increment(amount),
      total_locked_credits:   freshNewLocked,
      welcome_bonus_unlocked: false
    }, { merge: true });

    // Wallet transaction audit record
    const txRef = db.collection('wallet_transactions').doc();
    t.set(txRef, {
      user_id:        userId,
      type:           'credit',
      amount,
      reason:         'promo_credit',
      competition_id: null,
      metadata:       { note: REASON },
      balance_before: freshBalance,
      balance_after:  freshNew,
      created_at:     admin.firestore.FieldValue.serverTimestamp()
    });
  });

  console.log(`  ✅ $${amount.toFixed(2)} promo credit added to ${userId}`);
  console.log(`  ✅ total_locked_credits set to $${newLockedCredits.toFixed(2)}`);
  console.log(`  ✅ welcome_bonus_unlocked set to false`);
  console.log(`  ✅ Wallet transaction audit record written`);
  console.log('');
  console.log(`Done. User must stake $${stakingRemaining.toFixed(2)} more in rounds to unlock withdrawal.`);
  console.log('');
}

// ─────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────

async function main() {
  console.log('');
  console.log('── Seed Promo Credit ─────────────────────────────────');
  console.log('');
  console.log('Adds locked credits to a user wallet.');
  console.log('User must stake this amount in rounds before withdrawing.');
  console.log('');

  const userId = await prompt('Enter user ID: ');
  if (!userId) {
    console.error('❌ User ID is required');
    process.exit(1);
  }

  const amountRaw = await prompt('Enter amount (USD): ');
  const amount    = parseFloat(amountRaw);
  if (isNaN(amount) || amount <= 0) {
    console.error('❌ Amount must be a positive number');
    process.exit(1);
  }

  console.log('');
  console.log('──────────────────────────────────────────────────────');

  await seedPromoCredit(userId, amount);
}

main().catch((err) => {
  console.error('❌ Error:', err.message || err);
  process.exit(1);
});
