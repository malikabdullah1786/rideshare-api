const mongoose = require('mongoose');
const dotenv = require('dotenv');
const connectDB = require('../config/db');
const User = require('../models/User');

// Load environment variables from .env file in the root directory
dotenv.config({ path: __dirname + '/../.env' });

const makeAdmin = async (email) => {
  await connectDB();

  const user = await User.findOne({ email });

  if (!user) {
    console.error('User not found!');
    process.exit(1);
  }

  user.userType = 'admin';
  await user.save();

  console.log(`User ${email} is now an admin.`);
  process.exit(0);
};

const email = process.argv[2];
if (!email) {
  console.error('Please provide an email address. Usage: node scripts/make-admin.js <email>');
  process.exit(1);
}

makeAdmin(email);
