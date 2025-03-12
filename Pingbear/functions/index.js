const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { google } = require('googleapis');
const logger = require("firebase-functions/logger");

// Initialize Firebase Admin SDK outside function handler
admin.initializeApp();

// Pre-initialize auth client
const auth = new google.auth.GoogleAuth({
  scopes: ['https://www.googleapis.com/auth/firebase.messaging']
});
// Create auth client outside function scope
const authClientPromise = auth.getClient();

exports.getAccessToken = onRequest({
  cors: ["*"],
  maxInstances: 10,
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