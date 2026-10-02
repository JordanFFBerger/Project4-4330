// Repair the converted model's game-specific grayscale flame materials.
// Run from the repository root: node tool/fix_charizard_flame.cjs
const fs = require('node:fs');
const crypto = require('node:crypto');
const path = 'assets/pokemon/6.glb';
const bytes = fs.readFileSync(path);
if (bytes.readUInt32LE(0) !== 0x46546c67 || bytes.readUInt32LE(4) !== 2) throw Error('Expected GLB 2');
const jsonLength = bytes.readUInt32LE(12);
const model = JSON.parse(bytes.subarray(20, 20 + jsonLength));
for (const [index, name, color] of [
  [0, 'Tail flame - yellow core', [1, 0.85, 0.08, 1]],
  [1, 'Tail flame - orange envelope', [1, 0.12, 0.008, 0.28]],
]) {
  if (model.meshes[index].name !== `Object_${index + 3}`) throw Error('Unexpected flame mesh');
  const material = model.materials[model.meshes[index].primitives[0].material];
  material.name = name;
  material.pbrMetallicRoughness = { baseColorFactor: color, metallicFactor: 0, roughnessFactor: 1 };
  material.emissiveFactor = color.slice(0, 3); // Fallback for viewers without unlit support.
  material.extensions = { ...material.extensions, KHR_materials_unlit: {} };
  material.alphaMode = index === 0 ? 'OPAQUE' : 'BLEND';
  material.doubleSided = true;
}
model.extensionsUsed = [...new Set([...(model.extensionsUsed || []), 'KHR_materials_unlit'])];
const json = Buffer.from(JSON.stringify(model));
const padded = Buffer.alloc(Math.ceil(json.length / 4) * 4, 0x20);
json.copy(padded);
const remaining = bytes.subarray(20 + jsonLength); // Keep all geometry, skinning, textures and animation bytes identical.
const header = Buffer.alloc(20);
header.writeUInt32LE(0x46546c67, 0);
header.writeUInt32LE(2, 4);
header.writeUInt32LE(20 + padded.length + remaining.length, 8);
header.writeUInt32LE(padded.length, 12);
header.writeUInt32LE(0x4e4f534a, 16);
const result = Buffer.concat([header, padded, remaining]);
fs.writeFileSync(path, result);
const manifestPath = 'assets/pokemon/manifest.json';
const manifest = JSON.parse(fs.readFileSync(manifestPath));
const record = manifest.models.find(m => m.id === 6);
record.bytes = result.length;
record.sha256 = crypto.createHash('sha256').update(result).digest('hex');
record.materialRepair = 'Yellow unlit/emissive core and translucent orange envelope replace grayscale game-effect materials; original animation and geometry preserved.';
fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + '\n');
console.log(`Repaired Charizard flame: ${record.sha256}`);
