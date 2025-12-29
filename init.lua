--------------------------------------------------
-- Human-like activity simulator (macOS)
-- Pauses on real user input, resumes after 5s idle
-- Rectified + hardened version
--------------------------------------------------

math.randomseed(os.time())

--------------------------------------------------
-- CONFIG
--------------------------------------------------
local IDLE_SECONDS = 5
local SELF_EVENT_GRACE_MS = 500 -- Short grace period to avoid blocking user
local AUTO_REVERT_DELAY = 0.8   -- Fast revert to avoid conflicts (0.8s)

-- SEQUENTIAL FLOW CONFIG
local STEP_DELAYS = {
  COMMENT_DURATION = 5,   -- Step 1: Type comments for 5 seconds
  WAIT_BEFORE_CURSOR = 5, -- Step 2: Wait 5 seconds before cursor movement
  CURSOR_DURATION = 6,    -- Step 2: Move cursor/resize for 6 seconds average
  SEARCH_DELAY = 2,       -- Step 3: Delay before search
  TAB_CHANGE_DELAY = 2,   -- Step 4: Delay before tab change
  FINAL_CURSOR_DELAY = 2, -- Step 5: Final cursor movement delay
}

--------------------------------------------------
-- STATE
--------------------------------------------------
local activityTimer = nil
local resumeTimer = nil
local isPausedByUser = false
local lastSimulationTime = 0

-- Sequential flow state
local currentStep = 1
local stepStartTime = 0
local activeTimers = {} -- Track all active timers

--------------------------------------------------
-- TIME (MONOTONIC)
--------------------------------------------------
local function nowMs()
  return hs.timer.secondsSinceEpoch() * 1000
end

--------------------------------------------------
-- TYPING HELPERS
--------------------------------------------------


-- Browser search queries for developers (Flutter-focused)
local browserSearches = {
  "flutter widgets catalog", "flutter state management", "dart async programming",
  "flutter bloc pattern", "flutter riverpod tutorial", "dart null safety",
  "flutter responsive design", "firebase flutter integration", "flutter animations",
  "stackoverflow flutter", "flutter pub packages", "flutter dio http",
  "nestjs documentation", "nestjs typeorm relations", "nestjs jwt authentication",
  "docker nestjs production", "nestjs swagger setup", "nestjs middleware"
}



-- Generic code comments for VS Code
local codeComments = {
  "// TODO: Add null safety check",
  "// FIXME: Handle async state properly",
  "// TODO: Implement error boundary",
  "// NOTE: Widget rebuild optimization needed",
  "// TODO: Add loading state",
  "// FIXME: Memory leak in stream subscription",
  "// TODO: Extract reusable widget",
  "// NOTE: Consider using const constructor",
  "// TODO: Add input validation",
  "// FIXME: Dispose controllers properly",
  "// TODO: Implement state management",
  "// NOTE: Move to separate file",
  "// TODO: Add accessibility labels",
  "// FIXME: Handle navigation back press",
  "// TODO: Optimize build method",
  "// NOTE: Consider using ListView.builder",
  "// TODO: Add error handling for API call",
  "// FIXME: Update deprecated widget",
  "// TODO: Implement dependency injection",
  "// NOTE: Cache network images",
  "// TODO: Add unit tests for business logic",
  "// FIXME: Fix widget overflow issue",
  "// TODO: Implement proper form validation",
  "// NOTE: Use MediaQuery for responsive layout",
  "// TODO: Add localization support",
  "// FIXME: Handle keyboard dismiss",
  "// TODO: Optimize StatefulWidget lifecycle",
  "// NOTE: Consider using FutureBuilder",
  "// TODO: Add permission handling",
  "// FIXME: Prevent duplicate API calls"
}

--------------------------------------------------
-- TYPING HELPERS
--------------------------------------------------
local function simulateTyping(text)
  for i = 1, #text do
    local char = text:sub(i, i)
    -- Faster typing for more activity counts
    local delay = 30000
    if char:match("[%p%d]") then
      delay = math.random(40000, 80000) -- Faster for punctuation/numbers
    else
      delay = math.random(20000, 60000) -- Faster for letters
    end
    hs.timer.usleep(delay)
    hs.eventtap.keyStrokes(char)

    -- Less frequent pauses for more consistent activity
    if math.random() > 0.95 and i < #text then
      hs.timer.usleep(math.random(150000, 300000)) -- Shorter pauses
    end
  end
end

-- Function to add comment in code
local function addCodeComment()
  if isPausedByUser then return end

  local comment = codeComments[math.random(1, #codeComments)]

  -- Mark simulation time before keyboard actions
  lastSimulationTime = nowMs()

  -- Go to end of current line and add new line
  hs.eventtap.keyStroke({ "cmd" }, "right")
  hs.timer.usleep(30000) -- Faster
  hs.eventtap.keyStroke({}, "return")
  hs.timer.usleep(50000) -- Faster

  -- Type the comment faster (counts as more keystrokes)
  for i = 1, #comment do
    if isPausedByUser then return end
    local char = comment:sub(i, i)
    hs.eventtap.keyStrokes(char)
    hs.timer.usleep(math.random(20000, 40000)) -- Faster typing
  end

  -- Quick undo using Cmd+Z (faster revert)
  hs.timer.doAfter(AUTO_REVERT_DELAY, function()
    if isPausedByUser then return end
    lastSimulationTime = nowMs()

    -- Use Cmd+Z to undo - this works with editor's undo system
    hs.eventtap.keyStroke({ "cmd" }, "z")
    hs.timer.usleep(50000)
    -- Undo again to remove the newline
    hs.eventtap.keyStroke({ "cmd" }, "z")

    -- Add scrolling after undo (simulates reading the code)
    hs.timer.doAfter(0.2, function()
      local scrollAmount = math.random(-20, -5)
      hs.eventtap.scrollWheel({ 0, scrollAmount }, {}, "pixel")

      -- Always scroll back for clean revert
      hs.timer.doAfter(AUTO_REVERT_DELAY, function()
        hs.eventtap.scrollWheel({ 0, -scrollAmount }, {}, "pixel")
      end)
    end)
  end)
end



--------------------------------------------------
-- SEQUENTIAL FLOW FUNCTIONS
--------------------------------------------------

-- Forward declarations
local executeStep1, executeStep2, executeStep3, executeStep4, executeStep5

-- Step 1: Add comments in VS Code for 5 seconds, then undo
executeStep1 = function()
  print("📝 Step 1: Adding comments in VS Code...")
  lastSimulationTime = nowMs()

  local vscode = hs.application.find("Code") or hs.application.find("Visual Studio Code")
  if vscode then
    vscode:activate()
    hs.timer.usleep(500000)

    -- Add 2-3 comments over 5 seconds
    local commentCount = math.random(2, 3)
    for i = 1, commentCount do
      local timer = hs.timer.doAfter((i - 1) * 2, function()
        if not isPausedByUser then
          addCodeComment()
        end
      end)
      table.insert(activeTimers, timer)
    end

    -- Move to next step after duration
    local nextStepTimer = hs.timer.doAfter(STEP_DELAYS.COMMENT_DURATION, function()
      if isPausedByUser then return end
      currentStep = 2
      stepStartTime = os.time()
      executeStep2()
    end)
    table.insert(activeTimers, nextStepTimer)
  else
    -- Skip to next step if VS Code not found
    local skipTimer = hs.timer.doAfter(0.1, function()
      currentStep = 2
      stepStartTime = os.time()
      executeStep2()
    end)
    table.insert(activeTimers, skipTimer)
  end
end

-- Step 2: Wait 5s, then move cursor/resize windows for 5-7s (no typing)
executeStep2 = function()
  print("⏳ Step 2: Waiting, then cursor movements...")
  lastSimulationTime = nowMs()

  -- Wait 5 seconds
  local waitTimer = hs.timer.doAfter(STEP_DELAYS.WAIT_BEFORE_CURSOR, function()
    if isPausedByUser then return end
    lastSimulationTime = nowMs()

    -- Perform cursor movements and window resizing for configured duration
    local duration = STEP_DELAYS.CURSOR_DURATION
    local actionCount = math.random(3, 5)

    for i = 1, actionCount do
      local actionTimer = hs.timer.doAfter((i - 1) * (duration / actionCount), function()
        if isPausedByUser then return end

        local actionType = math.random(1, 3)
        if actionType == 1 then
          -- Smooth cursor movement
          lastSimulationTime = nowMs()
          local start = hs.mouse.absolutePosition()
          local target = {
            x = start.x + math.random(-200, 200),
            y = start.y + math.random(-100, 100)
          }

          local steps = 10
          for j = 1, steps do
            hs.timer.doAfter(0.03 * j, function()
              if isPausedByUser then return end
              lastSimulationTime = nowMs()
              hs.mouse.absolutePosition({
                x = start.x + (target.x - start.x) * (j / steps),
                y = start.y + (target.y - start.y) * (j / steps)
              })
            end)
          end
        elseif actionType == 2 then
          -- Window resize
          lastSimulationTime = nowMs()
          local win = hs.window.focusedWindow()
          if win then
            local f = win:frame()
            local originalFrame = hs.geometry.copy(f)
            f.w = math.max(400, f.w + math.random(-80, 80))
            f.h = math.max(300, f.h + math.random(-60, 60))
            win:setFrame(f, 0.3)

            hs.timer.doAfter(1.5, function()
              if isPausedByUser then return end
              if win and win:isVisible() then
                win:setFrame(originalFrame, 0.3)
              end
            end)
          end
        else
          -- Scroll
          lastSimulationTime = nowMs()
          local scrollAmount = math.random(-25, -10)
          hs.eventtap.scrollWheel({ 0, scrollAmount }, {}, "pixel")
          hs.timer.doAfter(1, function()
            if isPausedByUser then return end
            hs.eventtap.scrollWheel({ 0, -scrollAmount }, {}, "pixel")
          end)
        end
      end)
      table.insert(activeTimers, actionTimer)
    end

    -- Move to step 3 after duration
    local nextStepTimer = hs.timer.doAfter(duration, function()
      if isPausedByUser then return end
      currentStep = 3
      stepStartTime = os.time()
      executeStep3()
    end)
    table.insert(activeTimers, nextStepTimer)
  end)
  table.insert(activeTimers, waitTimer)
end

-- Step 3: Search in Spotlight or Chrome (Flutter/dev related)
executeStep3 = function()
  print("🔍 Step 3: Searching...")
  lastSimulationTime = nowMs()

  local searchTimer = hs.timer.doAfter(STEP_DELAYS.SEARCH_DELAY, function()
    if isPausedByUser then return end
    lastSimulationTime = nowMs()

    local searchType = math.random(1, 2)

    if searchType == 1 then
      -- Spotlight search
      local searchTerms = {
        "flutter widgets", "dart programming", "vs code", "terminal",
        "flutter state management", "firebase flutter", "flutter docs"
      }

      hs.eventtap.keyStroke({ "cmd" }, "space")
      local spotlightTimer1 = hs.timer.doAfter(0.4, function()
        if isPausedByUser then return end
        lastSimulationTime = nowMs()
        local term = searchTerms[math.random(1, #searchTerms)]
        simulateTyping(term)

        local spotlightTimer2 = hs.timer.doAfter(1.5, function()
          if isPausedByUser then return end
          lastSimulationTime = nowMs()
          hs.eventtap.keyStroke({}, "escape")

          -- Move to step 4
          local spotlightTimer3 = hs.timer.doAfter(0.5, function()
            currentStep = 4
            executeStep4()
          end)
          table.insert(activeTimers, spotlightTimer3)
        end)
        table.insert(activeTimers, spotlightTimer2)
      end)
      table.insert(activeTimers, spotlightTimer1)
    else
      -- Chrome/Browser search
      local chrome = hs.application.find("Chrome") or hs.application.find("Google Chrome")
      if chrome then
        chrome:activate()
        hs.timer.usleep(500000)

        -- Open new tab and search
        hs.eventtap.keyStroke({ "cmd" }, "t")
        local chromeTimer1 = hs.timer.doAfter(0.4, function()
          if isPausedByUser then return end
          lastSimulationTime = nowMs()
          local searches = browserSearches
          local searchQuery = searches[math.random(1, #searches)]
          simulateTyping(searchQuery)

          local chromeTimer2 = hs.timer.doAfter(1.5, function()
            if isPausedByUser then return end
            lastSimulationTime = nowMs()
            hs.eventtap.keyStroke({ "cmd" }, "w") -- Close tab

            -- Move to step 4
            local chromeTimer3 = hs.timer.doAfter(0.3, function()
              currentStep = 4
              executeStep4()
            end)
            table.insert(activeTimers, chromeTimer3)
          end)
          table.insert(activeTimers, chromeTimer2)
        end)
        table.insert(activeTimers, chromeTimer1)
      else
        -- Skip to step 4 if Chrome not found
        local skipTimer = hs.timer.doAfter(0.1, function()
          currentStep = 4
          executeStep4()
        end)
        table.insert(activeTimers, skipTimer)
      end
    end
  end)
  table.insert(activeTimers, searchTimer)
end

-- Step 4: Change VS Code tabs (files)
executeStep4 = function()
  print("📑 Step 4: Changing VS Code tabs...")
  lastSimulationTime = nowMs()

  local tabTimer = hs.timer.doAfter(STEP_DELAYS.TAB_CHANGE_DELAY, function()
    if isPausedByUser then return end
    lastSimulationTime = nowMs()

    local vscode = hs.application.find("Code") or hs.application.find("Visual Studio Code")
    if vscode then
      vscode:activate()
      hs.timer.usleep(300000)

      -- Switch between tabs using Ctrl+Tab
      local tabSwitches = math.random(2, 4)
      for i = 1, tabSwitches do
        local tabTimer = hs.timer.doAfter(i * 0.8, function()
          if isPausedByUser then return end
          lastSimulationTime = nowMs()
          hs.eventtap.keyStroke({ "ctrl" }, "tab")
        end)
        table.insert(activeTimers, tabTimer)
      end

      -- Move to step 5
      local nextStepTimer = hs.timer.doAfter(tabSwitches * 0.8 + 0.5, function()
        if isPausedByUser then return end
        currentStep = 5
        executeStep5()
      end)
      table.insert(activeTimers, nextStepTimer)
    else
      -- Skip to step 5 if VS Code not found
      local skipTimer = hs.timer.doAfter(0.1, function()
        currentStep = 5
        executeStep5()
      end)
      table.insert(activeTimers, skipTimer)
    end
  end)
  table.insert(activeTimers, tabTimer)
end

-- Step 5: Move cursor or resize window, then loop back
executeStep5 = function()
  print("🖱️ Step 5: Final cursor movement...")
  lastSimulationTime = nowMs()

  local finalTimer = hs.timer.doAfter(STEP_DELAYS.FINAL_CURSOR_DELAY, function()
    if isPausedByUser then return end
    lastSimulationTime = nowMs()

    -- Final cursor movement or window action
    if math.random() > 0.5 then
      -- Smooth cursor movement
      local start = hs.mouse.absolutePosition()
      local target = {
        x = start.x + math.random(-150, 150),
        y = start.y + math.random(-80, 80)
      }

      local steps = 12
      for i = 1, steps do
        local cursorTimer = hs.timer.doAfter(0.04 * i, function()
          if isPausedByUser then return end
          lastSimulationTime = nowMs()
          hs.mouse.absolutePosition({
            x = start.x + (target.x - start.x) * (i / steps),
            y = start.y + (target.y - start.y) * (i / steps)
          })
        end)
        table.insert(activeTimers, cursorTimer)
      end
    else
      -- Small window adjustment
      lastSimulationTime = nowMs()
      local win = hs.window.focusedWindow()
      if win then
        local f = win:frame()
        local originalFrame = hs.geometry.copy(f)
        f.x = f.x + math.random(-30, 30)
        f.y = f.y + math.random(-20, 20)
        win:setFrame(f, 0.2)

        local revertTimer = hs.timer.doAfter(1, function()
          if win and win:isVisible() then
            win:setFrame(originalFrame, 0.2)
          end
        end)
        table.insert(activeTimers, revertTimer)
      end
    end

    -- Loop back to step 1 after a brief pause - THIS IS THE CONTINUOUS LOOP
    local loopTimer = hs.timer.doAfter(2, function()
      if isPausedByUser then
        print("⏸ Loop cancelled - user is active")
        return
      end
      print("🔁 Looping back to Step 1...")
      currentStep = 1
      stepStartTime = os.time()
      lastSimulationTime = nowMs()
      executeStep1()
    end)
    table.insert(activeTimers, loopTimer)
  end)
  table.insert(activeTimers, finalTimer)
end

--------------------------------------------------
-- MAIN ACTIVITY CONTROLLER
--------------------------------------------------
local function simulateActivity()
  -- Skip if user is active
  if isPausedByUser then
    print("⏸ Skipped - user is active")
    return
  end

  -- Mark this as simulated activity FIRST to prevent self-pause
  lastSimulationTime = nowMs()

  -- Execute current step in the flow
  if currentStep == 1 then
    executeStep1()
  elseif currentStep == 2 then
    executeStep2()
  elseif currentStep == 3 then
    executeStep3()
  elseif currentStep == 4 then
    executeStep4()
  elseif currentStep == 5 then
    executeStep5()
  end
end -- Close simulateActivity function

--------------------------------------------------
-- SCHEDULER (SIMPLIFIED FOR FLOW)
--------------------------------------------------
local function scheduleNext()
  -- Just start the flow - it will handle its own timing
  if currentStep == 1 then
    simulateActivity()
  end
end

--------------------------------------------------
-- START / STOP
--------------------------------------------------
local function startAutomation()
  -- Don't start if manually stopped by user
  if isPausedByUser then
    print("⚠️ Cannot start - manually stopped")
    return
  end

  -- Always clean up any existing timers first (prevents leaks)
  stopAutomation()

  -- Reset to step 1 and start fresh
  currentStep = 1
  stepStartTime = os.time()
  lastSimulationTime = nowMs()

  print("▶️ Automation started")
  hs.alert.show("▶ Sequential automation started", 1)

  -- Start the first step
  scheduleNext()
end

local function stopAutomation()
  -- Stop old activity timer if exists
  if activityTimer then
    activityTimer:stop()
    activityTimer = nil
  end

  -- Stop and clear all active timers (prevents leaks)
  for _, timer in ipairs(activeTimers) do
    if timer and timer:running() then
      timer:stop()
    end
  end
  activeTimers = {}

  -- Note: Don't reset currentStep here to allow inspection
  -- It will be reset when starting fresh
end

--------------------------------------------------
-- USER INPUT DETECTION
--------------------------------------------------
local function onUserInput(event)
  local now = nowMs()
  local timeSinceLastSim = now - lastSimulationTime

  -- Check if this is likely a simulated event (very recent)
  if timeSinceLastSim < 500 then
    return false -- Very recent simulation, likely our own event
  end

  -- Real user input detected - immediately stop everything
  if not isPausedByUser then
    print("⏸ User input detected - pausing automation")
    isPausedByUser = true
    stopAutomation()
  end

  -- Reset the resume timer (always restart the countdown)
  if resumeTimer then
    resumeTimer:stop()
    resumeTimer = nil
  end

  resumeTimer = hs.timer.doAfter(IDLE_SECONDS, function()
    print("⏱️ Idle timeout reached - resuming automation")
    isPausedByUser = false
    startAutomation()
    hs.alert.show("▶ Resumed", 0.5)
  end)

  return false
end

--------------------------------------------------
-- EVENT TAPS
--------------------------------------------------
local userEventTap = hs.eventtap.new(
  {
    hs.eventtap.event.types.mouseMoved,
    hs.eventtap.event.types.leftMouseDown,
    hs.eventtap.event.types.rightMouseDown,
    hs.eventtap.event.types.scrollWheel,
    hs.eventtap.event.types.keyDown,
    hs.eventtap.event.types.flagsChanged -- Detect modifier keys
  },
  function(event)
    onUserInput(event)
    return false -- Don't block the event
  end
)

userEventTap:start()

--------------------------------------------------
-- MANUAL TOGGLE (HOTKEY)
--------------------------------------------------
hs.hotkey.bind({ "cmd", "alt", "ctrl" }, "S", function()
  if isPausedByUser or #activeTimers > 0 then
    -- Force stop everything
    print("🛑 Manual stop - automation disabled")
    isPausedByUser = true
    stopAutomation()

    -- Cancel any pending resume timer
    if resumeTimer then
      resumeTimer:stop()
      resumeTimer = nil
    end

    hs.alert.show("⛔ STOPPED", 1.5)
  else
    -- Start fresh
    print("▶️ Manual start - automation enabled")
    isPausedByUser = false
    startAutomation()
  end
end)

--------------------------------------------------
-- AUTO START
--------------------------------------------------
startAutomation()
