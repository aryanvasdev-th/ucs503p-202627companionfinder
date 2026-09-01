// imageService.js
// Converts HEIC/HEIF uploads (the default photo format on iOS/macOS) to
// JPEG so they render everywhere — most browsers and Android can't decode
// HEIC, so an unconverted upload from a Mac or iPhone shows as broken.

const fs = require('fs/promises');
const path = require('path');
const convert = require('heic-convert');

const HEIC_EXTENSIONS = new Set(['.heic', '.heif']);

/**
 * If the file at filePath is HEIC/HEIF, converts it to a JPEG sitting next
 * to it and removes the original. Returns the filename to use (unchanged
 * if no conversion was needed).
 */
async function convertHeicIfNeeded(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  if (!HEIC_EXTENSIONS.has(ext)) {
    return path.basename(filePath);
  }

  const inputBuffer = await fs.readFile(filePath);
  const outputBuffer = await convert({ buffer: inputBuffer, format: 'JPEG', quality: 0.85 });

  const jpegPath = filePath.slice(0, -ext.length) + '.jpg';
  await fs.writeFile(jpegPath, outputBuffer);
  await fs.unlink(filePath);

  return path.basename(jpegPath);
}

module.exports = { convertHeicIfNeeded };
