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
local SELF_EVENT_GRACE_MS = 300
local ENABLE_GLOBAL_UI = true -- Mission Control / Spotlight
local ENABLE_TYPING = true -- Keyboard typing in apps
local MIN_INTERVAL = 2 -- Reduced for more frequent activity
local MAX_INTERVAL = 5 -- Reduced for more frequent activity

--------------------------------------------------
-- STATE
--------------------------------------------------
local activityTimer = nil
local resumeTimer = nil
local isPausedByUser = false
local lastSimulationTime = 0

--------------------------------------------------
-- TIME (MONOTONIC)
--------------------------------------------------
local function nowMs()
  return hs.timer.secondsSinceEpoch() * 1000
end

--------------------------------------------------
-- TYPING HELPERS
--------------------------------------------------
local commonWords = {
  "the", "be", "to", "of", "and", "a", "in", "that", "have", "I",
  "it", "for", "not", "on", "with", "he", "as", "you", "do", "at",
  "this", "but", "his", "by", "from", "they", "we", "say", "her", "she",
  "or", "an", "will", "my", "one", "all", "would", "there", "their", "what",
  "function", "return", "const", "let", "var", "if", "else", "for", "while",
  "class", "import", "export", "async", "await", "try", "catch", "new"
}

local function typeRandomText()
  local numWords = math.random(2, 6)
  local text = ""
  
  for i = 1, numWords do
    text = text .. commonWords[math.random(1, #commonWords)]
    if i < numWords then
      text = text .. " "
    end
  end
  
  return text
end

local function simulateTyping(text)
  for i = 1, #text do
    local char = text:sub(i, i)
    hs.timer.usleep(math.random(50000, 150000)) -- 50-150ms per keystroke
    hs.eventtap.keyStrokes(char)
  end
end

--------------------------------------------------
-- ACTIVITY FUNCTION (REAL INPUT)
--------------------------------------------------
local function simulateActivity()
  lastSimulationTime = nowMs()

  -- Always: tiny mouse movement
  local pos = hs.mouse.absolutePosition()
  hs.mouse.absolutePosition({
    x = pos.x + math.random(-5, 5),
    y = pos.y + math.random(-5, 5)
  })

  local action = math.random(1, 100)

  ------------------------------------------------
  -- OPTION 1: Typing in focused app (30%)
  ------------------------------------------------
  if action <= 30 and ENABLE_TYPING then
    local win = hs.window.focusedWindow()
    if win then
      local appName = win:application():name()
      -- Type in text editors, terminals, browsers, etc.
      if appName:match("Code") or appName:match("TextEdit") or 
         appName:match("Notes") or appName:match("Terminal") or
         appName:match("Safari") or appName:match("Chrome") or
         appName:match("Slack") or appName:match("Mail") then
        
        local text = typeRandomText()
        hs.timer.doAfter(0.1, function()
          simulateTyping(text)
          -- Always delete all typed text
          hs.timer.doAfter(0.5, function()
            for _ = 1, #text do
              hs.eventtap.keyStroke({}, "delete")
              hs.timer.usleep(80000)
            end
          end)
        end)
      end
    end

  ------------------------------------------------
  -- OPTION 2: Scroll (25%)
  ------------------------------------------------
  elseif action <= 55 then
    local amount = ({ math.random(-8,-3), math.random(-15,-8), math.random(-25,-15) })[math.random(1,3)]
    if math.random() > 0.85 then
      hs.eventtap.scrollWheel({ math.random(-10,10), 0 }, {}, "pixel")
    else
      hs.eventtap.scrollWheel({ 0, amount }, {}, "pixel")
    end

  ------------------------------------------------
  -- OPTION 2: Scroll (25%)
  ------------------------------------------------
  elseif action <= 55 then
    local amount = ({ math.random(-8,-3), math.random(-15,-8), math.random(-25,-15) })[math.random(1,3)]
    if math.random() > 0.85 then
      hs.eventtap.scrollWheel({ math.random(-10,10), 0 }, {}, "pixel")
    else
      hs.eventtap.scrollWheel({ 0, amount }, {}, "pixel")
    end

  ------------------------------------------------
  -- OPTION 3: Cmd+Tab + scroll (20%)
  ------------------------------------------------
  elseif action <= 75 then
    hs.eventtap.event.newKeyEvent(hs.keycodes.map.cmd, true):post()

    for _ = 1, math.random(1,3) do
      hs.timer.usleep(100000)
      hs.eventtap.event.newKeyEvent(hs.keycodes.map.tab, true):post()
      hs.eventtap.event.newKeyEvent(hs.keycodes.map.tab, false):post()
    end

    hs.timer.doAfter(0.15, function()
      hs.eventtap.event.newKeyEvent(hs.keycodes.map.cmd, false):post()
    end)

    hs.timer.doAfter(0.3, function()
      hs.eventtap.scrollWheel({ 0, math.random(-15,-5) }, {}, "pixel")
    end)

  ------------------------------------------------
  -- OPTION 4: Smooth mouse movement (10%)
  ------------------------------------------------
  elseif action <= 85 then
    local start = hs.mouse.absolutePosition()
    local target = {
      x = start.x + math.random(-100,100),
      y = start.y + math.random(-80,80)
    }

    local steps = math.random(5,10)
    for i = 1, steps do
      hs.timer.doAfter(0.02 * i, function()
        hs.mouse.absolutePosition({
          x = start.x + (target.x - start.x) * (i / steps),
          y = start.y + (target.y - start.y) * (i / steps)
        })
      end)
    end

  ------------------------------------------------
  -- OPTION 5: Mission Control (5%)
  ------------------------------------------------
  elseif action <= 90 and ENABLE_GLOBAL_UI then
    hs.eventtap.keyStroke({"ctrl"}, "up")
    hs.timer.doAfter(0.8, function()
      hs.eventtap.keyStroke({}, "escape")
    end)

  ------------------------------------------------
  -- OPTION 6: Window resize / move (4%)
  ------------------------------------------------
  elseif action <= 94 then
    local win = hs.window.focusedWindow()
    if win then
      local f = win:frame()
      local s = win:screen():frame()

      if math.random() > 0.5 then
        f.w = math.max(400, f.w + math.random(-50,50))
        f.h = math.max(300, f.h + math.random(-50,50))
      else
        f.x = math.max(s.x, math.min(s.x + s.w - f.w, f.x + math.random(-30,30)))
        f.y = math.max(s.y, math.min(s.y + s.h - f.h, f.y + math.random(-30,30)))
      end

      win:setFrame(f, 0.2)
    end

  ------------------------------------------------
  -- OPTION 7: Spotlight search with typing (3%)
  ------------------------------------------------
  elseif action <= 97 and ENABLE_GLOBAL_UI and ENABLE_TYPING then
    hs.eventtap.keyStroke({"cmd"}, "space")
    hs.timer.doAfter(0.3, function()
      local searchTerms = {"calculator", "system", "activity", "finder", "safari", "notes"}
      local term = searchTerms[math.random(1, #searchTerms)]
      simulateTyping(term)
      hs.timer.doAfter(0.5, function()
        hs.eventtap.keyStroke({}, "escape")
      end)
    end)

  ------------------------------------------------
  -- OPTION 8: Copy/Paste/Select operations (2%)
  ------------------------------------------------
  elseif action <= 99 then
    local operations = {
      function() hs.eventtap.keyStroke({"cmd"}, "a") end, -- Select all
      function() hs.eventtap.keyStroke({"cmd"}, "c") end, -- Copy
      function() 
        hs.eventtap.keyStroke({"shift"}, "left") 
        hs.timer.usleep(50000)
        hs.eventtap.keyStroke({"shift"}, "left") 
      end, -- Select text
    }
    operations[math.random(1, #operations)]()

  ------------------------------------------------
  -- OPTION 9: Rapid scroll burst (1%)
  ------------------------------------------------
  else
    for i = 1, math.random(3,5) do
      hs.timer.doAfter(0.1 * i, function()
        hs.eventtap.scrollWheel({ 0, math.random(-12,-5) }, {}, "pixel")
      end)
    end
  end
end

--------------------------------------------------
-- SCHEDULER (NON-MECHANICAL)
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
  scheduleNext()
 -- hs.alert.show("▶ Activity automation running")
end

local function stopAutomation()
  if activityTimer then
    activityTimer:stop()
    activityTimer = nil
  end
end

--------------------------------------------------
-- USER INPUT DETECTION
--------------------------------------------------
local function onUserInput()
  local now = nowMs()
  if isPausedByUser or (now - lastSimulationTime < SELF_EVENT_GRACE_MS) then return end

  isPausedByUser = true
  stopAutomation()

  if resumeTimer then resumeTimer:stop() end
  resumeTimer = hs.timer.doAfter(IDLE_SECONDS, function()
    isPausedByUser = false
    startAutomation()
  end)
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
    hs.eventtap.event.types.keyDown
  },
  function()
    onUserInput()
    return false
  end
)

userEventTap:start()

--------------------------------------------------
-- MANUAL TOGGLE (HOTKEY)
--------------------------------------------------
hs.hotkey.bind({"cmd","alt","ctrl"}, "S", function()
  if activityTimer then
    stopAutomation()
    hs.alert.show("⛔ Automation stopped")
  else
    startAutomation()
  end
end)

--------------------------------------------------
-- AUTO START
--------------------------------------------------
startAutomation()
