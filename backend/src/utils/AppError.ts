/**
 * Custom Application Error Class
 * Extends the native Error class with additional properties for API error handling
 */
export class AppError extends Error {
  public readonly statusCode: number;
  public readonly status: 'fail' | 'error';
  public readonly isOperational: boolean;

  /**
   * Creates an instance of AppError
   * @param message - Error message to be sent to the client
   * @param statusCode - HTTP status code (default: 500)
   */
  constructor(message: string, statusCode: number = 500) {
    super(message);

    this.statusCode = statusCode;
    // 4xx errors are 'fail', 5xx errors are 'error'
    this.status = `${statusCode}`.startsWith('4') ? 'fail' : 'error';
    // Operational errors are trusted errors we throw intentionally
    this.isOperational = true;

    // Capture stack trace, excluding constructor call from it
    Error.captureStackTrace(this, this.constructor);

    // Set the prototype explicitly for proper instanceof checks
    Object.setPrototypeOf(this, AppError.prototype);
  }
}

// Common error factory methods for convenience
export const NotFoundError = (message: string = 'Resource not found') =>
  new AppError(message, 404);

export const BadRequestError = (message: string = 'Bad request') =>
  new AppError(message, 400);

export const UnauthorizedError = (message: string = 'Unauthorized') =>
  new AppError(message, 401);

export const ForbiddenError = (message: string = 'Forbidden') =>
  new AppError(message, 403);

export const ConflictError = (message: string = 'Resource already exists') =>
  new AppError(message, 409);

export const ValidationError = (message: string = 'Validation failed') =>
  new AppError(message, 422);

export const InternalServerError = (message: string = 'Internal server error') =>
  new AppError(message, 500);
