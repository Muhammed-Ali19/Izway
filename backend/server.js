const express = require('express');
const mysql = require('mysql2/promise');
const bodyParser = require('body-parser');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');

const app = express();
app.use(bodyParser.json());
app.use(cors());

// Database configuration
const dbConfig = {
  host: 'localhost',
  user: 'root',
  password: 'password', // TODO: Change this
  database: 'gps_app'
};

// GET /alerts?lat=...&lon=...&radius=...
app.get('/api/alerts', async (req, res) => {
  try {
    const { lat, lon, radius } = req.query;
    if (!lat || !lon) return res.status(400).send("Missing lat/lon");

    const connection = await mysql.createConnection(dbConfig);
    
    // Simple bounding box or Haversine formula
    // For simplicity here, we just return all recent alerts and filter client-side or add math here
    // In production, use ST_Distance_Sphere if MySQL 5.7+
    const [rows] = await connection.execute(
      'SELECT * FROM alerts WHERE timestamp > DATE_SUB(NOW(), INTERVAL 2 HOUR)'
    );
    
    await connection.end();
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).send("Server Error");
  }
});

// POST /alerts
app.post('/api/alerts', async (req, res) => {
  try {
    const { type, latitude, longitude, description, user_id } = req.body;
    if (!type || !latitude || !longitude) return res.status(400).send("Missing fields");

    const id = uuidv4();
    const connection = await mysql.createConnection(dbConfig);
    
    await connection.execute(
      'INSERT INTO alerts (id, type, latitude, longitude, description, user_id) VALUES (?, ?, ?, ?, ?, ?)',
      [id, type, latitude, longitude, description || '', user_id || 'anon']
    );
    
    await connection.end();
    res.json({ success: true, id });
  } catch (err) {
    console.error(err);
    res.status(500).send("Server Error");
  }
});

const PORT = 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
