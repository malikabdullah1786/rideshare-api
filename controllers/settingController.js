const Setting = require('../models/Setting');

// @desc    Get public settings
// @route   GET /api/settings
// @access  Public
const getPublicSettings = async (req, res) => {
  try {
    // Define default settings to ensure the app works even with an empty database
    const defaultSettings = {
      isBookingAvailable: true, // Crucial setting that was missing
      commissionRate: 0.15,
      bookingTimeLimitHours: 1,
      cancellationTimeLimitHoursPassenger: 2,
      cancellationTimeLimitHoursDriver: 4,
    };

    const settingsFromDb = await Setting.find({});

    // Convert settings from the database into a key-value map
    const dbSettingsMap = settingsFromDb.reduce((acc, setting) => {
      acc[setting.key] = setting.value;
      return acc;
    }, {});

    // Merge defaults with settings from the database.
    // Any setting present in the database will overwrite the default.
    const finalSettings = { ...defaultSettings, ...dbSettingsMap };

    res.json(finalSettings);
  } catch (error) {
    console.error('Error fetching public settings:', error);
    res.status(500).json({ message: 'Server Error' });
  }
};

module.exports = {
  getPublicSettings,
};
