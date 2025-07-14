const User = require('../models/User');
const admin = require('firebase-admin');
const jwt = require('jsonwebtoken');

// Helper function to generate JWT
const generateToken = (id, userType, firebaseUid) => {
  // Ensure JWT_SECRET is loaded from environment variables
  const jwtSecret = process.env.JWT_SECRET;
  if (!jwtSecret) {
    console.error('JWT_SECRET is not defined in environment variables!');
    throw new Error('JWT_SECRET is not configured.');
  }
  return jwt.sign({ id, userType, firebaseUid }, jwtSecret, {
    expiresIn: '30d', // Token valid for 30 days
  });
};

// @desc    Register a new user
// @route   POST /api/auth/register
// @access  Public
const registerUser = async (req, res) => {
  const { name, email, password, phone, cnic, address, userType } = req.body;

  // --- DEBUG LOGS START ---
  console.log('\n--- registerUser Controller Debug Start ---');
  console.log('Received registration request for email:', email);
  console.log('User Type:', userType);
  // --- DEBUG LOGS END ---

  if (!name || !email || !password || !phone || !cnic || !address || !userType) {
    console.error('Missing required fields for registration:', { name, email, password, phone, cnic, address, userType });
    return res.status(400).json({ message: 'Please enter all required fields.' });
  }

  try {
    // 1. Check if user already exists in Firebase
    let firebaseUser;
    try {
      firebaseUser = await admin.auth().getUserByEmail(email);
      console.log('Firebase user already exists with email:', email, 'UID:', firebaseUser.uid);
      return res.status(400).json({ message: 'User with this email already exists.' });
    } catch (firebaseError) {
      if (firebaseError.code === 'auth/user-not-found') {
        console.log('Firebase user not found, proceeding to create new Firebase user.');
      } else {
        console.error('Error checking Firebase user existence:', firebaseError);
        return res.status(500).json({ message: 'Firebase error during user check.' });
      }
    }

    // 2. Create user in Firebase Authentication
    let newFirebaseUser;
    try {
      newFirebaseUser = await admin.auth().createUser({
        email,
        password,
        displayName: name,
        phoneNumber: phone, // Firebase phone number format might need +countrycode
        emailVerified: false,
        disabled: false,
      });
      console.log('Successfully created Firebase user with UID:', newFirebaseUser.uid);
    } catch (firebaseCreateError) {
      console.error('Error creating Firebase user:', firebaseCreateError);
      if (firebaseCreateError.code === 'auth/email-already-exists') {
        return res.status(400).json({ message: 'User with this email already exists in Firebase.' });
      }
      return res.status(500).json({ message: `Failed to create Firebase user: ${firebaseCreateError.message}` });
    }

    // 3. Create user in MongoDB
    let user;
    try {
      user = await User.create({
        name,
        email,
        password, // Password will be hashed by pre-save hook in User model
        phone,
        cnic,
        address,
        userType,
        firebaseUid: newFirebaseUser.uid, // Store Firebase UID
      });
      console.log('Successfully created MongoDB user with ID:', user._id, 'Firebase UID:', user.firebaseUid);
    } catch (mongoError) {
      console.error('Error creating MongoDB user:', mongoError);
      // If MongoDB user creation fails, consider deleting the Firebase user to avoid orphaned accounts
      try {
        await admin.auth().deleteUser(newFirebaseUser.uid);
        console.warn('Deleted Firebase user due to MongoDB creation failure:', newFirebaseUser.uid);
      } catch (deleteError) {
        console.error('Failed to delete Firebase user after MongoDB error:', deleteError);
      }
      return res.status(500).json({ message: `Failed to create user profile: ${mongoError.message}` });
    }

    // 4. Generate JWT token
    const token = generateToken(user._id, user.userType, user.firebaseUid);
    console.log('Generated JWT token.');

    res.status(201).json({
      message: 'User registered successfully',
      token,
      user: {
        _id: user._id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        cnic: user.cnic,
        address: user.address,
        userType: user.userType,
        firebaseUid: user.firebaseUid,
      },
    });
    console.log('--- registerUser Controller Debug End ---\n');

  } catch (error) {
    console.error('General error during user registration:', error);
    res.status(500).json({ message: 'Server error during registration.' });
  }
};

// @desc    Authenticate user (login)
// @route   POST /api/auth/login
// @access  Public
const loginUser = async (req, res) => {
  const { email, password } = req.body;

  // --- DEBUG LOGS START ---
  console.log('\n--- loginUser Controller Debug Start ---');
  console.log('Login attempt for email:', email);
  // --- DEBUG LOGS END ---

  if (!email || !password) {
    return res.status(400).json({ message: 'Please enter all fields.' });
  }

  try {
    // 1. Authenticate with Firebase (to get Firebase UID and token for JWT)
    // This typically involves Firebase Client SDK on frontend, sending ID token to backend.
    // Here, we're assuming the backend might directly verify password if needed,
    // but usually, the frontend sends the Firebase ID token after client-side login.
    // For simplicity, let's assume the frontend sends the Firebase ID token.
    // If you're directly logging in with email/password here, you'd use Firebase Admin SDK's
    // signInWithEmailAndPassword (which is not directly available in Admin SDK for client-side auth).
    // The common flow is: Frontend authenticates with Firebase, gets ID token, sends ID token to backend.
    // Backend verifies ID token, then looks up user in MongoDB.

    // Let's assume for this login route, the frontend sends the Firebase ID token in the header or body
    // and we verify it to get the UID. If not, this login route needs to be adjusted.
    // For now, we'll just check MongoDB directly for password.
    // A more complete flow would be:
    // 1. Frontend sends email/password to Firebase Client SDK.
    // 2. Firebase Client SDK returns ID Token.
    // 3. Frontend sends ID Token to this backend /api/auth/login route.
    // 4. Backend verifies ID Token (admin.auth().verifyIdToken(idToken)).
    // 5. Extracts UID from verified token, then looks up user in MongoDB.

    // For now, let's stick to simple email/password check against MongoDB
    const user = await User.findOne({ email });
    console.log('MongoDB user lookup result for email:', email, ':', user ? 'Found' : 'Not Found');

    if (!user) {
      return res.status(400).json({ message: 'Invalid credentials.' });
    }

    // Compare provided password with hashed password in DB
    const isMatch = await user.matchPassword(password);
    console.log('Password match result:', isMatch);

    if (!isMatch) {
      return res.status(400).json({ message: 'Invalid credentials.' });
    }

    // Generate JWT token using MongoDB user ID and Firebase UID
    const token = generateToken(user._id, user.userType, user.firebaseUid);
    console.log('Generated JWT token for login.');

    res.status(200).json({
      message: 'Logged in successfully',
      token,
      user: {
        _id: user._id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        cnic: user.cnic,
        address: user.address,
        userType: user.userType,
        firebaseUid: user.firebaseUid,
      },
    });
    console.log('--- loginUser Controller Debug End ---\n');

  } catch (error) {
    console.error('Error during user login:', error);
    res.status(500).json({ message: 'Server error during login.' });
  }
};

// @desc    Get user profile
// @route   GET /api/auth/profile
// @access  Private
const getUserProfile = async (req, res) => {
  // The 'req.user' object is populated by the authMiddleware
  // --- DEBUG LOGS START ---
  console.log('\n--- getUserProfile Controller Debug Start ---');
  console.log('Request received for user profile. req.user (from authMiddleware):', req.user ? req.user.email : 'undefined');
  // --- DEBUG LOGS END ---

  if (!req.user) {
    console.error('getUserProfile: req.user is undefined, indicating authMiddleware failed.');
    return res.status(401).json({ message: 'Not authorized, no user data.' });
  }

  // req.user already contains the user document from MongoDB
  res.status(200).json({
    _id: req.user._id,
    name: req.user.name,
    email: req.user.email,
    phone: req.user.phone,
    cnic: req.user.cnic,
    address: req.user.address,
    userType: req.user.userType,
    firebaseUid: req.user.firebaseUid,
    averageRating: req.user.averageRating,
    numRatings: req.user.numRatings,
  });
  console.log('--- getUserProfile Controller Debug End ---\n');
};

module.exports = {
  registerUser,
  loginUser,
  getUserProfile,
};
