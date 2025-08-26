const request = require('supertest');
const express = require('express');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const adminRoutes = require('../routes/adminRoutes');
const Ride = require('../models/Ride');
const User = require('../models/User');

const mockAdmin = {
  _id: new mongoose.Types.ObjectId(),
  firebaseUid: 'test-admin-uid',
  userType: 'admin',
  name: 'Test Admin',
  email: 'admin@test.com',
  password: 'password',
  phone: '03001112233',
  cnic: '12345-8765432-1',
  address: '1 Admin Lane, Admin City',
  emergencyContact: '03003322111',
  gender: 'Other',
  age: 40,
  isApproved: true,
};

// Mock the auth middleware to simulate an admin user
jest.mock('../middleware/authMiddleware', () => ({
  protect: (req, res, next) => {
    req.user = mockAdmin;
    next();
  },
}));

let mongoServer;

const app = express();
app.use(express.json());
app.use('/api/admin', adminRoutes);

describe('Admin Controller', () => {
  beforeAll(async () => {
    mongoServer = await MongoMemoryServer.create();
    const mongoUri = mongoServer.getUri();
    await mongoose.connect(mongoUri);
    await User.create(mockAdmin);
  });

  afterAll(async () => {
    await mongoose.disconnect();
    await mongoServer.stop();
  });

  afterEach(async () => {
    await Ride.deleteMany();
  });

  describe('PUT /api/admin/rides/:id/cancel', () => {
    it('should allow an admin to cancel a ride', async () => {
      // We need a driver for the ride, but it can be a dummy one for this test
      const driver = await User.create({
        _id: new mongoose.Types.ObjectId(),
        firebaseUid: 'dummy-driver-uid',
        userType: 'driver',
        name: 'Dummy Driver',
        email: 'dummy@driver.com',
        password: 'password',
        phone: '03001234567',
        cnic: '12345-1234567-8',
        address: '123 Test Street, Test City',
        emergencyContact: '03007654321',
        gender: 'Male',
        age: 30,
        isApproved: true,
      });

      const ride = await Ride.create({
        driver: driver._id,
        driverName: 'Dummy Driver',
        driverPhone: '1234567890',
        from: 'Test Origin',
        to: 'Test Destination',
        price: 10,
        seats: 3,
        seatsAvailable: 3,
        departureTime: new Date(),
        status: 'active',
      });

      const cancellationReason = 'Driver violated terms of service.';

      const res = await request(app)
        .put(`/api/admin/rides/${ride._id}/cancel`)
        .send({ cancellationReason });

      expect(res.statusCode).toEqual(200);
      expect(res.body.message).toBe('Ride has been cancelled by admin.');

      const updatedRide = await Ride.findById(ride._id);
      expect(updatedRide.status).toBe('cancelled');
      expect(updatedRide.cancellationReason).toBe(`Cancelled by Admin: ${cancellationReason}`);
    });
  });
});
