import test from "node:test";
import assert from "node:assert/strict";
import { MODELS, review } from "../extensions/jev-reviewer/core.ts";

const details = (value = "pwd", surface = "bash") => ({
  requestId: "test", payload: {
    request: { surface, toolName: surface, value },
    evidence: [{ label: "full command", text: value, detail: null }],
  },
});
const result = (choice, confidence = 0.99) => ({ stopReason: "stop", answers: { risk: { type: "choice", choice, confidence } } });
// Returns the logged outcome; every case here must end in "defer" unless `expect` says otherwise.
async function run(overrides = {}, expect = "defer") {
  let outcome;
  const verdict = await review({
    details: details(), cwd: "/project", model: MODELS["auto-clef"], classify: async () => result("risky"),
    log: { review(event, value) { assert.equal(event, "jev-reviewer.decision"); outcome = value; } },
    ...overrides,
  });
  assert.deepEqual(verdict, { kind: expect });
  assert.equal(outcome?.verdict ?? "defer", expect);
  return outcome;
}

test("a confident benign label is approved, for commands and edits alike", async () => {
  for (const surface of ["bash", "edit"]) {
    const outcome = await run({ details: details("npm test", surface), classify: async context => {
      assert.equal(context.state.request.value, "npm test");
      return result("benign");
    } }, "allow");
    assert.equal(outcome.reviewer, "cloudflare-workers-ai/@cf/cloudflare/clef");
  }
});
test("risky, unknown, and unconfident benign labels all ask the human", async () => {
  for (const reply of [result("risky"), result("unknown"), result("benign", 0.79)]) {
    const outcome = await run({ details: details("git push --force"), classify: async () => reply });
    assert.equal(outcome.recommendation, reply.answers.risk.choice);
  }
});
test("sensitive-path and outside-project asks never reach the provider or the log", async () => {
  for (const surface of ["path", "path_write", "external_directory", "external_directory_read", null]) {
    const outcome = await run({ details: details("x", surface), classify: () => { throw new Error("should not call"); } });
    assert.equal(outcome, undefined);
  }
});
test("missing facts and oversized requests ask the human before any provider call", async () => {
  const classify = () => { throw new Error("should not call"); };
  assert.equal((await run({ details: details(" "), classify })).reason, "missing-facts");
  assert.equal((await run({ details: details("x".repeat(9000)), classify })).reason, "context-over-budget");
});
test("the log records metadata, never the command or provider messages", async () => {
  const allowed = await run({ details: details("secret-marker"), classify: async () => result("benign") }, "allow");
  assert.ok(!JSON.stringify(allowed).includes("secret-marker"));
  const thrown = await run({ classify: async () => { throw new Error("secret-token-123"); } });
  assert.equal(thrown.reason, "review-failed");
  const billing = await run({ classify: async () => ({ stopReason: "error", errorMessage: "403 customer_verification_required echoed-secret" }) });
  assert.equal(billing.reason, "billing-verification-required");
  const credits = await run({ classify: async () => ({ stopReason: "error", errorMessage: "402 Insufficient balance echoed-secret" }) });
  assert.equal(credits.reason, "paid-credits-required");
  assert.ok(!JSON.stringify([thrown, billing, credits]).includes("secret"));
});
test("provider errors and malformed answers ask the human", async () => {
  assert.equal((await run({ classify: async () => ({ stopReason: "error" }) })).reason, "provider-error");
  for (const reply of [{ stopReason: "stop", answers: {} }, result("safe"), result("benign", NaN)]) {
    assert.equal((await run({ classify: async () => reply })).reason, "invalid-answer");
  }
});
test("timeout and parent abort ask the human even if the provider ignores cancellation", async () => {
  let signal;
  const hang = (_context, s) => { signal = s; return new Promise(() => {}); };
  assert.equal((await run({ timeoutMs: 10, classify: hang })).reason, "timeout");
  assert.equal(signal.aborted, true);
  const controller = new AbortController();
  const pending = run({ signal: controller.signal, classify: hang });
  controller.abort();
  assert.equal((await pending).reason, "aborted");
});
test("a failing log or status update does not change the decision", async () => {
  const broken = { log: { review() { throw new Error("log failed"); } }, onOutcome() { throw new Error("UI failed"); } };
  assert.deepEqual(await review({ details: details(), cwd: "/", model: MODELS["auto-jev"], classify: async () => result("benign"), ...broken }), { kind: "allow" });
  assert.deepEqual(await review({ details: details(), cwd: "/", model: MODELS["auto-jev"], classify: async () => result("risky"), ...broken }), { kind: "defer" });
});
