#!/usr/bin/env python3
"""Offline integration checks against installed packages; never edits live config.
Run: python3 user/pi/tests/permissions-smoke.py (after setup.sh).
"""
import hashlib
import json
import os
import select
import subprocess
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AGENT = Path(os.environ.get("PI_CODING_AGENT_DIR", Path.home() / ".pi/agent"))

with tempfile.TemporaryDirectory(prefix="pi-permissions-test-") as directory:
    temp = Path(directory)
    agent = temp / "agent"
    gate = agent / "extensions/pi-permission-system/config.json"
    judge = agent / "extensions/pi-permission-classifier/config.json"
    # Exercise setup offline, with a fake package installer and isolated agent dir.
    fake_bin = temp / "bin"
    fake_bin.mkdir()
    fake_pi = fake_bin / "pi"
    installs = temp / "installs.txt"
    fake_pi.write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> "$PI_INSTALL_TRACE"\n')
    fake_pi.chmod(0o700)
    setup_env = {**os.environ, "PATH": f"{fake_bin}:{os.environ['PATH']}",
                 "PI_CODING_AGENT_DIR": str(agent), "PI_INSTALL_TRACE": str(installs)}
    def setup(*args):
        subprocess.run(["bash", str(ROOT / "setup.sh"), *args], env=setup_env, check=True, capture_output=True)
    agent.mkdir()
    settings_path = agent / "settings.json"
    web_config = agent / "web-search.json"
    saved_web_config = '{"provider": "brave", "workflow": "none", "localCustomization": true}\n'
    web_config.write_text(saved_web_config)
    settings_path.write_text(json.dumps({"theme": "system", "defaultThinkingLevel": "high",
                                         "defaultTools": ["-bash", "+codemode", "-grep"]}))
    setup()
    settings = json.loads(settings_path.read_text())
    assert settings == {"theme": "system", "defaultThinkingLevel": "high",
                        "defaultTools": ["-bash", "+codemode", "+grep", "+find", "+ls"]}
    for name in ("pi-hermes-memory", "projects-memory"):
        assert (agent / name).stat().st_mode & 0o777 == 0o700, "New memory stores must be private"
    runtime_files = ["subagents.json", "hermes-memory-config.json", "AGENTS.md"]
    for file in runtime_files:
        assert (agent / file).read_bytes() == (ROOT / file).read_bytes()
        (agent / file).write_text('{"localCustomization": true}\n')
    reviewer = agent / "agents/reviewer.md"
    assert reviewer.read_bytes() == (ROOT / "agents/reviewer.md").read_bytes()
    reviewer.write_text("outdated agent")
    legacy_handoff = agent / "prompts/handoff.md"
    assert not legacy_handoff.exists(), "Fresh setup must not install a handoff prompt"
    legacy_handoff.write_bytes((ROOT / "tests/fixtures/legacy-handoff.md").read_bytes())
    workflows = ["review.md", "grill-me.md"]
    for file in workflows:
        assert (agent / "prompts" / file).read_bytes() == (ROOT / "prompts" / file).read_bytes()
        (agent / "prompts" / file).write_text("outdated template")
    policy = json.loads((ROOT / "permissions/config.json").read_text())
    assert json.loads(gate.read_text()) == policy
    assert policy["yoloMode"] is False and policy["authorizerChain"] == ["classifier"], "Fresh setup must default to Auto"
    assert not (agent / "extensions/jev-reviewer").exists()
    helper = agent / "extensions/permission-modes.ts"
    assert helper.read_bytes() == (ROOT / "extensions/permission-modes.ts").read_bytes()
    footer = agent / "extensions/footer-colors.ts"
    assert not footer.is_symlink() and footer.read_bytes() == (ROOT / "extensions/footer-colors.ts").read_bytes()
    footer.unlink()
    footer.symlink_to(temp / "deleted-worktree/footer-colors.ts")
    teaching = agent / "prompts/teach.md"
    assert teaching.read_bytes() == (ROOT / "prompts/teach.md").read_bytes()
    teaching.write_text("outdated template")
    caveman_files = ["SKILL.md", "LICENSE", "LICENSE-MIT", "NOTICE", "UPSTREAM.md"]
    caveman = agent / "skills/caveman"
    assert {file.name for file in caveman.iterdir()} == set(caveman_files), "Install only the core skill and attribution"
    for file in caveman_files:
        assert (caveman / file).read_bytes() == (ROOT / "skills/caveman" / file).read_bytes()
    assert hashlib.sha256((caveman / "SKILL.md").read_bytes()).hexdigest() == "0bf09a0a9a017d004a81d4b693e5a2d830e1a28230a5885df773e1ed9c0571cc", "Keep the reviewed upstream skill verbatim"
    (caveman / "SKILL.md").write_text("outdated skill")
    grill = agent / "skills/grill-me"
    grill_files = {"SKILL.md", "LICENSE", "UPSTREAM.md"}
    assert {file.name for file in grill.iterdir()} == grill_files
    for file in grill_files:
        assert (grill / file).read_bytes() == (ROOT / "skills/grill-me" / file).read_bytes()
    (grill / "SKILL.md").write_text("outdated skill")
    policy["authorizerChain"] = ["test-existing-mode"]
    gate.write_text(json.dumps(policy))
    saved = gate.read_bytes()
    setup()
    assert not legacy_handoff.exists(), "Setup must remove the exact legacy handoff prompt"
    legacy_handoff.write_text("Locally customized handoff prompt\n")
    assert gate.read_bytes() == saved, "Setup must preserve existing runtime policy/mode"
    assert web_config.read_text() == saved_web_config, "Setup must preserve personal web provider settings"
    assert json.loads(settings_path.read_text()) == settings, "Tool merge must be idempotent"
    for file in runtime_files:
        assert (agent / file).read_text() == '{"localCustomization": true}\n'
    assert reviewer.read_bytes() == (ROOT / "agents/reviewer.md").read_bytes()
    for file in workflows:
        assert (agent / "prompts" / file).read_bytes() == (ROOT / "prompts" / file).read_bytes()
    for existing, expected in [([], ["grep", "find", "ls"]),
                               (["read", "-ls"], ["read", "grep", "find", "ls"]),
                               (None, ["+grep", "+find", "+ls"])]:
        custom = {"defaultThinkingLevel": "high", "custom": {"preserve": True}}
        if existing is not None:
            custom["defaultTools"] = existing
        settings_path.write_text(json.dumps(custom))
        setup()
        assert json.loads(settings_path.read_text()) == {**custom, "defaultTools": expected}
    assert not footer.is_symlink() and footer.read_bytes() == (ROOT / "extensions/footer-colors.ts").read_bytes(), "Setup must repair a dangling footer worktree symlink"
    assert teaching.read_bytes() == (ROOT / "prompts/teach.md").read_bytes(), "Setup must refresh the teaching template"
    assert (caveman / "SKILL.md").read_bytes() == (ROOT / "skills/caveman/SKILL.md").read_bytes(), "Setup must refresh the Caveman skill"
    assert (grill / "SKILL.md").read_bytes() == (ROOT / "skills/grill-me/SKILL.md").read_bytes(), "Setup must refresh the Grill Me skill"
    setup("--with-jev")
    assert legacy_handoff.read_text() == "Locally customized handoff prompt\n", "Preserve customized handoff prompts"
    legacy_handoff.unlink()
    assert gate.read_bytes() == saved
    for file in ["index.ts", "core.mjs", "package.json"]:
        assert (agent / "extensions/jev-reviewer" / file).read_bytes() == (ROOT / "extensions/jev-reviewer" / file).read_bytes()
    assert set(installs.read_text().splitlines()) == {
        "install npm:pi-vim@0.14.2", "install npm:@signalridge/pi-plan-mode@1.4.2",
        "install npm:pi-permission-classifier@0.5.2", "install npm:@gotgenes/pi-permission-system@36.2.1",
        "install npm:@gotgenes/pi-subagents@21.9.1", "install npm:pi-hermes-memory@0.9.9",
        "install npm:@ar-llm/pi-handoff@0.5.0",
        "install npm:pi-web-access@0.35.0", "install npm:@upstash/context7-pi@0.1.2",
        "install npm:pi-lens@4.3.0"}
    print("Setup: Auto default, pinned packages, stable extension copies, preserved policy, Jev opt-in")
    policy["authorizerChain"] = []
    # A deterministic deny must survive YOLO as well as other mode changes.
    blocked = temp / "always-denied.txt"
    policy["permission"]["write"] = {"*": "ask", str(blocked): "deny"}
    gate.write_text(json.dumps(policy))
    # Deliberately unresolved reviewer: Auto must fall back to a human prompt.
    judge.write_text(json.dumps({"provider": "missing-test-provider", "model": "missing-test-model"}))
    jev = agent / "extensions/jev-reviewer/config.json"
    jev.write_text(json.dumps({"provider": "missing-test-provider", "model": "missing-test-model"}))
    # Public package resolution uses the agent's managed npm root, not its auth.
    (agent / "npm").symlink_to(AGENT / "npm", target_is_directory=True)
    probe = temp / "probe.ts"
    gate_entry = AGENT / "npm/node_modules/@gotgenes/pi-permission-system/src/index.ts"
    probe.write_text(f'import permissionSystem from {json.dumps(str(gate_entry))};\n'
                     f'import modeControls from {json.dumps(str(ROOT / "extensions/permission-modes.ts"))};\n' + '''
      import {writeFile} from "node:fs/promises";
      export default function(pi) {
        let gateHandler;
        const modeCommands = new Map();
        modeControls({...pi, registerCommand(name, command) { modeCommands.set(name, command); }, on() { return () => {}; }});
        pi.registerCommand("probe-busy-mode", {
          description: "Ensure a busy mode switch returns without waiting, mutating, or reloading",
          handler: async (args, ctx) => {
            let forbiddenCalls = 0;
            await modeCommands.get(args).handler("", {...ctx, isIdle: () => false,
              waitForIdle() { forbiddenCalls++; throw new Error("must not wait"); },
              reload() { forbiddenCalls++; throw new Error("must not reload"); }});
            if (forbiddenCalls) throw new Error("Busy mode control tried to wait/reload");
          }
        });
        // Capture the real package's tool_call gate for deterministic offline
        // testing, while preserving all its normal lifecycle registrations.
        permissionSystem({...pi, on(type, handler) {
          if (type === "tool_call") { gateHandler = handler; return () => {}; }
          return pi.on(type, handler);
        }});
        pi.registerCommand("probe-read", {
          description: "Query read boundaries without reading any contents",
          handler: async (args, ctx) => {
            const result = await gateHandler({type: "tool_call", toolCallId: "test-read",
              toolName: "read", input: {path: args}}, ctx);
            ctx.ui.notify(JSON.stringify(result ?? {allowed: true}), "info");
          }
        });
        pi.registerCommand("probe-write", {
          description: "Test the real write gate in an isolated temporary directory",
          handler: async (args, ctx) => {
            const result = await gateHandler({type: "tool_call", toolCallId: "test",
              toolName: "write", input: {path: args, content: "approved test write"}}, ctx);
            if (!result?.block) await writeFile(args, "approved test write");
            ctx.ui.notify(JSON.stringify(result ?? {allowed: true}), "info");
          }
        });
      }
    ''')
    packages = [
        str(AGENT / "npm/node_modules/pi-permission-classifier"),
        str(probe),
    ]
    (agent / "settings.json").write_text(json.dumps({"packages": packages}))
    stderr_path = temp / "stderr.log"
    with stderr_path.open("w+") as stderr:
        process = subprocess.Popen(
            ["pi", "--offline", "--mode", "rpc", "--no-session"],
            cwd=temp, env={**os.environ, "PI_CODING_AGENT_DIR": str(agent)},
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=stderr,
        )
        buffer = bytearray()
        def receive(deadline):
            assert process.stdout is not None
            while b"\n" not in buffer:
                remaining = deadline - time.monotonic()
                if remaining <= 0 or not select.select([process.stdout], [], [], remaining)[0]:
                    raise AssertionError("Timed out waiting for Pi RPC")
                data = os.read(process.stdout.fileno(), 65536)
                if not data:
                    raise AssertionError(stderr_path.read_text())
                buffer.extend(data)
            line, _, rest = buffer.partition(b"\n")
            buffer[:] = rest
            return json.loads(line)
        def request(identifier, kind, approve=False, **fields):
            assert process.stdin is not None
            process.stdin.write((json.dumps({"id": identifier, "type": kind, **fields}) + "\n").encode())
            process.stdin.flush()
            prompts = []
            deadline = time.monotonic() + 30
            while True:
                event = receive(deadline)
                if os.environ.get("PI_PERMISSION_TEST_DEBUG"):
                    print(event)
                assert event.get("type") != "extension_error", event
                if event.get("type") == "extension_ui_request" and event.get("method") == "select":
                    prompts.append(event)
                    options = event["options"]
                    # Explicit approval/denial only; never approve session patterns.
                    if approve:
                        selected = next(option for option in options if
                                        option == "Yes" or "approve once" in option.lower() or "allow once" in option.lower())
                    else:
                        selected = next(option for option in options if option == "No" or "deny" in option.lower())
                    process.stdin.write((json.dumps({"type": "extension_ui_response", "id": event["id"], "value": selected}) + "\n").encode())
                    process.stdin.flush()
                if event.get("type") == "response" and event.get("id") == identifier:
                    assert event["success"], event
                    return event, prompts
        try:
            result, _ = request("commands", "get_commands")
            names = {entry["name"] for entry in result["data"]["commands"]}
            assert {"manual", "auto", "jev-shadow", "yolo", "permissions", "probe-write", "jev-test", "jev-status"} <= names, names
            assert {"teach", "review", "grill-me", "skill:grill-me"} <= names, "Pi must discover native workflow prompts and Grill Me"
            for name, source in (("grill-me", "prompt"), ("skill:grill-me", "skill")):
                entries = [entry for entry in result["data"]["commands"] if entry["name"] == name]
                assert len(entries) == 1 and entries[0]["source"] == source, entries
            print("Grill Me: isolated setup, refresh, native skill discovery, and prompt shortcut")
            assert "handoff" not in names, "Handoff is no longer a native prompt template"
            assert "test-plan" not in names, "Do not install the declined test-plan prompt"
            assert "skill:caveman" in names, "Pi must discover the native Caveman skill"
            assert next(entry for entry in result["data"]["commands"] if entry["name"] == "skill:caveman")["source"] == "skill"
            assert "caveman" not in names, "No custom Caveman command wrapper"
            assert "auto-gpt" not in names, "No redundant Auto alias"
            assert json.loads(gate.read_text())["authorizerChain"] == []
            original = gate.read_bytes()
            for mode in ["manual", "auto", "yolo", "jev-shadow", "permissions"]:
                request(f"busy-{mode}", "prompt", message=f"/probe-busy-mode {mode}")
                assert gate.read_bytes() == original
            request("invalid-mode", "prompt", message="/permissions invalid-mode")
            assert gate.read_bytes() == original
            print("Busy/invalid switches return immediately without changing policy")
            secret = temp / ".env"
            secret.write_text("FAKE_TEST_VALUE=not-a-real-secret")
            outside = temp.parent / "outside-permission-test.txt"
            for path in [secret, outside]:
                _, prompts = request(f"manual-read-{path.name}", "prompt", message=f"/probe-read {path}")
                assert prompts, (path, prompts)
            print("Manual: sensitive-path and outside-project reads require approval")
            denied = temp / "manual-denied.txt"
            _, prompts = request("manual-deny", "prompt", message=f"/probe-write {denied}")
            assert prompts and not denied.exists(), prompts
            print("Manual: write prompts; denial prevents mutation")
            allowed = temp / "manual-approved.txt"
            _, prompts = request("manual-allow", "prompt", approve=True, message=f"/probe-write {allowed}")
            assert prompts and allowed.read_text() == "approved test write"
            print("Manual: explicit approval allows mutation")
            request("auto", "prompt", message="/auto")
            assert json.loads(gate.read_text())["authorizerChain"] == ["classifier"]
            auto_denied = temp / "auto-denied.txt"
            _, prompts = request("auto-deny", "prompt", message=f"/probe-write {auto_denied}")
            assert prompts and not auto_denied.exists(), prompts
            print("Auto: GPT reviewer failure falls back to approval; denial prevents mutation")
            for path in [secret, outside]:
                _, prompts = request(f"auto-read-{path.name}", "prompt", message=f"/probe-read {path}")
                assert prompts, (path, prompts)
            print("Auto: sensitive/outside reads remain human decisions")
            request("jev-shadow", "prompt", message="/jev-shadow")
            assert json.loads(gate.read_text())["authorizerChain"] == ["jev-shadow"]
            jev_denied = temp / "jev-denied.txt"
            _, prompts = request("jev-deny", "prompt", message=f"/probe-write {jev_denied}")
            assert prompts and not jev_denied.exists(), prompts
            log = agent / "extensions/pi-permission-system/logs/pi-permission-system-permission-review.jsonl"
            assert "jev.shadow" in log.read_text(), "Jev must register and run, not merely fall back as a missing link"
            print("Jev shadow: optional link registers, records review, and defers to human")
            request("yolo", "prompt", message="/yolo")
            assert json.loads(gate.read_text())["yoloMode"] is True
            yolo = temp / "yolo.txt"
            _, prompts = request("yolo-write", "prompt", message=f"/probe-write {yolo}")
            assert not prompts and yolo.read_text() == "approved test write", prompts
            print("YOLO: write runs without approval prompts")
            _, prompts = request("yolo-deny", "prompt", message=f"/probe-write {blocked}")
            assert not prompts and not blocked.exists()
            print("YOLO: deterministic deny still prevents mutation")
            request("manual", "prompt", message="/manual")
            config = json.loads(gate.read_text())
            assert config["yoloMode"] is False and config["authorizerChain"] == []
            assert config["permission"] == policy["permission"]
            print("Returning to Manual preserves policy and disables reviewer/YOLO")
        finally:
            assert process.stdin is not None
            process.stdin.close()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        errors = stderr_path.read_text()
        assert "Failed to load extension" not in errors, errors
