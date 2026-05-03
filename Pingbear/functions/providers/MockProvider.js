/**
 * MockProvider - Development/testing payment provider
 *
 * Simulates a real provider so you can build and test the entire
 * wallet system without a live payment processor.
 *
 * Top-up flow: returns a fake checkout URL that deep-links straight
 * back into the app — no real payment page opened.
 *
 * Webhook simulation: call the simulateTopUp Cloud Function from
 * your Swift app during development to credit a user's balance
 * instantly without going through a real checkout.
 *
 * Swap to a real provider: update providers/index.js only.
 */

const PaymentProvider = require('./PaymentProvider');

class MockProvider extends PaymentProvider {

  async createTopUpSession({ userId, amount, currency, returnUrl, idempotencyKey }) {
    // In dev, return a fake token and a URL that immediately redirects
    // back to the app as if payment succeeded. The simulateTopUp function
    // handles the actual balance credit during development.
    const sessionToken = `mock_${idempotencyKey}_${Date.now()}`;
    const checkoutUrl = `${returnUrl}?mock=true&amount=${amount}&token=${sessionToken}`;

    return {
      sessionToken,
      checkoutUrl
    };
  }

  verifyWebhook({ payload, signature, secret }) {
    // In dev, always trust incoming webhooks
    // Real providers verify a signature header here
    return true;
  }

  parseWebhookEvent({ payload }) {
    // Translate mock webhook payload into the standard shape
    // Real providers translate their specific payload format here
    const { notification_type, userId, amount, currency, orderId } = payload;

    if (notification_type === 'mock_payment_success') {
      return {
        type: 'PAYMENT_SUCCESS',
        userId,
        amount: parseFloat(amount),
        currency: currency || 'USD',
        orderId: orderId || `mock_order_${Date.now()}`
      };
    }

    if (notification_type === 'mock_payment_cancelled') {
      return {
        type: 'PAYMENT_CANCELLED',
        userId,
        orderId
      };
    }

    return { type: 'UNKNOWN' };
  }

  async createPayout({ userId, amount, currency, destination }) {
    // Simulate a successful payout
    // Real providers call their API here (PayPal, Rapyd etc)
    const reference = `mock_payout_${userId}_${Date.now()}`;

    console.log(`[MockProvider] Simulated payout: $${amount} ${currency} to ${destination.email} (ref: ${reference})`);

    return {
      success: true,
      reference
    };
  }
}

module.exports = MockProvider;