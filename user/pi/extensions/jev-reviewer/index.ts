import { createRequire } from "node:module";
import { join } from "node:path";
import { getAgentDir, type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";
import { MODEL, reviewShadow } from "./core.mjs";

const LINK = "jev-shadow";

export default function (pi: ExtensionAPI) {
  let context: ExtensionContext | undefined;
  let dispose: (() => void) | undefined;

  async function review(details: unknown, log?: unknown, ctx = context) {
    if (!ctx) return { kind: "defer" };
    return reviewShadow({
      details, cwd: ctx.cwd, log, signal: ctx.signal,
      classify: async (input, signal) => {
        const model = ctx.modelRegistry.getModelOfType("classifier", MODEL.provider, MODEL.id);
        if (!model) throw new Error("model-unavailable");
        return ctx.modelRegistry.classify(model, input, { signal });
      },
      onOutcome: outcome => {
        const last = outcome.recommendation
          ? `${outcome.recommendation} (${Math.round(outcome.confidence * 100)}%)`
          : outcome.reason;
        ctx.ui.setStatus(LINK, `Jev shadow: ${last}; human decides`);
      },
    });
  }

  // Add Jev to the permission package's authorizer chain through its public
  // export. The chain uses it only in the jev-shadow permission mode.
  async function register(sessionId: string) {
    try {
      const require = createRequire(join(getAgentDir(), "npm/package.json"));
      const { getPermissionsService } = await import(require.resolve("@gotgenes/pi-permission-system"));
      // Checked after the await: the session may have ended or already be registered.
      if (dispose || context?.sessionManager.getSessionId() !== sessionId) return;
      dispose = getPermissionsService(sessionId)?.registerAuthorizer(LINK, (details, _query, log) => review(details, log));
    } catch {
      context?.ui.notify("Jev shadow link unavailable; permission asks still go to you.", "warning");
    }
  }

  // The permission service may be published before or after this session
  // starts, depending on extension load order, so try at both points.
  pi.events.on("permissions:ready", event => {
    const sessionId = (event as { sessionId?: string })?.sessionId;
    if (sessionId) void register(sessionId);
  });

  pi.on("session_start", async (_event, ctx) => {
    dispose?.();
    dispose = undefined;
    context = ctx;
    await register(ctx.sessionManager.getSessionId());
  });

  pi.on("session_shutdown", () => {
    dispose?.();
    dispose = undefined;
    context?.ui.setStatus(LINK, undefined);
    context = undefined;
  });

  pi.registerCommand("jev-test", {
    description: "Make one real Jev classification of a harmless pwd example (does not execute it)",
    handler: async (_args, ctx) => {
      let result: unknown;
      await review({
        requestId: "jev-test", payload: {
          request: { surface: "bash", toolName: "bash", value: "pwd", executedUnit: "pwd", matchedPattern: "*", requester: { forwarded: false } },
          evidence: [{ label: "full command", text: "pwd", detail: null }],
        },
      }, { review: (_event: string, outcome: unknown) => { result = outcome; } }, ctx);
      ctx.ui.notify(`Link ${dispose ? "registered" : "unavailable"}\n${JSON.stringify(result, null, 2)}`, "info");
    },
  });
}
