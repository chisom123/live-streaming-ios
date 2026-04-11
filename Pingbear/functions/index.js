const { onRequest, onCall } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const { google } = require('googleapis');
const logger = require("firebase-functions/logger");
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
  cors: ["*"],
  maxInstances: 20,
  secrets: ["STRIPE_SECRET_KEY", "STRIPE_WEBHOOK_SECRET"],
}, async (req, res) => {
  // Initialize Stripe with secret
  const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
  
  const sig = req.headers['stripe-signature'];
  const endpointSecret = process.env.STRIPE_WEBHOOK_SECRET;

  let event;

  try {
    event = stripe.webhooks.constructEvent(req.rawBody, sig, endpointSecret);
  } catch (err) {
    logger.error('Webhook signature verification failed:', err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  if (event.type === 'checkout.session.completed') {
    const session = event.data.object;
    await handleSuccessfulPayment(session);
  }

  res.json({ received: true });
});

async function handleSuccessfulPayment(session) {
  const { userId, competitionId, coinAmount } = session.metadata;
  const coins = parseInt(coinAmount);
  
  try {
    const db = admin.firestore();
    const memberRef = db.collection('competitions')
                      .doc(competitionId)
                      .collection('members')
                      .doc(userId);

    // Update member coins in a transaction
    await db.runTransaction(async (transaction) => {
      const memberDoc = await transaction.get(memberRef);
      
      if (!memberDoc.exists) {
        // Create member document if it doesn't exist
        transaction.set(memberRef, {
          coins: coins,
          joinedAt: admin.firestore.Timestamp.now(),
          userId: userId
        });
      } else {
        // Add coins to existing total
        const currentCoins = memberDoc.data().coins || 0;
        transaction.update(memberRef, {
          coins: currentCoins + coins
        });
      }
    });

    // Log the purchase
    await logWebPurchase(userId, competitionId, coins, session);
    
    logger.info(`Successfully added ${coins} coins to user ${userId} in competition ${competitionId}`);
  } catch (error) {
    logger.error('Error handling successful payment:', error);
    // Could implement retry logic or dead letter queue here
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

// GLOBAL LEADERBOARD - Close pots function
exports.closePots = onSchedule({
  schedule: 'every 1 minutes',
  timeZone: 'UTC',
}, async (event) => {
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();
  
  // Find all active pots that have ended
  // NOTE: This query requires a composite index on (end_date, status)
  const endedPotsSnapshot = await db.collection('global_pots')
    .where('end_date', '<=', now)
    .where('status', '==', 'active')
    .get();
  
  if (endedPotsSnapshot.empty) {
    logger.info('No pots to close');
    return null;
  }
  
  logger.info(`Found ${endedPotsSnapshot.size} pots to close`);
  
  // Process each pot
  const promises = endedPotsSnapshot.docs.map(potDoc => 
    closePot(potDoc.id, potDoc.data(), db)
  );
  
  await Promise.all(promises);
  logger.info('All pots processed');
  return null;
});

async function closePot(potId, potData, db) {
  logger.info(`Closing pot ${potId}`);
  
  try {
    // Get all participants sorted by stars
    const participantsSnapshot = await db.collection('global_pots')
      .doc(potId)
      .collection('participants')
      .orderBy('total_stars', 'desc')
      .get();
    
    if (participantsSnapshot.empty) {
      logger.info(`Pot ${potId} has no participants`);
      await db.collection('global_pots').doc(potId).update({
        status: 'closed',
        closed_at: admin.firestore.FieldValue.serverTimestamp(),
        prizes_paid: false,
        total_winners: 0
      });
      return;
    }
    
    // Calculate ranks and prizes with tie handling
    const participantUpdates = [];
    const userUpdates = [];
    let currentRank = 1;
    let lastStarCount = null;
    let tiedPlayers = [];
    
    participantsSnapshot.docs.forEach((doc, index) => {
      const data = doc.data();
      const userId = doc.id;
      const stars = data.total_stars || 0;
      
      // Check if this is a tie with previous player
      if (lastStarCount !== null && stars < lastStarCount) {
        // Different score - process previous tied group first
        if (tiedPlayers.length > 0) {
          processTiedGroup(tiedPlayers, potData, participantUpdates, userUpdates);
        }
        
        // Start new rank
        currentRank = index + 1;
        tiedPlayers = [{ref: doc.ref, userId, stars, rank: currentRank}];
      } else if (lastStarCount === stars) {
        // Same score as previous - add to tied group
        tiedPlayers.push({ref: doc.ref, userId, stars, rank: currentRank});
      } else {
        // First player
        tiedPlayers = [{ref: doc.ref, userId, stars, rank: currentRank}];
      }
      
      lastStarCount = stars;
    });
    
    // Don't forget to process the last group
    if (tiedPlayers.length > 0) {
      processTiedGroup(tiedPlayers, potData, participantUpdates, userUpdates);
    }
    
    // Batch write all participant updates (max 500 per batch)
    const participantBatches = [];
    for (let i = 0; i < participantUpdates.length; i += 500) {
      const batch = db.batch();
      const chunk = participantUpdates.slice(i, i + 500);
      chunk.forEach(update => {
        batch.update(update.ref, update.data);
      });
      participantBatches.push(batch.commit());
    }
    await Promise.all(participantBatches);
    
    // Update user wallets and create transactions (max 500 per batch)
    const userBatches = [];
    for (let i = 0; i < userUpdates.length; i += 500) {
      const batch = db.batch();
      const chunk = userUpdates.slice(i, i + 500);
      
      chunk.forEach(update => {
        const userRef = db.collection('users').doc(update.userId);
        
        // Update wallet balance, lifetime earnings, and clear active_pot_id
        batch.update(userRef, {
          wallet_balance: admin.firestore.FieldValue.increment(update.prize),
          lifetime_earnings: admin.firestore.FieldValue.increment(update.prize),
          active_pot_id: admin.firestore.FieldValue.delete()
        });
        
        // Create transaction record
        const transactionRef = userRef.collection('transactions').doc();
        batch.set(transactionRef, {
          type: 'winning',
          amount: update.prize,
          description: `Rank #${update.rank} - ${update.stars} stars`,
          pot_id: potId,
          rank: update.rank,
          stars: update.stars,
          timestamp: admin.firestore.FieldValue.serverTimestamp()
        });
      });
      
      userBatches.push(batch.commit());
    }
    await Promise.all(userBatches);
    
    // Clear active_pot_id for ALL participants (including non-winners)
    const clearPotBatches = [];
    for (let i = 0; i < participantsSnapshot.docs.length; i += 500) {
      const batch = db.batch();
      const chunk = participantsSnapshot.docs.slice(i, i + 500);
      
      chunk.forEach(doc => {
        const userRef = db.collection('users').doc(doc.id);
        batch.update(userRef, {
          active_pot_id: admin.firestore.FieldValue.delete()
        });
      });
      
      clearPotBatches.push(batch.commit());
    }
    await Promise.all(clearPotBatches);
    
    // Mark pot as closed
    await db.collection('global_pots').doc(potId).update({
      status: 'closed',
      closed_at: admin.firestore.FieldValue.serverTimestamp(),
      prizes_paid: true,
      total_winners: userUpdates.length
    });
    
    logger.info(`Pot ${potId} closed successfully with ${participantUpdates.length} participants and ${userUpdates.length} winners`);
  } catch (error) {
    logger.error(`Error closing pot ${potId}:`, error);
    throw error;
  }
}

function calculatePrize(rank, firstPlacePrize, decayRate, minPayout) {
  if (decayRate === 0) return rank === 1 ? firstPlacePrize : 0;
  
  // Use integer math for cents to avoid floating point errors
  const prizeCents = Math.floor(firstPlacePrize * 100 * Math.pow(decayRate, rank - 1));
  
  if (prizeCents < minPayout * 100) return 0;
  
  return prizeCents / 100;
}

// Helper function to process a group of tied players
function processTiedGroup(tiedPlayers, potData, participantUpdates, userUpdates) {
  // Calculate base prize for this rank
  const basePrize = calculatePrize(
    tiedPlayers[0].rank,
    potData.first_place_prize || 100,
    potData.decay_rate || 0,
    potData.min_payout || 0.01
  );
  
  // Split prize evenly among tied players
  const splitPrize = Math.floor((basePrize / tiedPlayers.length) * 100) / 100;
  
  logger.info(`Rank ${tiedPlayers[0].rank}: ${tiedPlayers.length} tied players, splitting $${basePrize} = $${splitPrize} each`);
  
  // Queue updates for each tied player
  tiedPlayers.forEach(player => {
    // Queue participant update
    participantUpdates.push({
      ref: player.ref,
      data: {
        final_rank: player.rank,
        prize_amount: splitPrize,
        tied_with: tiedPlayers.length - 1,  // Exclude self from count
        calculated_at: admin.firestore.FieldValue.serverTimestamp()
      }
    });
    
    // If prize > 0, queue user wallet update
    if (splitPrize > 0) {
      userUpdates.push({
        userId: player.userId,
        prize: splitPrize,
        rank: player.rank,
        stars: player.stars
      });
    }
  });
}


// DAILY RACE - Close races function
exports.closeRaces = onSchedule({
  schedule: 'every 1 minutes',
  timeZone: 'UTC',
}, async (event) => {
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();
  
  const endedRacesSnapshot = await db.collection('competition_races')
    .where('end_date', '<=', now)
    .where('status', '==', 'active')
    .get();
  
  if (endedRacesSnapshot.empty) {
    logger.info('No races to close');
    return null;
  }
  
  logger.info(`Found ${endedRacesSnapshot.size} races to close`);
  
  const promises = endedRacesSnapshot.docs.map(raceDoc =>
    closeRace(raceDoc.id, raceDoc.data(), db)
  );
  
  await Promise.all(promises);
  logger.info('All races processed');
  return null;
});

async function closeRace(raceId, raceData, db) {
  logger.info(`Closing race ${raceId}`);
  
  try {
    // Get all participants sorted by stars
    const participantsSnapshot = await db.collection('competition_races')
      .doc(raceId)
      .collection('race_participants')
      .orderBy('total_stars', 'desc')
      .get();
    
    if (participantsSnapshot.empty) {
      logger.info(`Race ${raceId} has no participants`);
      await db.collection('competition_races').doc(raceId).update({
        status: 'closed',
        closed_at: admin.firestore.FieldValue.serverTimestamp()
      });
      return;
    }
    
    const totalStars = raceData.total_stars || 0;
    const pointsPool = raceData.points_pool || 0;
    
    if (totalStars === 0 || pointsPool === 0) {
      logger.info(`Race ${raceId} has no stars or points to distribute`);
      await db.collection('competition_races').doc(raceId).update({
        status: 'closed',
        closed_at: admin.firestore.FieldValue.serverTimestamp()
      });
      return;
    }
    
    // Calculate points for each participant
    const participantUpdates = [];
    
    participantsSnapshot.docs.forEach(doc => {
      const data = doc.data();
      const userId = doc.id;
      const stars = data.total_stars || 0;
      
      if (stars === 0) return;
      
      // Proportional points: their stars / total stars × points pool
      const points = Math.floor((stars / totalStars) * pointsPool);
      
      if (points > 0) {
        participantUpdates.push({
          ref: doc.ref,
          userId,
          points,
          stars
        });
      }
    });
    
    // Award points to global leaderboard for each participant
    const globalLeaderboardPromises = participantUpdates.map(update =>
      awardPointsToGlobalLeaderboard(update.userId, update.points, db)
    );
    
    await Promise.all(globalLeaderboardPromises);
    
    // Update participant records with points awarded
    const batch = db.batch();
    participantUpdates.forEach(update => {
      batch.update(update.ref, {
        points_awarded: update.points
      });
    });
    
    // Mark race as closed
    const raceRef = db.collection('competition_races').doc(raceId);
    batch.update(raceRef, {
      status: 'closed',
      closed_at: admin.firestore.FieldValue.serverTimestamp(),
      total_winners: participantUpdates.length
    });
    
    await batch.commit();
    
    logger.info(`Race ${raceId} closed successfully, ${participantUpdates.length} participants awarded points`);
  } catch (error) {
    logger.error(`Error closing race ${raceId}:`, error);
    throw error;
  }
}

async function awardPointsToGlobalLeaderboard(userId, points, db) {
  try {
    // Check if user has an active pot
    const userDoc = await db.collection('users').doc(userId).get();
    const activePotId = userDoc.data()?.active_pot_id;
    
    if (activePotId) {
      // Verify pot is still active
      const potDoc = await db.collection('global_pots').doc(activePotId).get();
      const potData = potDoc.data();
      
      if (potData?.status === 'active' && potData?.end_date?.toMillis() > Date.now()) {
        // Add points to existing pot participant
        const participantRef = db.collection('global_pots')
          .doc(activePotId)
          .collection('participants')
          .doc(userId);
        
        const participantDoc = await participantRef.get();
        
        if (participantDoc.exists) {
          await participantRef.update({
            total_stars: admin.firestore.FieldValue.increment(points),
            last_star_at: admin.firestore.FieldValue.serverTimestamp()
          });
        } else {
          // User not yet in pot participants, add them
          await participantRef.set({
            user_id: userId,
            total_stars: points,
            last_star_at: admin.firestore.FieldValue.serverTimestamp(),
            joined_at: admin.firestore.FieldValue.serverTimestamp()
          });
          
          // Increment pot participant count
          await db.collection('global_pots').doc(activePotId).update({
            participant_count: admin.firestore.FieldValue.increment(1)
          });
        }
        
        logger.info(`✅ Awarded ${points} points to user ${userId} in pot ${activePotId}`);
        return;
      }
    }
    
    // No active pot - find or create one
    await joinPotAndAwardPoints(userId, points, db);
    
  } catch (error) {
    logger.error(`Error awarding points to user ${userId}:`, error);
    throw error;
  }
}

async function joinPotAndAwardPoints(userId, points, db) {
  await db.runTransaction(async (transaction) => {
    const currentPotRef = db.collection('app_config').doc('current_pot');
    const currentPotDoc = await transaction.get(currentPotRef);
    
    let potId;
    
    // Check if current pot exists and is valid
    if (currentPotDoc.exists) {
      const potData = currentPotDoc.data();
      const potId_candidate = potData?.pot_id;
      
      if (potId_candidate && potData?.end_date?.toMillis() > Date.now()) {
        const potRef = db.collection('global_pots').doc(potId_candidate);
        const potDoc = await transaction.get(potRef);
        const potDocData = potDoc.data();
        
        if (potDocData?.status === 'active' &&
            potDocData?.participant_count < potDocData?.max_participants) {
          potId = potId_candidate;
          
          // Add participant to existing pot
          const participantRef = db.collection('global_pots')
            .doc(potId)
            .collection('participants')
            .doc(userId);
          
          transaction.set(participantRef, {
            user_id: userId,
            total_stars: points,
            last_star_at: admin.firestore.FieldValue.serverTimestamp(),
            joined_at: admin.firestore.FieldValue.serverTimestamp()
          });
          
          transaction.update(potRef, {
            participant_count: admin.firestore.FieldValue.increment(1)
          });
          
          transaction.update(currentPotRef, {
            participant_count: admin.firestore.FieldValue.increment(1)
          });
          
          transaction.update(db.collection('users').doc(userId), {
            active_pot_id: potId
          });
          
          return;
        }
      }
    }
    
    // Create new pot
    const now = new Date();
    const endDate = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
    const newPotRef = db.collection('global_pots').doc();
    potId = newPotRef.id;
    
    // Get config for pot settings
    const configDoc = await transaction.get(
      db.collection('app_config').doc('global_leaderboard')
    );
    const config = configDoc.data() || {};
    
    transaction.set(newPotRef, {
      pot_id: potId,
      start_date: admin.firestore.Timestamp.fromDate(now),
      end_date: admin.firestore.Timestamp.fromDate(endDate),
      status: 'active',
      max_participants: config.pot_max_participants || 1000,
      first_place_prize: config.first_place_prize || 100.0,
      decay_rate: config.decay_rate || 0.0,
      min_payout: config.min_payout || 0.01,
      participant_count: 1,
      created_at: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Add participant
    const participantRef = db.collection('global_pots')
      .doc(potId)
      .collection('participants')
      .doc(userId);
    
    transaction.set(participantRef, {
      user_id: userId,
      total_stars: points,
      last_star_at: admin.firestore.FieldValue.serverTimestamp(),
      joined_at: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Update current pot reference
    transaction.set(currentPotRef, {
      pot_id: potId,
      participant_count: 1,
      end_date: admin.firestore.Timestamp.fromDate(endDate),
      updated_at: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Update user
    transaction.update(db.collection('users').doc(userId), {
      active_pot_id: potId
    });
    
    logger.info(`✅ Created new pot ${potId} and awarded ${points} points to user ${userId}`);
  });
}

exports.awardLeaderboardPoints = onCall({
  cors: ["*"],
  maxInstances: 20,
}, async (request) => {
  if (!request.auth) {
    throw new Error('User must be authenticated');
  }

  const { points } = request.data;
  const userId = request.auth.uid;

  const MAX_POINTS_PER_CLAIM = 1000;
  
  if (!Number.isInteger(points) || points <= 0 || points > MAX_POINTS_PER_CLAIM) {
    throw new Error('Invalid points value');
  }

  const db = admin.firestore();

  try {
    await awardPointsToGlobalLeaderboard(userId, points, db);
    logger.info(`✅ awardLeaderboardPoints: awarded ${points} to ${userId}`);
    return { success: true, points };
  } catch (error) {
    logger.error('Error in awardLeaderboardPoints:', error);
    throw new Error(error.message);
  }
});

// Call Live Leaderboard

exports.getCurrentPot = onRequest({
  cors: ["*"],
  maxInstances: 20,
  minInstances: 1
}, async (req, res) => {
  cors(req, res, async () => {
    if (req.method !== 'GET') {
      return res.status(405).send('Method not allowed');
    }

    try {
      const db = admin.firestore();

      // 1. Get current pot reference
      const currentPotDoc = await db.collection('app_config').doc('current_pot').get();

      if (!currentPotDoc.exists) {
        return res.status(404).json({ error: 'No active pot found' });
      }

      const currentPotData = currentPotDoc.data();
      const potId = currentPotData?.pot_id;

      if (!potId) {
        return res.status(404).json({ error: 'No pot ID in config' });
      }

      // 2. Get the pot document
      const potDoc = await db.collection('global_pots').doc(potId).get();

      if (!potDoc.exists) {
        return res.status(404).json({ error: 'Pot document not found' });
      }

      const potData = potDoc.data();

      // 3. Get all participants ordered by stars
      const participantsSnapshot = await db
        .collection('global_pots')
        .doc(potId)
        .collection('participants')
        .orderBy('total_stars', 'desc')
        .get();

      // 4. Fetch user display data for each participant
      const participantDocs = participantsSnapshot.docs;
      const userIds = participantDocs.map(doc => doc.id);

      // Batch fetch user documents (Firestore allows up to 10 in getAll)
      const userRefs = userIds.map(uid => db.collection('users').doc(uid));
      const userDocs = userRefs.length > 0 ? await db.getAll(...userRefs) : [];

      const userMap = {};
      userDocs.forEach(doc => {
        if (doc.exists) {
          const data = doc.data();
          userMap[doc.id] = {
            name: data.name ?? 'Unknown',
            profilePictureUrl: data.profilePictureUrl ?? null,
          };
        }
      });

      // 5. Build ranked participant list with tie handling
      const participants = [];
      let currentRank = 1;
      let lastStars = null;

      participantDocs.forEach((doc, index) => {
        const data = doc.data();
        const stars = data.total_stars ?? 0;

        if (lastStars !== null && stars < lastStars) {
          currentRank = index + 1;
        }
        lastStars = stars;

        const user = userMap[doc.id] ?? { name: 'Unknown', profilePictureUrl: null };

        participants.push({
          userId: doc.id,
          name: user.name,
          profilePictureUrl: user.profilePictureUrl,
          totalStars: stars,
          rank: currentRank,
          position: index + 1,
          joinedAt: data.joined_at?.toMillis?.() ?? null,
          lastStarAt: data.last_star_at?.toMillis?.() ?? null,
        });
      });

      // 6. Return everything
      return res.json({
        pot: {
          potId,
          status: potData.status,
          startDate: potData.start_date?.toMillis?.() ?? null,
          endDate: potData.end_date?.toMillis?.() ?? null,
          firstPlacePrize: potData.first_place_prize ?? 100,
          decayRate: potData.decay_rate ?? 0,
          minPayout: potData.min_payout ?? 0.01,
          maxParticipants: potData.max_participants ?? 1000,
          participantCount: potData.participant_count ?? 0,
        },
        participants,
      });

    } catch (error) {
      logger.error('Error in getCurrentPot:', error);
      return res.status(500).json({ error: 'Internal server error' });
    }
  });
});

exports.createWebUser = onCall({
  cors: ["*"],
  maxInstances: 20,
}, async (request) => {
  if (!request.auth) {
    throw new Error('User must be authenticated');
  }

  const { winCode, phoneNumberHash } = request.data;
  const userId = request.auth.uid;

  if (!winCode) throw new Error('winCode is required');
  if (!phoneNumberHash) throw new Error('phoneNumberHash is required');

  const db = admin.firestore();
  const userRef = db.collection('users').doc(userId);

  try {
    const userDoc = await userRef.get();

    if (userDoc.exists) {
      const userData = userDoc.data();

      // Existing user who completed onboarding — save winCode for background claim in app
      if (userData.profileComplete === true || userData.username) {
        await userRef.update({
          winCode,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        logger.info(`createWebUser: existing user ${userId}, winCode saved for background claim`);
        return { existingUser: true };
      }

      // Existing web signup — update winCode, claim happens in NameEntryView
      await userRef.update({
        winCode,
        phoneNumberHash,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      logger.info(`createWebUser: updated existing web user ${userId}`);
      return { existingUser: false };
    }

    // New user — claim happens in NameEntryView during onboarding
    await userRef.set({
      winCode,
      phoneNumberHash,
      createdFromWeb: true,
      profileComplete: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    logger.info(`createWebUser: created new web user ${userId}`);
    return { existingUser: false };

  } catch (error) {
    logger.error('Error in createWebUser:', error);
    throw new Error(error.message);
  }
});