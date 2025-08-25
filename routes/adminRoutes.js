const express = require('express');
const router = express.Router();
const {
  getUsers,
  approveUserProfile,
  updateUserPermissions,
} = require('../controllers/adminController');
const { protect } = require('../middleware/authMiddleware');
const { admin } = require('../middleware/adminMiddleware');

// All these routes are protected and for admin only
router.route('/users').get(protect, admin, getUsers);
router.route('/users/:id/approve').put(protect, admin, approveUserProfile);
router.route('/users/:id/permissions').put(protect, admin, updateUserPermissions);

module.exports = router;
