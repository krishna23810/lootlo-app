// ========================
// Enums
// ========================

export enum GameState {
  UPCOMING = 'upcoming',
  LIVE = 'live',
  COMPLETED = 'completed',
  CANCELLED = 'cancelled',
}

export enum WinningPattern {
  FULL_HOUSE = 'full_house',
  TOP_LINE = 'top_line',
  MIDDLE_LINE = 'middle_line',
  BOTTOM_LINE = 'bottom_line',
  EARLY_FIVE = 'early_five',
  FOUR_CORNERS = 'four_corners',
}

export enum TransactionType {
  TICKET_PURCHASE = 'ticket_purchase',
  WINNING = 'winning',
  TOP_UP = 'top_up',
  WITHDRAWAL = 'withdrawal',
  WITHDRAWAL_HOLD = 'withdrawal_hold',
  WITHDRAWAL_RELEASE = 'withdrawal_release',
}

export enum WithdrawalStatus {
  PENDING = 'pending',
  APPROVED = 'approved',
  PROCESSING = 'processing',
  COMPLETED = 'completed',
  REJECTED = 'rejected',
}

export enum ClaimStatus {
  PENDING = 'pending',
  VALID = 'valid',
  INVALID = 'invalid',
  ALREADY_CLAIMED = 'already_claimed',
}

export enum AdminRole {
  SUPER_ADMIN = 'super_admin',
  GAME_MANAGER = 'game_manager',
  DRAW_HOST = 'draw_host',
  FINANCE = 'finance',
}

// ========================
// Ticket Grid Types
// ========================

/** A single cell in a Housie ticket: a number (1-90) or null (empty) */
export type TicketCell = number | null;

/** A row in a Housie ticket: exactly 9 cells with 5 numbers and 4 nulls */
export type TicketRow = [
  TicketCell, TicketCell, TicketCell,
  TicketCell, TicketCell, TicketCell,
  TicketCell, TicketCell, TicketCell,
];

/** A complete Housie ticket: 3 rows × 9 columns */
export type Ticket3x9Grid = [TicketRow, TicketRow, TicketRow];

// ========================
// Prize Configuration
// ========================

/** Prize distribution percentages per winning pattern (must sum to 100) */
export interface PrizeConfig {
  [WinningPattern.FULL_HOUSE]: number;
  [WinningPattern.TOP_LINE]: number;
  [WinningPattern.MIDDLE_LINE]: number;
  [WinningPattern.BOTTOM_LINE]: number;
  [WinningPattern.EARLY_FIVE]: number;
  [WinningPattern.FOUR_CORNERS]: number;
}

// ========================
// Entity Types
// ========================

export interface Admin {
  id: string;
  email: string;
  name: string;
  role: AdminRole;
  isActive: boolean;
  createdAt: Date;
  lastLoginAt: Date | null;
}

export interface AdminAuthToken {
  token: string;
  expiresAt: Date;
  admin: Admin;
}

export interface User {
  id: string;
  email: string;
  mobile: string;
  displayName: string;
  failedLoginAttempts: number;
  lockedUntil: Date | null;
  createdAt: Date;
}

export interface AuthToken {
  token: string;
  expiresAt: Date;
  user: User;
}

export interface Wallet {
  id: string;
  userId: string;
  balanceCents: number;
  heldAmountCents: number;
  updatedAt: Date;
}

export interface Transaction {
  id: string;
  walletId: string;
  type: TransactionType;
  amountCents: number;
  referenceId: string;
  referenceType: string;
  createdAt: Date;
}

export interface Game {
  id: string;
  scheduledStartTime: Date;
  ticketPriceCents: number;
  maxTicketCount: number;
  soldTicketCount: number;
  commissionPercentage: number;
  prizePoolCents: number;
  state: GameState;
  prizeConfig: PrizeConfig;
  createdAt: Date;
}

export interface Ticket {
  id: string;
  userId: string;
  gameId: string;
  grid: Ticket3x9Grid;
  purchasedAt: Date;
}

export interface DrawEvent {
  id: string;
  gameId: string;
  number: number;
  position: number;
  drawnAt: Date;
}

export interface WinningClaim {
  id: string;
  gameId: string;
  ticketId: string;
  userId: string;
  pattern: WinningPattern;
  status: ClaimStatus;
  prizeAmountCents: number;
  claimedAtPosition: number;
  createdAt: Date;
}

export interface WithdrawalRequest {
  id: string;
  userId: string;
  amountCents: number;
  paymentDestination: string;
  status: WithdrawalStatus;
  rejectionReason: string | null;
  createdAt: Date;
  processedAt: Date | null;
}

export interface Session {
  id: string;
  userId: string;
  tokenHash: string;
  expiresAt: Date;
  isValid: boolean;
}

// ========================
// Request / Parameter Types
// ========================

export interface CreateGameParams {
  scheduledStartTime: Date;
  ticketPriceCents: number;
  maxTicketCount: number;
  commissionPercentage: number;
  prizeConfig: PrizeConfig;
}

export interface GameResults {
  gameId: string;
  drawSequence: DrawEvent[];
  winners: WinningClaim[];
  totalPrizePoolCents: number;
  commissionCents: number;
}

export interface TransactionRef {
  referenceId: string;
  referenceType: string;
}

export interface Pagination {
  page: number;
  pageSize: number;
}

export interface TopUpResult {
  transactionId: string;
  success: boolean;
  message: string;
}

export interface PaymentMethod {
  type: string;
  details: Record<string, string>;
}

export interface PaymentDestination {
  type: string;
  details: Record<string, string>;
  verified: boolean;
}

export interface ClaimResult {
  claimId: string;
  status: ClaimStatus;
  pattern: WinningPattern;
  prizeAmountCents: number;
  message: string;
}

export interface DetectedPattern {
  pattern: WinningPattern;
  completedAtPosition: number;
}
