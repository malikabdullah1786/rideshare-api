const express = require('express');
const router = express.Router();
const {
  postRide,
  getRides,
  bookRide,
  cancelBooking,
  cancelRide,
  completeRide,
  getMyPostedRides,
  getMyBookedRides,
  getDriverEarnings,
  rateDriver,
  adjustFare,
} = require('../controllers/rideController'); // Ensure all functions are imported

const { protect } = require('../middleware/authMiddleware');

// Public routes (or accessible to all authenticated users)
router.get('/', protect, getRides); // Get all active rides with filters

// Driver specific routes
router.post('/post', protect, postRide); // Post a new ride
router.get('/my-posted-rides', protect, getMyPostedRides); // Get rides posted by driver
router.put('/:id/cancel-ride', protect, cancelRide); // Driver cancels their ride
router.put('/:id/complete-ride', protect, completeRide); // Driver marks ride as complete
router.put('/:id/adjust-fare', protect, adjustFare); // Driver adjusts the fare of a ride
router.get('/earnings', protect, getDriverEarnings); // Get driver's earnings

// Rider specific routes
router.post('/:id/book', protect, bookRide); // Book a seat on a ride (This is likely line 19)
router.put('/:id/cancel-booking', protect, cancelBooking); // Rider cancels their booking
router.get('/my-booked-rides', protect, getMyBookedRides); // Get rides booked by rider
router.post('/:id/rate-driver', protect, rateDriver); // Rider rates a driver

module.exports = router;
