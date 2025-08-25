const { Client } = require("@googlemaps/google-maps-services-js");
const { apiKey } = require("../config/maps");

const client = new Client({});

const geocodeAddress = async (address) => {
  try {
    const response = await client.geocode({
      params: {
        address: address,
        key: apiKey,
      },
    });
    return response.data.results[0].geometry.location;
  } catch (error) {
    console.error("Error geocoding address:", error);
    throw error;
  }
};

const getDistanceMatrix = async (origin, destination) => {
  try {
    const response = await client.distancematrix({
      params: {
        origins: [origin],
        destinations: [destination],
        key: apiKey,
      },
    });
    return response.data.rows[0].elements[0];
  } catch (error) {
    console.error("Error getting distance matrix:", error);
    throw error;
  }
};

const reverseGeocodeLatLng = async (lat, lng) => {
  try {
    const response = await client.reverseGeocode({
      params: {
        latlng: { latitude: lat, longitude: lng },
        key: apiKey,
      },
    });
    // The first result is usually the most specific address.
    if (response.data.results && response.data.results.length > 0) {
      return response.data.results[0].formatted_address;
    } else {
      throw new Error('No address found for the given coordinates.');
    }
  } catch (error) {
    console.error("Error reverse geocoding coordinates:", error);
    throw error;
  }
};

module.exports = {
  geocodeAddress,
  getDistanceMatrix,
  reverseGeocodeLatLng,
};
