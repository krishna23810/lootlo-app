// ========================
// Validation Result Types
// ========================

export interface ValidationResult {
  valid: boolean;
  errors: Record<string, string>;
}

// ========================
// Email Validation
// ========================

/**
 * Validates email format:
 * - Must have local-part@domain structure
 * - Domain must contain at least one dot
 * - Total length must not exceed 254 characters
 */
export function validateEmail(email: string): ValidationResult {
  const errors: Record<string, string> = {};

  if (!email || email.trim().length === 0) {
    errors.email = 'Email is required';
    return { valid: false, errors };
  }

  if (email.length > 254) {
    errors.email = 'Email must not exceed 254 characters';
    return { valid: false, errors };
  }

  // Split into local-part and domain
  const atIndex = email.lastIndexOf('@');
  if (atIndex <= 0 || atIndex === email.length - 1) {
    errors.email = 'Email must be in the format local-part@domain';
    return { valid: false, errors };
  }

  const localPart = email.substring(0, atIndex);
  const domain = email.substring(atIndex + 1);

  // Local part must not be empty
  if (localPart.length === 0) {
    errors.email = 'Email local part must not be empty';
    return { valid: false, errors };
  }

  // Domain must contain at least one dot
  if (!domain.includes('.')) {
    errors.email = 'Email domain must contain at least one dot';
    return { valid: false, errors };
  }

  // Domain parts must not be empty (no leading/trailing dots or consecutive dots)
  const domainParts = domain.split('.');
  for (const part of domainParts) {
    if (part.length === 0) {
      errors.email = 'Email domain is invalid';
      return { valid: false, errors };
    }
  }

  return { valid: true, errors: {} };
}

// ========================
// Password Validation
// ========================

/**
 * Validates password:
 * - Must be 8-128 characters in length
 * - Must contain at least one uppercase letter
 * - Must contain at least one lowercase letter
 * - Must contain at least one digit
 */
export function validatePassword(password: string): ValidationResult {
  const errors: Record<string, string> = {};

  if (!password) {
    errors.password = 'Password is required';
    return { valid: false, errors };
  }

  if (password.length < 8) {
    errors.password = 'Password must be at least 8 characters';
    return { valid: false, errors };
  }

  if (password.length > 128) {
    errors.password = 'Password must not exceed 128 characters';
    return { valid: false, errors };
  }

  if (!/[A-Z]/.test(password)) {
    errors.password = 'Password must contain at least one uppercase letter';
    return { valid: false, errors };
  }

  if (!/[a-z]/.test(password)) {
    errors.password = 'Password must contain at least one lowercase letter';
    return { valid: false, errors };
  }

  if (!/\d/.test(password)) {
    errors.password = 'Password must contain at least one digit';
    return { valid: false, errors };
  }

  return { valid: true, errors: {} };
}

// ========================
// Mobile Number Validation
// ========================

/**
 * Validates mobile number:
 * - Must be 10-15 digits (optionally prefixed with +)
 * - Only digits allowed after optional + prefix
 */
export function validateMobile(mobile: string): ValidationResult {
  const errors: Record<string, string> = {};

  if (!mobile || mobile.trim().length === 0) {
    errors.mobile = 'Mobile number is required';
    return { valid: false, errors };
  }

  // Strip optional + prefix for length/digit check
  const digits = mobile.startsWith('+') ? mobile.slice(1) : mobile;

  if (!/^\d+$/.test(digits)) {
    errors.mobile = 'Mobile number must contain only digits (optionally prefixed with +)';
    return { valid: false, errors };
  }

  if (digits.length < 10 || digits.length > 15) {
    errors.mobile = 'Mobile number must be between 10 and 15 digits';
    return { valid: false, errors };
  }

  return { valid: true, errors: {} };
}

// ========================
// Display Name Validation
// ========================

/**
 * Validates display name:
 * - Must be 3-30 characters in length
 * - Must contain only alphanumeric characters, spaces, and underscores
 */
export function validateDisplayName(displayName: string): ValidationResult {
  const errors: Record<string, string> = {};

  if (!displayName || displayName.trim().length === 0) {
    errors.displayName = 'Display name is required';
    return { valid: false, errors };
  }

  if (displayName.length < 3) {
    errors.displayName = 'Display name must be at least 3 characters';
    return { valid: false, errors };
  }

  if (displayName.length > 30) {
    errors.displayName = 'Display name must not exceed 30 characters';
    return { valid: false, errors };
  }

  if (!/^[a-zA-Z0-9 _]+$/.test(displayName)) {
    errors.displayName = 'Display name must contain only alphanumeric characters, spaces, and underscores';
    return { valid: false, errors };
  }

  return { valid: true, errors: {} };
}

// ========================
// Amount Validation
// ========================

/**
 * Validates that an amount falls within a given range (inclusive).
 * @param amount - The amount to validate
 * @param min - Minimum allowed value (inclusive)
 * @param max - Maximum allowed value (inclusive)
 * @param fieldName - The field name for error messages
 */
export function validateAmountRange(
  amount: number,
  min: number,
  max: number,
  fieldName: string = 'amount',
): ValidationResult {
  const errors: Record<string, string> = {};

  if (amount === null || amount === undefined || isNaN(amount)) {
    errors[fieldName] = `${fieldName} is required and must be a number`;
    return { valid: false, errors };
  }

  if (!Number.isFinite(amount)) {
    errors[fieldName] = `${fieldName} must be a finite number`;
    return { valid: false, errors };
  }

  if (amount < min) {
    errors[fieldName] = `${fieldName} must be at least ${min}`;
    return { valid: false, errors };
  }

  if (amount > max) {
    errors[fieldName] = `${fieldName} must not exceed ${max}`;
    return { valid: false, errors };
  }

  return { valid: true, errors: {} };
}

/**
 * Validates top-up amount: must be between 1 and 100,000 inclusive.
 */
export function validateTopUpAmount(amount: number): ValidationResult {
  return validateAmountRange(amount, 1, 100_000, 'amount');
}

/**
 * Validates withdrawal amount: must be between 100 and 50,000 inclusive.
 */
export function validateWithdrawalAmount(amount: number): ValidationResult {
  return validateAmountRange(amount, 100, 50_000, 'amount');
}

/**
 * Validates ticket price: must be a positive integer.
 */
export function validateTicketPrice(price: number): ValidationResult {
  const errors: Record<string, string> = {};

  if (price === null || price === undefined || isNaN(price)) {
    errors.ticketPrice = 'Ticket price is required and must be a number';
    return { valid: false, errors };
  }

  if (!Number.isInteger(price)) {
    errors.ticketPrice = 'Ticket price must be an integer';
    return { valid: false, errors };
  }

  if (price <= 0) {
    errors.ticketPrice = 'Ticket price must be a positive integer';
    return { valid: false, errors };
  }

  return { valid: true, errors: {} };
}

/**
 * Validates commission percentage: must be between 1 and 30 inclusive.
 */
export function validateCommissionPercentage(percentage: number): ValidationResult {
  return validateAmountRange(percentage, 1, 30, 'commissionPercentage');
}

/**
 * Validates maximum ticket count: must be between 10 and 1000 inclusive.
 */
export function validateMaxTicketCount(count: number): ValidationResult {
  const errors: Record<string, string> = {};

  if (count === null || count === undefined || isNaN(count)) {
    errors.maxTicketCount = 'Maximum ticket count is required and must be a number';
    return { valid: false, errors };
  }

  if (!Number.isInteger(count)) {
    errors.maxTicketCount = 'Maximum ticket count must be an integer';
    return { valid: false, errors };
  }

  return validateAmountRange(count, 10, 1000, 'maxTicketCount');
}

// ========================
// Combined Registration Validation
// ========================

/**
 * Validates all registration fields at once and returns combined errors.
 */
export function validateRegistration(
  email: string,
  mobile: string,
  password: string,
  displayName: string,
): ValidationResult {
  const emailResult = validateEmail(email);
  const mobileResult = validateMobile(mobile);
  const passwordResult = validatePassword(password);
  const displayNameResult = validateDisplayName(displayName);

  const errors: Record<string, string> = {
    ...emailResult.errors,
    ...mobileResult.errors,
    ...passwordResult.errors,
    ...displayNameResult.errors,
  };

  return {
    valid: emailResult.valid && mobileResult.valid && passwordResult.valid && displayNameResult.valid,
    errors,
  };
}
