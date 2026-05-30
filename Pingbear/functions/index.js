const { onRequest, onCall } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const { google } = require('googleapis');
const logger = require("firebase-functions/logger");
const wallet = require('./walletFunctions');
const round = require('./roundFunctions');
const livekit = require('./liveKitFunctions');
const callkit = require('./callKitFunctions');
const webBattle = require('./saveUserProfile');

const cors = require('cors')({ origin: true });

admin.initializeApp();

const auth = new google.auth.GoogleAuth({
  scopes: ['https://www.googleapis.com/auth/firebase.messaging']
});

const authClientPromise = auth.getClient();

const COIN_PACKAGES = {
  '100': 99,
  '600': 499,
  '1500': 999
};

exports.getAccessToken = onRequest({
  cors: ["*"],
  maxInstances: 20,
  minInstances: 1,
}, async (request, response) => {
  try {
    if (request.method === 'OPTIONS') {
      response.set('Access-Control-Allow-Methods', 'GET');
      response.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
      response.status(204).send('');
      return;
    }

    const projectId = process.env.GCLOUD_PROJECT || admin.app().options.projectId;
    if (!projectId) throw new Error("Could not determine project ID");

    logger.info(`Using project ID: ${projectId}`);

    const authClient = await authClientPromise;
    const { token } = await authClient.getAccessToken();

    if (!token) throw new Error("Failed to get access token");

    logger.info("Access token obtained successfully");

    response.json({ accessToken: token, expiresIn: 3600 });
  } catch (error) {
    logger.error("Error obtaining access token:", error);
    response.status(500).json({
      error: "Failed to generate token",
      message: process.env.NODE_ENV === 'development' ? error.message : "Server error"
    });
  }
});

exports.createPurchaseToken = onCall({
  cors: ["*"],
  maxInstances: 20,
  minInstances: 1
}, async (request) => {
  try {
    if (!request.auth) throw new Error('User must be authenticated');

    const { competitionId, coinAmount } = request.data;

    logger.info('Request data:', { competitionId, coinAmount, userId: request.auth.uid });

    if (!competitionId) throw new Error('Competition ID is required');

    const allowedAmounts = Object.keys(COIN_PACKAGES).map(Number);
    if (!allowedAmounts.includes(coinAmount)) {
      throw new Error(`Coin amount must be one of: ${allowedAmounts.join(', ')}`);
    }

    const db = admin.firestore();
    const sessionRef = db.collection('purchaseSessions').doc();
    await sessionRef.set({
      userId: request.auth.uid,
      competitionId: competitionId,
      coinAmount: coinAmount,
      priceInCents: COIN_PACKAGES[coinAmount.toString()],
      createdAt: admin.firestore.Timestamp.now(),
      expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + (30 * 60 * 1000)),
      sessionId: sessionRef.id
    });

    const crypto = require('crypto');
    const tokenData = `${request.auth.uid}:${sessionRef.id}:${Date.now()}`;
    const token = crypto.createHash('sha256').update(tokenData + 'your-secret-key').digest('hex');

    logger.info('Session and token created successfully');
    return { token: `${sessionRef.id}.${token}`, sessionId: sessionRef.id };
  } catch (error) {
    logger.error('Error in createPurchaseToken:', error);
    throw error;
  }
});

exports.createCheckoutSession = onRequest({
  cors: ["*"],
  maxInstances: 20,
  minInstances: 1,
  secrets: ["STRIPE_SECRET_KEY"],
}, async (req, res) => {
  cors(req, res, async () => {
    if (req.method !== 'POST') return res.status(405).send('Method not allowed');

    try {
      const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
      const { token, sessionId } = req.body;

      if (!token || !sessionId) return res.status(400).send('Token and sessionId required');

      const expectedTokenPrefix = sessionId + '.';
      if (!token.startsWith(expectedTokenPrefix)) return res.status(403).send('Invalid token format');

      const db = admin.firestore();
      const sessionDoc = await db.collection('purchaseSessions').doc(sessionId).get();

      if (!sessionDoc.exists) return res.status(404).send('Session not found');

      const sessionData = sessionDoc.data();

      if (sessionData.expiresAt.toMillis() < Date.now()) return res.status(410).send('Session expired');

      const coinAmount = sessionData.coinAmount;
      const priceInCents = sessionData.priceInCents;
      const userId = sessionData.userId;
      const competitionId = sessionData.competitionId;

      const allowedAmounts = Object.keys(COIN_PACKAGES).map(Number);
      if (!allowedAmounts.includes(coinAmount)) return res.status(400).send('Invalid coin amount');

      let customerId;
      try {
        const customers = await stripe.customers.search({
          query: `metadata['firebase_uid']:'${userId}'`,
          limit: 1
        });
        customerId = customers.data[0]?.id || (await stripe.customers.create({
          metadata: { firebase_uid: userId }
        })).id;
      } catch (error) {
        logger.error('Error handling customer:', error);
        return res.status(500).send('Customer error');
      }

      const stripeSession = await stripe.checkout.sessions.create({
        payment_method_types: ['card'],
        line_items: [{
          price_data: {
            currency: 'usd',
            product_data: {
              name: `${coinAmount.toLocaleString()} Coins`,
              description: `Purchase ${coinAmount.toLocaleString()} coins`,
            },
            unit_amount: priceInCents,
          },
          quantity: 1,
        }],
        mode: 'payment',
        origin_context: 'mobile_app',
        customer: customerId,
        success_url: `${req.headers.origin}/success?session_id={CHECKOUT_SESSION_ID}`,
        cancel_url: `${req.headers.origin}/cancel`,
        metadata: {
          userId: userId,
          competitionId: competitionId,
          coinAmount: coinAmount.toString(),
          purchaseSessionId: sessionId
        }
      });

      res.json({ sessionId: stripeSession.id, url: stripeSession.url });
    } catch (error) {
      logger.error('Error creating checkout session:', error);
      res.status(500).send('Internal server error');
    }
  });
});

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
    logger.error('Webhook signature verification failed:', err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  if (event.type === 'checkout.session.completed') {
    await handleSuccessfulCoinPurchase(event.data.object);
  }

  if (event.type === 'payment_intent.succeeded') {
    const intent = event.data.object;
    if (intent.metadata?.top_up === 'true') {
      await handleSuccessfulTopUp(intent);
    }
  }

  res.json({ received: true });
});

async function handleSuccessfulCoinPurchase(session) {
  const { userId, competitionId, coinAmount } = session.metadata;
  const coins = parseInt(coinAmount);

  try {
    const db        = admin.firestore();
    const memberRef = db.collection('competitions')
                       .doc(competitionId)
                       .collection('members')
                       .doc(userId);

    await db.runTransaction(async (transaction) => {
      const memberDoc = await transaction.get(memberRef);
      if (!memberDoc.exists) {
        transaction.set(memberRef, {
          coins:    coins,
          joinedAt: admin.firestore.Timestamp.now(),
          userId:   userId
        });
      } else {
        transaction.update(memberRef, {
          coins: (memberDoc.data().coins || 0) + coins
        });
      }
    });

    await logWebPurchase(userId, competitionId, coins, session);
    logger.info(`handleSuccessfulCoinPurchase: ${coins} coins to ${userId}`);
  } catch (error) {
    logger.error('Error handling coin purchase:', error);
  }
}

async function handleSuccessfulTopUp(intent) {
  const userId      = intent.metadata.user_id;
  const amountPence = intent.amount;
  const amount      = parseFloat((amountPence / 100).toFixed(2));
  const intentId    = intent.id;

  if (!userId) {
    logger.error('handleSuccessfulTopUp: no user_id in metadata');
    return;
  }

  const db       = admin.firestore();
  const orderRef = db.collection('payment_orders').doc(intentId);

  try {
    await db.runTransaction(async (t) => {
      const existing = await t.get(orderRef);
      if (existing.exists) {
        logger.info(`handleSuccessfulTopUp: ${intentId} already processed`);
        return;
      }

      const userRef    = db.collection('users').doc(userId);
      const userDoc    = await t.get(userRef);
      const current    = userDoc.exists ? (userDoc.data().wallet_balance ?? 0) : 0;
      const newBalance = parseFloat((current + amount).toFixed(2));

      t.set(userRef, {
        wallet_balance: admin.firestore.FieldValue.increment(amount)
      }, { merge: true });

      t.set(orderRef, {
        user_id:      userId,
        amount,
        currency:     'USD',
        provider:     'stripe',
        status:       'credited',
        processed_at: admin.firestore.FieldValue.serverTimestamp()
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

async function logWebPurchase(userId, competitionId, coinAmount, session) {
  const db = admin.firestore();
  await db.collection('competitions')
          .doc(competitionId)
          .collection('purchases')
          .add({
            userId:           userId,
            coinAmount:       coinAmount,
            timestamp:        admin.firestore.Timestamp.now(),
            price:            session.amount_total / 100,
            source:           'web',
            stripeSessionId:  session.id,
            stripeCustomerId: session.customer
          });
}

exports.checkPurchaseStatus = onCall({
  cors: ["*"],
  maxInstances: 20
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');

  const { competitionId } = request.data;
  const userId = request.auth.uid;

  const db = admin.firestore();
  const memberDoc = await db.collection('competitions')
                          .doc(competitionId)
                          .collection('members')
                          .doc(userId)
                          .get();

  const coins = memberDoc.exists ? (memberDoc.data().coins || 0) : 0;
  return { coins };
});

// ── Wallet ────────────────────────────────────────────────────
exports.creditWelcomeBonus = wallet.creditWelcomeBonus;
exports.deductBalance      = wallet.deductBalance;
exports.creditBalance      = wallet.creditBalance;
exports.adminCreditBalance = wallet.adminCreditBalance;
exports.requestWithdrawal  = wallet.requestWithdrawal;
exports.approveWithdrawal  = wallet.approveWithdrawal;
exports.rejectWithdrawal   = wallet.rejectWithdrawal;
exports.createTopUpIntent  = wallet.createTopUpIntent;
exports.confirmTopUpIntent = wallet.confirmTopUpIntent;

// ── Sessions & Rounds ─────────────────────────────────────────
exports.createSession = round.createSession;
exports.joinSession   = round.joinSession;
exports.endSession    = round.endSession;
exports.inviteMore    = round.inviteMore;
exports.createRound   = round.createRound;
exports.joinRound     = round.joinRound;
exports.leaveRound    = round.leaveRound;
exports.startRound    = round.startRound;

// ── Live Calls ────────────────────────────────────────────────
exports.getLiveKitToken = livekit.getLiveKitToken;
exports.sendCallInvite  = callkit.sendCallInvite;
exports.sendCallEnded   = callkit.sendCallEnded;

// ── Web Battle ────────────────────────────────────────────────
exports.saveUserProfile = webBattle.saveUserProfile;
