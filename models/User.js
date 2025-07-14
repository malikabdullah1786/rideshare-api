const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = mongoose.Schema(
  {
    firebaseUid: {
      type: String,
      required: true,
      unique: true,
    },
    name: {
      type: String,
      required: true,
      trim: true, // Trim whitespace
    },
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
    },
    password: {
      type: String,
      required: true,
    },
    phone: {
      type: String,
      required: true,
      trim: true,
    },
    cnic: {
      type: String,
      required: true,
      unique: true,
      trim: true,
    },
    address: {
      type: String,
      required: true,
      trim: true,
    },
    emergencyContact: {
      type: String,
      required: true,
      trim: true,
      default: 'N/A', // Explicit default if not provided or empty string
    },
    gender: {
      type: String,
      required: true,
      enum: ['Male', 'Female', 'Other', 'Unknown'], // Add 'Unknown' for default
      trim: true,
      default: 'Unknown', // Explicit default
    },
    age: {
      type: Number,
      required: true,
      min: 1, // Age must be at least 1
      default: 18, // Explicit default
    },
    userType: {
      type: String,
      required: true,
      enum: ['rider', 'driver'],
    },
    emailVerified: {
      type: Boolean,
      default: false,
    },
    profileCompleted: {
      type: Boolean,
      default: false,
    },
    carModel: {
      type: String,
      trim: true,
      // required: function() { return this.userType === 'driver'; } // Example: required for drivers
    },
    carRegistration: {
      type: String,
      trim: true,
      // required: function() { return this.userType === 'driver'; }
    },
    seatsAvailable: {
      type: Number,
      // required: function() { return this.userType === 'driver'; },
      min: 0,
    },
    averageRating: {
      type: Number,
      default: 0,
      min: 0,
      max: 5,
    },
    numRatings: {
      type: Number,
      default: 0,
      min: 0,
    },
  },
  {
    timestamps: true,
  }
);

// Hash password before saving
userSchema.pre('save', async function (next) {
  if (!this.isModified('password')) {
    next();
  }
  const salt = await bcrypt.genSalt(10);
  this.password = await bcrypt.hash(this.password, salt);
  next();
});

// Match user entered password to hashed password in database
userSchema.methods.matchPassword = async function (enteredPassword) {
  return await bcrypt.compare(enteredPassword, this.password);
};

const User = mongoose.model('User', userSchema);

module.exports = User;
