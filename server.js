const dotenv = require('dotenv');
// IMPORTANT: Load environment variables from .env file before any other imports
dotenv.config();

const express = require('express');
const connectDB = require('./config/db');
const authRoutes = require('./routes/authRoutes');
const rideRoutes = require('./routes/rideRoutes');
const adminRoutes = require('./routes/adminRoutes');
const userRoutes = require('./routes/userRoutes');
const mapRoutes = require('./routes/mapRoutes');
const cors = require('cors');
const admin = require('firebase-admin'); // Import Firebase Admin SDK
const bodyParser = require('body-parser'); // Import body-parser

// Initialize Firebase Admin SDK
// IMPORTANT: For deployment, we load the service account key from an environment variable.
// For local development, it can fall back to a local JSON file if the env var is not set.
if (process.env.FIREBASE_SERVICE_ACCOUNT_KEY_JSON) {
  try {
    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_KEY_JSON);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
    console.log('Firebase Admin SDK initialized from environment variable.');
  } catch (error) {
    console.error('Failed to parse Firebase Service Account Key JSON from environment variable:', error);
    // In a production app, you might want to exit the process here if Firebase is critical
    // process.exit(1);
  }
} else {
  console.error('FIREBASE_SERVICE_ACCOUNT_KEY_JSON environment variable is not set. Attempting to load from local file.');
  try {
    // Fallback for local development if the file exists.
    // Ensure 'rideshare-bdd66-firebase-adminsdk-fbsvc-6656f7de8f.json' is the CORRECT filename.
    const serviceAccount = require('./rideshare-bdd66-firebase-adminsdk-fbsvc-6656f7de8f.json');
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
    console.log('Firebase Admin SDK initialized from local file.');
  } catch (error) {
    console.error('Failed to initialize Firebase Admin SDK from local file:', error);
    // In a production app, you might want to exit the process here if Firebase is critical
    // process.exit(1);
  }
}

// Connect to MongoDB
connectDB();

const app = express();

// Enable CORS for all origins (for development purposes)
// For production, consider restricting to your frontend domain for better security:
// app.use(cors({ origin: 'https://your-firebase-hosting-url.web.app' }));
app.use(cors());

// Middleware to parse JSON bodies using body-parser
app.use(bodyParser.json());

// --- DEBUG MIDDLEWARE (Keep for now, can remove later) ---
app.use((req, res, next) => {
  if (req.body && Object.keys(req.body).length > 0) {
    console.log('Server.js DEBUG: Incoming request body (after body-parser.json()):', req.body);
    console.log('Server.js DEBUG: Stringified body:', JSON.stringify(req.body));
  } else {
    console.log('Server.js DEBUG: Incoming request body (after body-parser.json()) is empty or not parsed.');
  }
  next();
});
// --- END DEBUG MIDDLEWARE ---

// Define Routes
app.use('/api/auth', authRoutes);
app.use('/api/rides', rideRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/users', userRoutes);
app.use('/api/maps', mapRoutes);

// Basic route for testing
app.get('/', (req, res) => {
  res.send('Ride Share Backend API is running!');
});

const PORT = process.env.PORT || 5000;

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
