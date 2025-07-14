const jwt = require('jsonwebtoken'); // Still needed if you generate your own JWTs
const User = require('../models/User');
const admin = require('firebase-admin'); // Import Firebase Admin SDK

const protect = async (req, res, next) => {
  let token;

  console.log('\n--- AuthMiddleware Debug Start ---');
  console.log('Request Headers:', req.headers);

  if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
    try {
      token = req.headers.authorization.split(' ')[1];
      console.log('AuthMiddleware: Token extracted:', token);

      // --- IMPORTANT CHANGE HERE ---
      // Determine if it's a Firebase ID Token or your custom JWT
      // Firebase ID Tokens are typically very long and signed by Google
      // Your custom JWTs are signed by your JWT_SECRET

      // A simple heuristic: Firebase ID tokens are usually much longer and start with specific patterns
      // A more robust way might be to have two different auth headers or paths
      // For now, let's assume if it's coming from Flutter's Firebase auth, it's a Firebase ID Token.
      // If your frontend sends Firebase ID Token directly for protected routes:

      let decodedToken;
      try {
          // Attempt to verify as a Firebase ID Token first
          decodedToken = await admin.auth().verifyIdToken(token);
          console.log('AuthMiddleware: Successfully verified Firebase ID Token.');
          console.log('AuthMiddleware: Decoded Firebase UID from Firebase ID Token:', decodedToken.uid);

          // The Firebase UID is in decodedToken.uid
          const firebaseUid = decodedToken.uid;

          // Find user by Firebase UID in MongoDB
          const user = await User.findOne({ firebaseUid: firebaseUid }).select('-password');

          if (!user) {
            console.error('AuthMiddleware ERROR: User not found in MongoDB for Firebase UID:', firebaseUid);
            return res.status(401).json({ message: 'Not authorized, user not found in database.' });
          }

          // Attach user to the request object
          req.user = user;
          console.log('AuthMiddleware: User found and attached to request:', req.user.email);
          console.log('--- AuthMiddleware Debug End (Success) ---\n');
          next();

      } catch (firebaseVerifyError) {
          console.warn('AuthMiddleware WARNING: Firebase ID Token verification failed. Attempting as custom JWT.', firebaseVerifyError.message);
          // If Firebase ID Token verification fails, it might be your custom JWT
          // This path will only be taken if you have a separate flow where your backend issues its own JWTs
          // and the frontend sends those for protected routes.
          // If your frontend ONLY sends Firebase ID Tokens, then this 'else' block
          // indicates a problem with the Firebase ID Token itself.

          const jwtSecret = process.env.JWT_SECRET;
          if (!jwtSecret) {
            console.error('AuthMiddleware ERROR: JWT_SECRET is not defined for custom JWT verification!');
            return res.status(500).json({ message: 'Server configuration error: JWT secret missing for custom token.' });
          }
          
          try {
              const decodedCustomJwt = jwt.verify(token, jwtSecret);
              console.log('AuthMiddleware: Successfully verified Custom JWT.');
              // Assuming your custom JWT also contains firebaseUid for lookup
              const firebaseUid = decodedCustomJwt.firebaseUid; 

              const user = await User.findOne({ firebaseUid: firebaseUid }).select('-password');

              if (!user) {
                console.error('AuthMiddleware ERROR: User not found in MongoDB for Custom JWT Firebase UID:', firebaseUid);
                return res.status(401).json({ message: 'Not authorized, user not found in database.' });
              }
              req.user = user;
              console.log('AuthMiddleware: User found and attached to request (via Custom JWT):', req.user.email);
              console.log('--- AuthMiddleware Debug End (Success via Custom JWT) ---\n');
              next();

          } catch (customJwtError) {
              console.error('AuthMiddleware ERROR: Both Firebase ID Token and Custom JWT verification failed:', customJwtError.message);
              if (customJwtError.name === 'TokenExpiredError') {
                return res.status(401).json({ message: 'Not authorized, token expired.' });
              }
              return res.status(401).json({ message: 'Not authorized, token failed.' });
          }
      }

    } catch (error) {
      console.error('AuthMiddleware ERROR: General error during token processing:', error.message);
      return res.status(500).json({ message: 'Server error during authentication.' });
    }
  } else {
    console.error('AuthMiddleware ERROR: No token found in authorization header.');
    return res.status(401).json({ message: 'Not authorized, no token.' });
  }
};

module.exports = { protect };
