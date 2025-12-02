import { Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { AuthenticatedRequest } from '../middleware/authMiddleware';
import { asyncHandler, BadRequestError, NotFoundError } from '../utils';

const prisma = new PrismaClient();

/**
 * @desc    Search for customers by name, identity reference, or customer ID
 * @route   GET /api/customers/search
 * @access  Protected (All Staff)
 */
export const searchCustomers = asyncHandler<AuthenticatedRequest>(
  async (req: AuthenticatedRequest, res: Response) => {
    const { q } = req.query;

    // Validation: search query required
    if (!q || typeof q !== 'string') {
      throw BadRequestError('Search query parameter "q" is required');
    }

    const searchTerm = q.trim();

    if (searchTerm.length === 0) {
      throw BadRequestError('Search query cannot be empty');
    }

    // Check if search term is a number (potential customer_id)
    const isNumericSearch = /^\d+$/.test(searchTerm);
    const customerId = isNumericSearch ? BigInt(searchTerm) : null;

    // Build search filters
    const searchFilters = [];

    // Search by full_name (partial match)
    searchFilters.push({
      full_name: {
        contains: searchTerm,
      },
    });

    // Search by identity_ref (partial match)
    searchFilters.push({
      identity_ref: {
        contains: searchTerm,
      },
    });

    // Search by exact customer_id if numeric
    if (customerId !== null) {
      searchFilters.push({
        customer_id: customerId,
      });
    }

    // Execute search query
    const customers = await prisma.customer.findMany({
      where: {
        OR: searchFilters,
      },
      select: {
        customer_id: true,
        full_name: true,
        address_line1: true,
        address_line2: true,
        city: true,
        postal_code: true,
        identity_ref: true,
        phone: true,
        email: true,
        status: true,
        registration_date: true,
      },
      orderBy: {
        full_name: 'asc',
      },
      take: 50, // Limit results to prevent excessive data
    });

    res.status(200).json({
      status: 'success',
      results: customers.length,
      data: {
        customers: customers.map((customer) => ({
          customer_id: customer.customer_id.toString(),
          full_name: customer.full_name,
          address: {
            line1: customer.address_line1,
            line2: customer.address_line2 || null,
            city: customer.city,
            postal_code: customer.postal_code || null,
          },
          identity_ref: customer.identity_ref,
          phone: customer.phone,
          email: customer.email,
          status: customer.status,
          registration_date: customer.registration_date,
        })),
      },
    });
  }
);

/**
 * @desc    Get comprehensive customer profile with connections and subsidies
 * @route   GET /api/customers/:id
 * @access  Protected (All Staff)
 */
export const getCustomerProfile = asyncHandler<AuthenticatedRequest>(
  async (req: AuthenticatedRequest, res: Response) => {
    const { id } = req.params;

    // Validation: customer ID required
    if (!id) {
      throw BadRequestError('Customer ID is required');
    }

    // Parse customer ID
    let customerId: bigint;
    try {
      customerId = BigInt(id);
    } catch (error) {
      throw BadRequestError('Invalid customer ID format');
    }

    // Fetch customer with comprehensive relations
    const customer = await prisma.customer.findUnique({
      where: {
        customer_id: customerId,
      },
      include: {
        // Include all connections for this customer
        connections: {
          include: {
            // For each connection, include zone and tariff info
            zone: {
              select: {
                zone_id: true,
                zone_name: true,
                region: true,
              },
            },
            tariffCategory: {
              select: {
                tariff_category_id: true,
                name: true,
                code: true,
                utility_type: true,
                is_subsidized: true,
              },
            },
            // Include the active meters for each connection
            meters: {
              where: {
                status: 'Active',
              },
              orderBy: {
                installed_from: 'desc',
              },
              take: 1, // Only get the most recent active meter
              select: {
                meter_id: true,
                meter_serial_no: true,
                meter_type: true,
                meter_role: true,
                status: true,
                installed_from: true,
                is_smart_meter: true,
              },
            },
            // Include bills count and latest bill
            bills: {
              orderBy: {
                billing_period_start: 'desc',
              },
              take: 1,
              select: {
                bill_id: true,
                billing_period_start: true,
                billing_period_end: true,
                net_amount: true,
                status: true,
                due_date: true,
              },
            },
          },
          orderBy: {
            start_date: 'desc',
          },
        },
        // Include active customer subsidies
        subsidies: {
          where: {
            status: 'Active',
          },
          include: {
            subsidyScheme: {
              select: {
                subsidy_id: true,
                name: true,
                discount_type: true,
                discount_value: true,
                description: true,
              },
            },
          },
          orderBy: {
            approved_date: 'desc',
          },
        },
      },
    });

    // Check if customer exists
    if (!customer) {
      throw NotFoundError(`Customer with ID ${id} not found`);
    }

    // Calculate summary statistics
    const activeConnections = customer.connections.filter(
      (conn) => conn.connection_status === 'Active'
    ).length;

    const totalConnections = customer.connections.length;

    const activeSubsidies = customer.subsidies.length;

    // Calculate total outstanding amount across all bills
    let totalOutstanding = 0;
    for (const connection of customer.connections) {
      if (connection.bills.length > 0) {
        const latestBill = connection.bills[0];
        if (
          latestBill.status !== 'Paid' &&
          latestBill.status !== 'Cancelled'
        ) {
          // Fetch payments for this bill to calculate outstanding
          const payments = await prisma.payment.findMany({
            where: {
              bill_id: latestBill.bill_id,
            },
            select: {
              payment_amount: true,
            },
          });

          const totalPaid = payments.reduce(
            (sum, payment) => sum + Number(payment.payment_amount),
            0
          );

          const outstanding = Number(latestBill.net_amount) - totalPaid;
          if (outstanding > 0) {
            totalOutstanding += outstanding;
          }
        }
      }
    }

    // Format response
    const response = {
      customer_id: customer.customer_id.toString(),
      full_name: customer.full_name,
      address: {
        line1: customer.address_line1,
        line2: customer.address_line2 || null,
        city: customer.city,
        postal_code: customer.postal_code || null,
      },
      identity_type: customer.identity_type,
      identity_ref: customer.identity_ref,
      phone: customer.phone || null,
      email: customer.email || null,
      status: customer.status,
      registration_date: customer.registration_date,

      // Summary statistics
      summary: {
        total_connections: totalConnections,
        active_connections: activeConnections,
        active_subsidies: activeSubsidies,
        total_outstanding: totalOutstanding,
      },

      // Connections with their meters and latest bill
      connections: customer.connections.map((connection) => ({
        connection_id: connection.connection_id.toString(),
        start_date: connection.start_date,
        status: connection.connection_status,
        service_address: connection.service_address,
        utility_type: connection.utility_type,

        // Zone information
        zone: connection.zone
          ? {
              zone_id: connection.zone.zone_id.toString(),
              zone_name: connection.zone.zone_name,
              region: connection.zone.region,
            }
          : null,

        // Tariff information
        tariff: connection.tariffCategory
          ? {
              tariff_category_id:
                connection.tariffCategory.tariff_category_id.toString(),
              name: connection.tariffCategory.name,
              code: connection.tariffCategory.code,
              utility_type: connection.tariffCategory.utility_type,
              is_subsidized: connection.tariffCategory.is_subsidized,
            }
          : null,

        // Active meter
        active_meter:
          connection.meters.length > 0
            ? {
                meter_id: connection.meters[0].meter_id.toString(),
                meter_serial_no: connection.meters[0].meter_serial_no,
                meter_type: connection.meters[0].meter_type,
                meter_role: connection.meters[0].meter_role,
                status: connection.meters[0].status,
                installed_from: connection.meters[0].installed_from,
                is_smart_meter: connection.meters[0].is_smart_meter,
              }
            : null,

        // Latest bill
        latest_bill:
          connection.bills.length > 0
            ? {
                bill_id: connection.bills[0].bill_id.toString(),
                billing_period: {
                  start: connection.bills[0].billing_period_start,
                  end: connection.bills[0].billing_period_end,
                },
                net_amount: Number(connection.bills[0].net_amount),
                status: connection.bills[0].status,
                due_date: connection.bills[0].due_date,
              }
            : null,
      })),

      // Active subsidies
      subsidies: customer.subsidies.map((cs) => ({
        customer_subsidy_id: cs.customer_subsidy_id.toString(),
        approved_date: cs.approved_date,
        status: cs.status,
        subsidy: {
          subsidy_id: cs.subsidyScheme.subsidy_id.toString(),
          name: cs.subsidyScheme.name,
          discount_type: cs.subsidyScheme.discount_type,
          discount_value: Number(cs.subsidyScheme.discount_value),
          description: cs.subsidyScheme.description,
        },
      })),
    };

    res.status(200).json({
      status: 'success',
      data: {
        customer: response,
      },
    });
  }
);
