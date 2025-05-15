const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { GeoFireCommon } = require('geofire-common');

admin.initializeApp();
const db = admin.database();

const GEO_RADIUS_KM = 0.1; // Geofence radius in kilometers

exports.updateLocation = functions.database.ref('/users/{userId}/location').onWrite(async (change, context) => {
  const { userId } = context.params;
  const location = change.after.val();

  if (!location) return null;

  const { latitude, longitude } = location;

  const visitedPlacesRef = db.ref(`/users/${userId}/visitedPlaces`);
  
  const visitedPlacesSnapshot = await visitedPlacesRef.once('value');
  const visitedPlaces = visitedPlacesSnapshot.val() || {};

  let visitUpdated = false;

  Object.keys(visitedPlaces).forEach((placeKey) => {
    const [placeLat, placeLng] = placeKey.split(',');
    const distance = GeoFireCommon.distanceBetween([latitude, longitude], [parseFloat(placeLat), parseFloat(placeLng)]);

    if (distance <= GEO_RADIUS_KM) {
      visitedPlaces[placeKey]++; // Increment visit count
      visitUpdated = true;
    }
  });

  if (!visitUpdated) {
    const newPlaceKey = `${latitude},${longitude}`;
    visitedPlaces[newPlaceKey] = 1; // New place
  }

  await visitedPlacesRef.set(visitedPlaces);
  return null;
});
