#!/usr/bin/env python3
"""Offline feature discovery and storage checks; no model calls or live writes.

Run after setup: python3 user/pi/tests/features-smoke.py
"""
import json
import os
from pathlib import Path
import select
import shutil
import sqlite3
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
AGENT = Path(os.environ.get("PI_CODING_AGENT_DIR", Path.home() / ".pi/agent"))
PACKAGES = ["npm:@gotgenes/pi-subagents@21.9.1", "npm:pi-hermes-memory@0.9.9"]

with tempfile.TemporaryDirectory(prefix="pi-features-test-") as directory:
    temp = Path(directory)
    agent = temp / "agent"
    agent.mkdir()
    (agent / "npm").symlink_to(AGENT / "npm", target_is_directory=True)
    shutil.copytree(ROOT / "prompts", agent / "prompts")
    shutil.copytree(ROOT / "agents", agent / "agents")
    shutil.copyfile(ROOT / "subagents.json", agent / "subagents.json")
    memory_config = json.loads((ROOT / "hermes-memory-config.json").read_text())
    assert memory_config["reviewEnabled"] and memory_config["correctionDetection"]
    assert memory_config["flushOnCompact"] and not memory_config["flushOnShutdown"]
    assert not memory_config["standingInstructionsEnabled"]
    assert "llmThinkingOverride" not in memory_config
    # Disable every automatic model-calling path in this isolated test session.
    memory_config.update(reviewEnabled=False, correctionDetection=False,
                         flushOnCompact=False, flushOnShutdown=False,
                         autoConsolidate=False, memoryOverflowStrategy="reject")
    (agent / "hermes-memory-config.json").write_text(json.dumps(memory_config))
    storage = agent / "pi-hermes-memory"
    storage.mkdir()
    fixture = "Offline fixture: preserve unrelated configuration."
    (storage / "MEMORY.md").write_text(fixture + "\n")
    subagents = json.loads((agent / "subagents.json").read_text())
    assert subagents["maxConcurrent"] == 2 and subagents["defaultMaxTurns"] == 20
    assert PACKAGES[1] in subagents["excludedExtensionPackages"]
    assert "npm:@gotgenes/pi-permission-system@36.2.1" not in subagents["excludedExtensionPackages"]

    probe = temp / "probe.ts"
    parser = AGENT / "npm/node_modules/@gotgenes/pi-subagents/src/config/custom-agents.ts"
    probe.write_text(f'import {{loadCustomAgents}} from {json.dumps(str(parser))};\n' + '''
      export default function(pi) {
        pi.registerCommand("probe-features", {
          description: "Inspect tool and agent configuration without calling models",
          handler: async (_args, ctx) => {
            const reviewer = loadCustomAgents(ctx.cwd).get("reviewer");
            ctx.ui.notify(JSON.stringify({probe: true, tools: pi.getActiveTools(), reviewer}), "info");
          }
        });
      }
    ''')
    (agent / "settings.json").write_text(json.dumps({
        "packages": [*PACKAGES, str(probe)],
        "defaultTools": ["+grep", "+find", "+ls"],
        "defaultThinkingLevel": "high",
    }))
    stderr_path = temp / "stderr.log"
    with stderr_path.open("w+") as stderr:
        process = subprocess.Popen(
            ["pi", "--offline", "--mode", "rpc", "--no-session"], cwd=temp,
            env={**os.environ, "PI_CODING_AGENT_DIR": str(agent)},
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=stderr,
        )
        buffer = bytearray()

        def receive(deadline):
            while b"\n" not in buffer:
                remaining = deadline - time.monotonic()
                if remaining <= 0 or not select.select([process.stdout], [], [], remaining)[0]:
                    raise AssertionError("Timed out waiting for Pi RPC\n" + stderr_path.read_text())
                data = os.read(process.stdout.fileno(), 65536)
                if not data:
                    raise AssertionError(stderr_path.read_text())
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
            assert {"teach", "review", "handoff", "subagents:sessions", "subagents:settings",
                    "memory-insights", "memory-preview-context"} <= names, names
            assert "test-plan" not in names
            _, events = request("probe", "prompt", message="/probe-features")
            payload = next(json.loads(event["message"]) for event in events
                           if event.get("method") == "notify" and event.get("message", "").startswith('{"probe":'))
            tools = set(payload["tools"])
            assert {"read", "bash", "edit", "write", "grep", "find", "ls",
                    "subagent", "get_subagent_result", "steer_subagent", "memory_search"} <= tools, tools
            reviewer = payload["reviewer"]
            assert set(reviewer["toolNames"]) == {"read", "grep", "find", "ls"}, reviewer
            assert reviewer["runInBackground"] and not reviewer["inheritContext"]
            assert reviewer["maxTurns"] == 12
            assert set(reviewer["locked"]) == {"max_turns", "inherit_context", "run_in_background"}
            assert reviewer.get("model") is None and reviewer.get("thinking") is None
            print("Discovery: native search tools, workflow prompts, subagents, read-only background reviewer")
            _, events = request("memory", "prompt", message="/memory-insights")
            assert any(fixture in event.get("message", "") for event in events), events
            database = storage / "sessions.db"
            assert database.exists(), "Memory storage must initialize successfully, not silently degrade"
            with sqlite3.connect(f"file:{database}?mode=ro", uri=True) as connection:
                assert connection.execute("PRAGMA quick_check").fetchone() == ("ok",)
                assert connection.execute("SELECT count(*) FROM memories WHERE content = ?", (fixture,)).fetchone()[0] == 1
                assert connection.execute("SELECT count(*) FROM memory_fts WHERE memory_fts MATCH ?", ('"Offline fixture"',)).fetchone()[0] == 1
            print("Memory: isolated Markdown load, SQLite integrity, and full-text search")
        finally:
            process.stdin.close()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        errors = stderr_path.read_text()
        assert "Failed to load extension" not in errors, errors
