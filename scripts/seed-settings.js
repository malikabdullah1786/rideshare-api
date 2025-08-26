const mongoose = require('mongoose');
const dotenv = require('dotenv');
const connectDB = require('../config/db');
const Setting = require('../models/Setting');

dotenv.config({ path: __dirname + '/../.env' });

const seedSettings = async () => {
  await connectDB();

  try {
    const commissionSetting = await Setting.findOne({ key: 'commissionRate' });

    if (!commissionSetting) {
      await Setting.create({
        key: 'commissionRate',
        value: 0.15, // Default commission rate of 15%
      });
      console.log('Default commissionRate setting created.');
    } else {
      console.log('commissionRate setting already exists.');
    }

    process.exit();
  } catch (error) {
    console.error('Error seeding settings:', error);
    process.exit(1);
  }
};

seedSettings();
