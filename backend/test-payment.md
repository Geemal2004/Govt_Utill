# Payment API Testing Guide

## Prerequisites
1. Server running on `http://localhost:3001`
2. Valid JWT token from login (see `test-auth.md`)
3. Database with sample bills (see `test-billing.md`)

---

## 🔐 Step 1: Get Authentication Token

### Login as Cashier (Authorized for payments)
```powershell
# Login as Cashier
$cashier = Invoke-RestMethod -Uri "http://localhost:3001/api/auth/login" -Method POST -ContentType "application/json" -Body '{"employee_no": "EMP-CS-031"}'

# Extract token
$token = $cashier.token
Write-Host "Cashier Token: $token"

# Setup headers
$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}
```

### Login as Admin (Also authorized)
```powershell
$admin = Invoke-RestMethod -Uri "http://localhost:3001/api/auth/login" -Method POST -ContentType "application/json" -Body '{"employee_no": "EMP-ADM-001"}'
$adminToken = $admin.token
$adminHeaders = @{
    "Authorization" = "Bearer $adminToken"
    "Content-Type" = "application/json"
}
```

---

## 💳 Step 2: Test Payment Endpoints

### 2.1 Create Payment (POST /api/payments)

**Access:** CASHIER, ADMIN, MANAGER only

#### Example 1: Cash Payment
```powershell
$payment1 = @{
    bill_id = 1
    payment_amount = 2000.50
    payment_method = "Cash"
    payment_channel = "Branch"
} | ConvertTo-Json

$result1 = Invoke-RestMethod -Uri "http://localhost:3001/api/payments" -Method POST -Headers $headers -Body $payment1

Write-Host "Payment Created:"
$result1 | ConvertTo-Json -Depth 10
```

**Expected Response:**
```json
{
  "status": "success",
  "message": "Payment recorded successfully",
  "data": {
    "payment": {
      "payment_id": "1",
      "bill_id": "1",
      "payment_date": "2025-12-02T10:48:00.000Z",
      "payment_amount": 2000.50,
      "payment_method": "Cash",
      "payment_channel": "Branch",
      "transaction_ref": null,
      "recorded_by_staff_id": "31",
      "bill": {
        "bill_id": "1",
        "connection_id": "1",
        "net_amount": 8394.00,
        "status": "Partially_Paid"
      },
      "recordedByStaff": {
        "staff_id": "31",
        "employee_no": "EMP-CS-031",
        "full_name": "Ravindu Silva"
      }
    }
  }
}
```

#### Example 2: Card Payment with Transaction Reference
```powershell
$payment2 = @{
    bill_id = 1
    payment_amount = 5000.00
    payment_method = "Card"
    payment_channel = "POS Terminal"
    transaction_ref = "CARD-TXN-20251202-001"
} | ConvertTo-Json

$result2 = Invoke-RestMethod -Uri "http://localhost:3001/api/payments" -Method POST -Headers $headers -Body $payment2

Write-Host "Card Payment:"
$result2 | ConvertTo-Json -Depth 10
```

#### Example 3: Online Payment
```powershell
$payment3 = @{
    bill_id = 3
    payment_amount = 1500.00
    payment_method = "Online"
    payment_channel = "Mobile App"
    transaction_ref = "APP-PAY-20251202-002"
} | ConvertTo-Json

$result3 = Invoke-RestMethod -Uri "http://localhost:3001/api/payments" -Method POST -Headers $headers -Body $payment3
```

#### Example 4: Bank Transfer
```powershell
$payment4 = @{
    bill_id = 5
    payment_amount = 55000.00
    payment_method = "Bank"
    payment_channel = "Internet Banking"
    transaction_ref = "BANK-REF-123456789"
} | ConvertTo-Json

$result4 = Invoke-RestMethod -Uri "http://localhost:3001/api/payments" -Method POST -Headers $headers -Body $payment4
```

#### Example 5: QR Code Payment
```powershell
$payment5 = @{
    bill_id = 7
    payment_amount = 1687.00
    payment_method = "QR"
    payment_channel = "Mobile App"
    transaction_ref = "QR-SCAN-987654321"
} | ConvertTo-Json

$result5 = Invoke-RestMethod -Uri "http://localhost:3001/api/payments" -Method POST -Headers $headers -Body $payment5
```

---

### 2.2 Get Payments by Bill (GET /api/payments/bill/:billId)

```powershell
# Get all payments for bill_id = 1
$billPayments = Invoke-RestMethod -Uri "http://localhost:3001/api/payments/bill/1" -Headers $headers

Write-Host "Payments for Bill 1:"
$billPayments | ConvertTo-Json -Depth 10
```

**Expected Response:**
```json
{
  "status": "success",
  "results": 2,
  "data": {
    "bill_summary": {
      "bill_id": "1",
      "connection_id": "1",
      "net_amount": 8394.00,
      "total_paid": 7000.50,
      "outstanding": 1393.50,
      "status": "Partially_Paid"
    },
    "payments": [
      {
        "payment_id": "2",
        "bill_id": "1",
        "payment_date": "2025-12-02T10:50:00.000Z",
        "payment_amount": 5000.00,
        "payment_method": "Card",
        "payment_channel": "POS Terminal",
        "transaction_ref": "CARD-TXN-20251202-001",
        "recordedByStaff": {
          "staff_id": "31",
          "employee_no": "EMP-CS-031",
          "full_name": "Ravindu Silva"
        }
      },
      {
        "payment_id": "1",
        "bill_id": "1",
        "payment_date": "2025-12-02T10:48:00.000Z",
        "payment_amount": 2000.50,
        "payment_method": "Cash",
        "payment_channel": "Branch",
        "transaction_ref": null,
        "recordedByStaff": {
          "staff_id": "31",
          "employee_no": "EMP-CS-031",
          "full_name": "Ravindu Silva"
        }
      }
    ]
  }
}
```

---

### 2.3 Get Payment by ID (GET /api/payments/:id)

```powershell
# Get specific payment with full details
$paymentDetail = Invoke-RestMethod -Uri "http://localhost:3001/api/payments/1" -Headers $headers

Write-Host "Payment Details:"
$paymentDetail | ConvertTo-Json -Depth 10
```

**Expected Response:** Full payment object with:
- Bill details
- Connection details
- Customer information
- Zone information
- Staff who recorded the payment

---

### 2.4 Get All Payments (GET /api/payments)

```powershell
# Get all payments (default limit: 50)
$allPayments = Invoke-RestMethod -Uri "http://localhost:3001/api/payments" -Headers $headers

Write-Host "All Payments:"
$allPayments | ConvertTo-Json -Depth 5

# Filter by payment method
$cashPayments = Invoke-RestMethod -Uri "http://localhost:3001/api/payments?payment_method=Cash" -Headers $headers

# Filter by date range
$todayPayments = Invoke-RestMethod -Uri "http://localhost:3001/api/payments?from_date=2025-12-02&to_date=2025-12-02" -Headers $headers

# Limit results
$recentPayments = Invoke-RestMethod -Uri "http://localhost:3001/api/payments?limit=10" -Headers $headers
```

---

### 2.5 Get Payment Statistics (GET /api/payments/stats)

```powershell
# Get stats for today
$todayStats = Invoke-RestMethod -Uri "http://localhost:3001/api/payments/stats?from_date=2025-12-02&to_date=2025-12-02" -Headers $headers

Write-Host "Today's Payment Statistics:"
$todayStats | ConvertTo-Json -Depth 10

# Get stats for the month
$monthStats = Invoke-RestMethod -Uri "http://localhost:3001/api/payments/stats?from_date=2025-12-01&to_date=2025-12-31" -Headers $headers

# Get all-time stats
$allTimeStats = Invoke-RestMethod -Uri "http://localhost:3001/api/payments/stats" -Headers $headers
```

**Expected Response:**
```json
{
  "status": "success",
  "data": {
    "period": {
      "from": "2025-12-02",
      "to": "2025-12-02"
    },
    "total": {
      "count": 5,
      "amount": 65187.50
    },
    "by_method": [
      {
        "payment_method": "Cash",
        "count": 1,
        "amount": 2000.50
      },
      {
        "payment_method": "Card",
        "count": 1,
        "amount": 5000.00
      },
      {
        "payment_method": "Online",
        "count": 1,
        "amount": 1500.00
      },
      {
        "payment_method": "Bank",
        "count": 1,
        "amount": 55000.00
      },
      {
        "payment_method": "QR",
        "count": 1,
        "amount": 1687.00
      }
    ]
  }
}
```

---

## 🧪 Test Scenarios

### Scenario 1: Complete Payment Workflow

```powershell
# 1. Login as Cashier
$cashier = Invoke-RestMethod -Uri "http://localhost:3001/api/auth/login" -Method POST -ContentType "application/json" -Body '{"employee_no": "EMP-CS-031"}'
$token = $cashier.token
$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}

# 2. Find unpaid bills
$unpaidBills = Invoke-RestMethod -Uri "http://localhost:3001/api/billing/unpaid" -Headers $headers
Write-Host "Found $($unpaidBills.results) unpaid bills"

# 3. Select first unpaid bill
$billToPay = $unpaidBills.data.bills[0]
Write-Host "Paying bill: $($billToPay.bill_id) - Outstanding: $($billToPay.outstanding_amount)"

# 4. Create payment
$payment = @{
    bill_id = [int]$billToPay.bill_id
    payment_amount = [decimal]$billToPay.outstanding_amount
    payment_method = "Cash"
    payment_channel = "Branch"
} | ConvertTo-Json

$paymentResult = Invoke-RestMethod -Uri "http://localhost:3001/api/payments" -Method POST -Headers $headers -Body $payment

# 5. Verify payment was recorded
$billPayments = Invoke-RestMethod -Uri "http://localhost:3001/api/payments/bill/$($billToPay.bill_id)" -Headers $headers
Write-Host "Bill Status: $($billPayments.data.bill_summary.status)"
Write-Host "Outstanding: $($billPayments.data.bill_summary.outstanding)"

Write-Host "✅ Payment workflow completed successfully"
```

---

### Scenario 2: Partial Payment Workflow

```powershell
# Pay bill in multiple installments
$billId = 3
$totalOutstanding = 7350.50

# Payment 1: Pay half
$payment1 = @{
    bill_id = $billId
    payment_amount = 3675.25
    payment_method = "Cash"
} | ConvertTo-Json

$result1 = Invoke-RestMethod -Uri "http://localhost:3001/api/payments" -Method POST -Headers $headers -Body $payment1
Write-Host "First payment recorded. Status: $($result1.data.payment.bill.status)"

# Check remaining balance
$billInfo = Invoke-RestMethod -Uri "http://localhost:3001/api/payments/bill/$billId" -Headers $headers
Write-Host "Remaining outstanding: $($billInfo.data.bill_summary.outstanding)"

# Payment 2: Pay remaining
$payment2 = @{
    bill_id = $billId
    payment_amount = $billInfo.data.bill_summary.outstanding
    payment_method = "Card"
    transaction_ref = "CARD-FINAL-PAYMENT"
} | ConvertTo-Json

$result2 = Invoke-RestMethod -Uri "http://localhost:3001/api/payments" -Method POST -Headers $headers -Body $payment2
Write-Host "Final payment recorded. Status: $($result2.data.payment.bill.status)"

Write-Host "✅ Partial payment workflow completed"
```

---

### Scenario 3: Test Role-Based Access Control

```powershell
# Login as Meter Reader (not authorized for payments)
$reader = Invoke-RestMethod -Uri "http://localhost:3001/api/auth/login" -Method POST -ContentType "application/json" -Body '{"employee_no": "EMP-MR-011"}'
$readerToken = $reader.token
$readerHeaders = @{
    "Authorization" = "Bearer $readerToken"
    "Content-Type" = "application/json"
}

# Try to create payment (should fail with 403 Forbidden)
try {
    $failPayment = @{
        bill_id = 1
        payment_amount = 100.00
        payment_method = "Cash"
    } | ConvertTo-Json
    
    Invoke-RestMethod -Uri "http://localhost:3001/api/payments" -Method POST -Headers $readerHeaders -Body $failPayment
    Write-Host "❌ ERROR: Should have been forbidden!"
} catch {
    Write-Host "✅ Correctly forbidden: $($_.Exception.Message)"
}

# Can view payments (should succeed)
$viewPayments = Invoke-RestMethod -Uri "http://localhost:3001/api/payments/bill/1" -Headers $readerHeaders
Write-Host "✅ Can view payments: $($viewPayments.results) payments found"
```

---

### Scenario 4: Test Validation

```powershell
# Test 1: Missing required field
try {
    $invalidPayment = @{
        payment_amount = 100.00
        payment_method = "Cash"
    } | ConvertTo-Json
    
    Invoke-RestMethod -Uri "http://localhost:3001/api/payments" -Method POST -Headers $headers -Body $invalidPayment
} catch {
    Write-Host "✅ Error caught for missing bill_id: $($_.Exception.Message)"
}

# Test 2: Invalid payment amount (zero)
try {
    $zeroPayment = @{
        bill_id = 1
        payment_amount = 0
        payment_method = "Cash"
    } | ConvertTo-Json
    
    Invoke-RestMethod -Uri "http://localhost:3001/api/payments" -Method POST -Headers $headers -Body $zeroPayment
} catch {
    Write-Host "✅ Error caught for zero amount: $($_.Exception.Message)"
}

# Test 3: Invalid payment amount (negative)
try {
    $negativePayment = @{
        bill_id = 1
        payment_amount = -100
        payment_method = "Cash"
    } | ConvertTo-Json
    
    Invoke-RestMethod -Uri "http://localhost:3001/api/payments" -Method POST -Headers $headers -Body $negativePayment
} catch {
    Write-Host "✅ Error caught for negative amount: $($_.Exception.Message)"
}

# Test 4: Invalid payment method
try {
    $invalidMethod = @{
        bill_id = 1
        payment_amount = 100
        payment_method = "Bitcoin"
    } | ConvertTo-Json
    
    Invoke-RestMethod -Uri "http://localhost:3001/api/payments" -Method POST -Headers $headers -Body $invalidMethod
} catch {
    Write-Host "✅ Error caught for invalid method: $($_.Exception.Message)"
}

# Test 5: Non-existent bill
try {
    $nonExistentBill = @{
        bill_id = 99999
        payment_amount = 100
        payment_method = "Cash"
    } | ConvertTo-Json
    
    Invoke-RestMethod -Uri "http://localhost:3001/api/payments" -Method POST -Headers $headers -Body $nonExistentBill
} catch {
    Write-Host "✅ Error caught for non-existent bill: $($_.Exception.Message)"
}
```

---

## 📋 All Available Endpoints

| Method | Endpoint | Auth | Roles | Description |
|--------|----------|------|-------|-------------|
| POST | `/api/payments` | ✅ | CASHIER, ADMIN, MANAGER | Create payment |
| GET | `/api/payments/bill/:billId` | ✅ | All | Get payments by bill |
| GET | `/api/payments/:id` | ✅ | All | Get payment details |
| GET | `/api/payments` | ✅ | All | Get all payments (with filters) |
| GET | `/api/payments/stats` | ✅ | All | Get payment statistics |

---

## 🔍 Verification Checklist

- [ ] Payment creation works for all methods (Cash, Card, Online, Bank, QR)
- [ ] Bill status is automatically updated by database trigger
- [ ] Validation prevents invalid amounts (≤ 0)
- [ ] Validation prevents invalid payment methods
- [ ] Role-based access control works (only CASHIER, ADMIN, MANAGER can create)
- [ ] All users can view payments
- [ ] Payment statistics calculate correctly
- [ ] BigInt values serialize correctly
- [ ] Transaction references are stored
- [ ] Staff recording payment is captured correctly

---

## 🐛 Troubleshooting

### Bill Status Not Updating
The database trigger `trg_PAYMENT_UpdateBillStatus` should automatically update the bill status. Check:
```sql
SELECT * FROM sys.triggers WHERE name = 'trg_PAYMENT_UpdateBillStatus'
```

### Payment Amount Validation Error
Ensure you're sending a positive number:
```powershell
payment_amount = 100.50  # Valid
payment_amount = 0       # Invalid
payment_amount = -50     # Invalid
```

### Invalid Payment Method
Valid methods are: `Cash`, `Card`, `Online`, `Bank`, `QR` (case-sensitive)

---

## 📊 Sample Test Data

From your SQL.sql file:
- Bills with unpaid amounts: 1, 3, 5, 6, 9
- Cashiers: EMP-CS-031 to EMP-CS-040
- Admins: EMP-ADM-001 to EMP-ADM-010
- Managers: EMP-MG-041 to EMP-MG-050
