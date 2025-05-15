const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendDistressNotification = functions.https.onCall(async (data, context) => {
  const { title, body } = data;

  const message = {
    notification: {
      title: title,
      body: body,
    },
    topic: 'emergency_alerts', // Topic to which relatives have subscribed
  };

  try {
    await admin.messaging().send(message);
    return { success: true };
  } catch (error) {
    console.error('Error sending notification:', error);
    throw new functions.https.HttpsError('unknown', error.message, error);
  }
});
