const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const { google } = require('googleapis');
const logger = require("firebase-functions/logger");

// Initialize Firebase Admin SDK
admin.initializeApp();

// Function to get access token
exports.getAccessToken = onRequest({
  // Optionally restrict CORS
  cors: ["*"],
  // Set max instances as needed
  maxInstances: 10,
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
    
    // Use Application Default Credentials (ADC)
    // This automatically uses the Firebase service account credentials
    const auth = new google.auth.GoogleAuth({
      scopes: ['https://www.googleapis.com/auth/firebase.messaging']
    });
    
    const authClient = await auth.getClient();
    const { token } = await authClient.getAccessToken();
    
    if (!token) {
      throw new Error("Failed to get access token");
    }
    
    // Log success but don't log the actual token in production
    logger.info("Access token obtained successfully");
    
    // Return the token
    response.json({ 
      accessToken: token,
      // Token typically expires in 1 hour (3600 seconds)
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