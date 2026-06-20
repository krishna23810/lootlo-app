import {
  validateEmail,
  validatePassword,
  validateDisplayName,
  validateMobile,
  validateAmountRange,
  validateTopUpAmount,
  validateWithdrawalAmount,
  validateTicketPrice,
  validateCommissionPercentage,
  validateMaxTicketCount,
  validateRegistration,
} from './validators';

describe('validateEmail', () => {
  it('accepts a valid email', () => {
    const result = validateEmail('user@example.com');
    expect(result.valid).toBe(true);
    expect(result.errors).toEqual({});
  });

  it('rejects empty email', () => {
    const result = validateEmail('');
    expect(result.valid).toBe(false);
    expect(result.errors.email).toBeDefined();
  });

  it('rejects email without @', () => {
    const result = validateEmail('userexample.com');
    expect(result.valid).toBe(false);
  });

  it('rejects email without domain dot', () => {
    const result = validateEmail('user@example');
    expect(result.valid).toBe(false);
    expect(result.errors.email).toContain('at least one dot');
  });

  it('rejects email longer than 254 characters', () => {
    const longEmail = 'a'.repeat(250) + '@b.co';
    expect(longEmail.length).toBeGreaterThan(254);
    const result = validateEmail(longEmail);
    expect(result.valid).toBe(false);
  });

  it('rejects email with empty domain part', () => {
    const result = validateEmail('user@.example.com');
    expect(result.valid).toBe(false);
  });

  it('accepts email with subdomains', () => {
    const result = validateEmail('user@mail.example.co.uk');
    expect(result.valid).toBe(true);
  });
});

describe('validatePassword', () => {
  it('accepts a valid password', () => {
    const result = validatePassword('Passw0rd');
    expect(result.valid).toBe(true);
  });

  it('rejects password shorter than 8 characters', () => {
    const result = validatePassword('Pa1');
    expect(result.valid).toBe(false);
    expect(result.errors.password).toContain('at least 8');
  });

  it('rejects password longer than 128 characters', () => {
    const result = validatePassword('A1' + 'a'.repeat(127));
    expect(result.valid).toBe(false);
    expect(result.errors.password).toContain('not exceed 128');
  });

  it('rejects password without uppercase', () => {
    const result = validatePassword('password1');
    expect(result.valid).toBe(false);
    expect(result.errors.password).toContain('uppercase');
  });

  it('rejects password without lowercase', () => {
    const result = validatePassword('PASSWORD1');
    expect(result.valid).toBe(false);
    expect(result.errors.password).toContain('lowercase');
  });

  it('rejects password without digit', () => {
    const result = validatePassword('Password');
    expect(result.valid).toBe(false);
    expect(result.errors.password).toContain('digit');
  });

  it('accepts exactly 8 character password', () => {
    const result = validatePassword('Abcdef1x');
    expect(result.valid).toBe(true);
  });

  it('accepts exactly 128 character password', () => {
    const password = 'A1' + 'a'.repeat(126);
    expect(password.length).toBe(128);
    const result = validatePassword(password);
    expect(result.valid).toBe(true);
  });
});

describe('validateDisplayName', () => {
  it('accepts a valid display name', () => {
    const result = validateDisplayName('Player_1');
    expect(result.valid).toBe(true);
  });

  it('accepts display name with spaces', () => {
    const result = validateDisplayName('John Doe');
    expect(result.valid).toBe(true);
  });

  it('rejects display name shorter than 3 characters', () => {
    const result = validateDisplayName('AB');
    expect(result.valid).toBe(false);
    expect(result.errors.displayName).toContain('at least 3');
  });

  it('rejects display name longer than 30 characters', () => {
    const result = validateDisplayName('a'.repeat(31));
    expect(result.valid).toBe(false);
    expect(result.errors.displayName).toContain('not exceed 30');
  });

  it('rejects display name with special characters', () => {
    const result = validateDisplayName('user@name!');
    expect(result.valid).toBe(false);
    expect(result.errors.displayName).toContain('alphanumeric');
  });

  it('accepts exactly 3 character display name', () => {
    const result = validateDisplayName('abc');
    expect(result.valid).toBe(true);
  });

  it('accepts exactly 30 character display name', () => {
    const result = validateDisplayName('a'.repeat(30));
    expect(result.valid).toBe(true);
  });
});

describe('validateAmountRange', () => {
  it('accepts amount within range', () => {
    const result = validateAmountRange(50, 1, 100);
    expect(result.valid).toBe(true);
  });

  it('accepts amount at minimum boundary', () => {
    const result = validateAmountRange(1, 1, 100);
    expect(result.valid).toBe(true);
  });

  it('accepts amount at maximum boundary', () => {
    const result = validateAmountRange(100, 1, 100);
    expect(result.valid).toBe(true);
  });

  it('rejects amount below minimum', () => {
    const result = validateAmountRange(0, 1, 100, 'price');
    expect(result.valid).toBe(false);
    expect(result.errors.price).toContain('at least 1');
  });

  it('rejects amount above maximum', () => {
    const result = validateAmountRange(101, 1, 100, 'price');
    expect(result.valid).toBe(false);
    expect(result.errors.price).toContain('not exceed 100');
  });

  it('rejects NaN', () => {
    const result = validateAmountRange(NaN, 1, 100);
    expect(result.valid).toBe(false);
  });

  it('rejects Infinity', () => {
    const result = validateAmountRange(Infinity, 1, 100);
    expect(result.valid).toBe(false);
  });
});

describe('validateTopUpAmount', () => {
  it('accepts 1', () => {
    expect(validateTopUpAmount(1).valid).toBe(true);
  });

  it('accepts 100000', () => {
    expect(validateTopUpAmount(100_000).valid).toBe(true);
  });

  it('rejects 0', () => {
    expect(validateTopUpAmount(0).valid).toBe(false);
  });

  it('rejects 100001', () => {
    expect(validateTopUpAmount(100_001).valid).toBe(false);
  });
});

describe('validateWithdrawalAmount', () => {
  it('accepts 100', () => {
    expect(validateWithdrawalAmount(100).valid).toBe(true);
  });

  it('accepts 50000', () => {
    expect(validateWithdrawalAmount(50_000).valid).toBe(true);
  });

  it('rejects 99', () => {
    expect(validateWithdrawalAmount(99).valid).toBe(false);
  });

  it('rejects 50001', () => {
    expect(validateWithdrawalAmount(50_001).valid).toBe(false);
  });
});

describe('validateTicketPrice', () => {
  it('accepts a positive integer', () => {
    expect(validateTicketPrice(100).valid).toBe(true);
  });

  it('rejects zero', () => {
    expect(validateTicketPrice(0).valid).toBe(false);
  });

  it('rejects negative', () => {
    expect(validateTicketPrice(-5).valid).toBe(false);
  });

  it('rejects non-integer', () => {
    expect(validateTicketPrice(10.5).valid).toBe(false);
  });
});

describe('validateCommissionPercentage', () => {
  it('accepts 1', () => {
    expect(validateCommissionPercentage(1).valid).toBe(true);
  });

  it('accepts 30', () => {
    expect(validateCommissionPercentage(30).valid).toBe(true);
  });

  it('rejects 0', () => {
    expect(validateCommissionPercentage(0).valid).toBe(false);
  });

  it('rejects 31', () => {
    expect(validateCommissionPercentage(31).valid).toBe(false);
  });
});

describe('validateMaxTicketCount', () => {
  it('accepts 10', () => {
    expect(validateMaxTicketCount(10).valid).toBe(true);
  });

  it('accepts 1000', () => {
    expect(validateMaxTicketCount(1000).valid).toBe(true);
  });

  it('rejects 9', () => {
    expect(validateMaxTicketCount(9).valid).toBe(false);
  });

  it('rejects 1001', () => {
    expect(validateMaxTicketCount(1001).valid).toBe(false);
  });

  it('rejects non-integer', () => {
    expect(validateMaxTicketCount(10.5).valid).toBe(false);
  });
});

describe('validateMobile', () => {
  it('accepts a valid 10-digit mobile number', () => {
    const result = validateMobile('9876543210');
    expect(result.valid).toBe(true);
  });

  it('accepts a mobile number with + prefix', () => {
    const result = validateMobile('+919876543210');
    expect(result.valid).toBe(true);
  });

  it('accepts a 15-digit number', () => {
    const result = validateMobile('+123456789012345');
    expect(result.valid).toBe(true);
  });

  it('rejects empty mobile', () => {
    const result = validateMobile('');
    expect(result.valid).toBe(false);
    expect(result.errors.mobile).toBeDefined();
  });

  it('rejects number shorter than 10 digits', () => {
    const result = validateMobile('12345');
    expect(result.valid).toBe(false);
    expect(result.errors.mobile).toContain('between 10 and 15');
  });

  it('rejects number longer than 15 digits', () => {
    const result = validateMobile('1234567890123456');
    expect(result.valid).toBe(false);
  });

  it('rejects non-digit characters', () => {
    const result = validateMobile('98765-43210');
    expect(result.valid).toBe(false);
    expect(result.errors.mobile).toContain('only digits');
  });
});

describe('validateRegistration', () => {
  it('accepts valid registration', () => {
    const result = validateRegistration('user@example.com', '+919876543210', 'Passw0rd', 'Player_1');
    expect(result.valid).toBe(true);
    expect(result.errors).toEqual({});
  });

  it('returns all field errors when all invalid', () => {
    const result = validateRegistration('invalid', 'abc', 'short', 'x!');
    expect(result.valid).toBe(false);
    expect(result.errors.email).toBeDefined();
    expect(result.errors.mobile).toBeDefined();
    expect(result.errors.password).toBeDefined();
    expect(result.errors.displayName).toBeDefined();
  });

  it('returns only failing field errors', () => {
    const result = validateRegistration('user@example.com', '+919876543210', 'short', 'Player_1');
    expect(result.valid).toBe(false);
    expect(result.errors.email).toBeUndefined();
    expect(result.errors.mobile).toBeUndefined();
    expect(result.errors.password).toBeDefined();
    expect(result.errors.displayName).toBeUndefined();
  });
});
