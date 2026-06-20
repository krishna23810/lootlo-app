/**
 * Payment Gateway — abstraction over payment providers.
 *
 * STRATEGY PATTERN:
 * ─────────────────
 * We define an INTERFACE (shape), then create implementations.
 * The rest of the code only knows about the interface — not the implementation.
 *
 * Today:  MockPaymentGateway (always succeeds, for development)
 * Later:  RazorpayGateway, StripeGateway, etc. (real payment processing)
 *
 * To switch: just change which implementation is exported at the bottom.
 * NO other file needs to change. This is the power of interfaces.
 */

import { v4 as uuid } from 'uuid';

// ─── Interface (the contract) ────────────────────────────────────────────────

export interface PaymentResult {
  success: boolean;
  transactionId: string;
  message: string;
}

export interface IPaymentGateway {
  /** Process a top-up payment */
  processTopUp(amount: number, userId: string): Promise<PaymentResult>;

  /** Process a withdrawal payout */
  processWithdrawal(amount: number, destination: string): Promise<PaymentResult>;
}

// ─── Mock Implementation ─────────────────────────────────────────────────────

/**
 * Mock Payment Gateway — always succeeds.
 * Use this during development when you don't have a real payment provider.
 *
 * Simulates a 500ms delay to mimic network latency.
 * In production, replace this with RazorpayGateway or similar.
 */
class MockPaymentGateway implements IPaymentGateway {
  async processTopUp(amount: number, _userId: string): Promise<PaymentResult> {
    // Simulate network delay (real payment takes 1-3 seconds)
    await new Promise((resolve) => setTimeout(resolve, 500));

    return {
      success: true,
      transactionId: `mock_topup_${uuid()}`,
      message: `Successfully processed top-up of ${amount} cents`,
    };
  }

  async processWithdrawal(amount: number, destination: string): Promise<PaymentResult> {
    await new Promise((resolve) => setTimeout(resolve, 500));

    return {
      success: true,
      transactionId: `mock_withdrawal_${uuid()}`,
      message: `Withdrawal of ${amount} cents to ${destination} initiated`,
    };
  }
}

// ─── Export the active implementation ────────────────────────────────────────
// When you integrate Razorpay, change this one line:
// export const paymentGateway: IPaymentGateway = new RazorpayGateway();

export const paymentGateway: IPaymentGateway = new MockPaymentGateway();
