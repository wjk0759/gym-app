#!/usr/bin/env node
/**
 * FitAI Web Preview module check.
 *
 * The preview intentionally has no bundler. This script catches the most
 * common split-file regressions:
 * - syntax errors
 * - index.html references missing files
 * - duplicate top-level globals between load-order modules
 * - accidental re-introduction of a monolithic JS/CSS file
 */

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const root = path.resolve(__dirname, "..", "preview");
const index = fs.readFileSync(path.join(root, "index.html"), "utf8");
const errors = [];

const scriptSources = [...index.matchAll(/<script[^>]+src="([^"]+)"/g)].map((m) => m[1]);
const styleSources = [...index.matchAll(/<link[^>]+href="([^"]+\.css[^"]*)"/g)].map((m) => m[1]);

for (const source of [...scriptSources, ...styleSources]) {
  const clean = source.split("?")[0];
  if (!fs.existsSync(path.join(root, clean))) {
    errors.push(`index.html references missing file: ${clean}`);
  }
}

const jsFiles = [];
function walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full);
    else if (entry.name.endsWith(".js")) jsFiles.push(full);
  }
}
walk(path.join(root, "js"));

const globals = new Map();
const actionMethods = new Map();
for (const file of jsFiles) {
  const source = fs.readFileSync(file, "utf8");
  const relative = path.relative(root, file);
  try {
    new vm.Script(source, { filename: file });
  } catch (error) {
    errors.push(`${relative}: ${error.message}`);
    continue;
  }

  const lineCount = source.split(/\r?\n/).length;
  if (lineCount > 800) {
    errors.push(`${relative}: ${lineCount} lines; split this module before it becomes a monolith`);
  }

  // Action modules only register object methods, so their method names are
  // checked separately from top-level page globals.
  if (file.includes(`${path.sep}actions${path.sep}`)) {
    for (const match of source.matchAll(/^  ([A-Za-z_$][\w$]*)\([^\n]*\) \{/gm)) {
      const name = match[1];
      if (!actionMethods.has(name)) actionMethods.set(name, []);
      actionMethods.get(name).push(relative);
    }
    continue;
  }

  for (const match of source.matchAll(/^(?:function|const|let)\s+([A-Za-z_$][\w$]*)/gm)) {
    const name = match[1];
    if (!globals.has(name)) globals.set(name, []);
    globals.get(name).push(relative);
  }
}

for (const [name, files] of globals) {
  if (files.length > 1) {
    errors.push(`duplicate top-level global "${name}": ${files.join(", ")}`);
  }
}

for (const [name, files] of actionMethods) {
  if (files.length > 1) {
    errors.push(`duplicate app action "${name}": ${files.join(", ")}`);
  }
}

const oldEntry = path.join(root, "app.js");
if (fs.existsSync(oldEntry)) {
  const lines = fs.readFileSync(oldEntry, "utf8").split(/\r?\n/).length;
  if (lines > 20) {
    errors.push(`app.js looks like a monolith again (${lines} lines); keep it as a namespace only`);
  }
}
if (fs.existsSync(path.join(root, "styles.css"))) {
  errors.push("styles.css should stay split into preview/css modules");
}

if (errors.length) {
  console.error(`Web preview check failed (${errors.length}):`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log(
  `Web preview check passed: ${jsFiles.length} JS modules, ` +
  `${styleSources.length} CSS modules, ${scriptSources.length} scripts.`
);
