// server.js
require('dotenv').config();

const express = require('express');
const cors = require('cors');
const authRoutes = require('./authRoutes');

const app = express();

app.use(cors());
app.use(express.json());

// Simple request logger — lets you see activity in the server terminal
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} ${req.method} ${req.path}`);
  next();
});

app.get('/', (req, res) => {
  res.json({ status: 'Campus Companion API is running' });
});

app.use('/api/auth', authRoutes);

const PORT = process.env.PORT || 5001;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});