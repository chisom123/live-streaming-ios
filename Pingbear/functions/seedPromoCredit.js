/**
 * seedPromoCredit.js
 *
 * Injects BONUS credits into a specific user's wallet.
 * Bonus credits are spendable (requests, offer unlocks) but NOT
 * withdrawable until the user earns real money back through it
 * (e.g. as a creator payout).
 *
 * Usage:
 *   node seedPromoCredit.js
 *   > Enter user ID: abc123
 *   > Enter amount (USD): 10
 *   > Enter note (optional): Early access gift
 */

const admin         = require('firebase-admin');
const readline       = require('readline');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

const db = admin.firestore();

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

async function seedPromoCredit(userId, amount, note) {
  console.log('');
  console.log(`User   : ${userId}`);
  console.log(`Amount : $${amount.toFixed(2)} (bonus — spendable, not withdrawable)`);
  console.log(`Note   : ${note || 'none'}`);
  console.log('');

  const userRef = db.collection('users').doc(userId);
  const userDoc = await userRef.get();

  if (!userDoc.exists) {
    throw new Error(`User "${userId}" not found in Firestore`);
  }

  const currentBalance = userDoc.data().wallet_balance ?? 0;
  const currentBonus   = userDoc.data().bonus_balance ?? 0;

  console.log(`  Current balance : $${currentBalance.toFixed(2)} (bonus: $${currentBonus.toFixed(2)})`);
  console.log(`  New balance     : $${(currentBalance + amount).toFixed(2)} (bonus: $${(currentBonus + amount).toFixed(2)})`);
  console.log('');

  await db.runTransaction(async (t) => {
    const freshDoc     = await t.get(userRef);
    const freshBalance = freshDoc.data()?.wallet_balance ?? 0;
    const freshNewBal  = parseFloat((freshBalance + amount).toFixed(2));

    // Credit both pools — wallet_balance makes it spendable,
    // bonus_balance tags that same amount as non-withdrawable.
    t.set(userRef, {
      wallet_balance: admin.firestore.FieldValue.increment(amount),
      bonus_balance:  admin.firestore.FieldValue.increment(amount)
    }, { merge: true });

    const txRef = db.collection('wallet_transactions').doc();
    t.set(txRef, {
      user_id:        userId,
      type:           'credit',
      amount,
      reason:         'promo_credit',
      session_id:     null,
      metadata:       { note: note || 'Manual promo credit' },
      balance_before: freshBalance,
      balance_after:  freshNewBal,
      created_at:     admin.firestore.FieldValue.serverTimestamp()
    });
  });

  console.log(`  ✅ $${amount.toFixed(2)} credited to ${userId}'s bonus balance`);
  console.log(`  ✅ Wallet transaction audit record written`);
  console.log(`  ✅ Spendable on requests/offers — not withdrawable`);
  console.log('');
}

// ─────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────

async function main() {
  console.log('');
  console.log('── Seed Promo Credit (Bonus) ──────────────────────────');
  console.log('');
  console.log('Adds BONUS balance to a specific user wallet.');
  console.log('Spendable immediately, but not withdrawable.');
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

  const note = await prompt('Enter note (optional): ');

  console.log('');
  console.log('──────────────────────────────────────────────────────');

  await seedPromoCredit(userId, amount, note);
}

main().catch((err) => {
  console.error('❌ Error:', err.message || err);
  process.exit(1);
});
