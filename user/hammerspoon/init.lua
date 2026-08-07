-- Linux/X11-style primary selection: highlight to capture, middle-click to
-- insert. Never touches the Cmd+C / Cmd+V pasteboard.
-- Implementation lives in Spoons/PrimarySelection.spoon.
hs.loadSpoon("PrimarySelection")
spoon.PrimarySelection:start()

-- Console helpers:
--   spoon.PrimarySelection:setDebug(true)   -- diagnostics on/off, no reload
--   spoon.PrimarySelection:dumpTree()       -- inspect focused window's AX tree
--   spoon.PrimarySelection:currentSelection()

-- Ctrl+F stands in for Find, matching Windows/Linux, because AeroSpace
-- claims Cmd+F for fullscreen. keyStroke's 4th argument posts the synthetic
-- Cmd+F straight to the app's pid, so AeroSpace's global hotkey never sees
-- it and we don't loop. Terminals are skipped: Ctrl+F is page-forward in
-- vim, and returning false leaves the keypress untouched.
local findRemapSkip = {
    ["com.googlecode.iterm2"] = true,
    ["org.alacritty"] = true,
    ["com.apple.Terminal"] = true,
}

findRemap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(e)
    if not e:getFlags():containExactly({ "ctrl" }) then return false end
    if hs.keycodes.map[e:getKeyCode()] ~= "f" then return false end

    local app = hs.application.frontmostApplication()
    if not app or findRemapSkip[app:bundleID()] then return false end

    hs.eventtap.keyStroke({ "cmd" }, "f", 0, app)
    return true
end)
findRemap:start()
