// ── 5.1.2: every translation lookup resolves to a real string ──────────
//
// 5.1.1 called i18n("je_nav.focus.home") without themePrefix(). Theme
// strings live under theme_translations.<themeId>., so the bare key
// resolved to the literal "[en.je_nav.focus.home]" (seen live), which is
// truthy and so also defeated every built-in fallback label. The
// projection tests pass labels in directly and could not see it.
//
// This test reads the component sources and the locale file: every i18n()
// call must wrap themePrefix(), and every key named must exist in
// locales/en.yml.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");

const ROOT = path.resolve(__dirname, "..");
const SOURCES = [
  "javascripts/discourse/components/je-nav/je-nav.gjs",
  "javascripts/discourse/components/je-nav-mobile/je-nav-mobile.gjs",
  "javascripts/discourse/components/je-nav-responsive.gjs",
  "javascripts/discourse/lib/je-nav-core.js",
  "javascripts/discourse/initializers/init-je-nav.js",
].filter((file) => fs.existsSync(path.join(ROOT, file)));

const read = (file) => fs.readFileSync(path.join(ROOT, file), "utf8");

// Minimal reader for the `en:` tree of locales/en.yml: returns the set of
// dotted keys that hold a string value. Indentation is two spaces.
function localeKeys() {
  const keys = new Set();
  const stack = [];
  for (const line of read("locales/en.yml").split(/\r?\n/)) {
    const match = line.match(/^( *)([A-Za-z0-9_]+):\s*(.*)$/);
    if (!match) {
      continue;
    }
    const depth = match[1].length / 2;
    stack.length = depth;
    stack[depth] = match[2];
    if (match[3] !== "") {
      keys.add(stack.join("."));
    }
  }
  return keys;
}

test("every i18n() call wraps themePrefix()", () => {
  for (const file of SOURCES) {
    const bare = [...read(file).matchAll(/\bi18n\(\s*(?!themePrefix\()/g)];
    assert.equal(bare.length, 0, `${file} has an i18n() call without themePrefix()`);
  }
});

test("every themePrefix key exists in locales/en.yml", () => {
  const keys = localeKeys();
  let checked = 0;
  for (const file of SOURCES) {
    for (const [, key] of read(file).matchAll(/themePrefix\(\s*"([^"]+)"\s*\)/g)) {
      checked += 1;
      assert.ok(keys.has(`en.${key}`), `${file}: en.${key} is missing from locales/en.yml`);
    }
  }
  assert.ok(checked >= 17, `expected at least 17 keys, found ${checked}`);
});
