const User = require('../models/User');
const admin = require('firebase-admin');
const jwt = require('jsonwebtoken');

// Helper function to generate JWT
const generateToken = (id, userType, firebaseUid) => {
  const jwtSecret = process.env.JWT_SECRET;
  if (!jwtSecret) {
    console.error('JWT_SECRET is not defined in environment variables!');
    throw new Error('JWT_SECRET is not configured.');
  }
  return jwt.sign({ id, userType, firebaseUid }, jwtSecret, {
    expiresIn: '30d', // Token valid for 30 days
  });
};

// @desc    Register a new user or complete profile for existing Firebase user
// @route   POST /api/auth/register
// @access  Public
const registerUser = async (req, res) => {
  const { name, email, password, phone, cnic, address, userType } = req.body;

  console.log('\n--- registerUser Controller Debug Start ---');
  console.log('Received registration request for email:', email);
  console.log('User Type:', userType);

  if (!name || !email || !password || !phone || !cnic || !address || !userType) {
    console.error('Missing required fields for registration:', { name, email, password, phone, cnic, address, userType });
    return res.status(400).json({ message: 'Please enter all required fields.' });
  }

  try {
    let firebaseUid;
    let firebaseUserExists = false;

    // 1. Try to create user in Firebase Authentication
    try {
      const newFirebaseUser = await admin.auth().createUser({
        email,
        password,
        displayName: name,
        phoneNumber: phone,
        emailVerified: false,
        disabled: false,
      });
      firebaseUid = newFirebaseUser.uid;
      console.log('Successfully created NEW Firebase user with UID:', firebaseUid);
    } catch (firebaseCreateError) {
      if (firebaseCreateError.code === 'auth/email-already-exists') {
        console.log('Firebase user with email already exists, retrieving existing UID.');
        // If user already exists in Firebase, get their UID
        try {
          const existingFirebaseUser = await admin.auth().getUserByEmail(email);
          firebaseUid = existingFirebaseUser.uid;
          firebaseUserExists = true;
          console.log('Retrieved existing Firebase user UID:', firebaseUid);
        } catch (getFirebaseUserError) {
          console.error('Error retrieving existing Firebase user:', getFirebaseUserError);
          return res.status(500).json({ message: 'Firebase error retrieving existing user.' });
        }
      } else {
        console.error('Error creating Firebase user:', firebaseCreateError);
        return res.status(500).json({ message: `Failed to create Firebase user: ${firebaseCreateError.message}` });
      }
    }

    // 2. Check if MongoDB user profile already exists for this Firebase UID
    let user = await User.findOne({ firebaseUid: firebaseUid });

    if (user) {
      // If MongoDB user exists AND Firebase user existed, it's a duplicate registration attempt
      if (firebaseUserExists) {
          console.log('MongoDB user already exists for Firebase UID:', firebaseUid, '. Duplicate registration attempt.');
          return res.status(400).json({ message: 'User with this email already exists and profile is complete.' });
      } else {
          // This case should ideally not happen if Firebase user was just created,
          // but if it does, it means a race condition or inconsistent state.
          console.warn('MongoDB user found for Firebase UID:', firebaseUid, ' but Firebase user was just created. Possible inconsistency.');
          return res.status(400).json({ message: 'User profile already exists for this Firebase account.' });
      }
    }

    // 3. If no MongoDB user found, create it
    try {
      user = await User.create({
        name,
        email,
        password, // Password will be hashed by pre-save hook in User model
        phone,
        cnic,
        address,
        userType,
        firebaseUid: firebaseUid, // Store Firebase UID
      });
      console.log('Successfully created MongoDB user with ID:', user._id, 'Firebase UID:', user.firebaseUid);
    } catch (mongoError) {
      console.error('Error creating MongoDB user:', mongoError);
      // If MongoDB user creation fails, consider deleting the Firebase user to avoid orphaned accounts
      try {
        await admin.auth().deleteUser(firebaseUid);
        console.warn('Deleted Firebase user due to MongoDB creation failure:', firebaseUid);
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

  console.log('\n--- loginUser Controller Debug Start ---');
  console.log('Login attempt for email:', email);

  if (!email || !password) {
    return res.status(400).json({ message: 'Please enter all fields.' });
  }

  try {
    // In a typical Firebase-integrated app, login would involve:
    // 1. Frontend authenticates with Firebase (e.g., signInWithEmailAndPassword)
    // 2. Frontend gets Firebase ID Token
    // 3. Frontend sends Firebase ID Token to this backend /api/auth/login route
    // 4. Backend verifies ID Token (admin.auth().verifyIdToken(idToken))
    // 5. Extracts UID from verified token, then looks up user in MongoDB.

    // Your current login route seems to be directly checking email/password against MongoDB.
    // If you intend to use Firebase for login, you'd need to adjust the frontend to send the Firebase ID Token
    // and this backend route to verify it instead of checking password directly.

    const user = await User.findOne({ email });
    console.log('MongoDB user lookup result for email:', email, ':', user ? 'Found' : 'Not Found');

    if (!user) {
      return res.status(400).json({ message: 'Invalid credentials.' });
    }

    // If user exists, check password (assuming it's hashed in MongoDB)
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
  console.log('\n--- getUserProfile Controller Debug Start ---');
  console.log('Request received for user profile. req.user (from authMiddleware):', req.user ? req.user.email : 'undefined');

  if (!req.user) {
    console.error('getUserProfile: req.user is undefined, indicating authMiddleware failed.');
    return res.status(401).json({ message: 'Not authorized, no user data.' });
  }

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

// @desc    Update user profile
// @route   PUT /api/auth/profile
// @access  Private
const updateUserProfile = async (req, res) => {
  console.log('\n--- updateUserProfile Controller Debug Start ---');
  console.log('Request received to update profile for user:', req.user ? req.user.email : 'undefined');

  if (!req.user) {
    console.error('updateUserProfile: req.user is undefined, indicating authMiddleware failed.');
    return res.status(401).json({ message: 'Not authorized, no user data.' });
  }

  const user = await User.findById(req.user._id);

  if (user) {
    user.name = req.body.name || user.name;
    user.email = req.body.email || user.email;
    user.phone = req.body.phone || user.phone;
    user.cnic = req.body.cnic || user.cnic;
    user.address = req.body.address || user.address;
    // userType should generally not be changed via profile update
    // password should be updated via a separate route or method

    const updatedUser = await user.save();

    res.status(200).json({
      message: 'Profile updated successfully',
      user: {
        _id: updatedUser._id,
        name: updatedUser.name,
        email: updatedUser.email,
        phone: updatedUser.phone,
        cnic: updatedUser.cnic,
        address: updatedUser.address,
        userType: updatedUser.userType,
        firebaseUid: updatedUser.firebaseUid,
        averageRating: updatedUser.averageRating,
        numRatings: updatedUser.numRatings,
      },
    });
    console.log('--- updateUserProfile Controller Debug End ---\n');
  } else {
    console.error('updateUserProfile: User not found in DB for update:', req.user._id);
    res.status(404).json({ message: 'User not found.' });
  }
};

// @desc    Request password reset (placeholder)
// @route   POST /api/auth/forgotpassword
// @access  Public
const forgotPassword = async (req, res) => {
  console.log('\n--- forgotPassword Controller Debug Start ---');
  const { email } = req.body;
  if (!email) {
    return res.status(400).json({ message: 'Please provide an email address.' });
  }
  // --- Implement actual password reset logic here ---
  // 1. Find user by email
  // 2. Generate a unique reset token (e.g., using crypto.randomBytes)
  // 3. Save the token and its expiry to the user's document in MongoDB
  // 4. Send an email to the user with a link containing the reset token
  //    (e.g., `https://your-frontend.com/reset-password?token=${resetToken}`)
  console.log(`Forgot password request for: ${email}. (Logic not fully implemented yet)`);
  res.status(200).json({ message: 'If a user with that email exists, a password reset link has been sent.' });
  console.log('--- forgotPassword Controller Debug End ---\n');
};

// @desc    Reset password using token (placeholder)
// @route   PUT /api/auth/resetpassword/:token
// @access  Public
const resetPassword = async (req, res) => {
  console.log('\n--- resetPassword Controller Debug Start ---');
  const { token } = req.params;
  const { password } = req.body;

  if (!password || password.length < 6) {
    return res.status(400).json({ message: 'Please provide a new password with at least 6 characters.' });
  }

  // --- Implement actual password reset logic here ---
  // 1. Find user by the reset token and ensure it's not expired
  // 2. Hash the new password and update the user's password in MongoDB
  // 3. Invalidate the reset token
  console.log(`Password reset request for token: ${token}. (Logic not fully implemented yet)`);
  res.status(200).json({ message: 'Password has been reset successfully.' });
  console.log('--- resetPassword Controller Debug End ---\n');
};


module.exports = {
  registerUser,
  loginUser,
  getUserProfile,
  updateUserProfile,
  forgotPassword,
  resetPassword,
};
