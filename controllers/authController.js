const User = require('../models/User');
const admin = require('firebase-admin');
const jwt = require('jsonwebtoken');

// Helper function to generate JWT
const generateToken = (id, userType, firebaseUid) => {
  const jwtSecret = process.env.JWT_SECRET;
  if (!jwtSecret) {
    console.error('JWT_SECRET is not defined in environment variables!');
    // In production, you might want to throw an error or handle this more gracefully
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

  console.log('\n--- registerUser Controller Debug Start ---');
  console.log('Received registration request for email:', email);
  console.log('User Type:', userType);

  if (!name || !email || !password || !phone || !cnic || !address || !userType) {
    console.error('Missing required fields for registration:', { name, email, password, phone, cnic, address, userType });
    return res.status(400).json({ message: 'Please enter all required fields.' });
  }

  try {
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

    let newFirebaseUser;
    try {
      newFirebaseUser = await admin.auth().createUser({
        email,
        password,
        displayName: name,
        phoneNumber: phone,
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

    let user;
    try {
      user = await User.create({
        name,
        email,
        password,
        phone,
        cnic,
        address,
        userType,
        firebaseUid: newFirebaseUser.uid,
      });
      console.log('Successfully created MongoDB user with ID:', user._id, 'Firebase UID:', user.firebaseUid);
    } catch (mongoError) {
      console.error('Error creating MongoDB user:', mongoError);
      try {
        await admin.auth().deleteUser(newFirebaseUser.uid);
        console.warn('Deleted Firebase user due to MongoDB creation failure:', newFirebaseUser.uid);
      } catch (deleteError) {
        console.error('Failed to delete Firebase user after MongoDB error:', deleteError);
      }
      return res.status(500).json({ message: `Failed to create user profile: ${mongoError.message}` });
    }

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

module.exports = {
  registerUser,
  loginUser,
  getUserProfile,
  updateUserProfile, // Ensure this is exported
};
