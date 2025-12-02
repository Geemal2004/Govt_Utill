import { Router } from 'express';
import { searchCustomers, getCustomerProfile } from '../controllers/customer.controller';
import { protect } from '../middleware/authMiddleware';

const router = Router();

// All customer routes require authentication
router.use(protect);

/**
 * @route   GET /api/customers/search?q=...
 * @desc    Search for customers by name, NIC, or ID
 * @access  Protected (All Staff)
 */
router.get('/search', searchCustomers);

/**
 * @route   GET /api/customers/:id
 * @desc    Get comprehensive customer profile (for Customer Dashboard)
 * @access  Protected (All Staff)
 */
router.get('/:id', getCustomerProfile);

export default router;
