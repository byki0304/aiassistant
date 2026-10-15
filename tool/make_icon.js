const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const crcTable = new Uint32Array(256);
for (let n = 0; n < 256; n += 1) {
  let c = n;
  for (let k = 0; k < 8; k += 1) {
    c = (c & 1) ? (0xedb88320 ^ (c >>> 1)) : (c >>> 1);
  }
  crcTable[n] = c >>> 0;
}

function crc32(buffer) {
  let c = 0xffffffff;
  for (let i = 0; i < buffer.length; i += 1) {
    c = crcTable[(c ^ buffer[i]) & 0xff] ^ (c >>> 8);
  }
  return (c ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const length = Buffer.alloc(4);
  length.writeUInt32BE(data.length);
  const name = Buffer.from(type);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([name, data])));
  return Buffer.concat([length, name, data, crc]);
}

function paint(size, maskable) {
  const raw = Buffer.alloc((size * 4 + 1) * size);
  const inset = maskable ? size * 0.1 : 0;
  for (let y = 0; y < size; y += 1) {
    const row = y * (size * 4 + 1);
    raw[row] = 0;
    for (let x = 0; x < size; x += 1) {
      const nx = (x - size / 2) / size;
      const ny = (y - size / 2) / size;
      const inBubble = nx > -0.08 && nx < 0.22 && ny > -0.16 && ny < 0.12
        && Math.hypot(nx - 0.06, ny + 0.02) < 0.2;
      const inTail = nx > -0.02 && nx < 0.08 && ny > 0.08 && ny < 0.2;
      let r = 0x0f;
      let g = 0x4c;
      let b = 0x5c;
      if (x < inset || y < inset || x >= size - inset || y >= size - inset) {
        r = 0x0f; g = 0x4c; b = 0x5c;
      } else if (inBubble || inTail) {
        r = 0xef; g = 0xfd; b = 0xde;
      }
      const i = row + 1 + x * 4;
      raw[i] = r;
      raw[i + 1] = g;
      raw[i + 2] = b;
      raw[i + 3] = 255;
    }
  }
  return raw;
}

function png(size, maskable) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(size, 0);
  ihdr.writeUInt32BE(size, 4);
  ihdr[8] = 8;
  ihdr[9] = 6;
  const compressed = zlib.deflateSync(paint(size, maskable));
  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', ihdr),
    chunk('IDAT', compressed),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

const root = path.join(__dirname, '..', 'web');
fs.mkdirSync(path.join(root, 'icons'), { recursive: true });
fs.writeFileSync(path.join(root, 'favicon.png'), png(32, false));
fs.writeFileSync(path.join(root, 'icons', 'Icon-192.png'), png(192, false));
fs.writeFileSync(path.join(root, 'icons', 'Icon-512.png'), png(512, false));
fs.writeFileSync(path.join(root, 'icons', 'Icon-maskable-192.png'), png(192, true));
fs.writeFileSync(path.join(root, 'icons', 'Icon-maskable-512.png'), png(512, true));
