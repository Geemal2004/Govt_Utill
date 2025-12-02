import { Router } from 'express';
import {
  generateBill,
  getUnpaidBills,
  getDefaulters,
  getBillById,
  getBillsByConnection,
} from '../controllers/billing.controller';
import { protect, restrictTo } from '../middleware/authMiddleware';

const router = Router();

/**
 * All billing routes require authentication
 */
router.use(protect);

/**
 * @route   POST /api/billing/generate
 * @desc    Generate bill for a connection using stored procedure
 * @access  Protected - ADMIN, MANAGER only
 * @body    { connection_id: number, bill_date?: string }
 */
router.post('/generate', restrictTo('ADMIN', 'MANAGER'), generateBill);

/**
 * @route   GET /api/billing/unpaid
 * @desc    Get all unpaid bills (queries vw_UnpaidBills view)
 * @access  Protected
 * @query   zone_id?: number, utility_type?: string
 */
router.get('/unpaid', getUnpaidBills);

/**
 * @route   GET /api/billing/defaulters
 * @desc    Get defaulters report using stored procedure
 * @access  Protected
 * @query   as_of_date?: string (YYYY-MM-DD)
 */
router.get('/defaulters', getDefaulters);

/**
 * @route   GET /api/billing/:id
 * @desc    Get bill by ID with full details
 * @access  Protected
 */
router.get('/:id', getBillById);

/**
 * @route   GET /api/billing/connection/:connectionId
 * @desc    Get all bills for a connection
 * @access  Protected
 * @query   status?: string, limit?: number
 */
router.get('/connection/:connectionId', getBillsByConnection);

export { router as billingRoutes };
