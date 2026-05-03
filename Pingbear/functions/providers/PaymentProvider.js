/**
 * PaymentProvider - Base class for all payment providers
 *
 * Every provider (Rapyd, Cashflows, PayPal etc) must implement
 * these methods. Your Cloud Functions never talk to a provider
 * directly — they always go through this interface.
 *
 * To swap providers: update providers/index.js only.
 * Nothing else in the codebase changes.
 */

class PaymentProvider {

  /**
   * Create a top-up session for a user
   *
   * @param {object} params
   * @param {string} params.userId       - Firebase UID
   * @param {number} params.amount       - Amount in USD (e.g. 10.00)
   * @param {string} params.currency     - Always 'USD'
   * @param {string} params.returnUrl    - Deep link back into the app after payment
   * @param {string} params.idempotencyKey - Unique key to prevent duplicate sessions
   *
   * @returns {Promise<{sessionToken: string, checkoutUrl: string}>}
   */
  async createTopUpSession({ userId, amount, currency, returnUrl, idempotencyKey }) {
    throw new Error('createTopUpSession() not implemented');
  }

  /**
   * Verify that an incoming webhook genuinely came from the provider
   *
   * @param {object} params
   * @param {object} params.payload    - Parsed request body
   * @param {string} params.signature  - Value from the provider's signature header
   * @param {string} params.secret     - Your webhook secret key
   *
   * @returns {boolean}
   */
  verifyWebhook({ payload, signature, secret }) {
    throw new Error('verifyWebhook() not implemented');
  }

  /**
   * Parse a verified webhook payload into a standard event shape
   *
   * Always returns one of:
   *   { type: 'PAYMENT_SUCCESS', userId, amount, currency, orderId }
   *   { type: 'PAYMENT_CANCELLED', userId, orderId }
   *   { type: 'UNKNOWN' }
   *
   * @param {object} params
   * @param {object} params.payload - Parsed request body
   *
   * @returns {{ type: string, userId?: string, amount?: number, currency?: string, orderId?: string }}
   */
  parseWebhookEvent({ payload }) {
    throw new Error('parseWebhookEvent() not implemented');
  }

  /**
   * Send a payout to a user (withdrawal)
   *
   * @param {object} params
   * @param {string} params.userId      - Firebase UID
   * @param {number} params.amount      - Amount in USD
   * @param {string} params.currency    - Always 'USD'
   * @param {object} params.destination - e.g. { method: 'paypal', email: 'user@example.com' }
   *
   * @returns {Promise<{success: boolean, reference: string}>}
   */
  async createPayout({ userId, amount, currency, destination }) {
    throw new Error('createPayout() not implemented');
  }
}

module.exports = PaymentProvider;
