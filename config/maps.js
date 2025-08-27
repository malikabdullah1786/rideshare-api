const { Client } = require("@googlemaps/google-maps-services-js");

const apiKey = process.env.GOOGLE_MAPS_API_KEY;

if (!apiKey) {
  console.error("FATAL ERROR: GOOGLE_MAPS_API_KEY environment variable is not set.");
  process.exit(1); // Exit the application
}

const client = new Client({});

module.exports = {
  googleMapsClient: client,
  apiKey: apiKey,
};
