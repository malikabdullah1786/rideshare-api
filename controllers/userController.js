const User = require('../models/User');

// @desc    Upload profile picture
// @route   POST /api/users/profile/upload
// @access  Private
const uploadProfilePicture = async (req, res) => {
  try {
    const user = await User.findById(req.user._id);

    if (user) {
      user.profilePictureUrl = req.file.path; // The path is the secure URL from Cloudinary
      const updatedUser = await user.save();
      res.json({
        message: 'Profile picture uploaded successfully',
        profilePictureUrl: updatedUser.profilePictureUrl,
      });
    } else {
      res.status(404).json({ message: 'User not found' });
    }
  } catch (error) {
    res.status(500).json({ message: 'Server Error' });
  }
};

module.exports = {
  uploadProfilePicture,
};
