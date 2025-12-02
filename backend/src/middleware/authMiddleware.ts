import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { PrismaClient } from '@prisma/client';
import { AppError } from '../utils';
import { JWT_SECRET, JwtPayload, StaffRole } from '../config';

const prisma = new PrismaClient();

/**
 * Extended Request interface with user property
 */
export interface AuthenticatedRequest extends Request {
  user: JwtPayload;
}

/**
 * Protect Middleware
 * Verifies JWT token and attaches user payload to request
 *
 * @throws AppError 401 if no token or invalid token
 */
export const protect = async (
  req: Request,
  _res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    let token: string | undefined;

    // 1) Extract token from Authorization header
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      token = authHeader.split(' ')[1];
    }

    // 2) Check if token exists
    if (!token) {
      throw new AppError(
        'You are not logged in. Please log in to access this resource.',
        401
      );
    }

    // 3) Verify token
    let decoded: JwtPayload;
    try {
      decoded = jwt.verify(token, JWT_SECRET) as JwtPayload;
    } catch (err) {
      if (err instanceof jwt.TokenExpiredError) {
        throw new AppError('Your session has expired. Please log in again.', 401);
      }
      if (err instanceof jwt.JsonWebTokenError) {
        throw new AppError('Invalid token. Please log in again.', 401);
      }
      throw new AppError('Token verification failed. Please log in again.', 401);
    }

    // 4) Check if user still exists
    const currentUser = await prisma.staff.findUnique({
      where: { staff_id: BigInt(decoded.id) },
    });

    if (!currentUser) {
      throw new AppError(
        'The user belonging to this token no longer exists.',
        401
      );
    }

    // 5) Check if user is still active
    if (currentUser.status !== 'Active') {
      throw new AppError(
        `Your account is ${currentUser.status}. Please contact administrator.`,
        401
      );
    }

    // 6) Attach user to request object
    (req as AuthenticatedRequest).user = decoded;

    next();
  } catch (error) {
    next(error);
  }
};

/**
 * Restrict To Middleware Factory
 * Creates middleware that restricts access to specific roles
 *
 * @param roles - Array of allowed roles
 * @returns Middleware function
 *
 * @example
 * router.delete('/users/:id', protect, restrictTo('ADMIN', 'MANAGER'), deleteUser);
 */
export const restrictTo = (...roles: StaffRole[]) => {
  return (req: Request, _res: Response, next: NextFunction): void => {
    const user = (req as AuthenticatedRequest).user;

    if (!user) {
      return next(
        new AppError('You must be logged in to access this resource.', 401)
      );
    }

    if (!roles.includes(user.role)) {
      return next(
        new AppError(
          'You do not have permission to perform this action.',
          403
        )
      );
    }

    next();
  };
};

/**
 * Optional Auth Middleware
 * Attaches user to request if token is valid, but doesn't require authentication
 * Useful for routes that behave differently for authenticated users
 */
export const optionalAuth = async (
  req: Request,
  _res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return next();
    }

    const token = authHeader.split(' ')[1];

    try {
      const decoded = jwt.verify(token, JWT_SECRET) as JwtPayload;
      
      const currentUser = await prisma.staff.findUnique({
        where: { staff_id: BigInt(decoded.id) },
      });

      if (currentUser && currentUser.status === 'Active') {
        (req as AuthenticatedRequest).user = decoded;
      }
    } catch {
      // Token invalid, continue without user
    }

    next();
  } catch (error) {
    next(error);
  }
};
