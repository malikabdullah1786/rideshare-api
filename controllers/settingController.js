const Setting = require('../models/Setting');

// @desc    Get public settings
// @route   GET /api/settings
// @access  Public
const getPublicSettings = async (req, res) => {
  try {
    // Define default settings to ensure the app works even with an empty database.
    // This object includes keys used by the rideController and the seed script to cover all bases.
    const defaultSettings = {
      // General settings
      isBookingAvailable: true,
      commissionRate: 0.15,

      // Settings as used by rideController.js
      bookingLeadTimeMinutes: 10,
      riderCancellationCutoffHours: 2,
      driverCancellationCutoffHours: 4,

      // Settings as defined in the (potentially outdated) seed script
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

    // FIXED: Do not expose sensitive settings like commissionRate to all users.
    // The frontend only needs the time limits for booking and cancellation.
    const publicSettings = {
      bookingTimeLimitHours: finalSettings.bookingTimeLimitHours,
      cancellationTimeLimitHoursPassenger: finalSettings.cancellationTimeLimitHoursPassenger,
      cancellationTimeLimitHoursDriver: finalSettings.cancellationTimeLimitHoursDriver,
    };

    res.json(publicSettings);
  } catch (error) {
    console.error('Error fetching public settings:', error);
    res.status(500).json({ message: 'Server Error' });
  }
};

module.exports = {
  getPublicSettings,
};
