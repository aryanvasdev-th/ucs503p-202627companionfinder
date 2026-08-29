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
const { initSocket } = require('./socket');

const app = express();

app.use(cors());
app.use(express.json());
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

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

const httpServer = http.createServer(app);
initSocket(httpServer);

const PORT = process.env.PORT || 5001;
httpServer.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});