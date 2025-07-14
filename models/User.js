const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = mongoose.Schema(
  {
    firebaseUid: {
      type: String,
      required: true,
      unique: true,
    },
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
    },
    password: { // Stored hashed password from Firebase Auth (or if local auth was used)
      type: String,
      required: true,
    },
    name: {
      type: String,
      required: true,
    },
    cnic: {
      type: String,
      required: true,
      unique: true,
    },
    phone: {
      type: String,
      required: true,
      unique: true,
    },
    address: {
      type: String,
      required: true,
    },
    emergencyContact: {
      type: String,
      required: true,
    },
    gender: {
      type: String,
      required: true,
      enum: ['Male', 'Female', 'Other'],
    },
    age: {
      type: Number,
      required: true,
    },
    userType: {
      type: String,
      required: true,
      enum: ['rider', 'driver'],
    },
    emailVerified: { // Reflects Firebase email verification status
      type: Boolean,
      default: false,
    },
    profileCompleted: { // Indicates if all extended profile fields are filled
      type: Boolean,
      default: false,
    },
    // Driver-specific fields (optional for riders)
    carModel: {
      type: String,
    },
    carRegistration: {
      type: String,
    },
    seatsAvailable: {
      type: Number,
    },
    // New: Rating fields for drivers
    averageRating: {
      type: Number,
      default: 0,
    },
    numRatings: {
      type: Number,
      default: 0,
    },
    resetPasswordToken: String,
    resetPasswordExpire: Date,
  },
  {
    timestamps: true, // Adds createdAt and updatedAt fields
  }
);

// Method to compare entered password with hashed password (if local auth was used)
userSchema.methods.matchPassword = async function (enteredPassword) {
  return await bcrypt.compare(enteredPassword, this.password);
};

const User = mongoose.model('User', userSchema);

module.exports = User;
