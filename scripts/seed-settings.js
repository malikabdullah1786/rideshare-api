const mongoose = require('mongoose');
const dotenv = require('dotenv');
const connectDB = require('../config/db');
const Setting = require('../models/Setting');

dotenv.config({ path: __dirname + '/../.env' });

const seedSettings = async () => {
  await connectDB();

  try {
    const settingsToSeed = [
      { key: 'commissionRate', value: 0.15, description: 'Default commission rate of 15%' },
      { key: 'bookingLeadTimeMinutes', value: 10, description: 'Users can book a ride up to 10 minutes before departure.' },
      { key: 'riderCancellationCutoffHours', value: 2, description: 'Riders can cancel up to 2 hours before departure.' },
      { key: 'driverCancellationCutoffHours', value: 4, description: 'Drivers can cancel up to 4 hours before departure.' },
    ];

    for (const setting of settingsToSeed) {
      const existingSetting = await Setting.findOne({ key: setting.key });
      if (!existingSetting) {
        await Setting.create(setting);
        console.log(`Default setting created: ${setting.key}`);
      } else {
        console.log(`Setting already exists: ${setting.key}`);
      }
    }

    console.log('Settings seeding process complete.');
    process.exit();
  } catch (error) {
    console.error('Error seeding settings:', error);
    process.exit(1);
  }
};

seedSettings();
