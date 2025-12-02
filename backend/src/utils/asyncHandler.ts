import { Request, Response, NextFunction, RequestHandler } from 'express';

/**
 * Type definition for async controller functions
 * Made generic to support both Request and extended request types (e.g., AuthenticatedRequest)
 */
type AsyncFunction<T = Request> = (
  req: T,
  res: Response,
  next: NextFunction
) => Promise<unknown>;

/**
 * Higher-Order Function to wrap async route handlers
 * Automatically catches errors and passes them to Express error handling middleware
 * Eliminates the need for try-catch blocks in every controller
 *
 * @param fn - Async function to wrap
 * @returns Express RequestHandler that catches async errors
 *
 * @example
 * // Instead of:
 * app.get('/api/zones', async (req, res, next) => {
 *   try {
 *     const zones = await prisma.zone.findMany();
 *     res.json(zones);
 *   } catch (error) {
 *     next(error);
 *   }
 * });
 *
 * // Use:
 * app.get('/api/zones', asyncHandler(async (req, res) => {
 *   const zones = await prisma.zone.findMany();
 *   res.json(zones);
 * }));
 */
export const asyncHandler = <T = Request>(fn: AsyncFunction<T>): RequestHandler => {
  return (req: Request, res: Response, next: NextFunction): void => {
    Promise.resolve(fn(req as T, res, next)).catch(next);
  };
};

/**
 * Alternative implementation using Express's native error handling
 * This version is slightly more explicit about the Promise handling
 */
export const catchAsync = <T = Request>(fn: AsyncFunction<T>): RequestHandler => {
  return (req: Request, res: Response, next: NextFunction): void => {
    fn(req as T, res, next).catch((error: Error) => next(error));
  };
};
