import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { PrismaClient } from '@prisma/client';
import { globalErrorHandler, notFoundHandler } from './middleware';
import { asyncHandler, NotFoundError } from './utils';
import {
  authRoutes,
  billingRoutes,
  paymentRoutes,
  customerRoutes,
} from './routes';

dotenv.config();

const app = express();
const prisma = new PrismaClient();
const PORT = process.env.PORT || 3001;

// ============================================
// Global BigInt JSON Serialization Patch
// ============================================
// This patches JSON.stringify to handle BigInt values globally
// Without this, any BigInt values will cause JSON serialization to crash
(BigInt.prototype as any).toJSON = function () {
  return this.toString();
};

// Middleware
app.use(cors());
app.use(express.json());

// BigInt serialization fix (for manual JSON.stringify calls)
const bigIntSerializer = (_key: string, value: unknown) =>
  typeof value === 'bigint' ? value.toString() : value;

// ============================================
// Routes
// ============================================

// Health check endpoint
app.get('/api/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Auth routes
app.use('/api/auth', authRoutes);

// Billing routes
app.use('/api/billing', billingRoutes);

// Payment routes
app.use('/api/payments', paymentRoutes);

// Customer routes
app.use('/api/customers', customerRoutes);

// Example endpoint using asyncHandler - no try-catch needed!
app.get(
  '/api/zones',
  asyncHandler(async (_req, res) => {
    const zones = await prisma.zone.findMany();
    // BigInt.toJSON() handles serialization automatically now
    res.json(zones);
  })
);

// Example: Get zone by ID with proper error handling
app.get(
  '/api/zones/:id',
  asyncHandler(async (req, res) => {
    const { id } = req.params;
    const zone = await prisma.zone.findUnique({
      where: { zone_id: BigInt(id) },
    });

    if (!zone) {
      throw NotFoundError(`Zone with ID ${id} not found`);
    }

    res.json(zone);
  })
);

// ============================================
// Error Handling (MUST be after all routes)
// ============================================

// Handle 404 - Route not found
app.use(notFoundHandler);

// Global error handler - catches all errors
app.use(globalErrorHandler);

// ============================================
// Server Startup
// ============================================

app.listen(PORT, () => {
  console.log(`🚀 Server running on http://localhost:${PORT}`);
  console.log(`📊 Environment: ${process.env.NODE_ENV || 'development'}`);
});

// Graceful shutdown
process.on('SIGINT', async () => {
  console.log('\n🛑 Shutting down gracefully...');
  await prisma.$disconnect();
  process.exit(0);
});

