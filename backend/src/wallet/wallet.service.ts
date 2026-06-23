/**
 * Wallet Service — manages user balance and transaction history.
 *
 * MONEY HANDLING RULES:
 * ─────────────────────
 * 1. ALL monetary values stored as CENTS (integers, never decimals)
 *    ₹50.00 → stored as 5000 cents
 *    WHY? Floating point math is broken: 0.1 + 0.2 = 0.30000000000000004
 *    Integers never have this problem.
 *
 * 2. Available balance = balanceCents - heldAmountCents
 *    heldAmountCents = sum of pending withdrawal holds
 *    This prevents spending money that's already earmarked for withdrawal.
 *
 * 3. All balance changes happen inside database TRANSACTIONS
 *    (not to be confused with financial "transactions" which are records of changes)
 *    A database transaction ensures: either ALL changes succeed, or NONE do.
 */

import { prisma } from '../common/prisma';
import { notFoundError } from '../common/errors';
import { sendNotification } from '../notification/notification.service';

// ─── Get Balance ─────────────────────────────────────────────────────────────

/**
 * Get the current wallet balance for a user.
 *
 * Returns:
 * - balanceCents: total wallet balance
 * - heldAmountCents: amount reserved for pending withdrawals
 * - availableBalanceCents: what the user can actually spend (balance - held)
 *
 * WHY return all three?
 * The user needs to know: "I have ₹500 but ₹200 is locked for a pending withdrawal,
 * so I can only spend ₹300 on tickets."
 */
export async function getWalletBalance(userId: string) {
  // Find the wallet for this user
  const wallet = await prisma.wallet.findUnique({
    where: { userId },
  });

  if (!wallet) {
    throw notFoundError('Wallet');
  }

  // Convert BigInt to Number for JSON serialization
  const balanceCents = Number(wallet.balanceCents);
  const heldAmountCents = Number(wallet.heldAmountCents);

  return {
    balanceCents,
    heldAmountCents,
    availableBalanceCents: balanceCents - heldAmountCents,
    updatedAt: wallet.updatedAt.toISOString(),
  };
}

// ─── Transaction History ─────────────────────────────────────────────────────

/**
 * Get paginated transaction history for a user.
 *
 * PAGINATION explained:
 * If a user has 500 transactions, sending ALL of them in one response is:
 * - Slow (large JSON payload)
 * - Wasteful (user only sees 20 at a time on screen)
 * - Memory-heavy (client parses 500 objects)
 *
 * Instead, we send "pages":
 * - Page 1: transactions 1-20
 * - Page 2: transactions 21-40
 * - etc.
 *
 * Client sends: GET /api/wallet/transactions?page=1&pageSize=20
 * Server returns: { transactions: [...20 items...], total: 500, page: 1, pageSize: 20 }
 * Client calculates: totalPages = Math.ceil(500 / 20) = 25
 *
 * Prisma implements this with:
 * - skip: (page - 1) * pageSize  → how many to skip from the start
 * - take: pageSize               → how many to return
 *
 * Example for page 3, pageSize 20:
 * - skip: (3-1) * 20 = 40  → skip first 40
 * - take: 20                → return the next 20
 */
export async function getTransactionHistory(
  userId: string,
  page: number = 1,
  pageSize: number = 20,
) {
  // First, find the user's wallet ID
  const wallet = await prisma.wallet.findUnique({
    where: { userId },
    select: { id: true },
  });

  if (!wallet) {
    throw notFoundError('Wallet');
  }

  // Run both queries in parallel (faster than sequential)
  // Promise.all() runs multiple async operations simultaneously
  const [transactions, total] = await Promise.all([
    // Query 1: Get the page of transactions
    prisma.transaction.findMany({
      where: { walletId: wallet.id },
      orderBy: { createdAt: 'desc' }, // Newest first
      skip: (page - 1) * pageSize,
      take: pageSize,
    }),
    // Query 2: Count total transactions (for pagination metadata)
    prisma.transaction.count({
      where: { walletId: wallet.id },
    }),
  ]);

  // Format the response
  return {
    transactions: transactions.map((tx) => ({
      id: tx.id,
      type: tx.type,
      amountCents: Number(tx.amountCents), // BigInt → Number
      referenceId: tx.referenceId,
      referenceType: tx.referenceType,
      createdAt: tx.createdAt.toISOString(),
    })),
    pagination: {
      page,
      pageSize,
      total,
      totalPages: Math.ceil(total / pageSize),
    },
  };
}

// ─── Top-Up ──────────────────────────────────────────────────────────────────

import { validateTopUpAmount, validateWithdrawalAmount } from '../common/validators';
import { validationError } from '../common/errors';
import { paymentGateway } from './payment-gateway';

/**
 * Top up the user's wallet.
 *
 * FLOW:
 * 1. Validate amount (1-100,000 cents)
 * 2. Process payment via gateway (mock: always succeeds)
 * 3. Credit wallet balance (atomic DB transaction)
 * 4. Record transaction in history
 *
 * WHY a database transaction (prisma.$transaction)?
 * We need TWO operations to succeed together:
 * - Update wallet balance (+amount)
 * - Create transaction record
 * If the transaction record fails, we DON'T want the balance to change.
 * $transaction ensures: both succeed or both rollback.
 */
export async function topUpWallet(userId: string, amountCents: number) {
  // Step 1: Validate
  const validation = validateTopUpAmount(amountCents);
  if (!validation.valid) {
    throw validationError('Invalid top-up amount', validation.errors);
  }

  // Step 2: Process payment (mock gateway)
  const paymentResult = await paymentGateway.processTopUp(amountCents, userId);
  if (!paymentResult.success) {
    throw validationError('Payment failed', { payment: paymentResult.message });
  }

  // Step 3 & 4: Credit wallet + record transaction (atomically)
  const wallet = await prisma.$transaction(async (tx) => {
    // Update balance
    const updatedWallet = await tx.wallet.update({
      where: { userId },
      data: {
        balanceCents: { increment: BigInt(amountCents) },
      },
    });

    // Record the transaction
    await tx.transaction.create({
      data: {
        walletId: updatedWallet.id,
        type: 'top_up',
        amountCents: BigInt(amountCents),
        referenceId: paymentResult.transactionId,
        referenceType: 'payment_gateway',
      },
    });

    return updatedWallet;
  });

  // Send notification for top-up
  try {
    await sendNotification({
      userId,
      type: 'winnings_credited',
      title: '💰 Wallet Credited',
      body: `Successfully credited ₹${(amountCents / 100).toFixed(2)} to your wallet. Ref: ${paymentResult.transactionId}`,
      data: { amountCents, referenceId: paymentResult.transactionId },
    });
  } catch (err) {
    console.error('[Notification Error] Failed to send topup notification:', err);
  }

  return {
    balanceCents: Number(wallet.balanceCents),
    amountCredited: amountCents,
    paymentReference: paymentResult.transactionId,
  };
}

// ─── Withdrawal ──────────────────────────────────────────────────────────────

/**
 * Request a withdrawal from the wallet.
 *
 * FLOW:
 * 1. Validate amount (100-50,000 cents)
 * 2. Check available balance (balance - already held amounts)
 * 3. Place a HOLD on the amount (not deducted yet, just reserved)
 * 4. Create withdrawal request record
 *
 * WHY a "hold" instead of immediate deduction?
 * - Withdrawal needs admin approval (takes time)
 * - If we deducted immediately and then rejected, we'd need complex reversal logic
 * - With a hold: money is reserved, user can't spend it, but it's not gone yet
 * - On approval: hold is released and money is actually sent
 * - On rejection: hold is released back to available balance
 */
export async function requestWithdrawal(
  userId: string,
  amountCents: number,
  paymentDestination: string,
) {
  // Step 1: Validate amount
  const validation = validateWithdrawalAmount(amountCents);
  if (!validation.valid) {
    throw validationError('Invalid withdrawal amount', validation.errors);
  }

  if (!paymentDestination || paymentDestination.trim().length === 0) {
    throw validationError('Payment destination is required', {
      paymentDestination: 'Payment destination is required',
    });
  }

  // Step 2: Check available balance
  const wallet = await prisma.wallet.findUnique({ where: { userId } });
  if (!wallet) {
    throw notFoundError('Wallet');
  }

  const availableBalance = Number(wallet.balanceCents) - Number(wallet.heldAmountCents);
  if (amountCents > availableBalance) {
    throw validationError('Insufficient balance', {
      amount: `Available balance is ${availableBalance} cents, requested ${amountCents}`,
    });
  }

  // Step 3 & 4: Place hold + create withdrawal record (atomically)
  const withdrawal = await prisma.$transaction(async (tx) => {
    // Increase held amount (reserves the money)
    await tx.wallet.update({
      where: { userId },
      data: {
        heldAmountCents: { increment: BigInt(amountCents) },
      },
    });

    // Create withdrawal request (starts as 'pending')
    const request = await tx.withdrawalRequest.create({
      data: {
        userId,
        amountCents: BigInt(amountCents),
        paymentDestination,
        status: 'pending',
      },
    });

    // Record hold transaction
    await tx.transaction.create({
      data: {
        walletId: wallet.id,
        type: 'withdrawal_hold',
        amountCents: BigInt(amountCents),
        referenceId: request.id,
        referenceType: 'withdrawal_request',
      },
    });

    return request;
  });

  // Send notification for withdrawal requested
  try {
    await sendNotification({
      userId,
      type: 'system_message',
      title: '💸 Withdrawal Requested',
      body: `Your request to withdraw ₹${(amountCents / 100).toFixed(2)} has been submitted and is pending review.`,
      data: { withdrawalId: withdrawal.id, amountCents },
    });
  } catch (err) {
    console.error('[Notification Error] Failed to send withdrawal request notification:', err);
  }

  return {
    withdrawalId: withdrawal.id,
    amountCents: Number(withdrawal.amountCents),
    status: withdrawal.status,
    paymentDestination: withdrawal.paymentDestination,
    createdAt: withdrawal.createdAt.toISOString(),
  };
}

/**
 * Approve a pending withdrawal request (admin only).
 */
export async function approveWithdrawal(withdrawalId: string) {
  const request = await prisma.withdrawalRequest.findUnique({
    where: { id: withdrawalId },
  });

  if (!request) {
    throw notFoundError('WithdrawalRequest');
  }

  if (request.status !== 'pending') {
    throw validationError('Invalid withdrawal state', {
      status: `Withdrawal request is already ${request.status}`,
    });
  }

  const amountCents = request.amountCents;
  const userId = request.userId;

  // Find user's wallet
  const wallet = await prisma.wallet.findUnique({
    where: { userId },
  });

  if (!wallet) {
    throw notFoundError('Wallet');
  }

  // Release hold and deduct balance atomically
  await prisma.$transaction(async (tx) => {
    await tx.wallet.update({
      where: { userId },
      data: {
        balanceCents: { decrement: amountCents },
        heldAmountCents: { decrement: amountCents },
      },
    });

    await tx.withdrawalRequest.update({
      where: { id: withdrawalId },
      data: {
        status: 'approved',
        processedAt: new Date(),
      },
    });

    await tx.transaction.create({
      data: {
        walletId: wallet.id,
        type: 'withdrawal',
        amountCents: amountCents,
        referenceId: withdrawalId,
        referenceType: 'withdrawal_request',
      },
    });
  });

  // Send notification to user
  try {
    await sendNotification({
      userId,
      type: 'withdrawal_approved',
      title: '💸 Withdrawal Approved',
      body: `Your withdrawal of ₹${(Number(amountCents) / 100).toFixed(2)} has been approved and processed successfully.`,
      data: { withdrawalId, amountCents: Number(amountCents) },
    });
  } catch (err) {
    console.error('[Notification Error] Failed to send withdrawal approval notification:', err);
  }

  return { withdrawalId, status: 'approved' };
}

/**
 * Reject a pending withdrawal request (admin only).
 */
export async function rejectWithdrawal(withdrawalId: string, reason?: string) {
  const request = await prisma.withdrawalRequest.findUnique({
    where: { id: withdrawalId },
  });

  if (!request) {
    throw notFoundError('WithdrawalRequest');
  }

  if (request.status !== 'pending') {
    throw validationError('Invalid withdrawal state', {
      status: `Withdrawal request is already ${request.status}`,
    });
  }

  const amountCents = request.amountCents;
  const userId = request.userId;

  // Find user's wallet
  const wallet = await prisma.wallet.findUnique({
    where: { userId },
  });

  if (!wallet) {
    throw notFoundError('Wallet');
  }

  // Release hold (no balance deduction) atomically
  await prisma.$transaction(async (tx) => {
    await tx.wallet.update({
      where: { userId },
      data: {
        heldAmountCents: { decrement: amountCents },
      },
    });

    await tx.withdrawalRequest.update({
      where: { id: withdrawalId },
      data: {
        status: 'rejected',
        rejectionReason: reason || 'Rejected by administrator',
        processedAt: new Date(),
      },
    });

    await tx.transaction.create({
      data: {
        walletId: wallet.id,
        type: 'withdrawal_release',
        amountCents: amountCents,
        referenceId: withdrawalId,
        referenceType: 'withdrawal_request',
      },
    });
  });

  // Send notification to user
  try {
    await sendNotification({
      userId,
      type: 'withdrawal_rejected',
      title: '❌ Withdrawal Rejected',
      body: `Your withdrawal request of ₹${(Number(amountCents) / 100).toFixed(2)} was rejected. Reason: ${reason || 'Rejected by administrator'}`,
      data: { withdrawalId, amountCents: Number(amountCents), reason },
    });
  } catch (err) {
    console.error('[Notification Error] Failed to send withdrawal rejection notification:', err);
  }

  return { withdrawalId, status: 'rejected' };
}

