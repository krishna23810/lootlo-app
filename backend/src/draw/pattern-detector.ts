import { WinningPattern } from '@prisma/client';

export type TicketGrid = (number | null)[][];

/**
 * Validates whether a specific pattern is completed on a ticket grid based on the drawn numbers.
 */
export function validateClaim(
  grid: TicketGrid,
  drawnNumbers: number[],
  pattern: WinningPattern,
): boolean {
  const drawnSet = new Set(drawnNumbers);

  // Helper to extract non-null numbers from a specific row
  const getRowNumbers = (rowIndex: number): number[] => {
    return grid[rowIndex].filter((num): num is number => num !== null);
  };

  // Helper to get all 15 numbers on the ticket
  const getAllTicketNumbers = (): number[] => {
    return grid.flat().filter((num): num is number => num !== null);
  };

  switch (pattern) {
    case 'early_five': {
      // Any 5 numbers on the ticket are drawn
      const allNumbers = getAllTicketNumbers();
      const matchedCount = allNumbers.filter((num) => drawnSet.has(num)).length;
      return matchedCount >= 5;
    }

    case 'four_corners': {
      // The 1st and last numbers of the top and bottom rows (4 numbers total)
      const topRow = getRowNumbers(0);
      const bottomRow = getRowNumbers(2);
      
      if (topRow.length === 0 || bottomRow.length === 0) return false;

      const corners = [
        topRow[0],
        topRow[topRow.length - 1],
        bottomRow[0],
        bottomRow[bottomRow.length - 1],
      ];

      return corners.every((num) => drawnSet.has(num));
    }

    case 'top_line': {
      // All 5 numbers of the top row are drawn
      const topRow = getRowNumbers(0);
      return topRow.length > 0 && topRow.every((num) => drawnSet.has(num));
    }

    case 'middle_line': {
      // All 5 numbers of the middle row are drawn
      const middleRow = getRowNumbers(1);
      return middleRow.length > 0 && middleRow.every((num) => drawnSet.has(num));
    }

    case 'bottom_line': {
      // All 5 numbers of the bottom row are drawn
      const bottomRow = getRowNumbers(2);
      return bottomRow.length > 0 && bottomRow.every((num) => drawnSet.has(num));
    }

    case 'full_house': {
      // All 15 numbers on the ticket are drawn
      const allNumbers = getAllTicketNumbers();
      return allNumbers.length > 0 && allNumbers.every((num) => drawnSet.has(num));
    }

    default:
      return false;
  }
}
