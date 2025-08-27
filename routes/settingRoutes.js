const express = require('express');
const router = express.Router();
const { getPublicSettings } = require('../controllers/settingController');

router.route('/').get(getPublicSettings);

module.exports = router;
