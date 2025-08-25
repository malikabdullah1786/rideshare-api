const { Client } = require("@googlemaps/google-maps-services-js");

const client = new Client({});

module.exports = {
  googleMapsClient: client,
  apiKey: process.env.GOOGLE_MAPS_API_KEY,
};
