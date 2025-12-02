import { Router } from 'express';
import {
  createPayment,
  getPaymentsByBill,
  getPaymentById,
  getAllPayments,
  getPaymentStats,
} from '../controllers/payment.controller';
import { protect, restrictTo } from '../middleware/authMiddleware';

const router = Router();

/**
 * All payment routes require authentication
 */
router.use(protect);

/**
 * @route   POST /api/payments
 * @desc    Create a new payment for a bill
 * @access  Protected - CASHIER, ADMIN, MANAGER only
 * @body    {
 *            bill_id: number,
 *            payment_amount: number,
 *            payment_method: 'Cash' | 'Card' | 'Online' | 'Bank' | 'QR',
 *            payment_channel?: string,
 *            transaction_ref?: string
 *          }
 * @note    Bill status is automatically updated by database trigger
 */
router.post('/', restrictTo('CASHIER', 'ADMIN', 'MANAGER'), createPayment);

/**
 * @route   GET /api/payments/stats
 * @desc    Get payment statistics for a date range
 * @access  Protected
 * @query   from_date?: string, to_date?: string
 */
router.get('/stats', getPaymentStats);

/**
 * @route   GET /api/payments/bill/:billId
 * @desc    Get all payments for a specific bill
 * @access  Protected
 */
router.get('/bill/:billId', getPaymentsByBill);

/**
 * @route   GET /api/payments/:id
 * @desc    Get payment by ID with full details
 * @access  Protected
 */
router.get('/:id', getPaymentById);

/**
 * @route   GET /api/payments
 * @desc    Get all payments with optional filters
 * @access  Protected
 * @query   payment_method?: string, from_date?: string, to_date?: string, limit?: number
 */
router.get('/', getAllPayments);

export { router as paymentRoutes };
