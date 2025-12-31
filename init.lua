-- =============================================================================
-- FLUTTER DEVELOPER SIMULATOR FOR HAMMERSPOON
-- =============================================================================
-- Simulates a real human Flutter developer on macOS
-- Focus: VS Code (Dart/Flutter), Chrome (ChatGPT), Terminal usage
--
-- FEATURES:
-- ✓ Loops forever with finite-state machine
-- ✓ Never leaves permanent changes (undo-based typing)
-- ✓ Feels human (reading > typing)
-- ✓ Hotkey to start/stop with alerts (Cmd+Ctrl+Shift+F)
-- ✓ Console logging for each activity
--
-- ACTIVITY DISTRIBUTION:
-- VS Code (Flutter/Dart): 70%
-- Chrome (ChatGPT tab): 15%
-- Cursor-only thinking: 7%
-- VS Code terminal: 5%
-- Spotlight / OS actions: 3%
-- =============================================================================

-- Configuration
local CONFIG = {
  -- Timing (in seconds)
  MIN_READ_TIME = 2.0,   -- Minimum reading pause
  MAX_READ_TIME = 6.0,   -- Maximum reading pause
  MIN_TYPE_DELAY = 0.05, -- Minimum delay between keystrokes
  MAX_TYPE_DELAY = 0.20, -- Maximum delay between keystrokes
  THINK_PAUSE_MIN = 1.0, -- Minimum thinking pause
  THINK_PAUSE_MAX = 4.0, -- Maximum thinking pause

  -- Apps
  VSCODE_BUNDLE = "com.microsoft.VSCode",
  CHROME_BUNDLE = "com.google.Chrome",

  -- State machine weights (probability out of 100)
  WEIGHTS = {
    VSCODE_READ = 40,    -- VS Code reading + cursor
    VSCODE_TAB = 25,     -- VS Code tab switching
    CHROME_CHATGPT = 20, -- Chrome ChatGPT scrolling
    CURSOR_THINK = 10,   -- Cursor-only thinking
    IDLE_PAUSE = 5,      -- Random idle pause
  },
}

-- =============================================================================
-- STATE MANAGEMENT
-- =============================================================================

local State = {
  running = false,
  stepTimer = nil,
  typeTimer = nil,
  undoCount = 0,
  actionCount = 0,
}

-- =============================================================================
-- LOGGING
-- =============================================================================

local function log(message)
  print("[FlutterSim] " .. os.date("%H:%M:%S") .. " - " .. message)
end

local function logActivity(activity)
  State.actionCount = State.actionCount + 1
  log(string.format("#%d ▶ %s", State.actionCount, activity))
end

-- =============================================================================
-- UTILITY FUNCTIONS
-- =============================================================================

-- Random float between min and max
local function randomFloat(min, max)
  return min + math.random() * (max - min)
end

-- Random integer between min and max (inclusive)
local function randomInt(min, max)
  return math.random(min, max)
end

-- Weighted random selection
local function weightedRandom()
  local total = 0
  for _, weight in pairs(CONFIG.WEIGHTS) do
    total = total + weight
  end

  local roll = math.random(1, total)
  local cumulative = 0

  local actions = {
    { name = "VSCODE_READ",    weight = CONFIG.WEIGHTS.VSCODE_READ },
    { name = "VSCODE_TAB",     weight = CONFIG.WEIGHTS.VSCODE_TAB },
    { name = "CHROME_CHATGPT", weight = CONFIG.WEIGHTS.CHROME_CHATGPT },
    { name = "CURSOR_THINK",   weight = CONFIG.WEIGHTS.CURSOR_THINK },
    { name = "IDLE_PAUSE",     weight = CONFIG.WEIGHTS.IDLE_PAUSE },
  }

  for _, action in ipairs(actions) do
    cumulative = cumulative + action.weight
    if roll <= cumulative then
      return action.name
    end
  end

  return "VSCODE_READ" -- Default fallback
end

-- Human-like delay
local function humanDelay()
  return randomFloat(CONFIG.MIN_READ_TIME, CONFIG.MAX_READ_TIME)
end

-- Short delay for quick actions
local function shortDelay()
  return randomFloat(0.3, 1.0)
end

-- Thinking delay
local function thinkDelay()
  return randomFloat(CONFIG.THINK_PAUSE_MIN, CONFIG.THINK_PAUSE_MAX)
end

-- Cancel all timers safely
local function cancelTimers()
  if State.stepTimer then
    State.stepTimer:stop()
    State.stepTimer = nil
  end
  if State.typeTimer then
    State.typeTimer:stop()
    State.typeTimer = nil
  end
end

-- =============================================================================
-- APP MANAGEMENT
-- =============================================================================

-- Focus VS Code
local function focusVSCode()
  local app = hs.application.get(CONFIG.VSCODE_BUNDLE)
  if app then
    app:activate()
    return true
  else
    -- Try to launch VS Code
    hs.application.launchOrFocusByBundleID(CONFIG.VSCODE_BUNDLE)
    hs.timer.usleep(500000) -- Wait 500ms
    return hs.application.get(CONFIG.VSCODE_BUNDLE) ~= nil
  end
end

-- Focus Chrome
local function focusChrome()
  local app = hs.application.get(CONFIG.CHROME_BUNDLE)
  if app then
    app:activate()
    return true
  else
    hs.application.launchOrFocusByBundleID(CONFIG.CHROME_BUNDLE)
    hs.timer.usleep(500000)
    return hs.application.get(CONFIG.CHROME_BUNDLE) ~= nil
  end
end

-- =============================================================================
-- KEYBOARD & MOUSE SIMULATION
-- =============================================================================

-- Type a single key with modifiers
local function pressKey(key, modifiers)
  modifiers = modifiers or {}
  hs.eventtap.keyStroke(modifiers, key, 50000) -- 50ms delay
end

-- Type a string character by character with human-like delays
local function typeString(str, callback)
  local chars = {}
  for i = 1, #str do
    table.insert(chars, str:sub(i, i))
  end

  local index = 1
  State.undoCount = #chars -- Track for undo

  local function typeNext()
    if not State.running then
      if callback then callback() end
      return
    end

    if index <= #chars then
      local char = chars[index]
      hs.eventtap.keyStrokes(char)
      index = index + 1

      local delay = randomFloat(CONFIG.MIN_TYPE_DELAY, CONFIG.MAX_TYPE_DELAY)
      State.typeTimer = hs.timer.doAfter(delay, typeNext)
    else
      if callback then callback() end
    end
  end

  typeNext()
end

-- Undo typed text (Cmd+Z multiple times)
local function undoTyping(count, callback)
  local remaining = count or State.undoCount

  local function undoNext()
    if not State.running then
      if callback then callback() end
      return
    end

    if remaining > 0 then
      pressKey("z", { "cmd" })
      remaining = remaining - 1
      State.typeTimer = hs.timer.doAfter(0.05, undoNext)
    else
      State.undoCount = 0
      if callback then callback() end
    end
  end

  undoNext()
end

-- Move cursor with arrow keys
local function moveCursor(direction, times)
  times = times or 1
  for _ = 1, times do
    pressKey(direction)
    hs.timer.usleep(30000) -- 30ms between moves
  end
end

-- Simulate mouse movement (subtle jitter)
local function jitterMouse()
  local pos = hs.mouse.absolutePosition()
  local jitterX = randomInt(-5, 5)
  local jitterY = randomInt(-3, 3)
  hs.mouse.absolutePosition({
    x = pos.x + jitterX,
    y = pos.y + jitterY
  })
end

-- Scroll in current app
local function scroll(direction, amount)
  amount = amount or randomInt(2, 5)
  local delta = direction == "down" and -amount or amount
  hs.eventtap.scrollWheel({ 0, delta }, {})
end

-- =============================================================================
-- SIMULATION ACTIONS
-- =============================================================================

-- VS Code: Read and move cursor
local function actionVSCodeRead(callback)
  logActivity("VS Code: Reading & cursor movement")

  if not focusVSCode() then
    log("  ✗ Failed to focus VS Code")
    if callback then callback() end
    return
  end

  -- Primary cursor movements simulating reading code line by line
  local actions = randomInt(8, 18)

  local function doAction(remaining)
    if not State.running or remaining <= 0 then
      if callback then callback() end
      return
    end

    -- 90% cursor movement, 10% occasional scroll
    if math.random() < 0.9 then
      -- Cursor movement - reading code line by line
      local movementTypes = {
        -- Line by line reading (most common)
        function()
          local lines = randomInt(1, 3)
          moveCursor("down", lines)
          log(string.format("  ↓ Reading %d line(s) down", lines))
        end,
        -- Jump across lines (scanning)
        function()
          local lines = randomInt(4, 8)
          moveCursor("down", lines)
          log("  ⇣ Jumping down through code")
        end,
        -- Scroll back up (re-reading)
        function()
          local lines = randomInt(1, 4)
          moveCursor("up", lines)
          log("  ↑ Re-reading previous lines")
        end,
        -- Move across line (reading code horizontally)
        function()
          local chars = randomInt(3, 12)
          moveCursor("right", chars)
          log("  → Reading across line")
        end,
        -- Jump to start of line
        function()
          pressKey("a", { "ctrl" })
          log("  ⇤ Jump to line start")
        end,
        -- Jump to end of line
        function()
          pressKey("e", { "ctrl" })
          log("  ⇥ Jump to line end")
        end,
        -- Word-by-word navigation
        function()
          local words = randomInt(1, 4)
          for _ = 1, words do
            pressKey("right", { "alt" })
            hs.timer.usleep(50000)
          end
          log(string.format("  ⇨ Jump %d word(s)", words))
        end,
      }

      -- Weight: 60% line reading, 40% other movements
      local choice
      if math.random() < 0.6 then
        choice = movementTypes[1] -- Line by line reading
      else
        choice = movementTypes[randomInt(1, #movementTypes)]
      end

      choice()
    else
      -- Occasional slow scroll (rarely used in code reading)
      local direction = math.random() < 0.8 and "down" or "up"
      scroll(direction, randomInt(2, 4))
      log("  🖱 Scroll " .. direction)
    end

    jitterMouse()

    -- Slower, more human pace
    local delay = randomFloat(0.8, 2.5)
    State.stepTimer = hs.timer.doAfter(delay, function()
      doAction(remaining - 1)
    end)
  end

  doAction(actions)
end

-- VS Code: Switch tabs
local function actionVSCodeTab(callback)
  logActivity("VS Code: Switching between files")

  if not focusVSCode() then
    log("  ✗ Failed to focus VS Code")
    if callback then callback() end
    return
  end

  -- Switch tabs multiple times (like looking for something)
  local switches = randomInt(2, 5)

  local function doSwitch(remaining)
    if not State.running or remaining <= 0 then
      if callback then callback() end
      return
    end

    -- Randomly switch tabs (Ctrl+Tab or Cmd+Shift+[ / ])
    local tabActions = {
      function()
        pressKey("tab", { "ctrl" })
        log("  → Next tab (Ctrl+Tab)")
      end,
      function()
        pressKey("tab", { "ctrl", "shift" })
        log("  → Previous tab (Ctrl+Shift+Tab)")
      end,
      function()
        pressKey("[", { "cmd", "shift" })
        log("  → Previous file (Cmd+Shift+[)")
      end,
      function()
        pressKey("]", { "cmd", "shift" })
        log("  → Next file (Cmd+Shift+])")
      end,
    }

    local action = tabActions[randomInt(1, #tabActions)]
    action()

    -- Pause to "look at" the new file
    local delay = randomFloat(2.0, 4.5)
    State.stepTimer = hs.timer.doAfter(delay, function()
      doSwitch(remaining - 1)
    end)
  end

  doSwitch(switches)
end

-- VS Code: Type Dart code and undo
local function actionVSCodeType(callback)
  logActivity("VS Code: Typing Dart code (will undo)")

  if not focusVSCode() then
    log("  ✗ Failed to focus VS Code")
    if callback then callback() end
    return
  end

  -- Sample Dart/Flutter code snippets to type
  local snippets = {
    "// TODO: Implement feature",
    "setState(() {});",
    "final data = await fetch();",
    "Widget build(BuildContext context) {",
    "const EdgeInsets.all(16.0),",
    "print('Debug: $value');",
    "if (mounted) {",
    "return Container(",
    "// FIXME: Handle edge case",
    "await Future.delayed(Duration(seconds: 1));",
    "class MyWidget extends StatefulWidget {",
    "final List<String> items = [];",
  }

  local snippet = snippets[randomInt(1, #snippets)]

  -- Type the snippet
  typeString(snippet, function()
    -- Pause to "look at" what was typed
    State.stepTimer = hs.timer.doAfter(randomFloat(0.5, 1.5), function()
      -- Undo everything (never leave permanent changes)
      undoTyping(#snippet, callback)
    end)
  end)
end

-- VS Code: Search with Cmd+F
local function actionVSCodeSearch(callback)
  logActivity("VS Code: Search (Cmd+F)")

  if not focusVSCode() then
    log("  ✗ Failed to focus VS Code")
    if callback then callback() end
    return
  end

  -- Open search
  pressKey("f", { "cmd" })

  State.stepTimer = hs.timer.doAfter(0.3, function()
    if not State.running then
      pressKey("escape")
      if callback then callback() end
      return
    end

    -- Search terms common in Flutter
    local searchTerms = {
      "Widget",
      "setState",
      "build",
      "initState",
      "dispose",
      "context",
      "async",
      "await",
      "final",
      "const",
      "import",
      "class",
    }

    local term = searchTerms[randomInt(1, #searchTerms)]

    typeString(term, function()
      -- Navigate through results
      State.stepTimer = hs.timer.doAfter(shortDelay(), function()
        if State.running then
          -- Press Enter to go to next result a few times
          for _ = 1, randomInt(1, 3) do
            pressKey("return")
            hs.timer.usleep(200000)
          end
        end

        -- Close search
        State.stepTimer = hs.timer.doAfter(shortDelay(), function()
          pressKey("escape")
          if callback then callback() end
        end)
      end)
    end)
  end)
end

-- VS Code: Terminal interaction
local function actionVSCodeTerminal(callback)
  logActivity("VS Code: Terminal (fake command)")

  if not focusVSCode() then
    log("  ✗ Failed to focus VS Code")
    if callback then callback() end
    return
  end

  -- Toggle terminal (Ctrl+`)
  pressKey("`", { "ctrl" })

  State.stepTimer = hs.timer.doAfter(0.5, function()
    if not State.running then
      pressKey("`", { "ctrl" }) -- Close terminal
      if callback then callback() end
      return
    end

    -- Fake terminal commands
    local commands = {
      "flutter run",
      "flutter build ios",
      "dart analyze",
      "flutter pub get",
      "flutter test",
      "flutter clean",
      "dart fix --apply",
    }

    local cmd = commands[randomInt(1, #commands)]

    typeString(cmd, function()
      -- Cancel before executing (Ctrl+C or Escape)
      State.stepTimer = hs.timer.doAfter(randomFloat(0.3, 0.8), function()
        pressKey("c", { "ctrl" }) -- Cancel

        -- Clear the line
        State.stepTimer = hs.timer.doAfter(0.2, function()
          pressKey("u", { "ctrl" }) -- Clear line

          -- Close terminal
          State.stepTimer = hs.timer.doAfter(shortDelay(), function()
            pressKey("`", { "ctrl" })
            if callback then callback() end
          end)
        end)
      end)
    end)
  end)
end

-- Chrome: ChatGPT tab interaction (scrolling/reading)
local function actionChromeChatGPT(callback)
  logActivity("Chrome ChatGPT: Reading responses")

  if not focusChrome() then
    log("  ✗ Failed to focus Chrome")
    if callback then callback() end
    return
  end

  State.stepTimer = hs.timer.doAfter(0.3, function()
    if not State.running then
      if callback then callback() end
      return
    end

    -- Scroll through the page (reading ChatGPT conversation)
    local scrollActions = randomInt(3, 7)

    local function doScroll(remaining)
      if not State.running or remaining <= 0 then
        if callback then callback() end
        return
      end

      local direction = math.random() < 0.7 and "down" or "up"
      scroll(direction, randomInt(2, 6))
      jitterMouse()

      State.stepTimer = hs.timer.doAfter(randomFloat(1.0, 2.5), function()
        doScroll(remaining - 1)
      end)
    end

    doScroll(scrollActions)
  end)
end

-- Chrome: ChatGPT typing prompt
local function actionChromeChatGPTType(callback)
  logActivity("Chrome ChatGPT: Typing prompt")

  if not focusChrome() then
    log("  ✗ Failed to focus Chrome")
    if callback then callback() end
    return
  end

  State.stepTimer = hs.timer.doAfter(0.3, function()
    if not State.running then
      if callback then callback() end
      return
    end

    -- Flutter/Dart related prompts for ChatGPT
    local prompts = {
      "How do I implement a custom painter in Flutter?",
      "What's the best way to handle state in Flutter?",
      "Explain Flutter widget lifecycle methods",
      "How to optimize Flutter app performance?",
      "Show me how to use Provider pattern in Flutter",
      "What's the difference between StatefulWidget and StatelessWidget?",
      "How to handle async operations in Flutter?",
      "Best practices for Flutter folder structure",
      "How do I create custom animations in Flutter?",
      "Explain Flutter's build context",
    }

    local prompt = prompts[randomInt(1, #prompts)]

    -- Click in the text area (simulate clicking at bottom of screen where input is)
    local screen = hs.screen.mainScreen():frame()
    hs.mouse.absolutePosition({ x = screen.w / 2, y = screen.h - 150 })
    hs.eventtap.leftClick(hs.mouse.absolutePosition())

    State.stepTimer = hs.timer.doAfter(0.3, function()
      if not State.running then
        if callback then callback() end
        return
      end

      -- Type the prompt
      typeString(prompt, function()
        -- Pause to review what was typed
        State.stepTimer = hs.timer.doAfter(randomFloat(0.5, 1.2), function()
          if not State.running then
            if callback then callback() end
            return
          end

          -- Submit the prompt (press Enter)
          pressKey("return")
          log("  ✓ Submitted ChatGPT prompt")

          -- Wait for response (simulate ChatGPT thinking/responding)
          local waitTime = randomFloat(3.0, 8.0)
          log(string.format("  ⏳ Waiting %.1fs for ChatGPT response...", waitTime))

          State.stepTimer = hs.timer.doAfter(waitTime, function()
            if not State.running then
              if callback then callback() end
              return
            end

            log("  📖 Reading ChatGPT response...")

            -- Scroll through the response like reading it
            local scrollActions = randomInt(4, 10)

            local function doScroll(remaining)
              if not State.running or remaining <= 0 then
                if callback then callback() end
                return
              end

              -- Mostly scroll down (reading), occasionally up (re-reading)
              local direction = math.random() < 0.85 and "down" or "up"
              scroll(direction, randomInt(2, 5))
              jitterMouse()

              local delay = randomFloat(1.5, 3.5)
              State.stepTimer = hs.timer.doAfter(delay, function()
                doScroll(remaining - 1)
              end)
            end

            doScroll(scrollActions)
          end)
        end)
      end)
    end)
  end)
end

-- Chrome: Web search
local function actionChromeSearch(callback)
  logActivity("Chrome: Web search")

  if not focusChrome() then
    log("  ✗ Failed to focus Chrome")
    if callback then callback() end
    return
  end

  -- Focus address bar (Cmd+L)
  pressKey("l", { "cmd" })

  State.stepTimer = hs.timer.doAfter(0.4, function()
    if not State.running then
      pressKey("escape")
      if callback then callback() end
      return
    end

    -- Flutter/development related searches
    local searches = {
      "flutter documentation",
      "dart language guide",
      "flutter packages",
      "flutter error handling",
      "flutter best practices",
      "dart async await",
      "flutter widget catalog",
      "flutter state management",
    }

    local search = searches[randomInt(1, #searches)]

    typeString(search, function()
      -- Pause then cancel (don't actually search)
      State.stepTimer = hs.timer.doAfter(randomFloat(0.5, 1.5), function()
        pressKey("escape")
        if callback then callback() end
      end)
    end)
  end)
end

-- Cursor-only thinking (just mouse movement)
local function actionCursorThink(callback)
  logActivity("Thinking: Mouse movement only")

  local movements = randomInt(5, 12)

  local function doJitter(remaining)
    if not State.running or remaining <= 0 then
      if callback then callback() end
      return
    end

    -- Larger movements simulating looking around screen
    local pos = hs.mouse.absolutePosition()
    local screen = hs.screen.mainScreen():frame()

    local newX = math.max(0, math.min(screen.w, pos.x + randomInt(-50, 50)))
    local newY = math.max(0, math.min(screen.h, pos.y + randomInt(-30, 30)))

    hs.mouse.absolutePosition({ x = newX, y = newY })

    State.stepTimer = hs.timer.doAfter(randomFloat(0.2, 0.8), function()
      doJitter(remaining - 1)
    end)
  end

  doJitter(movements)
end

-- Spotlight search (quick open and cancel)
local function actionSpotlight(callback)
  logActivity("Spotlight: Quick search")

  -- Open Spotlight
  pressKey("space", { "cmd" })

  State.stepTimer = hs.timer.doAfter(0.5, function()
    if not State.running then
      pressKey("escape")
      if callback then callback() end
      return
    end

    -- Type a search term
    local searches = {
      "flutter",
      "terminal",
      "vscode",
      "chrome",
      "notes",
    }

    local term = searches[randomInt(1, #searches)]

    typeString(term, function()
      -- Cancel without opening
      State.stepTimer = hs.timer.doAfter(randomFloat(0.5, 1.5), function()
        pressKey("escape")
        if callback then callback() end
      end)
    end)
  end)
end

-- Idle pause (just wait)
local function actionIdlePause(callback)
  logActivity("Idle: Thinking pause")

  local pauseTime = thinkDelay()
  jitterMouse()
  State.stepTimer = hs.timer.doAfter(pauseTime, function()
    if callback then callback() end
  end)
end

-- =============================================================================
-- MAIN STATE MACHINE
-- =============================================================================

local function scheduleNextAction()
  if not State.running then
    return
  end

  cancelTimers()

  local action = weightedRandom()
  local callback = function()
    -- Add reading/thinking delay between actions
    if State.running then
      local delay = humanDelay()
      log(string.format("  ⏳ Next action in %.1fs", delay))
      State.stepTimer = hs.timer.doAfter(delay, scheduleNextAction)
    end
  end

  -- Execute the selected action
  if action == "VSCODE_READ" then
    actionVSCodeRead(callback)
  elseif action == "VSCODE_TAB" then
    actionVSCodeTab(callback)
  elseif action == "CHROME_CHATGPT" then
    actionChromeChatGPT(callback)
  elseif action == "CURSOR_THINK" then
    actionCursorThink(callback)
  elseif action == "IDLE_PAUSE" then
    actionIdlePause(callback)
  else
    -- Fallback to reading
    actionVSCodeRead(callback)
  end
end

-- =============================================================================
-- START / STOP CONTROLS
-- =============================================================================

local function startSimulator()
  if State.running then
    hs.alert.show("🔄 Simulator already running!", 2)
    log("Already running - ignoring start request")
    return
  end

  State.running = true
  State.actionCount = 0

  log("========================================")
  log("🚀 FLUTTER DEV SIMULATOR STARTED")
  log("========================================")
  log("Press Cmd+Ctrl+Shift+F to stop")
  log("")

  hs.alert.show("▶️ Flutter Dev Simulator STARTED\n\nPress Cmd+Ctrl+Shift+F to stop", 3)

  -- Begin the state machine after a short delay
  State.stepTimer = hs.timer.doAfter(1.0, scheduleNextAction)
end

local function stopSimulator()
  if not State.running then
    hs.alert.show("⚠️ Simulator not running!", 2)
    log("Not running - ignoring stop request")
    return
  end

  State.running = false
  cancelTimers()
  State.undoCount = 0

  log("")
  log("========================================")
  log("⏹️ FLUTTER DEV SIMULATOR STOPPED")
  log("Total actions performed: " .. State.actionCount)
  log("========================================")

  hs.alert.show("⏹️ Flutter Dev Simulator STOPPED\n\nActions: " .. State.actionCount, 3)
end

local function toggleSimulator()
  if State.running then
    stopSimulator()
  else
    startSimulator()
  end
end

-- =============================================================================
-- INITIALIZATION
-- =============================================================================

-- Seed random number generator
math.randomseed(os.time())

-- Bind hotkey: Cmd+Ctrl+Shift+F
hs.hotkey.bind({ "cmd", "ctrl", "shift" }, "F", toggleSimulator)

-- Startup notification
log("========================================")
log("🎮 FLUTTER DEV SIMULATOR LOADED")
log("========================================")
log("Hotkey: Cmd+Ctrl+Shift+F to toggle")
log("")

hs.alert.show("🎮 Flutter Dev Simulator Ready!\n\nPress Cmd+Ctrl+Shift+F to toggle", 3)

-- =============================================================================
-- CONSOLE COMMANDS (for debugging)
-- =============================================================================

-- You can call these from Hammerspoon console:
-- startFlutterSim()
-- stopFlutterSim()
-- toggleFlutterSim()

function startFlutterSim()
  startSimulator()
end

function stopFlutterSim()
  stopSimulator()
end

function toggleFlutterSim()
  toggleSimulator()
end

-- Export for potential module use
return {
  start = startSimulator,
  stop = stopSimulator,
  toggle = toggleSimulator,
  config = CONFIG,
}
