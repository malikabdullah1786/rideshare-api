const mongoose = require('mongoose');

const passengerBookingSchema = mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  bookedSeats: {
    type: Number,
    required: true,
  },
  pickupAddress: {
    type: String,
    required: true,
  },
  dropoffAddress: {
    type: String,
    required: true,
  },
  contactPhone: {
    type: String,
    required: true,
  },
  status: {
    type: String,
    enum: ['accepted', 'pending', 'cancelled_by_rider', 'completed_by_driver'],
    default: 'accepted',
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
  cancellationReason: { // Reason for rider cancelling this specific booking
    type: String,
  },
});

const rideSchema = mongoose.Schema(
  {
    driver: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    // NEW: Store driver's name and phone directly in the ride for easier access
    driverName: {
      type: String,
      required: true,
    },
    driverPhone: {
      type: String,
      required: true,
    },
    from: {
      type: String,
      required: true,
    },
    to: {
      type: String,
      required: true,
    },
    origin: {
      lat: { type: Number },
      lng: { type: Number },
    },
    destination: {
      lat: { type: Number },
      lng: { type: Number },
    },
    distance: {
      type: String,
    },
    duration: {
      type: String,
    },
    price: {
      type: Number,
      required: true,
    },
    seats: {
      type: Number,
      required: true,
    },
    seatsAvailable: {
      type: Number,
      required: true,
    },
    departureTime: {
      type: Date,
      required: true,
    },
    status: {
      type: String,
      enum: ['active', 'completed', 'cancelled'],
      default: 'active',
    },
    passengers: [passengerBookingSchema], // Array of sub-documents
    cancellationReason: { // Reason for driver cancelling the entire ride
      type: String,
    },
  },
  {
    timestamps: true, // Adds createdAt and updatedAt
  }
);

module.exports = mongoose.model('Ride', rideSchema);
