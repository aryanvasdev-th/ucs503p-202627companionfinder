// optimize-existing-images.js
// One-off: re-encodes photos uploaded before imageService.optimizeImage
// existed and points the database at the new .webp files.
//   node --env-file=.env optimize-existing-images.js
const fs = require('fs');
const path = require('path');
const pool = require('./db');
const { optimizeImage } = require('./imageService');

const JOBS = [
  { dir: 'avatars', kind: 'avatar', table: 'users', column: 'avatar_url' },
  { dir: 'activity-banners', kind: 'banner', table: 'activities', column: 'banner_url' },
];

(async () => {
  let before = 0;
  let after = 0;
  for (const { dir, kind, table, column } of JOBS) {
    const folder = path.join(__dirname, 'uploads', dir);
    if (!fs.existsSync(folder)) continue;
    for (const name of fs.readdirSync(folder)) {
      if (name.endsWith('.webp') || name.startsWith('.')) continue;
      const file = path.join(folder, name);
      const size = fs.statSync(file).size;
      try {
        const newName = await optimizeImage(file, kind);
        const newSize = fs.statSync(path.join(folder, newName)).size;
        await pool.query(`UPDATE ${table} SET ${column} = ? WHERE ${column} = ?`, [
          `/uploads/${dir}/${newName}`,
          `/uploads/${dir}/${name}`,
        ]);
        before += size;
        after += newSize;
        console.log(`${dir}/${name}: ${Math.round(size / 1024)} KB -> ${Math.round(newSize / 1024)} KB`);
      } catch (err) {
        console.log(`skipped ${dir}/${name}: ${err.message}`);
      }
    }
  }
  console.log(`total: ${Math.round(before / 1024)} KB -> ${Math.round(after / 1024)} KB`);
  process.exit(0);
})();
