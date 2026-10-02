#!/usr/bin/env python3
"""Exercise agent wrappers against an isolated tmux server, never the live one."""

import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import unittest


SCRIPTS = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which("tmux"), "tmux is required")
class MouseWrapperTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="tmux-mouse-test-")
        self.root = Path(self.temp.name)
        self.socket = str(self.root / "tmux.sock")
        self.env = os.environ.copy()
        self.env.pop("TMUX", None)
        self.env.pop("TMUX_PANE", None)
        self.env["PATH"] = f"{self.root}:{self.env['PATH']}"
        self.tmux("new-session", "-d", "-s", "agents")
        self.tmux("new-session", "-d", "-s", "other")
        self.tmux("set-option", "-g", "mouse", "on")
        self.env["TMUX"] = f"{self.socket},0,0"
        self.env["TMUX_PANE"] = self.tmux(
            "display-message", "-p", "-t", "agents:0.0", "#{pane_id}"
        ).strip()
        for name in ("claude", "pi"):
            agent = self.root / name
            agent.write_text(
                f"#!{sys.executable}\n"
                "import json, os, signal, subprocess, sys\n"
                "if os.environ.get('TMUX'):\n"
                "    mouse = subprocess.check_output(['tmux', 'display-message', '-p',\n"
                "        '-t', os.environ['TMUX_PANE'], '#{mouse}'], text=True).strip()\n"
                "    assert mouse == '1', mouse\n"
                "print(json.dumps(sys.argv[1:]), flush=True)\n"
                "if os.environ.get('AGENT_SIGNAL'):\n"
                "    os.kill(os.getpid(), int(os.environ['AGENT_SIGNAL']))\n"
                "sys.exit(int(os.environ.get('AGENT_STATUS', '0')))\n"
            )
            agent.chmod(0o755)

    def tearDown(self):
        self.tmux("kill-server", check=False)
        self.temp.cleanup()

    def tmux(self, *args, check=True):
        result = subprocess.run(
            ["tmux", "-S", self.socket, "-f", "/dev/null", *args],
            env=self.env, capture_output=True, text=True, check=check,
        )
        return result.stdout

    def run_wrapper(self, name="run-pi"):
        return subprocess.run(
            ["bash", str(SCRIPTS / name), "argument with spaces", "*"],
            cwd=self.root, env=self.env, capture_output=True, text=True,
            timeout=10,
        )

    def assert_mouse_off(self):
        self.assertEqual(self.tmux("show-option", "-Av", "-t", "agents", "mouse").strip(), "off")
        self.assertEqual(self.tmux("show-option", "-Av", "-t", "other", "mouse").strip(), "on")
        self.assertEqual(self.tmux("show-option", "-gv", "mouse").strip(), "on")

    def test_wrappers_from_unrelated_directory(self):
        for name in ("run-claude", "run-pi"):
            with self.subTest(wrapper=name):
                self.tmux("set-option", "-t", "agents", "mouse", "off")
                result = self.run_wrapper(name)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(json.loads(result.stdout), ["argument with spaces", "*"])
                self.assert_mouse_off()

    def test_nonzero_status_is_preserved(self):
        self.env["AGENT_STATUS"] = "42"
        result = self.run_wrapper()
        self.assertEqual(result.returncode, 42, result.stderr)
        self.assert_mouse_off()

    def test_agent_signals_clean_up(self):
        for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
            with self.subTest(signal=sig):
                self.tmux("set-option", "-t", "agents", "mouse", "on")
                self.env["AGENT_SIGNAL"] = str(sig.value)
                result = self.run_wrapper()
                self.assertEqual(result.returncode, 128 + sig.value, result.stderr)
                self.assert_mouse_off()

    def test_ctrl_c_cleans_up(self):
        process = subprocess.Popen(
            ["bash", "-c", 'source "$1"; with-tmux-mouse bash -c "echo ready; sleep 30"',
             "bash", str(SCRIPTS / "with-tmux-mouse")],
            env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            text=True, start_new_session=True,
        )
        try:
            self.assertEqual(process.stdout.readline().strip(), "ready")
            os.killpg(process.pid, signal.SIGINT)
            _, stderr = process.communicate(timeout=10)
            self.assertEqual(process.returncode, 130, stderr)
            self.assert_mouse_off()
        finally:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGKILL)
                process.communicate()

    def test_missing_agent_cleans_up(self):
        (self.root / "pi").unlink()
        # Invoke a deliberately absent command rather than a live installed Pi.
        result = subprocess.run(
            ["bash", "-c", 'source "$1"; with-tmux-mouse nonexistent-agent-for-mouse-test',
             "bash", str(SCRIPTS / "with-tmux-mouse")],
            env=self.env, capture_output=True, text=True, timeout=10,
        )
        self.assertEqual(result.returncode, 127, result.stderr)
        self.assert_mouse_off()

    def test_outside_tmux_leaves_server_untouched(self):
        self.env.pop("TMUX")
        self.env.pop("TMUX_PANE")
        result = self.run_wrapper()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.tmux("show-option", "-Av", "-t", "agents", "mouse").strip(), "on")


if __name__ == "__main__":
    unittest.main()
