/**
 * Authentication Configuration
 * Exports JWT settings from environment variables
 */

// Validate required environment variables
if (!process.env.JWT_SECRET) {
  console.warn(
    '⚠️  JWT_SECRET is not set in environment variables. Using default (not secure for production).'
  );
}

/**
 * JWT Secret for signing tokens
 * IMPORTANT: Set this in .env file for production
 */
export const JWT_SECRET: string =
  process.env.JWT_SECRET || 'dev-secret-change-in-production';

/**
 * JWT Token expiration time
 * Examples: '1h', '7d', '30d'
 */
export const JWT_EXPIRES_IN: string = process.env.JWT_EXPIRES_IN || '7d';

/**
 * Staff role types based on subtype tables
 */
export type StaffRole =
  | 'ADMIN'
  | 'MANAGER'
  | 'CASHIER'
  | 'METER_READER'
  | 'FIELD_OFFICER'
  | 'STAFF';

/**
 * JWT Payload interface
 */
export interface JwtPayload {
  id: string; // staff_id as string (BigInt serialized)
  employeeNo: string;
  role: StaffRole;
  iat?: number;
  exp?: number;
}
