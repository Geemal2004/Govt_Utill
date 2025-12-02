// Middleware barrel export
export { globalErrorHandler, notFoundHandler } from './errorHandler';
export { protect, restrictTo, optionalAuth } from './authMiddleware';
export type { AuthenticatedRequest } from './authMiddleware';
