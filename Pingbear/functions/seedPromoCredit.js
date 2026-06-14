/**
 * seedPromoCredit.js
 *
 * Injects credits into a specific user's wallet.
 * No locking, no staking requirements — fully spendable and withdrawable immediately.
 * Use this to seed specific users with balance for testing or promotions.
 *
 * Usage:
 *   node seedPromoCredit.js
 *   > Enter user ID: abc123
 *   > Enter amount (USD): 10
 *   > Enter note (optional): Early access gift
 */

const admin        = require('firebase-admin');
const readline     = require('readline');
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
  console.log(`Amount : $${amount.toFixed(2)}`);
  console.log(`Note   : ${note || 'none'}`);
  console.log('');

  const userRef = db.collection('users').doc(userId);
  const userDoc = await userRef.get();

  if (!userDoc.exists) {
    throw new Error(`User "${userId}" not found in Firestore`);
  }

  const currentBalance = userDoc.data().wallet_balance ?? 0;
  const newBalance     = parseFloat((currentBalance + amount).toFixed(2));

  console.log(`  Current balance : $${currentBalance.toFixed(2)}`);
  console.log(`  New balance     : $${newBalance.toFixed(2)}`);
  console.log('');

  await db.runTransaction(async (t) => {
    const freshDoc     = await t.get(userRef);
    const freshBalance = freshDoc.data()?.wallet_balance ?? 0;
    const freshNew     = parseFloat((freshBalance + amount).toFixed(2));

    // Credit wallet — no locks, no staking, fully usable immediately
    t.set(userRef, {
      wallet_balance: admin.firestore.FieldValue.increment(amount)
    }, { merge: true });

    // Audit record
    const txRef = db.collection('wallet_transactions').doc();
    t.set(txRef, {
      user_id:        userId,
      type:           'credit',
      amount,
      reason:         'promo_credit',
      session_id:     null,
      metadata:       { note: note || 'Manual promo credit' },
      balance_before: freshBalance,
      balance_after:  freshNew,
      created_at:     admin.firestore.FieldValue.serverTimestamp()
    });
  });

  console.log(`  ✅ $${amount.toFixed(2)} credited to ${userId}`);
  console.log(`  ✅ Wallet transaction audit record written`);
  console.log(`  ✅ Fully spendable and withdrawable immediately`);
  console.log('');
}

// ─────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────

async function main() {
  console.log('');
  console.log('── Seed Promo Credit ──────────────────────────────────');
  console.log('');
  console.log('Adds balance to a specific user wallet.');
  console.log('No lock or staking requirement — fully usable immediately.');
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
