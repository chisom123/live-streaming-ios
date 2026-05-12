const admin = require("firebase-admin");
const readline = require("readline");
const serviceAccount = require("./serviceAccount.json");

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

const db = admin.firestore();

// ─────────────────────────────────────────────────────────────
// Admin account used as the contributor on all seeded pots.
// Shows up as a regular user contribution in the records.
// ─────────────────────────────────────────────────────────────

const ADMIN_USER_ID = "zxBo4ecEp1hzXhpVIfQ1vFpclkz1";

const RACE_DURATIONS = {
  weekly: 7 * 24 * 60 * 60 * 1000,
  daily:  1 * 24 * 60 * 60 * 1000
};

const DEFAULT_DURATION = "weekly";

// ─────────────────────────────────────────────────────────────
// prompt — helper to ask a question in the terminal
// ─────────────────────────────────────────────────────────────

function prompt(question) {
  const rl = readline.createInterface({
    input: process.stdin,
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
// getOrCreateRace — mirrors raceFunctions.js logic exactly.
// Checks for an active non-expired race first.
// If none found, reads race_duration from competition doc
// and creates a new race with the same fields as the app.
// ─────────────────────────────────────────────────────────────

async function getOrCreateRace(competitionId) {
  // Check for existing active race
  const activeRaceSnap = await db.collection("competition_races")
    .where("competition_id", "==", competitionId)
    .where("status", "==", "active")
    .limit(1)
    .get();

  if (!activeRaceSnap.empty) {
    const doc = activeRaceSnap.docs[0];
    const data = doc.data();

    // Verify not expired
    if (data.end_date.toMillis() > Date.now()) {
      console.log(`  ✅ Active race found: ${doc.id}`);
      return { raceId: doc.id, created: false };
    }
  }

  // No active race — read duration from competition and create one
  const competitionDoc = await db.collection("competitions").doc(competitionId).get();

  if (!competitionDoc.exists) {
    throw new Error(`Competition "${competitionId}" not found in Firestore`);
  }

  const duration = competitionDoc.data()?.race_duration || DEFAULT_DURATION;
  const durationMs = RACE_DURATIONS[duration] || RACE_DURATIONS[DEFAULT_DURATION];

  const now = new Date();
  const endDate = new Date(now.getTime() + durationMs);

  const raceRef = db.collection("competition_races").doc();

  await raceRef.set({
    competition_id:    competitionId,
    status:            "active",
    duration:          duration,
    start_date:        admin.firestore.Timestamp.fromDate(now),
    end_date:          admin.firestore.Timestamp.fromDate(endDate),
    total_pot:         0,
    total_stars:       0,
    participant_count: 0,
    payout_complete:   false,
    created_at:        admin.firestore.FieldValue.serverTimestamp()
  });

  console.log(`  ✅ No active race found — created new ${duration} race: ${raceRef.id}`);
  return { raceId: raceRef.id, created: true };
}

// ─────────────────────────────────────────────────────────────
// seedRacePot — main function
//
// 1. Resolves or creates the active race for the competition
// 2. Increments total_pot on the race doc
// 3. Writes a contribution record (group-visible)
// 4. Writes a wallet_transactions audit record (admin-side)
// ─────────────────────────────────────────────────────────────

async function seedRacePot(competitionId, amount) {
  console.log("");
  console.log(`Competition : ${competitionId}`);
  console.log(`Amount      : $${amount.toFixed(2)}`);
  console.log(`Admin user  : ${ADMIN_USER_ID}`);
  console.log("");

  // Step 1 — resolve or create race
  const { raceId } = await getOrCreateRace(competitionId);
  const raceRef = db.collection("competition_races").doc(raceId);

  // Step 2 — increment total_pot on the race
  await raceRef.update({
    total_pot: admin.firestore.FieldValue.increment(amount)
  });

  console.log(`  ✅ Race pot incremented by $${amount.toFixed(2)}`);

  // Step 3 — contribution record (subcollection — group-visible)
  const contributionRef = raceRef.collection("contributions").doc();
  await contributionRef.set({
    user_id:        ADMIN_USER_ID,
    amount:         amount,
    contributed_at: admin.firestore.FieldValue.serverTimestamp()
  });

  console.log(`  ✅ Contribution record written: ${contributionRef.id}`);

  // Step 4 — wallet_transactions audit trail (admin-side / private)
  const txRef = db.collection("wallet_transactions").doc();
  await txRef.set({
    user_id:        ADMIN_USER_ID,
    type:           "debit",
    amount:         amount,
    reason:         "race_contribution",
    competition_id: competitionId,
    metadata:       { race_id: raceId },
    created_at:     admin.firestore.FieldValue.serverTimestamp()
  });

  console.log(`  ✅ Wallet transaction audit record written: ${txRef.id}`);
  console.log("");
  console.log(`✅ Done. $${amount.toFixed(2)} seeded into race ${raceId} for competition ${competitionId}`);
  console.log("");
}

// ─────────────────────────────────────────────────────────────
// Entry point — prompts for competitionId and amount
// then runs seedRacePot
// ─────────────────────────────────────────────────────────────

async function main() {
  console.log("");
  console.log("── Seed Race Pot ─────────────────────────────────────");
  console.log("");

  const competitionId = await prompt("Enter competition ID: ");

  if (!competitionId) {
    console.error("❌ Competition ID is required");
    process.exit(1);
  }

  const amountRaw = await prompt("Enter amount (USD): ");
  const amount = parseFloat(amountRaw);

  if (isNaN(amount) || amount <= 0) {
    console.error("❌ Amount must be a positive number");
    process.exit(1);
  }

  console.log("");
  console.log("──────────────────────────────────────────────────────");

  await seedRacePot(competitionId, amount);
}

main().catch((err) => {
  console.error("❌ Error:", err.message || err);
  process.exit(1);
});
