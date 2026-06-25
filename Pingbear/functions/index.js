const { onRequest } = require("firebase-functions/v2/https");
const admin         = require("firebase-admin");
const { google }    = require('googleapis');
const logger        = require("firebase-functions/logger");

const wallet = require('./walletFunctions');
const stream = require('./streamFunctions');

admin.initializeApp();

const auth             = new google.auth.GoogleAuth({
  scopes: ['https://www.googleapis.com/auth/firebase.messaging']
});
const authClientPromise = auth.getClient();

// ─────────────────────────────────────────────────────────────
// getAccessToken
// ─────────────────────────────────────────────────────────────

exports.getAccessToken = onRequest({
  cors: ["*"],
  maxInstances: 20,
  minInstances: 0,
}, async (request, response) => {
  try {
    if (request.method === 'OPTIONS') {
      response.set('Access-Control-Allow-Methods', 'GET');
      response.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
      response.status(204).send('');
      return;
    }
    const projectId  = process.env.GCLOUD_PROJECT || admin.app().options.projectId;
    if (!projectId) throw new Error("Could not determine project ID");
    const authClient = await authClientPromise;
    const { token }  = await authClient.getAccessToken();
    if (!token) throw new Error("Failed to get access token");
    response.json({ accessToken: token, expiresIn: 3600 });
  } catch (error) {
    logger.error("getAccessToken error:", error);
    response.status(500).json({ error: "Failed to generate token" });
  }
});

// ─────────────────────────────────────────────────────────────
// Stripe — top up
// ─────────────────────────────────────────────────────────────

exports.createTopUpIntent  = wallet.createTopUpIntent;
exports.confirmTopUpIntent = wallet.confirmTopUpIntent;

exports.stripeWebhook = onRequest({
  cors: false,
  maxInstances: 20,
  secrets: ["STRIPE_SECRET_KEY", "STRIPE_WEBHOOK_SECRET"],
}, async (req, res) => {
  const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
  const sig    = req.headers['stripe-signature'];

  let event;
  try {
    event = stripe.webhooks.constructEvent(req.rawBody, sig, process.env.STRIPE_WEBHOOK_SECRET);
  } catch (err) {
    logger.error('Stripe webhook signature failed:', err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  if (event.type === 'payment_intent.succeeded') {
    const intent = event.data.object;
    if (intent.metadata?.top_up === 'true') {
      await handleSuccessfulTopUp(intent);
    }
  }

  res.json({ received: true });
});

async function handleSuccessfulTopUp(intent) {
  const userId   = intent.metadata.user_id;
  const amount   = parseFloat((intent.amount / 100).toFixed(2));
  const intentId = intent.id;

  if (!userId) { logger.error('handleSuccessfulTopUp: no user_id in metadata'); return; }

  const db       = admin.firestore();
  const orderRef = db.collection('payment_orders').doc(intentId);

  try {
    await db.runTransaction(async (t) => {
      const existing = await t.get(orderRef);
      if (existing.exists) { logger.info(`handleSuccessfulTopUp: ${intentId} already processed`); return; }

      const userRef    = db.collection('users').doc(userId);
      const userDoc    = await t.get(userRef);
      const current    = userDoc.exists ? (userDoc.data().wallet_balance ?? 0) : 0;
      const newBalance = parseFloat((current + amount).toFixed(2));

      t.set(userRef, { wallet_balance: admin.firestore.FieldValue.increment(amount) }, { merge: true });
      t.set(orderRef, {
        user_id: userId, amount, currency: 'USD', provider: 'stripe',
        status: 'credited', processed_at: admin.firestore.FieldValue.serverTimestamp()
      });

      const txRef = db.collection('wallet_transactions').doc();
      t.set(txRef, {
        user_id:        userId,
        type:           'credit',
        amount,
        reason:         'top_up',
        session_id:     null,
        metadata:       { payment_intent_id: intentId, provider: 'stripe' },
        balance_before: current,
        balance_after:  newBalance,
        created_at:     admin.firestore.FieldValue.serverTimestamp()
      });
    });
    logger.info(`handleSuccessfulTopUp: $${amount} credited to ${userId}`);
  } catch (error) {
    logger.error('handleSuccessfulTopUp error:', error);
  }
}

// ─────────────────────────────────────────────────────────────
// Wallet
// ─────────────────────────────────────────────────────────────

exports.deductBalance      = wallet.deductBalance;
exports.creditBalance      = wallet.creditBalance;
exports.adminCreditBalance = wallet.adminCreditBalance;
exports.requestWithdrawal  = wallet.requestWithdrawal;
exports.approveWithdrawal  = wallet.approveWithdrawal;
exports.rejectWithdrawal   = wallet.rejectWithdrawal;
exports.grantWelcomeBonus  = wallet.grantWelcomeBonus;

// ─────────────────────────────────────────────────────────────
// Streams
// ─────────────────────────────────────────────────────────────

exports.createStream           = stream.createStream;
exports.endStream              = stream.endStream;
exports.joinStream             = stream.joinStream;
exports.sendStreamRequest      = stream.sendStreamRequest;
exports.respondToStreamRequest = stream.respondToStreamRequest;
exports.completeStreamRequest  = stream.completeStreamRequest;
exports.resolveInviteStream    = stream.resolveInviteStream;
