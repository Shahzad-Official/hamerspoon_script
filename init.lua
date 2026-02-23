-- =============================================================================
-- FLUTTER DEVELOPER SIMULATOR FOR HAMMERSPOON
-- =============================================================================
-- luacheck: globals hs
---@diagnostic disable: undefined-global
-- Simulates a real human Flutter developer on macOS
-- Focus: VS Code (Dart/Flutter) and Chrome (ChatGPT)
--
-- FEATURES:
-- ✓ Loops forever with finite-state machine
-- ✓ Feels human (reading/scanning-focused pacing)
-- ✓ Hotkey to start/stop with alerts (Cmd+Ctrl+Shift+F)
-- ✓ Console logging for each activity
--
-- ACTIVITY DISTRIBUTION:
-- VS Code read: 40%
-- VS Code tab switch: 25%
-- Chrome ChatGPT read: 20%
-- Cursor-only thinking: 10%
-- Idle pause: 5%
-- =============================================================================

-- Configuration
local CONFIG = {
  -- Timing (in seconds)
  MIN_READ_TIME = 2.0,   -- Minimum reading pause
  MAX_READ_TIME = 6.0,   -- Maximum reading pause
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

-- Scroll using short bursts with micro-pauses to look more human
local function naturalScrollBurst(direction, ticksMin, ticksMax)
  local ticks = randomInt(ticksMin or 2, ticksMax or 4)
  for _ = 1, ticks do
    scroll(direction, randomInt(1, 2))
    hs.timer.usleep(randomInt(120000, 260000))
  end
  return ticks
end

-- Read line-by-line using arrow keys at a human pace
local function lineByLineRead(direction, minLines, maxLines)
  local lines = randomInt(minLines or 2, maxLines or 5)
  for _ = 1, lines do
    pressKey(direction)
    hs.timer.usleep(randomInt(160000, 340000))
  end
  return lines
end

-- Switch to next open editor tab in VS Code
local function switchToNextVSCodeTab()
  pressKey("]", { "cmd", "shift" })
  hs.timer.usleep(randomInt(300000, 700000))
end

-- =============================================================================
-- SIMULATION ACTIONS
-- =============================================================================

-- VS Code: Cycle through files and perform down/up natural scroll reading
local function actionVSCodeFileCycle(callback, label)
  logActivity(label or "VS Code: File cycle (next tab + read down/up)")

  if not focusVSCode() then
    log("  ✗ Failed to focus VS Code")
    if callback then callback() end
    return
  end

  local function maybeCursorScan(direction)
    local roll = math.random()
    if roll < 0.74 then
      local lines = lineByLineRead(direction, 2, 5)
      log(string.format("  %s Line-by-line read %d line(s)", direction == "down" and "↓" or "↑", lines))
    elseif roll < 0.90 then
      local chars = randomInt(4, 12)
      local horizontalDirection = math.random() < 0.85 and "right" or "left"
      moveCursor(horizontalDirection, chars)
      log(string.format("  %s Horizontal scan", horizontalDirection == "right" and "→" or "←"))
    end
  end

  -- Keep a rough local drift count so the reverse phase can compensate.
  local drift = 0
  local downBursts = randomInt(5, 8)
  local upBursts = downBursts + randomInt(1, 3)

  -- Move to next file tab first, then start from top.
  switchToNextVSCodeTab()
  log("  ⇥ Switched to next open file tab")
  pressKey("up", { "cmd" })
  hs.timer.usleep(randomInt(300000, 650000))

  local function finishCycle()
    if not State.running then
      if callback then callback() end
      return
    end

    -- If still net-down, force additional reverse reading.
    if drift > 3 then
      local extra = math.min(drift, randomInt(5, 10))
      local ticks = naturalScrollBurst("up", extra, extra + 2)
      drift = drift - ticks
      local lines = lineByLineRead("up", 2, 4)
      drift = drift - math.floor(lines / 2)
      jitterMouse()
      log("  ↺ Extra reverse scroll to complete re-read")
    end

    if callback then callback() end
  end

  local doUp
  local function doDown(remaining)
    if not State.running then
      if callback then callback() end
      return
    end

    if remaining <= 0 then
      -- Anchor to bottom before reverse pass, then scroll back up naturally.
      pressKey("down", { "cmd" })
      hs.timer.usleep(randomInt(300000, 650000))
      log("  ↓ Reached file bottom, starting reverse read")
      State.stepTimer = hs.timer.doAfter(randomFloat(0.8, 1.6), function()
        doUp(upBursts)
      end)
      return
    end

    local ticks = naturalScrollBurst("down", 2, 4)
    drift = drift + ticks
    jitterMouse()
    maybeCursorScan("down")
    log(string.format("  ↓ Natural read down (%d ticks)", ticks))

    State.stepTimer = hs.timer.doAfter(randomFloat(0.9, 2.1), function()
      doDown(remaining - 1)
    end)
  end

  doUp = function(remaining)
    if not State.running then
      if callback then callback() end
      return
    end

    if remaining <= 0 then
      finishCycle()
      return
    end

    local ticks = naturalScrollBurst("up", 2, 4)
    drift = drift - ticks
    jitterMouse()
    maybeCursorScan("up")
    log(string.format("  ↑ Natural reverse read up (%d ticks)", ticks))

    State.stepTimer = hs.timer.doAfter(randomFloat(0.9, 2.1), function()
      doUp(remaining - 1)
    end)
  end

  log("  ↓ Starting top → bottom read")
  doDown(downBursts)
end

local function actionVSCodeRead(callback)
  actionVSCodeFileCycle(callback, "VS Code: File cycle read")
end

-- VS Code: Keep same deterministic file-cycle flow
local function actionVSCodeTab(callback)
  actionVSCodeFileCycle(callback, "VS Code: Next file cycle")
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

-- Export for potential module use
return {
  start = startSimulator,
  stop = stopSimulator,
  toggle = toggleSimulator,
  config = CONFIG,
}
