/*
  Warnings:

  - Made the column `game_name` on table `games` required. This step will fail if there are existing NULL values in that column.

*/
-- AlterTable
ALTER TABLE "games" ADD COLUMN     "is_featured" BOOLEAN NOT NULL DEFAULT false,
ALTER COLUMN "game_name" SET NOT NULL;
