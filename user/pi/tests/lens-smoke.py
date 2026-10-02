#!/usr/bin/env python3
"""Verify pinned pi-lens registration and parsing without models or live writes."""
import json
import os
from pathlib import Path
import select
import subprocess
import tempfile
import time

AGENT = Path(os.environ.get("PI_CODING_AGENT_DIR", Path.home() / ".pi/agent"))
PACKAGE = "npm:pi-lens@4.3.0"

with tempfile.TemporaryDirectory(prefix="pi-lens-test-") as directory:
    temp = Path(directory)
    agent = temp / "agent"
    agent.mkdir()
    (agent / "npm").symlink_to(AGENT / "npm", target_is_directory=True)
    fixture = temp / "fixture.ts"
    source = "export function greet(name: string): string {\n  return `Hello, ${name}!`;\n}\n"
    fixture.write_text(source)
    config = temp / "lens-config.json"
    config.write_text(json.dumps({
        "startup": {"mode": "minimal", "scans": {"enabled": False}},
        "lsp": {"enabled": False}, "tests": {"enabled": False},
        "opengrep": {"enabled": False}, "format": {"enabled": False},
        "autofix": {"enabled": False}, "contextInjection": {"enabled": False},
    }))
    probe = temp / "probe.ts"
    tools_module = AGENT / "npm/node_modules/pi-lens/dist/tools/module-report.js"
    probe.write_text(f'import {{createModuleReportTool, createReadSymbolTool}} from {json.dumps(str(tools_module))};\n' + '''
      export default function(pi) {
        pi.registerCommand("probe-lens", {
          description: "Inspect registration and parse an isolated fixture",
          handler: async (_args, ctx) => {
            const report = await createModuleReportTool(() => ctx.cwd).execute(
              "fixture-report", {path: "fixture.ts"}, undefined, undefined, ctx);
            const symbol = await createReadSymbolTool(() => ctx.cwd, () => {}).execute(
              "fixture-symbol", {path: "fixture.ts", symbol: "greet"}, undefined, undefined, ctx);
            ctx.ui.notify(JSON.stringify({probe: true,
              tools: pi.getAllTools().map(tool => tool.name), report, symbol}), "info");
          }
        });
      }
    ''')
    (agent / "settings.json").write_text(json.dumps({
        "packages": [PACKAGE, str(probe)],
    }))
    env = {**os.environ, "PI_CODING_AGENT_DIR": str(agent),
           "PI_LENS_CONFIG_PATH": str(config), "PI_LENS_HOME": str(temp / "lens-home"),
           "PILENS_DATA_DIR": str(temp / "lens-data"),
           "PI_LENS_DISABLE_LSP_INSTALL": "1", "PI_LENS_DISABLE_TOOL_INSTALL": "1"}
    stderr_path = temp / "stderr.log"
    with stderr_path.open("w+") as stderr:
        process = subprocess.Popen(
            ["pi", "--offline", "--mode", "rpc", "--no-session", "--no-context-files"],
            cwd=temp, env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=stderr,
        )
        buffer = bytearray()

        def receive(deadline):
            while b"\n" not in buffer:
                remaining = deadline - time.monotonic()
                if remaining <= 0 or not select.select([process.stdout], [], [], remaining)[0]:
                    raise AssertionError("Timed out waiting for Pi RPC\n" + stderr_path.read_text())
                data = os.read(process.stdout.fileno(), 65536)
                if not data:
                    raise AssertionError("Pi exited unexpectedly\n" + stderr_path.read_text())
                buffer.extend(data)
            line, _, rest = buffer.partition(b"\n")
            buffer[:] = rest
            return json.loads(line)

        def request(identifier, kind, **fields):
            process.stdin.write((json.dumps({"id": identifier, "type": kind, **fields}) + "\n").encode())
            process.stdin.flush()
            events = []
            deadline = time.monotonic() + 60
            while True:
                event = receive(deadline)
                events.append(event)
                assert event.get("type") != "extension_error", event
                if event.get("type") == "response" and event.get("id") == identifier:
                    assert event["success"], event
                    return event, events

        try:
            result, _ = request("commands", "get_commands")
            names = {entry["name"] for entry in result["data"]["commands"]}
            assert {"lens-health", "lens-tools", "lens-toggle", "lens-context-toggle",
                    "skill:pi-lens-ast-grep", "skill:pi-lens-lsp-navigation"} <= names, names
            _, events = request("probe", "prompt", message="/probe-lens")
            payload = next(json.loads(event["message"]) for event in events
                           if event.get("method") == "notify" and event.get("message", "").startswith('{"probe":'))
            assert {"lens_diagnostics", "module_report", "read_symbol", "read_enclosing",
                    "symbol_search", "lsp_navigation", "ast_grep_search",
                    "pi_lens_activate_tools"} <= set(payload["tools"]), payload["tools"]
            assert not payload["report"].get("isError"), payload["report"]
            assert payload["report"]["details"]["symbols"] >= 1, payload["report"]
            assert not payload["symbol"].get("isError"), payload["symbol"]
            assert "Hello, ${name}!" in json.dumps(payload["symbol"]), payload["symbol"]
            assert fixture.read_text() == source, "Fixture was rewritten"
            print("pi-lens: commands, bundled skills, and diagnostic/navigation tools registered")
            print("pi-lens: bundled TypeScript grammar parsed a module and read a symbol body")
        finally:
            process.stdin.close()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        errors = stderr_path.read_text()
        assert "Failed to load extension" not in errors, errors
