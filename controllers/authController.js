const User = require('../models/User');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const sendEmail = require('../utils/emailService');
const crypto = require('crypto');
const admin = require('firebase-admin'); // Import Firebase Admin SDK

// Generate JWT (for your backend's session, distinct from Firebase ID Token)
const generateToken = (id) => {
  return jwt.sign({ id }, process.env.JWT_SECRET, {
    expiresIn: '1h', // Token expires in 1 hour
  });
};

// @desc    Register a new user
// @route   POST /api/auth/register
// @access  Public
const registerUser = async (req, res) => {
  const {
    firebaseUid,
    email,
    password,
    name,
    cnic,
    phone,
    address,
    emergencyContact,
    gender,
    age,
    userType,
    emailVerified,
    profileCompleted,
    carModel,
    carRegistration,
    seatsAvailable,
  } = req.body;

  if (!firebaseUid || !email || !password || !name || !userType) {
    return res.status(400).json({ message: 'Please enter all required fields' });
  }

  try {
    const userExists = await User.findOne({ $or: [{ firebaseUid }, { email }, { cnic }, { phone }] });

    if (userExists) {
      return res.status(400).json({ message: 'User already exists with this Firebase UID, email, CNIC, or phone.' });
    }

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    const user = await User.create({
      firebaseUid,
      email,
      password: hashedPassword,
      name,
      cnic,
      phone,
      address,
      emergencyContact,
      gender,
      age,
      userType,
      emailVerified,
      profileCompleted,
      carModel: userType === 'driver' ? carModel : undefined,
      carRegistration: userType === 'driver' ? carRegistration : undefined,
      seatsAvailable: userType === 'driver' ? seatsAvailable : undefined,
    });

    if (user) {
      res.status(201).json({
        message: 'User registered successfully',
        user: {
          firebaseUid: user.firebaseUid, // Ensure Firebase UID is returned
          email: user.email,
          name: user.name,
          userType: user.userType,
          emailVerified: user.emailVerified,
          profileCompleted: user.profileCompleted,
        },
        token: generateToken(user._id),
      });
    } else {
      res.status(400).json({ message: 'Invalid user data' });
    }
  } catch (error) {
    console.error('Error during user registration:', error);
    res.status(500).json({ message: 'Server error during registration' });
  }
};

// @desc    Authenticate user & get token
// @route   POST /api/auth/login
// @access  Public
const loginUser = async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ message: 'Please enter all fields' });
  }

  try {
    const user = await User.findOne({ email });

    if (!user) {
      return res.status(401).json({ message: 'Invalid email or password' });
    }

    // IMPORTANT: If you are relying solely on Firebase Auth for password verification,
    // you should verify the password with Firebase here instead of bcrypt.
    // For now, assuming bcrypt is still used for local password check.
    const isMatch = await bcrypt.compare(password, user.password);

    if (!isMatch) {
      return res.status(401).json({ message: 'Invalid email or password' });
    }

    // After successful local authentication, you might want to generate a custom Firebase token
    // for the client to sign in with Firebase on the frontend, if they haven't already.
    // However, for protected routes, the client should send their Firebase ID Token.
    // This `loginUser` endpoint primarily serves to fetch the user's profile from your DB
    // and potentially provide a backend-specific JWT if needed for other non-Firebase-protected routes.

    res.json({
      message: 'Login successful',
      user: {
        firebaseUid: user.firebaseUid, // Ensure Firebase UID is returned here
        email: user.email,
        name: user.name,
        userType: user.userType,
        emailVerified: user.emailVerified,
        profileCompleted: user.profileCompleted,
      },
      token: generateToken(user._id), // This is your backend's JWT, not Firebase ID Token
    });
  } catch (error) {
    console.error('Error during user login:', error);
    res.status(500).json({ message: 'Server error during login' });
  }
};

// @desc    Get user profile (protected route)
// @route   GET /api/auth/profile
// @access  Private
const getUserProfile = async (req, res) => {
  // --- DEBUG LOG START ---
  console.log('\n--- getUserProfile Controller Debug Start ---');
  console.log('req.user at start of getUserProfile:', req.user ? req.user.email : 'undefined');
  console.log('--- getUserProfile Controller Debug End ---\n');
  // --- DEBUG LOG END ---

  try {
    // req.user is populated by the 'protect' middleware
    if (!req.user) {
      console.error('getUserProfile ERROR: req.user is null/undefined after protect middleware.');
      return res.status(401).json({ message: 'Authentication failed, user data not available.' });
    }
    
    const user = await User.findById(req.user._id).select('-password');
    if (user) {
      res.json({
        firebaseUid: user.firebaseUid,
        email: user.email,
        name: user.name,
        cnic: user.cnic,
        phone: user.phone,
        address: user.address,
        emergencyContact: user.emergencyContact,
        gender: user.gender,
        age: user.age,
        userType: user.userType,
        emailVerified: user.emailVerified,
        profileCompleted: user.profileCompleted,
        carModel: user.carModel,
        carRegistration: user.carRegistration,
        seatsAvailable: user.seatsAvailable,
        createdAt: user.createdAt,
      });
    } else {
      console.error('getUserProfile ERROR: User not found in DB for ID:', req.user._id);
      res.status(404).json({ message: 'User not found' });
    }
  } catch (error) {
    console.error('Error fetching user profile:', error);
    res.status(500).json({ message: 'Server error fetching profile' });
  }
};

// @desc    Update user profile (protected route)
// @route   PUT /api/auth/profile
// @access  Private
const updateUserProfile = async (req, res) => {
  try {
    const user = await User.findById(req.user._id);

    if (user) {
      user.name = req.body.name || user.name;
      user.cnic = req.body.cnic || user.cnic;
      user.phone = req.body.phone || user.phone;
      user.address = req.body.address || user.address;
      user.emergencyContact = req.body.emergencyContact || user.emergencyContact;
      user.gender = req.body.gender || user.gender;
      user.age = req.body.age || user.age;
      user.userType = req.body.userType || user.userType;
      user.emailVerified = req.body.emailVerified ?? user.emailVerified;
      user.profileCompleted = req.body.profileCompleted ?? user.profileCompleted;

      if (user.userType === 'driver') {
        user.carModel = req.body.carModel || user.carModel;
        user.carRegistration = req.body.carRegistration || user.carRegistration;
        user.seatsAvailable = req.body.seatsAvailable || user.seatsAvailable;
      } else {
        user.carModel = undefined;
        user.carRegistration = undefined;
        user.seatsAvailable = undefined;
      }

      const updatedUser = await user.save();

      res.json({
        message: 'Profile updated successfully',
        user: {
          firebaseUid: updatedUser.firebaseUid,
          email: updatedUser.email,
          name: updatedUser.name,
          userType: updatedUser.userType,
          emailVerified: updatedUser.emailVerified,
          profileCompleted: updatedUser.profileCompleted,
        },
      });
    } else {
      res.status(404).json({ message: 'User not found' });
    }
  } catch (error) {
    console.error('Error updating user profile:', error);
    res.status(500).json({ message: 'Server error updating profile' });
  }
};

// @desc    Request password reset link
// @route   POST /api/auth/forgotpassword
// @access  Public
const forgotPassword = async (req, res) => {
  const { email } = req.body;

  try {
    const user = await User.findOne({ email });

    if (!user) {
      return res.status(404).json({ message: 'No user found with that email' });
    }

    const resetToken = crypto.randomBytes(32).toString('hex');
    const resetPasswordExpire = Date.now() + 3600000;

    user.resetPasswordToken = resetToken;
    user.resetPasswordExpire = resetPasswordExpire;
    await user.save();

    const resetUrl = `${req.protocol}://${req.get('host')}/api/auth/resetpassword/${resetToken}`;

    const message = `
      <h1>You have requested a password reset</h1>
      <p>Please go to this link to reset your password:</p>
      <a href="${resetUrl}" clicktracking=off>${resetUrl}</a>
      <p>This link is valid for 1 hour.</p>
    `;

    try {
      await sendEmail({
        email: user.email,
        subject: 'Password Reset Request',
        message: message,
      });

      res.status(200).json({ message: 'Email sent successfully' });
    } catch (emailError) {
      console.error('Error sending password reset email:', emailError);
      user.resetPasswordToken = undefined;
      user.resetPasswordExpire = undefined;
      await user.save();
      res.status(500).json({ message: 'Email could not be sent' });
    }
  } catch (error) {
    console.error('Server error during password reset request:', error);
    res.status(500).json({ message: 'Server error during password reset request' });
  }
};

// @desc    Reset password (using token from email)
// @route   PUT /api/auth/resetpassword/:token
// @access  Public
const resetPassword = async (req, res) => {
  const resetPasswordToken = req.params.token;
  const { newPassword } = req.body;

  try {
    const user = await User.findOne({
      resetPasswordToken,
      resetPasswordExpire: { $gt: Date.now() },
    });

    if (!user) {
      return res.status(400).json({ message: 'Invalid or expired reset token' });
    }

    const salt = await bcrypt.genSalt(10);
    user.password = await bcrypt.hash(newPassword, salt);
    user.resetPasswordToken = undefined;
    user.resetPasswordExpire = undefined;

    await user.save();

    res.status(200).json({ message: 'Password reset successfully' });
  } catch (error) {
    console.error('Server error during password reset:', error);
    res.status(500).json({ message: 'Server error during password reset' });
  }
};


module.exports = {
  registerUser,
  loginUser,
  getUserProfile,
  updateUserProfile,
  forgotPassword,
  resetPassword,
};
