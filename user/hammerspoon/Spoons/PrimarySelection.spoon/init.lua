--- === PrimarySelection ===
---
--- Linux/X11-style "primary selection" for macOS: highlighting text stashes it
--- in a private buffer, middle-click inserts it elsewhere.
---
--- The buffer is a plain Lua value -- it is NOT a pasteboard. The general
--- pasteboard (Cmd+C / Cmd+V) is never read, written, or restored at any point,
--- so this cannot clobber or race with your real clipboard.
---
--- Selections are read via the Accessibility API (AXSelectedText) and inserted
--- by synthesizing keystrokes, so no copy/paste keys are ever simulated either.
---
--- App support depends entirely on what each app exposes to the Accessibility
--- API:
---   * Native Cocoa apps (TextEdit, Mail, ...) -- work out of the box.
---   * iTerm2 -- works; implements accessibilitySelectedText unconditionally.
---   * Alacritty -- does NOT work; GPU-rendered with no accessibility tree.
---   * Chromium browsers -- page content only works if the browser was LAUNCHED
---     with --force-renderer-accessibility. That flag is fixed at process
---     start and cannot be applied to an already-running browser. See the
---     chrome-acc.app wrapper. Browser chrome (address bar) works regardless.
---
--- Use :setDebug(true) and :dumpTree() when onboarding a new app.

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "PrimarySelection"
obj.version = "1.0"
obj.author = "cjordan"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- PrimarySelection.excludedBundleIDs
--- Variable
--- Table of bundle IDs where middle-click keeps its native meaning instead of
--- pasting the primary selection. Empty by default: middle-click pastes
--- everywhere, including browsers.
---
--- Trade-off: in a browser this replaces middle-click "open link in new tab"
--- (and middle-click autoscroll) with paste, matching X11 behaviour. Add a
--- bundle ID here to opt an app back out, e.g.
---   spoon.PrimarySelection.excludedBundleIDs["com.google.Chrome"] = true
obj.excludedBundleIDs = {}

--- PrimarySelection.chromiumBundleIDs
--- Variable
--- Chromium-based browsers. These get a best-effort AXEnhancedUserInterface
--- write (Chromium's lazy opt-in path for building its accessibility tree).
--- Note this is unreliable on its own -- Chrome tears the tree back down --
--- which is why the launch flag above is the real fix.
obj.chromiumBundleIDs = {
    ["com.google.Chrome"] = true,
    ["com.google.Chrome.canary"] = true,
    ["com.brave.Browser"] = true,
    ["com.vivaldi.Vivaldi"] = true,
    ["org.chromium.Chromium"] = true,
    ["com.microsoft.edgemac"] = true,
}

--- PrimarySelection.captureDelay
--- Variable
--- Seconds to wait after mouse-up before reading the selection. An app's
--- accessibility tree updates asynchronously, so reading instantly can miss a
--- fast highlight-and-release.
obj.captureDelay = 0.1

--- PrimarySelection.searchDepth
--- Variable
--- How deep to walk an app's accessibility tree when searching for content.
obj.searchDepth = 12

obj.debug = false
obj.buffer = nil

local function dbg(self, ...)
    if self.debug then print(...) end
end

--------------------------------------------------------------------------------
-- Internal helpers
--------------------------------------------------------------------------------

function obj:_ensureChromiumAccessibility(app)
    if not app then return end
    local bundleID = app:bundleID()
    if not bundleID or not self.chromiumBundleIDs[bundleID] then return end
    local appElement = hs.axuielement.applicationElement(app)
    if not appElement then return end
    local ok = pcall(function() appElement:setAttributeValue("AXEnhancedUserInterface", true) end)
    dbg(self, "chromium a11y nudge: " .. bundleID .. " ok=" .. tostring(ok))
end

-- Find the first descendant with a given AXRole. Used to locate the page
-- content root (AXWebArea) so the selection search never touches browser
-- chrome like the address bar, which caches a stale AXSelectedText long after
-- focus has moved away.
local function findElementByRole(element, role, depth)
    if not element or depth <= 0 then return nil end

    local ok, r = pcall(function() return element:attributeValue("AXRole") end)
    if ok and r == role then return element end

    local ok2, children = pcall(function() return element:attributeValue("AXChildren") end)
    if ok2 and children then
        for _, child in ipairs(children) do
            local found = findElementByRole(child, role, depth - 1)
            if found then return found end
        end
    end
    return nil
end

-- Recursively find a descendant reporting non-empty AXSelectedText. Needed
-- because plain, non-editable text (a paragraph on a webpage) never becomes
-- "focused" -- AXFocusedUIElement only reflects keyboard focus, so it cannot
-- see that kind of selection at all.
local function findSelectedTextInTree(element, depth)
    if not element or depth <= 0 then return nil end

    local ok, text = pcall(function() return element:attributeValue("AXSelectedText") end)
    if ok and text and text ~= "" then return text end

    local ok2, children = pcall(function() return element:attributeValue("AXChildren") end)
    if ok2 and children then
        for _, child in ipairs(children) do
            local found = findSelectedTextInTree(child, depth - 1)
            if found then return found end
        end
    end
    return nil
end

function obj:_capture(isRetry)
    self:_ensureChromiumAccessibility(hs.application.frontmostApplication())

    -- Fast path: the focused element. Correct for real text fields (TextEdit,
    -- iTerm2, address/search bars).
    local ok, focused = pcall(function()
        return hs.axuielement.systemWideElement():attributeValue("AXFocusedUIElement")
    end)
    dbg(self, "capture: focused=" .. tostring(focused))
    if ok and focused then
        local ok2, text = pcall(function() return focused:attributeValue("AXSelectedText") end)
        dbg(self, "capture: focused text=" .. tostring(text))
        if ok2 and text and text ~= "" then
            self.buffer = text
            return
        end
    end

    -- Fallback: walk the page content root for a non-focused selection.
    local win = hs.window.focusedWindow()
    if not win then return end
    local ok3, windowElement = pcall(hs.axuielement.windowElement, win)
    if not (ok3 and windowElement) then return end

    local webArea = findElementByRole(windowElement, "AXWebArea", self.searchDepth)
    dbg(self, "capture: webArea=" .. tostring(webArea) .. " isRetry=" .. tostring(isRetry))
    if not webArea then
        if not isRetry then
            dbg(self, "capture: no AXWebArea yet, retrying once")
            hs.timer.doAfter(0.25, function() self:_capture(true) end)
        else
            dbg(self, "capture: no selection (no AXWebArea after retry)")
        end
        return
    end

    local text = findSelectedTextInTree(webArea, self.searchDepth)
    dbg(self, "capture: webArea text=" .. tostring(text))
    if text and text ~= "" then
        self.buffer = text
    end
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- PrimarySelection:paste()
--- Method
--- Types the current primary selection at the caret.
function obj:paste()
    if not self.buffer or self.buffer == "" then
        hs.alert.show("primary selection is empty")
        return self
    end
    hs.eventtap.keyStrokes(self.buffer)
    return self
end

--- PrimarySelection:currentSelection()
--- Method
--- Returns the current buffer contents (and prints it, for console use).
function obj:currentSelection()
    print("primary selection = " .. tostring(self.buffer))
    return self.buffer
end

--- PrimarySelection:setDebug(enabled)
--- Method
--- Toggles diagnostic logging to the Hammerspoon console at runtime.
function obj:setDebug(enabled)
    self.debug = (enabled ~= false)
    print("PrimarySelection.debug = " .. tostring(self.debug))
    return self
end

--- PrimarySelection:dumpTree([maxDepth], [maxChildren])
--- Method
--- Dumps the focused window's AXRole tree, annotating any node that reports
--- non-empty AXSelectedText. Use this when onboarding a new app: if no content
--- roles appear at all, the app exposes no usable accessibility tree and
--- cannot work with this Spoon.
function obj:dumpTree(maxDepth, maxChildren)
    maxDepth = maxDepth or 6
    maxChildren = maxChildren or 6

    local win = hs.window.focusedWindow()
    if not win then print("dumpTree: no focused window") return self end
    local ok, element = pcall(hs.axuielement.windowElement, win)
    if not (ok and element) then print("dumpTree: no AX element for window") return self end

    print("---- " .. tostring(win:title()) .. " ----")
    local function walk(el, depth, prefix)
        if not el or depth > maxDepth then return end
        local okRole, role = pcall(function() return el:attributeValue("AXRole") end)
        local okSel, sel = pcall(function() return el:attributeValue("AXSelectedText") end)
        local suffix = (okSel and sel and sel ~= "") and ("  <- AXSelectedText: " .. sel) or ""
        print(prefix .. (okRole and tostring(role) or "ERR") .. suffix)

        local okKids, children = pcall(function() return el:attributeValue("AXChildren") end)
        if okKids and children then
            for i, child in ipairs(children) do
                if i > maxChildren then
                    print(prefix .. "  ...(" .. (#children - maxChildren) .. " more)")
                    break
                end
                walk(child, depth + 1, prefix .. "  ")
            end
        end
    end
    walk(element, 0, "")
    print("-------------------")
    return self
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

--- PrimarySelection:start()
--- Method
--- Starts the selection and middle-click watchers.
function obj:start()
    self:stop()

    -- macOS auto-disables a CGEventTap if its callback is ever slow to return,
    -- and does not restart it. So watch for the disable events and restart.
    -- The capture itself is deferred out of the callback entirely, both to
    -- keep the tap fast and to let the app's a11y bridge catch up.
    self._selectionWatcher = hs.eventtap.new({
        hs.eventtap.event.types.leftMouseUp,
        hs.eventtap.event.types.tapDisabledByTimeout,
        hs.eventtap.event.types.tapDisabledByUserInput,
    }, function(event)
        local eventType = event:getType()
        if eventType == hs.eventtap.event.types.tapDisabledByTimeout
            or eventType == hs.eventtap.event.types.tapDisabledByUserInput then
            dbg(self, "selection watcher disabled, restarting")
            self._selectionWatcher:start()
            return false
        end
        hs.timer.doAfter(self.captureDelay, function() self:_capture(false) end)
        return false -- never swallow; must not interfere with normal clicking
    end)
    self._selectionWatcher:start()

    self._pasteWatcher = hs.eventtap.new({ hs.eventtap.event.types.otherMouseDown }, function(event)
        local button = event:getProperty(hs.eventtap.event.properties.mouseEventButtonNumber)
        if button ~= 2 then return false end -- middle button only

        local frontApp = hs.application.frontmostApplication()
        if frontApp and self.excludedBundleIDs[frontApp:bundleID()] then
            return false -- let browsers handle middle-click natively
        end

        if not self.buffer or self.buffer == "" then
            return false -- nothing to paste; don't swallow the click
        end

        local clickPoint = event:location()
        hs.eventtap.leftClick(clickPoint) -- move the caret to the click location
        hs.timer.doAfter(0.05, function() self:paste() end)

        return true -- swallow so nothing else double-handles it
    end)
    self._pasteWatcher:start()

    return self
end

--- PrimarySelection:stop()
--- Method
--- Stops the watchers.
function obj:stop()
    if self._selectionWatcher then
        self._selectionWatcher:stop()
        self._selectionWatcher = nil
    end
    if self._pasteWatcher then
        self._pasteWatcher:stop()
        self._pasteWatcher = nil
    end
    return self
end

--- PrimarySelection:bindHotkeys(mapping)
--- Method
--- Binds hotkeys. Supported action: "paste".
--- e.g. :bindHotkeys({ paste = {{"cmd", "alt"}, "v"} })
function obj:bindHotkeys(mapping)
    local spec = {
        paste = hs.fnutils.partial(self.paste, self),
    }
    hs.spoons.bindHotkeysToSpec(spec, mapping)
    return self
end

return obj
