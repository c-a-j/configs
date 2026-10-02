#!/usr/bin/env node
/** Offline checks of the published handoff against real Pi session replacement.
 * All storage is temporary; both summary and continuation models are mocked.
 */
import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { pathToFileURL } from "node:url";

const sourceAgent = process.env.PI_CODING_AGENT_DIR || path.join(os.homedir(), ".pi/agent");
const host = process.env.PI_TEST_HOST_DIR || path.join(
  os.homedir(), ".pi/agent/install/releases/1.0.0/node_modules/@earendil-works/pi-coding-agent",
);
const extension = path.join(sourceAgent, "npm/node_modules/@ar-llm/pi-handoff/src/handoff.ts");
const metadata = JSON.parse(await fs.readFile(path.join(path.dirname(extension), "../package.json")));
assert.equal(metadata.version, "0.5.0", "Test the pinned published extension");
const temp = await fs.mkdtemp(path.join(os.tmpdir(), "pi-handoff-test-"));
const previousAgent = process.env.PI_CODING_AGENT_DIR;
const previousOffline = process.env.PI_OFFLINE;
const previousDebug = process.env.PI_HANDOFF_DEBUG;
process.env.PI_CODING_AGENT_DIR = path.join(temp, "agent");
process.env.PI_OFFLINE = "1";
process.env.PI_HANDOFF_DEBUG = "0";
let runtime;
try {
  const pi = await import(pathToFileURL(path.join(host, "dist/index.js")));
  const { AssistantMessageEventStream } = await import(pathToFileURL(
    path.join(host, "../pi-ai/dist/index.js"),
  ));
  const { loadExtensions } = await import(pathToFileURL(path.join(host, "dist/core/extensions/loader.js")));
  const { createEventBus } = await import(pathToFileURL(path.join(host, "dist/core/event-bus.js")));
  pi.initTheme("dark", false);
  const agentDir = process.env.PI_CODING_AGENT_DIR;
  const cwd = path.join(temp, "workspace");
  await fs.mkdir(agentDir);
  await fs.mkdir(cwd);
  const summary = "## Context\nKeep unrelated edits.\n## Task\nFinish tests.";
  const editedSummary = summary + "\nReviewed by the user.";
  let scenario, summaryCalls, continuationCalls, notices, errors;
  function response(model, text, stopReason = "stop") {
    return {
      role: "assistant", content: [{ type: "text", text }], api: model.api,
      provider: model.provider, model: model.id, stopReason, timestamp: Date.now(),
      usage: { input: 1, output: 1, cacheRead: 0, cacheWrite: 0, totalTokens: 2,
        cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } },
    };
  }
  const modelRuntime = await pi.ModelRuntime.create({
    authPath: path.join(agentDir, "auth.json"), modelsPath: path.join(agentDir, "models.json"),
  });
  modelRuntime.registerProvider("handoff-test", {
    api: "handoff-test", apiKey: "fake-offline-test-key", baseUrl: "http://invalid.test",
    models: [{ id: "mock", name: "Mock", input: ["text"], reasoning: false,
      contextWindow: 128000, maxTokens: 4096,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 } }],
    streamSimple(model, context) {
      continuationCalls.push(context);
      const stream = new AssistantMessageEventStream();
      queueMicrotask(() => {
        const message = response(model, "Continued from the reviewed handoff.");
        stream.push({ type: "start", partial: message });
        stream.push({ type: "done", reason: "stop", message });
        stream.end();
      });
      return stream;
    },
  });
  const model = modelRuntime.getModel("handoff-test", "mock");
  assert(model);
  modelRuntime.complete = async (selectedModel, context) => {
    summaryCalls.push(context);
    if (scenario === "generation-error") return response(selectedModel, "", "error");
    if (scenario === "generation-throw") throw new Error("Offline provider failure");
    if (scenario === "empty") return response(selectedModel, "  ");
    if (scenario === "loader-cancel") return response(selectedModel, "", "aborted");
    return response(selectedModel, summary);
  };
  const theme = { fg: (_color, text) => text, bg: (_color, text) => text, bold: text => text };
  const ui = {
    theme, notify: (...args) => notices.push(args),
    editor: async (_title, text) => {
      assert.equal(text, summary);
      return scenario === "editor-cancel" ? undefined : editedSummary;
    },
    custom: factory => new Promise((resolve, reject) => {
      let component;
      try {
        component = factory({ requestRender() {} }, theme, {}, value => {
          component?.dispose?.();
          resolve(value);
        });
      } catch (error) { reject(error); }
    }),
    setEditorText() { throw new Error("Handoff must submit, not leave an editor draft"); },
    setStatus() {}, setWidget() {}, setTitle() {}, setWorkingMessage() {},
    setWorkingIndicator() {}, setHiddenThinkingLabel() {},
    confirm: async () => true, select: async () => undefined, input: async () => undefined,
  };
  async function factory({ cwd, sessionManager, sessionStartEvent }) {
    const extensions = await loadExtensions([extension], cwd, createEventBus());
    assert.deepEqual(extensions.errors, [], "The published package must load on Pi 1.0.0");
    const resourceLoader = {
      getExtensions: () => extensions, getSkills: () => ({ skills: [], diagnostics: [] }),
      getPrompts: () => ({ prompts: [], diagnostics: [] }), getThemes: () => ({ themes: [], diagnostics: [] }),
      getAgentsFiles: () => ({ agentsFiles: [] }), getSystemPrompt: () => "Offline test; no tools.",
      getSystemPromptSource: () => undefined, getAppendSystemPrompt: () => [],
      getAppendSystemPromptSources: () => [], extendResources() {}, reload: async () => {},
    };
    const settingsManager = pi.SettingsManager.inMemory({
      compaction: { enabled: false }, retry: { enabled: false }, cacheWarming: { enabled: false },
    });
    const result = await pi.createAgentSession({ cwd, agentDir, sessionManager, sessionStartEvent,
      modelRuntime, model, resourceLoader, settingsManager, tools: [], thinkingLevel: "off" });
    return { ...result, services: { cwd, agentDir }, diagnostics: [] };
  }
  async function bind(session) {
    await session.bindExtensions({ mode: "tui", uiContext: ui, onError: error => errors.push(error),
      commandContextActions: {
        waitForIdle: () => session.waitForIdle(),
        newSession: options => runtime.newSession(options),
        switchSession: (file, options) => runtime.switchSession(file, options),
      } });
  }
  for (scenario of ["success", "compacted", "editor-cancel", "loader-cancel", "generation-error",
    "generation-throw", "empty", "switch-veto", "bare-command"]) {
    summaryCalls = []; continuationCalls = []; notices = []; errors = [];
    const manager = pi.SessionManager.create(cwd, path.join(temp, "sessions", scenario));
    manager.appendMessage({ role: "user", content: "OBSOLETE_CONTEXT", timestamp: Date.now() });
    manager.appendMessage(response(model, "Files inspected."));
    const keptId = manager.appendMessage({ role: "user", content: "KEPT_CONTEXT", timestamp: Date.now() });
    if (scenario === "compacted") manager.appendCompaction("COMPACTED_SUMMARY", keptId, 1000);
    manager.appendMessage(response(model, "Finish tests; keep unrelated edits."));
    runtime = await pi.createAgentSessionRuntime(factory, { cwd, agentDir, sessionManager: manager });
    runtime.setRebindSession(bind);
    await bind(runtime.session);
    if (scenario === "switch-veto") runtime.emitBeforeSwitch = async () => ({ cancelled: true });
    const originalFile = runtime.session.sessionFile;
    const originalId = runtime.session.sessionManager.getSessionId();
    await runtime.session.prompt(scenario === "bare-command" ? "/handoff" : "/handoff finish tests");
    await runtime.session.waitForIdle();
    assert.deepEqual(errors, []);
    const replaced = runtime.session.sessionManager.getSessionId() !== originalId;
    if (scenario === "success" || scenario === "compacted") {
      assert(replaced);
      assert.equal(runtime.session.sessionManager.getHeader().parentSession, originalFile);
      const userMessages = runtime.session.messages.filter(message => message.role === "user");
      assert.equal(userMessages.length, 1, "Do not copy the outgoing transcript into the new session");
      const content = userMessages[0].content;
      assert.equal(typeof content === "string" ? content : content.map(part => part.text).join("\n"), editedSummary);
      assert.equal(continuationCalls.length, 1, "The fresh session must actually continue");
      if (scenario === "compacted") {
        const history = summaryCalls[0].messages[0].content[0].text;
        assert(history.includes("COMPACTED_SUMMARY") && history.includes("KEPT_CONTEXT"));
        assert(!history.includes("OBSOLETE_CONTEXT"));
      }
    } else {
      assert(!replaced, `${scenario} must keep the original session`);
      assert.equal(continuationCalls.length, 0);
      assert(notices.length > 0, "Failure/cancellation must be visible");
    }
    assert.equal(summaryCalls.length, scenario === "bare-command" ? 0 : 1);
    console.log(`Handoff: ${scenario} passed`);
    await runtime.dispose();
    runtime = undefined;
  }
} finally {
  await runtime?.dispose();
  await fs.rm(temp, { recursive: true, force: true });
  for (const [name, value] of [["PI_CODING_AGENT_DIR", previousAgent], ["PI_OFFLINE", previousOffline],
    ["PI_HANDOFF_DEBUG", previousDebug]]) {
    if (value === undefined) delete process.env[name]; else process.env[name] = value;
  }
}
