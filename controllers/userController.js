const User = require('../models/User');

// @desc    Upload profile picture
// @route   POST /api/users/profile/upload
// @access  Private
const uploadProfilePicture = async (req, res) => {
  try {
    // The error handling is now more robust in the route, but we still check for the file.
    if (!req.file) {
      return res.status(400).json({ message: 'No file was uploaded. Please select an image.' });
    }

    const user = await User.findById(req.user._id);

    if (user) {
      // The path is the secure URL from Cloudinary storage engine
      user.profilePictureUrl = req.file.path;
      const updatedUser = await user.save();

      res.status(200).json({
        message: 'Profile picture uploaded successfully',
        profilePictureUrl: updatedUser.profilePictureUrl,
      });
    } else {
      // This case is unlikely if the 'protect' middleware is working, but good to have
      res.status(404).json({ message: 'User not found.' });
    }
  } catch (error) {
    console.error('Error in uploadProfilePicture controller:', error);
    res.status(500).json({ message: 'Server error while updating profile picture.' });
  }
};

module.exports = {
  uploadProfilePicture,
};
