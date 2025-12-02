// Controllers barrel export
export { login, getMe, logout } from './auth.controller';
export {
  generateBill,
  getUnpaidBills,
  getDefaulters,
  getBillById,
  getBillsByConnection,
} from './billing.controller';
export {
  createPayment,
  getPaymentsByBill,
  getPaymentById,
  getAllPayments,
  getPaymentStats,
} from './payment.controller';
export { searchCustomers, getCustomerProfile } from './customer.controller';
