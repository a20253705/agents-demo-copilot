// Shell entry — mocks Claude.ai artifact runtime for local testing
import React from "react";
import { createRoot } from "react-dom/client";

// ── Mock window.storage (mirrors Claude.ai API exactly) ──
const _store = new Map();

window.storage = {
  async get(key, shared = false) {
    if (!_store.has(key)) throw new Error(`Key not found: ${key}`);
    return { key, value: _store.get(key), shared };
  },
  async set(key, value, shared = false) {
    _store.set(key, value);
    return { key, value, shared };
  },
  async delete(key, shared = false) {
    const had = _store.has(key);
    _store.delete(key);
    return { key, deleted: had, shared };
  },
  async list(prefix = "", shared = false) {
    const keys = [..._store.keys()].filter((k) => k.startsWith(prefix));
    return { keys, prefix, shared };
  },
};

// ── Import assembled app (esbuild resolves this) ──
// NOTE: Update this import path to match your concat output filename
import App from "../app.jsx";

// ── Render ──
const root = createRoot(document.getElementById("root"));
root.render(React.createElement(App));
