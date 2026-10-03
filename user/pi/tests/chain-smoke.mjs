#!/usr/bin/env node
/** Offline /chain checks against real Pi lifecycle and session replacement. */
import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { pathToFileURL } from "node:url";

const sourceAgent = process.env.PI_CODING_AGENT_DIR || path.join(os.homedir(), ".pi/agent");
const host = process.env.PI_TEST_HOST_DIR || path.join(os.homedir(),
  ".pi/agent/install/releases/1.0.1/node_modules/@earendil-works/pi-coding-agent");
const handoff = path.join(sourceAgent, "npm/node_modules/@ar-llm/pi-handoff/src/handoff.ts");
const chain = path.resolve("user/pi/extensions/chain.ts");
const temp = await fs.mkdtemp(path.join(os.tmpdir(), "pi-chain-test-"));
const previous = new Map(["PI_CODING_AGENT_DIR", "PI_OFFLINE", "PI_HANDOFF_DEBUG"].map(name => [name, process.env[name]]));
process.env.PI_CODING_AGENT_DIR = path.join(temp, "agent");
process.env.PI_OFFLINE = "1";
process.env.PI_HANDOFF_DEBUG = "0";
let runtime;
try {
  const pi = await import(pathToFileURL(path.join(host, "dist/index.js")));
  const { AssistantMessageEventStream } = await import(pathToFileURL(path.join(host, "../pi-ai/dist/index.js")));
  const { loadExtensions } = await import(pathToFileURL(path.join(host, "dist/core/extensions/loader.js")));
  const { createEventBus } = await import(pathToFileURL(path.join(host, "dist/core/event-bus.js")));
  pi.initTheme("dark", false);
  const agentDir = process.env.PI_CODING_AGENT_DIR;
  const cwd = path.join(temp, "workspace");
  await fs.mkdir(agentDir);
  await fs.mkdir(cwd);
  const task = "Update the plan. Preserve unrelated edits.";
  const goal = "Continue models in teaching mode.";
  const summary = "## Context\nPlan updated; preserve unrelated edits.\n## Task\nContinue models in teaching mode.";
  const editedSummary = summary + "\nReviewed.";
  let scenario, streamCalls, summaryCalls, notices, errors, releaseTask;
  const text = message => typeof message.content === "string" ? message.content : message.content
    .filter(part => part.type === "text").map(part => part.text).join("\n");
  function response(model, content, stopReason = "stop") {
    return { role: "assistant", content: [{ type: "text", text: content }], api: model.api,
      provider: model.provider, model: model.id, stopReason, timestamp: Date.now(),
      usage: { input: 1, output: 1, cacheRead: 0, cacheWrite: 0, totalTokens: 2,
        cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } } };
  }
  const modelRuntime = await pi.ModelRuntime.create({
    authPath: path.join(agentDir, "auth.json"), modelsPath: path.join(agentDir, "models.json"),
  });
  modelRuntime.registerProvider("chain-test", {
    api: "chain-test", apiKey: "fake-offline-test-key", baseUrl: "http://invalid.test",
    models: [{ id: "mock", name: "Mock", input: ["text"], reasoning: false,
      contextWindow: 128000, maxTokens: 4096,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 } }],
    streamSimple(model, context, options) {
      streamCalls.push(context);
      const stream = new AssistantMessageEventStream();
      const first = streamCalls.length === 1;
      const finish = () => {
        const reason = first && scenario === "task-error" ? "error" :
          first && scenario === "task-length" ? "length" :
          first && (scenario === "task-abort" || options?.signal?.aborted) ? "aborted" : "stop";
        const message = response(model, first ? "Plan updated." : "Continue teaching.", reason);
        if (reason === "error" || reason === "aborted") stream.push({ type: "error", reason, error: message });
        else stream.push({ type: "done", reason, message });
        stream.end();
      };
      queueMicrotask(() => {
        stream.push({ type: "start", partial: response(model, "") });
        if (first && ["cancel", "busy", "new-input", "queued-input", "shutdown", "real-abort"].includes(scenario)) {
          releaseTask = finish;
          options?.signal?.addEventListener("abort", finish, { once: true });
        } else finish();
      });
      return stream;
    },
  });
  const model = modelRuntime.getModel("chain-test", "mock");
  assert(model);
  modelRuntime.complete = async (selectedModel, context) => {
    summaryCalls.push(context);
    if (scenario === "summary-error") throw new Error("Offline summary failure");
    return response(selectedModel, summary);
  };
  const theme = { fg: (_color, value) => value, bg: (_color, value) => value, bold: value => value };
  const ui = {
    theme, notify: (...args) => notices.push(args),
    editor: async (_title, value) => { assert.equal(value, summary); return scenario === "editor-cancel" ? undefined : editedSummary; },
    custom: factory => new Promise((resolve, reject) => {
      let component;
      try { component = factory({ requestRender() {} }, theme, {}, value => { component?.dispose?.(); resolve(value); }); }
      catch (error) { reject(error); }
    }),
    setEditorText() { throw new Error("Handoff must submit the reviewed summary"); },
    setStatus() {}, setWidget() {}, setTitle() {}, setWorkingMessage() {},
    setWorkingIndicator() {}, setHiddenThinkingLabel() {},
    confirm: async () => true, select: async () => undefined, input: async () => undefined,
  };
  async function factory({ cwd, sessionManager, sessionStartEvent }) {
    const extensions = await loadExtensions(["missing-handoff", "legacy-prompt"].includes(scenario) ? [chain] : [chain, handoff], cwd, createEventBus());
    assert.deepEqual(extensions.errors, []);
    // Exercise transformations, interception, and extra automatic turns without
    // loading live configuration or making model calls outside the mock provider.
    const interception = path.join(temp, "interception.ts");
    await fs.writeFile(interception, `export default function(pi) {
      pi.on("input", event => {
        if (event.text === ${JSON.stringify(task)}) {
          ${scenario === "transformed" ? 'return {action: "transform", text: "A transformed task."};' : ""}
          ${scenario === "handled" ? 'return {action: "handled"};' : ""}
        }
      });
      ${scenario === "extra-turn" ? 'let continued = false; pi.on("agent_before_settle", () => { if (!continued) { continued = true; return {entries: [{type: "custom_message", customType: "offline-followup", content: "Verify the task before settling.", display: false}], continue: true}; } });' : ""}
    }`);
    const extra = await loadExtensions([interception], cwd, createEventBus());
    extensions.extensions.push(...extra.extensions);
    const resourceLoader = {
      getExtensions: () => extensions, getSkills: () => ({ skills: [], diagnostics: [] }),
      getPrompts: () => ({ prompts: scenario === "legacy-prompt" ? [{ name: "handoff", source: "fixture", content: "Print a brief.", description: "Legacy prompt" }] : [], diagnostics: [] }),
      getThemes: () => ({ themes: [], diagnostics: [] }),
      getAgentsFiles: () => ({ agentsFiles: [] }), getSystemPrompt: () => "Offline test; no tools.",
      getSystemPromptSource: () => undefined, getAppendSystemPrompt: () => [],
      getAppendSystemPromptSources: () => [], extendResources() {}, reload: async () => {},
    };
    const result = await pi.createAgentSession({ cwd, agentDir, sessionManager, sessionStartEvent,
      modelRuntime, model, resourceLoader, tools: [], thinkingLevel: "off",
      settingsManager: pi.SettingsManager.inMemory({ compaction: { enabled: false },
        retry: { enabled: false }, cacheWarming: { enabled: false } }) });
    return { ...result, services: { cwd, agentDir }, diagnostics: [] };
  }
  async function bind(session) {
    await session.bindExtensions({ mode: scenario === "rpc" ? "rpc" : "tui", uiContext: ui,
      onError: error => errors.push(error), commandContextActions: {
        waitForIdle: () => session.waitForIdle(), newSession: options => runtime.newSession(options),
        switchSession: (file, options) => runtime.switchSession(file, options),
      } });
  }
  async function until(condition) {
    const deadline = Date.now() + 5000;
    while (!condition()) {
      if (Date.now() > deadline) throw new Error(`Timed out: ${scenario}; notices=${JSON.stringify(notices)}; errors=${JSON.stringify(errors)}`);
      await new Promise(resolve => setTimeout(resolve, 5));
    }
  }
  for (scenario of ["success", "multiline", "extra-turn", "task-error", "task-length", "task-abort",
    "real-abort", "cancel", "busy", "new-input", "queued-input", "shutdown", "transformed", "handled",
    "editor-cancel", "summary-error", "switch-veto", "missing-handoff", "legacy-prompt", "rpc", "invalid", "empty-goal",
    "slash-task", "slash-goal", "multiple-commands"]) {
    streamCalls = []; summaryCalls = []; notices = []; errors = []; releaseTask = undefined;
    const manager = pi.SessionManager.create(cwd, path.join(temp, "sessions", scenario));
    manager.appendMessage({ role: "user", content: "OBSOLETE_CONTEXT", timestamp: Date.now() });
    manager.appendMessage(response(model, "Old work."));
    runtime = await pi.createAgentSessionRuntime(factory, { cwd, agentDir, sessionManager: manager });
    runtime.setRebindSession(bind);
    await bind(runtime.session);
    if (scenario === "switch-veto") runtime.emitBeforeSwitch = async () => ({ cancelled: true });
    const original = runtime.session;
    const originalId = original.sessionManager.getSessionId();
    const originalFile = original.sessionFile;
    let command = `/chain ${task} then /handoff ${goal}`;
    if (scenario === "multiline") command = `/chain ${task}\nthen /handoff ${goal}`;
    if (scenario === "invalid") command = "/chain Update plan then /sensei Continue";
    if (scenario === "empty-goal") command = `/chain ${task} then /handoff`;
    if (scenario === "slash-task") command = `/chain /sensei ${task} then /handoff ${goal}`;
    if (scenario === "slash-goal") command = `/chain ${task} then /handoff /sensei ${goal}`;
    if (scenario === "multiple-commands") command += " then /sensei Continue";
    await original.prompt(command);
    const rejected = ["missing-handoff", "legacy-prompt", "rpc", "invalid", "empty-goal", "slash-task", "slash-goal", "multiple-commands"].includes(scenario);
    if (!rejected && scenario !== "handled") await until(() => streamCalls.length > 0);
    if (["cancel", "busy", "new-input", "queued-input", "shutdown", "real-abort"].includes(scenario)) {
      await until(() => releaseTask);
      await original.prompt("/chain status");
      assert(notices.some(([message]) => message.includes("Chain is pending")));
      if (scenario === "cancel") await original.prompt("/chain cancel");
      if (scenario === "busy") {
        await original.prompt(command);
        assert(notices.some(([message]) => message.includes("requires an idle session")));
      }
      if (scenario === "new-input") await original.steer("A new user instruction.");
      if (scenario === "queued-input") await original.sendUserMessage("An extension follow-up.", { deliverAs: "followUp" });
      if (scenario === "shutdown") await original.dispose();
      if (scenario === "real-abort") await original.abort();
      else releaseTask();
    }
    const succeeds = ["success", "multiline", "extra-turn", "busy"].includes(scenario);
    const summarizes = succeeds || ["editor-cancel", "summary-error", "switch-veto"].includes(scenario);
    if (summarizes) await until(() => summaryCalls.length === 1);
    if (succeeds) await until(() => runtime.session.sessionManager.getSessionId() !== originalId && runtime.session.isIdle);
    else if (!rejected && scenario !== "handled" && scenario !== "shutdown") await original.waitForIdle();
    assert.deepEqual(errors, [], scenario);
    assert.equal(summaryCalls.length, summarizes ? 1 : 0, scenario);
    if (succeeds) {
      assert.equal(runtime.session.sessionManager.getHeader().parentSession, originalFile);
      const users = runtime.session.messages.filter(message => message.role === "user");
      assert.equal(users.length, 1);
      assert.equal(text(users[0]), editedSummary);
      assert(summaryCalls[0].messages[0].content[0].text.includes("Plan updated."));
      assert(summaryCalls[0].messages[0].content[0].text.includes(goal));
      assert.equal(streamCalls.length, scenario === "extra-turn" ? 4 : 2);
      assert(!JSON.stringify(streamCalls.at(-1)).includes("OBSOLETE_CONTEXT"));
    } else {
      assert.equal(runtime.session.sessionManager.getSessionId(), originalId);
      assert(!streamCalls.some(context => context.messages.some(message => message.role === "user" && text(message) === editedSummary)));
      assert(notices.length > 0);
      if (rejected || scenario === "handled") assert.equal(streamCalls.length, 0);
      if (scenario !== "shutdown" && scenario !== "rpc") {
        // A stopped/cancelled handoff must not fire later on an unrelated task.
        await original.prompt("A later unrelated task.");
        assert.equal(summaryCalls.length, summarizes ? 1 : 0);
      }
    }
    console.log(`Chain: ${scenario} passed`);
    await runtime.dispose();
    runtime = undefined;
  }
} finally {
  await runtime?.dispose();
  await fs.rm(temp, { recursive: true, force: true });
  for (const [name, value] of previous) {
    if (value === undefined) delete process.env[name]; else process.env[name] = value;
  }
}
