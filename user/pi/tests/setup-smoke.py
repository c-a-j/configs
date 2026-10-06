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
    package_sources = [package if isinstance(package, str) else package["source"]
                       for package in repository_settings["packages"]]
    context7 = next(package for package in repository_settings["packages"]
                    if isinstance(package, dict) and package["source"].startswith("npm:@upstash/context7-pi@"))
    assert context7["skills"] == [], "Exclude the package's broad lookup skill, not its tools or prompts"
    assert "extensions" not in context7 and "prompts" not in context7
    assert (agent / "skills/context7-docs/SKILL.md").is_file(), "Install the targeted lookup skill"
    memory = json.loads((agent / "hermes-memory-config.json").read_text())
    assert memory["memoryMode"] == "policy-only" and memory["memoryPolicyStyle"] == "custom"
    assert memory["memoryPolicyCustomText"].strip(), "Retain concise recall and trust guidance"
    assert memory["reviewEnabled"] is True
    assert (memory["nudgeInterval"], memory["nudgeToolCalls"], memory["reviewRecentMessages"]) == (20, 30, 20)
    assert memory["flushOnCompact"] is True and memory["flushRecentMessages"] == 20
    assert memory["correctionDetection"] is True and memory["flushOnShutdown"] is False
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
    assert policy["permission"]["memory_search"] == "allow", "Memory searches must not require approval"
    assert policy["permission"]["*"] == "ask", "Unlisted tools must still require review"

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
    assert set(installs.read_text().splitlines()) == {f"install {package}" for package in package_sources}
    assert package_sources and all(
        package.startswith("npm:") and package.rsplit("@", 1)[1][0].isdigit() for package in package_sources
    ), "Packages must be pinned"
    # Installed pinned packages are not reinstalled.
    installs.write_text("")
    for package in package_sources:
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
    assert set(excluded) <= set(package_sources), "Update subagents.json with the memory pin"

    # Exercise native package resource filtering without a download or model call.
    # The fixture mimics Context7's manifest; only its bundled skill is excluded.
    package_name, package_version = context7["source"].removeprefix("npm:").rsplit("@", 1)
    package_root = agent / "npm/node_modules" / package_name
    (package_root / "skills/bundled-lookup").mkdir(parents=True)
    (package_root / "prompts").mkdir()
    (package_root / "package.json").write_text(json.dumps({
        "name": package_name, "version": package_version, "type": "module",
        "pi": {"extensions": ["index.js"], "skills": ["skills"], "prompts": ["prompts"]},
    }))
    (package_root / "skills/bundled-lookup/SKILL.md").write_text(
        "---\nname: bundled-lookup\ndescription: BUNDLED_LOOKUP_MUST_NOT_LOAD\n---\nAlways look up everything.\n")
    (package_root / "prompts/c7-docs.md").write_text(
        "---\ndescription: Explicit documentation lookup fixture\n---\nLook up $1.\n")
    (package_root / "index.js").write_text('''
export default function (pi) {
  pi.registerTool({
    name: "fixture_docs", label: "Documentation fixture", description: "Fixture tool",
    parameters: { type: "object", properties: {} },
    async execute() { return { content: [{ type: "text", text: "fixture" }], details: undefined }; },
  });
  pi.registerCommand("token-config-check", {
    description: "Check native resource filtering without contacting a provider",
    handler: async (_args, ctx) => {
      const prompt = ctx.getSystemPrompt();
      if (prompt.includes("BUNDLED_LOOKUP_MUST_NOT_LOAD")) throw new Error("Bundled skill was not excluded");
      if (!prompt.includes("Verify uncertain or version-sensitive library APIs")) throw new Error("Local skill missing");
      if (!pi.getAllTools().some(tool => tool.name === "fixture_docs")) throw new Error("Package tools missing");
      if (!pi.getCommands().some(command => command.name === "c7-docs")) throw new Error("Explicit prompt missing");
    },
  });
}
''')

    # Drive the fixture and local mode commands through a real, isolated Pi over RPC.
    settings_path.write_text(json.dumps({"packages": [context7]}))
    source_policy = (ROOT / "permissions/config.json").read_bytes()
    process = subprocess.Popen(
        ["pi", "--offline", "--mode", "rpc", "--no-session"], cwd=temp, text=True,
        env={**os.environ, "PI_CODING_AGENT_DIR": str(agent)},
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    )
    assert process.stdin is not None and process.stdout is not None and process.stderr is not None

    def command(message):
        assert process.stdin is not None and process.stdout is not None and process.stderr is not None
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
        assert command("/token-config-check") == policy, "Resource inspection must not change permissions"
        print("Resources: targeted documentation skill, excluded bundled skill, retained tools and explicit prompt")
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
