const express = require('express');
const router = express.Router();
const { 
  postRide, 
  getRides, 
  bookRide, 
  cancelBooking, // New
  cancelRide,    // New
  getMyPostedRides, 
  getMyBookedRides,
  getDriverEarnings // New
} = require('../controllers/rideController');
const { protect, isDriver, isRider } = require('../middleware/authMiddleware');

// GET /api/rides - Get all rides (can be filtered)
router.get('/', protect, getRides); 

// POST /api/rides/post - Post a new ride (only for drivers)
router.post('/post', protect, isDriver, postRide); 

// POST /api/rides/:id/book - Book a ride (only for riders)
router.post('/:id/book', protect, isRider, bookRide);

// PUT /api/rides/:id/cancel-booking - Cancel a booking by a rider
router.put('/:id/cancel-booking', protect, isRider, cancelBooking);

// PUT /api/rides/:id/cancel-ride - Cancel a ride by a driver
router.put('/:id/cancel-ride', protect, isDriver, cancelRide);

// GET /api/rides/my-posted-rides - Get rides posted by the authenticated driver
router.get('/my-posted-rides', protect, isDriver, getMyPostedRides);

// GET /api/rides/my-booked-rides - Get rides booked by the authenticated rider
router.get('/my-booked-rides', protect, isRider, getMyBookedRides);

// GET /api/rides/earnings - Get driver's earnings
router.get('/earnings', protect, isDriver, getDriverEarnings);


module.exports = router;
