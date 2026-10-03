/** Run one ordinary task, then invoke the maintained handoff command. */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const USAGE = "Usage: /chain <task> then /handoff <goal>; /chain status; /chain cancel";

type ChainPlan = { task: string; goal: string };
type PendingChain = ChainPlan & {
  sessionId: string;
  started: boolean;
  outcome?: "completed" | "aborted" | "error";
  stopReason?: string;
  aborted: boolean;
};

/** The explicit separator is reserved syntax, not a shell or Markdown parser. */
export function parseChain(args: string): ChainPlan {
  const separators = [...args.matchAll(/\s+then[ \t]+\/([\w:-]+)(?=\s|$)/g)];
  if (separators.length !== 1 || separators[0][1] !== "handoff") {
    throw new Error("Chain supports one task followed by one /handoff command. " + USAGE);
  }
  const separator = separators[0];
  const task = args.slice(0, separator.index).trim();
  const goal = args.slice(separator.index! + separator[0].length).trim();
  if (!task || !goal) throw new Error(USAGE);
  if (task.startsWith("/") || goal.startsWith("/")) {
    throw new Error("Use ordinary task and goal text. Describe teaching mode in the goal instead of chaining /sensei.");
  }
  return { task, goal };
}

export default function chain(pi: ExtensionAPI) {
  let pending: PendingChain | undefined;

  pi.registerCommand("chain", {
    description: "Run a task, then review a handoff to a fresh session; status/cancel",
    handler: async (args, ctx) => {
      if (ctx.mode !== "tui") {
        ctx.ui.notify("chain requires interactive mode", "error");
        return;
      }
      if (args.trim() === "status") {
        ctx.ui.notify(pending ? "Chain is pending: finish the current task, then review /handoff." : "No chain is pending.", "info");
        return;
      }
      if (args.trim() === "cancel") {
        const existed = Boolean(pending);
        pending = undefined;
        ctx.ui.notify(existed ? "Chain cancelled. The current task continues; no handoff will follow." : "No chain is pending.", "info");
        return;
      }
      if (pending || !ctx.isIdle() || ctx.hasPendingMessages()) {
        ctx.ui.notify("Chain requires an idle session with no pending chain or queued messages.", "warning");
        return;
      }
      let plan: ChainPlan;
      try {
        plan = parseChain(args);
      } catch (error) {
        ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
        return;
      }
      if (!pi.getCommands().some(command => command.name === "handoff" && command.source === "extension")) {
        ctx.ui.notify("The /handoff extension is unavailable. Install the pinned package and reload before using /chain.", "error");
        return;
      }
      if (!ctx.model) {
        ctx.ui.notify("No model selected", "error");
        return;
      }
      pending = { ...plan, sessionId: ctx.sessionManager.getSessionId(), started: false, aborted: false };
      ctx.ui.notify("Chain started. Handoff review follows when the task settles. Use /chain cancel to keep this session.", "info");
      // This API returns void. Waiting for idle immediately would race prompt
      // preflight, so completion is observed through the session lifecycle.
      pi.sendUserMessage(plan.task);
    },
  });

  pi.on("input", (event, ctx) => {
    if (pending && event.source !== "extension") {
      pending = undefined;
      ctx.ui.notify("Chain cancelled by new input. Submit /chain again when ready.", "info");
    }
  });

  pi.on("before_agent_start", (event, ctx) => {
    if (!pending) return;
    if (pending.started || pending.sessionId !== ctx.sessionManager.getSessionId() || event.prompt !== pending.task) {
      pending = undefined;
      ctx.ui.notify("Chain cancelled because another or transformed task started.", "warning");
      return;
    }
    pending.started = true;
  });

  pi.on("message_start", (event, ctx) => {
    if (!pending?.started || event.message.role !== "user") return;
    const content = event.message.content;
    const text = typeof content === "string" ? content : content.filter(part => part.type === "text").map(part => part.text).join("\n");
    if (text !== pending.task) {
      pending = undefined;
      ctx.ui.notify("Chain cancelled because another user message entered the run.", "info");
    }
  });

  pi.on("message_end", event => {
    if (!pending?.started || event.message.role !== "assistant") return;
    pending.stopReason = event.message.stopReason;
    if (event.message.stopReason === "aborted") pending.aborted = true;
  });

  pi.on("agent_before_settle", event => {
    if (pending?.started) {
      pending.outcome = event.outcome;
      if (event.outcome === "aborted") pending.aborted = true;
    }
  });

  pi.on("agent_settled", (_event, ctx) => {
    const finished = pending;
    pending = undefined;
    if (!finished) return;
    if (!finished.started || finished.aborted || finished.outcome !== "completed" || finished.stopReason !== "stop" || ctx.hasPendingMessages()) {
      ctx.ui.notify("Chain stopped without handoff: the task did not settle normally or more messages are queued.", "warning");
      return;
    }
    if (finished.sessionId !== ctx.sessionManager.getSessionId()) return;
    ctx.ui.notify("Task settled. Opening handoff review.", "info");
    // Pi 1.0.1 defers messages sent during agent_settled until all notification
    // handlers finish. Command dispatch then receives a command-capable context.
    // Do not call newSession from an event or use captured state after dispatch.
    pi.sendUserMessage(`/handoff ${finished.goal}`, { expandPromptTemplates: true });
  });

  pi.on("session_shutdown", () => { pending = undefined; });
  pi.on("session_tree", () => { pending = undefined; });
}
