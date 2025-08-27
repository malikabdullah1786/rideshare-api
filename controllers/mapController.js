const { reverseGeocodeLatLng } = require('../utils/googleMaps');

// @desc    Get address from coordinates
// @route   POST /api/maps/reverse-geocode
// @access  Private
const reverseGeocode = async (req, res) => {
  const { lat, lng } = req.body;

  if (lat === undefined || lng === undefined) {
    return res.status(400).json({ message: 'Please provide lat and lng in the request body.' });
  }

  try {
    const address = await reverseGeocodeLatLng(lat, lng);
    res.status(200).json({ address: address });
  } catch (error) {
    console.error('Error in reverseGeocode controller:', error.message);
    res.status(400).json({ message: error.message || 'Server error while reverse geocoding.' });
  }
};

module.exports = {
  reverseGeocode,
};
