import { Request, Response, NextFunction } from 'express';
import { Prisma } from '@prisma/client';
import { AppError } from '../utils/AppError';

/**
 * Environment check
 */
const isDevelopment = process.env.NODE_ENV !== 'production';

/**
 * Error response interface
 */
interface ErrorResponse {
  status: 'fail' | 'error';
  message: string;
  error?: {
    statusCode: number;
    isOperational: boolean;
  };
  stack?: string;
}

/**
 * Handle Prisma Known Request Errors
 * These are errors thrown by Prisma due to constraint violations, not found records, etc.
 */
const handlePrismaKnownError = (
  error: Prisma.PrismaClientKnownRequestError
): AppError => {
  switch (error.code) {
    // Unique constraint violation
    case 'P2002': {
      const target = error.meta?.target as string[] | undefined;
      const field = target ? target.join(', ') : 'field';
      return new AppError(
        `Duplicate value for ${field}. This record already exists.`,
        400
      );
    }

    // Record not found (for update/delete operations)
    case 'P2025': {
      const cause = error.meta?.cause as string | undefined;
      return new AppError(cause || 'Record not found.', 404);
    }

    // Foreign key constraint violation
    case 'P2003': {
      const field = error.meta?.field_name as string | undefined;
      return new AppError(
        `Invalid reference: ${field || 'Related record'} does not exist.`,
        400
      );
    }

    // Required field missing
    case 'P2011': {
      const constraint = error.meta?.constraint as string | undefined;
      return new AppError(
        `Missing required field: ${constraint || 'unknown field'}.`,
        400
      );
    }

    // Invalid ID value
    case 'P2023': {
      return new AppError('Invalid ID format provided.', 400);
    }

    // Too many database connections
    case 'P2024': {
      return new AppError(
        'Database connection timeout. Please try again later.',
        503
      );
    }

    default:
      return new AppError(`Database error: ${error.message}`, 500);
  }
};

/**
 * Handle Prisma Validation Errors
 * These occur when invalid data is passed to Prisma operations
 */
const handlePrismaValidationError = (
  error: Prisma.PrismaClientValidationError
): AppError => {
  // Extract a cleaner message from the validation error
  const message = error.message.split('\n').pop() || 'Invalid data provided';
  return new AppError(`Validation error: ${message}`, 400);
};

/**
 * Handle Prisma Initialization Errors
 * These occur when Prisma can't connect to the database
 */
const handlePrismaInitError = (
  _error: Prisma.PrismaClientInitializationError
): AppError => {
  return new AppError(
    'Database connection failed. Please try again later.',
    503
  );
};

/**
 * Send error response in Development environment
 * Includes full error details and stack trace
 */
const sendErrorDev = (err: AppError, res: Response): void => {
  const response: ErrorResponse = {
    status: err.status,
    message: err.message,
    error: {
      statusCode: err.statusCode,
      isOperational: err.isOperational,
    },
    stack: err.stack,
  };

  res.status(err.statusCode).json(response);
};

/**
 * Send error response in Production environment
 * Only sends operational (trusted) error details to client
 * Programming or unknown errors get generic message
 */
const sendErrorProd = (err: AppError, res: Response): void => {
  // Operational, trusted error: send message to client
  if (err.isOperational) {
    const response: ErrorResponse = {
      status: err.status,
      message: err.message,
    };
    res.status(err.statusCode).json(response);
  } else {
    // Programming or unknown error: don't leak error details
    console.error('ERROR 💥:', err);

    res.status(500).json({
      status: 'error',
      message: 'Something went wrong. Please try again later.',
    });
  }
};

/**
 * Global Error Handling Middleware
 * Catches all errors passed to next() and sends appropriate responses
 *
 * @param err - Error object (can be AppError, Prisma error, or native Error)
 * @param req - Express Request object
 * @param res - Express Response object
 * @param _next - Express NextFunction (unused but required for signature)
 */
export const globalErrorHandler = (
  err: Error,
  req: Request,
  res: Response,
  _next: NextFunction
): void => {
  // Log error for debugging
  if (isDevelopment) {
    console.error('🔴 Error:', {
      name: err.name,
      message: err.message,
      stack: err.stack,
    });
  }

  // Default to 500 Internal Server Error if not specified
  let error: AppError;

  // Handle known error types
  if (err instanceof AppError) {
    error = err;
  } else if (err instanceof Prisma.PrismaClientKnownRequestError) {
    error = handlePrismaKnownError(err);
  } else if (err instanceof Prisma.PrismaClientValidationError) {
    error = handlePrismaValidationError(err);
  } else if (err instanceof Prisma.PrismaClientInitializationError) {
    error = handlePrismaInitError(err);
  } else if (err.name === 'SyntaxError') {
    // JSON parsing error
    error = new AppError('Invalid JSON in request body.', 400);
  } else {
    // Unknown error - wrap in AppError
    error = new AppError(
      isDevelopment ? err.message : 'An unexpected error occurred.',
      500
    );
    // Mark as non-operational (programming error)
    (error as { isOperational: boolean }).isOperational = false;
  }

  // Send appropriate response based on environment
  if (isDevelopment) {
    sendErrorDev(error, res);
  } else {
    sendErrorProd(error, res);
  }
};

/**
 * 404 Not Found Handler
 * Catches requests to undefined routes
 */
export const notFoundHandler = (
  req: Request,
  _res: Response,
  next: NextFunction
): void => {
  const error = new AppError(
    `Cannot find ${req.method} ${req.originalUrl} on this server.`,
    404
  );
  next(error);
};
