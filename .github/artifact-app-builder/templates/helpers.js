// Shared test helpers — keeps individual test files lean
const puppeteer = require("puppeteer-core");
const path = require("path");
const fs = require("fs");

const CHROME = "/opt/pw-browsers/chromium-1194/chrome-linux/chrome";
const PROJECT = path.resolve(__dirname, "..");
const SHELL = "file://" + path.resolve(PROJECT, "shell/index.html");
const SHOTS_DIR = path.resolve(__dirname, "screenshots");

// Ensure screenshots dir exists
if (!fs.existsSync(SHOTS_DIR)) fs.mkdirSync(SHOTS_DIR, { recursive: true });

async function launch() {
  const browser = await puppeteer.launch({
    executablePath: CHROME,
    headless: "new",
    args: ["--no-sandbox", "--disable-setuid-sandbox", "--disable-dev-shm-usage"],
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 720 });

  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));

  await page.goto(SHELL, { waitUntil: "load", timeout: 10000 });
  await new Promise((r) => setTimeout(r, 1500)); // Let React render

  return { browser, page, errors };
}

function screenshot(page, name) {
  return page.screenshot({ path: path.join(SHOTS_DIR, `${name}.png`) });
}

function assert(label, condition) {
  if (condition) {
    console.log(`  ✅ ${label}`);
    return true;
  } else {
    console.log(`  ❌ ${label}`);
    return false;
  }
}

async function wait(ms = 300) {
  return new Promise((r) => setTimeout(r, ms));
}

module.exports = { launch, screenshot, assert, wait, SHOTS_DIR };
