import { createRequire } from "node:module";
import { join } from "node:path";
import { getAgentDir, type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";
import { MODELS, review as reviewAsk } from "./core.ts";

type Link = keyof typeof MODELS;
const LINKS = Object.keys(MODELS) as Link[];
const STATUS = "model-review";

export default function (pi: ExtensionAPI) {
  let context: ExtensionContext | undefined;
  let dispose: (() => void)[] | undefined;

  async function review(link: Link, details: unknown, log?: unknown, ctx = context) {
    if (!ctx) return { kind: "defer" };
    return reviewAsk({
      details, cwd: ctx.cwd, model: MODELS[link], log, signal: ctx.signal,
      classify: async (input, signal) => {
        const model = ctx.modelRegistry.getModelOfType("classifier", MODELS[link].provider, MODELS[link].id);
        if (!model) throw new Error("model-unavailable");
        return ctx.modelRegistry.classify(model, input, { signal });
      },
      onOutcome: outcome => {
        const last = outcome.recommendation
          ? `${outcome.recommendation} (${Math.round(outcome.confidence * 100)}%)`
          : outcome.reason;
        ctx.ui.setStatus(STATUS, `${link}: ${last}; ${outcome.verdict === "allow" ? "approved" : "asked you"}`);
      },
    });
  }

  // Offer each model to the permission package's authorizer chain through its
  // public export. The chain uses one only in the permission mode of that name.
  async function register(sessionId: string) {
    try {
      const require = createRequire(join(getAgentDir(), "npm/package.json"));
      const { getPermissionsService } = await import(require.resolve("@gotgenes/pi-permission-system"));
      // Checked after the await: the session may have ended or already be registered.
      if (dispose || context?.sessionManager.getSessionId() !== sessionId) return;
      const service = getPermissionsService(sessionId);
      if (service) dispose = LINKS.map(link => service.registerAuthorizer(link, (details, _query, log) => review(link, details, log)));
    } catch {
      context?.ui.notify("Model review unavailable; permission asks go to you.", "warning");
    }
  }

  // The permission service may be published before or after this session
  // starts, depending on extension load order, so try at both points.
  pi.events.on("permissions:ready", event => {
    const sessionId = (event as { sessionId?: string })?.sessionId;
    if (sessionId) void register(sessionId);
  });

  pi.on("session_start", async (_event, ctx) => {
    dispose?.forEach(remove => remove());
    dispose = undefined;
    context = ctx;
    await register(ctx.sessionManager.getSessionId());
  });

  pi.on("session_shutdown", () => {
    dispose?.forEach(remove => remove());
    dispose = undefined;
    context?.ui.setStatus(STATUS, undefined);
    context = undefined;
  });

  // /jev-test and /clef-test: one command per model.
  for (const link of LINKS) {
    const name = `${link.replace("auto-", "")}-test`;
    pi.registerCommand(name, {
      description: `Make one real ${MODELS[link].id} classification of a harmless pwd example (does not execute it)`,
      handler: async (_args, ctx) => {
        let result: unknown;
        await review(link, {
          requestId: name, payload: {
            request: { surface: "bash", toolName: "bash", value: "pwd", executedUnit: "pwd", matchedPattern: "*", requester: { forwarded: false } },
            evidence: [{ label: "full command", text: "pwd", detail: null }],
          },
        }, { review: (_event: string, outcome: unknown) => { result = outcome; } }, ctx);
        ctx.ui.notify(`Link ${dispose ? "registered" : "unavailable"}\n${JSON.stringify(result, null, 2)}`, "info");
      },
    });
  }
}
