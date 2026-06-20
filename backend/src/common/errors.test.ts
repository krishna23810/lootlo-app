import {
  AppError,
  validationError,
  unauthorizedError,
  forbiddenError,
  notFoundError,
  conflictError,
  internalError,
  serviceUnavailableError,
} from './errors';

describe('ErrorResponse and AppError', () => {
  it('should create an AppError with correct status and response', () => {
    const err = new AppError({
      status: 400,
      code: 'TEST_ERROR',
      message: 'Something went wrong',
      retryable: false,
    });

    expect(err.status).toBe(400);
    expect(err.response.code).toBe('TEST_ERROR');
    expect(err.response.message).toBe('Something went wrong');
    expect(err.response.retryable).toBe(false);
    expect(err.response.fields).toBeUndefined();
    expect(err).toBeInstanceOf(Error);
    expect(err).toBeInstanceOf(AppError);
  });

  it('should include field-level validation errors', () => {
    const err = validationError('Invalid input', {
      email: 'Invalid email format',
      password: 'Must be at least 8 characters',
    });

    expect(err.status).toBe(400);
    expect(err.response.code).toBe('VALIDATION_ERROR');
    expect(err.response.fields).toEqual({
      email: 'Invalid email format',
      password: 'Must be at least 8 characters',
    });
    expect(err.response.retryable).toBe(false);
  });

  it('should create unauthorized error', () => {
    const err = unauthorizedError();
    expect(err.status).toBe(401);
    expect(err.response.code).toBe('UNAUTHORIZED');
    expect(err.response.retryable).toBe(false);
  });

  it('should create forbidden error', () => {
    const err = forbiddenError();
    expect(err.status).toBe(403);
    expect(err.response.code).toBe('FORBIDDEN');
    expect(err.response.retryable).toBe(false);
  });

  it('should create not found error', () => {
    const err = notFoundError('Game');
    expect(err.status).toBe(404);
    expect(err.response.code).toBe('NOT_FOUND');
    expect(err.response.message).toBe('Game not found');
    expect(err.response.retryable).toBe(false);
  });

  it('should create conflict error', () => {
    const err = conflictError('Email already in use');
    expect(err.status).toBe(409);
    expect(err.response.code).toBe('CONFLICT');
    expect(err.response.message).toBe('Email already in use');
    expect(err.response.retryable).toBe(false);
  });

  it('should create internal error with retryable = true', () => {
    const err = internalError();
    expect(err.status).toBe(500);
    expect(err.response.code).toBe('INTERNAL_ERROR');
    expect(err.response.retryable).toBe(true);
  });

  it('should create service unavailable error with retryable = true', () => {
    const err = serviceUnavailableError();
    expect(err.status).toBe(503);
    expect(err.response.code).toBe('SERVICE_UNAVAILABLE');
    expect(err.response.retryable).toBe(true);
  });
});
