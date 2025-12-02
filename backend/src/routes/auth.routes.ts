import { Router } from 'express';
import { login, getMe, logout } from '../controllers';
import { protect } from '../middleware';

const router = Router();

/**
 * @route   POST /api/auth/login
 * @desc    Authenticate staff and get token
 * @access  Public
 * @body    { employee_no: string }
 */
router.post('/login', login);

/**
 * @route   GET /api/auth/me
 * @desc    Get current logged in user
 * @access  Private
 */
router.get('/me', protect, getMe);

/**
 * @route   POST /api/auth/logout
 * @desc    Logout user (client-side token removal)
 * @access  Private
 */
router.post('/logout', protect, logout);

export default router;
