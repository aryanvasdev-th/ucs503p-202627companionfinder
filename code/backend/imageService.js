// imageService.js
// Every uploaded photo is re-encoded before it's stored, because images are
// almost all of the app's data use (the backend is reached through a tunnel
// with a monthly data cap, and students are often on mobile data):
//   - HEIC/HEIF (the iPhone default) is converted, since most browsers and
//     Android can't show it;
//   - the phone's EXIF rotation is applied so nothing shows sideways;
//   - avatars become 400x400 and banners at most 1200px wide — a phone
//     never shows them bigger;
//   - everything is saved as WebP, typically 20-80 KB instead of 200-500 KB.

const fs = require('fs/promises');
const path = require('path');
const sharp = require('sharp');
const heicConvert = require('heic-convert');

const HEIC_EXTENSIONS = new Set(['.heic', '.heif']);

const PRESETS = {
  avatar: { width: 400, height: 400, fit: 'cover', quality: 80 },
  banner: { width: 1200, height: 1200, fit: 'inside', quality: 78 },
};

/**
 * Re-encodes the uploaded file at filePath as a resized WebP next to it,
 * deletes the original, and returns the new filename.
 */
async function optimizeImage(filePath, kind) {
  const preset = PRESETS[kind];
  if (!preset) throw new Error(`Unknown image kind: ${kind}`);

  const ext = path.extname(filePath).toLowerCase();
  let input = await fs.readFile(filePath);
  if (HEIC_EXTENSIONS.has(ext)) {
    input = Buffer.from(await heicConvert({ buffer: input, format: 'JPEG', quality: 0.92 }));
  }

  const outPath = filePath.slice(0, filePath.length - ext.length) + '.webp';
  await sharp(input)
    .rotate()
    .resize({
      width: preset.width,
      height: preset.height,
      fit: preset.fit,
      withoutEnlargement: true,
    })
    .webp({ quality: preset.quality })
    .toFile(outPath);

  if (outPath !== filePath) await fs.unlink(filePath);
  return path.basename(outPath);
}

module.exports = { optimizeImage };
