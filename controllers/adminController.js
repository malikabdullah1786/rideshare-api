const User = require('../models/User');
const Ride = require('../models/Ride');

// @desc    Get all users
// @route   GET /api/admin/users
// @access  Private/Admin
const getUsers = async (req, res) => {
  try {
    const users = await User.find({});
    res.json(users);
  } catch (error) {
    res.status(500).json({ message: 'Server Error' });
  }
};

// @desc    Approve a user's profile
// @route   PUT /api/admin/users/:id/approve
// @access  Private/Admin
const approveUserProfile = async (req, res) => {
  try {
    const user = await User.findById(req.params.id);

    if (user) {
      user.profileCompleted = true;
      user.isApproved = true;
      const updatedUser = await user.save();
      res.json(updatedUser);
    } else {
      res.status(404).json({ message: 'User not found' });
    }
  } catch (error) {
    res.status(500).json({ message: 'Server Error' });
  }
};

// @desc    Update user permissions
// @route   PUT /api/admin/users/:id/permissions
// @access  Private/Admin
const updateUserPermissions = async (req, res) => {
  // This is a placeholder. The actual implementation will depend on the permission model.
  // For example, you might add a field to the user model like `canPostRidesDirectly: Boolean`.
  res.json({ message: `Permissions updated for user ${req.params.id}` });
};

// @desc    Cancel any ride by an admin
// @route   PUT /api/admin/rides/:id/cancel
// @access  Private/Admin
const adminCancelRide = async (req, res) => {
  const { cancellationReason } = req.body;
  if (!cancellationReason) {
    return res.status(400).json({ message: 'Cancellation reason is required.' });
  }

  try {
    const ride = await Ride.findById(req.params.id);

    if (ride) {
      if (ride.status === 'cancelled' || ride.status === 'completed') {
        return res.status(400).json({ message: `Ride is already ${ride.status}.` });
      }
      ride.status = 'cancelled';
      ride.cancellationReason = `Cancelled by Admin: ${cancellationReason}`;
      await ride.save();
      res.json({ message: 'Ride has been cancelled by admin.' });
    } else {
      res.status(404).json({ message: 'Ride not found' });
    }
  } catch (error) {
    console.error('Error cancelling ride by admin:', error);
    res.status(500).json({ message: 'Server Error' });
  }
};

module.exports = {
  getUsers,
  approveUserProfile,
  updateUserPermissions,
  adminCancelRide,
};
