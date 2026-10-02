import { isAbsolute, relative, resolve, sep } from "node:path";
import { FooterComponent, type ExtensionAPI } from "@earendil-works/pi-coding-agent";

/** Keep Pi's built-in footer (stats, model, permission statuses, etc.).
 * Pi currently has no separate theme tokens for the path and git branch,
 * so decorate only its rendered first line. Restore the method on reload.
 * Installed as a regular file by user/pi/setup.sh; no worktree symlink.
 */
export default function (pi: ExtensionAPI) {
	let restore: (() => void) | undefined;

	pi.on("session_start", (_event, ctx) => {
		if (ctx.mode !== "tui" || restore) return;
		const original = FooterComponent.prototype.render;
		const decorated: typeof original = function (width) {
			const lines = original.call(this, width);
			if (!lines[0]) return lines;

			let cwd = ctx.sessionManager.getCwd();
			const home = process.env.HOME || process.env.USERPROFILE;
			if (home) {
				const rel = relative(resolve(home), resolve(cwd));
				if (rel === "" || (rel !== ".." && !rel.startsWith(`..${sep}`) && !isAbsolute(rel))) {
					cwd = rel ? `~${sep}${rel}` : "~";
				}
			}

			// The built-in first line contains only foreground SGR styling.
			const text = lines[0].replace(/\x1b\[[0-9;]*m/g, "");
			// If truncation cut the path, the ellipsis belongs to the path too.
			const pathLength = text.startsWith(cwd) ? cwd.length : text.length;
			const path = text.slice(0, pathLength);
			let suffix = text.slice(pathLength);
			let branch = "";
			if (suffix.startsWith(" (")) {
				const end = suffix.indexOf(" • ");
				branch = end < 0 ? suffix : suffix.slice(0, end);
				suffix = suffix.slice(branch.length);
			}
			const theme = ctx.ui.theme;
			lines[0] = theme.fg("success", path)
				+ theme.fg("error", branch)
				+ theme.fg("dim", suffix);
			return lines;
		};
		FooterComponent.prototype.render = decorated;
		restore = () => {
			if (FooterComponent.prototype.render === decorated) FooterComponent.prototype.render = original;
			restore = undefined;
		};
	});

	pi.on("session_shutdown", () => restore?.());
}
