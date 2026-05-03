/**
 * providers/index.js
 *
 * THE ONLY FILE YOU CHANGE TO SWAP PAYMENT PROVIDERS.
 *
 * To go live with Rapyd:
 *   const RapydProvider = require('./RapydProvider');
 *   module.exports = new RapydProvider({ ... });
 *
 * To go live with Cashflows:
 *   const CashflowsProvider = require('./CashflowsProvider');
 *   module.exports = new CashflowsProvider({ ... });
 *
 * Nothing else in the codebase changes.
 */

const MockProvider = require('./MockProvider');
const PayPalProvider = require('./PayPalProvider');

// ── Toggle this to switch providers ──────────────────────────
const USE_PAYPAL = true; // set to true once PayPal is provisioned

const provider = USE_PAYPAL
  ? new PayPalProvider({
      clientId:     process.env.PAYPAL_CLIENT_ID,
      clientSecret: process.env.PAYPAL_CLIENT_SECRET,
      environment:  process.env.PAYPAL_ENV || 'sandbox'
    })
  : new MockProvider();

module.exports = provider;
