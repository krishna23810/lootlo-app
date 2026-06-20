/**
 * Housie/Tambola Ticket Generator
 *
 * ALGORITHM OVERVIEW:
 * ──────────────────
 * Generating a valid Housie ticket is a CONSTRAINT SATISFACTION problem.
 * We need to satisfy ALL these constraints simultaneously:
 * 
 * 1. 3 rows × 9 columns
 * 2. Exactly 5 numbers per row (15 total)
 * 3. Column ranges: col 0→1-9, col 1→10-19, ..., col 8→80-90
 * 4. Each column has 1, 2, or 3 numbers
 * 5. Numbers sorted top-to-bottom within each column
 * 6. All numbers unique
 *
 * APPROACH:
 * Step 1: Decide HOW MANY numbers each column gets (1, 2, or 3)
 *         → Must sum to 15 total AND each row must have exactly 5
 * Step 2: Decide WHICH ROWS each column's numbers go in
 *         → Each row must end up with exactly 5 filled cells
 * Step 3: Pick the actual NUMBERS from each column's range
 *         → Random selection, then sort within column
 *
 * This is like a Sudoku generator — you build the structure first,
 * then fill in the values.
 */

// Type for the ticket: 3 rows × 9 columns, each cell is number or null
type TicketCell = number | null;
type TicketGrid = TicketCell[][];

/**
 * Generate a valid Housie ticket.
 * Returns a 3×9 grid where each cell is either a number (1-90) or null.
 */
export function generateTicket(): TicketGrid {
  // Keep trying until we get a valid ticket
  // (the random distribution might occasionally violate constraints)
  for (let attempt = 0; attempt < 100; attempt++) {
    const ticket = tryGenerateTicket();
    if (ticket && validateTicket(ticket)) {
      return ticket;
    }
  }

  // Should never reach here with a correct algorithm, but just in case
  throw new Error('Failed to generate valid ticket after 100 attempts');
}

/**
 * Attempt to generate a ticket. May return null if constraints can't be met.
 */
function tryGenerateTicket(): TicketGrid | null {
  // ── Step 1: Decide column counts ────────────────────────────────────────
  // Each column gets 1, 2, or 3 numbers. Total must be 15.
  // We need to distribute 15 numbers across 9 columns where each has 1-3.
  // 
  // Minimum possible: 9 × 1 = 9
  // Maximum possible: 9 × 3 = 27
  // We need exactly 15, so average is ~1.67 per column.
  //
  // Strategy: start with all 1s (=9), then distribute remaining 6 among columns.
  
  const columnCounts = new Array(9).fill(1); // Start: each column gets 1 number
  let remaining = 15 - 9; // Need to distribute 6 more

  while (remaining > 0) {
    // Pick a random column that hasn't hit max (3)
    const available = columnCounts
      .map((count, index) => ({ count, index }))
      .filter(({ count }) => count < 3);

    if (available.length === 0) break;

    const pick = available[Math.floor(Math.random() * available.length)];
    columnCounts[pick.index]++;
    remaining--;
  }

  // ── Step 2: Assign numbers to rows ──────────────────────────────────────
  // For each column, decide WHICH rows get the numbers.
  // Constraint: each row must end up with exactly 5.
  //
  // We track how many numbers each row has been assigned so far.
  const rowCounts = [0, 0, 0]; // How many numbers assigned to each row
  const columnRows: number[][] = []; // For each column, which rows have numbers

  for (let col = 0; col < 9; col++) {
    const count = columnCounts[col];
    const rows = pickRowsForColumn(count, rowCounts);
    
    if (!rows) return null; // Constraint can't be met, retry
    
    columnRows.push(rows);
    for (const row of rows) {
      rowCounts[row]++;
    }
  }

  // Verify each row has exactly 5
  if (rowCounts[0] !== 5 || rowCounts[1] !== 5 || rowCounts[2] !== 5) {
    return null;
  }

  // ── Step 3: Pick actual numbers ─────────────────────────────────────────
  // For each column, randomly select `count` numbers from the column's range.
  // Column ranges: col 0 → 1-9, col 1 → 10-19, ..., col 8 → 80-90
  const grid: TicketGrid = [
    new Array(9).fill(null),
    new Array(9).fill(null),
    new Array(9).fill(null),
  ];

  for (let col = 0; col < 9; col++) {
    const range = getColumnRange(col);
    const count = columnCounts[col];
    const rows = columnRows[col];

    // Pick `count` random unique numbers from the range
    const numbers = pickRandomNumbers(range, count);
    
    // Sort numbers (for this column, top row gets smallest)
    numbers.sort((a, b) => a - b);

    // Sort rows too (so smallest number goes to earliest row)
    const sortedRows = [...rows].sort((a, b) => a - b);

    // Assign numbers to cells
    for (let i = 0; i < count; i++) {
      grid[sortedRows[i]][col] = numbers[i];
    }
  }

  return grid;
}

/**
 * Pick which rows a column's numbers go into.
 * Must respect the constraint: no row can exceed 5 total numbers.
 *
 * Strategy: prefer rows that have fewer numbers assigned so far.
 * This greedy approach distributes numbers evenly.
 */
function pickRowsForColumn(count: number, rowCounts: number[]): number[] | null {
  // Available rows: those that haven't reached 5 yet
  const available = [0, 1, 2].filter((r) => rowCounts[r] < 5);
  
  if (available.length < count) return null;

  // Sort by fewest numbers first (greedy: fill emptier rows first)
  available.sort((a, b) => rowCounts[a] - rowCounts[b]);

  // Pick `count` rows, preferring emptier ones but with some randomness
  const selected: number[] = [];
  const pool = [...available];

  for (let i = 0; i < count; i++) {
    // Slight randomness: sometimes skip the "optimal" choice
    const index = Math.random() < 0.3 && pool.length > 1 
      ? Math.floor(Math.random() * pool.length) 
      : 0;
    selected.push(pool[index]);
    pool.splice(index, 1);
  }

  return selected;
}

/**
 * Get the valid number range for a column.
 * Column 0: 1-9, Column 1: 10-19, ..., Column 8: 80-90
 *
 * NOTE: Column 8 has range 80-90 (11 numbers), not 80-89.
 * This is the standard Housie rule — the last column includes 90.
 */
function getColumnRange(col: number): number[] {
  const start = col === 0 ? 1 : col * 10;
  const end = col === 8 ? 90 : (col + 1) * 10 - 1;
  
  const range: number[] = [];
  for (let i = start; i <= end; i++) {
    range.push(i);
  }
  return range;
}

/**
 * Pick `count` unique random numbers from an array.
 * Uses Fisher-Yates shuffle on a copy, then takes first `count`.
 *
 * WHY Fisher-Yates?
 * It's the only correct way to get a uniformly random selection.
 * Using Math.random() repeatedly and checking for duplicates is biased
 * and can be slow for large arrays.
 */
function pickRandomNumbers(pool: number[], count: number): number[] {
  const shuffled = [...pool]; // Don't mutate the original
  
  // Fisher-Yates shuffle (partial — only need first `count` positions)
  for (let i = 0; i < count; i++) {
    const j = i + Math.floor(Math.random() * (shuffled.length - i));
    [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
  }
  
  return shuffled.slice(0, count);
}

// ─── Validation ──────────────────────────────────────────────────────────────

/**
 * Validate that a ticket grid satisfies ALL Housie rules.
 * Used to verify generated tickets and validate incoming data.
 */
export function validateTicket(grid: TicketGrid): boolean {
  // Rule 1: Must be 3 rows × 9 columns
  if (grid.length !== 3) return false;
  if (!grid.every((row) => row.length === 9)) return false;

  // Rule 2: Exactly 5 numbers per row
  for (const row of grid) {
    const count = row.filter((cell) => cell !== null).length;
    if (count !== 5) return false;
  }

  // Rule 3: Column ranges
  for (let col = 0; col < 9; col++) {
    const range = getColumnRange(col);
    for (let row = 0; row < 3; row++) {
      const cell = grid[row][col];
      if (cell !== null && !range.includes(cell)) return false;
    }
  }

  // Rule 4: Each column has 1-3 numbers
  for (let col = 0; col < 9; col++) {
    const count = [0, 1, 2].filter((row) => grid[row][col] !== null).length;
    if (count < 1 || count > 3) return false;
  }

  // Rule 5: Numbers sorted top-to-bottom within columns
  for (let col = 0; col < 9; col++) {
    const numbers = [0, 1, 2]
      .map((row) => grid[row][col])
      .filter((cell): cell is number => cell !== null);
    for (let i = 1; i < numbers.length; i++) {
      if (numbers[i] <= numbers[i - 1]) return false;
    }
  }

  // Rule 6: All numbers unique
  const allNumbers = grid.flat().filter((cell): cell is number => cell !== null);
  if (new Set(allNumbers).size !== allNumbers.length) return false;
  if (allNumbers.length !== 15) return false;

  return true;
}
