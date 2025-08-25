const Ride = require('../models/Ride');
const User = require('../models/User'); // To populate driver details
const {
  geocodeAddress,
  getDistanceMatrix,
} = require('../utils/googleMaps');

// @desc    Post a new ride
// @route   POST /api/rides/post
// @access  Private (Driver only)
const postRide = async (req, res) => {
  const { from, to, price, seats, departureTime } = req.body;

  if (!req.user || req.user.userType !== 'driver') {
    return res.status(403).json({ message: 'Only drivers can post rides.' });
  }

  if (!req.user.isApproved) {
    return res.status(403).json({ message: 'Your account is not approved to post rides yet.' });
  }

  if (!from || !to || !price || !seats || !departureTime) {
    return res.status(400).json({ message: 'Please include all ride details.' });
  }

  try {
    const origin = await geocodeAddress(from);
    const destination = await geocodeAddress(to);

    const distanceMatrix = await getDistanceMatrix(origin, destination);
    const distance = distanceMatrix.distance.text;
    const duration = distanceMatrix.duration.text;

    const suggestedPrice = (distanceMatrix.distance.value / 1000) * 0.5;

    const parsedDepartureTime = new Date(departureTime);

    const ride = await Ride.create({
      driver: req.user._id,
      driverName: req.user.name,
      driverPhone: req.user.phone,
      from,
      to,
      origin,
      destination,
      distance,
      duration,
      price,
      seats,
      seatsAvailable: seats,
      departureTime: parsedDepartureTime,
      status: 'active',
    });

    res.status(201).json({
      message: 'Ride posted successfully',
      ride: ride,
      suggestedPrice: suggestedPrice.toFixed(2),
    });
  } catch (error) {
    console.error('Error posting ride:', error);
    res.status(500).json({ message: 'Server error posting ride' });
  }
};

// @desc    Get all active rides with optional filters
// @route   GET /api/rides
// @access  Private (Rider or Driver)
const getRides = async (req, res) => {
  const { from, to, date, time } = req.query;

  let query = {
    status: 'active',
    departureTime: { $gt: new Date() }
  };

  if (from) {
    query.from = { $regex: from, $options: 'i' };
  }
  if (to) {
    query.to = { $regex: to, $options: 'i' };
  }

  if (date) {
    const selectedDate = new Date(date);
    selectedDate.setHours(0, 0, 0, 0);

    const nextDay = new Date(selectedDate);
    nextDay.setDate(selectedDate.getDate() + 1);

    query.departureTime.$gte = selectedDate;
    query.departureTime.$lt = nextDay;
  }

  if (time && date) {
    const [hours, minutes] = time.split(':').map(Number);
    const selectedDateTime = new Date(date);
    selectedDateTime.setHours(hours, minutes, 0, 0);

    query.departureTime.$gte = selectedDateTime;
  }

  try {
    // Populate driver's averageRating, numRatings, AND carModel
    const rides = await Ride.find(query)
      .populate('driver', 'averageRating numRatings carModel') // ADDED 'carModel' here
      .sort({ departureTime: 1 });

    res.status(200).json(rides);
  } catch (error) {
    console.error('Error fetching rides:', error);
    res.status(500).json({ message: 'Server error fetching rides' });
  }
};

// @desc    Book a seat(s) on a ride
// @route   POST /api/rides/:id/book
// @access  Private (Rider only)
const bookRide = async (req, res) => {
  const rideId = req.params.id;
  const { passengersToBook } = req.body;

  console.log('RideController DEBUG: Received booking request for rideId:', rideId);
  console.log('RideController DEBUG: Request Headers:', req.headers);
  console.log('RideController DEBUG: req.body received:', req.body);
  console.log('RideController DEBUG: passengersToBook extracted:', passengersToBook);

  if (!passengersToBook || !Array.isArray(passengersToBook) || passengersToBook.length === 0) {
    return res.status(400).json({ message: 'Please provide passenger details to book.' });
  }

  if (!req.user || req.user.userType !== 'rider') {
    return res.status(403).json({ message: 'Only riders can book rides.' });
  }

  try {
    const ride = await Ride.findById(rideId);

    if (!ride) {
      return res.status(404).json({ message: 'Ride not found.' });
    }

    if (ride.driver.toString() === req.user._id.toString()) {
      return res.status(400).json({ message: 'Drivers cannot book their own rides.' });
    }

    let totalSeatsToBook = 0;
    const newBookings = [];

    for (const p of passengersToBook) {
      console.log('RideController DEBUG: Processing passenger object (inside loop):', p);
      console.log('RideController DEBUG: Passenger pickupAddress (inside loop):', p.pickupAddress);
      console.log('RideController DEBUG: Passenger dropoffAddress (inside loop):', p.dropoffAddress);
      console.log('RideController DEBUG: Passenger contactPhone (inside loop):', p.contactPhone);

      if (!p.bookedSeats || p.bookedSeats <= 0 || !p.pickupAddress || !p.dropoffAddress || !p.contactPhone) {
        return res.status(400).json({ message: 'Invalid passenger booking details provided. Ensure all fields are filled.' });
      }
      totalSeatsToBook += p.bookedSeats;

      const existingBookingForThisPerson = ride.passengers.some(
        (existingP) =>
          existingP.user.toString() === req.user._id.toString() &&
          existingP.contactPhone === p.contactPhone &&
          existingP.pickupAddress === p.pickupAddress &&
          existingP.dropoffAddress === p.dropoffAddress &&
          existingP.status === 'accepted'
      );

      if (existingBookingForThisPerson) {
        return res.status(400).json({ message: `A booking for ${p.contactPhone} with these details already exists on this ride.` });
      }

      newBookings.push({
        user: req.user._id,
        bookedSeats: p.bookedSeats,
        pickupAddress: p.pickupAddress,
        dropoffAddress: p.dropoffAddress,
        contactPhone: p.contactPhone,
        status: 'accepted',
      });
    }

    if (ride.seatsAvailable < totalSeatsToBook) {
      return res.status(400).json({ message: `Not enough seats available. Only ${ride.seatsAvailable} left.` });
    }

    ride.seatsAvailable -= totalSeatsToBook;
    ride.passengers.push(...newBookings);

    await ride.save();

    res.status(200).json({
      message: 'Ride booked successfully!',
      ride: ride,
    });
  } catch (error) {
    console.error('Error booking ride:', error);
    if (error.name === 'ValidationError') {
      const messages = Object.values(error.errors).map(err => err.message);
      return res.status(400).json({ message: `Validation failed: ${messages.join(', ')}` });
    }
    res.status(500).json({ message: 'Server error booking ride' });
  }
};

// @desc    Cancel a booked ride (by rider)
// @route   PUT /api/rides/:id/cancel-booking
// @access  Private (Rider only)
const cancelBooking = async (req, res) => {
  const rideId = req.params.id;
  const { cancellationReason } = req.body;

  if (!req.user || req.user.userType !== 'rider') {
    return res.status(403).json({ message: 'Only riders can cancel bookings.' });
  }

  try {
    const ride = await Ride.findById(rideId);

    if (!ride) {
      return res.status(404).json({ message: 'Ride not found.' });
    }

    const bookingIndex = ride.passengers.findIndex(
      (p) => p.user.toString() === req.user._id.toString() && p.status === 'accepted'
    );

    if (bookingIndex === -1) {
      return res.status(404).json({ message: 'Active booking not found for this ride by your account.' });
    }

    const bookedSeats = ride.passengers[bookingIndex].bookedSeats;

    ride.passengers[bookingIndex].status = 'cancelled_by_rider';
    ride.passengers[bookingIndex].cancellationReason = cancellationReason || 'No reason provided';

    ride.seatsAvailable += bookedSeats;

    await ride.save();
    console.log(`Rider ${req.user._id} cancelled booking for ride ${rideId} with reason: ${cancellationReason}`);
    res.status(200).json({ message: 'Ride booking cancelled successfully.' });
  } catch (error) {
    console.error('Error cancelling booking:', error);
    res.status(500).json({ message: 'Server error cancelling booking' });
  }
};

// @desc    Cancel a posted ride (by driver)
// @route   PUT /api/rides/:id/cancel-ride
// @access  Private (Driver only)
const cancelRide = async (req, res) => {
  const rideId = req.params.id;
  const { cancellationReason } = req.body;

  if (!req.user || req.user.userType !== 'driver') {
    return res.status(403).json({ message: 'Only drivers can cancel their posted rides.' });
  }

  try {
    const ride = await Ride.findById(rideId);

    if (!ride) {
      return res.status(404).json({ message: 'Ride not found.' });
    }

    if (ride.driver.toString() !== req.user._id.toString()) {
      return res.status(403).json({ message: 'You are not authorized to cancel this ride.' });
    }

    if (ride.status === 'cancelled' || ride.status === 'completed') {
      return res.status(400).json({ message: 'Ride is already cancelled or completed.' });
    }

    ride.status = 'cancelled';
    ride.cancellationReason = cancellationReason || 'No reason provided';
    
    await ride.save();
    console.log(`Driver ${req.user._id} cancelled ride ${rideId} with reason: ${cancellationReason}`);
    res.status(200).json({ message: 'Ride cancelled successfully.' });
  } catch (error) {
    console.error('Error cancelling ride:', error);
    res.status(500).json({ message: 'Server error cancelling ride' });
  }
};

// @desc    Mark a ride as completed (by driver)
// @route   PUT /api/rides/:id/complete-ride
// @access  Private (Driver only)
const completeRide = async (req, res) => {
  const rideId = req.params.id;

  console.log('\n--- completeRide Controller Debug Start ---');
  console.log('req.user at start of completeRide:', req.user ? req.user.email : 'undefined');
  console.log('Attempting to complete ride ID:', rideId);

  if (!req.user || req.user.userType !== 'driver') {
    console.error('completeRide ERROR: Attempt to complete ride by non-driver or unauthenticated user.');
    return res.status(403).json({ message: 'Only drivers can complete rides.' });
  }

  try {
    const ride = await Ride.findById(rideId);

    if (!ride) {
      console.error('completeRide ERROR: Ride not found for ID:', rideId);
      return res.status(404).json({ message: 'Ride not found.' });
    }

    if (ride.driver.toString() !== req.user._id.toString()) {
      console.error('completeRide ERROR: Unauthorized attempt to complete ride. Driver ID mismatch.');
      return res.status(403).json({ message: 'You are not authorized to complete this ride.' });
    }

    if (ride.status === 'completed') {
      console.warn('completeRide WARNING: Ride already marked as completed for ID:', rideId);
      return res.status(400).json({ message: 'Ride is already marked as completed.' });
    }

    ride.status = 'completed';
    ride.passengers.forEach(p => {
      if (p.status === 'accepted') {
        p.status = 'completed_by_driver';
      }
    });

    await ride.save();
    console.log(`Driver ${req.user._id} marked ride ${rideId} as completed.`);

    res.status(200).json({ message: 'Ride marked as completed successfully.' });
  } catch (error) {
    console.error('Error completing ride:', error);
    res.status(500).json({ message: 'Server error completing ride' });
  } finally {
    console.log('--- completeRide Controller Debug End ---\n');
  }
};


// @desc    Get rides posted by the authenticated driver
// @route   GET /api/rides/my-posted-rides
// @access  Private (Driver only)
const getMyPostedRides = async (req, res) => {
  if (!req.user || req.user.userType !== 'driver') {
    return res.status(403).json({ message: 'Only drivers can view their posted rides.' });
  }

  try {
    const rides = await Ride.find({ driver: req.user._id })
      .populate('passengers.user', 'name email phone')
      .sort({ createdAt: -1 });

    res.status(200).json(rides);
  } catch (error) {
    console.error('Error fetching posted rides:', error);
    res.status(500).json({ message: 'Server error fetching posted rides' });
  }
};

// @desc    Get rides booked by the authenticated rider
// @route   GET /api/rides/my-booked-rides
// @access  Private (Rider only)
const getMyBookedRides = async (req, res) => {
  console.log('\n--- getMyBookedRides Controller Debug Start (Entry) ---');
  console.log('req.user at start of getMyBookedRides:', req.user ? req.user.email : 'undefined');

  if (!req.user || req.user.userType !== 'rider') {
    console.error('getMyBookedRides ERROR: Attempt to fetch booked rides by non-rider or unauthenticated user.');
    return res.status(403).json({ message: 'Only riders can view their booked rides.' });
  }

  try {
    // Populate driver's averageRating, numRatings, AND carModel
    // Also populate the 'user' field within the 'passengers' array
    const rides = await Ride.find({ 'passengers.user': req.user._id })
      .populate('driver', 'averageRating numRatings carModel') // ADDED 'carModel' here
      .populate('passengers.user', 'name email phone') // Populate relevant passenger user details
      .sort({ departureTime: 1 });

    console.log('Rides fetched and populated for rider:');
    rides.forEach(ride => {
      console.log(`  Ride ID: ${ride._id}, From: ${ride.from}, To: ${ride.to}, Driver: ${ride.driverName}, Phone: ${ride.driverPhone}, Status: ${ride.status}`);
      if (ride.driver) {
        console.log(`    Driver Rating (from populated driver obj): ${ride.driver.averageRating}, Car Model: ${ride.driver.carModel}`);
      } else {
        console.log('    Driver (populated object): NOT POPULATED or NULL');
      }
      console.log(`    Departure Time (from DB): ${ride.departureTime}`);
      console.log(`    Departure Time (toLocaleString, server's local): ${ride.departureTime.toLocaleString()}`);
      console.log(`    CreatedAt (from DB): ${ride.createdAt}`);
      console.log(`    CreatedAt (toLocaleString, server's local): ${ride.createdAt.toLocaleString()}`);
      ride.passengers.forEach(p => {
        console.log(`    Passenger Booking User ID: ${p.user._id}, Status: ${p.status}, Booked Seats: ${p.bookedSeats}`);
      });
    });
    console.log('--- getMyBookedRides Controller Debug End ---\n');

    res.status(200).json(rides);
  } catch (error) {
    console.error('Error fetching booked rides:', error);
    res.status(500).json({ message: 'Server error fetching booked rides' });
  }
};

// @desc    Get driver's earnings
// @route   GET /api/rides/earnings
// @access  Private (Driver only)
const getDriverEarnings = async (req, res) => {
  if (!req.user || req.user.userType !== 'driver') {
    return res.status(403).json({ message: 'Only drivers can view earnings.' });
  }

  try {
    const completedRides = await Ride.find({
      driver: req.user._id,
      status: 'completed',
    });

    let totalEarnings = 0;
    let completedRideCount = 0;

    for (const ride of completedRides) {
      const seatsBookedOnThisRide = ride.passengers.reduce((sum, p) => {
        if (p.status === 'completed_by_driver') {
          return sum + p.bookedSeats;
        }
        return sum;
      }, 0);
      totalEarnings += ride.price * seatsBookedOnThisRide;
      if (seatsBookedOnThisRide > 0) {
        completedRideCount++;
      }
    }

    res.status(200).json({
      totalEarnings: totalEarnings,
      completedRideCount: completedRideCount,
      message: 'Driver earnings retrieved successfully.',
    });
  } catch (error) {
    console.error('Error fetching driver earnings:', error);
    res.status(500).json({ message: 'Server error fetching earnings' });
  }
};

// @desc    Rate a driver after a completed ride
// @route   POST /api/rides/:id/rate-driver
// @access  Private (Rider only)
const rateDriver = async (req, res) => {
  const rideId = req.params.id;
  const { rating } = req.body;

  if (!rating || rating < 1 || rating > 5) {
    return res.status(400).json({ message: 'Please provide a rating between 1 and 5.' });
  }

  if (!req.user || req.user.userType !== 'rider') {
    return res.status(403).json({ message: 'Only riders can rate drivers.' });
  }

  try {
    const ride = await Ride.findById(rideId).populate('driver', 'averageRating numRatings');

    if (!ride) {
      return res.status(404).json({ message: 'Ride not found.' });
    }

    if (ride.status !== 'completed') {
      return res.status(400).json({ message: 'Ride must be completed to rate the driver.' });
    }

    const passengerBooking = ride.passengers.find(
      (p) => p.user.toString() === req.user._id.toString() && p.status === 'completed_by_driver'
    );

    if (!passengerBooking) {
      return res.status(403).json({ message: 'You did not complete this ride as a passenger.' });
    }

    const driverUser = await User.findById(ride.driver._id);

    if (!driverUser) {
      return res.status(404).json({ message: 'Driver not found.' });
    }

    const newNumRatings = driverUser.numRatings + 1;
    const newAverageRating = 
      ((driverUser.averageRating * driverUser.numRatings) + rating) / newNumRatings;

    driverUser.averageRating = newAverageRating;
    driverUser.numRatings = newNumRatings;

    await driverUser.save();
    console.log(`Rider ${req.user._id} rated driver ${driverUser._id} with ${rating} stars for ride ${rideId}.`);
    res.status(200).json({ message: 'Driver rated successfully.', newAverageRating: newAverageRating });

  } catch (error) {
    console.error('Error rating driver:', error);
    res.status(500).json({ message: 'Server error rating driver' });
  }
};


// @desc    Adjust the fare of a posted ride
// @route   PUT /api/rides/:id/adjust-fare
// @access  Private (Driver only)
const adjustFare = async (req, res) => {
  const rideId = req.params.id;
  const { newPrice } = req.body;

  if (!req.user || req.user.userType !== 'driver') {
    return res.status(403).json({ message: 'Only drivers can adjust fares.' });
  }

  if (!newPrice) {
    return res.status(400).json({ message: 'Please provide a new price.' });
  }

  try {
    const ride = await Ride.findById(rideId);

    if (!ride) {
      return res.status(404).json({ message: 'Ride not found.' });
    }

    if (ride.driver.toString() !== req.user._id.toString()) {
      return res.status(403).json({ message: 'You are not authorized to adjust the fare for this ride.' });
    }

    ride.price = newPrice;
    await ride.save();

    res.status(200).json({
      message: 'Fare adjusted successfully',
      ride: ride,
    });
  } catch (error) {
    console.error('Error adjusting fare:', error);
    res.status(500).json({ message: 'Server error adjusting fare' });
  }
};

// @desc    Calculate a suggested fare for a ride
// @route   POST /api/rides/calculate-fare
// @access  Private
const calculateFare = async (req, res) => {
  const { from, to } = req.body;

  if (!from || !to) {
    return res.status(400).json({ message: 'Please provide both origin and destination.' });
  }

  try {
    const origin = await geocodeAddress(from);
    const destination = await geocodeAddress(to);

    const distanceMatrix = await getDistanceMatrix(origin, destination);

    // Pricing formula: Base Fare + (distance in km * rate per km)
    const baseFare = 100; // e.g., 100 PKR
    const pricePerKm = 50; // e.g., 50 PKR per kilometer
    const distanceInKm = distanceMatrix.distance.value / 1000;

    let suggestedPrice = baseFare + (distanceInKm * pricePerKm);

    // Round to the nearest 10 for a cleaner price
    suggestedPrice = Math.round(suggestedPrice / 10) * 10;

    res.status(200).json({
      suggestedPrice: suggestedPrice,
      distance: distanceMatrix.distance.text,
      duration: distanceMatrix.duration.text,
    });
  } catch (error) {
    console.error('Error calculating fare:', error);
    res.status(500).json({ message: 'Server error calculating fare.' });
  }
};

module.exports = {
  postRide,
  getRides,
  adjustFare,
  bookRide,
  cancelBooking,
  cancelRide,
  completeRide,
  getMyPostedRides,
  getMyBookedRides,
  getDriverEarnings,
  rateDriver,
  calculateFare,
};
