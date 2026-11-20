// idCardService.js
// Verifies a Thapar "Identity Cum Library Card" from two photos (front and
// back) and ties it to the account's OTP-verified @thapar.edu email.
//
// Why not face matching: we tried comparing a selfie with the card portrait,
// but the printed photos are small, faded and often years old — a genuine
// student scored 22% similarity against their own card. The card's text and
// barcode are far more reliable:
//
//   1. Front (OCR): must read as a Thapar identity card, and carry a name
//      whose first initial + surname match the email (avasdev_be24@thapar.edu
//      <-> "Aryan Vasdev"). Only the email's owner can log in, so a borrowed
//      card fails here.
//   2. Back (barcode): the Code 128 barcode must decode to the same roll
//      number printed on the front, so both photos are of one real card.
//   3. The roll number may verify only one account (stored as a keyed hash,
//      never in plain text).
//
// Photos are processed in memory and never written to disk.
const crypto = require('crypto');
const path = require('path');
const sharp = require('sharp');
const heicConvert = require('heic-convert');
const Tesseract = require('tesseract.js');

const ENG_DATA_DIR = path.join(
  path.dirname(require.resolve('@tesseract.js-data/eng/package.json')),
  '4.0.0_best_int'
);

class IdCardError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

let workerPromise = null;
function getOcrWorker() {
  if (!workerPromise) {
    workerPromise = Tesseract.createWorker('eng', 1, {
      langPath: ENG_DATA_DIR,
      gzip: true,
      cacheMethod: 'none', // language data is bundled locally; nothing downloaded
    }).catch((err) => {
      workerPromise = null;
      throw err;
    });
  }
  return workerPromise;
}

// zxing-wasm is ESM-only; load it lazily from this CommonJS module.
let readBarcodesFn = null;
async function getBarcodeReader() {
  if (!readBarcodesFn) {
    ({ readBarcodes: readBarcodesFn } = await import('zxing-wasm/reader'));
  }
  return readBarcodesFn;
}

function isHeic(buffer) {
  if (buffer.length < 12 || buffer.toString('ascii', 4, 8) !== 'ftyp') return false;
  return ['heic', 'heix', 'hevc', 'heim', 'heis', 'mif1', 'msf1'].includes(buffer.toString('ascii', 8, 12));
}

async function normalise(buffer) {
  const input = isHeic(buffer) ? Buffer.from(await heicConvert({ buffer, format: 'JPEG', quality: 0.95 })) : buffer;
  try {
    // Apply the phone's EXIF rotation so text and barcode are upright.
    // Re-encode losslessly: a second lossy pass blurs the small printed
    // digits enough to break the roll-number read.
    return await sharp(input).rotate().png({ compressionLevel: 1 }).toBuffer();
  } catch (err) {
    throw new IdCardError('BAD_IMAGE', "One of the photos couldn't be read. Please retake it.");
  }
}

async function readFrontText(buffer) {
  // Upscaled greyscale with stretched contrast reads the small printed text
  // far better than the raw camera image.
  const prepared = await sharp(buffer)
    .resize({ width: 2000, withoutEnlargement: false })
    .grayscale()
    .normalize()
    .png()
    .toBuffer();
  const worker = await getOcrWorker();
  const { data } = await worker.recognize(prepared);
  return data.text || '';
}

async function readBackBarcodes(buffer) {
  const readBarcodes = await getBarcodeReader();
  const { data, info } = await sharp(buffer)
    .resize({ width: 2400, height: 2400, fit: 'inside', withoutEnlargement: true })
    .ensureAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });
  const results = await readBarcodes(
    { data: new Uint8ClampedArray(data), width: info.width, height: info.height, colorSpace: 'srgb' },
    { tryHarder: true, tryRotate: true, formats: [] }
  );
  return results.map((r) => (r.text || '').trim()).filter(Boolean);
}

// avasdev_be24@thapar.edu -> { initial: 'a', surname: 'vasdev', program: 'be', year: '24' }
// A trailing digit before the underscore (vtripathi1_be24) disambiguates
// students with the same name and isn't part of the surname.
function parseThaparEmail(email) {
  const local = String(email || '').toLowerCase().split('@')[0];
  const domain = String(email || '').toLowerCase().split('@')[1];
  const m = /^([a-z])([a-z]+?)\d*_([a-z]+)(\d{2})$/.exec(local);
  if (domain !== 'thapar.edu' || !m) return null;
  return { initial: m[1], surname: m[2], program: m[3], year: m[4] };
}

function levenshtein(a, b) {
  const dp = Array.from({ length: a.length + 1 }, (_, i) => [i, ...Array(b.length).fill(0)]);
  for (let j = 1; j <= b.length; j++) dp[0][j] = j;
  for (let i = 1; i <= a.length; i++) {
    for (let j = 1; j <= b.length; j++) {
      dp[i][j] = Math.min(
        dp[i - 1][j] + 1,
        dp[i][j - 1] + 1,
        dp[i - 1][j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1)
      );
    }
  }
  return dp[a.length][b.length];
}

// Looks for "<Firstname> <Surname>" on any line, where the first name starts
// with the email's initial and the surname matches allowing one OCR slip
// (e.g. "Vasdeyv").
function findMatchingName(text, initial, surname) {
  const allowed = surname.length >= 5 ? 1 : 0;
  for (const line of text.split('\n')) {
    const words = line.toLowerCase().replace(/[^a-z\s]/g, ' ').split(/\s+/).filter(Boolean);
    for (let i = 1; i < words.length; i++) {
      if (words[i - 1][0] === initial && levenshtein(words[i], surname) <= allowed) {
        return `${words[i - 1]} ${words[i]}`;
      }
    }
  }
  return null;
}

function hammingAtMostOne(a, b) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) if (a[i] !== b[i] && ++diff > 1) return false;
  return true;
}

function rollHash(roll) {
  return crypto.createHmac('sha256', process.env.JWT_SECRET || 'campus-companion').update(roll).digest('hex');
}

/**
 * Returns { rollHash, name, checks } on success; throws IdCardError with a
 * user-facing message on the first check that fails.
 */
async function verifyThaparCard({ frontBuffer, backBuffer, email }) {
  const parsedEmail = parseThaparEmail(email);
  if (!parsedEmail) {
    throw new IdCardError(
      'EMAIL_FORMAT',
      'ID verification needs a student @thapar.edu email (like avasdev_be24@thapar.edu).'
    );
  }

  const [front, back] = await Promise.all([normalise(frontBuffer), normalise(backBuffer)]);
  const [text, barcodes] = await Promise.all([readFrontText(front), readBackBarcodes(back)]);
  const upper = text.toUpperCase();

  if (!upper.includes('THAPAR') || !(upper.includes('IDENTITY') || upper.includes('LIBRARY'))) {
    throw new IdCardError(
      'NOT_THAPAR_CARD',
      "This doesn't look like the front of a Thapar ID card. Lay the card flat in good light, fill most of the photo with it, and avoid glare."
    );
  }

  const name = findMatchingName(text, parsedEmail.initial, parsedEmail.surname);
  if (!name) {
    throw new IdCardError(
      'NAME_MISMATCH',
      "The name on the card doesn't match your Thapar email. You can only verify with your own ID card."
    );
  }

  const barcodeRolls = barcodes.map((b) => b.replace(/\D/g, '')).filter((b) => b.length >= 8);
  if (barcodeRolls.length === 0) {
    throw new IdCardError(
      'NO_BARCODE',
      "We couldn't read the barcode on the back. Retake the back photo closer, flat, with the whole barcode in frame."
    );
  }
  const frontRolls = (text.match(/\d[\d\s]{7,13}\d/g) || []).map((s) => s.replace(/\s/g, ''));
  const roll = barcodeRolls.find((b) => frontRolls.some((f) => hammingAtMostOne(f, b)));
  if (!roll) {
    throw new IdCardError(
      'ROLL_MISMATCH',
      "The roll number on the front doesn't match the barcode on the back. Make sure both photos are of the same card."
    );
  }

  return {
    rollHash: rollHash(roll),
    name,
    checks: {
      thaparCard: true,
      nameMatchesEmail: true,
      barcodeMatchesFront: true,
      // Informational: batch year in the roll number (10<24>...) and the
      // program printed on the card agree with the email.
      yearMatchesEmail: roll.slice(2, 4) === parsedEmail.year,
      programMatchesEmail: new RegExp(`\\b${parsedEmail.program.toUpperCase()}\\b`).test(upper),
    },
  };
}

module.exports = { verifyThaparCard, parseThaparEmail, findMatchingName, IdCardError, getOcrWorker };
