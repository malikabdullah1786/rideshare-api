const User = require('../models/User');

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

module.exports = {
  getUsers,
  approveUserProfile,
  updateUserPermissions,
};
