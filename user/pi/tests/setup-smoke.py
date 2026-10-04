#!/usr/bin/env python3
"""Offline checks of setup.sh and the local mode commands; never edits live config.
Run: python3 user/pi/tests/setup-smoke.py
"""
import hashlib
import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

with tempfile.TemporaryDirectory(prefix="pi-permissions-test-") as directory:
    temp = Path(directory)
    # Test deployment using temporary sources and destination, not live files.
    source = temp / "source"
    shutil.copytree(ROOT, source)
    ROOT = source
    agent = temp / "agent"

    def assert_linked(target, source):
        assert not target.is_symlink() and target.samefile(source), (target, source)

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

    def managed_pairs():
        pairs = [(ROOT / "permissions/config.json", gate)]
        for file in ["subagents.json", "hermes-memory-config.json", "AGENTS.md", "keybindings.json"]:
            pairs.append((ROOT / file, agent / file))
        for folder in ["extensions", "prompts", "agents", "skills"]:
            pairs.extend((path, agent / path.relative_to(ROOT))
                         for path in (ROOT / folder).rglob("*")
                         if path.is_file())
        return pairs

    # Simulate an outdated machine: local state, stale copies, and a dangling symlink.
    (agent / "extensions").mkdir(parents=True)
    preserved = {"auth.json": "Preserved authentication fixture\n",
                 "web-search.json": '{"provider": "brave", "localCustomization": true}\n',
                 "extensions/custom.txt": "Preserved unmanaged extension\n",
                 "prompts/handoff.md": "Locally customized handoff prompt\n"}
    for relative, content in preserved.items():
        (agent / relative).parent.mkdir(exist_ok=True)
        (agent / relative).write_text(content)
    (agent / "AGENTS.md").write_text("outdated instructions")
    (agent / "extensions/chain.ts").write_text("outdated extension")
    (agent / "extensions/jev-reviewer").mkdir()
    (agent / "extensions/jev-reviewer/index.ts").write_text("outdated extension")
    (agent / "extensions/footer-colors.ts").symlink_to(temp / "deleted-worktree/footer-colors.ts")
    settings_path = agent / "settings.json"
    settings_path.write_text(json.dumps({"deviceId": "local", "theme": "dark", "custom": {"preserve": True},
                                         "defaultModel": "work-model",
                                         "packages": ["npm:pi-vim@0.0.1"]}))
    setup()
    for relative, content in preserved.items():
        assert (agent / relative).read_text() == content, relative
    # extensions/chain.ts and extensions/jev-reviewer are retired; setup removes them.
    for relative in ("setup.sh", "README.md", "tests", "permissions", "extensions/chain.ts", "extensions/jev-reviewer"):
        assert not (agent / relative).exists(), relative
    for name in ("pi-hermes-memory", "projects-memory"):
        assert (agent / name).stat().st_mode & 0o777 == 0o700, "New memory stores must be private"
    for source_path, target_path in managed_pairs():
        assert_linked(target_path, source_path)
    # Repository settings win; machine-local keys survive the merge. Model
    # choices are the reverse: the repository fills only what the machine lacks.
    repository_settings = json.loads((ROOT / "settings.json").read_text())
    model_defaults = json.loads((ROOT / "model-defaults.json").read_text())
    assert model_defaults["defaultModel"] != "work-model" and not set(model_defaults) & set(repository_settings)
    settings = json.loads(settings_path.read_text())
    assert settings == {"deviceId": "local", "custom": {"preserve": True}, **model_defaults,
                        "defaultModel": "work-model", **repository_settings}
    assert not settings_path.samefile(ROOT / "settings.json")
    assert judge.read_bytes() == (ROOT / "permissions/classifier.json").read_bytes() and not judge.samefile(ROOT / "permissions/classifier.json")
    judge.write_text('{"provider": "work", "model": "work-judge"}')
    policy = json.loads(gate.read_text())
    assert policy["yoloMode"] is False and policy["authorizerChain"] == ["classifier"], "Fresh setup must default to Auto"

    # Mode-specific teaching changes must preserve the shared safety boundaries.
    teaching_source = (ROOT / "prompts/sensei.md").read_bytes()
    for rule in (
        b"I type the code and run the commands.",
        b"Do not edit, create, delete, or format",
        b"files, install packages, run tests or other commands, or delegate implementation.",
        b"You may use read-only inspection tools",
        b"Do not continue to the next step until I respond.",
        b"Do not implement anything\njust because teaching mode ended.",
        b"not a permission-policy change or a sandbox",
        b"these teaching instructions and the selected mode",
    ):
        assert rule in teaching_source, rule
    assert b"http://" not in teaching_source and b"https://" not in teaching_source, "The prompt must be self-contained"
    caveman = agent / "skills/caveman"
    assert {file.name for file in caveman.iterdir()} == {"SKILL.md", "LICENSE", "LICENSE-MIT", "NOTICE", "UPSTREAM.md"}, "Install only the core skill and attribution"
    assert hashlib.sha256((caveman / "SKILL.md").read_bytes()).hexdigest() == "0bf09a0a9a017d004a81d4b693e5a2d830e1a28230a5885df773e1ed9c0571cc", "Keep the reviewed upstream skill verbatim"
    assert {file.name for file in (agent / "skills/grill-me").iterdir()} == {"SKILL.md", "LICENSE", "UPSTREAM.md"}

    # In-place repository edits reach the agent directory without rerunning setup.
    instructions = ROOT / "AGENTS.md"
    with instructions.open("a") as output:
        output.write("\nHard link test fixture.\n")
    assert (agent / "AGENTS.md").read_bytes() == instructions.read_bytes()
    # A replaced runtime file, such as a policy rewritten by a mode change,
    # leaves the repository untouched until setup links it again.
    gate.unlink()
    gate.write_text(json.dumps({**policy, "authorizerChain": ["test-existing-mode"]}))
    assert json.loads((ROOT / "permissions/config.json").read_text()) == policy
    setup()
    for source_path, target_path in managed_pairs():
        assert_linked(target_path, source_path)
    assert json.loads(settings_path.read_text()) == settings
    assert json.loads(judge.read_text())["model"] == "work-judge", "Setup must keep a machine's own classifier model"
    assert set(installs.read_text().splitlines()) == {f"install {package}" for package in repository_settings["packages"]}
    assert repository_settings["packages"] and all(
        package.startswith("npm:") and package.rsplit("@", 1)[1][0].isdigit() for package in repository_settings["packages"]
    ), "Packages must be pinned"
    # Installed pinned packages are not reinstalled.
    installs.write_text("")
    for package in repository_settings["packages"]:
        name, version = package.removeprefix("npm:").rsplit("@", 1)
        manifest = agent / "npm/node_modules" / name / "package.json"
        manifest.parent.mkdir(parents=True)
        manifest.write_text(json.dumps({"version": "0.0.0" if name == "pi-lens" else version}))
    setup()
    assert installs.read_text().splitlines() == ["install npm:pi-lens@4.3.0"]
    shutil.rmtree(agent / "npm")
    (agent / "prompts/handoff.md").unlink()  # Remove the custom test prompt before runtime discovery.
    print("Setup: hard links, merged settings, machine-local model choices, Auto default, pinned packages")
    # The subagent memory exclusion must match the pinned package string exactly.
    excluded = json.loads((ROOT / "subagents.json").read_text())["excludedExtensionPackages"]
    assert set(excluded) <= set(repository_settings["packages"]), "Update subagents.json with the memory pin"

    # Drive the local mode commands through a real, isolated Pi over RPC.
    settings_path.write_text("{}")
    source_policy = (ROOT / "permissions/config.json").read_bytes()
    process = subprocess.Popen(
        ["pi", "--offline", "--mode", "rpc", "--no-session"], cwd=temp, text=True,
        env={**os.environ, "PI_CODING_AGENT_DIR": str(agent)},
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    )
    def command(message):
        process.stdin.write(json.dumps({"id": message, "type": "prompt", "message": message}) + "\n")
        process.stdin.flush()
        for line in process.stdout:
            event = json.loads(line)
            assert event.get("type") != "extension_error", event
            if event.get("type") == "response" and event.get("id") == message:
                assert event["success"], event
                return json.loads(gate.read_text())
        raise AssertionError(process.stderr.read())
    try:
        assert command("/permissions invalid-mode") == policy, "An invalid mode must not change policy"
        for mode, yolo, chain in (("/yolo", True, []), ("/auto-jev", False, ["auto-jev"]), ("/auto-clef", False, ["auto-clef"]),
                                 ("/manual", False, []), ("/permissions auto", False, ["classifier"])):
            config = command(mode)
            assert (config["yoloMode"], config["authorizerChain"]) == (yolo, chain), (mode, config)
            assert config["permission"] == policy["permission"], "Mode changes must keep permission rules"
        assert (ROOT / "permissions/config.json").read_bytes() == source_policy, "Mode changes must not alter repository defaults"
    finally:
        process.stdin.close()
        process.wait(timeout=10)
    print("Modes: /manual, /auto, /yolo, /auto-jev, /auto-clef, and /permissions rewrite only the installed policy")
