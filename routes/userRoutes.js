const express = require('express');
const router = express.Router();
const { uploadProfilePicture } = require('../controllers/userController');
const { protect } = require('../middleware/authMiddleware');
const upload = require('../middleware/multer');
const multer = require('multer');

// Custom error handler for multer
const handleUploadErrors = (err, req, res, next) => {
  if (err instanceof multer.MulterError) {
    // A Multer error occurred when uploading.
    console.error('Multer Error:', err);
    return res.status(400).json({ message: `File upload error: ${err.message}` });
  } else if (err) {
    // An unknown error occurred when uploading.
    console.error('Unknown Upload Error:', err);
    return res.status(500).json({ message: 'An unknown error occurred during file upload.' });
  }
  // Everything went fine.
  next();
};

const uploadMiddleware = (req, res, next) => {
  const uploader = upload.single('profilePicture');
  uploader(req, res, function (err) {
    // Pass any upload errors to our custom handler
    if (err) {
      return handleUploadErrors(err, req, res, next);
    }
    // If no file was uploaded, it's not a multer error, but we should still check in the controller.
    next();
  });
};

router.route('/profile/upload').post(protect, uploadMiddleware, uploadProfilePicture);

module.exports = router;
