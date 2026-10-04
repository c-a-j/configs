#!/usr/bin/env node
/** Offline input-routing checks with the installed pi-vim and fullscreen renderer. */
import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { execFileSync } from "node:child_process";

const sourceAgent = process.env.PI_CODING_AGENT_DIR || path.join(os.homedir(), ".pi/agent");
const host = process.env.PI_TEST_HOST_DIR || path.join(os.homedir(),
  ".pi/agent/install/releases/1.0.1/node_modules/@earendil-works/pi-coding-agent");
const temp = await fs.mkdtemp(path.join(os.tmpdir(), "pi-vim-scroll-test-"));
const previous = new Map(["PI_CODING_AGENT_DIR", "PI_OFFLINE"].map(key => [key, process.env[key]]));
process.env.PI_CODING_AGENT_DIR = path.join(temp, "agent");
process.env.PI_OFFLINE = "1";
let renderer, loaded;
try {
  const pi = await import(pathToFileURL(path.join(host, "dist/index.js")));
  const tui = await import(pathToFileURL(path.join(host, "../pi-tui/dist/index.js")));
  const { KeybindingsManager } = await import(pathToFileURL(path.join(host, "dist/core/keybindings.js")));
  const themes = await import(pathToFileURL(path.join(host, "dist/modes/interactive/theme/theme.js")));
  const { createInteractiveTuiReference } = await import(pathToFileURL(path.join(host,
    "dist/modes/interactive/tui-renderer.js")));
  pi.initTheme("dark", false);
  // Exercise only isolated installation; the stub makes package installs offline.
  const setupAgent = path.join(temp, "setup-agent");
  const bin = path.join(temp, "bin");
  await fs.mkdir(setupAgent);
  await fs.mkdir(bin);
  await fs.writeFile(path.join(bin, "pi"), "#!/bin/sh\nexit 0\n", { mode: 0o700 });
  const savedSettings = { theme: "system", defaultTools: ["+grep", "+find", "+ls"], packages: ["preserve-me"] };
  const savedKeys = '{"tui.select.down":["down","ctrl+j"]}\n';
  await fs.writeFile(path.join(setupAgent, "settings.json"), JSON.stringify(savedSettings));
  await fs.writeFile(path.join(setupAgent, "keybindings.json"), savedKeys);
  const setup = () => execFileSync("bash", [path.resolve("user/pi/setup.sh")], {
    env: { ...process.env, PI_CODING_AGENT_DIR: setupAgent, PATH: `${bin}:${process.env.PATH}` },
  });
  const copiedScroll = path.join(setupAgent, "extensions/vim-scroll.ts");
  const expectedScroll = await fs.readFile(path.resolve("user/pi/extensions/vim-scroll.ts"));
  setup();
  assert.deepEqual(await fs.readFile(copiedScroll), expectedScroll);
  await fs.writeFile(copiedScroll, "outdated extension");
  await fs.chmod(copiedScroll, 0o644);
  setup();
  assert.deepEqual(await fs.readFile(copiedScroll), expectedScroll);
  assert.equal((await fs.stat(copiedScroll)).mode & 0o777, 0o600);
  assert.deepEqual(JSON.parse(await fs.readFile(path.join(setupAgent, "settings.json"), "utf8")), savedSettings);
  assert.equal(await fs.readFile(path.join(setupAgent, "keybindings.json"), "utf8"), savedKeys);

  const agent = process.env.PI_CODING_AGENT_DIR;
  const cwd = path.join(temp, "workspace");
  await fs.mkdir(path.join(agent, "extensions"), { recursive: true });
  await fs.mkdir(cwd);
  await fs.copyFile(path.resolve("user/pi/extensions/vim-scroll.ts"), path.join(agent, "extensions/vim-scroll.ts"));
  await fs.writeFile(path.join(agent, "settings.json"), JSON.stringify({
    packages: [path.join(sourceAgent, "npm/node_modules/pi-vim")],
    piVim: { clipboardMirror: "never" },
  }));
  const loader = new pi.DefaultResourceLoader({ cwd, agentDir: agent,
    noSkills: true, noPromptTemplates: true, noContextFiles: true });
  await loader.reload();
  loaded = loader.getExtensions();
  assert.deepEqual(loaded.errors, []);
  const vimIndex = loaded.extensions.findIndex(extension => extension.path.endsWith("pi-vim/index.ts"));
  const scrollIndex = loaded.extensions.findIndex(extension => extension.path.endsWith("extensions/vim-scroll.ts"));
  assert(vimIndex >= 0 && scrollIndex >= 0, "Discover both pi-vim and the local decorator");
  const scroll = loaded.extensions[scrollIndex];

  let onInput, factory, editor;
  const terminal = {
    columns: 80, rows: 24, kittyProtocolActive: false,
    start(input) { onInput = input; }, stop() {}, write() {},
    moveBy() {}, hideCursor() {}, showCursor() {}, clearLine() {},
    clearFromCursor() {}, clearScreen() {}, setTitle() {}, setProgress() {},
  };
  renderer = new tui.TuiAltScreen(terminal);
  const reference = createInteractiveTuiReference(() => renderer);
  const keybindings = KeybindingsManager.create(agent);
  tui.setKeybindings(keybindings);
  const notices = [];
  const ui = {
    theme: themes.theme, notify: (...args) => notices.push(args),
    getEditorComponent: () => factory,
    setEditorComponent(value) {
      factory = value;
      editor = value(reference, themes.getEditorTheme(), keybindings);
    },
  };
  const ctx = { mode: "tui", hasUI: true, cwd, ui, shutdown() {}, };
  for (const event of [{ type: "session_start" }, { type: "resources_discover", cwd, reason: "startup" }]) {
    for (const extension of loaded.extensions) {
      for (const handler of extension.handlers.get(event.type) ?? []) {
        await handler(event, ctx);
      }
    }
  }
  assert.equal(editor.getMode(), "insert");
  assert.equal(notices.length, 0);
  // The real renderer owns input routing, including fullscreen actions and overlays.
  renderer.addChild(new tui.Text(Array.from({ length: 100 }, (_, i) => `Output line ${i}`).join("\n")));
  renderer.addChild(editor);
  renderer.setFocus(editor);
  renderer.start();
  renderer.renderNow();
  const send = data => { onInput(data); renderer.renderNow(); };
  const top = () => renderer.viewportTop;

  editor.setText("draft");
  renderer.scrollToTop();
  renderer.renderNow();
  const beforeInsert = top();
  send("\n");
  assert.equal(editor.getText(), "draft\n", "Insert Ctrl+j must insert a newline");
  assert.equal(top(), beforeInsert, "Insert Ctrl+j must not scroll output");
  editor.setText("abc def");
  send("\x01"); // Ctrl+a: line start.
  send("\x0b"); // Ctrl+k: delete to line end.
  assert.equal(editor.getText(), "", "Insert Ctrl+k must keep native deletion");

  editor.setText("draft");
  send("\x1b");
  assert.equal(editor.getMode(), "normal");
  renderer.scrollToTop();
  renderer.renderNow();
  const beforeNormal = top();
  const scrollStep = Math.floor(terminal.rows / 4);
  send("\n");
  assert.equal(top(), beforeNormal + scrollStep, "Normal Ctrl+j must scroll down a quarter page");
  assert.equal(editor.getText(), "draft");
  send("\x0b");
  assert.equal(top(), beforeNormal, "Normal Ctrl+k must scroll up a quarter page");
  assert.equal(editor.getText(), "draft");
  send("\x1b[106;5u"); // Kitty Ctrl+j press.
  assert.equal(top(), beforeNormal + scrollStep);
  send("\x1b[106;5:2u"); // Kitty Ctrl+j repeat.
  assert.equal(top(), beforeNormal + 2 * scrollStep);
  send("\x1b[106;5:3u"); // Kitty Ctrl+j release.
  assert.equal(top(), beforeNormal + 2 * scrollStep, "Key releases must not scroll");
  send("\x1b[107;5u");
  assert.equal(top(), beforeNormal + scrollStep);
  terminal.rows = 40;
  renderer.renderNow();
  const beforeResizeScroll = top();
  send("\n");
  assert.equal(top(), beforeResizeScroll + 10, "Quarter-page steps must follow terminal height");
  terminal.rows = 24;
  renderer.renderNow();
  const beforePaste = top();
  send("\x1b[200~\n\x0b\x1b[201~");
  assert.equal(top(), beforePaste, "Pasted control bytes must not become scroll commands");
  assert.equal(editor.getText(), "draft");

  const dialogInput = [];
  const dialog = { render: () => ["Dialog"], invalidate() {}, handleInput: data => dialogInput.push(data) };
  const overlay = renderer.showOverlay(dialog);
  const beforeDialog = top();
  send("\n");
  send("\x0b");
  assert.deepEqual(dialogInput, ["\n", "\x0b"], "Focused overlays must retain their input");
  assert.equal(top(), beforeDialog);
  overlay.hide();
  renderer.setFocus(editor);
  send("v");
  assert.equal(editor.getMode(), "visual");
  const beforeVisual = top();
  send("\n");
  assert.equal(top(), beforeVisual, "Visual mode must not acquire Normal scrolling");
  send("\x1b");
  send("i");
  assert.equal(editor.getMode(), "insert");
  editor.setText("draft");
  send("\x1b[106;5u");
  assert.equal(editor.getText(), "draft\n", "Returning to Insert must restore Ctrl+j");

  // The stable TUI reference must follow renderer replacement without rebuilding the editor.
  send("\x1b");
  renderer.stop();
  renderer = new tui.TuiMainScreen(terminal);
  renderer.addChild(editor);
  renderer.setFocus(editor);
  renderer.start();
  renderer.renderNow();
  send("i");
  editor.setText("regular");
  send("\n");
  assert.equal(editor.getText(), "regular\n");
  send("\x1b");
  renderer.stop();
  renderer = new tui.TuiAltScreen(terminal);
  renderer.addChild(new tui.Text(Array.from({ length: 100 }, (_, i) => `New output ${i}`).join("\n")));
  renderer.addChild(editor);
  renderer.setFocus(editor);
  renderer.start();
  renderer.renderNow();
  renderer.scrollToTop();
  renderer.renderNow();
  send("\n");
  assert.equal(top(), scrollStep, "Scrolling must target the replacement fullscreen renderer");

  // Non-interactive startup and an absent modal factory are safe no-ops.
  for (const mode of ["rpc", "json", "print"]) {
    for (const handler of scroll.handlers.get("resources_discover")) {
      await handler({ type: "resources_discover", cwd, reason: "startup" }, { mode, ui: new Proxy({}, {
        get() { throw new Error("Non-TUI startup must not access terminal UI"); },
      }) });
    }
  }
  for (const handler of scroll.handlers.get("resources_discover")) {
    await handler({ type: "resources_discover", cwd, reason: "startup" }, { mode: "tui", ui: {
      getEditorComponent: () => undefined, setEditorComponent() { assert.fail("No editor to decorate"); },
    } });
  }
  // An unrelated custom editor without pi-vim's mode API is preserved in place.
  const plainInput = [];
  const plainEditor = { handleInput: data => plainInput.push(data) };
  for (const handler of scroll.handlers.get("resources_discover")) {
    await handler({ type: "resources_discover", cwd, reason: "startup" }, { mode: "tui", ui: {
      getEditorComponent: () => () => plainEditor,
      setEditorComponent(value) {
        const decorated = value(reference, themes.getEditorTheme(), keybindings);
        assert.equal(decorated, plainEditor);
        decorated.handleInput("\n");
      },
    } });
  }
  assert.deepEqual(plainInput, ["\n"]);
  // Reload/new sessions recreate pi-vim in Insert; no stale mode is retained.
  for (const event of [{ type: "session_start", reason: "reload" }, { type: "resources_discover", cwd, reason: "reload" }]) {
    for (const extension of loaded.extensions) {
      for (const handler of extension.handlers.get(event.type) ?? []) await handler(event, ctx);
    }
  }
  assert.equal(editor.getMode(), "insert");
  editor.setText("reloaded");
  editor.handleInput("\n");
  assert.equal(editor.getText(), "reloaded\n");
  console.log("Vim scrolling: isolated setup/refresh, discovery, Insert bindings, Normal scrolling, protocols, paste, overlays, Visual, renderer replacement, reload, and non-TUI guards");
} finally {
  renderer?.stop();
  for (const extension of loaded?.extensions ?? []) {
    for (const handler of extension.handlers.get("session_shutdown") ?? []) {
      await handler({ type: "session_shutdown" }, {});
    }
  }
  for (const [key, value] of previous) {
    if (value === undefined) delete process.env[key]; else process.env[key] = value;
  }
  await fs.rm(temp, { recursive: true, force: true });
}
