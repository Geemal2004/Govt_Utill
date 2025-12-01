# GOVT Utility Management System

A comprehensive utility management system for Sri Lanka's electricity, water, and gas services. Built with Node.js/Express backend, React/Vite frontend, and SQL Server database using Prisma ORM.

## 🏗️ Architecture

- **Backend**: Node.js + Express + TypeScript + Prisma
- **Frontend**: React + TypeScript + Vite
- **Database**: Microsoft SQL Server
- **ORM**: Prisma

## 📋 Prerequisites

Before you begin, ensure you have the following installed:

### Required Software
- **Node.js** (v18 or higher) - [Download](https://nodejs.org/)
- **npm** (comes with Node.js)
- **Microsoft SQL Server** (2019 or later) - [Download](https://www.microsoft.com/en-us/sql-server/sql-server-downloads)
- **SQL Server Management Studio (SSMS)** (optional, for database management) - [Download](https://docs.microsoft.com/en-us/sql/ssms/download-sql-server-management-studio-ssms)

### Database Setup
1. Install SQL Server with SQL Server Authentication enabled
2. Create a database named `GOVT_UTILL_6`
3. Run the provided `SQL.sql` script to create tables and sample data

## 🚀 Quick Start

### 1. Clone the Repository
```bash
git clone https://github.com/Geemal2004/Govt_Utill.git
cd govt-utility-monorepo
```

### 2. Install Dependencies
```bash
npm install
```

### 3. Database Configuration

#### Option A: SQL Server Authentication
Create a `.env` file in the `backend/` folder:
```env
DATABASE_URL="sqlserver://localhost:1433;database=GOVT_UTILL_6;user=YOUR_USERNAME;password=YOUR_PASSWORD;trustServerCertificate=true"
PORT=3001
```

#### Option B: Windows Authentication (Named Instance)
```env
DATABASE_URL="sqlserver://DESKTOP-YOURPC;instanceName=SQLEXPRESS01;database=GOVT_UTILL_6;integratedSecurity=true;trustServerCertificate=true"
PORT=3001
```

### 4. Database Setup
1. Execute the `SQL.sql` script in your SQL Server instance
2. Generate Prisma client:
```bash
cd backend
npx prisma generate
cd ..
```

### 5. Start Development Servers
```bash
# Start both frontend and backend
npm run dev

# Or run separately:
npm run dev:backend  # Backend on http://localhost:3001
npm run dev:frontend # Frontend on http://localhost:5173
```

### 6. Verify Setup
- **Backend Health Check**: Visit `http://localhost:3001/api/health`
- **Frontend**: Visit `http://localhost:5173`
- **Database Test**: Visit `http://localhost:3001/api/zones`

## 📁 Project Structure

```
govt-utility-monorepo/
├── backend/                    # Express.js API server
│   ├── prisma/
│   │   ├── schema.prisma      # Database schema
│   │   └── migrations/        # Database migrations
│   ├── src/
│   │   └── index.ts           # Main server file
│   ├── package.json
│   ├── tsconfig.json
│   └── .env                   # Environment variables
├── frontend/                   # React application
│   ├── src/
│   │   ├── App.tsx            # Main React component
│   │   ├── main.tsx           # React entry point
│   │   └── index.css          # Global styles
│   ├── package.json
│   ├── tsconfig.json
│   └── vite.config.ts         # Vite configuration
├── SQL.sql                     # Database schema & sample data
├── package.json               # Root workspace config
└── README.md                  # This file
```

## 🔧 Available Scripts

### Root Level
```bash
npm run dev          # Start both frontend and backend
npm run build        # Build both frontend and backend
npm run dev:backend  # Start only backend
npm run dev:frontend # Start only frontend
```

### Backend Scripts
```bash
cd backend
npm run dev          # Start development server with hot reload
npm run build        # Build TypeScript to JavaScript
npm run start        # Start production server
npm run prisma:generate  # Generate Prisma client
npm run prisma:db:pull   # Introspect database schema
```

### Frontend Scripts
```bash
cd frontend
npm run dev          # Start Vite development server
npm run build        # Build for production
npm run preview      # Preview production build
npm run lint         # Run ESLint
```

## 🌐 API Endpoints

### Health Check
- `GET /api/health` - Server health status

### Zones
- `GET /api/zones` - Get all zones

## 🔒 Environment Variables

Create `.env` file in `backend/` directory:

```env
# Database Connection
DATABASE_URL="sqlserver://localhost:1433;database=GOVT_UTILL_6;user=username;password=password;trustServerCertificate=true"

# Server Configuration
PORT=3001

# Optional: Add these for production
NODE_ENV=development
JWT_SECRET=your-secret-key
```

## 🧪 Testing

### Backend Testing
```bash
cd backend
npm test  # (when tests are added)
```

### Frontend Testing
```bash
cd frontend
npm run test  # (when tests are added)
```

## 🚀 Deployment

### Backend Deployment
```bash
cd backend
npm run build
npm start
```

### Frontend Deployment
```bash
cd frontend
npm run build
# Serve the dist/ folder with any static server
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit changes: `git commit -m 'Add some feature'`
4. Push to branch: `git push origin feature/your-feature`
5. Open a Pull Request

### Code Style
- Use TypeScript for type safety
- Follow ESLint rules
- Use meaningful commit messages
- Write tests for new features

## 📝 Development Notes

### Database Changes
When modifying the database schema:
1. Update `SQL.sql` with new schema changes
2. Run `npx prisma db pull` to introspect changes
3. Update Prisma schema if needed
4. Run `npx prisma generate` to update client

### API Development
- All API responses should handle BigInt serialization
- Use proper HTTP status codes
- Implement error handling for all endpoints
- Add input validation

### Frontend Development
- Use TypeScript for all components
- Follow React best practices
- Handle loading states and errors
- Use consistent styling

## 🐛 Troubleshooting

### Common Issues

**Port 3001 already in use:**
```bash
# Find process using port
netstat -ano | findstr :3001
# Kill the process
taskkill /PID <PID> /F
```

**Database connection fails:**
- Verify SQL Server is running
- Check connection string in `.env`
- Ensure database `GOVT_UTILL_6` exists
- Test connection with SSMS

**Prisma client issues:**
```bash
cd backend
npx prisma generate
```

**Frontend build fails:**
```bash
cd frontend
rm -rf node_modules package-lock.json
npm install
```

## 📞 Support

For questions or issues:
- Check this README first
- Review existing issues on GitHub
- Create a new issue with detailed information

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.</content>
<parameter name="filePath">c:\Users\lakit\Desktop\IMR\GOVT-2\README.md