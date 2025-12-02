import { Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { asyncHandler, BadRequestError } from '../utils';
import { AuthenticatedRequest } from '../middleware/authMiddleware';

const prisma = new PrismaClient();

/**
 * Helper function to calculate billing period dates
 */
const calculateBillingDates = (billDateStr: string) => {
  const billDate = new Date(billDateStr);

  // Period start: 1st of the month
  const periodStart = new Date(billDate.getFullYear(), billDate.getMonth(), 1);

  // Period end: Last day of the month
  const periodEnd = new Date(
    billDate.getFullYear(),
    billDate.getMonth() + 1,
    0
  );

  // Due date: bill_date + 14 days
  const dueDate = new Date(billDate);
  dueDate.setDate(dueDate.getDate() + 14);

  // Format dates as YYYY-MM-DD for SQL Server
  const formatDate = (date: Date): string => {
    return date.toISOString().split('T')[0];
  };

  return {
    periodStart: formatDate(periodStart),
    periodEnd: formatDate(periodEnd),
    billDate: formatDate(billDate),
    dueDate: formatDate(dueDate),
  };
};

/**
 * Generate Bill for Connection
 * Calls stored procedure sp_GenerateBillForConnection
 *
 * @route POST /api/billing/generate
 * @access Protected - ADMIN, MANAGER only
 *
 * @body {
 *   connection_id: number,
 *   bill_date: string (YYYY-MM-DD, optional - defaults to today)
 * }
 */
export const generateBill = asyncHandler(
  async (req: AuthenticatedRequest, res: Response) => {
    const { connection_id, bill_date } = req.body;

    // Validation
    if (!connection_id) {
      throw BadRequestError('connection_id is required');
    }

    // Use provided bill_date or default to today
    const billDateStr = bill_date || new Date().toISOString().split('T')[0];

    // Calculate dates
    const { periodStart, periodEnd, billDate, dueDate } =
      calculateBillingDates(billDateStr);

    // Get staff ID from authenticated user
    const staffId = req.user.id;

    // Call stored procedure using $executeRawUnsafe
    // NOTE: All billing calculation logic is in the SQL stored procedure
    await prisma.$executeRawUnsafe(
      `EXEC dbo.sp_GenerateBillForConnection 
        @connection_id = ${connection_id},
        @billing_period_start = '${periodStart}',
        @billing_period_end = '${periodEnd}',
        @bill_date = '${billDate}',
        @due_date = '${dueDate}',
        @generated_by_staff_id = ${staffId}`
    );

    res.status(201).json({
      status: 'success',
      message: 'Bill generated successfully',
      data: {
        connection_id,
        billing_period: {
          start: periodStart,
          end: periodEnd,
        },
        bill_date: billDate,
        due_date: dueDate,
      },
    });
  }
);

/**
 * Get Unpaid Bills
 * Queries the vw_UnpaidBills view
 *
 * @route GET /api/billing/unpaid
 * @access Protected
 *
 * @query {
 *   zone_id?: number (optional filter),
 *   utility_type?: string (optional filter: Electricity, Water, Gas)
 * }
 */
export const getUnpaidBills = asyncHandler(
  async (req: AuthenticatedRequest, res: Response) => {
    const { zone_id, utility_type } = req.query;

    // Build dynamic WHERE clause
    let whereClause = '';
    const conditions: string[] = [];

    if (zone_id) {
      conditions.push(`zone_id = ${zone_id}`);
    }

    if (utility_type) {
      conditions.push(`utility_type = '${utility_type}'`);
    }

    if (conditions.length > 0) {
      whereClause = `WHERE ${conditions.join(' AND ')}`;
    }

    // Query the view using $queryRawUnsafe
    const unpaidBills = await prisma.$queryRawUnsafe<any[]>(
      `SELECT * FROM dbo.vw_UnpaidBills ${whereClause} ORDER BY due_date ASC`
    );

    res.status(200).json({
      status: 'success',
      results: unpaidBills.length,
      data: {
        bills: unpaidBills,
      },
    });
  }
);

/**
 * Get Defaulters Report
 * Calls stored procedure sp_ListDefaulters
 *
 * @route GET /api/billing/defaulters
 * @access Protected
 *
 * @query {
 *   as_of_date?: string (YYYY-MM-DD, optional - defaults to today)
 * }
 */
export const getDefaulters = asyncHandler(
  async (req: AuthenticatedRequest, res: Response) => {
    // Get as_of_date from query or default to today
    const asOfDate =
      (req.query.as_of_date as string) ||
      new Date().toISOString().split('T')[0];

    // Validate date format (basic check)
    const dateRegex = /^\d{4}-\d{2}-\d{2}$/;
    if (!dateRegex.test(asOfDate)) {
      throw BadRequestError(
        'Invalid date format. Use YYYY-MM-DD (e.g., 2025-12-02)'
      );
    }

    // Call stored procedure using $queryRawUnsafe
    // NOTE: All defaulter calculation logic is in the SQL stored procedure
    const defaulters = await prisma.$queryRawUnsafe<any[]>(
      `EXEC dbo.sp_ListDefaulters @as_of_date = '${asOfDate}'`
    );

    res.status(200).json({
      status: 'success',
      as_of_date: asOfDate,
      results: defaulters.length,
      data: {
        defaulters,
      },
    });
  }
);

/**
 * Get Bill by ID
 * Fetch specific bill details with related data
 *
 * @route GET /api/billing/:id
 * @access Protected
 */
export const getBillById = asyncHandler(
  async (req: AuthenticatedRequest, res: Response) => {
    const { id } = req.params;

    const bill = await prisma.bill.findUnique({
      where: { bill_id: BigInt(id) },
      include: {
        connection: {
          include: {
            customer: true,
            zone: true,
            tariffCategory: true,
          },
        },
        meter: true,
        billDetails: {
          include: {
            tariffSlab: true,
          },
        },
        billTaxes: {
          include: {
            taxConfig: true,
          },
        },
        payments: true,
        generatedByStaff: {
          select: {
            staff_id: true,
            employee_no: true,
            full_name: true,
          },
        },
      },
    });

    if (!bill) {
      throw new (require('../utils').NotFoundError)(`Bill with ID ${id} not found`);
    }

    res.status(200).json({
      status: 'success',
      data: {
        bill,
      },
    });
  }
);

/**
 * Get Bills by Connection ID
 * Fetch all bills for a specific connection
 *
 * @route GET /api/billing/connection/:connectionId
 * @access Protected
 */
export const getBillsByConnection = asyncHandler(
  async (req: AuthenticatedRequest, res: Response) => {
    const { connectionId } = req.params;
    const { status, limit = '10' } = req.query;

    // Build where clause
    const where: any = {
      connection_id: BigInt(connectionId),
    };

    if (status) {
      where.status = status;
    }

    const bills = await prisma.bill.findMany({
      where,
      orderBy: {
        bill_date: 'desc',
      },
      take: parseInt(limit as string),
      include: {
        payments: true,
      },
    });

    res.status(200).json({
      status: 'success',
      results: bills.length,
      data: {
        bills,
      },
    });
  }
);
