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
local MIN_INTERVAL = 1 -- Increased frequency for 70-90% activity
local MAX_INTERVAL = 3 -- Increased frequency for 70-90% activity
local PRIORITY_APPS = {"Code", "Visual Studio Code"} -- VS Code is top priority
local SECONDARY_APPS = {"Chrome", "Google Chrome"} -- Chrome secondary
local VSCODE_FOCUS_CHANCE = 80 -- 80% chance to focus VS Code specifically
local PRIORITY_APP_FOCUS_CHANCE = 75 -- Overall chance to focus priority apps

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
-- Terminal commands for NestJS & Flutter developer
local terminalCommands = {
  "npm run start:dev", "npm install", "npm run build", "npm run test",
  "flutter run", "flutter doctor", "flutter pub get", "flutter clean",
  "git status", "git add .", "git commit -m \"", "git push origin",
  "docker-compose up -d", "docker ps", "yarn install", "yarn start",
  "nest generate module", "nest generate service", "nest g controller",
  "flutter create", "flutter build apk", "flutter analyze",
  "npm run lint", "npm run format", "yarn test:watch",
  "cd backend && npm install", "cd mobile && flutter pub get",
  "prisma migrate dev", "prisma studio", "typeorm migration:run"
}

-- NestJS code snippets
local nestjsSnippets = {
  "@Controller('", "@Get()", "@Post()", "@Injectable()",
  "async create(@Body() dto: ", "constructor(private readonly ",
  "import { Controller, Get, Post } from '@nestjs/common';",
  "export class AppService {", "@Module({ imports: [",
  "async findAll(): Promise<", "return this.service.",
  "@UseGuards(JwtAuthGuard)", "throw new HttpException(",
  "await this.repository.save(", "@ApiTags('",
  "implements OnModuleInit {", "private readonly logger = new Logger("
}

-- Flutter/Dart code snippets
local flutterSnippets = {
  "class MyWidget extends StatelessWidget {", "Widget build(BuildContext context) {",
  "return Scaffold(", "setState(() {", "final controller = TextEditingController();",
  "Navigator.push(context, MaterialPageRoute(", "import 'package:flutter/material.dart';",
  "Future<void> fetchData() async {", "try { await http.get(",
  "child: Column(children: [", "onPressed: () {", "const SizedBox(height: ",
  "Provider.of<", "BlocBuilder<", "GetX<",
  "final response = await dio.get(", "StreamBuilder<",
  "ListView.builder(itemBuilder: (context, index) =>"
}

-- Mixed code snippets for full-stack dev
local codeSnippets = {
  "async function fetchData() {", "const response = await axios.get(",
  "try { const result = ", "} catch (error) { console.error(",
  "interface UserDto {", "type ResponseType = {",
  "import { Injectable } from '@nestjs/common';", "export default function",
  "const [data, setData] = useState(", "useEffect(() => {",
  "return { statusCode: 200,", "await repository.findOne(",
}

-- Browser search queries for developers
local browserSearches = {
  "nestjs documentation", "flutter widgets catalog", "dart async programming",
  "nestjs typeorm relations", "flutter state management", "stackoverflow nestjs",
  "flutter riverpod tutorial", "nestjs jwt authentication", "dart null safety",
  "flutter bloc pattern", "nestjs middleware", "firebase flutter integration",
  "nestjs swagger setup", "flutter responsive design", "docker nestjs production"
}

-- Regular text for notes/documents
local documentText = {
  "API endpoint documentation", "database schema design notes",
  "mobile app feature requirements", "backend service architecture",
  "sprint planning tasks", "code review comments and feedback",
  "deployment checklist items", "bug fixes and improvements needed",
  "user authentication flow", "data model relationships overview"
}

-- Communication text for Slack/Mail
local messageText = {
  "pushed the latest changes", "merged the PR, please review",
  "deployment completed successfully", "found a bug in the API endpoint",
  "updated the mobile UI components", "backend service is ready for testing",
  "need help with flutter widget", "code review requested for nestjs module",
  "completed the feature implementation", "database migration ran successfully"
}

-- Generate text based on app type
local function getTextForApp(appName)
  if appName:match("Terminal") or appName:match("iTerm") then
    return terminalCommands[math.random(1, #terminalCommands)]
  elseif appName:match("Code") or appName:match("Xcode") or appName:match("Sublime") or appName:match("Atom") then
    -- Mix NestJS, Flutter, and general code snippets
    local snippetType = math.random(1, 3)
    if snippetType == 1 then
      return nestjsSnippets[math.random(1, #nestjsSnippets)]
    elseif snippetType == 2 then
      return flutterSnippets[math.random(1, #flutterSnippets)]
    else
      return codeSnippets[math.random(1, #codeSnippets)]
    end
  elseif appName:match("Safari") or appName:match("Chrome") or appName:match("Firefox") then
    return browserSearches[math.random(1, #browserSearches)]
  elseif appName:match("Slack") or appName:match("Mail") or appName:match("Messages") then
    return messageText[math.random(1, #messageText)]
  elseif appName:match("Notes") or appName:match("TextEdit") or appName:match("Pages") then
    return documentText[math.random(1, #documentText)]
  else
    -- Default to code snippets for developer
    local snippetType = math.random(1, 3)
    if snippetType == 1 then
      return nestjsSnippets[math.random(1, #nestjsSnippets)]
    elseif snippetType == 2 then
      return flutterSnippets[math.random(1, #flutterSnippets)]
    else
      return codeSnippets[math.random(1, #codeSnippets)]
    end
  end
end

local function simulateTyping(text)
  for i = 1, #text do
    local char = text:sub(i, i)
    -- Vary typing speed for realism: faster for common chars, slower for special chars
    local delay = 50000
    if char:match("[%p%d]") then
      delay = math.random(80000, 180000) -- Slower for punctuation/numbers
    else
      delay = math.random(40000, 120000) -- Faster for letters
    end
    hs.timer.usleep(delay)
    hs.eventtap.keyStrokes(char)
    
    -- Occasionally pause mid-typing (thinking)
    if math.random() > 0.92 and i < #text then
      hs.timer.usleep(math.random(300000, 600000)) -- 300-600ms pause
    end
  end
end

local function deleteTypedText(textLength)
  -- Select all typed text and delete with proper timing
  hs.timer.doAfter(0.05, function()
    for i = 1, textLength do
      hs.eventtap.keyStroke({}, "delete")
      if i < textLength then
        hs.timer.usleep(math.random(25000, 40000)) -- Variable delete speed
      end
    end
  end)
end

--------------------------------------------------
-- PRIORITY APP HELPERS
--------------------------------------------------
local function isPriorityApp(appName)
  for _, priority in ipairs(PRIORITY_APPS) do
    if appName:match(priority) then
      return true
    end
  end
  for _, secondary in ipairs(SECONDARY_APPS) do
    if appName:match(secondary) then
      return true
    end
  end
  return false
end

local function isVSCode(appName)
  return appName:match("Code") or appName:match("Visual Studio Code")
end

local function focusPriorityApp()
  -- Try to find VS Code and Chrome
  local vscode = hs.application.find("Code") or hs.application.find("Visual Studio Code")
  local chrome = hs.application.find("Chrome") or hs.application.find("Google Chrome")
  
  -- 80% chance to focus VS Code if it exists, otherwise Chrome
  if vscode and math.random(1, 100) <= VSCODE_FOCUS_CHANCE then
    vscode:activate()
    return true
  elseif chrome then
    chrome:activate()
    return true
  elseif vscode then
    -- Fallback to VS Code if Chrome wasn't chosen
    vscode:activate()
    return true
  end
  return false
end

--------------------------------------------------
-- ACTIVITY FUNCTION (REAL INPUT)
--------------------------------------------------
local function simulateActivity()
  lastSimulationTime = nowMs()

  -- Focus priority apps frequently (75% chance, heavily favoring VS Code)
  if math.random(1, 100) <= PRIORITY_APP_FOCUS_CHANCE then
    focusPriorityApp()
    hs.timer.usleep(500000) -- Wait 500ms for app to focus
  end

  -- Always: tiny mouse movement (increased movement for more activity)
  local pos = hs.mouse.absolutePosition()
  hs.mouse.absolutePosition({
    x = pos.x + math.random(-8, 8),
    y = pos.y + math.random(-8, 8)
  })

  local action = math.random(1, 100)

  ------------------------------------------------
  -- OPTION 1: Typing in focused app (45% - increased for VS Code)
  ------------------------------------------------
  if action <= 45 and ENABLE_TYPING then
    local win = hs.window.focusedWindow()
    if win then
      local appName = win:application():name()
      -- Type in text editors, terminals, browsers, etc.
      if appName:match("Code") or appName:match("TextEdit") or 
         appName:match("Notes") or appName:match("Terminal") or
         appName:match("Safari") or appName:match("Chrome") or
         appName:match("Slack") or appName:match("Mail") or
         appName:match("iTerm") or appName:match("Firefox") or
         appName:match("Xcode") or appName:match("Sublime") or
         appName:match("Pages") or appName:match("Messages") then
        
        -- Get intelligent text based on the app
        local text = getTextForApp(appName)
        local textLength = #text
        
        -- Extra typing for priority apps, especially VS Code
        local typeCount = 1
        if isVSCode(appName) then
          typeCount = math.random(2, 3) -- Type 2-3 times in VS Code for max activity
        elseif isPriorityApp(appName) then
          typeCount = math.random(1, 2) -- Sometimes type twice in Chrome
        end
        
        hs.timer.doAfter(0.1, function()
          -- Type multiple times with pauses
          local currentIteration = 0
          local function typeIteration()
            currentIteration = currentIteration + 1
            simulateTyping(text)
            
            if currentIteration < typeCount then
              -- Delete and type again
              hs.timer.doAfter(0.5, function()
                deleteTypedText(textLength)
                hs.timer.doAfter(0.3, function()
                  typeIteration() -- Type next iteration
                end)
              end)
            else
              -- Final deletion after last typing
              hs.timer.doAfter(math.random(1.0, 1.8), function()
                deleteTypedText(textLength)
                -- Sometimes add extra actions after typing
                if math.random() > 0.7 then
                  hs.timer.doAfter(0.2, function()
                    -- Scroll after typing (reading what was typed)
                    hs.eventtap.scrollWheel({ 0, math.random(-10,-3) }, {}, "pixel")
                  end)
                end
              end)
            end
          end
          
          typeIteration() -- Start typing
        end)
      end
    end

  ------------------------------------------------
  -- OPTION 2: Scroll (25% - adjusted for more typing)
  ------------------------------------------------
  elseif action <= 70 then
    -- More aggressive scrolling
    local scrollType = math.random(1, 3)
    if scrollType == 1 then
      -- Single scroll
      local amount = math.random(-30, -5)
      hs.eventtap.scrollWheel({ 0, amount }, {}, "pixel")
    elseif scrollType == 2 then
      -- Double scroll (rapid)
      hs.eventtap.scrollWheel({ 0, math.random(-20,-8) }, {}, "pixel")
      hs.timer.doAfter(0.1, function()
        hs.eventtap.scrollWheel({ 0, math.random(-20,-8) }, {}, "pixel")
      end)
    else
      -- Horizontal scroll
      hs.eventtap.scrollWheel({ math.random(-15,15), 0 }, {}, "pixel")
    end

  ------------------------------------------------
  -- OPTION 3: Cmd+Tab + scroll (10%)
  ------------------------------------------------
  elseif action <= 80 then
    -- Heavily favor switching to VS Code
    if math.random() > 0.3 then
      focusPriorityApp() -- 70% chance to go straight to VS Code/Chrome
      hs.timer.usleep(300000)
    else
      hs.eventtap.event.newKeyEvent(hs.keycodes.map.cmd, true):post()

      for _ = 1, math.random(1,3) do
        hs.timer.usleep(100000)
        hs.eventtap.event.newKeyEvent(hs.keycodes.map.tab, true):post()
        hs.eventtap.event.newKeyEvent(hs.keycodes.map.tab, false):post()
      end

      hs.timer.doAfter(0.15, function()
        hs.eventtap.event.newKeyEvent(hs.keycodes.map.cmd, false):post()
      end)
    end

    hs.timer.doAfter(0.3, function()
      hs.eventtap.scrollWheel({ 0, math.random(-20,-8) }, {}, "pixel")
    end)

  ------------------------------------------------
  -- OPTION 4: Smooth mouse movement + clicks (8%)
  ------------------------------------------------
  elseif action <= 88 then
    local start = hs.mouse.absolutePosition()
    local target = {
      x = start.x + math.random(-150,150), -- Larger movements
      y = start.y + math.random(-100,100)
    }

    local steps = math.random(8,15) -- More steps for smoother movement
    for i = 1, steps do
      hs.timer.doAfter(0.02 * i, function()
        hs.mouse.absolutePosition({
          x = start.x + (target.x - start.x) * (i / steps),
          y = start.y + (target.y - start.y) * (i / steps)
        })
      end)
    end
    
    -- Sometimes click at the end of movement
    if math.random() > 0.7 then
      hs.timer.doAfter(0.02 * steps + 0.1, function()
        hs.eventtap.leftClick(hs.mouse.absolutePosition())
      end)
    end

  ------------------------------------------------
  -- OPTION 5: Mission Control (4%)
  ------------------------------------------------
  elseif action <= 92 and ENABLE_GLOBAL_UI then
    hs.eventtap.keyStroke({"ctrl"}, "up")
    hs.timer.doAfter(0.8, function()
      hs.eventtap.keyStroke({}, "escape")
    end)

  ------------------------------------------------
  -- OPTION 6: Window resize / move (3%)
  ------------------------------------------------
  elseif action <= 95 then
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
      local searchTerms = {"calculator", "system preferences", "activity monitor", "finder", "safari", "notes", "terminal"}
      local term = searchTerms[math.random(1, #searchTerms)]
      local termLength = #term
      simulateTyping(term)
      -- Delete the search and close spotlight
      hs.timer.doAfter(0.7, function()
        deleteTypedText(termLength)
        hs.timer.usleep(200000)
        hs.eventtap.keyStroke({}, "escape")
      end)
    end)

  ------------------------------------------------
  -- OPTION 8: Copy/Paste/Select operations (3%)
  ------------------------------------------------
  elseif action <= 98 then
    local operations = {
      function() hs.eventtap.keyStroke({"cmd"}, "a") end, -- Select all
      function() hs.eventtap.keyStroke({"cmd"}, "c") end, -- Copy
      function() hs.eventtap.keyStroke({"cmd"}, "f") end, -- Find
      function() 
        hs.eventtap.keyStroke({"shift"}, "left") 
        hs.timer.usleep(50000)
        hs.eventtap.keyStroke({"shift"}, "left") 
        hs.eventtap.keyStroke({"shift"}, "left") 
      end, -- Select text
      function()
        hs.eventtap.keyStroke({"cmd"}, "left") -- Move to beginning of line
        hs.timer.usleep(80000)
        hs.eventtap.keyStroke({"shift", "cmd"}, "right") -- Select to end
      end,
    }
    operations[math.random(1, #operations)]()

  ------------------------------------------------
  -- OPTION 9: Rapid scroll burst (2%)
  ------------------------------------------------
  else
    -- More intensive scroll bursts
    for i = 1, math.random(4,8) do
      hs.timer.doAfter(0.08 * i, function()
        hs.eventtap.scrollWheel({ 0, math.random(-18,-8) }, {}, "pixel")
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
