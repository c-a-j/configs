/** Idle-only GLOBAL permission controls. No private package API or hot-switch claim. */
import { readFile, writeFile, rename, rm } from "node:fs/promises";
import { join } from "node:path";
import { randomUUID } from "node:crypto";
import { getAgentDir, type ExtensionAPI, type ExtensionCommandContext } from "@earendil-works/pi-coding-agent";

const choices = [
  { name: "manual", label: "Manual — approval prompts", chain: [] },
  { name: "auto", label: "Auto — GPT risk assessment", chain: ["classifier"] },
  { name: "yolo", label: "YOLO — no permission prompts", chain: [] },
  { name: "jev-shadow", label: "Jev shadow — experimental; always asks you", chain: ["jev-shadow"] },
];
const configPath = () => join(getAgentDir(), "extensions/pi-permission-system/config.json");

async function readConfig(): Promise<Record<string, unknown>> {
  let config: Record<string, unknown>;
  try {
    config = JSON.parse(await readFile(configPath(), "utf8"));
  } catch (error) {
    throw new Error(`Cannot read permission policy at ${configPath()}: ${String(error)}`);
  }
  if (!config || typeof config !== "object" || Array.isArray(config) ||
      !config.permission || typeof config.permission !== "object" || Array.isArray(config.permission)) {
    throw new Error("Permission policy missing or invalid. Run user/pi/setup.sh first.");
  }
  return config;
}

function currentMode(config: Record<string, unknown>): string {
  if (config.yoloMode === true) return "yolo";
  const chain = config.authorizerChain ?? [];
  return choices.find(choice => choice.name !== "yolo" && JSON.stringify(choice.chain) === JSON.stringify(chain))?.name ?? "custom";
}

export default function (pi: ExtensionAPI) {
  const busyMessage = "Mode unchanged: interrupt the current run, switch modes, then ask the agent to continue. Live switching is not supported by this integration.";

  async function changeMode(name: string, ctx: ExtensionCommandContext) {
    // Waiting for idle inside a command can hang behind an approval prompt.
    // Reloading mid-run is not a supported live-policy change either.
    if (!ctx.isIdle()) {
      ctx.ui.notify(busyMessage, "warning");
      return;
    }
    const choice = choices.find(choice => choice.name === name);
    if (!choice) throw new Error("Usage: /permissions manual|auto|yolo|jev-shadow");
    const config = await readConfig();
    const next = { ...config, yoloMode: name === "yolo", authorizerChain: choice.chain };
    const path = configPath();
    const temporary = `${path}.${randomUUID()}.tmp`;
    try {
      await writeFile(temporary, `${JSON.stringify(next, null, 2)}\n`, { mode: 0o600, flag: "wx" });
      await rename(temporary, path);
    } finally {
      await rm(temporary, { force: true });
    }
    ctx.ui.notify(`GLOBAL permissions: ${name}. Persistent across sessions; reloading this session.`, name === "yolo" ? "warning" : "info");
    await ctx.reload(); // Do not use the old runtime after reload.
  }

  for (const choice of choices) {
    pi.registerCommand(choice.name, {
      description: `Set GLOBAL permissions: ${choice.label} (idle only)`,
      handler: async (_args, ctx) => {
        try { await changeMode(choice.name, ctx); }
        catch (error) { ctx.ui.notify(String(error), "error"); }
      },
    });
  }

  pi.registerCommand("permissions", {
    description: "Show/select GLOBAL permission mode (idle only)",
    handler: async (args, ctx) => {
      try {
        if (args.trim()) { await changeMode(args.trim().toLowerCase(), ctx); return; }
        if (!ctx.isIdle()) { ctx.ui.notify(busyMessage, "warning"); return; }
        const selected = await ctx.ui.select(`GLOBAL permissions: ${currentMode(await readConfig())}`, choices.map(choice => choice.label));
        const choice = choices.find(choice => choice.label === selected);
        if (choice) await changeMode(choice.name, ctx);
      } catch (error) { ctx.ui.notify(String(error), "error"); }
    },
  });

  pi.on("session_start", async (_event, ctx) => {
    try { ctx.ui.setStatus("permission-mode", `permissions:${currentMode(await readConfig())} (global)`); }
    catch (error) { ctx.ui.setStatus("permission-mode", "permissions:config-error"); ctx.ui.notify(String(error), "error"); }
  });
}
