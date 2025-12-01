import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { PrismaClient } from '@prisma/client';

dotenv.config();

const app = express();
const prisma = new PrismaClient();
const PORT = process.env.PORT || 3001;

app.use(cors());
app.use(express.json());

// BigInt serialization fix
const bigIntSerializer = (_key: string, value: unknown) =>
  typeof value === 'bigint' ? value.toString() : value;

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Example endpoint to test database connection
app.get('/api/zones', async (req, res) => {
  try {
    const zones = await prisma.zone.findMany();
    res.send(JSON.stringify(zones, bigIntSerializer));
  } catch (error) {
    console.error('Database error:', error);
    res.status(500).json({ error: 'Failed to fetch zones' });
  }
});

app.listen(PORT, () => {
  console.log(`🚀 Server running on http://localhost:${PORT}`);
});

// Graceful shutdown
process.on('SIGINT', async () => {
  await prisma.$disconnect();
  process.exit(0);
});
