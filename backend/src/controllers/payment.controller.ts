import { Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { asyncHandler, BadRequestError, NotFoundError } from '../utils';
import { AuthenticatedRequest } from '../middleware/authMiddleware';

const prisma = new PrismaClient();

/**
 * Payment method type
 * Must match the CHECK constraint in the database
 */
type PaymentMethod = 'Cash' | 'Card' | 'Online' | 'Bank' | 'QR';

/**
 * Valid payment methods
 */
const VALID_PAYMENT_METHODS: PaymentMethod[] = [
  'Cash',
  'Card',
  'Online',
  'Bank',
  'QR',
];

/**
 * Create Payment
 * Records a payment for a bill
 *
 * @route POST /api/payments
 * @access Protected - CASHIER, ADMIN, MANAGER only
 *
 * @body {
 *   bill_id: number,
 *   payment_amount: number,
 *   payment_method: 'Cash' | 'Card' | 'Online' | 'Bank' | 'QR',
 *   payment_channel?: string,
 *   transaction_ref?: string
 * }
 *
 * @note The Bill status is automatically updated by a database trigger
 */
export const createPayment = asyncHandler<AuthenticatedRequest>(
  async (req: AuthenticatedRequest, res: Response) => {
    const {
      bill_id,
      payment_amount,
      payment_method,
      payment_channel,
      transaction_ref,
    } = req.body;

    // ============================================
    // Validation
    // ============================================

    // 1. Check required fields
    if (!bill_id) {
      throw BadRequestError('bill_id is required');
    }

    if (payment_amount === undefined || payment_amount === null) {
      throw BadRequestError('payment_amount is required');
    }

    if (!payment_method) {
      throw BadRequestError('payment_method is required');
    }

    // 2. Validate payment_amount > 0
    const amount = Number(payment_amount);
    if (isNaN(amount) || amount <= 0) {
      throw BadRequestError('payment_amount must be a positive number');
    }

    // 3. Validate payment_method is one of the allowed values
    if (!VALID_PAYMENT_METHODS.includes(payment_method as PaymentMethod)) {
      throw BadRequestError(
        `payment_method must be one of: ${VALID_PAYMENT_METHODS.join(', ')}`
      );
    }

    // 4. Check if bill exists
    const bill = await prisma.bill.findUnique({
      where: { bill_id: BigInt(bill_id) },
      select: {
        bill_id: true,
        status: true,
        net_amount: true,
      },
    });

    if (!bill) {
      throw NotFoundError(`Bill with ID ${bill_id} not found`);
    }

    // 5. Check if bill is already cancelled
    if (bill.status === 'Cancelled') {
      throw BadRequestError(
        'Cannot create payment for a cancelled bill'
      );
    }

    // 6. Check if bill is already fully paid
    if (bill.status === 'Paid') {
      throw BadRequestError(
        'Bill is already fully paid. Cannot accept additional payments.'
      );
    }

    // 7. Calculate outstanding amount
    const existingPayments = await prisma.payment.aggregate({
      where: { bill_id: BigInt(bill_id) },
      _sum: {
        payment_amount: true,
      },
    });

    const totalPaid = existingPayments._sum.payment_amount || 0;
    const outstanding = Number(bill.net_amount) - Number(totalPaid);

    // 8. Warn if payment exceeds outstanding (but allow it - business may handle overpayments)
    if (amount > outstanding) {
      // Optional: You could throw an error here if overpayments should be rejected
      // throw BadRequestError(`Payment amount (${amount}) exceeds outstanding amount (${outstanding})`);
      console.warn(
        `Payment amount (${amount}) exceeds outstanding amount (${outstanding}) for bill ${bill_id}`
      );
    }

    // ============================================
    // Create Payment
    // ============================================

    // Get staff ID from authenticated user
    const staffId = req.user.id;

    // Create payment record
    // NOTE: The database trigger will automatically update the bill status
    const payment = await prisma.payment.create({
      data: {
        bill_id: BigInt(bill_id),
        payment_date: new Date(),
        payment_amount: amount,
        payment_method,
        payment_channel: payment_channel || null,
        transaction_ref: transaction_ref || null,
        recorded_by_staff_id: BigInt(staffId),
      },
      include: {
        bill: {
          select: {
            bill_id: true,
            connection_id: true,
            net_amount: true,
            status: true,
          },
        },
        recordedByStaff: {
          select: {
            staff_id: true,
            employee_no: true,
            full_name: true,
          },
        },
      },
    });

    res.status(201).json({
      status: 'success',
      message: 'Payment recorded successfully',
      data: {
        payment,
      },
    });
  }
);

/**
 * Get Payments by Bill
 * Retrieves all payments for a specific bill
 *
 * @route GET /api/payments/bill/:billId
 * @access Protected
 */
export const getPaymentsByBill = asyncHandler<AuthenticatedRequest>(
  async (req: AuthenticatedRequest, res: Response) => {
    const { billId } = req.params;

    // Validate bill exists
    const bill = await prisma.bill.findUnique({
      where: { bill_id: BigInt(billId) },
      select: {
        bill_id: true,
        connection_id: true,
        net_amount: true,
        status: true,
      },
    });

    if (!bill) {
      throw NotFoundError(`Bill with ID ${billId} not found`);
    }

    // Fetch all payments for the bill
    const payments = await prisma.payment.findMany({
      where: { bill_id: BigInt(billId) },
      orderBy: {
        payment_date: 'desc',
      },
      include: {
        recordedByStaff: {
          select: {
            staff_id: true,
            employee_no: true,
            full_name: true,
          },
        },
      },
    });

    // Calculate payment summary
    const totalPaid = payments.reduce(
      (sum, payment) => sum + Number(payment.payment_amount),
      0
    );

    const outstanding = Number(bill.net_amount) - totalPaid;

    res.status(200).json({
      status: 'success',
      results: payments.length,
      data: {
        bill_summary: {
          bill_id: bill.bill_id.toString(),
          connection_id: bill.connection_id.toString(),
          net_amount: Number(bill.net_amount),
          total_paid: totalPaid,
          outstanding: outstanding > 0 ? outstanding : 0,
          status: bill.status,
        },
        payments,
      },
    });
  }
);

/**
 * Get Payment by ID
 * Retrieves a specific payment with full details
 *
 * @route GET /api/payments/:id
 * @access Protected
 */
export const getPaymentById = asyncHandler<AuthenticatedRequest>(
  async (req: AuthenticatedRequest, res: Response) => {
    const { id } = req.params;

    const payment = await prisma.payment.findUnique({
      where: { payment_id: BigInt(id) },
      include: {
        bill: {
          include: {
            connection: {
              include: {
                customer: {
                  select: {
                    customer_id: true,
                    full_name: true,
                    phone: true,
                    email: true,
                  },
                },
                zone: {
                  select: {
                    zone_id: true,
                    zone_name: true,
                  },
                },
              },
            },
          },
        },
        recordedByStaff: {
          select: {
            staff_id: true,
            employee_no: true,
            full_name: true,
            phone: true,
            email: true,
          },
        },
      },
    });

    if (!payment) {
      throw NotFoundError(`Payment with ID ${id} not found`);
    }

    res.status(200).json({
      status: 'success',
      data: {
        payment,
      },
    });
  }
);

/**
 * Get All Payments
 * Retrieves all payments with optional filters
 *
 * @route GET /api/payments
 * @access Protected
 *
 * @query {
 *   payment_method?: string,
 *   from_date?: string (YYYY-MM-DD),
 *   to_date?: string (YYYY-MM-DD),
 *   limit?: number (default: 50)
 * }
 */
export const getAllPayments = asyncHandler<AuthenticatedRequest>(
  async (req: AuthenticatedRequest, res: Response) => {
    const {
      payment_method,
      from_date,
      to_date,
      limit = '50',
    } = req.query;

    // Build where clause
    const where: any = {};

    if (payment_method) {
      where.payment_method = payment_method;
    }

    if (from_date || to_date) {
      where.payment_date = {};
      
      if (from_date) {
        where.payment_date.gte = new Date(from_date as string);
      }
      
      if (to_date) {
        // Add 1 day to include the entire end date
        const endDate = new Date(to_date as string);
        endDate.setDate(endDate.getDate() + 1);
        where.payment_date.lt = endDate;
      }
    }

    const payments = await prisma.payment.findMany({
      where,
      orderBy: {
        payment_date: 'desc',
      },
      take: parseInt(limit as string),
      include: {
        bill: {
          select: {
            bill_id: true,
            connection_id: true,
            net_amount: true,
          },
        },
        recordedByStaff: {
          select: {
            staff_id: true,
            employee_no: true,
            full_name: true,
          },
        },
      },
    });

    // Calculate total amount
    const totalAmount = payments.reduce(
      (sum, payment) => sum + Number(payment.payment_amount),
      0
    );

    res.status(200).json({
      status: 'success',
      results: payments.length,
      data: {
        summary: {
          total_payments: payments.length,
          total_amount: totalAmount,
        },
        payments,
      },
    });
  }
);

/**
 * Get Payment Statistics
 * Returns payment statistics for a date range
 *
 * @route GET /api/payments/stats
 * @access Protected
 *
 * @query {
 *   from_date?: string (YYYY-MM-DD),
 *   to_date?: string (YYYY-MM-DD)
 * }
 */
export const getPaymentStats = asyncHandler<AuthenticatedRequest>(
  async (req: AuthenticatedRequest, res: Response) => {
    const { from_date, to_date } = req.query;

    // Build date filter
    const dateFilter: any = {};
    
    if (from_date) {
      dateFilter.gte = new Date(from_date as string);
    }
    
    if (to_date) {
      const endDate = new Date(to_date as string);
      endDate.setDate(endDate.getDate() + 1);
      dateFilter.lt = endDate;
    }

    const where = Object.keys(dateFilter).length > 0 
      ? { payment_date: dateFilter }
      : {};

    // Get payment statistics
    const [totalStats, methodBreakdown] = await Promise.all([
      // Total amount and count
      prisma.payment.aggregate({
        where,
        _sum: {
          payment_amount: true,
        },
        _count: {
          payment_id: true,
        },
      }),
      
      // Breakdown by payment method
      prisma.payment.groupBy({
        by: ['payment_method'],
        where,
        _sum: {
          payment_amount: true,
        },
        _count: {
          payment_id: true,
        },
      }),
    ]);

    res.status(200).json({
      status: 'success',
      data: {
        period: {
          from: from_date || 'all time',
          to: to_date || 'present',
        },
        total: {
          count: totalStats._count.payment_id,
          amount: Number(totalStats._sum.payment_amount || 0),
        },
        by_method: methodBreakdown.map((method) => ({
          payment_method: method.payment_method,
          count: method._count.payment_id,
          amount: Number(method._sum.payment_amount || 0),
        })),
      },
    });
  }
);
