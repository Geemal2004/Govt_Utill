import { Request, Response, NextFunction, RequestHandler } from 'express';

/**
 * Type definition for async controller functions
 */
type AsyncFunction = (
  req: Request,
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
export const asyncHandler = (fn: AsyncFunction): RequestHandler => {
  return (req: Request, res: Response, next: NextFunction): void => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
};

/**
 * Alternative implementation using Express's native error handling
 * This version is slightly more explicit about the Promise handling
 */
export const catchAsync = (fn: AsyncFunction): RequestHandler => {
  return (req: Request, res: Response, next: NextFunction): void => {
    fn(req, res, next).catch((error: Error) => next(error));
  };
};
