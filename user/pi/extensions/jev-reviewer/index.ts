import { readFile } from "node:fs/promises";
import { createRequire } from "node:module";
import { join } from "node:path";
import { getAgentDir, type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";
import { reviewShadow, validateConfig } from "./core.mjs";

const LINK = "jev-shadow";
const configPath = () => join(getAgentDir(), "extensions/jev-reviewer/config.json");

export default function (pi: ExtensionAPI) {
  let context: ExtensionContext | undefined;
  let dispose: (() => void) | undefined;
  let registering = false;
  let generation = 0;
  let last = "not run";

  async function review(details: unknown, log?: unknown, ctx = context) {
    if (!ctx) return { kind: "defer" };
    let config;
    try {
      config = validateConfig(JSON.parse(await readFile(configPath(), "utf8")));
    } catch {
      try { (log as any)?.review("jev.shadow", { mode: "shadow", verdict: "defer", reason: "config-unavailable" }); } catch {}
      return { kind: "defer" };
    }
    return reviewShadow({
      details, config, cwd: ctx.cwd, log, signal: ctx.signal,
      classify: async (input, signal) => {
        const model = ctx.modelRegistry.getModelOfType("classifier", config.provider, config.model);
        if (!model) throw new Error("model-unavailable");
        return ctx.modelRegistry.classify(model, input, { signal });
      },
      onOutcome: outcome => {
        last = outcome.recommendation
          ? `${outcome.recommendation} (${Math.round(outcome.confidence * 100)}%)`
          : outcome.reason;
        ctx.ui.setStatus("jev-shadow", `Jev shadow: ${last}; human decides`);
      },
    });
  }

  async function register(sessionId: string) {
    if (!context || dispose || registering || context.sessionManager.getSessionId() !== sessionId) return;
    registering = true;
    const currentGeneration = generation;
    try {
      // Resolve the installed package's PUBLIC export; no private gate imports
      // or extra dependency copy. Symbol-backed service survives module isolation.
      const require = createRequire(join(getAgentDir(), "npm/package.json"));
      const entry = require.resolve("@gotgenes/pi-permission-system");
      const { getPermissionsService } = await import(entry);
      if (generation !== currentGeneration) return;
      const service = getPermissionsService(sessionId);
      if (service) dispose = service.registerAuthorizer(LINK, (details, _query, log) => review(details, log));
    } catch {
      context?.ui.notify("Jev shadow link unavailable; permission asks still go to you.", "warning");
    } finally {
      if (generation === currentGeneration) registering = false;
    }
  }

  pi.events.on("permissions:ready", event => {
    const sessionId = (event as { sessionId?: string })?.sessionId;
    if (sessionId) void register(sessionId);
  });

  pi.on("session_start", async (_event, ctx) => {
    generation++;
    dispose?.();
    dispose = undefined;
    registering = false;
    context = ctx;
    last = "not run";
    // Also register here to tolerate either package order. The repeating ready
    // event covers a service not yet published at this point.
    await register(ctx.sessionManager.getSessionId());
  });

  pi.registerCommand("jev-status", {
    description: "Show Jev shadow reviewer configuration and last recommendation",
    handler: async (_args, ctx) => {
      try {
        const config = validateConfig(JSON.parse(await readFile(configPath(), "utf8")));
        ctx.ui.notify(`${config.provider}/${config.model}; SHADOW ONLY; link ${dispose ? "registered" : "unavailable"}; last: ${last}`, "info");
      } catch {
        ctx.ui.notify(`Jev config missing or invalid: ${configPath()}. All asks still defer to you.`, "warning");
      }
    },
  });

  pi.registerCommand("jev-test", {
    description: "Make one real Jev classification of a harmless pwd example (does not execute it)",
    handler: async (_args, ctx) => {
      let result;
      await review({
        requestId: "jev-test", payload: {
          request: { surface: "bash", toolName: "bash", value: "pwd", executedUnit: "pwd", matchedPattern: "*", requester: { forwarded: false } },
          evidence: [{ label: "full command", text: "pwd", detail: null }],
        },
      }, { review: (_event, outcome) => { result = outcome; } }, ctx);
      ctx.ui.notify(JSON.stringify(result ?? { verdict: "defer", reason: "config-unavailable" }, null, 2), "info");
    },
  });

  pi.on("session_shutdown", () => {
    generation++;
    dispose?.();
    dispose = undefined;
    registering = false;
    context?.ui.setStatus("jev-shadow", undefined);
    context = undefined;
  });
}
