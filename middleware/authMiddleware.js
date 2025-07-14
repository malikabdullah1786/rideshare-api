const jwt = require('jsonwebtoken');
const User = require('../models/User');

const protect = async (req, res, next) => {
  let token;

  // --- DEBUG LOGS START ---
  console.log('\n--- AuthMiddleware Debug Start ---');
  console.log('Request Headers:', req.headers);
  // --- DEBUG LOGS END ---

  // Check if token exists in headers
  if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
    try {
      // Get token from header
      token = req.headers.authorization.split(' ')[1];
      console.log('AuthMiddleware: Token extracted:', token);

      // Verify token
      const jwtSecret = process.env.JWT_SECRET;
      if (!jwtSecret) {
        console.error('AuthMiddleware ERROR: JWT_SECRET is not defined!');
        return res.status(500).json({ message: 'Server configuration error: JWT secret missing.' });
      }
      const decoded = jwt.verify(token, jwtSecret);
      console.log('AuthMiddleware: Token decoded:', decoded);
      console.log('AuthMiddleware: Decoded Firebase UID:', decoded.firebaseUid);

      // Find user by Firebase UID in MongoDB
      // Use findOne and select specific fields for efficiency
      const user = await User.findOne({ firebaseUid: decoded.firebaseUid }).select('-password');

      if (!user) {
        console.error('AuthMiddleware ERROR: User not found in MongoDB for Firebase UID:', decoded.firebaseUid);
        return res.status(401).json({ message: 'Not authorized, user not found in database.' });
      }

      // Attach user to the request object
      req.user = user;
      console.log('AuthMiddleware: User found and attached to request:', req.user.email);
      console.log('--- AuthMiddleware Debug End (Success) ---\n');
      next();
    } catch (error) {
      console.error('AuthMiddleware ERROR: Token verification failed or user lookup error:', error.message);
      if (error.name === 'TokenExpiredError') {
        return res.status(401).json({ message: 'Not authorized, token expired.' });
      }
      return res.status(401).json({ message: 'Not authorized, token failed.' });
    }
  } else {
    console.error('AuthMiddleware ERROR: No token found in authorization header.');
    return res.status(401).json({ message: 'Not authorized, no token.' });
  }
};

module.exports = { protect };
