#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..", "..");
const css = fs.readFileSync(path.join(root, "src", "app", "globals.css"), "utf8");
const token = (name) => {
  const match = css.match(new RegExp(`${name}:\\s*(#[0-9a-fA-F]{6})`));
  if (!match) throw new Error(`Missing color token ${name}`);
  return match[1];
};

function luminance(hex) {
  const values = hex.slice(1).match(/.{2}/g).map((part) => parseInt(part, 16) / 255);
  const linear = values.map((value) => value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4);
  return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2];
}

function ratio(left, right) {
  const [lighter, darker] = [luminance(left), luminance(right)].sort((a, b) => b - a);
  return (lighter + 0.05) / (darker + 0.05);
}

const pairs = [
  { name: "primary action", foreground: "#ffffff", background: token("--blue") },
  { name: "secondary text", foreground: token("--ink-soft"), background: "#ffffff" },
  { name: "metadata text", foreground: token("--ink-faint"), background: "#ffffff" },
  { name: "dark-panel body text", foreground: token("--on-dark-muted"), background: token("--ink") },
  { name: "dark-panel metadata", foreground: token("--on-dark-subtle"), background: token("--ink") },
];

const sourceFiles = [];
function collect(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const target = path.join(directory, entry.name);
    if (entry.isDirectory()) collect(target);
    else if (/\.(tsx|ts|css)$/.test(entry.name)) sourceFiles.push(target);
  }
}
collect(path.join(root, "src"));
const lowOpacityText = sourceFiles.flatMap((file) => {
  const matches = fs.readFileSync(file, "utf8").matchAll(/text-white\/([0-6]\d)/g);
  return [...matches].map((match) => `${path.relative(root, file)}: text-white/${match[1]}`);
});

const results = pairs.map((pair) => ({ ...pair, ratio: Number(ratio(pair.foreground, pair.background).toFixed(2)) }));
console.log(JSON.stringify({ minimum_ratio: 4.5, pairs: results, low_opacity_text: lowOpacityText }, null, 2));

if (results.some((item) => item.ratio < 4.5) || lowOpacityText.length > 0) {
  console.error("Contrast audit failed: use named dark-surface tokens and keep text contrast at 4.5:1 or higher.");
  process.exit(1);
}
