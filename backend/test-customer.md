# Customer API Testing Guide

## Prerequisites
1. Server running on `http://localhost:3001`
2. Valid JWT token from login (see `test-auth.md`)
3. Database with sample customers

---

## 🔐 Step 1: Get Authentication Token

### Login as any staff member (all can access customer APIs)
```powershell
# Login as Admin
$admin = Invoke-RestMethod -Uri "http://localhost:3001/api/auth/login" -Method POST -ContentType "application/json" -Body '{"employee_no": "EMP-ADM-001"}'

# Extract token
$token = $admin.token
Write-Host "Token: $token"

# Setup headers
$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}
```

---

## 🔍 Step 2: Test Customer Search Endpoint

### 2.1 Search by Customer Name (GET /api/customers/search?q=...)

**Access:** Protected (All Staff)

#### Example 1: Search by partial name
```powershell
# Search for customers with "Silva" in their name
$searchResults = Invoke-RestMethod -Uri "http://localhost:3001/api/customers/search?q=Silva" -Headers $headers

Write-Host "Found $($searchResults.results) customers:"
$searchResults.data.customers | Format-Table -Property customer_id, full_name, status
```

**Expected Response:**
```json
{
  "status": "success",
  "results": 3,
  "data": {
    "customers": [
      {
        "customer_id": "1",
        "full_name": "Ravindu Silva",
        "address": {
          "line1": "12, Galle Road",
          "line2": "Mount Lavinia",
          "city": "Colombo",
          "postal_code": "10370"
        },
        "identity_ref": "NIC123456789V",
        "phone": "+94712345678",
        "email": "ravindu@email.com",
        "status": "Active",
        "registration_date": "2020-05-15T00:00:00.000Z"
      },
      ...
    ]
  }
}
```

#### Example 2: Search by NIC (Identity Reference)
```powershell
# Search by NIC/Identity Reference
$nicSearch = Invoke-RestMethod -Uri "http://localhost:3001/api/customers/search?q=NIC123456789V" -Headers $headers

Write-Host "Customer found:"
$nicSearch.data.customers[0] | ConvertTo-Json -Depth 5
```

#### Example 3: Search by Customer ID
```powershell
# Search by exact customer ID
$idSearch = Invoke-RestMethod -Uri "http://localhost:3001/api/customers/search?q=1" -Headers $headers

Write-Host "Customer ID 1:"
$idSearch.data.customers[0].full_name
```

#### Example 4: Search by City
```powershell
# Search for all customers in Colombo
$citySearch = Invoke-RestMethod -Uri "http://localhost:3001/api/customers/search?q=Colombo" -Headers $headers

Write-Host "Found $($citySearch.results) customers in Colombo"
```

#### Example 5: Search with no results
```powershell
# Search with term that doesn't match anything
$noResults = Invoke-RestMethod -Uri "http://localhost:3001/api/customers/search?q=XYZ999" -Headers $headers

Write-Host "Results: $($noResults.results)"  # Should be 0
```

---

## 👤 Step 3: Test Customer Profile Endpoint

### 3.1 Get Comprehensive Customer Profile (GET /api/customers/:id)

**Access:** Protected (All Staff)

**Purpose:** This endpoint provides ALL data needed for a Customer Dashboard page, including:
- Customer basic info
- All connections (with zones, tariffs, utility types)
- Active meters for each connection
- Latest bills for each connection
- Active subsidies
- Summary statistics (total connections, active connections, outstanding amounts)

#### Example 1: Get complete customer profile
```powershell
# Get customer ID 1's full profile
$customerId = 1
$profile = Invoke-RestMethod -Uri "http://localhost:3001/api/customers/$customerId" -Headers $headers

Write-Host "=== Customer Profile ==="
Write-Host "Name: $($profile.data.customer.full_name)"
Write-Host "Status: $($profile.data.customer.status)"
Write-Host "Phone: $($profile.data.customer.phone)"
Write-Host "Email: $($profile.data.customer.email)"

Write-Host "`n=== Summary Statistics ==="
Write-Host "Total Connections: $($profile.data.customer.summary.total_connections)"
Write-Host "Active Connections: $($profile.data.customer.summary.active_connections)"
Write-Host "Active Subsidies: $($profile.data.customer.summary.active_subsidies)"
Write-Host "Total Outstanding: Rs. $($profile.data.customer.summary.total_outstanding)"

Write-Host "`n=== Connections ==="
foreach ($conn in $profile.data.customer.connections) {
    Write-Host "`nConnection ID: $($conn.connection_id)"
    Write-Host "  Utility Type: $($conn.utility_type)"
    Write-Host "  Status: $($conn.status)"
    Write-Host "  Service Address: $($conn.service_address)"
    Write-Host "  Zone: $($conn.zone.zone_name) ($($conn.zone.region))"
    Write-Host "  Tariff: $($conn.tariff.name) - $($conn.tariff.code)"
    
    if ($conn.active_meter) {
        Write-Host "  Active Meter: $($conn.active_meter.meter_serial_no)"
        Write-Host "  Meter Type: $($conn.active_meter.meter_type)"
        Write-Host "  Smart Meter: $($conn.active_meter.is_smart_meter)"
    }
    
    if ($conn.latest_bill) {
        Write-Host "  Latest Bill: Rs. $($conn.latest_bill.net_amount)"
        Write-Host "  Bill Status: $($conn.latest_bill.status)"
        Write-Host "  Due Date: $($conn.latest_bill.due_date)"
    }
}

Write-Host "`n=== Active Subsidies ==="
foreach ($subsidy in $profile.data.customer.subsidies) {
    Write-Host "- $($subsidy.subsidy.name)"
    Write-Host "  Discount: Rs. $($subsidy.subsidy.discount_value) ($($subsidy.subsidy.discount_type))"
    Write-Host "  Approved: $($subsidy.approved_date)"
}
```

**Expected Response Structure:**
```json
{
  "status": "success",
  "data": {
    "customer": {
      "customer_id": "1",
      "full_name": "Ravindu Silva",
      "address": {
        "line1": "12, Galle Road",
        "line2": "Mount Lavinia",
        "city": "Colombo",
        "postal_code": "10370"
      },
      "identity_type": "NIC",
      "identity_ref": "NIC123456789V",
      "phone": "+94712345678",
      "email": "ravindu@email.com",
      "status": "Active",
      "registration_date": "2020-05-15T00:00:00.000Z",
      
      "summary": {
        "total_connections": 2,
        "active_connections": 2,
        "active_subsidies": 1,
        "total_outstanding": 1500.50
      },
      
      "connections": [
        {
          "connection_id": "1",
          "start_date": "2020-05-20T00:00:00.000Z",
          "status": "Active",
          "service_address": "12, Galle Road, Mount Lavinia",
          "utility_type": "Electricity",
          
          "zone": {
            "zone_id": "1",
            "zone_name": "Colombo Central",
            "region": "Western"
          },
          
          "tariff": {
            "tariff_category_id": "1",
            "name": "Domestic - Low Usage",
            "code": "DOM-LOW",
            "utility_type": "Electricity",
            "is_subsidized": true
          },
          
          "active_meter": {
            "meter_id": "1",
            "meter_serial_no": "MTR-ELC-001",
            "meter_type": "Digital",
            "meter_role": "Import",
            "status": "Active",
            "installed_from": "2020-05-20T00:00:00.000Z",
            "is_smart_meter": true
          },
          
          "latest_bill": {
            "bill_id": "1",
            "billing_period": {
              "start": "2025-11-01T00:00:00.000Z",
              "end": "2025-11-30T00:00:00.000Z"
            },
            "net_amount": 8394.00,
            "status": "Partially_Paid",
            "due_date": "2025-12-15T00:00:00.000Z"
          }
        }
      ],
      
      "subsidies": [
        {
          "customer_subsidy_id": "1",
          "approved_date": "2020-06-01T00:00:00.000Z",
          "status": "Active",
          "subsidy": {
            "subsidy_id": "1",
            "name": "Low Income Subsidy",
            "discount_type": "Percentage",
            "discount_value": 25.00,
            "description": "25% discount for low-income families"
          }
        }
      ]
    }
  }
}
```

#### Example 2: Display customer dashboard summary
```powershell
$customerId = 1
$profile = Invoke-RestMethod -Uri "http://localhost:3001/api/customers/$customerId" -Headers $headers

# Create a dashboard view
$dashboard = @{
    "Customer Name" = $profile.data.customer.full_name
    "Status" = $profile.data.customer.status
    "Total Connections" = $profile.data.customer.summary.total_connections
    "Active Connections" = $profile.data.customer.summary.active_connections
    "Active Subsidies" = $profile.data.customer.summary.active_subsidies
    "Total Outstanding" = "Rs. $($profile.data.customer.summary.total_outstanding)"
}

$dashboard | Format-Table -AutoSize
```

---

## 🧪 Test Scenarios

### Scenario 1: Customer Search Workflow

```powershell
# 1. Login
$staff = Invoke-RestMethod -Uri "http://localhost:3001/api/auth/login" -Method POST -ContentType "application/json" -Body '{"employee_no": "EMP-ADM-001"}'
$headers = @{
    "Authorization" = "Bearer $($staff.token)"
    "Content-Type" = "application/json"
}

# 2. Search for customer by partial name
$search = Invoke-RestMethod -Uri "http://localhost:3001/api/customers/search?q=Silva" -Headers $headers

# 3. Select first customer from results
$selectedCustomer = $search.data.customers[0]
Write-Host "Selected: $($selectedCustomer.full_name) (ID: $($selectedCustomer.customer_id))"

# 4. Get full profile
$profile = Invoke-RestMethod -Uri "http://localhost:3001/api/customers/$($selectedCustomer.customer_id)" -Headers $headers

# 5. Display comprehensive info
Write-Host "`nCustomer has $($profile.data.customer.connections.Count) connection(s)"
Write-Host "Outstanding balance: Rs. $($profile.data.customer.summary.total_outstanding)"

Write-Host "✅ Search workflow completed"
```

---

### Scenario 2: Customer Dashboard Data

```powershell
# Simulate fetching all data for a customer dashboard page
$customerId = 1
$profile = Invoke-RestMethod -Uri "http://localhost:3001/api/customers/$customerId" -Headers $headers

$customer = $profile.data.customer

# Customer Info Card
Write-Host "=== Customer Information ==="
Write-Host "Name: $($customer.full_name)"
Write-Host "ID Type: $($customer.identity_type)"
Write-Host "ID Number: $($customer.identity_ref)"
Write-Host "Phone: $($customer.phone)"
Write-Host "Email: $($customer.email)"
Write-Host "Address: $($customer.address.line1), $($customer.address.city)"

# Summary Card
Write-Host "`n=== Quick Summary ==="
Write-Host "Total Connections: $($customer.summary.total_connections)"
Write-Host "Active: $($customer.summary.active_connections)"
Write-Host "Outstanding Amount: Rs. $($customer.summary.total_outstanding)"

# Connections Table
Write-Host "`n=== Connections ==="
$connectionTable = $customer.connections | ForEach-Object {
    [PSCustomObject]@{
        ID = $_.connection_id
        Type = $_.utility_type
        Status = $_.status
        Zone = $_.zone.zone_name
        Meter = if ($_.active_meter) { $_.active_meter.meter_serial_no } else { "No Active Meter" }
        BillStatus = if ($_.latest_bill) { $_.latest_bill.status } else { "No Bills" }
    }
}
$connectionTable | Format-Table -AutoSize

Write-Host "✅ Dashboard data ready"
```

---

### Scenario 3: Test Error Handling

```powershell
# Test 1: Missing search query
try {
    Invoke-RestMethod -Uri "http://localhost:3001/api/customers/search" -Headers $headers
} catch {
    Write-Host "✅ Error caught for missing query: $($_.Exception.Message)"
}

# Test 2: Empty search query
try {
    Invoke-RestMethod -Uri "http://localhost:3001/api/customers/search?q=" -Headers $headers
} catch {
    Write-Host "✅ Error caught for empty query: $($_.Exception.Message)"
}

# Test 3: Non-existent customer ID
try {
    Invoke-RestMethod -Uri "http://localhost:3001/api/customers/99999" -Headers $headers
} catch {
    Write-Host "✅ Error caught for non-existent customer: $($_.Exception.Message)"
}

# Test 4: Invalid customer ID format
try {
    Invoke-RestMethod -Uri "http://localhost:3001/api/customers/invalid" -Headers $headers
} catch {
    Write-Host "✅ Error caught for invalid ID format: $($_.Exception.Message)"
}

# Test 5: Unauthorized access (no token)
try {
    Invoke-RestMethod -Uri "http://localhost:3001/api/customers/search?q=Silva"
} catch {
    Write-Host "✅ Error caught for unauthorized access: $($_.Exception.Message)"
}
```

---

## 📋 All Available Endpoints

| Method | Endpoint | Auth | Roles | Description |
|--------|----------|------|-------|-------------|
| GET | `/api/customers/search?q=...` | ✅ | All Staff | Search customers by name/NIC/ID |
| GET | `/api/customers/:id` | ✅ | All Staff | Get comprehensive customer profile |

---

## 🔍 Query Parameters

### `/api/customers/search`
- **q** (required): Search term
  - Can be: customer name (partial match), NIC/identity reference, customer ID (exact match)
  - Case-insensitive
  - Searches across: `full_name`, `identity_ref`, `customer_id`
  - Results limited to 50 customers

---

## 🔑 Use Cases

### Use Case 1: Customer Service Portal
```powershell
# Staff member searches for customer who called
$search = Invoke-RestMethod -Uri "http://localhost:3001/api/customers/search?q=712345678" -Headers $headers

# Gets full profile to answer questions
$profile = Invoke-RestMethod -Uri "http://localhost:3001/api/customers/$($search.data.customers[0].customer_id)" -Headers $headers

# Can see all connections, bills, and subsidies immediately
```

### Use Case 2: Bill Payment Counter
```powershell
# Customer comes to pay bill with NIC
$customer = Invoke-RestMethod -Uri "http://localhost:3001/api/customers/search?q=NIC123456789V" -Headers $headers

# Get full profile to see all outstanding bills
$profile = Invoke-RestMethod -Uri "http://localhost:3001/api/customers/$($customer.data.customers[0].customer_id)" -Headers $headers

# Display all connections with outstanding amounts
foreach ($conn in $profile.data.customer.connections) {
    if ($conn.latest_bill -and $conn.latest_bill.status -ne "Paid") {
        Write-Host "Connection $($conn.connection_id): Rs. $($conn.latest_bill.net_amount) - Due: $($conn.latest_bill.due_date)"
    }
}
```

### Use Case 3: Field Officer App
```powershell
# Field officer needs customer info for a specific address
$customers = Invoke-RestMethod -Uri "http://localhost:3001/api/customers/search?q=Galle+Road" -Headers $headers

# Select customer
$profile = Invoke-RestMethod -Uri "http://localhost:3001/api/customers/$($customers.data.customers[0].customer_id)" -Headers $headers

# See meter details for each connection
$profile.data.customer.connections | ForEach-Object {
    Write-Host "Meter: $($_.active_meter.meter_serial_no) - Type: $($_.active_meter.meter_type)"
}
```

---

## 🐛 Troubleshooting

### Search returns no results
- Check if customer exists in database
- Try broader search terms (partial name)
- Search is case-insensitive, so "silva" will match "Silva"

### Customer profile missing connections
- Customer may not have any active connections
- Check `connections` array in response

### BigInt serialization errors
- Already handled by global `BigInt.prototype.toJSON` patch in `src/index.ts`
- All BigInt fields automatically converted to strings

---

## 📊 Sample Test Data

From your SQL.sql file:
- Customer IDs: 1-100
- Sample names to search: "Silva", "Fernando", "Perera"
- Sample NICs to search by identity_ref column
- Zones: Colombo (1-10), Gampaha (11-20), Kandy (21-30), etc.
