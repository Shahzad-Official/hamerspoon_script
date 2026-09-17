-- =============================================================================
-- FLUTTER DEVELOPER SIMULATOR FOR HAMMERSPOON
-- =============================================================================
-- luacheck: globals hs
---@diagnostic disable: undefined-global
-- Simulates a real human Flutter developer on macOS
-- Focus: VS Code (Dart/Flutter) only
--
-- FEATURES:
-- ✓ Loops forever with finite-state machine
-- ✓ Feels human (reading/scanning-focused pacing)
-- ✓ Hotkey to start/stop with alerts (Cmd+Ctrl+Shift+F)
-- ✓ Console logging for each activity
--
-- ACTIVITY DISTRIBUTION:
-- VS Code read: 60%
-- VS Code tab switch: 25%
-- Cursor-only thinking: 10%
-- Idle pause: 5%
-- =============================================================================

-- Configuration
local CONFIG = {
  -- Timing (in seconds)
  -- Keep the gaps short enough for a sustained medium/high activity level.
  MIN_READ_TIME = 1.00,
  MAX_READ_TIME = 1.80,
  THINK_PAUSE_MIN = 0.80,
  THINK_PAUSE_MAX = 1.40,
  READ_STEP_MIN = 1.00,
  READ_STEP_MAX = 1.80,
  MOUSE_STEP_MIN = 0.45,
  MOUSE_STEP_MAX = 0.90,
  KEYBOARD_FREE_PAUSE_MIN = 2.00,       -- Quiet gap between outer activity bursts
  KEYBOARD_FREE_PAUSE_MAX = 3.00,

  -- Repeating five-minute keyboard schedule
  ACTIVITY_WINDOW_SECONDS = 5 * 60,
  NO_TYPING_START_SECONDS = 30,        -- No keyboard events at window start
  TYPING_PHASE_MIN_SECONDS = 2 * 60,
  TYPING_PHASE_MAX_SECONDS = 3 * 60,
  NO_TYPING_END_SECONDS = 30,          -- Keep this much time keyboard-free at the end
  TYPING_CYCLE_MIN_SECONDS = 50,
  TYPING_CYCLE_MAX_SECONDS = 60,
  TYPE_DELETE_GAP_MIN_SECONDS = 0.65,
  TYPE_DELETE_GAP_MAX_SECONDS = 0.90,

  -- Apps
  VSCODE_BUNDLE = "com.microsoft.VSCode",

  -- State machine weights (probability out of 100)
  WEIGHTS = {
    VSCODE_READ = 60,    -- VS Code reading + cursor
    VSCODE_TAB = 25,     -- VS Code tab switching
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
  startedAt = nil,
  windowIndex = -1,
  typingPhaseStartAt = nil,
  typingPhaseEndAt = nil,
  typingPhaseDuration = nil,
  typingFocusWindowIndex = -1,
  typingCycleEndAt = nil,
  typingCycleIndex = 0,
  scrollCount = 0,
  typingActive = false,
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

-- Monotonic elapsed time in seconds, so the cutoff is unaffected by clock
-- changes. This also matches Hammerspoon's timer behavior across sleep.
local function monotonicSeconds()
  return hs.timer.absoluteTime() / 1000000000
end

local function elapsedSinceStart()
  if not State.startedAt then
    return 0
  end
  return monotonicSeconds() - State.startedAt
end

-- Refresh the keyboard phase for the current five-minute window. The state
-- machine calls this before every action, and the input guard calls it before
-- every key event, so a phase boundary cannot be crossed by a long action.
local function updateTypingPhase()
  if not State.running or not State.startedAt then
    State.typingActive = false
    return
  end

  local elapsed = elapsedSinceStart()
  local windowIndex = math.floor(elapsed / CONFIG.ACTIVITY_WINDOW_SECONDS)
  local windowOffset = elapsed % CONFIG.ACTIVITY_WINDOW_SECONDS

  if windowIndex ~= State.windowIndex then
    State.windowIndex = windowIndex

    local maxDuration = math.min(
      CONFIG.TYPING_PHASE_MAX_SECONDS,
      CONFIG.ACTIVITY_WINDOW_SECONDS
        - CONFIG.NO_TYPING_START_SECONDS
        - CONFIG.NO_TYPING_END_SECONDS
    )
    local minDuration = math.min(CONFIG.TYPING_PHASE_MIN_SECONDS, maxDuration)

    State.typingPhaseDuration = randomFloat(minDuration, maxDuration)
    State.typingPhaseStartAt = State.startedAt
      + (windowIndex * CONFIG.ACTIVITY_WINDOW_SECONDS)
      + CONFIG.NO_TYPING_START_SECONDS
    State.typingPhaseEndAt = State.typingPhaseStartAt + State.typingPhaseDuration
    State.typingCycleEndAt = nil
    State.typingCycleIndex = 0

    log(string.format(
      "🕔 Five-minute window #%d: keyboard phase %.0f–%.0fs",
      windowIndex + 1,
      CONFIG.NO_TYPING_START_SECONDS,
      CONFIG.NO_TYPING_START_SECONDS + State.typingPhaseDuration
    ))
  end

  local wasActive = State.typingActive
  State.typingActive = windowOffset >= CONFIG.NO_TYPING_START_SECONDS
    and windowOffset < (CONFIG.NO_TYPING_START_SECONDS + State.typingPhaseDuration)

  if State.typingActive and not wasActive then
    log("⌨️ Keyboard phase started")
  elseif wasActive and not State.typingActive then
    log("🖱️ Keyboard phase ended; mouse/scroll activity only")
  end
end

local function typingWindowOpen()
  if not State.running then
    return false
  end

  updateTypingPhase()
  return State.typingActive
end

local function noteScroll()
  State.scrollCount = State.scrollCount + 1
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
    { name = "VSCODE_READ",  weight = CONFIG.WEIGHTS.VSCODE_READ },
    { name = "VSCODE_TAB",   weight = CONFIG.WEIGHTS.VSCODE_TAB },
    { name = "CURSOR_THINK", weight = CONFIG.WEIGHTS.CURSOR_THINK },
    { name = "IDLE_PAUSE",   weight = CONFIG.WEIGHTS.IDLE_PAUSE },
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

-- =============================================================================
-- KEYBOARD & MOUSE SIMULATION
-- =============================================================================

-- Type a single key with modifiers. typingKey is true only for the isolated
-- type/delete loop; navigation and tab-switch keys are blocked during it.
local function pressKey(key, modifiers, typingKey)
  -- Keyboard input is allowed only during the active phase of the current
  -- five-minute window.
  if not typingWindowOpen() then
    return false
  end

  if not typingKey then
    return false
  end

  -- keyStroke's delay is in microseconds. Leave enough time for the full
  -- key-down/key-up pair to finish before the phase boundary.
  if not State.typingPhaseEndAt
      or State.typingPhaseEndAt - monotonicSeconds() <= 0.05 then
    return false
  end

  modifiers = modifiers or {}
  hs.eventtap.keyStroke(modifiers, key, 50000) -- 50ms delay
  return true
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
local function postMouseMove(point)
  -- Do not let a keyboard-phase action leak mouse events into the editor.
  if typingWindowOpen() then
    return false
  end

  -- Warp alone does not reliably create an input event for activity monitors.
  -- Post an explicit mouseMoved event, then keep the cursor position in sync.
  hs.eventtap.event.newMouseEvent(
    hs.eventtap.event.types.mouseMoved,
    point
  ):post()
  return true
end

local function jitterMouse()
  local pos = hs.mouse.absolutePosition()
  local jitterX = randomInt(-5, 5)
  local jitterY = randomInt(-3, 3)
  postMouseMove({
    x = pos.x + jitterX,
    y = pos.y + jitterY
  })
end

-- Scroll in current app
local function scroll(direction, amount)
  -- The typing phase is intentionally exclusive: no scrolls while a typed
  -- character is waiting to be removed.
  if typingWindowOpen() then
    return false
  end

  amount = amount or randomInt(2, 5)
  local delta = direction == "down" and -amount or amount
  hs.eventtap.scrollWheel({ 0, delta }, {})
  noteScroll()
  return true
end

-- Scroll using short bursts with micro-pauses to look more human
local function naturalScrollBurst(direction, ticksMin, ticksMax)
  local ticks = randomInt(ticksMin or 2, ticksMax or 4)
  for _ = 1, ticks do
    scroll(direction, randomInt(1, 2))
    hs.timer.usleep(randomInt(180000, 320000))
  end
  return ticks
end

-- Read line-by-line using arrow keys at a human pace
local function lineByLineRead(direction, minLines, maxLines)
  local lines = randomInt(minLines or 2, maxLines or 5)
  for _ = 1, lines do
    pressKey(direction)
    hs.timer.usleep(randomInt(180000, 360000))
  end
  return lines
end

-- Switch to next open editor tab in VS Code
local function switchToNextVSCodeTab()
  pressKey("]", { "cmd", "shift" })
  hs.timer.usleep(randomInt(300000, 600000))
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

    updateTypingPhase()
    if State.typingActive then
      log("  ⌨️ Keyboard phase started; switching to type/delete loop")
      if callback then callback() end
      return
    end

    if remaining <= 0 then
      -- Anchor to bottom before reverse pass, then scroll back up naturally.
      pressKey("down", { "cmd" })
      hs.timer.usleep(randomInt(300000, 600000))
      log("  ↓ Reached file bottom, starting reverse read")
      State.stepTimer = hs.timer.doAfter(randomFloat(0.75, 1.30), function()
        doUp(upBursts)
      end)
      return
    end

    local ticks = naturalScrollBurst("down", 2, 4)
    drift = drift + ticks
    jitterMouse()
    maybeCursorScan("down")
    log(string.format("  ↓ Natural read down (%d ticks)", ticks))

    if State.typingActive then
      log("  ⌨️ Keyboard phase started; switching to type/delete loop")
      if callback then callback() end
      return
    end

    State.stepTimer = hs.timer.doAfter(randomFloat(CONFIG.READ_STEP_MIN, CONFIG.READ_STEP_MAX), function()
      doDown(remaining - 1)
    end)
  end

  doUp = function(remaining)
    if not State.running then
      if callback then callback() end
      return
    end

    updateTypingPhase()
    if State.typingActive then
      log("  ⌨️ Keyboard phase started; switching to type/delete loop")
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

    if State.typingActive then
      log("  ⌨️ Keyboard phase started; switching to type/delete loop")
      if callback then callback() end
      return
    end

    State.stepTimer = hs.timer.doAfter(randomFloat(CONFIG.READ_STEP_MIN, CONFIG.READ_STEP_MAX), function()
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

    postMouseMove({ x = newX, y = newY })

    State.stepTimer = hs.timer.doAfter(randomFloat(CONFIG.MOUSE_STEP_MIN, CONFIG.MOUSE_STEP_MAX), function()
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

-- Type and immediately remove random strings for one 50–60 second cycle.
-- The cycle boundary saves the clean file and switches tabs before typing
-- resumes on the next file.
local function actionRandomTypeDelete(callback)
  if State.typingFocusWindowIndex ~= State.windowIndex then
    if not focusVSCode() then
      log("  ✗ Could not focus VS Code; skipping typing burst")
      if callback then callback() end
      return
    end
    State.typingFocusWindowIndex = State.windowIndex
  end

  logActivity("Typing: Random characters + immediate removal")

  local characters = "abcdefghijklmnopqrstuvwxyz0123456789"
  local now = monotonicSeconds()
  if not State.typingCycleEndAt or now >= State.typingCycleEndAt then
    State.typingCycleIndex = State.typingCycleIndex + 1
    State.typingCycleEndAt = now + randomFloat(
      CONFIG.TYPING_CYCLE_MIN_SECONDS,
      CONFIG.TYPING_CYCLE_MAX_SECONDS
    )
    log(string.format(
      "  🔁 Typing cycle #%d: %ds–%ds before save + tab switch",
      State.typingCycleIndex,
      CONFIG.TYPING_CYCLE_MIN_SECONDS,
      CONFIG.TYPING_CYCLE_MAX_SECONDS
    ))
  end

  local function finishTypingCycle()
    if not State.running or not typingWindowOpen() then
      if callback then callback() end
      return
    end

    log("  💾 Typing cycle complete; saving clean file")
    pressKey("s", { "cmd" }, true)
    hs.timer.usleep(randomInt(350000, 600000))

    if typingWindowOpen() then
      log("  ⇥ Switching to next VS Code tab")
      pressKey("]", { "cmd", "shift" }, true)
      hs.timer.usleep(randomInt(450000, 750000))
    end

    State.typingCycleEndAt = nil
    if callback then callback() end
  end

  local function nextPair()
    if not State.running or not typingWindowOpen() then
      if callback then callback() end
      return
    end

    -- Leave a small margin for the type/delete pair before the cycle
    -- transition, so the boundary never leaves a character behind.
    if State.typingCycleEndAt - monotonicSeconds() <= 0.25 then
      finishTypingCycle()
      return
    end

    local index = randomInt(1, #characters)
    local character = string.sub(characters, index, index)

    -- Guard both sides of the short pause so neither event crosses the cutoff.
    if not pressKey(character, nil, true) then
      if callback then callback() end
      return
    end

    local pendingCharacter = true
    hs.timer.usleep(randomInt(70000, 130000))

    if not typingWindowOpen() then
      -- The character was inserted but the phase closed during the short
      -- pause. Remove it immediately before any other simulator event can
      -- occur, even though the normal typing guard is now closed.
      hs.eventtap.keyStroke({}, "delete", 50000)
      pendingCharacter = false
      log("  🧹 Removed pending character at keyboard-phase boundary")
      if callback then callback() end
      return
    end

    if not pressKey("delete", nil, true) and pendingCharacter then
      hs.eventtap.keyStroke({}, "delete", 50000)
    end
    pendingCharacter = false

    if State.typingCycleEndAt - monotonicSeconds() <= 0.25 then
      finishTypingCycle()
    else
      State.stepTimer = hs.timer.doAfter(randomFloat(
        CONFIG.TYPE_DELETE_GAP_MIN_SECONDS,
        CONFIG.TYPE_DELETE_GAP_MAX_SECONDS
      ), nextPair)
    end
  end

  nextPair()
end

local function scheduleKeyboardFreePause(callback)
  local pause = randomFloat(
    CONFIG.KEYBOARD_FREE_PAUSE_MIN,
    CONFIG.KEYBOARD_FREE_PAUSE_MAX
  )
  log(string.format("  💤 Keyboard-free pause for %.1fs", pause))
  State.stepTimer = hs.timer.doAfter(pause, callback)
end

-- Keep the opening and closing parts of every window active without sending
-- keyboard events. Short bursts plus quiet gaps keep the five-minute average
-- below a continuously-active 100% pattern.
local function actionKeyboardFreeScroll(callback)
  logActivity("Keyboard-free: Scroll + mouse burst")

  local ticks = naturalScrollBurst(
    math.random() < 0.8 and "down" or "up",
    3,
    5
  )

  local movements = randomInt(3, 5)
  for _ = 1, movements do
    jitterMouse()
    hs.timer.usleep(randomInt(250000, 500000))
  end

  log(string.format("  ↕ Scroll burst: %d tick(s)", ticks))

  scheduleKeyboardFreePause(callback)
end

local function actionKeyboardFreeMouse(callback)
  logActivity("Keyboard-free: Mouse movement burst")

  local movements = randomInt(4, 7)
  local function doJitter(remaining)
    if not State.running then
      return
    end

    if remaining <= 0 then
      scheduleKeyboardFreePause(callback)
      return
    end

    jitterMouse()
    State.stepTimer = hs.timer.doAfter(
      randomFloat(CONFIG.MOUSE_STEP_MIN, CONFIG.MOUSE_STEP_MAX),
      function()
        doJitter(remaining - 1)
      end
    )
  end

  doJitter(movements)
end

-- =============================================================================
-- MAIN STATE MACHINE
-- =============================================================================

local function scheduleNextAction()
  if not State.running then
    return
  end

  -- Refresh the repeating five-minute phase before choosing the next action.
  updateTypingPhase()

  cancelTimers()
  local callback = function()
    -- Re-check here because a timer callback can run just after a phase
    -- boundary.
    updateTypingPhase()
    if State.running then
      scheduleNextAction()
    end
  end

  if State.typingActive then
    actionRandomTypeDelete(callback)
    return
  end

  -- Outside the typing phase, use only mouse/scroll bursts. No keyboard
  -- action is scheduled here.
  if math.random() < 0.6 then
    actionKeyboardFreeScroll(callback)
  else
    actionKeyboardFreeMouse(callback)
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
  State.startedAt = monotonicSeconds()
  State.windowIndex = -1
  State.typingPhaseStartAt = nil
  State.typingPhaseEndAt = nil
  State.typingPhaseDuration = nil
  State.typingFocusWindowIndex = -1
  State.typingCycleEndAt = nil
  State.typingCycleIndex = 0
  State.scrollCount = 0
  State.typingActive = false

  log("========================================")
  log("🚀 FLUTTER DEV SIMULATOR STARTED")
  log("========================================")
  log("Press Cmd+Ctrl+Shift+F to stop")
  log("Keyboard schedule: 30s off → 2–3m on → keyboard-free remainder")
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
