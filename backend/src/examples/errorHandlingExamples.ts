/**
 * Error Handling Examples
 * This file demonstrates how to use the error handling architecture
 * in your controllers and routes.
 *
 * NOTE: This is a reference file - do not import it directly into your app.
 */

import { Router, Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { asyncHandler, AppError, NotFoundError, BadRequestError } from '../utils';

const router = Router();
const prisma = new PrismaClient();

// BigInt serialization helper
const bigIntSerializer = (_key: string, value: unknown) =>
  typeof value === 'bigint' ? value.toString() : value;

/**
 * Example 1: Basic async handler usage
 * No try-catch needed - errors automatically forwarded to error middleware
 */
router.get(
  '/zones',
  asyncHandler(async (_req: Request, res: Response) => {
    const zones = await prisma.zone.findMany();
    res.send(JSON.stringify(zones, bigIntSerializer));
  })
);

/**
 * Example 2: Throwing custom AppError
 * Use when you need to return a specific error response
 */
router.get(
  '/zones/:id',
  asyncHandler(async (req: Request, res: Response) => {
    const { id } = req.params;

    // Validate ID format
    if (isNaN(Number(id))) {
      throw BadRequestError('Zone ID must be a number');
    }

    const zone = await prisma.zone.findUnique({
      where: { zone_id: BigInt(id) },
    });

    if (!zone) {
      throw NotFoundError(`Zone with ID ${id} not found`);
    }

    res.send(JSON.stringify(zone, bigIntSerializer));
  })
);

/**
 * Example 3: Prisma errors are automatically handled
 * P2002 (duplicate) and P2025 (not found) are converted to appropriate responses
 */
router.post(
  '/customers',
  asyncHandler(async (req: Request, res: Response) => {
    const { zone_id, full_name, identity_type, ...rest } = req.body;

    // Basic validation using AppError
    if (!full_name) {
      throw BadRequestError('Customer full_name is required');
    }

    // Prisma will throw P2002 if identity_ref already exists (handled by middleware)
    // Prisma will throw P2003 if zone_id doesn't exist (handled by middleware)
    const customer = await prisma.customer.create({
      data: {
        zone_id: BigInt(zone_id),
        full_name,
        identity_type: identity_type || 'NIC',
        address_line1: rest.address_line1 || '',
        city: rest.city || '',
        registration_date: new Date(),
        status: 'Active',
        ...rest,
      },
    });

    res.status(201).send(JSON.stringify(customer, bigIntSerializer));
  })
);

/**
 * Example 4: Update with automatic P2025 handling
 * If record doesn't exist, Prisma throws P2025 → 404 response
 */
router.patch(
  '/customers/:id',
  asyncHandler(async (req: Request, res: Response) => {
    const { id } = req.params;

    const customer = await prisma.customer.update({
      where: { customer_id: BigInt(id) },
      data: req.body,
    });

    res.send(JSON.stringify(customer, bigIntSerializer));
  })
);

/**
 * Example 5: Using AppError with custom status codes
 */
router.delete(
  '/customers/:id',
  asyncHandler(async (req: Request, res: Response) => {
    const { id } = req.params;

    // Check for related connections before deleting
    const connections = await prisma.connection.findFirst({
      where: { customer_id: BigInt(id) },
    });

    if (connections) {
      throw new AppError(
        'Cannot delete customer with active connections. Please close all connections first.',
        409 // Conflict
      );
    }

    await prisma.customer.delete({
      where: { customer_id: BigInt(id) },
    });

    res.status(204).send();
  })
);

/**
 * Example 6: Calling stored procedures with error handling
 * Complex billing logic uses SQL stored procedures per your constraints
 */
router.post(
  '/bills/generate',
  asyncHandler(async (req: Request, res: Response) => {
    const {
      connection_id,
      billing_period_start,
      billing_period_end,
      bill_date,
      due_date,
      generated_by_staff_id,
    } = req.body;

    // Validate required fields
    if (!connection_id || !billing_period_start || !billing_period_end) {
      throw BadRequestError(
        'connection_id, billing_period_start, and billing_period_end are required'
      );
    }

    // Call SQL stored procedure using $executeRawUnsafe
    // NOTE: The SP handles all billing calculation logic in SQL
    await prisma.$executeRawUnsafe(
      `EXEC dbo.sp_GenerateBillForConnection 
        @connection_id = ${connection_id},
        @billing_period_start = '${billing_period_start}',
        @billing_period_end = '${billing_period_end}',
        @bill_date = '${bill_date}',
        @due_date = '${due_date}',
        @generated_by_staff_id = ${generated_by_staff_id || 'NULL'}`
    );

    res.status(201).json({
      status: 'success',
      message: 'Bill generated successfully',
    });
  })
);

/**
 * Example 7: Querying stored procedures that return data
 */
router.get(
  '/reports/defaulters',
  asyncHandler(async (req: Request, res: Response) => {
    const { as_of_date } = req.query;

    if (!as_of_date) {
      throw BadRequestError('as_of_date query parameter is required');
    }

    // Call SP that returns data using $queryRawUnsafe
    const defaulters = await prisma.$queryRawUnsafe(
      `EXEC dbo.sp_ListDefaulters @as_of_date = '${as_of_date}'`
    );

    res.send(JSON.stringify(defaulters, bigIntSerializer));
  })
);

export default router;
