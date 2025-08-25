const express = require('express');
const router = express.Router();
const { reverseGeocode } = require('../controllers/mapController');
const { protect } = require('../middleware/authMiddleware');

// @route   POST /api/maps/reverse-geocode
// @desc    Get address from coordinates
// @access  Private
router.post('/reverse-geocode', protect, reverseGeocode);

module.exports = router;
