/** Scroll the fullscreen transcript with Ctrl+j/k without changing Insert bindings. */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isKeyRelease, matchesKey, type EditorComponent, type TUI } from "@earendil-works/pi-tui";

type ModalEditor = EditorComponent & { getMode?: () => string };
type ScrollableTUI = TUI & { scrollBy?: (lines: number) => void };

export default function vimScroll(pi: ExtensionAPI) {
  // This lifecycle event runs after every session_start handler, including pi-vim's.
  // Local extensions can load before packages, so session_start would be too early.
  pi.on("resources_discover", (_event, ctx) => {
    if (ctx.mode !== "tui") return;

    const factory = ctx.ui.getEditorComponent();
    if (!factory) return;

    ctx.ui.setEditorComponent((tui, theme, keybindings) => {
      const editor: ModalEditor = factory(tui, theme, keybindings);
      const viewport = tui as ScrollableTUI;
      const handleInput = editor.handleInput?.bind(editor);
      if (!handleInput || typeof editor.getMode !== "function") return editor;

      // Decorate in place to retain pi-vim's callbacks, flags, rendering, and state.
      // Pi supplies a stable TUI reference that follows regular/fullscreen changes.
      editor.handleInput = (data) => {
        if (!isKeyRelease(data) && editor.getMode?.() === "normal" &&
            viewport.mode === "fullscreen" && typeof viewport.scrollBy === "function") {
          const step = Math.max(1, Math.floor(viewport.terminal.rows / 4));
          if (matchesKey(data, "ctrl+j")) {
            viewport.scrollBy(step);
            return;
          }
          if (matchesKey(data, "ctrl+k")) {
            viewport.scrollBy(-step);
            return;
          }
        }
        handleInput(data);
      };
      return editor;
    });
  });
}
