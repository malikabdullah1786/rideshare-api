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
      { key: 'bookingTimeLimitHours', value: 1, description: 'Users can book a ride up to 1 hour before departure.' },
      { key: 'cancellationTimeLimitHoursPassenger', value: 2, description: 'Riders can cancel up to 2 hours before departure.' },
      { key: 'cancellationTimeLimitHoursDriver', value: 4, description: 'Drivers can cancel up to 4 hours before departure.' },
    ];

    for (const setting of settingsToSeed) {
      const existingSetting = await Setting.findOne({ key: setting.key });
      if (!existingSetting) {
        await Setting.create(setting);
        console.log(`Default setting created: ${setting.key}`);
      } else {
        // Optional: Update existing settings to new defaults if needed
        // await Setting.updateOne({ key: setting.key }, { $set: { value: setting.value, description: setting.description } });
        // console.log(`Setting updated: ${setting.key}`);
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
