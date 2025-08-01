import React, { useState, useEffect } from 'react';
import { createRoot } from 'react-dom/client';
import { initializeApp } from 'firebase/app';
import { getAuth, signInWithCustomToken } from 'firebase/auth';

// Your Firebase config - replace with your actual config
const firebaseConfig = {
    apiKey: "AIzaSyBOi9UCGqF9Ex1VPvzEP7c8nlB3IVrMv5w",
    authDomain: "pingbear-96b4c.firebaseapp.com",
    projectId: "pingbear-96b4c",
    storageBucket: "pingbear-96b4c.appspot.com",
    messagingSenderId: "958676880670",
    appId: "1:958676880670:web:7d69e799c05bd6004a0d0f",
    measurementId: "G-PRPFKVFXBJ"
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);

// Router component to handle different pages
function App() {
  const [currentPage, setCurrentPage] = useState('');

  useEffect(() => {
    const path = window.location.pathname;
    const search = window.location.search;
    
    if (path === '/success') {
      setCurrentPage('success');
    } else if (path === '/cancel') {
      setCurrentPage('cancel');
    } else if (search.includes('token=')) {
      setCurrentPage('purchase');
    } else {
      setCurrentPage('error');
    }
  }, []);

  switch (currentPage) {
    case 'purchase':
      return <PurchasePage />;
    case 'success':
      return <SuccessPage />;
    case 'cancel':
      return <CancelPage />;
    default:
      return <ErrorPage />;
  }
}

// Main Purchase Page Component
function PurchasePage() {
  const [loading, setLoading] = useState(true);
  const [authenticated, setAuthenticated] = useState(false);
  const [error, setError] = useState('');
  const [userInfo, setUserInfo] = useState(null);
  const [redirecting, setRedirecting] = useState(false);

  useEffect(() => {
    authenticateUser();
  }, []);

  const authenticateUser = async () => {
    try {
      // Get token and sessionId from URL params
      const urlParams = new URLSearchParams(window.location.search);
      const token = urlParams.get('token');
      const sessionId = urlParams.get('sessionId');

      if (!token || !sessionId) {
        setError('Invalid access. Please return to the app and try again.');
        setLoading(false);
        return;
      }

      // Get session data from Firestore
      const { getFirestore, doc, getDoc } = await import('firebase/firestore');
      const db = getFirestore();
      
      const sessionDoc = await getDoc(doc(db, 'purchaseSessions', sessionId));
      
      if (!sessionDoc.exists()) {
        setError('Invalid purchase session. Please try again.');
        setLoading(false);
        return;
      }
      
      const sessionData = sessionDoc.data();
      
      // Check if session has expired
      if (sessionData.expiresAt.toMillis() < Date.now()) {
        setError('Purchase session has expired. Please try again.');
        setLoading(false);
        return;
      }

      // Validate token
      const expectedTokenPrefix = sessionId + '.';
      if (!token.startsWith(expectedTokenPrefix)) {
        setError('Invalid access token. Please try again.');
        setLoading(false);
        return;
      }

      setUserInfo({
        coinAmount: sessionData.coinAmount,
        competitionId: sessionData.competitionId,
        sessionId: sessionId,
        userId: sessionData.userId,
        token: token,
        price: (sessionData.coinAmount * 0.01).toFixed(2)
      });

      setAuthenticated(true);
      setLoading(false);

      // Immediately redirect to Stripe
      redirectToStripe(token, sessionId);

    } catch (error) {
      console.error('Authentication failed:', error);
      setError('Authentication failed. Please try again.');
      setLoading(false);
    }
  };

  const redirectToStripe = async (token, sessionId) => {
    if (redirecting) return;
    
    setRedirecting(true);

    try {
      const response = await fetch('https://us-central1-pingbear-96b4c.cloudfunctions.net/createCheckoutSession', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ token, sessionId }),
      });

      if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`Payment setup failed: ${response.status}`);
      }

      const responseData = await response.json();
      const { url } = responseData;
      
      if (!url) {
        throw new Error('Payment setup failed');
      }
      
      // Redirect to Stripe Checkout
      window.location.href = url;

    } catch (error) {
      console.error('Checkout error:', error);
      setError('Failed to start payment. Please try again.');
      setRedirecting(false);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center p-4" style={{backgroundColor: '#10183C'}}>
          <div className="relative w-14 h-14 mx-auto mb-6">
            <div className="absolute inset-0 border-4 border-white border-opacity-20 rounded-full"></div>
            <div className="absolute inset-0 border-4 border-white border-t-transparent rounded-full animate-spin"></div>
          </div>
      </div>
    );
  }

  if (!authenticated) {
    return (
      <div className="min-h-screen flex items-center justify-center p-4" style={{backgroundColor: '#10183C'}}>
        <div className="backdrop-blur-sm border border-white border-opacity-10 rounded-2xl p-8 max-w-sm w-full text-center" style={{backgroundColor: '#1A2245'}}>
          <h1 className="text-white text-2xl font-bold mb-4">Access Denied</h1>
          <p className="text-white text-opacity-80 leading-relaxed">{error}</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen flex items-center justify-center p-4" style={{backgroundColor: '#10183C'}}>
      <div className="backdrop-blur-sm border border-white border-opacity-10 rounded-2xl p-8 max-w-sm w-full text-center" style={{backgroundColor: '#1A2245'}}>
        <div className="text-center">
          <div className="relative w-14 h-14 mx-auto mb-6">
            <div className="absolute inset-0 border-4 border-white border-opacity-20 rounded-full"></div>
            <div className="absolute inset-0 border-4 border-white border-t-transparent rounded-full animate-spin"></div>
          </div>
          
          <div className="text-white text-opacity-80 mb-6">
            Redirecting to secure payment...
          </div>
          
          <button
            onClick={() => redirectToStripe(userInfo?.token, userInfo?.sessionId)}
            className="w-full text-white py-3 px-6 rounded-full font-semibold transition-all duration-200 transform hover:scale-105 disabled:opacity-50 disabled:transform-none"
            style={{backgroundColor: '#4169E1'}}
            disabled={redirecting}
          >
            {redirecting ? 'Redirecting...' : 'Continue to Payment'}
          </button>
        </div>
      </div>
    </div>
  );
}

// Success Page Component
function SuccessPage() {

  return (
    <div className="min-h-screen flex items-center justify-center p-4" style={{backgroundColor: '#10183C'}}>
      <div className="backdrop-blur-sm border border-white border-opacity-10 rounded-2xl p-8 max-w-sm w-full text-center" style={{backgroundColor: '#1A2245'}}>
        <h1 className="text-white text-2xl font-bold mb-4">Purchase Complete!</h1>
        <p className="text-white text-opacity-80 leading-relaxed">
          Your coins have been added to your balance. Return to the app to continue.
        </p>
      </div>
    </div>
  );
}

// Cancel Page Component
function CancelPage() {
  return (
    <div className="min-h-screen flex items-center justify-center p-4" style={{backgroundColor: '#10183C'}}>
      <div className="backdrop-blur-sm border border-white border-opacity-10 rounded-2xl p-8 max-w-sm w-full text-center" style={{backgroundColor: '#1A2245'}}>
        <h1 className="text-white text-3xl font-bold mb-4">Purchase Cancelled</h1>
        <p className="text-white text-opacity-80 leading-relaxed">
          Your purchase was cancelled. No charges were made to your account.
        </p>
      </div>
    </div>
  );
}

// Error Page Component
function ErrorPage() {
  return (
    <div className="min-h-screen flex items-center justify-center p-4" style={{backgroundColor: '#10183C'}}>
      <div className="backdrop-blur-sm border border-white border-opacity-10 rounded-2xl p-8 max-w-sm w-full text-center" style={{backgroundColor: '#1A2245'}}>
        <h1 className="text-white text-3xl font-bold mb-4">Invalid Access</h1>
        <p className="text-white text-opacity-80 leading-relaxed">
          This page can only be accessed from the app. Please return to the app and try again.
        </p>
      </div>
    </div>
  );
}

// Initialize React app
const container = document.getElementById('root');
const root = createRoot(container);
root.render(<App />);