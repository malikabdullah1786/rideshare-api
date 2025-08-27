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
  const { name, email, password, phone, cnic, address, emergencyContact, gender, age, userType, carModel, carRegistration, seatsAvailable } = req.body;

  console.log('\n--- registerUser Controller Debug Start ---');
  console.log('Received registration request for email:', email);
  console.log('User Type:', userType);
  console.log('Raw req.body from frontend:', req.body); // Log the raw body

  if (!name || !email || !password || !phone || !cnic || !address || !emergencyContact || !gender || !age || !userType) {
    console.error('Missing required fields for registration:', { name, email, password, phone, cnic, address, emergencyContact, gender, age, userType });
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
        phoneNumber: phone, // This should be E.164 from Flutter now
        emailVerified: false,
        disabled: false,
      });
      firebaseUid = newFirebaseUser.uid;
      console.log('Successfully created NEW Firebase user with UID:', firebaseUid);
    } catch (firebaseCreateError) {
      if (firebaseCreateError.code === 'auth/email-already-exists') {
        console.log('Firebase user with email already exists, retrieving existing UID.');
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
      if (firebaseUserExists) {
          console.log('MongoDB user already exists for Firebase UID:', firebaseUid, '. Duplicate registration attempt.');
          return res.status(400).json({ message: 'User with this email already exists and profile is complete.' });
      } else {
          console.warn('MongoDB user found for Firebase UID:', firebaseUid, ' but Firebase user was just created. Possible inconsistency.');
          return res.status(400).json({ message: 'User profile already exists for this Firebase account.' });
      }
    }

    // 3. If no MongoDB user found, create it
    const userDataForMongo = {
        name,
        email,
        password,
        phone,
        cnic,
        address,
        emergencyContact,
        gender,
        age,
        userType,
        firebaseUid: firebaseUid,
        // Optional fields, only include if they exist and are relevant
        ...(carModel && { carModel }),
        ...(carRegistration && { carRegistration }),
        ...(seatsAvailable !== undefined && { seatsAvailable }), // Check for undefined, as 0 is a valid value
    };

    console.log('Attempting to create MongoDB user with data:', userDataForMongo); // CRITICAL DEBUG LOG

    try {
      user = await User.create(userDataForMongo);
      console.log('Successfully created MongoDB user with ID:', user._id, 'Firebase UID:', user.firebaseUid);
    } catch (mongoError) {
      console.error('Error creating MongoDB user:', mongoError);
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
        address: user.address,
        userType: user.userType,
        firebaseUid: user.firebaseUid,
        averageRating: user.averageRating,
        numRatings: user.numRatings,
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
    const user = await User.findOne({ email });
    console.log('MongoDB user lookup result for email:', email, ':', user ? 'Found' : 'Not Found');

    if (!user) {
      return res.status(400).json({ message: 'Invalid credentials.' });
    }

    const isMatch = await user.matchPassword(password);
    console.log('Password match result:', isMatch);

    if (!isMatch) {
      return res.status(400).json({ message: 'Invalid credentials.' });
    }

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
        address: user.address,
        userType: user.userType,
        firebaseUid: user.firebaseUid,
        averageRating: user.averageRating,
        numRatings: user.numRatings,
        emailVerified: user.emailVerified, // <-- ADD THIS LINE
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
    user.emergencyContact = req.body.emergencyContact || user.emergencyContact; // Update this
    user.gender = req.body.gender || user.gender; // Update this
    user.age = req.body.age || user.age; // Update this
    // Also handle emailVerified status, if sent
    if (req.body.emailVerified !== undefined) {
      user.emailVerified = req.body.emailVerified;
    }

    const updatedUser = await user.save();

    res.status(200).json({
      message: 'Profile updated successfully',
      user: {
        _id: updatedUser._id,
        name: updatedUser.name,
        email: updatedUser.email,
        phone: updatedUser.phone,
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

  console.log(`Password reset request for token: ${token}. (Logic not fully implemented yet)`);
  res.status(200).json({ message: 'Password has been reset successfully.' });
  console.log('--- resetPassword Controller Debug End ---\n');
};


// @desc    Check user's email verification status against Firebase
// @route   POST /api/auth/check-verification
// @access  Private
const checkEmailVerification = async (req, res) => {
  try {
    const user = await User.findById(req.user._id);
    if (!user) {
      return res.status(404).json({ message: 'User not found.' });
    }

    // Get the very latest user record from Firebase
    const firebaseUser = await admin.auth().getUser(user.firebaseUid);
    const isVerified = firebaseUser.emailVerified;

    // If Firebase says verified but our DB says not, update our DB.
    if (isVerified && !user.emailVerified) {
      user.emailVerified = true;
      await user.save();
      console.log(`Updated email verification status for ${user.email} to true.`);
    }

    res.status(200).json({ emailVerified: user.emailVerified });
  } catch (error) {
    console.error('Error checking email verification status:', error);
    res.status(500).json({ message: 'Server error while checking verification status.' });
  }
};

module.exports = {
  registerUser,
  loginUser,
  getUserProfile,
  updateUserProfile,
  forgotPassword,
  resetPassword,
  checkEmailVerification,
};
