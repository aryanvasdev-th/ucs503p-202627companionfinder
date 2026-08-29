// smsService.js
// Sends SOS alert texts via Twilio. Needs TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN,
// and TWILIO_PHONE_NUMBER in .env — see .env.example. On a Twilio trial account,
// the destination number must first be verified in the Twilio console.
const twilio = require('twilio');

const client = twilio(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);

async function sendSosSms(toPhone, { userName, latitude, longitude, companions }) {
  const mapsLink = `https://maps.google.com/?q=${latitude},${longitude}`;
  const companionText = companions.length > 0 ? companions.join(', ') : 'no one else logged in the app';

  const body =
    `${userName} triggered an SOS on Campus Companion.\n` +
    `Location: ${mapsLink}\n` +
    `With: ${companionText}`;

  await client.messages.create({
    body,
    from: process.env.TWILIO_PHONE_NUMBER,
    to: toPhone,
  });
}

module.exports = { sendSosSms };
