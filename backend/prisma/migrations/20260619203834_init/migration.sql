-- CreateEnum
CREATE TYPE "GameState" AS ENUM ('upcoming', 'live', 'completed', 'cancelled');

-- CreateEnum
CREATE TYPE "WinningPattern" AS ENUM ('full_house', 'top_line', 'middle_line', 'bottom_line', 'early_five', 'four_corners');

-- CreateEnum
CREATE TYPE "TransactionType" AS ENUM ('ticket_purchase', 'winning', 'top_up', 'withdrawal', 'withdrawal_hold', 'withdrawal_release');

-- CreateEnum
CREATE TYPE "WithdrawalStatus" AS ENUM ('pending', 'approved', 'processing', 'completed', 'rejected');

-- CreateEnum
CREATE TYPE "ClaimStatus" AS ENUM ('pending', 'valid', 'invalid', 'already_claimed');

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL,
    "email" VARCHAR(254) NOT NULL,
    "mobile" VARCHAR(16) NOT NULL,
    "password_hash" VARCHAR(255) NOT NULL,
    "display_name" VARCHAR(30) NOT NULL,
    "failed_login_attempts" INTEGER NOT NULL DEFAULT 0,
    "locked_until" TIMESTAMPTZ,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "wallets" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "balance_cents" BIGINT NOT NULL DEFAULT 0,
    "held_amount_cents" BIGINT NOT NULL DEFAULT 0,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "wallets_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "transactions" (
    "id" UUID NOT NULL,
    "wallet_id" UUID NOT NULL,
    "type" "TransactionType" NOT NULL,
    "amount_cents" BIGINT NOT NULL,
    "reference_id" VARCHAR(255) NOT NULL,
    "reference_type" VARCHAR(50) NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "transactions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "games" (
    "id" UUID NOT NULL,
    "scheduled_start_time" TIMESTAMPTZ NOT NULL,
    "ticket_price_cents" INTEGER NOT NULL,
    "max_ticket_count" INTEGER NOT NULL,
    "sold_ticket_count" INTEGER NOT NULL DEFAULT 0,
    "commission_percentage" INTEGER NOT NULL,
    "prize_pool_cents" BIGINT NOT NULL DEFAULT 0,
    "state" "GameState" NOT NULL DEFAULT 'upcoming',
    "prize_config" JSONB NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "games_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "tickets" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "game_id" UUID NOT NULL,
    "grid" JSONB NOT NULL,
    "purchased_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "tickets_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "draw_events" (
    "id" UUID NOT NULL,
    "game_id" UUID NOT NULL,
    "number" INTEGER NOT NULL,
    "position" INTEGER NOT NULL,
    "drawn_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "draw_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "winning_claims" (
    "id" UUID NOT NULL,
    "game_id" UUID NOT NULL,
    "ticket_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "pattern" "WinningPattern" NOT NULL,
    "status" "ClaimStatus" NOT NULL DEFAULT 'pending',
    "prize_amount_cents" BIGINT NOT NULL DEFAULT 0,
    "claimed_at_position" INTEGER NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "winning_claims_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "withdrawal_requests" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "amount_cents" BIGINT NOT NULL,
    "payment_destination" VARCHAR(500) NOT NULL,
    "status" "WithdrawalStatus" NOT NULL DEFAULT 'pending',
    "rejection_reason" TEXT,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "processed_at" TIMESTAMPTZ,

    CONSTRAINT "withdrawal_requests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sessions" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "token_hash" VARCHAR(255) NOT NULL,
    "expires_at" TIMESTAMPTZ NOT NULL,
    "is_valid" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "sessions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "idx_users_email_lower" ON "users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "idx_users_mobile" ON "users"("mobile");

-- CreateIndex
CREATE UNIQUE INDEX "wallets_user_id_key" ON "wallets"("user_id");

-- CreateIndex
CREATE INDEX "idx_transactions_wallet_created" ON "transactions"("wallet_id", "created_at" DESC);

-- CreateIndex
CREATE INDEX "idx_games_state_start" ON "games"("state", "scheduled_start_time");

-- CreateIndex
CREATE INDEX "idx_tickets_user_game" ON "tickets"("user_id", "game_id");

-- CreateIndex
CREATE INDEX "idx_draw_events_game_position" ON "draw_events"("game_id", "position");

-- CreateIndex
CREATE UNIQUE INDEX "idx_draw_events_game_number" ON "draw_events"("game_id", "number");

-- CreateIndex
CREATE INDEX "idx_winning_claims_game_pattern" ON "winning_claims"("game_id", "pattern");

-- CreateIndex
CREATE INDEX "idx_withdrawal_requests_user" ON "withdrawal_requests"("user_id");

-- CreateIndex
CREATE INDEX "idx_sessions_token_hash" ON "sessions" USING HASH ("token_hash");

-- AddForeignKey
ALTER TABLE "wallets" ADD CONSTRAINT "wallets_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "transactions" ADD CONSTRAINT "transactions_wallet_id_fkey" FOREIGN KEY ("wallet_id") REFERENCES "wallets"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tickets" ADD CONSTRAINT "tickets_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tickets" ADD CONSTRAINT "tickets_game_id_fkey" FOREIGN KEY ("game_id") REFERENCES "games"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "draw_events" ADD CONSTRAINT "draw_events_game_id_fkey" FOREIGN KEY ("game_id") REFERENCES "games"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "winning_claims" ADD CONSTRAINT "winning_claims_game_id_fkey" FOREIGN KEY ("game_id") REFERENCES "games"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "winning_claims" ADD CONSTRAINT "winning_claims_ticket_id_fkey" FOREIGN KEY ("ticket_id") REFERENCES "tickets"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "winning_claims" ADD CONSTRAINT "winning_claims_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "withdrawal_requests" ADD CONSTRAINT "withdrawal_requests_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sessions" ADD CONSTRAINT "sessions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
