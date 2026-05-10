const { onRequest, onCall } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const { google } = require('googleapis');
const logger = require("firebase-functions/logger");
const wallet = require('./walletFunctions');
const race = require('./raceFunctions');
const challenge = require('./challengeFunctions');
// Stripe will be initialized in functions that need it
const cors = require('cors')({ origin: true });

// Initialize Firebase Admin SDK outside function handler
admin.initializeApp();

// Pre-initialize auth client
const auth = new google.auth.GoogleAuth({
  scopes: ['https://www.googleapis.com/auth/firebase.messaging']
});

// Create auth client outside function scope
const authClientPromise = auth.getClient();

// Coin pricing configuration - PACKAGE BASED
const COIN_PACKAGES = {
  '100': 99,    // 100 coins for $0.99 (in cents)
  '600': 499,   // 600 coins for $4.99 (in cents)
  '1500': 999   // 1,500 coins for $9.99 (in cents)
};

// Your existing function
exports.getAccessToken = onRequest({
  cors: ["*"],
  maxInstances: 20,
  minInstances: 1, // Keep at least one instance warm
}, async (request, response) => {
  try {
    // Handle CORS preflight requests
    if (request.method === 'OPTIONS') {
      response.set('Access-Control-Allow-Methods', 'GET');
      response.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
      response.status(204).send('');
      return;
    }

    // Get the project ID from the default app
    const projectId = process.env.GCLOUD_PROJECT || admin.app().options.projectId;
    if (!projectId) {
      throw new Error("Could not determine project ID");
    }

    logger.info(`Using project ID: ${projectId}`);

    // Use the pre-initialized client
    const authClient = await authClientPromise;
    const { token } = await authClient.getAccessToken();

    if (!token) {
      throw new Error("Failed to get access token");
    }

    // Log success but don't log the actual token in production
    logger.info("Access token obtained successfully");

    // Return the token
    response.json({
      accessToken: token,
      expiresIn: 3600
    });
  } catch (error) {
    logger.error("Error obtaining access token:", error);
    response.status(500).json({
      error: "Failed to generate token",
      message: process.env.NODE_ENV === 'development' ? error.message : "Server error"
    });
  }
});

// NEW STRIPE FUNCTIONS

// Generate secure purchase token
exports.createPurchaseToken = onCall({
  cors: ["*"],
  maxInstances: 20,
  minInstances: 1
}, async (request) => {
  try {
    // Verify user is authenticated
    if (!request.auth) {
      logger.error('User not authenticated');
      throw new Error('User must be authenticated');
    }

    const { competitionId, coinAmount } = request.data;
    
    logger.info('Request data:', { competitionId, coinAmount, userId: request.auth.uid });
    
    if (!competitionId) {
      logger.error('Competition ID missing');
      throw new Error('Competition ID is required');
    }

    // Validate coin amount against allowed packages
    const allowedAmounts = Object.keys(COIN_PACKAGES).map(Number);
    if (!allowedAmounts.includes(coinAmount)) {
      logger.error('Invalid coin amount:', coinAmount);
      throw new Error(`Coin amount must be one of: ${allowedAmounts.join(', ')}`);
    }

    // Store the purchase session data in Firestore
    const db = admin.firestore();
    const sessionRef = db.collection('purchaseSessions').doc();
    await sessionRef.set({
      userId: request.auth.uid,
      competitionId: competitionId,
      coinAmount: coinAmount,
      priceInCents: COIN_PACKAGES[coinAmount.toString()], // Store the fixed price
      createdAt: admin.firestore.Timestamp.now(),
      expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + (30 * 60 * 1000)), // 30 minutes
      sessionId: sessionRef.id
    });

    // Create simple secure token
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

// Create Stripe checkout session
exports.createCheckoutSession = onRequest({
  cors: ["*"],
  maxInstances: 20,
  minInstances: 1,
  secrets: ["STRIPE_SECRET_KEY"],
}, async (req, res) => {
  cors(req, res, async () => {
    if (req.method !== 'POST') {
      return res.status(405).send('Method not allowed');
    }

    try {
      // Initialize Stripe with secret
      const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
      
      const { token, sessionId } = req.body;

      if (!token || !sessionId) {
        return res.status(400).send('Token and sessionId required');
      }

      // Validate token format
      const expectedTokenPrefix = sessionId + '.';
      if (!token.startsWith(expectedTokenPrefix)) {
        return res.status(403).send('Invalid token format');
      }

      // Get session data from Firestore
      const db = admin.firestore();
      const sessionDoc = await db.collection('purchaseSessions').doc(sessionId).get();
      
      if (!sessionDoc.exists) {
        return res.status(404).send('Session not found');
      }

      const sessionData = sessionDoc.data();
      
      // Check if session has expired
      if (sessionData.expiresAt.toMillis() < Date.now()) {
        return res.status(410).send('Session expired');
      }

      const coinAmount = sessionData.coinAmount;
      const priceInCents = sessionData.priceInCents; // Use the stored fixed price
      const userId = sessionData.userId;
      const competitionId = sessionData.competitionId;

      // Validate coin amount against allowed packages
      const allowedAmounts = Object.keys(COIN_PACKAGES).map(Number);
      if (!allowedAmounts.includes(coinAmount)) {
        return res.status(400).send('Invalid coin amount');
      }

      // Create or get Stripe customer
      let customerId;
      try {
        // Efficiently search for existing customer by Firebase UID
        const customers = await stripe.customers.search({
          query: `metadata['firebase_uid']:'${userId}'`,
          limit: 1
        });
      
        // Use existing customer if found, otherwise create
        customerId = customers.data[0]?.id || (await stripe.customers.create({
          metadata: { firebase_uid: userId }
        })).id;
      } catch (error) {
        logger.error('Error handling customer:', error);
        return res.status(500).send('Customer error');
      }

      // Create Stripe checkout session
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
        origin_context: 'mobile_app', // Optimized for app-to-web flow
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

// Handle Stripe webhooks
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
    // Existing coin purchase flow — unchanged
    await handleSuccessfulCoinPurchase(event.data.object);
  }

  if (event.type === 'payment_intent.succeeded') {
    const intent = event.data.object;
    // Only handle wallet top-ups — ignore other PaymentIntents
    if (intent.metadata?.top_up === 'true') {
      await handleSuccessfulTopUp(intent);
    }
  }

  res.json({ received: true });
});


// ── Existing coin purchase handler — renamed but unchanged ────

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


// ── New wallet top-up handler ─────────────────────────────────

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
      // Idempotency — skip if already processed
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

      // Record wallet transaction
      const txRef = db.collection('wallet_transactions').doc();
      t.set(txRef, {
        user_id:        userId,
        type:           'credit',
        amount,
        reason:         'top_up',
        competition_id: null,
        metadata:       { payment_intent_id: intentId, provider: 'stripe' },
        balance_before: current,
        balance_after:  newBalance,
        created_at:     admin.firestore.FieldValue.serverTimestamp()
      });
    });

    logger.info(`handleSuccessfulTopUp: £${amount} credited to ${userId}`);
  } catch (error) {
    logger.error('handleSuccessfulTopUp error:', error);
  }
}

async function logWebPurchase(userId, competitionId, coinAmount, session) {
  const db = admin.firestore();
  
  const purchaseData = {
    userId: userId,
    coinAmount: coinAmount,
    timestamp: admin.firestore.Timestamp.now(),
    price: session.amount_total / 100, // Convert from cents
    source: 'web',
    stripeSessionId: session.id,
    stripeCustomerId: session.customer
  };

  await db.collection('competitions')
          .doc(competitionId)
          .collection('purchases')
          .add(purchaseData);
}

// Check purchase status (for app to poll)
exports.checkPurchaseStatus = onCall({
  cors: ["*"],
  maxInstances: 20
}, async (request) => {
  if (!request.auth) {
    throw new Error('User must be authenticated');
  }

  const { competitionId } = request.data;
  const userId = request.auth.uid;

  // Get user's current coin balance
  const db = admin.firestore();
  const memberDoc = await db.collection('competitions')
                          .doc(competitionId)
                          .collection('members')
                          .doc(userId)
                          .get();

  const coins = memberDoc.exists ? (memberDoc.data().coins || 0) : 0;
  
  return { coins };
});

exports.saveUserProfile = onCall({
  cors: ['*'],
  maxInstances: 20,
  minInstances: 1
}, async (request) => {
  if (!request.auth) throw new Error('User must be authenticated');
 
  const { phoneNumberHash, linkId, fingerprint } = request.data;
  const userId = request.auth.uid;
 
  if (!phoneNumberHash) throw new Error('phoneNumberHash is required');
 
  const db = admin.firestore();
  const userRef = db.collection('users').doc(userId);
 
  try {
    const userDoc = await userRef.get();
 
    if (userDoc.exists) {
      // ── Existing user — update attribution fields ──────────
      // Always overwrite webRatingLinkId so every new web rating
      // gets a fresh attribution opportunity (last touch)
      await userRef.set({
        userId,
        phoneNumberHash,
        updatedAt:              admin.firestore.FieldValue.serverTimestamp(),
        ...(linkId && fingerprint && {
          webRatingLinkId:      linkId,
          webFingerprint:       fingerprint,
          webRatingOpenedApp:   false,
          webRatingAttributedAt: admin.firestore.FieldValue.serverTimestamp()
        })
      }, { merge: true });
 
      logger.info(`saveUserProfile: updated existing user ${userId}`);
    } else {
      // ── New user ───────────────────────────────────────────
      await userRef.set({
        userId,
        phoneNumberHash,
        createdFromWeb:         true,
        createdAt:              admin.firestore.FieldValue.serverTimestamp(),
        lastActiveAt:           admin.firestore.FieldValue.serverTimestamp(),
        ...(linkId && fingerprint && {
          webRatingLinkId:      linkId,
          webFingerprint:       fingerprint,
          webRatingOpenedApp:   false,
          webRatingAttributedAt: admin.firestore.FieldValue.serverTimestamp()
        })
      });
 
      logger.info(`saveUserProfile: created new user ${userId}`);
    }
 
    return { success: true, userId };
 
  } catch (error) {
    logger.error('saveUserProfile: error', { error: error.message, userId });
    throw new Error(error.message);
  }
});

// ── Wallet ────────────────────────────────────────────────────
exports.creditWelcomeBonus = wallet.creditWelcomeBonus;
exports.unlockBonus        = wallet.unlockBonus;
exports.deductBalance      = wallet.deductBalance;
exports.creditBalance      = wallet.creditBalance;
exports.adminCreditBalance = wallet.adminCreditBalance;
exports.requestWithdrawal  = wallet.requestWithdrawal;
exports.approveWithdrawal  = wallet.approveWithdrawal;
exports.rejectWithdrawal   = wallet.rejectWithdrawal;
exports.contributeToRace   = wallet.contributeToRace;
exports.recordStarsEarned  = wallet.recordStarsEarned;
exports.createTopUpIntent      = wallet.createTopUpIntent;
exports.confirmTopUpIntent     = wallet.confirmTopUpIntent;

// ── Race ──────────────────────────────────────────────────────
exports.setRaceDuration               = race.setRaceDuration;
exports.getOrCreateRaceForCompetition = race.getOrCreateRaceForCompetition;
exports.closeRaces                    = race.closeRaces;

// ── Challenges ──────────────────────────────────────────────────────
exports.assignChallenge               = challenge.assignChallenge;
