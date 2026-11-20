// server.js
require('dotenv').config({ quiet: true });

const http = require('http');
const path = require('path');
const express = require('express');
const cors = require('cors');
const authRoutes = require('./authRoutes');
const activitiesRoutes = require('./activitiesRoutes');
const usersRoutes = require('./usersRoutes');
const sosRoutes = require('./sosRoutes');
const conversationsRoutes = require('./conversationsRoutes');
const notificationsRoutes = require('./notificationsRoutes');
const adminRoutes = require('./adminRoutes');
const { initSocket } = require('./socket');
const { runMigrations } = require('./migrate');

const app = express();

app.use(cors());
app.use(express.json());
// Uploaded photos never change (each upload gets a new filename), so phones
// can cache them for a month instead of re-downloading on every screen.
app.use(
  '/uploads',
  express.static(path.join(__dirname, 'uploads'), { maxAge: '30d', immutable: true })
);

// Simple request logger — lets you see activity in the server terminal
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} ${req.method} ${req.path}`);
  next();
});

app.get('/', (req, res) => {
  res.json({ status: 'Campus Companion API is running' });
});

app.use('/api/auth', authRoutes);
app.use('/api/activities', activitiesRoutes);
app.use('/api/users', usersRoutes);
app.use('/api/sos', sosRoutes);
app.use('/api/conversations', conversationsRoutes);
app.use('/api/notifications', notificationsRoutes);
app.use('/api/admin', adminRoutes);

const httpServer = http.createServer(app);
initSocket(httpServer);

const PORT = process.env.PORT || 5001;
runMigrations()
  .catch((err) => console.error('Migration failed — some new features may not work:', err))
  .finally(() => {
    httpServer.listen(PORT, () => {
      console.log(`Server running on port ${PORT}`);
    });
  });