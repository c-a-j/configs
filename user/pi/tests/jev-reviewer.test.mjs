import test from "node:test";
import assert from "node:assert/strict";
import { reviewShadow } from "../extensions/jev-reviewer/core.mjs";

const details = (value = "pwd", surface = "bash") => ({
  requestId: "test", payload: {
    request: { surface, toolName: "bash", value },
    evidence: [{ label: "full command", text: value, detail: null }],
  },
});
const result = choice => ({ stopReason: "stop", answers: { risk: { type: "choice", choice, confidence: 0.99 } } });
async function run(overrides = {}) {
  let outcome;
  const verdict = await reviewShadow({
    details: details(), cwd: "/project", classify: async () => result("benign"),
    log: { review(event, value) { assert.equal(event, "jev.shadow"); outcome = value; } },
    ...overrides,
  });
  assert.deepEqual(verdict, { kind: "defer" });
  return outcome;
}

for (const choice of ["benign", "risky", "unknown"]) {
  test(`${choice}, even at high confidence, always defers`, async () => {
    const outcome = await run({ details: details("git push --force"), classify: async context => {
      assert.equal(context.state.request.value, "git push --force");
      return result(choice);
    } });
    assert.equal(outcome.recommendation, choice);
    assert.equal(outcome.reason, "shadow-only");
  });
}
test("asks that are not shell commands never reach the provider or the log", async () => {
  for (const surface of ["path_write", "external_directory", "edit"]) {
    const outcome = await run({ details: details("x", surface), classify: () => { throw new Error("should not call"); } });
    assert.equal(outcome, undefined);
  }
});
test("missing facts and oversized commands defer before the provider call", async () => {
  const classify = () => { throw new Error("should not call"); };
  assert.equal((await run({ details: details(" "), classify })).reason, "missing-facts");
  assert.equal((await run({ details: details("x".repeat(9000)), classify })).reason, "context-over-budget");
});
test("the log records metadata, never the command or provider messages", async () => {
  assert.ok(!JSON.stringify(await run({ details: details("secret-marker") })).includes("secret-marker"));
  const thrown = await run({ classify: async () => { throw new Error("secret-token-123"); } });
  assert.equal(thrown.reason, "review-failed");
  const billing = await run({ classify: async () => ({ stopReason: "error", errorMessage: "403 customer_verification_required echoed-secret" }) });
  assert.equal(billing.reason, "billing-verification-required");
  assert.ok(!JSON.stringify([thrown, billing]).includes("secret"));
});
test("provider errors and malformed answers defer", async () => {
  assert.equal((await run({ classify: async () => ({ stopReason: "error" }) })).reason, "provider-error");
  for (const reply of [{ stopReason: "stop", answers: {} }, result("safe"),
    { stopReason: "stop", answers: { risk: { choice: "benign", confidence: NaN } } }]) {
    assert.equal((await run({ classify: async () => reply })).reason, "invalid-answer");
  }
});
test("timeout and parent abort defer even if the provider ignores cancellation", async () => {
  let signal;
  const hang = (_context, s) => { signal = s; return new Promise(() => {}); };
  assert.equal((await run({ timeoutMs: 10, classify: hang })).reason, "timeout");
  assert.equal(signal.aborted, true);
  const controller = new AbortController();
  const pending = run({ signal: controller.signal, classify: hang });
  controller.abort();
  assert.equal((await pending).reason, "aborted");
});
test("a failing log or status update does not block the human decision", async () => {
  await run({ log: { review() { throw new Error("log failed"); } }, onOutcome() { throw new Error("UI failed"); } });
});
