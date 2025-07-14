const jwt = require('jsonwebtoken');
const User = require('../models/User');
const admin = require('firebase-admin'); // Import Firebase Admin SDK

const protect = async (req, res, next) => {
  let token;

  // Check for Authorization header
  if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
    try {
      // Get token from header
      token = req.headers.authorization.split(' ')[1];

      // --- DEBUG LOGS START ---
      console.log('\n--- AuthMiddleware Debug Start ---');
      console.log('1. Authorization header found.');
      console.log('2. FULL Extracted Token (from header):', token); // Log the full token received
      // --- DEBUG LOGS END ---

      // Verify Firebase ID Token using Firebase Admin SDK
      const decodedToken = await admin.auth().verifyIdToken(token);

      // --- DEBUG LOGS START ---
      console.log('3. Firebase ID Token verified successfully.');
      console.log('4. Decoded Firebase Token UID:', decodedToken.uid);
      console.log('5. Decoded Token full payload:', decodedToken); // Log full decoded token
      // --- DEBUG LOGS END ---

      // Find user in your MongoDB based on Firebase UID
      const user = await User.findOne({ firebaseUid: decodedToken.uid }).select('-password');

      if (!user) {
        console.error('AuthMiddleware ERROR: User not found in MongoDB for Firebase UID:', decodedToken.uid);
        console.log('--- AuthMiddleware Debug End ---\n');
        return res.status(401).json({ message: 'Not authorized, user not found in database.' });
      }

      // Attach user to the request object
      req.user = user; 

      // --- DEBUG LOGS START ---
      console.log('6. User found in MongoDB:', user.email, user.userType);
      console.log('7. User object SUCCESSFULLY ATTACHED to req.user. Email:', req.user.email, 'UserType:', req.user.userType);
      console.log('--- AuthMiddleware Debug End ---\n');
      // --- DEBUG LOGS END ---

      next(); // Proceed to the next middleware/controller

    } catch (error) {
      console.error('\n--- AuthMiddleware ERROR Start ---');
      console.error('Firebase ID token verification failed or database lookup error:', error);
      console.error('Error Code:', error.code);
      console.error('Error Message:', error.message);
      console.error('--- AuthMiddleware ERROR End ---\n');
      
      let errorMessage = 'Not authorized, invalid or expired token.';
      if (error.code === 'auth/id-token-expired') {
        errorMessage = 'Not authorized, token has expired. Please log in again.';
      } else if (error.code === 'auth/argument-error') {
        errorMessage = 'Not authorized, malformed token.';
      } else if (error.code === 'auth/invalid-id-token') {
        errorMessage = 'Not authorized, invalid token.';
      }
      res.status(401).json({ message: errorMessage });
    }
  } else {
    console.error('\n--- AuthMiddleware ERROR Start ---');
    console.error('No Authorization header or token not in Bearer format.');
    console.error('--- AuthMiddleware ERROR End ---\n');
    res.status(401).json({ message: 'Not authorized, no token provided.' });
  }
};

// Middleware to check if user is a driver
const isDriver = (req, res, next) => {
  if (req.user && req.user.userType === 'driver') {
    next();
  } else {
    res.status(403).json({ message: 'Not authorized as a driver.' });
  }
};

// Middleware to check if user is a rider
const isRider = (req, res, next) => {
  if (req.user && req.user.userType === 'rider') {
    next();
  } else {
    res.status(403).json({ message: 'Not authorized as a rider.' });
  }
};

module.exports = { protect, isDriver, isRider };
