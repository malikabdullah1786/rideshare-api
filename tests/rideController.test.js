const request = require('supertest');
const express = require('express');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const rideRoutes = require('../routes/rideRoutes');
const Ride = require('../models/Ride');
const User = require('../models/User');
const { geocodeAddress, getDistanceMatrix } = require('../utils/googleMaps');

// Mock the google maps functions
jest.mock('../utils/googleMaps', () => ({
  geocodeAddress: jest.fn(),
  getDistanceMatrix: jest.fn(),
}));

const mockDriver = {
  _id: new mongoose.Types.ObjectId(),
  firebaseUid: 'test-driver-uid',
  userType: 'driver',
  name: 'Test Driver',
  phone: '1234567890',
  email: 'driver@test.com',
  password: 'password',
  cnic: '12345-1234567-1',
  address: '123 Test Street',
  emergencyContact: '0987654321',
  gender: 'Male',
  age: 30,
};

// Mock the auth middleware
jest.mock('../middleware/authMiddleware', () => ({
  protect: (req, res, next) => {
    req.user = mockDriver;
    next();
  },
}));

let mongoServer;

const app = express();
app.use(express.json());
app.use('/api/rides', rideRoutes);

describe('Ride Controller', () => {
  beforeAll(async () => {
    mongoServer = await MongoMemoryServer.create();
    const mongoUri = mongoServer.getUri();
    await mongoose.connect(mongoUri, {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    });
    await User.create(mockDriver);
  });

  afterAll(async () => {
    await mongoose.disconnect();
    await mongoServer.stop();
  });

  afterEach(async () => {
    await Ride.deleteMany();
  });

  describe('POST /api/rides/post', () => {
    it('should post a new ride and return a suggested price', async () => {
      geocodeAddress.mockResolvedValue({ lat: 1, lng: 1 });
      getDistanceMatrix.mockResolvedValue({
        distance: { text: '10 km', value: 10000 },
        duration: { text: '30 mins', value: 1800 },
      });

      const res = await request(app)
        .post('/api/rides/post')
        .send({
          from: 'Test Origin',
          to: 'Test Destination',
          price: 10,
          seats: 3,
          departureTime: new Date(),
        });

      expect(res.statusCode).toEqual(201);
      expect(res.body.message).toBe('Ride posted successfully');
      expect(res.body.ride).toHaveProperty('distance', '10 km');
      expect(res.body.ride).toHaveProperty('duration', '30 mins');
      expect(res.body).toHaveProperty('suggestedPrice', '5.00');
    });
  });

  describe('PUT /api/rides/:id/adjust-fare', () => {
    it('should adjust the fare of a ride', async () => {
      const ride = await Ride.create({
        driver: mockDriver._id,
        driverName: 'Test Driver',
        driverPhone: '1234567890',
        from: 'Test Origin',
        to: 'Test Destination',
        price: 10,
        seats: 3,
        seatsAvailable: 3,
        departureTime: new Date(),
        status: 'active',
      });

      const res = await request(app)
        .put(`/api/rides/${ride._id}/adjust-fare`)
        .send({ newPrice: 15 });

      expect(res.statusCode).toEqual(200);
      expect(res.body.message).toBe('Fare adjusted successfully');
      expect(res.body.ride.price).toBe(15);
    });
  });
});
