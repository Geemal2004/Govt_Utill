import { Request, Response } from 'express';
import jwt, { SignOptions } from 'jsonwebtoken';
import { PrismaClient } from '@prisma/client';
import { asyncHandler, AppError } from '../utils';
import { JWT_SECRET, JWT_EXPIRES_IN, StaffRole } from '../config';

const prisma = new PrismaClient();

/**
 * Helper function to serialize BigInt values for JSON
 */
const bigIntSerializer = (_key: string, value: unknown) =>
  typeof value === 'bigint' ? value.toString() : value;

/**
 * Determine staff role based on subtype tables
 * Priority: Manager > Admin > Cashier > Field Officer > Meter Reader > Staff
 */
const determineStaffRole = async (staffId: bigint): Promise<StaffRole> => {
  // Check Manager
  const manager = await prisma.manager.findUnique({
    where: { staff_id: staffId },
  });
  if (manager) return 'MANAGER';

  // Check Administrative Staff
  const admin = await prisma.administrativeStaff.findUnique({
    where: { staff_id: staffId },
  });
  if (admin) return 'ADMIN';

  // Check Cashier
  const cashier = await prisma.cashier.findUnique({
    where: { staff_id: staffId },
  });
  if (cashier) return 'CASHIER';

  // Check Field Officer
  const fieldOfficer = await prisma.fieldOfficer.findUnique({
    where: { staff_id: staffId },
  });
  if (fieldOfficer) return 'FIELD_OFFICER';

  // Check Meter Reader
  const meterReader = await prisma.meterReader.findUnique({
    where: { staff_id: staffId },
  });
  if (meterReader) return 'METER_READER';

  // Default role
  return 'STAFF';
};

/**
 * Generate JWT token for authenticated staff
 */
const signToken = (id: string, employeeNo: string, role: StaffRole): string => {
  const options: SignOptions = {
    expiresIn: JWT_EXPIRES_IN as jwt.SignOptions['expiresIn'],
  };
  return jwt.sign({ id, employeeNo, role }, JWT_SECRET, options);
};

/**
 * Login Controller
 * DEV MODE: No password required - just employee_no
 *
 * @route POST /api/auth/login
 * @body { employee_no: string }
 * @returns { status, token, data: { user } }
 */
export const login = asyncHandler(async (req: Request, res: Response) => {
  const { employee_no } = req.body;

  // 1) Validate input
  if (!employee_no) {
    throw new AppError('Please provide employee_no', 400);
  }

  // 2) Find staff by employee_no
  const staff = await prisma.staff.findFirst({
    where: { employee_no },
  });

  if (!staff) {
    throw new AppError('Invalid employee number. Staff not found.', 401);
  }

  // 3) Check if staff is active
  if (staff.status !== 'Active') {
    throw new AppError(
      `Staff account is ${staff.status}. Please contact administrator.`,
      401
    );
  }

  // 4) Determine staff role from subtype tables
  const role = await determineStaffRole(staff.staff_id);

  // 5) Generate JWT token
  const token = signToken(staff.staff_id.toString(), staff.employee_no, role);

  // 6) Prepare user data (excluding sensitive fields if any)
  const userData = {
    staff_id: staff.staff_id.toString(),
    employee_no: staff.employee_no,
    full_name: staff.full_name,
    email: staff.email,
    phone: staff.phone,
    status: staff.status,
    role,
  };

  // 7) Send response
  res.status(200).json({
    status: 'success',
    token,
    data: {
      user: userData,
    },
  });
});

/**
 * Get current user profile
 *
 * @route GET /api/auth/me
 * @requires Authentication
 * @returns { status, data: { user } }
 */
export const getMe = asyncHandler(async (req: Request, res: Response) => {
  // req.user is attached by protect middleware
  const userId = (req as Request & { user: { id: string } }).user.id;

  const staff = await prisma.staff.findUnique({
    where: { staff_id: BigInt(userId) },
    include: {
      administrativeStaff: true,
      manager: true,
      cashier: true,
      fieldOfficer: true,
      meterReader: true,
    },
  });

  if (!staff) {
    throw new AppError('User not found', 404);
  }

  const role = await determineStaffRole(staff.staff_id);

  res.status(200).send(
    JSON.stringify(
      {
        status: 'success',
        data: {
          user: {
            ...staff,
            staff_id: staff.staff_id.toString(),
            role,
          },
        },
      },
      bigIntSerializer
    )
  );
});

/**
 * Logout (client-side token removal)
 * For stateless JWT, logout is handled client-side
 *
 * @route POST /api/auth/logout
 * @returns { status, message }
 */
export const logout = asyncHandler(async (_req: Request, res: Response) => {
  // For JWT-based auth, logout is handled client-side by removing the token
  // This endpoint can be used to clear HTTP-only cookies if implemented
  res.status(200).json({
    status: 'success',
    message: 'Logged out successfully',
  });
});
