const express = require('express');
const router = express.Router();
const {
  getUsers,
  approveUserProfile,
  updateUserPermissions,
  adminCancelRide,
  getSettings,
  updateSettings,
} = require('../controllers/adminController');
const { protect } = require('../middleware/authMiddleware');
const { admin } = require('../middleware/adminMiddleware');

// All these routes are protected and for admin only
router.route('/users').get(protect, admin, getUsers);
router.route('/users/:id/approve').put(protect, admin, approveUserProfile);
router.route('/users/:id/permissions').put(protect, admin, updateUserPermissions);

// Admin routes for managing rides
router.route('/rides/:id/cancel').put(protect, admin, adminCancelRide);

// Admin routes for managing settings
router.route('/settings').get(protect, admin, getSettings).put(protect, admin, updateSettings);

module.exports = router;
