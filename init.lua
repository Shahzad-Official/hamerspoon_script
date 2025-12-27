--------------------------------------------------
-- MAXIMUM ACTIVITY SIMULATOR - Aggressive Mode
-- Generates maximum activity counts
--------------------------------------------------

math.randomseed(os.time())

--------------------------------------------------
-- CONFIG - MAXIMUM FREQUENCY (80-90% Activity)
--------------------------------------------------
local MIN_INTERVAL = 0.2 -- ULTRA fast for 80-90% activity
local MAX_INTERVAL = 0.5 -- ULTRA fast for 80-90% activity
local AUTO_REVERT_DELAY = 0.3 -- Quick revert
local IDLE_SECONDS = 2 -- Pause 2s after real user input, then auto-resume
local SELF_EVENT_GRACE_MS = 1800 -- Shorter grace to be more responsive

--------------------------------------------------
-- STATE
--------------------------------------------------
local activityTimer = nil
local resumeTimer = nil
local isPausedByUser = false
local lastSimulationTime = 0

--------------------------------------------------
-- TIME
--------------------------------------------------
local function nowMs()
  return hs.timer.secondsSinceEpoch() * 1000
end

--------------------------------------------------
-- TEXT SAMPLES (More variety)
--------------------------------------------------
local codeSnippets = {
  "import React from 'react';",
  "const [state, setState] = useState();",
  "async function getData() {",
  "return response.json();",
  "flutter build apk",
  "git commit -m 'update'",
  "npm run dev",
  "class MyWidget extends StatelessWidget {",
  "Widget build(BuildContext context) {",
  "setState(() {",
  "Navigator.push(context,",
  "const response = await fetch(",
  "function handleClick() {",
  "export default App;",
  "docker-compose up -d",
  "// TODO: Fix this",
  "console.log('debug');",
  "await repository.save(",
  "return <div>",
  "for (let i = 0; i < ",
  "if (condition) {",
  "const data = await",
  "try { await",
  "} catch (error) {",
  "import { Component }",
}

local searchTerms = {
  "react hooks",
  "flutter widgets",
  "typescript",
  "git commands",
  "docker tutorial",
  "nestjs api",
  "javascript async",
  "css flexbox",
  "python pandas",
  "vscode shortcuts"
}

--------------------------------------------------
-- TYPING SIMULATION (Faster)
--------------------------------------------------
local function fastType(text)
  for i = 1, #text do
    hs.eventtap.keyStrokes(text:sub(i, i))
    hs.timer.usleep(math.random(10000, 25000)) -- Ultra fast typing
  end
end

local function quickDelete(length)
  hs.eventtap.keyStroke({"cmd"}, "z") -- Undo first
  hs.timer.usleep(20000)
  for i = 1, math.min(length, 80) do
    hs.eventtap.keyStroke({}, "delete")
    if i % 15 == 0 then
      hs.timer.usleep(5000) -- Tiny pause every 15 chars
    end
  end
end

--------------------------------------------------
-- MOUSE MOVEMENT IN ACTIVE APP
--------------------------------------------------
local function smartMouseMove()
  local win = hs.window.focusedWindow()
  if win then
    local frame = win:frame()
    -- Move mouse within the active window
    local targetX = frame.x + math.random(50, frame.w - 50)
    local targetY = frame.y + math.random(50, frame.h - 50)
    
    local currentPos = hs.mouse.absolutePosition()
    local steps = 5
    
    -- Smooth movement
    for i = 1, steps do
      hs.timer.doAfter(0.01 * i, function()
        hs.mouse.absolutePosition({
          x = currentPos.x + (targetX - currentPos.x) * (i / steps),
          y = currentPos.y + (targetY - currentPos.y) * (i / steps)
        })
      end)
    end
    
    -- Revert after delay
    hs.timer.doAfter(AUTO_REVERT_DELAY + 0.1, function()
      hs.mouse.absolutePosition(currentPos)
    end)
  else
    -- Fallback to simple movement
    local pos = hs.mouse.absolutePosition()
    local newPos = {x = pos.x + math.random(-15, 15), y = pos.y + math.random(-15, 15)}
    hs.mouse.absolutePosition(newPos)
    hs.timer.doAfter(AUTO_REVERT_DELAY, function()
      hs.mouse.absolutePosition(pos)
    end)
  end
end

--------------------------------------------------
-- MAIN ACTIVITY FUNCTION (80-90% Activity)
--------------------------------------------------
local function simulateActivity()
  if isPausedByUser then 
    print("⏸ Paused by user")
    return 
  end
  
  -- Mark as simulated to prevent self-pause
  lastSimulationTime = nowMs()
  print("✓ Activity executing...")
  
  -- Random action selection
  local action = math.random(1, 100)
  
  ------------------------------------------------
  -- 1. TYPING (60% - Maximum typing activity)
  ------------------------------------------------
  if action <= 60 then
    lastSimulationTime = nowMs()
    local text = codeSnippets[math.random(1, #codeSnippets)]
    
    fastType(text)
    
    -- Quick revert
    hs.timer.doAfter(AUTO_REVERT_DELAY, function()
      lastSimulationTime = nowMs()
      quickDelete(#text)
    end)
  
  ------------------------------------------------
  -- 2. SCROLLING (20%)
  ------------------------------------------------
  elseif action <= 80 then
    lastSimulationTime = nowMs()
    local amount = math.random(-40, -12)
    hs.eventtap.scrollWheel({ 0, amount }, {}, "pixel")
    
    -- Revert scroll
    hs.timer.doAfter(AUTO_REVERT_DELAY, function()
      lastSimulationTime = nowMs()
      hs.eventtap.scrollWheel({ 0, -amount }, {}, "pixel")
    end)
  
  ------------------------------------------------
  -- 3. WINDOW SWITCHING (12%)
  ------------------------------------------------
  elseif action <= 92 then
    lastSimulationTime = nowMs()
    hs.eventtap.keyStroke({"cmd"}, "tab")
    
    hs.timer.doAfter(0.25, function()
      lastSimulationTime = nowMs()
      hs.eventtap.scrollWheel({ 0, math.random(-18, -6) }, {}, "pixel")
      
      -- Extra mouse move in new window
      hs.timer.doAfter(0.1, function()
        smartMouseMove()
      end)
    end)
  
  ------------------------------------------------
  -- 4. KEYBOARD SHORTCUTS (8%)
  ------------------------------------------------
  else
    lastSimulationTime = nowMs()
    local shortcuts = {
      function() 
        hs.eventtap.keyStroke({"cmd"}, "a") -- Select all
        hs.timer.doAfter(AUTO_REVERT_DELAY, function()
          hs.eventtap.keyStroke({}, "right") -- Deselect
        end)
      end,
      function() 
        hs.eventtap.keyStroke({"cmd"}, "f") -- Find
        hs.timer.doAfter(AUTO_REVERT_DELAY, function()
          hs.eventtap.keyStroke({}, "escape")
        end)
      end,
      function() 
        hs.eventtap.keyStroke({"cmd"}, "c") -- Copy
      end,
      function()
        hs.eventtap.keyStroke({"cmd"}, "b") -- Toggle sidebar
        hs.timer.doAfter(AUTO_REVERT_DELAY, function()
          hs.eventtap.keyStroke({"cmd"}, "b") -- Toggle back
        end)
      end,
      function()
        hs.eventtap.keyStroke({"cmd"}, "t") -- New tab
        hs.timer.doAfter(AUTO_REVERT_DELAY, function()
          hs.eventtap.keyStroke({"cmd"}, "w") -- Close tab
        end)
      end,
      function()
        -- Type in search bar
        hs.eventtap.keyStroke({"cmd"}, "l") -- Focus address bar
        hs.timer.usleep(50000)
        local term = searchTerms[math.random(1, #searchTerms)]
        fastType(term)
        hs.timer.doAfter(AUTO_REVERT_DELAY, function()
          hs.eventtap.keyStroke({}, "escape")
          quickDelete(#term)
        end)
      end,
    }
    shortcuts[math.random(1, #shortcuts)]()
  end
  
  -- ALWAYS add smart mouse movement in active app
  smartMouseMove()
  
  -- Extra aggressive activity: sometimes do double action
  if math.random() > 0.7 then
    hs.timer.doAfter(0.15, function()
      lastSimulationTime = nowMs()
      -- Quick scroll or mouse move
      if math.random() > 0.5 then
        local amt = math.random(-15, -5)
        hs.eventtap.scrollWheel({ 0, amt }, {}, "pixel")
        hs.timer.doAfter(0.3, function()
          hs.eventtap.scrollWheel({ 0, -amt }, {}, "pixel")
        end)
      else
        smartMouseMove()
      end
    end)
  end
end

--------------------------------------------------
-- SCHEDULER
--------------------------------------------------
local function scheduleNext()
  activityTimer = hs.timer.doAfter(math.random(MIN_INTERVAL, MAX_INTERVAL), function()
    simulateActivity()
    scheduleNext()
  end)
end

--------------------------------------------------
-- START / STOP
--------------------------------------------------
local function startAutomation()
  if activityTimer then return end
  isPausedByUser = false
  scheduleNext()
  hs.alert.show("▶ ULTRA ACTIVITY MODE (80-90%)", 2)
  print("▶ Ultra activity automation started!")
end

local function stopAutomation()
  if activityTimer then
    activityTimer:stop()
    activityTimer = nil
  end
  hs.alert.show("⛔ AUTOMATION STOPPED", 1.5)
  print("⛔ Automation stopped")
end

--------------------------------------------------
-- USER INPUT DETECTION (Smart Pause & Auto-Resume)
--------------------------------------------------
local function onUserInput(event)
  local now = nowMs()
  local timeSinceLastSim = now - lastSimulationTime
  
  -- Ignore if this is likely our own event
  if timeSinceLastSim < SELF_EVENT_GRACE_MS then 
    return false
  end
  
  -- Real user input detected - PAUSE IMMEDIATELY
  if not isPausedByUser then
    isPausedByUser = true
    if activityTimer then
      activityTimer:stop()
      activityTimer = nil
    end
    hs.alert.show("⏸ PAUSED", 0.6)
    print("⏸ Paused - user active")
  end

  -- Auto-resume timer: restart every time user moves
  if resumeTimer then 
    resumeTimer:stop()
    resumeTimer = nil
  end
  
  resumeTimer = hs.timer.doAfter(IDLE_SECONDS, function()
    print("▶ Auto-resuming after " .. IDLE_SECONDS .. "s idle")
    if isPausedByUser then
      isPausedByUser = false
      scheduleNext() -- Start scheduling again
      hs.alert.show("▶ RESUMED", 1.5)
      print("✓ Activity resumed successfully")
    end
  end)
  
  return false
end

--------------------------------------------------
-- EVENT TAP
--------------------------------------------------
local userEventTap = hs.eventtap.new(
  {
    hs.eventtap.event.types.mouseMoved,
    hs.eventtap.event.types.leftMouseDown,
    hs.eventtap.event.types.rightMouseDown,
    hs.eventtap.event.types.scrollWheel,
    hs.eventtap.event.types.keyDown,
  },
  onUserInput
)

userEventTap:start()

--------------------------------------------------
-- HOTKEYS
--------------------------------------------------
-- Toggle automation: Cmd+Alt+Ctrl+S
hs.hotkey.bind({"cmd","alt","ctrl"}, "S", function()
  if activityTimer then
    stopAutomation()
  else
    startAutomation()
  end
end)

-- Manual trigger: Cmd+Alt+Ctrl+T
hs.hotkey.bind({"cmd","alt","ctrl"}, "T", function()
  simulateActivity()
  hs.alert.show("🔄 Manual Activity Triggered", 0.5)
end)

--------------------------------------------------
-- AUTO START
--------------------------------------------------
hs.alert.show("🚀 ULTRA MODE ACTIVE\nActions every 0.2-0.5s\nAuto-resume in 2s", 3)
print("🚀 Hammerspoon Ultra Activity Mode - 80-90% target")
print("⏸ Will pause on physical interaction, auto-resume after 2s idle")
print("✓ Hotkeys: Cmd+Alt+Ctrl+S (toggle), Cmd+Alt+Ctrl+T (manual trigger)")
startAutomation()
