const express = require('express');
const router = express.Router();
const { uploadProfilePicture } = require('../controllers/userController');
const { protect } = require('../middleware/authMiddleware');
const upload = require('../middleware/multer');

router.route('/profile/upload').post(protect, upload.single('profilePicture'), uploadProfilePicture);

module.exports = router;
