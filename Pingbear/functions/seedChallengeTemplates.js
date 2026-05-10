const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccount.json");

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

const db = admin.firestore();

// ─────────────────────────────────────────────────────────────
// Challenge Templates — Winning Money Tier System
//
// Challenges never expire — they persist until the user
// completes them or the template is retired (isActive: false).
//
// Tracking field: totalWinnings on the user document
// Tier tracking:  challengeTier on the user document
//
// Tier 1 uses totalWinnings lt 2 — works for new users with
// no totalWinnings field since it defaults to 0.
// Tiers 2+ use challengeTier eq N — clean single condition.
//
// To add a new tier: add to templates array and re-run.
// To retire a tier: set isActive: false in Firestore console.
// ─────────────────────────────────────────────────────────────

const templates = [
  {
    id: "win_2",
    data: {
      title: "Win $2 in a competition",
      description: "Post a photo, get rated, and win your first $2 across competitions",
      completionTrigger: "race_win",
      targetValue: 2,
      priority: 1,
      isActive: true,
      conditions: {
        totalWinnings: { operator: "lt", value: 2 }
      }
    }
  },
  {
    id: "win_5",
    data: {
      title: "Win $5 in competitions",
      description: "Keep competing and grow your total winnings to $5",
      completionTrigger: "race_win",
      targetValue: 5,
      priority: 2,
      isActive: true,
      conditions: {
        challengeTier: { operator: "eq", value: 1 }
      }
    }
  },
  {
    id: "win_10",
    data: {
      title: "Win $10 in competitions",
      description: "You're finding your rhythm — push your total winnings to $10",
      completionTrigger: "race_win",
      targetValue: 10,
      priority: 3,
      isActive: true,
      conditions: {
        challengeTier: { operator: "eq", value: 2 }
      }
    }
  },
  {
    id: "win_20",
    data: {
      title: "Win $20 in competitions",
      description: "A serious competitor — reach $20 in total competition winnings",
      completionTrigger: "race_win",
      targetValue: 20,
      priority: 4,
      isActive: true,
      conditions: {
        challengeTier: { operator: "eq", value: 3 }
      }
    }
  },
  {
    id: "win_50",
    data: {
      title: "Win $50 in competitions",
      description: "Elite level — accumulate $50 in total competition winnings",
      completionTrigger: "race_win",
      targetValue: 50,
      priority: 5,
      isActive: true,
      conditions: {
        challengeTier: { operator: "eq", value: 4 }
      }
    }
  },
  {
    id: "win_75",
    data: {
      title: "Win $75 in competitions",
      description: "Top tier — reach $75 in total competition winnings",
      completionTrigger: "race_win",
      targetValue: 75,
      priority: 6,
      isActive: true,
      conditions: {
        challengeTier: { operator: "eq", value: 5 }
      }
    }
  }
];

async function seed() {
  console.log(`Seeding ${templates.length} challenge templates...`);
  console.log('');

  for (const template of templates) {
    await db.collection("challenge_templates").doc(template.id).set(template.data);
    console.log(`✅ ${template.id} — "${template.data.title}"`);
  }

  console.log('');
  console.log(`✅ Done. ${templates.length} templates seeded.`);
  console.log('');
  console.log('Notes:');
  console.log('  • Challenges have no expiry — persist until completed or retired');
  console.log('  • totalWinnings incremented in closeRaces when crediting winners');
  console.log('  • challengeTier incremented in closeRaces when challenge completes');
  console.log('  • To add more tiers, add to templates array and re-run');
  console.log('  • To retire a tier, set isActive: false in Firestore console');
}

seed().catch(console.error);
