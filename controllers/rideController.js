const Ride = require('../models/Ride');
const User = require('../models/User'); // To populate driver details

// @desc    Post a new ride
// @route   POST /api/rides/post
// @access  Private (Driver only)
const postRide = async (req, res) => {
  const { from, to, price, seats, departureTime } = req.body;

  // --- DEBUG LOGS START ---
  console.log('\n--- postRide Controller Debug Start ---');
  console.log('1. Received departureTime from frontend (ISO string):', departureTime); // e.g., "2025-07-15T10:00:00.000+05:00"
  // --- DEBUG LOGS END ---

  if (!req.user || req.user.userType !== 'driver') {
    console.error('Attempt to post ride by non-driver or unauthenticated user:', req.user);
    return res.status(403).json({ message: 'Only drivers can post rides.' });
  }

  if (!from || !to || !price || !seats || !departureTime) {
    console.error('Missing required fields for postRide:', { from, to, price, seats, departureTime });
    return res.status(400).json({ message: 'Please include all ride details.' });
  }

  try {
    // Parse the ISO 8601 string. If it contains a timezone offset (+05:00),
    // JavaScript's Date constructor will interpret it correctly and store it internally as UTC.
    const parsedDepartureTime = new Date(departureTime); 

    // --- DEBUG LOGS START ---
    console.log('2. Parsed departureTime (Date object):', parsedDepartureTime); // e.g., Tue Jul 15 2025 10:00:00 GMT+0500 (PKT)
    // getTimezoneOffset returns the difference in minutes between UTC and local time.
    // For a Date object created from an ISO string with an offset, it internally represents UTC.
    // So, getTimezoneOffset() will give the *server's* timezone offset relative to UTC.
    console.log('3. Parsed departureTime getTimezoneOffset (minutes from UTC on server):', parsedDepartureTime.getTimezoneOffset());
    console.log('4. Parsed departureTime toISOString() (always UTC):', parsedDepartureTime.toISOString()); // e.g., "2025-07-15T05:00:00.000Z"
    console.log('5. Parsed departureTime toLocaleString() (server local time):', parsedDepartureTime.toLocaleString()); // e.g., "7/15/2025, 10:00:00 AM" (if server is PKT)
    // --- DEBUG LOGS END ---

    const ride = await Ride.create({
      driver: req.user._id, // MongoDB _id of the driver
      driverName: req.user.name, // Save driver's name directly
      driverPhone: req.user.phone, // Save driver's phone directly
      from,
      to,
      price,
      seats,
      seatsAvailable: seats, // Initially all seats are available
      departureTime: parsedDepartureTime, // Use the parsed Date object
      status: 'active',
    });

    // --- DEBUG LOGS START ---
    console.log('6. Ride saved to DB. Departure time from saved ride object:', ride.departureTime); // This will show the UTC time that MongoDB stored
    console.log('--- postRide Controller Debug End ---\n');
    // --- DEBUG LOGS END ---

    res.status(201).json({
      message: 'Ride posted successfully',
      ride: ride,
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
  const { from, to, date, time } = req.query; // Get query parameters

  let query = {
    status: 'active',
    departureTime: { $gt: new Date() } // Only active and future rides
  };

  if (from) {
    query.from = { $regex: from, $options: 'i' }; // Case-insensitive search
  }
  if (to) {
    query.to = { $regex: to, $options: 'i' };     // Case-insensitive search
  }

  // Filter by date
  if (date) {
    const selectedDate = new Date(date);
    // If the frontend sends local date strings without time, we assume start of day in local timezone
    selectedDate.setHours(0, 0, 0, 0); // Set to start of the selected day in local time

    const nextDay = new Date(selectedDate);
    nextDay.setDate(selectedDate.getDate() + 1); // Start of the next day in local time

    query.departureTime.$gte = selectedDate;
    query.departureTime.$lt = nextDay;
  }

  // Filter by time (requires date to be present for accurate filtering)
  if (time && date) {
    const [hours, minutes] = time.split(':').map(Number);
    const selectedDateTime = new Date(date);
    selectedDateTime.setHours(hours, minutes, 0, 0); // Set time on the selected date

    // Adjust query to filter from this specific time onwards on the selected date
    query.departureTime.$gte = selectedDateTime;
  }

  try {
    const rides = await Ride.find(query)
      .populate('driver', 'averageRating numRatings') // Only populate dynamic driver fields
      .sort({ departureTime: 1 }); // Sort by earliest departure time

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
  const { passengersToBook } = req.body; // Array of { bookedSeats, pickupAddress, dropoffAddress, contactPhone }

  // --- DEBUG LOGS START ---
  console.log('RideController DEBUG: Received booking request for rideId:', rideId);
  console.log('RideController DEBUG: Request Headers:', req.headers);
  console.log('RideController DEBUG: req.body received:', req.body);
  console.log('RideController DEBUG: passengersToBook extracted:', passengersToBook);
  // --- DEBUG LOGS END ---

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
      // --- DEBUG LOGS START ---
      console.log('RideController DEBUG: Processing passenger object (inside loop):', p);
      console.log('RideController DEBUG: Passenger pickupAddress (inside loop):', p.pickupAddress);
      console.log('RideController DEBUG: Passenger dropoffAddress (inside loop):', p.dropoffAddress);
      console.log('RideController DEBUG: Passenger contactPhone (inside loop):', p.contactPhone);
      // --- DEBUG LOGS END ---

      if (!p.bookedSeats || p.bookedSeats <= 0 || !p.pickupAddress || !p.dropoffAddress || !p.contactPhone) {
        return res.status(400).json({ message: 'Invalid passenger booking details provided. Ensure all fields are filled.' });
      }
      totalSeatsToBook += p.bookedSeats;

      // Check if a booking with the same primary user and same contact phone/addresses already exists
      // This ensures a rider cannot book the exact same details multiple times on one ride.
      const existingBookingForThisPerson = ride.passengers.some(
        (existingP) =>
          existingP.user.toString() === req.user._id.toString() &&
          existingP.contactPhone === p.contactPhone &&
          existingP.pickupAddress === p.pickupAddress &&
          existingP.dropoffAddress === p.dropoffAddress &&
          existingP.status === 'accepted' // Only check for active/accepted bookings
      );

      if (existingBookingForThisPerson) {
        return res.status(400).json({ message: `A booking for ${p.contactPhone} with these details already exists on this ride.` });
      }

      newBookings.push({
        user: req.user._id, // The primary rider's ID for all bookings made by them
        bookedSeats: p.bookedSeats,
        pickupAddress: p.pickupAddress,
        dropoffAddress: p.dropoffAddress,
        contactPhone: p.contactPhone,
        status: 'accepted', // Default status
      });
    }

    if (ride.seatsAvailable < totalSeatsToBook) {
      return res.status(400).json({ message: `Not enough seats available. Only ${ride.seatsAvailable} left.` });
    }

    // Update seats available
    ride.seatsAvailable -= totalSeatsToBook;

    // Add new bookings to the ride's passengers array
    ride.passengers.push(...newBookings);

    await ride.save();

    res.status(200).json({
      message: 'Ride booked successfully!',
      ride: ride,
    });
  } catch (error) {
    console.error('Error booking ride:', error);
    // Check if it's a Mongoose validation error for required fields
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
  const { cancellationReason } = req.body; // Get cancellation reason from request body

  if (!req.user || req.user.userType !== 'rider') {
    return res.status(403).json({ message: 'Only riders can cancel bookings.' });
  }

  try {
    const ride = await Ride.findById(rideId);

    if (!ride) {
      return res.status(404).json({ message: 'Ride not found.' });
    }

    // Find the specific booking entry by the current user that is 'accepted'
    const bookingIndex = ride.passengers.findIndex(
      (p) => p.user.toString() === req.user._id.toString() && p.status === 'accepted'
    );

    if (bookingIndex === -1) {
      return res.status(404).json({ message: 'Active booking not found for this ride by your account.' });
    }

    const bookedSeats = ride.passengers[bookingIndex].bookedSeats;

    // Update the status of the specific booking to cancelled
    ride.passengers[bookingIndex].status = 'cancelled_by_rider';
    ride.passengers[bookingIndex].cancellationReason = cancellationReason || 'No reason provided'; // Save reason

    // Increase available seats
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
  const { cancellationReason } = req.body; // Get cancellation reason from request body

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
    ride.cancellationReason = cancellationReason || 'No reason provided'; // Save reason
    
    // Optionally, notify passengers about cancellation here (e.g., set their booking status to cancelled_by_driver)
    // For simplicity, we just change the main ride status and its reason.
    // If you want to mark each passenger's booking as cancelled, you'd iterate:
    // ride.passengers.forEach(p => { p.status = 'cancelled_by_driver_ride'; });

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

  // --- DEBUG LOGS START ---
  console.log('\n--- completeRide Controller Debug Start ---');
  console.log('req.user at start of completeRide:', req.user ? req.user.email : 'undefined');
  console.log('Attempting to complete ride ID:', rideId);
  // --- DEBUG LOGS END ---

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
    // Mark all accepted passengers for this ride as completed by driver
    ride.passengers.forEach(p => {
      if (p.status === 'accepted') {
        p.status = 'completed_by_driver';
      }
    });

    await ride.save();
    console.log(`Driver ${req.user._id} marked ride ${rideId} as completed.`);

    // Earnings will be calculated when getDriverEarnings is called, based on completed bookings.
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
    // We no longer need to populate driver name/phone here if they are stored directly on the Ride
    const rides = await Ride.find({ driver: req.user._id })
      .populate('passengers.user', 'name email phone cnic address') // Populate specific user fields for passengers
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
  // --- DEBUG LOGS START ---
  console.log('\n--- getMyBookedRides Controller Debug Start (Entry) ---');
  console.log('req.user at start of getMyBookedRides:', req.user ? req.user.email : 'undefined');
  // --- DEBUG LOGS END ---

  if (!req.user || req.user.userType !== 'rider') {
    console.error('getMyBookedRides ERROR: Attempt to fetch booked rides by non-rider or unauthenticated user.');
    return res.status(403).json({ message: 'Only riders can view their booked rides.' });
  }

  try {
    // Find rides where the current user is a passenger
    // Populate the driver for dynamic fields like averageRating, but name/phone are already on the ride object
    const rides = await Ride.find({ 'passengers.user': req.user._id })
      .populate('driver', 'averageRating numRatings') // Only populate dynamic driver fields
      .sort({ departureTime: 1 });

    // --- DEBUG LOGS START ---
    console.log('Rides fetched and populated for rider:');
    rides.forEach(ride => {
      console.log(`  Ride ID: ${ride._id}, From: ${ride.from}, To: ${ride.to}`);
      console.log(`    Driver Name (from ride obj): ${ride.driverName}, Phone (from ride obj): ${ride.driverPhone}`);
      if (ride.driver) { // This `ride.driver` object only contains _id, averageRating, numRatings now
        console.log(`    Driver Rating (from populated driver obj): ${ride.driver.averageRating}`);
      } else {
        console.log('    Driver (populated object): NOT POPULATED or NULL');
      }
      console.log(`    Departure Time (from DB): ${ride.departureTime}`); // This will be UTC from MongoDB
      console.log(`    Departure Time (toLocaleString, server's local): ${ride.departureTime.toLocaleString()}`); // This will be in server's local time
      console.log(`    CreatedAt (from DB): ${ride.createdAt}`); // This will be UTC from MongoDB
      console.log(`    CreatedAt (toLocaleString, server's local): ${ride.createdAt.toLocaleString()}`); // This will be in server's local time
      ride.passengers.forEach(p => {
        console.log(`    Passenger Booking User ID: ${p.user._id}, Status: ${p.status}`);
      });
    });
    console.log('--- getMyBookedRides Controller Debug End ---\n');
    // --- DEBUG LOGS END ---

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
    // Find all rides posted by this driver that are 'completed'
    const completedRides = await Ride.find({
      driver: req.user._id,
      status: 'completed',
    });

    let totalEarnings = 0;
    let completedRideCount = 0;

    for (const ride of completedRides) {
      // Sum up bookedSeats from all passengers whose bookings were completed by the driver
      const seatsBookedOnThisRide = ride.passengers.reduce((sum, p) => {
        if (p.status === 'completed_by_driver') { // Only count seats from completed bookings
          return sum + p.bookedSeats;
        }
        return sum;
      }, 0);
      totalEarnings += ride.price * seatsBookedOnThisRide;
      if (seatsBookedOnThisRide > 0) { // Only count the ride as completed if it had at least one completed booking
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
  const { rating } = req.body; // Expecting a rating value (e.g., 1-5)

  if (!rating || rating < 1 || rating > 5) {
    return res.status(400).json({ message: 'Please provide a rating between 1 and 5.' });
  }

  if (!req.user || req.user.userType !== 'rider') {
    return res.status(403).json({ message: 'Only riders can rate drivers.' });
  }

  try {
    // Populate the driver to get their current averageRating and numRatings
    const ride = await Ride.findById(rideId).populate('driver', 'averageRating numRatings');

    if (!ride) {
      return res.status(404).json({ message: 'Ride not found.' });
    }

    // Check if the ride status is completed by the driver
    if (ride.status !== 'completed') {
      return res.status(400).json({ message: 'Ride must be completed to rate the driver.' });
    }

    // Check if the current rider was a passenger on this ride and if their booking was completed
    const passengerBooking = ride.passengers.find(
      (p) => p.user.toString() === req.user._id.toString() && p.status === 'completed_by_driver'
    );

    if (!passengerBooking) {
      return res.status(403).json({ message: 'You did not complete this ride as a passenger.' });
    }

    // Prevent multiple ratings from the same rider for the same ride
    // You might add a 'rated' flag to the passengerBookingSchema if needed for strict tracking.
    // For now, we assume one rating per completed booking.
    // A more robust solution would be to add a 'hasRated' boolean to the passengerBookingSchema
    // and set it to true after rating, then check it here.

    const driverUser = await User.findById(ride.driver._id); // Get the full driver user object

    if (!driverUser) {
      return res.status(404).json({ message: 'Driver not found.' });
    }

    // Update driver's average rating
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


module.exports = {
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
};
