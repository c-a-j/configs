import { FooterComponent, type ExtensionAPI } from "@earendil-works/pi-coding-agent";

/** Colour the built-in footer's first line: green path, red git branch.
 * Pi has no theme tokens for these, so wrap the built-in render and restyle
 * that one line. Everything else in the footer is Pi's own output.
 */
export default function (pi: ExtensionAPI) {
	let restore: (() => void) | undefined;

	pi.on("session_start", (_event, ctx) => {
		if (ctx.mode !== "tui" || restore) return;
		const original = FooterComponent.prototype.render;
		FooterComponent.prototype.render = function (width) {
			const lines = original.call(this, width);
			// The line is "path[ (branch)][ • session name]" with colour codes only.
			const plain = (lines[0] ?? "").replace(/\x1b\[[0-9;]*m/g, "");
			const [, path, branch = "", rest = ""] = /^(.*?)( \([^)]*\))?( • .*)?$/.exec(plain) ?? [];
			if (path) {
				const theme = ctx.ui.theme;
				lines[0] = theme.fg("success", path) + theme.fg("error", branch) + theme.fg("dim", rest);
			}
			return lines;
		};
		restore = () => {
			FooterComponent.prototype.render = original;
			restore = undefined;
		};
	});

	pi.on("session_shutdown", () => restore?.());
}
