# Authentication Testing Guide

## ✅ Authentication Module Status

All authentication files are properly implemented:

### 📁 Files Created:
- ✅ `src/config/auth.ts` - JWT configuration
- ✅ `src/controllers/auth.controller.ts` - Login, getMe, logout
- ✅ `src/middleware/authMiddleware.ts` - protect, restrictTo, optionalAuth
- ✅ `src/routes/auth.routes.ts` - Auth routes
- ✅ `.env` - JWT_SECRET and JWT_EXPIRES_IN configured

### 🔧 Features Implemented:

#### 1. **Login (Dev Mode - No Password Required)**
- Validates employee_no
- Determines role from subtype tables (Manager, Admin, Cashier, Field Officer, Meter Reader, Staff)
- Generates JWT token
- Returns user data

#### 2. **Protect Middleware**
- Verifies JWT token from Authorization header
- Checks user exists and is active
- Attaches user to `req.user`

#### 3. **RestrictTo Middleware**
- Role-based access control
- Usage: `restrictTo('ADMIN', 'MANAGER')`

#### 4. **Staff Roles Hierarchy**
```typescript
'MANAGER' > 'ADMIN' > 'CASHIER' > 'FIELD_OFFICER' > 'METER_READER' > 'STAFF'
```

---

## 🧪 Testing the API

### 1. **Login**
```powershell
# Test with existing employee from sample data (e.g., EMP-ADM-001)
$loginResponse = Invoke-RestMethod -Uri "http://localhost:3001/api/auth/login" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"employee_no": "EMP-ADM-001"}'

$token = $loginResponse.token
Write-Host "Token: $token"
Write-Host "User: $($loginResponse.data.user | ConvertTo-Json)"
```

Expected Response:
```json
{
  "status": "success",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "data": {
    "user": {
      "staff_id": "1",
      "employee_no": "EMP-ADM-001",
      "full_name": "Nimal Perera",
      "email": "nimal.perera@utility.gov.lk",
      "phone": "0771000001",
      "status": "Active",
      "role": "ADMIN"
    }
  }
}
```

### 2. **Get Current User Profile**
```powershell
# Use token from login
$headers = @{
  "Authorization" = "Bearer $token"
  "Content-Type" = "application/json"
}

$profile = Invoke-RestMethod -Uri "http://localhost:3001/api/auth/me" `
  -Method GET `
  -Headers $headers

Write-Host ($profile | ConvertTo-Json -Depth 5)
```

### 3. **Test Protected Route (401 - No Token)**
```powershell
# Should fail with 401
try {
  Invoke-RestMethod -Uri "http://localhost:3001/api/auth/me" -Method GET
} catch {
  Write-Host "Expected Error: $($_.Exception.Message)"
}
```

Expected Response:
```json
{
  "status": "fail",
  "message": "You are not logged in. Please log in to access this resource."
}
```

### 4. **Test Different Staff Roles**

#### Manager (staff_id: 41)
```powershell
$managerLogin = Invoke-RestMethod -Uri "http://localhost:3001/api/auth/login" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"employee_no": "EMP-MG-041"}'

Write-Host "Manager Role: $($managerLogin.data.user.role)"
```

#### Cashier (staff_id: 31)
```powershell
$cashierLogin = Invoke-RestMethod -Uri "http://localhost:3001/api/auth/login" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"employee_no": "EMP-CS-031"}'

Write-Host "Cashier Role: $($cashierLogin.data.user.role)"
```

#### Meter Reader (staff_id: 11)
```powershell
$readerLogin = Invoke-RestMethod -Uri "http://localhost:3001/api/auth/login" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"employee_no": "EMP-MR-011"}'

Write-Host "Meter Reader Role: $($readerLogin.data.user.role)"
```

---

## 🔒 Using Protected Routes

### Example: Creating a protected endpoint

```typescript
import { Router } from 'express';
import { protect, restrictTo } from '../middleware';
import { asyncHandler } from '../utils';

const router = Router();

// Only authenticated users
router.get('/dashboard', protect, asyncHandler(async (req, res) => {
  const user = (req as AuthenticatedRequest).user;
  res.json({ message: `Welcome ${user.employeeNo}` });
}));

// Only ADMIN and MANAGER
router.delete('/users/:id', 
  protect, 
  restrictTo('ADMIN', 'MANAGER'), 
  asyncHandler(async (req, res) => {
    // Delete user logic
    res.json({ message: 'User deleted' });
  })
);

// Only CASHIER
router.post('/payments', 
  protect, 
  restrictTo('CASHIER'), 
  asyncHandler(async (req, res) => {
    // Record payment logic
    res.json({ message: 'Payment recorded' });
  })
);
```

---

## 🛠️ Available Endpoints

| Method | Endpoint | Access | Description |
|--------|----------|--------|-------------|
| POST | `/api/auth/login` | Public | Login with employee_no |
| GET | `/api/auth/me` | Private | Get current user profile |
| POST | `/api/auth/logout` | Private | Logout (client-side) |

---

## 📋 Sample Employee Numbers from Database

```
Administrators:
- EMP-ADM-001 to EMP-ADM-010

Meter Readers:
- EMP-MR-011 to EMP-MR-020

Field Officers:
- EMP-FO-021 to EMP-FO-030

Cashiers:
- EMP-CS-031 to EMP-CS-040

Managers:
- EMP-MG-041 to EMP-MG-050
```

---

## ✨ Key Features

### 1. **No Password Required (Dev Mode)**
- Just provide `employee_no` to login
- Automatically determines role from subtype tables

### 2. **JWT Token Based**
- Stateless authentication
- Token expires in 7 days (configurable)
- Contains: `{ id, employeeNo, role }`

### 3. **Role-Based Access Control**
- Automatic role detection
- Easy middleware: `restrictTo('ADMIN', 'MANAGER')`
- Supports multiple roles per route

### 4. **Error Handling**
- Uses AppError for consistent responses
- Proper HTTP status codes
- Development vs Production error messages

### 5. **Security Checks**
- Verifies user still exists
- Checks user is Active status
- Validates token expiration
- Handles token tampering

---

## 🚨 Important Notes

1. **This is DEV MODE LOGIN** - No password required for development/testing
2. **JWT_SECRET** - Change in production (currently in .env)
3. **Token Storage** - Client must store token (localStorage/sessionStorage)
4. **Token Header Format** - `Authorization: Bearer <token>`
5. **Role Hierarchy** - One staff can only have ONE role (based on subtype tables)

---

## 🔐 Production Readiness Checklist

Before deploying to production, add:

- [ ] Password field to Staff table
- [ ] Password hashing (bcrypt)
- [ ] Password validation in login
- [ ] Refresh token mechanism
- [ ] Rate limiting on login endpoint
- [ ] Account lockout after failed attempts
- [ ] Password reset functionality
- [ ] Email verification
- [ ] Two-factor authentication (optional)
- [ ] Audit logging for auth events

---

## ✅ Current Status: **WORKING**

All authentication components are properly integrated and ready for testing.
