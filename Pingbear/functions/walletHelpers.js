/**
 * walletHelpers.js
 *
 * Shared helpers for bonus-vs-real balance accounting.
 * Bonus money (from grantWelcomeBonus / seedPromoCredit) is spendable
 * but not withdrawable. It's tracked as a SUBSET of wallet_balance via
 * the bonus_balance field — not a separate pot of money.
 *
 *   wallet_balance  = total spendable balance (existing field)
 *   bonus_balance   = portion of wallet_balance that is non-withdrawable
 *   withdrawable    = wallet_balance - bonus_balance
 *
 * Every debit spends bonus money first (see splitDebit). When bonus
 * money is paid out to a creator, it becomes ordinary real money for
 * them — payCreator never touches the recipient's bonus_balance.
 */

function round2(n) {
  return parseFloat(n.toFixed(2));
}

// Bonus is always spent first. Returns how much of `debitAmount`
// comes out of bonus vs real money, given the user's current
// bonus_balance.
function splitDebit(currentBonusBalance, debitAmount) {
  const bonusUsed = round2(Math.min(currentBonusBalance, debitAmount));
  const realUsed  = round2(debitAmount - bonusUsed);
  return { bonusUsed, realUsed };
}

function withdrawableAmount(walletBalance, bonusBalance) {
  return round2(Math.max(0, walletBalance - bonusBalance));
}

module.exports = { round2, splitDebit, withdrawableAmount };
