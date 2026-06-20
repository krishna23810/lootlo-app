import { generateTicket, validateTicket } from './ticket-generator';

describe('Ticket Generator', () => {
  it('should generate a valid ticket', () => {
    const ticket = generateTicket();
    expect(validateTicket(ticket)).toBe(true);
  });

  it('should generate 100 valid tickets (stress test)', () => {
    for (let i = 0; i < 100; i++) {
      const ticket = generateTicket();
      expect(validateTicket(ticket)).toBe(true);
    }
  });

  it('should have exactly 15 numbers total', () => {
    const ticket = generateTicket();
    const numbers = ticket.flat().filter((cell) => cell !== null);
    expect(numbers.length).toBe(15);
  });

  it('should have exactly 5 numbers per row', () => {
    const ticket = generateTicket();
    for (const row of ticket) {
      const count = row.filter((cell) => cell !== null).length;
      expect(count).toBe(5);
    }
  });

  it('should have 1-3 numbers per column', () => {
    const ticket = generateTicket();
    for (let col = 0; col < 9; col++) {
      const count = [0, 1, 2].filter((row) => ticket[row][col] !== null).length;
      expect(count).toBeGreaterThanOrEqual(1);
      expect(count).toBeLessThanOrEqual(3);
    }
  });

  it('should have numbers in correct column ranges', () => {
    const ticket = generateTicket();
    for (let col = 0; col < 9; col++) {
      const start = col === 0 ? 1 : col * 10;
      const end = col === 8 ? 90 : (col + 1) * 10 - 1;
      for (let row = 0; row < 3; row++) {
        const cell = ticket[row][col];
        if (cell !== null) {
          expect(cell).toBeGreaterThanOrEqual(start);
          expect(cell).toBeLessThanOrEqual(end);
        }
      }
    }
  });

  it('should have numbers sorted within columns', () => {
    const ticket = generateTicket();
    for (let col = 0; col < 9; col++) {
      const numbers = [0, 1, 2]
        .map((row) => ticket[row][col])
        .filter((cell): cell is number => cell !== null);
      for (let i = 1; i < numbers.length; i++) {
        expect(numbers[i]).toBeGreaterThan(numbers[i - 1]);
      }
    }
  });

  it('should have all unique numbers', () => {
    const ticket = generateTicket();
    const numbers = ticket.flat().filter((cell): cell is number => cell !== null);
    expect(new Set(numbers).size).toBe(15);
  });

  it('should generate different tickets each time', () => {
    const ticket1 = generateTicket();
    const ticket2 = generateTicket();
    // Extremely unlikely to be identical (15 numbers from 90 possible)
    const str1 = JSON.stringify(ticket1);
    const str2 = JSON.stringify(ticket2);
    expect(str1).not.toBe(str2);
  });
});
