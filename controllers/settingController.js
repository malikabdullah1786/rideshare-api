const Setting = require('../models/Setting');

// @desc    Get public settings
// @route   GET /api/settings
// @access  Public
const getPublicSettings = async (req, res) => {
  try {
    const settings = await Setting.find({});
    // Convert array of settings to a key-value object
    const settingsMap = settings.reduce((acc, setting) => {
      acc[setting.key] = setting.value;
      return acc;
    }, {});
    res.json(settingsMap);
  } catch (error) {
    res.status(500).json({ message: 'Server Error' });
  }
};

module.exports = {
  getPublicSettings,
};
