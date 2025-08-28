const cloudinary = require('cloudinary').v2;
const { CloudinaryStorage } = require('multer-storage-cloudinary');
const dotenv = require('dotenv');

dotenv.config();

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

const storage = new CloudinaryStorage({
  cloudinary: cloudinary,
  params: {
    folder: 'ride_share_profile_pictures',
    format: async (req, file) => 'png', // supports promises as well
    public_id: (req, file) => {
      // Create a unique public ID using the Firebase UID and a timestamp
      // This is more robust than using the MongoDB _id, which might not be a simple string
      const firebaseUid = req.user.firebaseUid;
      const timestamp = Date.now();
      return `user-${firebaseUid}-${timestamp}`;
    },
  },
});

module.exports = { cloudinary, storage };
