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

    if (response.data.status !== 'OK' || !response.data.results || response.data.results.length === 0) {
      throw new Error(`Geocoding failed for address "${address}". Status: ${response.data.status}`);
    }

    return response.data.results[0].geometry.location;
  } catch (error) {
    console.error("Error geocoding address:", error.message);
    // Re-throw a more generic error to not expose too much detail to the client
    throw new Error('Failed to find location for the provided address.');
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

    const element = response.data.rows[0].elements[0];

    if (element.status !== 'OK') {
      // Handle cases like 'ZERO_RESULTS', 'NOT_FOUND', etc.
      throw new Error(`Could not find a route. Status: ${element.status}`);
    }

    return element;
  } catch (error) {
    console.error("Error getting distance matrix:", error.message);
    throw new Error('Failed to calculate distance and duration for the ride.');
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

    if (response.data.status !== 'OK' || !response.data.results || response.data.results.length === 0) {
      throw new Error(`Reverse geocoding failed for coordinates. Status: ${response.data.status}`);
    }

    // The first result is usually the most specific address.
    return response.data.results[0].formatted_address;

  } catch (error) {
    console.error("Error reverse geocoding coordinates:", error.message);
    throw new Error('Failed to find address for the given coordinates.');
  }
};

module.exports = {
  geocodeAddress,
  getDistanceMatrix,
  reverseGeocodeLatLng,
};
