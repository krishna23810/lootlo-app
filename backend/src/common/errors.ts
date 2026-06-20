/**
 * Standard error response interface for the Live Housie API.
 * All error responses from the backend conform to this structure.
 */
export interface ErrorResponse {
  status: number;
  code: string;           // Machine-readable error code
  message: string;        // Human-readable message
  fields?: {              // Field-level validation errors
    [field: string]: string;
  };
  retryable: boolean;
}

/**
 * Custom application error that carries an ErrorResponse payload.
 * Throw this from service/handler code and let the error middleware serialize it.
 */
export class AppError extends Error {
  public readonly response: ErrorResponse;

  constructor(response: ErrorResponse) {
    super(response.message);
    this.response = response;
    Object.setPrototypeOf(this, AppError.prototype);
  }

  get status(): number {
    return this.response.status;
  }
}

// ─── Common error factory helpers ───────────────────────────────────────────────

export function validationError(
  message: string,
  fields: { [field: string]: string }
): AppError {
  return new AppError({
    status: 400,
    code: 'VALIDATION_ERROR',
    message,
    fields,
    retryable: false,
  });
}

export function unauthorizedError(message = 'Authentication required'): AppError {
  return new AppError({
    status: 401,
    code: 'UNAUTHORIZED',
    message,
    retryable: false,
  });
}

export function forbiddenError(message = 'Access denied'): AppError {
  return new AppError({
    status: 403,
    code: 'FORBIDDEN',
    message,
    retryable: false,
  });
}

export function notFoundError(resource: string): AppError {
  return new AppError({
    status: 404,
    code: 'NOT_FOUND',
    message: `${resource} not found`,
    retryable: false,
  });
}

export function conflictError(message: string): AppError {
  return new AppError({
    status: 409,
    code: 'CONFLICT',
    message,
    retryable: false,
  });
}

export function internalError(message = 'Internal server error'): AppError {
  return new AppError({
    status: 500,
    code: 'INTERNAL_ERROR',
    message,
    retryable: true,
  });
}

export function serviceUnavailableError(message = 'Service temporarily unavailable'): AppError {
  return new AppError({
    status: 503,
    code: 'SERVICE_UNAVAILABLE',
    message,
    retryable: true,
  });
}
