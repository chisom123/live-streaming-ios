const PaymentProvider = require('./PaymentProvider');

class PayPalProvider extends PaymentProvider {

  constructor({ clientId, clientSecret, environment = 'sandbox' }) {
    super();
    this.clientId     = clientId;
    this.clientSecret = clientSecret;
    this.baseUrl      = environment === 'live'
      ? 'https://api-m.paypal.com'
      : 'https://api-m.sandbox.paypal.com';
  }

  // ── Get OAuth token ───────────────────────────────────────

  async getAccessToken() {
    const credentials = Buffer.from(`${this.clientId}:${this.clientSecret}`).toString('base64');
    const res = await fetch(`${this.baseUrl}/v1/oauth2/token`, {
      method: 'POST',
      headers: {
        'Authorization': `Basic ${credentials}`,
        'Content-Type':  'application/x-www-form-urlencoded'
      },
      body: 'grant_type=client_credentials'
    });
    const data = await res.json();
    if (!data.access_token) throw new Error('Failed to get PayPal access token');
    return data.access_token;
  }

  // ── Create a top-up session (PayPal order) ────────────────

  async createTopUpSession({ userId, amount, currency, returnUrl, idempotencyKey }) {
    const token = await this.getAccessToken();

    const res = await fetch(`${this.baseUrl}/v2/checkout/orders`, {
      method: 'POST',
      headers: {
        'Authorization':     `Bearer ${token}`,
        'Content-Type':      'application/json',
        'PayPal-Request-Id': idempotencyKey
      },
      body: JSON.stringify({
        intent: 'CAPTURE',
        payment_source: {
          apple_pay: {
            experience_context: {
              return_url: returnUrl,
              cancel_url: returnUrl + '?cancelled=true'
            }
          }
        },
        purchase_units: [{
          custom_id:   userId,
          description: 'Wallet top-up',
          amount: {
            currency_code: currency,
            value:         amount.toFixed(2)
          }
        }]
      })
    });

    const order = await res.json();
    if (!order.id) throw new Error(`PayPal order creation failed: ${JSON.stringify(order)}`);

    return {
      sessionToken: order.id,   // PayPal order ID
      checkoutUrl:  order.id    // Not used in native flow — SDK uses the order ID directly
    };
  }

  // ── Capture a PayPal order after Apple Pay approval ───────

  async captureOrder(orderId) {
    const token = await this.getAccessToken();

    const res = await fetch(`${this.baseUrl}/v2/checkout/orders/${orderId}/capture`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type':  'application/json'
      }
    });

    const data = await res.json();
    if (data.status !== 'COMPLETED') {
      throw new Error(`PayPal capture failed: ${JSON.stringify(data)}`);
    }

    const unit   = data.purchase_units[0];
    const capture = unit.payments.captures[0];

    return {
      success:  true,
      orderId:  data.id,
      amount:   parseFloat(capture.amount.value),
      currency: capture.amount.currency_code,
      userId:   unit.custom_id
    };
  }

  // ── Verify webhook signature ──────────────────────────────

  verifyWebhook({ payload, signature, secret }) {
    // PayPal webhook verification requires a separate API call
    // For now returns true — add full verification before going live
    // See: https://developer.paypal.com/api/rest/webhooks/
    return true;
  }

  // ── Parse webhook event ───────────────────────────────────

  parseWebhookEvent({ payload }) {
    if (payload.event_type === 'PAYMENT.CAPTURE.COMPLETED') {
      const resource = payload.resource;
      return {
        type:     'PAYMENT_SUCCESS',
        userId:   resource.custom_id,
        amount:   parseFloat(resource.amount.value),
        currency: resource.amount.currency_code,
        orderId:  resource.id
      };
    }

    if (payload.event_type === 'PAYMENT.CAPTURE.DENIED') {
      return { type: 'PAYMENT_CANCELLED', orderId: payload.resource?.id };
    }

    return { type: 'UNKNOWN' };
  }

  // ── Send payout (withdrawal) ──────────────────────────────

  async createPayout({ userId, amount, currency, destination }) {
    const token = await this.getAccessToken();

    const res = await fetch(`${this.baseUrl}/v1/payments/payouts`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type':  'application/json'
      },
      body: JSON.stringify({
        sender_batch_header: {
          sender_batch_id: `payout_${userId}_${Date.now()}`,
          email_subject:   'Your Pingbear withdrawal',
          email_message:   'Your withdrawal has been processed.'
        },
        items: [{
          recipient_type: 'EMAIL',
          amount: {
            value:         amount.toFixed(2),
            currency
          },
          receiver:  destination.email,
          note:      'Pingbear wallet withdrawal',
          sender_item_id: `${userId}_${Date.now()}`
        }]
      })
    });

    const data = await res.json();
    if (!data.batch_header?.payout_batch_id) {
      throw new Error(`PayPal payout failed: ${JSON.stringify(data)}`);
    }

    return {
      success:   true,
      reference: data.batch_header.payout_batch_id
    };
  }
}

module.exports = PayPalProvider;
