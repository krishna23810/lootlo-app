import {
  Admin,
  AdminAuthToken,
  AdminRole,
  AuthToken,
  ClaimResult,
  CreateGameParams,
  DetectedPattern,
  DrawEvent,
  Game,
  GameResults,
  GameState,
  Pagination,
  PaymentDestination,
  PaymentMethod,
  Ticket,
  Ticket3x9Grid,
  TopUpResult,
  Transaction,
  TransactionRef,
  User,
  WinningPattern,
  WithdrawalRequest,
} from './types';

// ========================
// Auth Service
// ========================

export interface IAuthService {
  /**
   * Register a new user with email, mobile, password, and display name.
   * Returns an auth token on success.
   */
  register(email: string, mobile: string, password: string, displayName: string): Promise<AuthToken>;

  /**
   * Authenticate a user with email and password.
   * Returns a session token with 24-hour expiry.
   */
  login(email: string, password: string): Promise<AuthToken>;

  /**
   * Invalidate the given session token.
   */
  logout(token: string): Promise<void>;

  /**
   * Validate a session token and return the associated user, or null if invalid/expired.
   */
  validateToken(token: string): Promise<User | null>;

  /**
   * Check if the account associated with the given email is currently locked
   * due to excessive failed login attempts.
   */
  isAccountLocked(email: string): Promise<boolean>;
}

// ========================
// Game Service
// ========================

export interface IGameService {
  /**
   * Create a new game with the given parameters.
   * Start time must be at least 30 minutes in the future.
   */
  createGame(params: CreateGameParams): Promise<Game>;

  /**
   * List all upcoming games sorted by scheduled start time (earliest first).
   */
  listUpcoming(): Promise<Game[]>;

  /**
   * Retrieve a specific game by ID.
   */
  getGame(id: string): Promise<Game>;

  /**
   * Transition the game to a new state.
   * Valid transitions: upcoming → live → completed/cancelled.
   */
  transitionState(id: string, newState: GameState): Promise<Game>;

  /**
   * Get results for a completed game including draw sequence and winners.
   */
  getResults(id: string): Promise<GameResults>;
}

// ========================
// Ticket Service
// ========================

export interface ITicketService {
  /**
   * Purchase a ticket for a game. Atomically deducts wallet balance,
   * issues ticket, and adds to prize pool.
   */
  purchaseTicket(userId: string, gameId: string): Promise<Ticket>;

  /**
   * Generate a valid 3×9 Housie ticket grid following standard rules.
   */
  generateTicket(): Ticket3x9Grid;

  /**
   * Get all tickets for a user, optionally filtered by game.
   */
  getUserTickets(userId: string, gameId?: string): Promise<Ticket[]>;

  /**
   * Validate that a ticket grid satisfies all structural rules.
   */
  validateTicketGrid(grid: number[][]): boolean;
}

// ========================
// Wallet Service
// ========================

export interface IWalletService {
  /**
   * Get the current wallet balance (in cents) for a user.
   */
  getBalance(userId: string): Promise<number>;

  /**
   * Credit an amount to the user's wallet with a transaction reference.
   */
  credit(userId: string, amount: number, reference: TransactionRef): Promise<void>;

  /**
   * Debit an amount from the user's wallet with a transaction reference.
   */
  debit(userId: string, amount: number, reference: TransactionRef): Promise<void>;

  /**
   * Initiate a wallet top-up via payment gateway.
   * Amount must be between 1 and 100,000 inclusive.
   */
  initiateTopUp(userId: string, amount: number, method: PaymentMethod): Promise<TopUpResult>;

  /**
   * Submit a withdrawal request. Amount must be between 100 and 50,000.
   * Destination must be previously verified.
   */
  requestWithdrawal(
    userId: string,
    amount: number,
    destination: PaymentDestination,
  ): Promise<WithdrawalRequest>;

  /**
   * Get paginated transaction history for a user in reverse chronological order.
   */
  getTransactions(userId: string, pagination: Pagination): Promise<Transaction[]>;
}

// ========================
// Draw Service
// ========================

export interface IDrawService {
  /**
   * Start a live draw session for a game.
   */
  startSession(gameId: string): Promise<void>;

  /**
   * Input a drawn number into the game. Validates range (1-90) and uniqueness.
   * Broadcasts to all connected participants.
   */
  inputNumber(gameId: string, number: number): Promise<DrawEvent>;

  /**
   * Get all numbers drawn so far in a game, in draw order.
   */
  getDrawnNumbers(gameId: string): Promise<number[]>;

  /**
   * Submit a winning pattern claim for validation.
   */
  submitClaim(
    userId: string,
    gameId: string,
    ticketId: string,
    pattern: WinningPattern,
  ): Promise<ClaimResult>;

  /**
   * End the draw session and calculate final results.
   */
  endSession(gameId: string): Promise<GameResults>;
}

// ========================
// Pattern Detector
// ========================

export interface IPatternDetector {
  /**
   * Evaluate a ticket against drawn numbers and return all completed patterns.
   */
  evaluate(ticket: Ticket3x9Grid, drawnNumbers: number[]): DetectedPattern[];

  /**
   * Validate a specific claim: check that the pattern is complete given
   * the ticket grid and drawn numbers.
   */
  validateClaim(
    ticket: Ticket3x9Grid,
    drawnNumbers: number[],
    pattern: WinningPattern,
  ): boolean;
}

// ========================
// Admin Service
// ========================

export interface IAdminService {
  /**
   * Authenticate an admin with email and password.
   */
  login(email: string, password: string): Promise<AdminAuthToken>;

  /**
   * Create a new admin account (super_admin only).
   */
  createAdmin(email: string, password: string, name: string, role: AdminRole): Promise<Admin>;

  /**
   * List all admin accounts.
   */
  listAdmins(): Promise<Admin[]>;

  /**
   * Deactivate an admin account.
   */
  deactivateAdmin(adminId: string): Promise<void>;

  /**
   * Get dashboard stats: total users, active games, revenue, etc.
   */
  getDashboardStats(): Promise<DashboardStats>;

  /**
   * List all users with pagination and optional search.
   */
  listUsers(pagination: Pagination, search?: string): Promise<{ users: User[]; total: number }>;

  /**
   * Approve or reject a withdrawal request.
   */
  processWithdrawal(
    withdrawalId: string,
    action: 'approve' | 'reject',
    reason?: string,
  ): Promise<WithdrawalRequest>;

  /**
   * Get all pending withdrawal requests.
   */
  getPendingWithdrawals(pagination: Pagination): Promise<{ withdrawals: WithdrawalRequest[]; total: number }>;
}

// ========================
// Dashboard Stats
// ========================

export interface DashboardStats {
  totalUsers: number;
  activeGames: number;
  totalGamesPlayed: number;
  totalRevenueCents: number;
  pendingWithdrawals: number;
  totalTicketsSold: number;
}
