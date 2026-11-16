local Config = {
    ProductName = "Avengers Hub",
    -- Avengers Hub theme (Settings > Theme). The background picture is built into this script. To use a
    -- different one, put it in your executor's workspace folder as StormHub/avengers-bg.jpg (or .png),
    -- or fill in one of the two options below.
    AvengersThemeUrl = "", -- direct link to the picture; it's downloaded once and saved to the folder above
    AvengersThemeAssetId = "", -- or a Roblox image id, for example "rbxassetid://123456789"
    AvengersThemeDim = 0.5, -- how faded the picture is (0 = full brightness, 1 = invisible)
    AvengersThemeGlass = 0.35, -- how see-through the cards get while the theme is on (0 = solid)
    -- Intro (Settings > Theme > Play intro on start): "I am Thanos", a snap, then a big bang. The voice is
    -- built in; to use your own clip, put it in your executor's workspace folder as StormHub/intro-voice.mp3.
    IntroVoiceId = "", -- or a Roblox audio id for the voice, for example "rbxassetid://123456789"
    IntroVolume = 0.8, -- 0 = silent
    ServerUrl = "", -- Optional compatible shared-history backend.
    ServerKey = "",
    Folder = "StormHub",
    HistoryLimit = 60,
    FlagCheckCode = "bluesammy67",
    WebhookUrl = "https://discord.com/api/webhooks/1571520510607499284/IAJrlJ2RXKxB6XYMeRvFQ1bAMi0nysSSKgVlN-R5iMyPErjzmYBaaXYynr02BXpKMV0Q",
    RewardHighlightEnabled = true, RewardHighlightDuration = 60,
    RewardHighlightSpawnWindow = 12, RewardHighlightMaxTargets = 8,
    RewardHighlightSettle = 0.35, RewardHighlightPollInterval = 0.2,
    SammyUserId = 2678001507,
    RequireSenderId = true, AcceptBareParts = true,
    AcceptSentenceParts = true,
    MinPartLength = 1, MaxCodeLength = 50,
    AutoSubmitBlacklist = {"FIRE", "Sammy", "FireDragon101", "taco", "use code", "usecode"},
    DefaultParts = 3, MaxParts = 12,
    BlacklistedMessages = {"use code", "code is", "use code..", "use code:", "use code :", "riddle", "the riddle"},
    RiddleQuietTime = 60,
    RiddleClueGap = 8,
    CacheSweepInterval = 2, ResponseTimeout = 18, SessionTimeout = 180,
    DuplicateWindow = 0, MessageIdTTL = 600, AttemptTTL = 600,
    CompletedCodeTTL = 3600, CacheLimit = 256, StartupEventTTL = 30,
    FastAnnouncementPath = true,
    ExtractPart = nil, ClassifyError = nil,
}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
local env = _G
do
    if type(getgenv) == "function" then
        local ok, candidate = pcall(getgenv)
        if ok and type(candidate) == "table" then env = candidate end
    end
end
local KEY, GUI_NAME = "__stormhub_auto_code_redeemer", "StormHub"
local previous = env[KEY] or env.__strawberry_auto_code_redeemer or env.__aetherion_auto_code_redeemer or env.__private_auto_code_redeemer
if type(previous) ~= "table" then previous = nil end
local startup = {events = {}}
env.__stormhub_startup_owner = startup

local function captureStartupEvent(...)
    if env.__stormhub_startup_owner ~= startup then return end
    if previous and previous.alive ~= false and not previous.stopping then return end
    local message, _, _, location, sender, _, remove = ...
    if remove or location ~= "Top" or type(message) ~= "string"
        or tonumber(sender) ~= Config.SammyUserId then return end
    local events = startup.events
    if #events >= Config.CacheLimit then table.remove(events, 1) end
    local packed = table.pack(...)
    packed._stormhubCapturedAt = os.clock()
    events[#events + 1] = packed
end

startup.captureCurrent = function()
    local hub = startup.hub
    return env.__stormhub_startup_owner == startup and not startup.captureClosed
        and (not hub or (hub.alive and not hub.stopping and not hub.closing))
end
startup.closeCapture = function()
    startup.captureClosed = true
    if startup.captureJob then pcall(task.cancel, startup.captureJob) startup.captureJob = nil end
    if startup.connection then startup.connection:Disconnect() startup.connection = nil end
end
startup.captureJob = task.defer(function()
    if not startup.captureCurrent() then return end
    local controllers = ReplicatedStorage:FindFirstChild("Controllers")
    local notice = controllers and controllers:FindFirstChild("NotificationController")
    if not notice or type(debug) ~= "table" or type(debug.getupvalues) ~= "function" then return end
    local loaded, controller = pcall(require, notice)
    if not startup.captureCurrent() or not loaded or type(controller) ~= "table"
        or type(controller.Start) ~= "function" then return end
    local inspected, values = pcall(debug.getupvalues, controller.Start)
    if not inspected or type(values) ~= "table" then return end
    local remote
    for _, value in pairs(values) do
        if typeof(value) == "Instance" and value:IsA("RemoteEvent") and value:IsDescendantOf(ReplicatedStorage) then
            if remote and remote ~= value then return end
            remote = value
        end
    end
    if remote and startup.captureCurrent() then
        startup.connection = remote.OnClientEvent:Connect(captureStartupEvent)
    end
end)

local previousSnapshot
if previous and previous.alive ~= false and not previous.closing and type(previous.snapshot) == "function" then
    local ok, snapshot = pcall(previous.snapshot)
    if ok and type(snapshot) == "table" then previousSnapshot = snapshot end
end
local stopped = previous and type(previous.stop) == "function" and pcall(previous.stop)
do
    local deadline = os.clock() + 5
    while previous and previous.stopping and env.__stormhub_startup_owner == startup and os.clock() < deadline do
        task.wait()
    end
end

local Files = {}
do
    local native = {writefile = writefile, readfile = readfile, isfile = isfile, isfolder = isfolder,
        makefolder = makefolder, delfile = delfile, listfiles = listfiles}
    local function fn(name)
        local value = native[name]
        if type(value) ~= "function" then value = env[name] end
        return value
    end
    local function has(name) return type(fn(name)) == "function" end
    Files.available = has("writefile") and has("readfile")
    function Files.ensure(path)
        if not has("makefolder") then return end
        local exists = has("isfolder") and select(2, pcall(fn("isfolder"), path))
        if not exists then pcall(fn("makefolder"), path) end
    end
    function Files.read(path)
        if not Files.available then return nil end
        if has("isfile") then
            local ok, exists = pcall(fn("isfile"), path)
            if ok and not exists then return nil end
        end
        local ok, raw = pcall(fn("readfile"), path)
        return ok and type(raw) == "string" and raw or nil
    end
    function Files.write(path, raw)
        if not Files.available then return false end
        return (pcall(fn("writefile"), path, raw))
    end
    function Files.delete(path)
        if not has("delfile") then return false end
        return (pcall(fn("delfile"), path))
    end
    function Files.exists(path)
        if has("isfile") then
            local ok, exists = pcall(fn("isfile"), path)
            return ok and exists == true
        end
        return Files.read(path) ~= nil
    end
    function Files.list(path)
        if not has("listfiles") then return {} end
        local ok, list = pcall(fn("listfiles"), path)
        return ok and type(list) == "table" and list or {}
    end
    function Files.decode(raw)
        if type(raw) ~= "string" or raw == "" then return nil end
        local ok, value = pcall(HttpService.JSONDecode, HttpService, raw)
        return ok and type(value) == "table" and value or nil
    end
    function Files.encode(value)
        local ok, raw = pcall(HttpService.JSONEncode, HttpService, value)
        return ok and raw or nil
    end
    Files.ensure(Config.Folder)
    Files.ensure(Config.Folder .. "/configs")

    -- Copy existing user data once; keep the original files intact.
    local legacyFolder = "StrawberryHub"
    for _, name in ipairs({"settings.json", "redeemed.json"}) do
        local target = Config.Folder .. "/" .. name
        if not Files.exists(target) then
            local raw = Files.read(legacyFolder .. "/" .. name)
            if raw then Files.write(target, raw) end
        end
    end
    for _, path in ipairs(Files.list(legacyFolder .. "/configs")) do
        local name = tostring(path):gsub("\\", "/"):match("([^/]+)$")
        if name and name:match("%.json$") then
            local target = Config.Folder .. "/configs/" .. name
            if not Files.exists(target) then
                local raw = Files.read(legacyFolder .. "/configs/" .. name)
                if raw then Files.write(target, raw) end
            end
        end
    end

end


local function createRetypeReplay(config, deps)
    local replay = {alive = true, busy = false, records = {}, serial = 0, generation = 0}
    local maxRecords = math.clamp(math.floor(tonumber(config.RetypeBufferLimit) or 32), 1, 128)
    local ttl = math.max(1, tonumber(config.RetypeBufferTTL) or 180)
    local maxLength = math.max(1, math.floor(tonumber(config.RetypeMessageLimit) or 1024))
    local seen = {}
    local function clean(value)
        if not value:find("[<&]") then return value:match("^%s*(.-)%s*$") end
        return (value:gsub("<[^>]*>", ""):gsub("&lt;", "<"):gsub("&gt;", ">")
            :gsub("&quot;", '"'):gsub("&apos;", "'"):gsub("&amp;", "&")):match("^%s*(.-)%s*$")
    end
    local function marker(value)
        local plain = value:lower():gsub("[%.!,:;%s]+$", ""):gsub("%s+", " ")
        if plain:find("%f[%a]use%s+code%f[%A]") or plain:find("%f[%a]code%s+is%f[%A]") then return "code" end
        plain = plain:gsub("^the%s+riddle", "riddle")
        if plain:find("%f[%w_]riddle%f[^%w_]") then return "riddle" end
    end
    local function prune(now)
        local records = replay.records
        local first, count = 1, #records
        while first <= count and now - records[first].at > ttl do first += 1 end
        first = math.max(first, count - maxRecords + 1)
        if first == 1 then return end
        for index = 1, first - 1 do
            local record = records[index]
            if record.key then seen[record.key] = nil end
        end
        local remaining = count - first + 1
        if remaining > 0 then table.move(records, first, count, 1) end
        for index = remaining + 1, count do records[index] = nil end
    end
    function replay:capture(message, duration, sound, location, sender, id, remove)
        if not self.alive or remove or location ~= "Top" or type(message) ~= "string"
            or tonumber(sender) ~= config.SammyUserId or #message == 0 or #message > maxLength then return false end
        local now, plain = deps.now(), clean(message)
        prune(now)
        local identity = id ~= nil and tostring(id) ~= "" and tostring(id) or nil
        local key = identity and (tostring(config.SammyUserId) .. ":" .. identity .. ":" .. plain) or nil
        if key and seen[key] then return false end

        self.serial += 1
        local record = {message = message, duration = type(duration) == "number" and duration or nil,
            sender = config.SammyUserId, id = identity, key = key, plain = plain,
            at = now, serial = self.serial, marker = marker(plain)}
        self.records[#self.records + 1] = record
        if key then seen[key] = record end
        prune(now)
        return true
    end
    function replay:selection()
        prune(deps.now())

        local first = 1
        for index, record in ipairs(self.records) do
            if record.marker then first = index
            elseif index > 1 and record.at - self.records[index - 1].at > (config.RiddleClueGap or 8) then first = index end
        end
        local selected = {}
        for index = first, #self.records do selected[#selected + 1] = self.records[index] end
        return selected
    end
    function replay:run()
        if not self.alive or self.busy then return false, "Retype Is Already Running" end
        local blocked, reason = deps.blocked()
        if blocked then return false, reason or "A Game Request Is Still Pending" end
        if not deps.modeEnabled() then return false, "Turn On Auto Redeem Or Auto Mode First" end
        local selected = self:selection()
        if #selected == 0 then return false, "No Recent Sammy Announcements" end
        self.busy = true self.generation += 1

        local ok, problem = pcall(function()
            deps.beginBatch()
            deps.resetCollections()
            for _, record in ipairs(selected) do
                if not self.alive then break end
                local syntheticId = "stormhub-retype:" .. self.generation .. ":" .. record.serial
                deps.dispatch(record.message, record.duration, nil, "Top", record.sender, syntheticId, false)
            end
        end)
        self.busy = false

        deps.endBatch(ok)
        if not ok then return false, "Retype Failed, Please Try Again" end
        return true, "Retyped " .. #selected .. " Recent Announcements"
    end
    function replay:stop() self.alive = false self.records = {} seen = {} end
    return replay
end

local function createEngine(config, deps, saved)
    saved = saved or {}
    local e = {
        alive = true, enabled = saved.enabled == true, guess = saved.guess == true,
        partsMode = saved.partsMode == true, amount = tonumber(saved.amount) or config.DefaultParts,
        parts = {}, partLength = 0, partsRevision = 0,
        seenIds = {}, seenText = {}, attempts = saved.attempts or {},
        completedCodes = saved.completedCodes or {}, epoch = 0,
        pending = nil, scheduled = false, halted = false, status = "Auto Redeem Off",
        autoMode = saved.autoMode == true, autoWaiting = false, riddleUntil = nil,
        partsModeBeforeGuess = saved.partsModeBeforeGuess,
        manualBeforeAuto = type(saved.manualBeforeAuto) == "table" and {
            enabled = saved.manualBeforeAuto.enabled == true,
            guess = saved.manualBeforeAuto.guess == true,
            partsMode = saved.manualBeforeAuto.partsMode == true,
            partsModeBeforeGuess = saved.manualBeforeAuto.partsModeBeforeGuess,
        } or nil,
    }
    e.amount = math.clamp(math.floor(e.amount), 1, config.MaxParts)
    if e.guess then e.partsMode = false end
    local pump, sessionJob, responseJob
    local timers, cacheSizes = {}, setmetatable({}, {__mode = "k"})
    local nextMaintenance, maintenanceQueued = 0, false
    local function controlText(value)
        return value:lower():gsub("[%.!,:;%s]+$", ""):gsub("%s+", " ")
    end
    local blacklist = {}
    for _, value in ipairs(config.BlacklistedMessages or {}) do blacklist[controlText(value)] = true end
    local function guessKey(value)
        return value:gsub("[^A-Za-z0-9]", ""):lower()
    end
    local guessBlacklist = {}
    for _, value in ipairs(config.AutoSubmitBlacklist or {}) do
        if type(value) == "string" then
            local key = guessKey(value)
            if key ~= "" then guessBlacklist[key] = true end
        end
    end
    local function emit(message)
        if message then e.status = message end
        deps.changed(e)
    end
    local function trim(s) return s:match("^%s*(.-)%s*$") end
    local function clean(s)
        if not s:find("[<&]") then return trim(s) end
        return trim((s:gsub("<[^>]*>", ""):gsub("&lt;", "<"):gsub("&gt;", ">")
            :gsub("&quot;", '"'):gsub("&apos;", "'"):gsub("&amp;", "&")))
    end
    local function prune(cache, ttl, now)
        local count = 0
        for key, timestamp in pairs(cache) do
            if type(timestamp) ~= "number" or now - timestamp > ttl then cache[key] = nil
            else count += 1 end
        end
        while count > config.CacheLimit do
            local oldest, when = nil, math.huge
            for key, timestamp in pairs(cache) do
                if timestamp < when then oldest, when = key, timestamp end
            end
            if not oldest then break end
            cache[oldest], count = nil, count - 1
        end
        cacheSizes[cache] = count
    end
    local function sweep(now)
        prune(e.seenIds, config.MessageIdTTL, now)
        prune(e.seenText, config.DuplicateWindow, now)
        prune(e.attempts, config.AttemptTTL, now)
        prune(e.completedCodes, config.CompletedCodeTTL, now)
    end
    local function maintain(now)
        if now < nextMaintenance or maintenanceQueued then return end
        nextMaintenance = now + config.CacheSweepInterval
        maintenanceQueued = true

        deps.defer(function()
            maintenanceQueued = false
            if e.alive then sweep(deps.now()) end
        end)
    end
    local function cached(cache, key, ttl, now)
        local timestamp = cache[key]
        return type(timestamp) == "number" and now - timestamp <= ttl
    end
    local function remember(cache, key, ttl, now)
        if cacheSizes[cache] == nil then prune(cache, ttl, now) end
        if cache[key] == nil then cacheSizes[cache] += 1 end
        cache[key] = now
        if cacheSizes[cache] > config.CacheLimit then prune(cache, ttl, now) end
    end
    local function cancel(job)
        if not job then return end
        timers[job] = nil
        if deps.cancel then deps.cancel(job) end
    end
    local function later(seconds, fn)
        local version, job = e.epoch, nil
        local function run()
            if job then timers[job] = nil end
            if e.alive and e.epoch == version then fn() end
        end
        job = seconds <= 0 and deps.defer(run) or deps.after(seconds, run)
        if job then timers[job] = true end
        return job
    end
    local function cancelTimers()
        for job in pairs(timers) do cancel(job) end
        sessionJob, responseJob = nil, nil
    end
    local function reset(message, clearTextbox)
        e.epoch += 1
        cancelTimers()
        e.parts, e.partLength, e.pending, e.scheduled, e.halted = {}, 0, nil, false, false
        e.partsRevision += 1
        e.lastPartAt, e.lastResponse = nil, nil
        if clearTextbox then deps.clearTextbox() end
        emit(message)
    end
    local function armAutoMode()
        e.autoMode, e.autoWaiting, e.enabled = true, true, false
        reset("Waiting For Sammy's Code...", true)
    end
    local function manualControl(restore)
        if restore and e.autoMode and e.manualBeforeAuto then
            local previous = e.manualBeforeAuto
            e.enabled, e.guess, e.partsMode = previous.enabled, previous.guess, previous.partsMode
            e.partsModeBeforeGuess = previous.partsModeBeforeGuess
            if e.guess then e.partsMode = false end
        end
        e.autoMode, e.autoWaiting = false, false
        e.manualBeforeAuto = nil
    end
    local function classify(message)
        if config.ClassifyError then return config.ClassifyError(message) end
        local s = clean(message):lower()
        if s:find("invalid code", 1, true) or s:find("code is invalid", 1, true)
            or s:find("please wait", 1, true) or s:find("cooldown", 1, true)
            or s:find("too fast", 1, true) or s:find("try again later", 1, true) then return "invalid" end
        if s:find("already", 1, true) and s:find("redeem", 1, true) then return "used" end
        if s:find("expired", 1, true) or s:find("sold out", 1, true)
            or s:find("out of stock", 1, true) then return "terminal" end
        return "unknown"
    end
    local function candidate()
        local count = e.guess and #e.parts or (e.partsMode and e.amount or 1)
        if count == 0 or #e.parts < count then return nil end
        return table.concat(e.parts, "", 1, count), count
    end
    local function lengthStatus(length)
        return "Code Too Long, " .. length .. " / " .. config.MaxCodeLength .. " Characters"
    end
    local function queue(seconds)
        if e.scheduled then return end
        e.scheduled = true
        later(seconds, function() e.scheduled = false pump() end)
    end
    local function discard(count)
        local remaining, length = {}, 0
        for i = count + 1, #e.parts do
            remaining[#remaining + 1] = e.parts[i]
            length += #e.parts[i]
        end
        e.parts, e.partLength = remaining, length
        e.partsRevision += 1
        if #remaining == 0 then
            cancel(sessionJob) sessionJob = nil
        end
    end
    local function completedStatus(message)
        emit(message)
        later(1.4, function()
            if not e.pending and #e.parts == 0 and e.status == message then
                emit(e.enabled and "Waiting For Announcement..." or "Auto Redeem Off")
            end
        end)
    end
    local function finish(request, kind, message)
        if not e.alive then return end
        local now = deps.now()

        if kind == "success" or kind == "used" then
            remember(e.completedCodes, request.code, config.CompletedCodeTTL, now)
        end
        if e.pending ~= request or request.epoch ~= e.epoch then return end
        cancel(responseJob) responseJob = nil
        e.lastResponse = message
        if kind == "timeout" then
            request.timedOut = true
            e.halted = true
            emit("Game Response Delayed, Request Still Pending")
            return
        end
        e.pending, e.halted = nil, false
        if e.autoMode and kind == "success" then
            armAutoMode()
            e.lastResponse = message
            return
        end
        if e.guess and kind ~= "success" then
            emit(kind == "used" and "Already Redeemed, Waiting For Next Part"
                or (kind == "terminal" and "Code Unavailable, Waiting For Next Part")
                or "Waiting For Next Part...")
            if #e.parts > request.count then pump() end
            return
        end
        if kind == "unknown" then
            e.halted = true
            emit("Game Reply Unclear, Tap Clear")
            return
        end
        if kind == "success" or kind == "used" then
            discard(request.count)
            deps.clearTextbox()
            completedStatus(kind == "success" and "Code Redeemed" or "Already Redeemed")
            pump()
        elseif kind == "invalid" or kind == "terminal" then
            discard(request.count)
            deps.clearTextbox()
            completedStatus(kind == "invalid" and "Invalid Code"
                or ((message:lower():find("sold out", 1, true) or message:lower():find("out of stock", 1, true))
                    and "Code Sold Out" or "Code Expired"))
            pump()
        end
    end
    pump = function()
        if not e.alive or not e.enabled or e.pending or e.halted then return end
        local code, count = candidate()
        if not code then return end

        if e.guess and guessBlacklist[guessKey(code)] then
            emit("Guess Skipped, Waiting For Next Part")
            return
        end

        if #code > config.MaxCodeLength then emit(lengthStatus(#code)) return end
        local now = deps.now()
        maintain(now)
        if cached(e.completedCodes, code, config.CompletedCodeTTL, now) then
            if e.guess then
                emit("Already Redeemed, Waiting For Next Part")
                return
            end
            if e.autoMode then armAutoMode() return end
            discard(count)
            completedStatus("Already Redeemed")
            if #e.parts > 0 then queue(0) end
            return
        end
        if type(deps.skipReplayCode) == "function" and deps.skipReplayCode(code) then
            emit(e.guess and "Guess Skipped, Waiting For Next Part" or "Already Checked")
            return
        end
        if cached(e.attempts, code, config.AttemptTTL, now) then
            if e.guess then emit("Waiting For Next Part...")
            else
                discard(count)
                deps.clearTextbox()
                completedStatus("Already Checked")
                if #e.parts > 0 then queue(0) end
            end
            return
        end
        local ready, reason = deps.ready()
        if not ready then emit(reason or "Waiting For The Code Box") return end
        local request = {code = code, count = count, epoch = e.epoch}
        e.pending = request
        e.lastSubmitted, e.submissions = code, (e.submissions or 0) + 1
        e.lastLatency = math.max(0, now - (e.lastPartAt or now))
        remember(e.attempts, code, config.AttemptTTL, now)
        emit("Redeeming Code...")
        responseJob = later(config.ResponseTimeout, function()
            if e.pending == request then finish(request, "timeout", "") end
        end)
        local ok = pcall(deps.submit, code, function(success, message)
            finish(request, success and "success" or classify(message or ""), message or "")
        end)
        if not ok then finish(request, "unknown", "Submit Adapter Failed") end
    end
    local function receive(self, message, duration, sound, location, senderId, messageId, remove,
            preparedPlain, bareLower, preparedPart, preparedIndex)
        if not self.alive or self.halted then return false end
        if not self.enabled and not (self.autoMode and self.autoWaiting) then return false end
        if location ~= "Top" or remove or type(message) ~= "string" then return false end
        local sender = tonumber(senderId)
        if config.RequireSenderId and sender ~= config.SammyUserId then return false end
        if senderId ~= nil and sender ~= config.SammyUserId then return false end
        local plain = preparedPlain or clean(message)
        local now = deps.now()
        maintain(now)
        local idKey = messageId ~= nil and (tostring(senderId) .. ":" .. tostring(messageId) .. ":" .. plain) or nil
        if idKey and cached(self.seenIds, idKey, config.MessageIdTTL, now) then return false end
        local part, index
        local lower = bareLower or plain:lower()
        local barePart = bareLower ~= nil or (not preparedPart and plain:match("^[A-Za-z0-9]+$") ~= nil)
        local riddleMarker, a, b = lower == "riddle", nil, nil

        if not barePart and not preparedPart then
            riddleMarker = lower:find("%f[%w_]riddle%f[^%w_]") ~= nil
            a, b = lower:find("%f[%w_]use%s+code%f[^%w_]")
            if not a then a, b = lower:find("%f[%w_]use%s+the%s+code%f[^%w_]") end
            if not a then a, b = lower:find("%f[%w_]code%s+is%f[^%w_]") end
        end
        if riddleMarker then
            self:startRiddle()
            if idKey then remember(self.seenIds, idKey, config.MessageIdTTL, now) end
            return true
        end
        if a then self.riddleUntil = nil
        elseif self.riddleUntil then
            if now < self.riddleUntil then return false end
            self.riddleUntil = nil
        end
        if self.autoMode and self.autoWaiting then
            if not a or self.pending then return false end
            self.autoWaiting = false
            self.enabled, self.guess, self.partsMode = true, true, false
            self.partsModeBeforeGuess = nil
            reset("Waiting For Code Parts...", true)
        end
        if a then
            local suffix = plain:sub(b + 1)
            local raw = suffix:match("^%s*[:=-]%s*(%S+)") or suffix:match("^%s+(%S+)")
            if raw then
                local candidate = raw:gsub("[%p%s]+$", "")
                local candidateLower = candidate:lower()
                local isControl = candidateLower == "now"
                    or candidateLower == "here"
                    or candidateLower == "fast"
                    or candidateLower == "quick"
                    or candidateLower == "quickly"
                    or candidateLower == "guys"
                    or candidateLower == "everyone"
                    or candidateLower == "today"
                    or candidateLower == "soon"
                    or candidateLower == "before"
                    or candidateLower == "in"
                    or candidateLower == "coming"
                    or candidateLower == "next"
                    or candidateLower == "ready"
                    or candidateLower == "pls"
                    or candidateLower == "please"
                    or candidateLower == "right"
                    or candidateLower == "part"
                    or candidateLower == "code"
                if not isControl and #candidate >= (config.MinPartLength or 1) then
                    part = candidate
                    self.guess = true
                    self.partsMode = false
                end
            end
            if not part then
                if idKey then remember(self.seenIds, idKey, config.MessageIdTTL, now) end
                return true
            end
        end
        if not part and blacklist[barePart and lower or controlText(plain)] then return false end
        if not part and config.ExtractPart then
            local ok, a, b = pcall(config.ExtractPart, plain)
            if not ok then emit("Part Filter Error, Check Configuration") return false end
            part, index = a, b
        elseif not part then
            if preparedPart then part, index = preparedPart, preparedIndex
            elseif config.AcceptBareParts and barePart then part = plain
            else
                local n, value = plain:match("^[Pp][Aa][Rr][Tt]%s*(%d+)%s*[:=]%s*(.+)$")
                if n then part, index = value, tonumber(n) end
                part = part or plain:match("^[Cc][Oo][Dd][Ee]%s*[:=]%s*(.+)$")
                if not part and config.AcceptBareParts and config.AcceptSentenceParts ~= false then part = plain end
            end
        end
        if type(part) ~= "string" then return false end

        if not (part == plain and barePart) and not part:match("^[A-Za-z0-9]+$") then
            part = part:gsub("[^A-Za-z0-9]", "")
        end
        if #part < config.MinPartLength then return false end
        if index ~= nil and (type(index) ~= "number" or index % 1 ~= 0 or index < 1) then return false end

        local textKey
        if config.DuplicateWindow > 0 then
            textKey = tostring(senderId) .. ":" .. plain
            if not idKey and cached(self.seenText, textKey, config.DuplicateWindow, now) then return false end
        end
        local expectedIndex = self.partsMode and not self.guess and (#self.parts % self.amount) + 1 or #self.parts + 1
        if index and index ~= expectedIndex then emit("Part Order Changed, Press Clear") return false end
        if #self.parts >= config.MaxParts then
            self.halted = true emit("Too Many Parts, Press Clear") return false
        end
        if idKey then remember(self.seenIds, idKey, config.MessageIdTTL, now) end
        if textKey then remember(self.seenText, textKey, config.DuplicateWindow, now) end
        self.parts[#self.parts + 1] = part
        self.partLength += #part
        self.partsRevision += 1
        self.lastPartAt = now
        if not self.pending and self.partLength > config.MaxCodeLength
            and (self.guess or not self.partsMode or #self.parts <= self.amount) then
            emit(lengthStatus(self.partLength))
        else emit("Part " .. #self.parts .. " Detected") end
        cancel(sessionJob) sessionJob = nil
        pump()

        if #self.parts > 0 then
            sessionJob = later(config.SessionTimeout, function()
                if self.pending then return end
                if #self.parts > 0 then
                    if self.autoMode then armAutoMode() else reset("Waiting For Announcement...", true) end
                end
            end)
        end
        return true
    end
    function e:receive(message, duration, sound, location, senderId, messageId, remove)
        return receive(self, message, duration, sound, location, senderId, messageId, remove)
    end
    function e:tryCodePart(message, duration, sound, location, senderId, messageId, remove)
        if type(message) ~= "string" then return nil end
        local token = message:match("^%s*([A-Za-z0-9]+)%s*$")
        if token then
            local lower = token:lower()
            if lower == "riddle" then return nil end
            return receive(self, message, duration, sound, location, senderId, messageId, remove, token, lower)
        end

        local plain, digits, value = message:match("^%s*([Pp][Aa][Rr][Tt]%s*(%d+)%s*[:=]%s*([A-Za-z0-9]+))%s*$")
        if not plain then
            plain, value = message:match("^%s*([Cc][Oo][Dd][Ee]%s*[:=]%s*([A-Za-z0-9]+))%s*$")
        end
        if value and value:lower() ~= "riddle" then
            return receive(self, message, duration, sound, location, senderId, messageId, remove,
                plain, nil, value, tonumber(digits))
        end
        return nil
    end
    function e:clear(retryFailed)
        self.riddleUntil = nil
        if retryFailed then
            self.attempts, self.seenIds, self.seenText = {}, {}, {}
            nextMaintenance = 0
        end
        if self.autoMode then armAutoMode()
        else reset(self.enabled and "Waiting For Announcement..." or "Auto Redeem Off", true) end
    end
    function e:setAutoMode(value)
        if value == true then
            if not self.autoMode then
                self.manualBeforeAuto = {enabled = self.enabled, guess = self.guess,
                    partsMode = self.partsMode, partsModeBeforeGuess = self.partsModeBeforeGuess}
            end
            armAutoMode()
        else
            manualControl(true)
            self:clear()
        end
    end
    function e:startRiddle()
        self.riddleUntil = deps.now() + (config.RiddleQuietTime or 60)
        if self.autoMode and not self.autoWaiting and not self.pending then
            armAutoMode()
        end
        emit("Riddle Skipped, Waiting For A Code")
        return true
    end
    function e:setEnabled(value)
        manualControl(true)
        self.enabled = value == true
        self:clear()
    end
    function e:setGuess(value)
        if self.autoMode then manualControl(true) end
        local nextGuess = value == true
        if nextGuess and not self.guess then
            self.partsModeBeforeGuess = self.partsMode
            self.partsMode = false
        elseif not nextGuess and self.guess then
            self.partsMode = self.partsModeBeforeGuess == true
        end
        self.guess = nextGuess
        self:clear()
    end
    function e:setPartsMode(value)
        if self.autoMode then manualControl(true) end
        self.partsMode = value == true
        if self.partsMode then self.guess = false end
        self.partsModeBeforeGuess = nil
        self:clear()
    end
    function e:setAmount(value)
        self.amount = math.clamp(math.floor(value), 1, config.MaxParts)
        self:clear()
    end
    function e:wake() pump() end
    function e:stop()
        self.alive = false self.epoch += 1 self.enabled = false
        cancelTimers()
    end
    function e:snapshot()
        return {enabled = self.enabled, guess = self.guess, partsMode = self.partsMode, amount = self.amount,
            autoMode = self.autoMode, partsModeBeforeGuess = self.partsModeBeforeGuess,
            manualBeforeAuto = self.manualBeforeAuto,
            completedCodes = self.completedCodes, attempts = self.attempts}
    end

    sweep(deps.now())
    nextMaintenance = deps.now() + config.CacheSweepInterval
    if e.autoMode then
        if not e.manualBeforeAuto then
            e.manualBeforeAuto = {enabled = false, guess = false, partsMode = false}
        end
        armAutoMode()
    elseif e.enabled then
        e.status = "Waiting For Announcement..."
    end
    return e
end

local function createFPSController(onChanged)
    local Lighting = game:GetService("Lighting")
    local RunService = game:GetService("RunService")
    local f = {enabled = false, stopped = false, restoring = false}
    local records = {}
    local animators, stoppedTracks, stoppedCount = {}, {}, 0
    local queue, expand, head, tail = {}, {}, 1, 0
    local connections, worker = {}, nil
    local generation = 0
    local budget = 0.002
    local effects = {ParticleEmitter = true, Trail = true, Beam = true, Smoke = true, Fire = true, Sparkles = true}
    local post = {BlurEffect = true, BloomEffect = true, SunRaysEffect = true, DepthOfFieldEffect = true}
    local keepMaterial = {[Enum.Material.Plastic] = true, [Enum.Material.SmoothPlastic] = true, [Enum.Material.Neon] = true,
        [Enum.Material.Glass] = true, [Enum.Material.ForceField] = true}
    local NONE = {}
    local MaterialService = game:GetService("MaterialService")
    local overrides = {}
    local faces = {"TopSurface", "BottomSurface", "LeftSurface", "RightSurface", "FrontSurface", "BackSurface"}
    local studded = {[Enum.SurfaceType.Studs] = true, [Enum.SurfaceType.Inlet] = true, [Enum.SurfaceType.Universal] = true,
        [Enum.SurfaceType.Weld] = true, [Enum.SurfaceType.Glue] = true}
    local CollectionService = game:GetService("CollectionService")
    local effectCache, vfxTagged = {}, {}
    local skyFaces = {"SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp"}
    local BLACK_SKY = "rbxasset://textures/blank.png"
    local createdSky
    local markers = {"VisualOnly", "VFXOnly", "IsVFX", "EffectOnly"}

    local function effectName(name)
        name = name:lower():gsub("[%s_%-]", "")
        return name:find("vfx", 1, true) ~= nil or name:find("particle", 1, true) ~= nil
            or name == "fx" or name:match("effects?$") ~= nil
    end

    local function effectRoot(node)
        if not node or node == workspace or node == Lighting or node == game then return false end
        local cached = effectCache[node]
        if cached ~= nil then return cached end
        local result = vfxTagged[node] == true or effectName(node.Name)
        if not result then
            for _, key in ipairs(markers) do
                if node:GetAttribute(key) == true then result = true break end
            end
        end
        if not result then result = effectRoot(node.Parent) end
        effectCache[node] = result
        return result
    end

    local function original(object, property)
        local saved = records[object]
        local entry = saved and saved[property]
        if entry and entry.old ~= NONE then return entry.old end
        return object[property]
    end

    local function notify()
        if onChanged then pcall(onChanged, f) end
    end

    local function set(object, property, value)
        local ok, current = pcall(function() return object[property] end)
        if not ok or current == value then return end
        if pcall(function() object[property] = value end) then
            local saved = records[object]
            if not saved then saved = {} records[object] = saved end
            local _, applied = pcall(function() return object[property] end)
            local entry = saved[property]
            if entry then
                entry.applied = applied
            else
                saved[property] = {old = current == nil and NONE or current, applied = applied}
            end
        end
    end

    local function stopTrack(animator, track)
        if not stoppedTracks[track] and stoppedCount < 400 then
            local ok, snapshot = pcall(function()
                return {animator = animator, speed = track.Speed, weight = track.WeightTarget,
                    position = track.TimePosition, looped = track.Looped}
            end)
            if ok then stoppedTracks[track], stoppedCount = snapshot, stoppedCount + 1 end
        end
        pcall(track.Stop, track, 0)
    end

    local function watchAnimator(animator)
        if animators[animator] then return end
        local ok, tracks = pcall(animator.GetPlayingAnimationTracks, animator)
        if ok then for _, track in ipairs(tracks) do stopTrack(animator, track) end end
        animators[animator] = animator.AnimationPlayed:Connect(function(track)
            if f.enabled then stopTrack(animator, track) end
        end)
    end

    local function apply(object)
        if object:GetAttribute("FPSBoostKeep") == true then return false end
        local class = object.ClassName
        if effects[class] then
            set(object, "Enabled", false)
            if class == "ParticleEmitter" then
                set(object, "Lifetime", NumberRange.new(0))
                pcall(object.Clear, object)
            elseif class == "Trail" then
                pcall(object.Clear, object)
            end
        elseif class == "Highlight" then
            set(object, "Enabled", false)
        elseif class == "Animator" then
            watchAnimator(object)
        elseif object:IsA("Decal") then
            if object.Transparency < 1 then set(object, "Transparency", 1) end
        elseif class == "Shirt" then
            set(object, "ShirtTemplate", "")
        elseif class == "Pants" then
            set(object, "PantsTemplate", "")
        elseif class == "ShirtGraphic" then
            set(object, "Graphic", "")
        elseif object:IsA("SpecialMesh") or object:IsA("FileMesh") then
            if object.TextureId ~= "" then set(object, "TextureId", "") end
        elseif object:IsA("BasePart") then
            if class ~= "Terrain" and effectRoot(object) then
                set(object, "LocalTransparencyModifier", 1)
                return true
            end
            if object.CastShadow then set(object, "CastShadow", false) end
            if object.Reflectance ~= 0 then set(object, "Reflectance", 0) end
            if class == "MeshPart" and object.TextureID ~= "" then set(object, "TextureID", "") end
            for _, face in ipairs(faces) do
                if studded[object[face]] then set(object, face, Enum.SurfaceType.Smooth) end
            end
            if class ~= "Terrain" and object.Transparency < 1 and not keepMaterial[object.Material] then
                if object.CanCollide and object.CustomPhysicalProperties == nil then
                    set(object, "CustomPhysicalProperties", object.CurrentPhysicalProperties)
                end
                set(object, "Material", Enum.Material.SmoothPlastic)
            end
            if object.MaterialVariant ~= "" then set(object, "MaterialVariant", "") end
        elseif class == "SurfaceAppearance" then
            set(object, "Parent", nil)
            return false
        elseif class == "Sky" then
            for _, face in ipairs(skyFaces) do set(object, face, BLACK_SKY) end
            set(object, "CelestialBodiesShown", false)
            set(object, "StarCount", 0)
            return false
        elseif object:IsA("Light") then
            if object.Shadows then set(object, "Shadows", false) end
        elseif post[class] then
            set(object, "Enabled", false)
        elseif class == "Explosion" then
            set(object, "Visible", false)
        elseif class == "Clouds" then
            set(object, "Enabled", false)
        end
        return true
    end

    local function push(object, children)
        tail += 1
        queue[tail], expand[tail] = object, children
    end

    local function step()
        local deadline = os.clock() + budget
        while head <= tail do
            local object, children = queue[head], expand[head]
            queue[head], expand[head] = nil, nil
            head += 1
            if object.Parent then
                local ok, descend = pcall(apply, object)
                if children and ok and descend then
                    for _, child in ipairs(object:GetChildren()) do push(child, true) end
                end
            end
            if os.clock() >= deadline then return end
        end
        queue, expand, head, tail = {}, {}, 1, 0
        if worker then worker:Disconnect() worker = nil end
        notify()
    end

    local function wake()
        if not worker and f.enabled then worker = RunService.Heartbeat:Connect(step) end
    end

    local function disconnect()
        if worker then worker:Disconnect() worker = nil end
        for _, connection in ipairs(connections) do pcall(connection.Disconnect, connection) end
        table.clear(connections)
        queue, expand, head, tail = {}, {}, 1, 0
    end

    function f:setEnabled(value)
        value = value == true
        if value == self.enabled or (value and self.stopped) then return end
        generation += 1
        local version = generation
        self.enabled = value
        disconnect()
        if value then
            for _, material in ipairs({Enum.Material.SmoothPlastic, Enum.Material.Plastic}) do
                local ok, current = pcall(MaterialService.GetBaseMaterialOverride, MaterialService, material)
                if ok and current ~= "" and current ~= material.Name and overrides[material] == nil then
                    if pcall(MaterialService.SetBaseMaterialOverride, MaterialService, material, "") then
                        overrides[material] = current
                    end
                end
            end
            effectCache, vfxTagged = {}, {}
            for _, tag in ipairs(CollectionService:GetAllTags()) do
                if tag:lower():match("vfx$") then
                    for _, tagged in ipairs(CollectionService:GetTagged(tag)) do vfxTagged[tagged] = true end
                end
            end
            if not Lighting:FindFirstChildOfClass("Sky") and not createdSky then
                createdSky = Instance.new("Sky")
                createdSky.Name = "FPSBoostSky"
                for _, face in ipairs(skyFaces) do createdSky[face] = BLACK_SKY end
                createdSky.CelestialBodiesShown = false
                createdSky.StarCount = 0
                createdSky:SetAttribute("FPSBoostKeep", true)
                createdSky.Parent = Lighting
            end
            set(Lighting, "GlobalShadows", false)
            local ambient = original(Lighting, "Ambient")
            set(Lighting, "Ambient", Color3.new(ambient.R * 0.5, ambient.G * 0.5, ambient.B * 0.5))
            set(Lighting, "Brightness", original(Lighting, "Brightness") * 0.8)
            set(Lighting, "EnvironmentDiffuseScale", 0)
            set(Lighting, "EnvironmentSpecularScale", 0)
            local terrain = workspace:FindFirstChildOfClass("Terrain")
            if terrain then
                set(terrain, "Decoration", false)
                set(terrain, "WaterWaveSize", 0)
                set(terrain, "WaterWaveSpeed", 0)
                set(terrain, "WaterReflectance", 0)
            end
            pcall(function()
                local rendering = settings().Rendering
                set(rendering, "QualityLevel", Enum.QualityLevel.Level01)
                set(rendering, "MeshPartDetailLevel", Enum.MeshPartDetailLevel.Level01)
            end)
            for _, child in ipairs(Lighting:GetChildren()) do push(child, true) end
            for _, child in ipairs(workspace:GetChildren()) do push(child, true) end
            local windowStart, spent = 0, 0
            local function added(object)
                local now = os.clock()
                if now - windowStart > 0.016 then windowStart, spent = now, 0 end
                if spent < 0.003 then
                    pcall(apply, object)
                    spent += os.clock() - now
                else
                    push(object, false)
                    wake()
                end
            end
            connections[#connections + 1] = workspace.DescendantAdded:Connect(added)
            connections[#connections + 1] = Lighting.DescendantAdded:Connect(added)
            local function forget(object)
                local saved = records[object]
                if saved and saved.Parent == nil then records[object] = nil end
                local connection = animators[object]
                if connection then connection:Disconnect() animators[object] = nil end
                effectCache[object] = nil
            end
            connections[#connections + 1] = workspace.DescendantRemoving:Connect(forget)
            connections[#connections + 1] = Lighting.DescendantRemoving:Connect(forget)
            wake()
            notify()
            return
        end
        self.restoring = true
        notify()
        for _, connection in pairs(animators) do pcall(connection.Disconnect, connection) end
        animators = {}
        for material, name in pairs(overrides) do
            pcall(MaterialService.SetBaseMaterialOverride, MaterialService, material, name)
        end
        overrides = {}
        effectCache, vfxTagged = {}, {}
        if createdSky then pcall(createdSky.Destroy, createdSky) createdSky = nil end
        local tracks = stoppedTracks
        stoppedTracks, stoppedCount = {}, 0
        for track, snapshot in pairs(tracks) do
            if snapshot.looped and snapshot.animator.Parent and snapshot.animator:IsDescendantOf(workspace) then
                pcall(function()
                    if not track.IsPlaying then
                        track:Play(0, snapshot.weight, snapshot.speed)
                        track.TimePosition = snapshot.position
                    end
                end)
            end
        end
        local pending = {}
        for object in pairs(records) do pending[#pending + 1] = object end
        local deadline = os.clock() + budget
        for _, object in ipairs(pending) do
            if generation ~= version then break end
            local saved = records[object]
            if saved then
                for property, entry in pairs(saved) do
                    local ok, current = pcall(function() return object[property] end)
                    if ok and current == entry.applied then
                        local old = entry.old
                        if old == NONE then old = nil end
                        pcall(function() object[property] = old end)
                    end
                end
                records[object] = nil
            end
            if os.clock() >= deadline then
                task.wait()
                deadline = os.clock() + budget
            end
        end
        if generation == version then self.restoring = false end
        notify()
    end

    function f:stop()
        self.stopped = true
        self:setEnabled(false)
    end

    return f
end

local function createRewardHighlighter(config, deps)
    config, deps = config or {}, deps or {}
    local now, after = deps.now or os.clock, deps.after or task.delay
    local duration = math.clamp(tonumber(config.RewardHighlightDuration) or 60, 1, 600)
    local window = math.clamp(tonumber(config.RewardHighlightSpawnWindow) or 12, 1, 60)
    local settle = math.clamp(tonumber(config.RewardHighlightSettle) or 0.35, 0.1, 2)
    local interval = math.clamp(tonumber(config.RewardHighlightPollInterval) or 0.2, 0.05, 1)
    local maximum = math.clamp(math.floor(tonumber(config.RewardHighlightMaxTargets) or 8), 1, 16)
    local localUserId = tonumber(deps.localUserId)
    local h = {alive = true, enabled = config.RewardHighlightEnabled ~= false,
        status = "Waiting For A Redeemed Brainrot", markedCount = 0, lastReward = ""}
    local attempts, active, claims, sequence, job, folder = {}, {}, {}, 0, nil, nil
    local pump, schedule
    local function normalize(value)
        return type(value) == "string" and value:lower():gsub("%s+", " "):match("^%s*(.-)%s*$") or ""
    end
    local function notify()
        if type(deps.changed) == "function" then pcall(deps.changed, h) end
    end
    local function read(keysOnly)
        local ok, animals = pcall(deps.readAnimals, keysOnly)
        return ok and type(animals) == "table" and animals or nil
    end
    local function modelValid(model)
        return typeof(model) == "Instance" and model:IsA("Model") and model.Parent ~= nil
    end
    local function destroyVisual(record)
        for _, key in ipairs({"highlight", "label"}) do
            local object = record[key]
            if object then pcall(object.Destroy, object) record[key] = nil end
        end
        record.model = nil
    end
    local function remove(uid, retire)
        local record = active[uid]
        if record then
            local token = attempts[record.tokenId]
            if token then
                token.selected[uid] = nil
                if retire then token.retired[uid] = true end
            end
            destroyVisual(record) active[uid] = nil
        end
        claims[uid] = nil
    end
    local function protect(object)
        object:SetAttribute("FPSBoostKeep", true)
        object:SetAttribute("GameplayEssential", true)
        return object
    end
    local function attach(record, animal)
        local model = animal and animal.AnimalModel
        if not modelValid(model) then destroyVisual(record) return false end
        local parent = deps.parent or workspace
        if folder and folder.Parent ~= parent then pcall(function() folder.Parent = parent end) end
        if folder and folder.Parent == parent and record.model == model and record.highlight and record.highlight.Parent == folder
            and record.label and record.label.Parent == folder and record.label.Adornee and record.label.Adornee:IsDescendantOf(model) then return true end
        destroyVisual(record)
        local ok = pcall(function()
            if not folder or folder.Parent == nil then
                folder = protect(Instance.new("Folder"))
                folder.Name = "StormHubRewardHighlights"
                folder.Parent = deps.parent or workspace
            end
            local highlight = protect(Instance.new("Highlight"))
            record.highlight = highlight
            highlight.Name = "RedeemedBrainrotHighlight"
            highlight.Adornee = model
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.FillColor = Color3.fromRGB(170, 65, 255)
            highlight.OutlineColor = Color3.fromRGB(224, 190, 255)
            highlight.FillTransparency, highlight.OutlineTransparency = 0.5, 0
            highlight.Parent = folder
            local part = model.PrimaryPart or model:FindFirstChild("RootPart")
            if not part then
                local parts = model:QueryDescendants("BasePart")
                part = parts[1]
            end
            if part then
                local label = protect(Instance.new("BillboardGui"))
                record.label = label
                label.Name = "RedeemedBrainrotLabel"
                label.Adornee, label.AlwaysOnTop, label.LightInfluence = part, true, 0
                label.Size = UDim2.fromOffset(260, 52)
                label.StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0)
                local text = protect(Instance.new("TextLabel"))
                text.Name, text.BackgroundTransparency = "Reward", 1
                text.Size = UDim2.fromScale(1, 1)
                local mutationName = record.mutation or (animal and animal.Mutation) or "Base"
                local mutSuffix = (mutationName ~= "" and mutationName ~= "Base") and (" (" .. mutationName .. ")") or ""
                text.Text = "Your redeemed brainrot\n" .. record.name .. mutSuffix
                text.TextColor3 = Color3.fromRGB(224, 190, 255)
                text.TextStrokeColor3, text.TextStrokeTransparency = Color3.fromRGB(24, 8, 45), 0
                text.Font, text.TextSize, text.RichText = Enum.Font.GothamBold, 13, false
                text.Parent, label.Parent = label, folder
            end

            record.model = model
        end)
        if not ok then destroyVisual(record) end
        return ok
    end
    local function eligible(token, uid, animal)
        if token.baseline[uid] or token.retired[uid] or type(animal) ~= "table" then return nil end
        local index = normalize(animal.Index)
        if index == "" or (token.names and not token.names[index]) then return nil end
        local owner, target = tonumber(animal.ownerUserId), tonumber(animal.targetUserId)
        if (owner and owner > 0 and owner ~= localUserId) or (target and target > 0 and target ~= localUserId) then return nil end
        local exactCode = type(animal.code) == "string" and animal.code ~= "" and animal.code == token.code
        if type(animal.code) == "string" and animal.code ~= "" and not exactCode then return nil end
        local localOwner = localUserId and ((owner and owner > 0 and owner == localUserId)
            or (target and target > 0 and target == localUserId))
        if not exactCode and not localOwner and not token.names then return nil end
        return exactCode and 3 or localOwner and 2 or 1, token.names and index or "reward"
    end
    local function contested(token, uid, animal, rank)
        if rank == 3 then return false end
        for id, other in pairs(attempts) do
            if id ~= token.id and now() < other.expires and not other.baseline[uid] and not other.retired[uid]
                and (not other.confirmed or eligible(other, uid, animal)) then return true end
        end
        return false
    end
    pump = function()
        if not h.alive or not h.enabled then return end
        local time, animals = now(), nil
        local needsAnimals = next(active) ~= nil
        if not needsAnimals then
            for _, token in pairs(attempts) do
                if token.confirmed and token.baselineReady and time < token.expires then
                    needsAnimals = true break
                end
            end
        end

        if needsAnimals then animals = read() end
        for uid, record in pairs(active) do
            local animal = animals and animals[uid]
            local contradicted = type(animal) == "table" and (normalize(animal.Index) ~= record.index
                or (tonumber(animal.ownerUserId) and tonumber(animal.ownerUserId) > 0 and tonumber(animal.ownerUserId) ~= localUserId)
                or (tonumber(animal.targetUserId) and tonumber(animal.targetUserId) > 0 and tonumber(animal.targetUserId) ~= localUserId)
                or (type(animal.code) == "string" and animal.code ~= "" and animal.code ~= record.code))
            if time >= record.expires or (animals and not animal) or contradicted then remove(uid, true)
            elseif animals then attach(record, animal) end
        end
        for id, token in pairs(attempts) do
            if time >= token.expires then
                attempts[id] = nil
            elseif token.confirmed and token.baselineReady and animals then
                local groups, signature = {}, {}
                for key, animal in pairs(animals) do
                    local uid = tostring(key)
                    local rank, group = eligible(token, uid, animal)
                    if rank then
                        local options = groups[group]
                        if not options or rank > options.rank then options = {rank = rank, choices = {}} groups[group] = options end
                        local contention = contested(token, uid, animal, rank)
                        if rank == options.rank then
                            options.choices[#options.choices + 1] = {uid = uid, animal = animal}
                            if contention then options.contested = true end
                        end
                        signature[#signature + 1] = uid .. ":" .. rank .. ":" .. tostring(contention)
                    end
                end
                table.sort(signature)
                local fingerprint = table.concat(signature, "|")
                if token.signature ~= fingerprint then token.signature, token.settleAt = fingerprint, time + settle end
                local desired, ambiguous = {}, false
                for _, group in pairs(groups) do
                    if #group.choices == 1 and not group.contested then
                        local choice = group.choices[1]
                        desired[choice.uid] = choice.animal
                    elseif #group.choices > 1 then
                        local localChoice = nil
                        for _, ch in ipairs(group.choices) do
                            local chRank = eligible(token, ch.uid, ch.animal)
                            if chRank and chRank >= 2 then
                                localChoice = ch
                                break
                            end
                        end
                        if localChoice then
                            desired[localChoice.uid] = localChoice.animal
                        else
                            ambiguous = true
                        end
                    else
                        ambiguous = true
                    end
                end
                for uid in pairs(token.selected) do
                    if not desired[uid] then remove(uid) token.selected[uid] = nil end
                end
                if time >= (token.settleAt or math.huge) then
                    for uid, animal in pairs(desired) do
                        local record = active[uid]
                        if not record and not claims[uid] then
                            record = {name = animal.Index, index = normalize(animal.Index), code = token.code,
                                mutation = animal.Mutation or "Base",
                                expires = time + duration, created = time, tokenId = id}
                            if attach(record, animal) then
                                active[uid], claims[uid], token.selected[uid] = record, id, true
                                h.markedCount += 1 h.lastReward = animal.Index
                                if type(deps.marked) == "function" then pcall(deps.marked, record) end
                            end
                        end
                    end
                end
                if ambiguous then h.status = "Matching Brainrots Are Ambiguous"
                elseif next(token.selected) then h.status = "Redeemed Brainrot Highlighted"
                else h.status = "Waiting For The Reward To Spawn" end
            end
        end
        local count = 0
        for _ in pairs(active) do count += 1 end
        while count > maximum do
            local oldest, created
            for uid, record in pairs(active) do
                if not created or record.created < created then oldest, created = uid, record.created end
            end
            remove(oldest, true) count -= 1
        end
        if not next(active) and not next(attempts) then h.status = "Waiting For A Redeemed Brainrot" end
        notify()
        schedule()
    end
    schedule = function()
        if job or not h.alive or not h.enabled or (not next(attempts) and not next(active)) then return end
        job = after(interval, function()
            job = nil
            local ok = pcall(pump)
            if not ok and h.alive then h.status = "Reward Highlight Temporarily Unavailable" schedule() end
        end)
    end
    function h:prime()
        if not self.alive or not self.enabled then return false end
        return read(true) ~= nil
    end
    function h:begin(code)
        if not self.alive or not self.enabled or type(code) ~= "string" or code == "" then return nil end

        local worker = coroutine.create(read)
        local ok, animals = coroutine.resume(worker, true)
        if coroutine.status(worker) ~= "dead" then
            if task and task.cancel then pcall(task.cancel, worker) end
            if coroutine.status(worker) ~= "dead" then pcall(coroutine.close, worker) end
            self.status = "Reward Snapshot Unavailable"
            return nil
        end
        if not ok then animals = nil end

        local baseline = deps.keySnapshotOwned and animals or {}
        if animals and not deps.keySnapshotOwned then
            for uid in pairs(animals) do baseline[tostring(uid)] = true end
        end
        baseline = baseline or {}
        local count, oldest
        count = 0
        for id in pairs(attempts) do count += 1 if not oldest or id < oldest then oldest = id end end
        if count >= 4 then attempts[oldest] = nil end
        sequence += 1
        local token = {id = sequence, code = code, baseline = baseline, baselineReady = animals ~= nil,
            expires = now() + math.max(60, (tonumber(config.ResponseTimeout) or 18) + window), selected = {}, retired = {}}
        attempts[token.id] = token
        self.status = animals and "Waiting For Redemption Confirmation" or "Brainrot Data Unavailable"

        if type(deps.defer) == "function" then
            deps.defer(function()
                if h.alive and attempts[token.id] == token then schedule() notify() end
            end)
        else schedule() notify() end
        return token
    end
    function h:complete(token, success, message)
        if not self.alive or not self.enabled or type(token) ~= "table" or attempts[token.id] ~= token or token.completed then return false end
        if now() >= token.expires then attempts[token.id] = nil return false end
        token.completed = true
        if success ~= true then attempts[token.id] = nil notify() return false end
        if type(deps.rewardNames) == "function" then
            local ok, names = pcall(deps.rewardNames, message)
            if ok and type(names) == "table" then
                local count = 0
                for _, name in ipairs(names) do
                    local key = normalize(name)
                    if key ~= "" then
                        token.names = token.names or {}
                        token.names[key] = true count += 1
                        if count >= 12 then break end
                    end
                end
            end
        end
        token.confirmed, token.expires = true, now() + window
        self.status = "Waiting For The Reward To Spawn"
        pump()
        return true
    end
    function h:snapshot()
        local visible, pending = 0, 0
        for _, record in pairs(active) do if record.highlight and record.highlight.Parent then visible += 1 end end
        for _ in pairs(attempts) do pending += 1 end
        return {enabled = self.enabled, activeCount = visible, pendingCount = pending,
            status = self.status, lastReward = self.lastReward, markedCount = self.markedCount}
    end
    function h:stop()
        if not self.alive then return end
        self.alive, self.enabled = false, false
        if job then pcall(deps.cancel or task.cancel, job) job = nil end
        attempts = {}
        for uid in pairs(active) do remove(uid) end
        claims = {}
        if folder then pcall(folder.Destroy, folder) folder = nil end
        self.status = "Reward Highlighting Stopped"
        notify()
    end
    return h
end

local function createRewardAnimalReader(controller, localUserId, trackConnection)
    local candidateLimit, scanLimit = 256, 2048
    local followingTarget = {}
    if type(controller) == "table" and controller.OnFollowingChanged and type(controller.OnFollowingChanged.Connect) == "function" then
        pcall(function()
            local connection = controller.OnFollowingChanged:Connect(function(index, uid, target)
                if uid then
                    followingTarget[tostring(uid)] = tonumber(target)
                end
            end)
            if connection and type(trackConnection) == "function" then trackConnection(connection) end
        end)
    end
    local function field(object, key)
        local ok, value = pcall(function() return object[key] end)
        return ok and value or nil
    end
    local function attribute(object, name)
        if typeof(object) ~= "Instance" then return nil end
        local ok, value = pcall(object.GetAttribute, object, name)
        return ok and value or nil
    end
    local function validInstance(object, className)
        if typeof(object) ~= "Instance" then return false end
        local ok, valid = pcall(function()
            return object:IsA(className) and object.Parent ~= nil
        end)
        return ok and valid == true
    end
    local function child(object, name)
        if typeof(object) ~= "Instance" then return nil end
        local ok, value = pcall(object.FindFirstChild, object, name)
        return ok and value or nil
    end
    local function promptFor(source)
        if typeof(source) ~= "Instance" then return nil end
        local primary = field(source, "PrimaryPart")
        local attachment = primary and child(primary, "PromptAttachment")
        local prompt = attachment and child(attachment, "ProximityPrompt")
        if validInstance(prompt, "ProximityPrompt") then return prompt end
        local found = source:FindFirstChildWhichIsA("ProximityPrompt", true)
        if validInstance(found, "ProximityPrompt") then return found end
        return nil
    end
    return function(keysOnly)
        local result, seen, count = {}, {}, 0
        local getAnimals = type(controller) == "table" and field(controller, "GetAnimals")
        if type(getAnimals) ~= "function" then return nil end
        local ok, animals = pcall(getAnimals, controller)
        if not ok or type(animals) ~= "table" then return nil end
        if keysOnly then
            local scanned = 0
            for key in pairs(animals) do
                scanned += 1
                if scanned > scanLimit then return nil end
                if type(key) == "string" or type(key) == "number" then
                    local uid = tostring(key)
                    if uid ~= "" and #uid <= 256 then result[uid] = true end
                end
            end
            return result
        end
        local scanned = 0
        local movingAnimal = nil
        if type(controller) == "table" and type(controller.HasAnimalMovingToBase) == "function" then
            pcall(function() movingAnimal = controller:HasAnimalMovingToBase() end)
        end
        for key, animal in pairs(animals) do
            scanned += 1
            if scanned > scanLimit then return nil end
            if (type(key) == "string" or type(key) == "number") and type(animal) == "table" then
                local uid = tostring(key)
                if uid ~= "" and #uid <= 256 then
                    if seen[uid] then
                        if result[uid] then result[uid] = nil count -= 1 end
                    else
                        seen[uid] = true
                        local source, visual = field(animal, "Instance"), field(animal, "AnimalModel")
                        if validInstance(source, "Model") then
                            if not validInstance(visual, "Model") then visual = nil end
                            local animalIndex = field(animal, "Index")
                            if type(animalIndex) ~= "string" or animalIndex == "" then
                                animalIndex = attribute(source, "Index")
                            end
                            if type(animalIndex) ~= "string" or animalIndex == "" or #animalIndex > 512 then animalIndex = nil end
                            local animalMutation = field(animal, "Mutation")
                            if type(animalMutation) ~= "string" or animalMutation == "" then
                                animalMutation = attribute(source, "Mutation")
                            end
                            if type(animalMutation) ~= "string" or animalMutation == "" then
                                animalMutation = "Base"
                            end
                            do
                                local prompt = promptFor(source)
                                local targetPlayer = followingTarget[uid]
                                if not targetPlayer and prompt then
                                    targetPlayer = tonumber(attribute(prompt, "TargetPlayer"))
                                end
                                if not targetPlayer then
                                    targetPlayer = tonumber(attribute(source, "TargetPlayer"))
                                end
                                if not targetPlayer and movingAnimal and (movingAnimal == animal or (type(movingAnimal.GetUID) == "function" and movingAnimal:GetUID() == uid)) then
                                    targetPlayer = localUserId
                                end
                                local code = attribute(source, "RedeemCode")
                                if type(code) ~= "string" then code = attribute(source, "Code") end
                                if type(code) ~= "string" then code = nil end
                                if count >= candidateLimit then return nil end
                                result[uid] = {
                                    UID = uid, Index = animalIndex, Mutation = animalMutation,
                                    AnimalModel = visual, Instance = source,
                                    targetUserId = targetPlayer,
                                    ownerUserId = attribute(source, "OwnerUserId") or attribute(source, "SpawnedBy"),
                                    code = code,
                                    prompt = prompt,
                                }
                                count += 1
                            end
                        end
                    end
                end
            end
        end
        return result
    end
end

local function createDeferredRewardReader(deps)
    local reader, loading, retryAt = nil, false, 0
    return function(keysOnly)
        if not deps.alive() then return nil end
        if reader then return reader(keysOnly) end
        if not loading and deps.now() >= retryAt then
            loading = true
            deps.defer(function()
                if not deps.alive() then loading = false return end
                local ok, result = pcall(deps.load)
                if deps.alive() and ok and type(result) == "function" then reader = result end
                loading = false
                if not reader then retryAt = deps.now() + 2 end
            end)
        end
        return nil
    end
end


local function createRewardRecognizer(animals)
    local names = {}
    if type(animals) == "table" then
        for name in pairs(animals) do
            if type(name) == "string" and name ~= "" and #name <= 512 then
                names[#names + 1] = {name = name, text = name:lower():gsub("%s+", " ")}
            end
        end
    end
    table.sort(names, function(a, b) return #a.text == #b.text and a.text < b.text or #a.text > #b.text end)
    local function wordByte(value) return value ~= "" and value:match("[%w_\128-\255]") ~= nil end
    local function listGap(value)
        if value:find("[%.!?;:]") then return false end
        value = value:gsub("%f[%a]and%f[%A]", ""):gsub("[%s,'\"&]", "")
        return value == ""
    end
    return function(message)
        if type(message) ~= "string" then return nil end
        local text = message:gsub("&amp;", "&"):gsub("&apos;", "'"):gsub("&quot;", '"')
            :gsub("<[^>]*>", ""):lower():gsub("%s+", " ")
        if not text:match("%f[%a]spawned%f[%A]") and not text:match("%f[%a]received%f[%A]") then return nil end

        for _, negative in ipairs({"not", "failed", "cannot", "invalid", "unable", "error"}) do
            if text:match("%f[%a]" .. negative .. "%f[%A]") then return nil end
        end
        if text:find("can't", 1, true) or text:find("couldn't", 1, true) or text:find("wasn't", 1, true) then return nil end
        local matches = {}

        for _, entry in ipairs(names) do
            local from = 1
            while true do
                local first, last = text:find(entry.text, from, true)
                if not first then break end
                from = last + 1
                if not wordByte(text:sub(first - 1, first - 1)) and not wordByte(text:sub(last + 1, last + 1)) then
                    local overlap = false
                    for _, existing in ipairs(matches) do
                        if first <= existing.last and last >= existing.first then overlap = true break end
                    end
                    if not overlap then matches[#matches + 1] = {first = first, last = last, name = entry.name} end
                end
            end
        end
        table.sort(matches, function(a, b) return a.first < b.first end)
        for _, entry in ipairs(matches) do
            local before = text:sub(1, entry.first - 1):gsub("['\"]", "")
            local after = text:sub(entry.last + 1):gsub("^['\"]", "")
            for _, verb in ipairs({"spawned", "received"}) do
                for _, article in ipairs({"", "a", "an", "the"}) do
                    local ending = article == "" and (verb .. "%s+$") or (verb .. "%s+" .. article .. "%s+$")
                    if before:match("%f[%a]" .. ending) then entry.reliable = true end
                end
            end
            for _, prefix in ipairs({"has%s+been", "have%s+been", "was", "were"}) do
                if after:match("^%s+" .. prefix .. "%s+spawned%f[%A]")
                    or after:match("^%s+" .. prefix .. "%s+successfully%s+spawned%f[%A]") then entry.reliable = true end
            end
            if after:match("^%s+spawned%f[%A]") then entry.reliable = true end
        end
        for index = 2, #matches do
            local previous, current = matches[index - 1], matches[index]
            if previous.reliable and listGap(text:sub(previous.last + 1, current.first - 1)) then current.reliable = true end
        end
        for index = #matches - 1, 1, -1 do
            local current, following = matches[index], matches[index + 1]
            if following.reliable and listGap(text:sub(current.last + 1, following.first - 1)) then current.reliable = true end
        end
        local result, seen = {}, {}
        for _, entry in ipairs(matches) do
            if entry.reliable and not seen[entry.name] then result[#result + 1], seen[entry.name] = entry.name, true end
        end
        return #result > 0 and table.concat(result, ", ") or nil, #result > 0 and result or nil
    end
end

local function createHelper(integration)
local Config = {
    Name = "StormHub AA Helper",
    ScanInterval = 0.2,
    PurchaseInterval = 0.45,
    RetryInterval = 2,
    ConfirmationWindow = 8,
    FreezeDrainTime = 1.15,
    QuickGrabScanInterval = 0.5,
    QuickGrabDebounce = 0.35,
}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
if not player then return nil, "AA Helper is waiting for your player." end

local env = integration.env
local key = "__stormhub_aa_helper"
local previous = env[key] or env.__strawberry_aa_helper
if previous and type(previous.stop) == "function" then pcall(previous.stop) end
pcall(function()
    for _, name in ipairs({"StormHubAAHelper", "StrawberryAAHelper"}) do
        local old = player.PlayerGui:FindFirstChild(name)
        if old then old:Destroy() end
    end
end)

local state = {
    alive = true, frozen = false, releasing = false, antiRagdoll = false,
    autoBuy = false, quickGrab = false, quickSell = false,
    generation = 0, ragdollGeneration = 0, frozenAt = 0, confirmed = 0, attempts = 0,
    lastPurchase = -math.huge, buyerMessage = "Auto buy off",
    connections = {}, prompts = {},
    grabGeneration = 0, grabAttempts = 0, placeAttempts = 0, sellAttempts = 0, lastGrabScan = -math.huge,
    grabPrompts = {}, grabConnections = {},
}
env[key] = state
local refreshUI = function()
    if state.alive and integration.changed then integration.changed(state) end
end
local buyerThread, freezeRecord, combatPatch, ragdollPatch, ensureLoop
local ragdollRecord
local ragdollStates = {
    Enum.HumanoidStateType.Physics,
    Enum.HumanoidStateType.Ragdoll,
    Enum.HumanoidStateType.FallingDown,
}

local function ragdollActive()
    local endTime = player:GetAttribute("RagdollEndTime")
    return type(endTime) == "number" and endTime > workspace:GetServerTimeNow()
end

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    state.connections[#state.connections + 1] = connection
    return connection
end

local function ownerId(prompt)
    local value = prompt:GetAttribute("TargetPlayer")
    if typeof(value) == "Instance" and value:IsA("Player") then return value.UserId end
    return tonumber(value)
end

local function sourceAnimal(prompt)
    local item = prompt.Parent
    while item and item ~= workspace do
        if CollectionService:HasTag(item, "Animal") then return item end
        item = item.Parent
    end
end

local function animalName(prompt)
    local source = sourceAnimal(prompt)
    return tostring((source and source:GetAttribute("Index")) or prompt.ObjectText or "brainrot"):sub(1, 40)
end

local function promptPosition(prompt)
    local parent = prompt.Parent
    if parent and parent:IsA("Attachment") then return parent.WorldPosition end
    if parent and parent:IsA("BasePart") then return parent.Position end
    local source = sourceAnimal(prompt)
    if source and source:IsA("Model") then return source:GetPivot().Position end
    if source and source:IsA("BasePart") then return source.Position end
end

local function forgetPrompt(prompt)
    local entry = state.prompts[prompt]
    if not entry then return end
    if entry.ownerConnection then entry.ownerConnection:Disconnect() end
    state.prompts[prompt] = nil
end

local function watchPrompt(prompt)
    if not prompt:IsA("ProximityPrompt") or state.prompts[prompt] then return end
    local entry = {owner = ownerId(prompt), lastAttempt = -math.huge}
    state.prompts[prompt] = entry
    entry.ownerConnection = prompt:GetAttributeChangedSignal("TargetPlayer"):Connect(function()
        if not state.alive then return end
        local current = ownerId(prompt)
        if current ~= entry.owner then
            entry.owner = current
            entry.lastAttempt = -math.huge
            if current == player.UserId and entry.pendingAt
                and os.clock() - entry.pendingAt <= Config.ConfirmationWindow then
                entry.pendingAt = nil
                state.confirmed += 1
                state.buyerMessage = "Bought " .. animalName(prompt)
                refreshUI()
            end
        end
    end)
end

local function reconcilePrompts()
    for _, prompt in ipairs(CollectionService:GetTagged("AnimalPurchasePrompt")) do watchPrompt(prompt) end
    for prompt in pairs(state.prompts) do
        if not prompt.Parent or not CollectionService:HasTag(prompt, "AnimalPurchasePrompt") then
            forgetPrompt(prompt)
        end
    end
end

local function restoreCombat()
    local patch = combatPatch
    combatPatch = nil
    if patch then
        pcall(function()
            if patch.module.ApplyImpulse == patch.wrapper then patch.module.ApplyImpulse = patch.original end
        end)
    end
end

local function patchCombat(generation)
    if not state.alive or not state.frozen or state.generation ~= generation or combatPatch then return end
    local controllers = ReplicatedStorage:FindFirstChild("Controllers")
    local scriptObject = controllers and controllers:FindFirstChild("CombatController")
    if not scriptObject then return end
    local ok, controller = pcall(require, scriptObject)
    if not state.alive or not state.frozen or state.generation ~= generation or combatPatch then return end
    if not ok or type(controller) ~= "table" or type(controller.ApplyImpulse) ~= "function" then return end
    local original = controller.ApplyImpulse
    local function wrapper(self, ...)
        if state.frozen or state.releasing then return end
        return original(self, ...)
    end
    local assigned = pcall(function() controller.ApplyImpulse = wrapper end)
    if assigned then
        combatPatch = {module = controller, original = original, wrapper = wrapper}
        state.frozenAt = os.clock()
    end
end

local function restoreRagdoll()
    local patch = ragdollPatch
    ragdollPatch = nil
    if not patch then return end
    pcall(function()
        if patch.module.ToggleControls == patch.toggleWrapper then
            patch.module.ToggleControls = patch.originalToggle
        end
    end)
    pcall(function()
        if patch.module.IsInRagdoll == patch.queryWrapper then
            patch.module.IsInRagdoll = patch.originalQuery
        end
    end)

    if patch.blockedControls and ragdollActive() then
        pcall(patch.originalToggle, patch.module, false)
    end
end

local function patchRagdoll(generation)
    if not state.alive or not state.antiRagdoll or state.ragdollGeneration ~= generation or ragdollPatch then return end
    local controllers = ReplicatedStorage:FindFirstChild("Controllers")
    local scriptObject = controllers and controllers:FindFirstChild("RagdollController")
    if not scriptObject then return end
    local ok, controller = pcall(require, scriptObject)
    if not state.alive or not state.antiRagdoll or state.ragdollGeneration ~= generation or ragdollPatch then return end
    if not ok or type(controller) ~= "table" or type(controller.ToggleControls) ~= "function"
        or type(controller.IsInRagdoll) ~= "function" then return end
    local patch = {module = controller, originalToggle = controller.ToggleControls,
        originalQuery = controller.IsInRagdoll, blockedControls = false}
    patch.toggleWrapper = function(self, enabled, ...)
        if not enabled and state.antiRagdoll then
            patch.blockedControls = true
            return
        end
        return patch.originalToggle(self, enabled, ...)
    end
    patch.queryWrapper = function(self, ...)
        if state.antiRagdoll then return false end
        return patch.originalQuery(self, ...)
    end
    ragdollPatch = patch
    local assigned, err = pcall(function()
        controller.ToggleControls = patch.toggleWrapper
        controller.IsInRagdoll = patch.queryWrapper
        if ragdollActive() then
            patch.blockedControls = true
            patch.originalToggle(controller, true)
        end
    end)
    if not assigned then
        state.lastError = tostring(err)
        restoreRagdoll()
    end
end

local function guardRagdoll(record)
    if ragdollRecord ~= record or not state.antiRagdoll or record.guarding then return end
    local humanoid = record.humanoid
    if not humanoid.Parent or humanoid.Health <= 0 then return end
    record.guarding = true
    if humanoid.PlatformStand then humanoid.PlatformStand = false end
    local current = humanoid:GetState()
    local recover = current == Enum.HumanoidStateType.PlatformStanding
    for _, kind in ipairs(ragdollStates) do
        if humanoid:GetStateEnabled(kind) then humanoid:SetStateEnabled(kind, false) end
        if current == kind then recover = true end
    end
    if recover then humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
    local camera = workspace.CurrentCamera
    local head = record.character:FindFirstChild("Head")
    if camera and head and camera.CameraSubject == head then
        record.cameras[camera] = head
        camera.CameraSubject = humanoid
    end
    record.guarding = false
end

local function restoreRagdollCharacter()
    local record = ragdollRecord
    ragdollRecord = nil
    if not record then return end
    if record.stateChanged then record.stateChanged:Disconnect() end
    if record.platformChanged then record.platformChanged:Disconnect() end
    local humanoid = record.humanoid
    if humanoid and humanoid.Parent then
        pcall(function()
            for kind, enabled in pairs(record.stateEnabled) do humanoid:SetStateEnabled(kind, enabled) end
            humanoid.PlatformStand = record.platformStand
        end)
    end
    local stillRagdolled = ragdollActive()
    for camera, head in pairs(record.cameras) do
        pcall(function()
            if camera.CameraSubject == humanoid and stillRagdolled and head.Parent then
                camera.CameraSubject = head
            end
        end)
    end
    if humanoid and humanoid.Parent and humanoid.Health > 0 then
        pcall(function()
            if stillRagdolled and humanoid:GetStateEnabled(Enum.HumanoidStateType.Physics) then
                humanoid:ChangeState(Enum.HumanoidStateType.Physics)
            elseif not stillRagdolled and not record.platformStand then
                humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end)
    end
end

local function protectRagdollCharacter(character)
    if not state.alive or not state.antiRagdoll or not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end
    if ragdollRecord and ragdollRecord.character == character then return end
    restoreRagdollCharacter()
    local record = {character = character, humanoid = humanoid, platformStand = humanoid.PlatformStand,
        stateEnabled = {}, cameras = {}}
    ragdollRecord = record
    for _, kind in ipairs(ragdollStates) do record.stateEnabled[kind] = humanoid:GetStateEnabled(kind) end
    record.stateChanged = humanoid.StateChanged:Connect(function() guardRagdoll(record) end)
    record.platformChanged = humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(function()
        if humanoid.PlatformStand then guardRagdoll(record) end
    end)
    guardRagdoll(record)
end

local function restoreCharacter()
    local record = freezeRecord
    freezeRecord = nil
    if not record then return end
    if record.added then record.added:Disconnect() end
    if record.removing then record.removing:Disconnect() end
    if record.humanoid and record.humanoid.Parent then
        pcall(function() record.humanoid.AutoRotate = record.autoRotate end)
    end
    for part, anchored in pairs(record.parts) do
        pcall(function()
            part.AssemblyLinearVelocity = Vector3.zero
            part.AssemblyAngularVelocity = Vector3.zero
            part.Anchored = anchored
        end)
    end
    pcall(function()
        if player:GetAttribute("FreezeLocalMovement") == true then
            player:SetAttribute("FreezeLocalMovement", record.movementAttribute)
        end
    end)
end

local function freezeCharacter(character)
    if not state.alive or not state.frozen or not character then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 then return end
    if freezeRecord and freezeRecord.character == character then return end
    restoreCharacter()
    local record = {
        character = character, parts = {}, humanoid = humanoid,
        autoRotate = humanoid.AutoRotate,
        movementAttribute = player:GetAttribute("FreezeLocalMovement"),
    }
    freezeRecord = record
    state.frozenAt = os.clock()
    local function anchorPart(part)
        if not part:IsA("BasePart") or freezeRecord ~= record then return end
        if record.parts[part] == nil then record.parts[part] = part.Anchored end
        part.AssemblyLinearVelocity = Vector3.zero
        part.AssemblyAngularVelocity = Vector3.zero
        part.Anchored = true
    end
    for _, part in ipairs(character:GetDescendants()) do anchorPart(part) end
    record.added = character.DescendantAdded:Connect(anchorPart)
    record.removing = character.DescendantRemoving:Connect(function(part)
        local original = record.parts[part]
        if original == nil then return end
        record.parts[part] = nil
        pcall(function() part.Anchored = original end)
    end)
    humanoid.AutoRotate = false
    player:SetAttribute("FreezeLocalMovement", true)
end

local function setFrozen(enabled)
    state.generation += 1
    local generation = state.generation
    if enabled then
        state.frozen, state.releasing = true, false
        state.frozenAt = os.clock()
        freezeCharacter(player.Character)

        task.defer(function() patchCombat(generation) end)
    else
        state.frozen = false
        local remaining = math.max(0, Config.FreezeDrainTime - (os.clock() - state.frozenAt))
        state.releasing = freezeRecord ~= nil and remaining > 0
        local function release()
            if not state.alive or state.generation ~= generation or state.frozen then return end
            state.releasing = false
            restoreCharacter()
            restoreCombat()
            refreshUI()
        end
        if state.releasing then task.delay(remaining, release) else release() end
    end
    refreshUI()
end

local function setAntiRagdoll(enabled)
    state.ragdollGeneration += 1
    local generation = state.ragdollGeneration
    state.antiRagdoll = enabled
    if enabled then
        protectRagdollCharacter(player.Character)
        task.defer(function() patchRagdoll(generation) end)
    else
        restoreRagdollCharacter()
        restoreRagdoll()
    end
    refreshUI()
end

local function setAutoBuy(enabled)
    local adapter = fireproximityprompt or fire_proximity_prompt
    if enabled and type(adapter) ~= "function" then
        state.autoBuy = false
        state.buyerMessage = "Executor needs fireproximityprompt"
    else
        state.autoBuy = enabled
        state.buyerMessage = enabled and "Watching moving brainrots..." or "Auto buy off"
    end
    if state.autoBuy then ensureLoop() end
    refreshUI()
end

local function purchaseStep()
    if not state.autoBuy or not state.alive then return end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 then
        state.buyerMessage = "Waiting for your character..."
        return
    end
    local now = os.clock()
    if now - state.lastPurchase < Config.PurchaseInterval then return end
    local target
    local distant = false
    for prompt, entry in pairs(state.prompts) do
        if prompt:IsDescendantOf(workspace) and prompt.Enabled
            and prompt:GetAttribute("Disabled") ~= true and prompt:GetAttribute("UID") ~= nil
            and ownerId(prompt) ~= player.UserId and sourceAnimal(prompt)
            and now - entry.lastAttempt >= Config.RetryInterval then
            local position = promptPosition(prompt)
            if position then
                local distance = (position - root.Position).Magnitude
                if distance <= prompt.MaxActivationDistance then
                    local redirected = ownerId(prompt) ~= nil
                    if not target or entry.lastAttempt < target.entry.lastAttempt
                        or (entry.lastAttempt == target.entry.lastAttempt and
                            ((redirected and not target.redirected)
                            or (redirected == target.redirected and distance < target.distance))) then
                        target = {prompt = prompt, entry = entry, distance = distance, redirected = redirected}
                    end
                else
                    distant = true
                end
            end
        end
    end
    if not target then
        state.buyerMessage = distant and "Move closer to a moving brainrot" or "Waiting for an available brainrot..."
        return
    end

    target.entry.lastAttempt, target.entry.pendingAt = now, now
    state.lastPurchase = now
    state.attempts += 1
    local adapter = fireproximityprompt or fire_proximity_prompt
    local ok, err = pcall(adapter, target.prompt)
    if ok and target.entry.pendingAt and ownerId(target.prompt) ~= player.UserId then
        state.buyerMessage = "Trying " .. animalName(target.prompt)
    elseif not ok then
        target.entry.pendingAt = nil
        state.buyerMessage = "Purchase prompt unavailable"
        state.lastError = tostring(err)
    end
end

local function ownPlot()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return end
    local found
    for _, plot in ipairs(plots:GetChildren()) do
        if plot:GetAttribute("Loaded") == true and CollectionService:HasTag(plot, "Plot") then
            local sign = plot:FindFirstChild("PlotSign")
            local marker = sign and sign:FindFirstChild("YourBase")
            if marker and marker:IsA("BillboardGui") and marker.Enabled then
                if found then return end
                found = plot
            end
        end
    end
    return found
end

local function podiumAction(prompt, plot, action)
    if not plot or not prompt.Parent or not prompt:IsA("ProximityPrompt")
        or not prompt.Enabled or prompt:GetAttribute("State") ~= action
        or CollectionService:HasTag(prompt, "AnimalPurchasePrompt") then return false end
    local podiums = plot:FindFirstChild("AnimalPodiums")
    local attachment = prompt.Parent
    local spawnPart = attachment and attachment.Parent
    local base = spawnPart and spawnPart.Parent
    local podium = base and base.Parent
    if not podiums or not attachment or not spawnPart or not base or not podium then return false end
    return attachment:IsA("Attachment") and attachment.Name == "PromptAttachment"
        and spawnPart:IsA("BasePart") and spawnPart.Name == "Spawn"
        and base.Name == "Base" and podium.Parent == podiums
        and prompt:IsDescendantOf(podiums)
end

local function quickActionEnabled(action)
    return ((action == "Grab" or action == "Place") and state.quickGrab)
        or (action == "Sell" and state.quickSell)
end

local function forgetGrabPrompt(prompt)
    local entry = state.grabPrompts[prompt]
    if not entry then return end
    entry.connection:Disconnect()
    entry.triggeredConnection:Disconnect()
    state.grabPrompts[prompt] = nil
end

local function clearQuickGrab()
    state.grabGeneration += 1
    for _, connection in ipairs(state.grabConnections) do connection:Disconnect() end
    state.grabConnections = {}
    for prompt in pairs(state.grabPrompts) do forgetGrabPrompt(prompt) end
    state.grabPlot, state.grabContainer = nil, nil
end

local function watchGrabPrompt(prompt)
    if not prompt:IsA("ProximityPrompt") or state.grabPrompts[prompt] then return end
    local entry = {busy = false, lastGrab = -math.huge, triggerVersion = 0}
    state.grabPrompts[prompt] = entry
    entry.triggeredConnection = prompt.Triggered:Connect(function()
        entry.triggerVersion += 1
    end)
    entry.connection = prompt.PromptButtonHoldBegan:Connect(function(triggeringPlayer)
        local action = prompt:GetAttribute("State")
        if not state.alive or not quickActionEnabled(action) or entry.busy
            or os.clock() - entry.lastGrab < Config.QuickGrabDebounce then return end
        if triggeringPlayer and triggeringPlayer ~= player then return end
        local plot = ownPlot()
        if plot ~= state.grabPlot or not podiumAction(prompt, plot, action) then return end
        local generation = state.grabGeneration
        local triggerVersion = entry.triggerVersion
        entry.busy = true

        task.defer(function()
            local function eligible()
                if not state.alive or not quickActionEnabled(action) or state.grabGeneration ~= generation
                    or state.grabPrompts[prompt] ~= entry or ownPlot() ~= plot
                    or entry.triggerVersion ~= triggerVersion
                    or not podiumAction(prompt, plot, action) then return false end
                local character = player.Character
                local root = character and character:FindFirstChild("HumanoidRootPart")
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                local position = promptPosition(prompt)
                return root ~= nil and humanoid ~= nil and humanoid.Health > 0 and position ~= nil
                    and (position - root.Position).Magnitude <= prompt.MaxActivationDistance
            end
            local ok, err = pcall(function()
                if not eligible() then return end

                prompt:InputHoldEnd()
                if not eligible() then return end
                entry.lastGrab = os.clock()
                local fire = firesignal or fire_signal
                if type(fire) ~= "function" then error("Quick " .. action .. " requires firesignal") end
                if action == "Sell" then
                    state.sellAttempts += 1
                elseif action == "Place" then
                    state.placeAttempts += 1
                else
                    state.grabAttempts += 1
                end

                fire(prompt.Triggered, player)
            end)
            entry.busy = false
            if not ok then state.lastError = tostring(err) end
            refreshUI()
        end)
    end)
end

local function syncQuickGrab()
    if not state.alive or not (state.quickGrab or state.quickSell) then return end
    local plot = ownPlot()
    local podiums = plot and plot:FindFirstChild("AnimalPodiums")
    if plot == state.grabPlot and podiums == state.grabContainer then return end
    clearQuickGrab()
    if not plot or not podiums then return end
    state.grabPlot, state.grabContainer = plot, podiums
    state.grabConnections[#state.grabConnections + 1] = podiums.DescendantAdded:Connect(watchGrabPrompt)
    state.grabConnections[#state.grabConnections + 1] = podiums.DescendantRemoving:Connect(forgetGrabPrompt)
    for _, object in ipairs(podiums:GetDescendants()) do watchGrabPrompt(object) end
end

local function setQuickGrab(enabled)
    if enabled and type(firesignal or fire_signal) ~= "function" then
        state.lastError = "Quick Grab / Place requires firesignal"
        warn(Config.Name .. ": " .. state.lastError)
        return
    end
    state.quickGrab = enabled
    clearQuickGrab()
    if state.quickGrab or state.quickSell then syncQuickGrab() ensureLoop() end
    refreshUI()
end

local function setQuickSell(enabled)
    if enabled and type(firesignal or fire_signal) ~= "function" then
        state.lastError = "Quick Sell requires firesignal"
        warn(Config.Name .. ": " .. state.lastError)
        return
    end
    state.quickSell = enabled
    clearQuickGrab()
    if state.quickGrab or state.quickSell then syncQuickGrab() ensureLoop() end
    refreshUI()
end

state.stop = function()
    if state.stopping then
        while state.stopping do task.wait() end
        return
    end
    if not state.alive then return end
    state.stopping = true
    state.alive, state.frozen, state.autoBuy, state.quickGrab, state.quickSell = false, false, false, false, false
    state.antiRagdoll = false
    state.ragdollGeneration += 1
    state.releasing = freezeRecord ~= nil
    state.generation += 1
    clearQuickGrab()
    for _, connection in ipairs(state.connections) do pcall(function() connection:Disconnect() end) end
    for prompt in pairs(state.prompts) do forgetPrompt(prompt) end
    if buyerThread then pcall(task.cancel, buyerThread) buyerThread = nil end
    restoreRagdollCharacter()
    restoreRagdoll()
    local remaining = state.releasing and math.max(0, Config.FreezeDrainTime - (os.clock() - state.frozenAt)) or 0
    if remaining > 0 then task.wait(remaining) end
    restoreCharacter()
    restoreCombat()
    state.releasing, state.stopping = false, false
    if env[key] == state then env[key] = nil end
end

ensureLoop = function()
    if buyerThread or not state.alive then return end
    buyerThread = task.spawn(function()
        local lastReconcile = -math.huge
        while state.alive and (state.autoBuy or state.quickGrab or state.quickSell) do
            if (state.quickGrab or state.quickSell) and os.clock() - state.lastGrabScan >= Config.QuickGrabScanInterval then
                state.lastGrabScan = os.clock()
                local grabOk, grabError = pcall(syncQuickGrab)
                if not grabOk then state.lastError = tostring(grabError) end
            end
            if state.autoBuy then
                if os.clock() - lastReconcile >= 2 then
                    local ok = pcall(reconcilePrompts)
                    lastReconcile = os.clock()
                    if not ok then state.buyerMessage = "Waiting for purchase prompts..." end
                end
                local ok, err = pcall(purchaseStep)
                if not ok then state.lastError = tostring(err) state.buyerMessage = "Waiting for purchase prompts..." end
                refreshUI()
            end
            task.wait(Config.ScanInterval)
        end
        buyerThread = nil
    end)
end

connect(player.CharacterRemoving, function(character)
    if freezeRecord and freezeRecord.character == character then restoreCharacter() end
    if ragdollRecord and ragdollRecord.character == character then restoreRagdollCharacter() end
    refreshUI()
end)
connect(player.CharacterAdded, function(character)
    if not (state.frozen or state.antiRagdoll) then return end
    local generation = state.generation
    local ragdollGeneration = state.ragdollGeneration
    task.spawn(function()
        character:WaitForChild("HumanoidRootPart", 10)
        character:WaitForChild("Humanoid", 10)
        if state.alive and player.Character == character then
            if state.frozen and state.generation == generation then freezeCharacter(character) end
            if state.antiRagdoll and state.ragdollGeneration == ragdollGeneration then protectRagdollCharacter(character) end
            refreshUI()
        end
    end)
end)
connect(RunService.Heartbeat, function()
    if not (state.frozen or state.releasing or state.antiRagdoll) then return end
    if state.frozen and not freezeRecord then freezeCharacter(player.Character) end
    if state.antiRagdoll then
        if not ragdollRecord then protectRagdollCharacter(player.Character) end
        if ragdollRecord then guardRagdoll(ragdollRecord) end
    end
    local record = freezeRecord
    if not record or not (state.frozen or state.releasing) then return end
    for part in pairs(record.parts) do
        if part.Parent and part:IsDescendantOf(record.character) then
            part.Anchored = true
            part.AssemblyLinearVelocity = Vector3.zero
            part.AssemblyAngularVelocity = Vector3.zero
        end
    end
end)
connect(CollectionService:GetInstanceAddedSignal("AnimalPurchasePrompt"), watchPrompt)
connect(CollectionService:GetInstanceRemovedSignal("AnimalPurchasePrompt"), forgetPrompt)
state.setFrozen, state.setAntiRagdoll, state.setAutoBuy = setFrozen, setAntiRagdoll, setAutoBuy
state.setQuickGrab, state.setQuickSell = setQuickGrab, setQuickSell
return state
end

if not player then
    local deadline = os.clock() + 20
    repeat
        task.wait(0.1)
        player = Players.LocalPlayer
    until player or os.clock() >= deadline
end
if not player then
    startup.closeCapture()
    warn(Config.ProductName .. ": run in a client")
    return
end
local playerGui = player:WaitForChild("PlayerGui", 20)
if not playerGui or env.__stormhub_startup_owner ~= startup then
    startup.closeCapture()
    return
end
if previous and not stopped then
    previous.alive = false
    for _, connection in ipairs(previous.connections or {}) do pcall(connection.Disconnect, connection) end
    for _, undo in ipairs(previous.restore or {}) do pcall(undo) end
    for thread in pairs(previous.jobs or {}) do pcall(task.cancel, thread) end
end

local Input = game:GetService("UserInputService")
local Tween = game:GetService("TweenService")

local Paths = {
    settings = Config.Folder .. "/settings.json",
    history = Config.Folder .. "/redeemed.json",
    configs = Config.Folder .. "/configs",
}

local saved = Files.decode(Files.read(Paths.settings)) or {}
if previousSnapshot then
    for key, value in pairs(previousSnapshot) do saved[key] = value end
end

local history = {}
do
    local raw = Files.decode(Files.read(Paths.history))
    if type(raw) == "table" then
        for _, entry in ipairs(raw) do
            if type(entry) == "table" and type(entry.code) == "string" and type(entry.at) == "number" then
                history[#history + 1] = {
                    code = entry.code:sub(1, 60), at = entry.at, sent = true,
                    reward = type(entry.reward) == "string" and entry.reward:sub(1, 80) or nil,
                    mutation = type(entry.mutation) == "string" and entry.mutation:sub(1, 40) or nil,
                    message = type(entry.message) == "string" and entry.message:sub(1, 200) or "",
                }
                if #history >= Config.HistoryLimit then break end
            end
        end
    end
end

local function validKey(name)
    if type(name) ~= "string" or name == "" then return nil end
    local ok, value = pcall(function() return Enum.KeyCode[name] end)
    return ok and value and name or nil
end

local S = {
    alive = true, connections = {}, jobs = {}, restore = {},
    ledger = type(saved.submissionLedger) == "table" and saved.submissionLedger or {},
    retypeSafety = false, retypeBatch = false,
    theme = ((tonumber(saved.themeRevision) or 0) >= 4 and type(saved.theme) == "string" and saved.theme ~= "grape") and saved.theme or "avengers",
    winter = (tonumber(saved.themeRevision) or 0) >= 4 and saved.winter == true,
    avengers = saved.avengers == true,
    intro = saved.intro ~= false,
    uiScale = tonumber(saved.uiScale),
    style = tonumber(saved.style) == 2 and 2 or 1,
    autoload = type(saved.autoload) == "string" and saved.autoload or nil,
    binds = {},
    tab = type(saved.tab) == "string" and saved.tab or "redeem",
    hidden = false, session = 0,
    layoutVersion = tonumber(saved.version) or 0,
}
if type(saved.binds) == "table" and S.layoutVersion >= 3 then
    S.binds = {}
    for id, name in pairs(saved.binds) do
        if type(id) == "string" then S.binds[id] = validKey(name) end
    end
end
env[KEY] = S
startup.hub = S

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    if S.alive then S.connections[#S.connections + 1] = connection
    else pcall(connection.Disconnect, connection) end
    return connection
end

local hubIdentity, setIdentity
do
    local getter = getthreadidentity or getidentity or get_thread_identity
    setIdentity = setthreadidentity or setidentity or set_thread_identity
    if type(getter) == "function" and type(setIdentity) == "function" then
        local ok, value = pcall(getter)
        if ok and type(value) == "number" then hubIdentity = value end
    end
end
local function elevate()
    if hubIdentity then pcall(setIdentity, hubIdentity) end
end

local function after(seconds, callback)
    local thread
    thread = task.delay(seconds, function()
        elevate()
        S.jobs[thread] = nil
        if S.alive then callback() end
    end)
    S.jobs[thread] = true
    return thread
end

local function defer(callback)
    local thread
    thread = task.defer(function()
        elevate()
        S.jobs[thread] = nil
        if S.alive then callback() end
    end)
    S.jobs[thread] = true
    return thread
end

local function cancelJob(thread)
    if not thread then return end
    S.jobs[thread] = nil
    pcall(task.cancel, thread)
end

local function titleCase(value)
    return (tostring(value or ""):gsub("%a[%w']*", function(word)
        return word:sub(1, 1):upper() .. word:sub(2):lower()
    end))
end

local function stripTags(value)
    return (tostring(value or ""):gsub("<[^>]*>", ""):gsub("&lt;", "<"):gsub("&gt;", ">")
        :gsub("&quot;", '"'):gsub("&apos;", "'"):gsub("&amp;", "&"))
end

local Code = {
    box = nil, button = nil, buttonConnected = false, boxReady = false, boxConnection = nil,
    flight = nil, enabled = true, remote = nil, notification = nil, script = nil, flags = nil,
    readyReason = "Connecting To Game...", responses = false,
    announceConnection = nil, watchConnection = nil,
}
local engine, rewardHighlighter, requestRefresh
local Hub = {}

local function capable()
    return type(firesignal) == "function" and type(getconnections) == "function"
        and type(debug) == "table" and type(debug.getupvalues) == "function" and type(debug.info) == "function"
end

local function resolve(rootObject, names)
    local current = rootObject
    for _, name in ipairs(names) do
        current = current and current:FindFirstChild(name)
        if not current then return nil end
    end
    return current
end

function Code.markStart(flight)
    if not flight or flight.startedAt or not flight.box then return end
    local ok, placeholder = pcall(function() return flight.box.PlaceholderText end)
    if ok and tostring(placeholder):lower():find("redeeming", 1, true) then flight.startedAt = os.clock() end
end

local function refreshCodeObjects()
    local box = resolve(playerGui, {"Codes", "Codes", "CodeRedeem", "TextBox"})
    local confirm = resolve(playerGui, {"Codes", "Codes", "Confirm"})
    if not box or not box:IsA("TextBox") or not confirm or not confirm:IsA("GuiButton") then
        if Code.boxConnection then Code.boxConnection:Disconnect() Code.boxConnection = nil end
        if Code.placeholderConnection then Code.placeholderConnection:Disconnect() Code.placeholderConnection = nil end
        Code.box, Code.button, Code.buttonConnected, Code.boxReady = nil, nil, false, false
        return
    end
    if confirm ~= Code.button then Code.buttonConnected = false end
    if box ~= Code.box then
        if Code.boxConnection then Code.boxConnection:Disconnect() end
        if Code.placeholderConnection then Code.placeholderConnection:Disconnect() end
        Code.box = box
        Code.boxReady = box.Active
        Code.placeholderConnection = connect(box:GetPropertyChangedSignal("PlaceholderText"), function()
            local flight = Code.flight
            if flight and flight.box == box then Code.markStart(flight) end
        end)
        Code.boxConnection = connect(box:GetPropertyChangedSignal("Active"), function()
            if box ~= Code.box then return end
            Code.boxReady = false
            if not box.Active then return end
            defer(function()
                if box ~= Code.box or not box.Active then return end
                Code.boxReady = true
                local missed = Code.flight
                if missed and missed.box == box then
                    Code.flight = nil
                    local ok, err = pcall(missed.callback, false, "Game Reply Not Captured")
                    if not ok then warn(Config.ProductName .. ": " .. tostring(err)) end
                end
                if engine then engine:wake() end
            end)
        end)
    end
    Code.button = confirm
end

local function adapterReady()
    if S.retypeBatch then return false, "Retyping Recent Announcements..." end
    if not Code.remote or not Code.remote:IsDescendantOf(ReplicatedStorage) then
        return false, Code.readyReason or "Waiting For The Announcement Event"
    end
    if not Code.notification or not Code.responses then return false, "Response Listener Unavailable" end
    if not capable() then return false, "Executor Needs Firesignal And Getconnections" end
    if not Code.enabled then return false, "Codes Are Disabled By The Game" end
    if Code.flight or (engine and engine.pending) then return false, "Waiting For The Game To Finish" end
    if not Code.box or not Code.box.Parent or not Code.button or not Code.button.Parent then refreshCodeObjects() end
    if not Code.box or not Code.button then return false, "Waiting For The Game's Code Box" end
    if not Code.box.Active or not Code.boxReady then return false, "Waiting For The Game To Finish" end
    if not Code.buttonConnected then
        Code.buttonConnected = #getconnections(Code.button.Activated) > 0
        if not Code.buttonConnected then return false, "Waiting For The Confirm Button" end
    end
    return true
end

local function pruneLedger()
    local now, count, oldest, oldestAt = os.clock(), 0, nil, math.huge
    for key, value in pairs(S.ledger) do
        if type(value) ~= "table" or type(value.at) ~= "number" or now - value.at > Config.AttemptTTL then
            S.ledger[key] = nil
        else
            count += 1
            if value.at < oldestAt then oldest, oldestAt = key, value.at end
        end
    end
    if count > Config.CacheLimit and oldest then S.ledger[oldest] = nil end
end

local function outcomeOf(success, lower)
    if success then return "success" end
    if lower == "textbox rejected the code" or lower == "confirm button could not be activated"
        or lower == "submission cancelled before confirm" then return "local" end
    if lower:find("sold out", 1, true) or lower:find("out of stock", 1, true) then return "sold_out" end
    if lower:find("expired", 1, true) then return "expired" end
    if lower:find("already", 1, true) and lower:find("redeem", 1, true) then return "used" end
    if lower:find("invalid code", 1, true) or lower:find("code is invalid", 1, true)
        or lower:find("please wait", 1, true) or lower:find("cooldown", 1, true)
        or lower:find("too fast", 1, true) or lower:find("try again later", 1, true) then return "invalid" end
    return "uncertain"
end

local function submitCode(code, callback)
    local box, confirm = Code.box, Code.button
    local request = engine and engine.pending
    local settled, highlightAttempt, sentAt, flight = false, nil, nil, nil
    local record = {at = os.clock(), outcome = "pending",
        replay = S.retypeSafety and S.retypeReplay and S.retypeReplay.generation or nil}
    S.ledger[code] = record
    local function completed(success, message)
        if settled then return end
        settled = true
        if sentAt and Hub.flagCheck then
            local elapsed = os.clock() - (flight and flight.startedAt or sentAt)
            local existing = Hub.codeExists(success, message)
            defer(function() pcall(Hub.flagCheck, code, elapsed, existing) end)
        end
        record.outcome = outcomeOf(success, tostring(message or ""):lower())
        local callbackOk, callbackError = pcall(callback, success, message)
        if success then
            local text = tostring(message or "")
            defer(function() pcall(Hub.onRedeemed, code, text) end)
        end
        if rewardHighlighter and highlightAttempt then
            local attempt = highlightAttempt
            defer(function() pcall(rewardHighlighter.complete, rewardHighlighter, attempt, success == true, message) end)
        end
        if not callbackOk then error(callbackError, 0) end
    end
    if not S.alive or S.closing then completed(false, "Submission Cancelled Before Confirm") return end
    local current = request and engine.pending == request and request.code == code
        and engine.alive and engine.enabled and request.epoch == engine.epoch
    if not current or Code.flight or box ~= Code.box or confirm ~= Code.button
        or not box or not box.Parent or not confirm or not confirm.Parent
        or not box.Active or not Code.boxReady or not Code.enabled then
        completed(false, "Submission Cancelled Before Confirm")
        return
    end
    flight = {callback = completed, box = box, code = code}
    Code.flight = flight
    local wrote, accepted = pcall(function() box.Text = code return box.Text == code end)
    if not wrote or not accepted then
        if Code.flight == flight then Code.flight = nil end
        completed(false, "Textbox Rejected The Code")
        return
    end
    sentAt = os.clock()
    local fired = pcall(firesignal, confirm.Activated)
    if not fired then
        sentAt = nil
        if Code.flight == flight then Code.flight = nil end
        completed(false, "Confirm Button Could Not Be Activated")
        return
    end
    Code.markStart(flight)
    if rewardHighlighter and not settled then
        local ok, token = pcall(rewardHighlighter.begin, rewardHighlighter, code)
        if ok then highlightAttempt = token end
    end
    defer(pruneLedger)
end

engine = createEngine(Config, {
    now = os.clock, after = after, defer = defer, cancel = cancelJob,
    changed = function() if requestRefresh then requestRefresh() end end,
    ready = adapterReady,
    clearTextbox = function()
        local box = Code.box
        if box and box.Parent and box.Active and not Code.flight then box.Text = "" end
    end,
    submit = submitCode,
    skipReplayCode = function(code) return S.skipReplayCode and S.skipReplayCode(code) end,
}, saved)
S.engine = engine

S.skipReplayCode = function(code)
    local record = S.ledger[code]
    if not record then return false end
    if record.outcome == "pending" or record.outcome == "uncertain" then return true end
    local generation = S.retypeReplay and S.retypeReplay.generation
    return S.retypeSafety and record.outcome ~= "local" and record.replay ~= generation
end

local rewardRecognizer
local function recognizeReward(message)
    if not rewardRecognizer then
        local animalsData
        pcall(function()
            local datas = ReplicatedStorage:FindFirstChild("Datas")
            local animals = datas and datas:FindFirstChild("Animals")
            if animals then animalsData = require(animals) end
        end)
        rewardRecognizer = createRewardRecognizer(animalsData)
    end
    return rewardRecognizer(message)
end

do
    local readAnimals = createDeferredRewardReader({
        now = os.clock, defer = defer,
        alive = function() return S.alive and not S.closing end,
        load = function()
            local controllers = ReplicatedStorage:FindFirstChild("Controllers")
            local module = controllers and controllers:FindFirstChild("AnimalController")
            if not module or not module:IsA("ModuleScript") then return nil end
            local ok, controller = pcall(require, module)
            if not S.alive or S.closing or not ok or type(controller) ~= "table" then return nil end
            return createRewardAnimalReader(controller, player.UserId, function(connection)
                if S.alive then S.connections[#S.connections + 1] = connection
                else pcall(connection.Disconnect, connection) end
            end)
        end,
    })
    rewardHighlighter = createRewardHighlighter(Config, {
        now = os.clock, after = after, cancel = cancelJob, defer = defer,
        keySnapshotOwned = true,
        parent = workspace, localUserId = player.UserId,
        readAnimals = readAnimals,
        rewardNames = function(message)
            local _, names = recognizeReward(message)
            return names
        end,
        marked = function(record) if Hub.onRewardSpawned then Hub.onRewardSpawned(record) end end,
    })
    after(1, function() pcall(rewardHighlighter.prime, rewardHighlighter) end)
end

S.retypeReplay = createRetypeReplay(Config, {
    now = os.clock,
    blocked = function()
        return Code.flight ~= nil or engine.pending ~= nil, "A Game Request Is Still Pending"
    end,
    modeEnabled = function() return engine.enabled or engine.autoMode end,
    beginBatch = function() S.retypeBatch, S.retypeSafety = true, true end,
    resetCollections = function() engine:clear(false) end,
    dispatch = function(...) S.route(true, ...) end,
    endBatch = function(ok)
        S.retypeBatch = false
        if ok then engine:wake() end
        if requestRefresh then requestRefresh() end
    end,
})

S.route = function(replayed, message, duration, sound, location, sender, id, remove)
    if not S.alive or not engine then return false end
    if remove or location ~= "Top" or type(message) ~= "string" or tonumber(sender) ~= Config.SammyUserId then return false end
    if not replayed then S.retypeSafety = false end
    if Config.FastAnnouncementPath and engine.enabled then
        local accepted = engine:tryCodePart(message, duration, sound, location, sender, id, remove)
        if accepted ~= nil then return accepted end
    end
    return engine:receive(message, duration, sound, location, sender, id, remove)
end

S.fps = createFPSController(function()
    if requestRefresh then requestRefresh() end
end)
-- If an older copy is still undoing its FPS boost in the background, wait for it before boosting again.
function S.waitPreviousFPS()
    local deadline = os.clock() + 30
    while previous and previous.fpsRestoring and S.alive and os.clock() < deadline do task.wait(0.1) end
end

local helperState
local function helper()
    if helperState and helperState.alive then return helperState end
    local ok, result = pcall(createHelper, {
        env = env,
        changed = function() if Hub.helperChanged then Hub.helperChanged() end end,
    })
    if ok and type(result) == "table" then helperState = result
    else warn(Config.ProductName .. ": helper unavailable: " .. tostring(result)) end
    return helperState
end
local function helperFlag(name)
    return helperState ~= nil and helperState.alive and helperState[name] == true
end

-- Colors in Settings > Theme. "base" changes the whole window: "black" is pitch black, "light" is a white window.
local Themes = {
    {id = "black", accent = Color3.fromRGB(232, 232, 238), base = "black", swatch = Color3.fromRGB(8, 8, 10)},
    {id = "white", accent = Color3.fromRGB(24, 24, 30), base = "light", swatch = Color3.fromRGB(250, 250, 252)},
    {id = "avengers", accent = Color3.fromRGB(228, 38, 50)},
    {id = "storm", accent = Color3.fromRGB(170, 65, 255)},
    {id = "winter", accent = Color3.fromRGB(105, 186, 255)},
    {id = "rose", accent = Color3.fromRGB(244, 63, 94)},
    {id = "sakura", accent = Color3.fromRGB(255, 121, 176)},
    {id = "mango", accent = Color3.fromRGB(255, 159, 67)},
    {id = "mint", accent = Color3.fromRGB(52, 211, 153)},
    {id = "ocean", accent = Color3.fromRGB(56, 152, 255)},
    {id = "gold", accent = Color3.fromRGB(250, 190, 30)},
    {id = "cyan", accent = Color3.fromRGB(34, 211, 238)},
    {id = "lime", accent = Color3.fromRGB(132, 204, 22)},
    {id = "lavender", accent = Color3.fromRGB(167, 139, 250)},
}
local P = {}
local function buildPalette(id, frost)
    local theme
    for _, item in ipairs(Themes) do if item.id == id then theme = item end end
    if not theme then
        for _, item in ipairs(Themes) do if item.id == "avengers" then theme = item end end
    end
    local a = theme.accent
    P.accent = a
    P.base = theme.base or "dark"
    local k = frost and 2.4 or 1
    P.accentHover = a:Lerp(Color3.new(1, 1, 1), 0.16)
    if P.base == "light" then
        -- White window with dark text.
        P.accentHover = a:Lerp(Color3.new(1, 1, 1), 0.22)
        P.bg = Color3.fromRGB(244, 245, 248)
        P.bgTop = Color3.fromRGB(255, 255, 255)
        P.side = Color3.fromRGB(236, 237, 242)
        P.card = Color3.fromRGB(255, 255, 255)
        P.cardHover = Color3.fromRGB(238, 239, 244)
        P.field = Color3.fromRGB(240, 241, 245)
        P.stroke = Color3.fromRGB(212, 214, 222)
        P.text = Color3.fromRGB(22, 22, 28)
        P.sub = Color3.fromRGB(100, 104, 118)
        P.off = Color3.fromRGB(205, 207, 215)
        P.soft = P.card:Lerp(a, 0.1)
    elseif P.base == "black" then
        -- Pitch-black window with white highlights.
        P.accentHover = a:Lerp(Color3.new(1, 1, 1), 0.5)
        P.bg = Color3.fromRGB(0, 0, 0)
        P.bgTop = Color3.fromRGB(14, 14, 16)
        P.side = Color3.fromRGB(6, 6, 8)
        P.card = Color3.fromRGB(12, 12, 14)
        P.cardHover = Color3.fromRGB(24, 24, 28)
        P.field = Color3.fromRGB(4, 4, 6)
        P.stroke = Color3.fromRGB(42, 42, 48)
        P.text = Color3.fromRGB(245, 245, 248)
        P.sub = Color3.fromRGB(140, 140, 150)
        P.off = Color3.fromRGB(46, 46, 54)
        P.soft = P.card:Lerp(a, 0.14)
    else
        P.bg = Color3.fromRGB(10, 11, 15):Lerp(a, 0.035 * k)
        P.bgTop = Color3.fromRGB(22, 22, 30):Lerp(a, 0.09 * k)
        P.side = Color3.fromRGB(14, 15, 20):Lerp(a, 0.05 * k)
        P.card = Color3.fromRGB(20, 21, 28):Lerp(a, 0.04 * k)
        P.cardHover = Color3.fromRGB(29, 30, 39):Lerp(a, 0.07 * k)
        P.field = Color3.fromRGB(13, 14, 19):Lerp(a, 0.03 * k)
        P.stroke = Color3.fromRGB(42, 44, 56):Lerp(a, 0.16 * k)
        P.text = Color3.fromRGB(241, 243, 248)
        P.sub = frost and Color3.fromRGB(150, 166, 186) or Color3.fromRGB(138, 144, 162)
        P.off = Color3.fromRGB(48, 50, 62)
        P.soft = P.card:Lerp(a, 0.2)
    end
    -- Text on highlight-colored buttons: dark on light highlights (white, gold, lime), white otherwise.
    local brightness = 0.299 * a.R + 0.587 * a.G + 0.114 * a.B
    P.onAccent = brightness > 0.62 and Color3.fromRGB(14, 14, 18) or Color3.new(1, 1, 1)
    P.good = Color3.fromRGB(74, 222, 128)
    P.warn = Color3.fromRGB(250, 204, 21)
    P.bad = Color3.fromRGB(248, 113, 113)
    P.danger = Color3.fromRGB(225, 52, 64)
    P.badHover = Color3.fromRGB(240, 72, 84)
end
buildPalette(S.theme, S.winter)

local painted, themeHooks = {}, {}

-- Avengers theme: panels that turn see-through so the background picture shows.
local Glass = {active = false, items = {}}
function Glass.alpha(normal)
    if not Glass.active then return normal end
    local see = math.clamp(tonumber(Config.AvengersThemeGlass) or 0.35, 0, 0.9)
    return 1 - (1 - normal) * (1 - see)
end
function Glass.add(object, normal)
    Glass.items[#Glass.items + 1] = {object = object, normal = normal}
    object.BackgroundTransparency = Glass.alpha(normal)
    return object
end
function Glass.prune()
    local live = {}
    for _, item in ipairs(Glass.items) do
        if item.object.Parent then live[#live + 1] = item end
    end
    Glass.items = live
end

local function paint(object, property, role)
    painted[#painted + 1] = {object, property, role}
    object[property] = P[role]
end
local function prunePainted()
    local live = {}
    for _, entry in ipairs(painted) do
        if entry[1].Parent then live[#live + 1] = entry end
    end
    painted = live
end

local FontFamily = "rbxasset://fonts/families/BuilderSans.json"
local Weights = {[Enum.Font.Gotham] = Enum.FontWeight.Regular, [Enum.Font.GothamMedium] = Enum.FontWeight.Medium,
    [Enum.Font.GothamBold] = Enum.FontWeight.Bold, [Enum.Font.GothamBlack] = Enum.FontWeight.ExtraBold}

local function make(class, parent, properties, roles)
    local object = Instance.new(class)
    for key, value in pairs(properties or {}) do object[key] = value end
    local weight = properties and properties.Font and Weights[properties.Font]
    if weight then pcall(function() object.FontFace = Font.new(FontFamily, weight) end) end
    if roles then for property, role in pairs(roles) do paint(object, property, role) end end
    object.Parent = parent
    return object
end

local function corner(object, radius)
    return make("UICorner", object, {CornerRadius = UDim.new(0, radius)})
end

local function outline(object, role, transparency, thickness)
    local line = make("UIStroke", object, {Transparency = transparency or 0, Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, {Color = role or "stroke"})
    pcall(function() line.BorderStrokePosition = Enum.BorderStrokePosition.Inner end)
    return line
end

local function padding(object, left, right, top, bottom)
    return make("UIPadding", object, {PaddingLeft = UDim.new(0, left), PaddingRight = UDim.new(0, right or left),
        PaddingTop = UDim.new(0, top or left), PaddingBottom = UDim.new(0, bottom or top or left)})
end

local function label(parent, properties, roles)
    local base = {BackgroundTransparency = 1, BorderSizePixel = 0, Font = Enum.Font.GothamMedium, TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}
    for key, value in pairs(properties) do base[key] = value end
    return make("TextLabel", parent, base, roles or {TextColor3 = "text"})
end

local function animate(object, properties, duration, style, direction)
    local tween = Tween:Create(object, TweenInfo.new(duration or 0.18, style or Enum.EasingStyle.Quint,
        direction or Enum.EasingDirection.Out), properties)
    tween:Play()
    return tween
end

local function sentence(value)
    local text = tostring(value or ""):gsub("%s*\194\183%s*", ", ") -- \194\183 is the middle-dot separator in game messages
    text = text:lower():gsub("sammy", "Sammy"):gsub("fps", "FPS")
    return (text:gsub("^%l", string.upper))
end

local KeyNames = {RightShift = "Right Shift", LeftShift = "Left Shift", RightControl = "Right Ctrl", LeftControl = "Left Ctrl",
    RightAlt = "Right Alt", LeftAlt = "Left Alt", PageUp = "Page Up", PageDown = "Page Down",
    Backquote = "`", Semicolon = ";", Quote = "'", Comma = ",", Period = ".", Slash = "/", BackSlash = "\\",
    LeftBracket = "[", RightBracket = "]", Minus = "-", Equals = "=", One = "1", Two = "2", Three = "3",
    Four = "4", Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9", Zero = "0"}
local function keyText(name)
    if not name then return "None" end
    return KeyNames[name] or name
end

local guiParent = playerGui
if type(gethui) == "function" then
    local ok, container = pcall(gethui)
    if ok and typeof(container) == "Instance" then guiParent = container end
end
for _, container in ipairs({playerGui, guiParent}) do
    for _, child in ipairs(container:GetChildren()) do
        if child.Name == GUI_NAME or child.Name == "StormHubTag" or child.Name == "StrawberryHub" or child.Name == "StrawberryTag" then child:Destroy() end
    end
end
pcall(function()
    local old = game:GetService("CoreGui"):FindFirstChild(GUI_NAME)
    if old then old:Destroy() end
end)

local function glyph(parent, kind, size, color)
    local box = make("Frame", parent, {Name = "Glyph", Size = UDim2.fromOffset(size or 18, size or 18),
        BackgroundTransparency = 1})
    local unit = 1 / 18
    color = color or P.sub
    local function fill(x, y, w, h, radius, rotation)
        local part = make("Frame", box, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x * unit, y * unit),
            Size = UDim2.fromScale(w * unit, h * unit), BorderSizePixel = 0, BackgroundColor3 = color, Rotation = rotation or 0})
        part:SetAttribute("glyphFill", true)
        if radius then corner(part, radius) end
        return part
    end
    local function frame(x, y, w, h, radius)
        local part = make("Frame", box, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x * unit, y * unit),
            Size = UDim2.fromScale(w * unit, h * unit), BackgroundTransparency = 1})
        local line = make("UIStroke", part, {Thickness = 1.6, Color = color, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
        line:SetAttribute("glyphLine", true)
        if radius then corner(part, radius) end
        return part
    end
    if kind == "redeem" then
        frame(9, 9, 15, 11, 3)
        fill(12, 9, 1.4, 6)
        fill(6, 7.5, 3.5, 1.4, 1)
        fill(6, 10.5, 3.5, 1.4, 1)
    elseif kind == "helper" then
        fill(5.5, 5.5, 6, 6, 2)
        fill(12.5, 5.5, 6, 6, 2)
        fill(5.5, 12.5, 6, 6, 2)
        frame(12.5, 12.5, 5.4, 5.4, 2)
    elseif kind == "gift" then
        frame(9, 11.6, 12.5, 8, 2)
        fill(9, 5.8, 15, 3.6, 1)
        fill(9, 9.6, 1.6, 11.5)
    elseif kind == "account" then
        frame(9, 5.8, 6.4, 6.4, 99)
        frame(9, 14.2, 12.5, 6, 3)
    elseif kind == "settings" then
        fill(9, 4.5, 15, 1.5, 1)
        fill(9, 9, 15, 1.5, 1)
        fill(9, 13.5, 15, 1.5, 1)
        fill(5, 4.5, 4.6, 4.6, 99)
        fill(12.5, 9, 4.6, 4.6, 99)
        fill(7.5, 13.5, 4.6, 4.6, 99)
    elseif kind == "minus" then
        fill(9, 9, 11, 1.8, 1)
        local vertical = fill(9, 9, 1.8, 0, 1)
        vertical.Name = "Vertical"
    elseif kind == "close" then
        fill(9, 9, 13, 1.8, 1, 45)
        fill(9, 9, 13, 1.8, 1, -45)
    end
    return box
end

local function tintGlyph(box, color, duration)
    for _, child in ipairs(box:GetDescendants()) do
        if child:GetAttribute("glyphFill") then
            if duration == 0 then child.BackgroundColor3 = color else animate(child, {BackgroundColor3 = color}, duration or 0.2) end
        elseif child:GetAttribute("glyphLine") then
            if duration == 0 then child.Color = color else animate(child, {Color = color}, duration or 0.2) end
        end
    end
end

local UI = {updates = {}, page = {}, tabs = {}, keyChips = {}, bindButtons = {}, swatches = {}, glyphs = {}}
local Actions = {}
local ActionOrder = {"toggle_ui", "auto_redeem", "part_guesser", "auto_mode", "combine_parts", "fps_boost",
    "freeze", "anti_ragdoll", "auto_buy", "quick_grab", "quick_sell"}

UI.gui = make("ScreenGui", nil, {Name = GUI_NAME, ResetOnSpawn = false, IgnoreGuiInset = true,
    DisplayOrder = 100, ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
UI.gui.Parent = guiParent
S.gui = UI.gui

local function viewport()
    local size = UI.gui.AbsoluteSize
    if size.X < 2 or size.Y < 2 then
        local camera = workspace.CurrentCamera
        size = camera and camera.ViewportSize or Vector2.new(1280, 720)
    end
    return size
end

local function createWindow(options)
    local w = {width = options.width, height = options.height, header = options.header, scaleValue = 1,
        visible = false, collapsed = false, token = 0}
    w.shadow = make("ImageLabel", UI.gui, {Name = options.name .. "Shadow", AnchorPoint = Vector2.new(0.5, 0),
        BackgroundTransparency = 1, Image = "rbxassetid://6014261993", ImageColor3 = Color3.new(0, 0, 0),
        ImageTransparency = 1, ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(49, 49, 450, 450),
        Visible = false, ZIndex = options.z})
    w.shadowScale = make("UIScale", w.shadow, {Scale = 1})
    w.frame = make("CanvasGroup", UI.gui, {Name = options.name, AnchorPoint = Vector2.new(0.5, 0), BorderSizePixel = 0,
        GroupTransparency = 1, Visible = false, ZIndex = options.z + 1}, {BackgroundColor3 = "bg"})
    corner(w.frame, 14)
    w.scale = make("UIScale", w.frame, {Scale = 1})
    local fillFrame = make("Frame", w.frame, {Name = "Backdrop", Size = UDim2.fromScale(1, 1), BorderSizePixel = 0,
        ZIndex = 0, BackgroundColor3 = Color3.new(1, 1, 1)})
    local backdrop = make("UIGradient", fillFrame, {Rotation = 115})
    w.border = make("UIStroke", w.frame, {Thickness = 1.2, Color = Color3.new(1, 1, 1),
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
    pcall(function() w.border.BorderStrokePosition = Enum.BorderStrokePosition.Inner end)
    local shine = make("UIGradient", w.border, {Rotation = 0})
    themeHooks[#themeHooks + 1] = function()
        backdrop.Color = ColorSequence.new(P.bgTop, P.bg)
        shine.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, P.stroke), ColorSequenceKeypoint.new(0.38, P.stroke),
            ColorSequenceKeypoint.new(0.5, P.accent), ColorSequenceKeypoint.new(0.62, P.stroke), ColorSequenceKeypoint.new(1, P.stroke)})
    end
    themeHooks[#themeHooks]()
    Tween:Create(shine, TweenInfo.new(options.spin or 8, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
        {Rotation = 360}):Play()

    function w:currentHeight() return self.collapsed and self.header or self.height end
    function w:clamp(position)
        local area = viewport()
        local half = self.width * self.scaleValue / 2
        local height = self:currentHeight() * self.scaleValue
        return Vector2.new(math.clamp(position.X, half + 6, math.max(half + 6, area.X - half - 6)),
            math.clamp(position.Y, 6, math.max(6, area.Y - height - 6)))
    end
    function w:place(position)
        self.pos = self:clamp(position or self.pos or options.default(self))
        self.frame.Position = UDim2.fromOffset(self.pos.X, self.pos.Y)
        self.shadow.Position = UDim2.fromOffset(self.pos.X, self.pos.Y - 17 * self.scaleValue)
    end
    function w:applySize(animated)
        local height = self:currentHeight()
        local size, shadowSize = UDim2.fromOffset(self.width, height), UDim2.fromOffset(self.width + 46, height + 42)
        if animated then
            animate(self.frame, {Size = size}, 0.36)
            animate(self.shadow, {Size = shadowSize}, 0.36)
        else
            self.frame.Size, self.shadow.Size = size, shadowSize
        end
    end
    function w:setScale(value)
        self.scaleValue = value
        self.scale.Scale, self.shadowScale.Scale = value, value
    end
    function w:show()
        self.token += 1
        self.visible = true
        self.frame.Visible, self.shadow.Visible = true, true
        self.frame.GroupTransparency, self.shadow.ImageTransparency = 1, 1
        self.scale.Scale, self.shadowScale.Scale = self.scaleValue * 0.9, self.scaleValue * 0.9
        animate(self.frame, {GroupTransparency = 0}, 0.24)
        animate(self.shadow, {ImageTransparency = 0.4}, 0.34)
        animate(self.scale, {Scale = self.scaleValue}, 0.42, Enum.EasingStyle.Back)
        animate(self.shadowScale, {Scale = self.scaleValue}, 0.42, Enum.EasingStyle.Back)
    end
    function w:hide(done)
        self.token += 1
        local token = self.token
        self.visible = false
        animate(self.frame, {GroupTransparency = 1}, 0.2, Enum.EasingStyle.Quad)
        animate(self.shadow, {ImageTransparency = 1}, 0.2, Enum.EasingStyle.Quad)
        animate(self.scale, {Scale = self.scaleValue * 0.92}, 0.2, Enum.EasingStyle.Quad)
        animate(self.shadowScale, {Scale = self.scaleValue * 0.92}, 0.2, Enum.EasingStyle.Quad)
        task.delay(0.21, function()
            if self.token == token then self.frame.Visible, self.shadow.Visible = false, false end
            if done then done() end
        end)
    end
    function w:setCollapsed(value, instant)
        self.collapsed = value == true
        self:applySize(not instant)
        if self.onCollapse then self.onCollapse(self.collapsed, instant) end
        self:place()
    end
    return w
end

local function iconButton(parent, kind, x)
    local object = make("TextButton", parent, {Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, x, 0.5, 0), Size = UDim2.fromOffset(30, 30), BorderSizePixel = 0,
        BackgroundTransparency = 1, ZIndex = 6}, {BackgroundColor3 = "cardHover"})
    corner(object, 9)
    local icon = glyph(object, kind, 14)
    icon.AnchorPoint, icon.Position, icon.ZIndex = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), 7
    for _, child in ipairs(icon:GetChildren()) do child.ZIndex = 7 end
    local hoverColor = kind == "close" and P.bad or P.text
    connect(object.MouseEnter, function()
        animate(object, {BackgroundTransparency = 0})
        tintGlyph(icon, kind == "close" and P.bad or P.text)
    end)
    connect(object.MouseLeave, function()
        animate(object, {BackgroundTransparency = 1})
        tintGlyph(icon, P.sub)
    end)
    UI.glyphs[#UI.glyphs + 1] = {box = icon, role = "sub"}
    return object, icon, hoverColor
end

local Layout = {compact = false, side = 174, scale = 1}
local savedPositions = S.layoutVersion >= 3
local function savedVector(x, y)
    if savedPositions and type(x) == "number" and type(y) == "number" then return Vector2.new(x, y) end
    return nil
end

local main = createWindow({name = "Window", width = 630, height = 430, header = 58, z = 1,
    default = function(self)
        local area = viewport()
        return Vector2.new(area.X / 2, (area.Y - self.height * self.scaleValue) / 2)
    end})
main.pos = savedVector(saved.x, saved.y)
UI.window = main.frame
UI.avengersBg = make("ImageLabel", main.frame:FindFirstChild("Backdrop"), {Name = "AvengersBackground",
    Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Image = "",
    ScaleType = Enum.ScaleType.Crop, ImageTransparency = 1, Visible = false, ZIndex = 0})

UI.snow = make("Frame", UI.window, {Name = "Snow", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
    ClipsDescendants = true, Visible = S.winter, ZIndex = 0})
do
    local flakes = {}
    local random = Random.new()
    for index = 1, 36 do
        local size = random:NextInteger(2, 5)
        local flake = make("Frame", UI.snow, {Size = UDim2.fromOffset(size, size), BorderSizePixel = 0, ZIndex = 0,
            BackgroundColor3 = Color3.fromRGB(235, 245, 255), BackgroundTransparency = random:NextNumber(0.2, 0.65)})
        corner(flake, size)
        flakes[index] = {object = flake, x = random:NextNumber(), y = random:NextNumber(),
            speed = random:NextNumber(0.035, 0.09) * (size / 4 + 0.5), phase = random:NextNumber(0, math.pi * 2),
            sway = random:NextNumber(4, 12), rate = random:NextNumber(0.6, 1.4)}
    end
    local clock = 0
    connect(game:GetService("RunService").Heartbeat, function(dt)
        if not S.winter or not main.visible or main.collapsed then return end
        clock += math.min(dt, 0.1)
        for _, flake in ipairs(flakes) do
            flake.y += flake.speed * math.min(dt, 0.1)
            if flake.y > 1.03 then flake.y, flake.x = -0.03, random:NextNumber() end
            flake.object.Position = UDim2.new(flake.x, math.sin(clock * flake.rate + flake.phase) * flake.sway, flake.y, 0)
        end
    end)
end

-- Top chrome: a header (logo, title, window buttons) with the tab bar under it. Hub.layout sizes it.
UI.side = Glass.add(make("Frame", UI.window, {Name = "Chrome", Size = UDim2.new(1, 0, 0, 104), BorderSizePixel = 0,
    BackgroundTransparency = 0.18, ZIndex = 2}, {BackgroundColor3 = "side"}), 0.18)
make("Frame", UI.side, {AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 1),
    BorderSizePixel = 0, BackgroundTransparency = 0.25, ZIndex = 3}, {BackgroundColor3 = "stroke"})
-- A thin accent light that drifts along the top edge of the window.
UI.topGlow = make("Frame", UI.window, {Name = "TopGlow", Size = UDim2.new(1, 0, 0, 2), BorderSizePixel = 0, ZIndex = 8},
    {BackgroundColor3 = "accent"})
do
    local drift = make("UIGradient", UI.topGlow, {Offset = Vector2.new(-0.6, 0), Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1)})})
    Tween:Create(drift, TweenInfo.new(3.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        {Offset = Vector2.new(0.6, 0)}):Play()
end

UI.brand = make("Frame", UI.side, {Name = "Header", Size = UDim2.new(1, 0, 0, 58), BackgroundTransparency = 1,
    Active = true, ZIndex = 3})
UI.header, UI.drag = UI.brand, UI.brand
-- Style 2 only: a soft wash of the chosen color behind the logo and title.
UI.banner = make("Frame", UI.brand, {Name = "Banner", Size = UDim2.fromScale(1, 1), BorderSizePixel = 0,
    Visible = false, ZIndex = 3}, {BackgroundColor3 = "accent"})
make("UIGradient", UI.banner, {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.78),
    NumberSequenceKeypoint.new(0.55, 0.97), NumberSequenceKeypoint.new(1, 1)})})
-- Logo: the "A" from the Avengers picture, tinted with the chosen color (see Hub.loadLogo and the theme hook below).
UI.logo = make("Frame", UI.brand, {Name = "Logo", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0),
    Size = UDim2.fromOffset(40, 40), BorderSizePixel = 0, ZIndex = 4}, {BackgroundColor3 = "field"})
UI.logoCorner = corner(UI.logo, 10)
UI.logoRing = outline(UI.logo, "accent", 0.35, 1.5)
UI.logoImage = make("ImageLabel", UI.logo, {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = "",
    ScaleType = Enum.ScaleType.Crop, ZIndex = 5})
UI.logoImageCorner = corner(UI.logoImage, 10)
UI.logoLetter = label(UI.logo, {Text = "A", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center,
    Font = Enum.Font.GothamBlack, TextSize = 22, ZIndex = 6}, {TextColor3 = "accent"})
UI.brandTitle = label(UI.brand, {Text = string.upper(Config.ProductName), Position = UDim2.fromOffset(62, 9),
    Size = UDim2.new(1, -150, 0, 24), Font = Enum.Font.GothamBlack, TextSize = 21, ZIndex = 4})
pcall(function() UI.brandTitle.FontFace = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold) end)
UI.brandShade = make("UIGradient", UI.brandTitle, {Rotation = 90})
themeHooks[#themeHooks + 1] = function()
    -- Silver title on dark windows; on the white window the title is plain dark text instead.
    UI.brandShade.Color = P.base == "light" and ColorSequence.new(Color3.new(1, 1, 1)) or ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(214, 218, 228)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 166, 180))})
end
UI.brandSub = label(UI.brand, {Text = "STEAL A BRAINROT", Position = UDim2.fromOffset(63, 33), Size = UDim2.new(1, -150, 0, 14),
    Font = Enum.Font.GothamBold, TextSize = 11, ZIndex = 4}, {TextColor3 = "accent"})
UI.closeButton = iconButton(UI.brand, "close", -20)
UI.collapseButton, UI.collapseGlyph = iconButton(UI.brand, "minus", -56)
UI.headerLine = make("Frame", UI.side, {Position = UDim2.new(0, 14, 0, 58), Size = UDim2.new(1, -28, 0, 1), BorderSizePixel = 0,
    BackgroundTransparency = 0.5, ZIndex = 3}, {BackgroundColor3 = "stroke"})
UI.tabBar = make("Frame", UI.side, {Name = "Tabs", Position = UDim2.fromOffset(10, 63), Size = UDim2.new(1, -20, 0, 36),
    BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3})
-- Style 2 turns the tab bar into a rounded track with a solid pill for the open tab.
UI.tabBarCorner = corner(UI.tabBar, 11)
UI.tabBarStroke = outline(UI.tabBar, "stroke", 1)

UI.main = make("Frame", UI.window, {Name = "Main", Position = UDim2.fromOffset(0, 104), Size = UDim2.new(1, 0, 1, -104),
    BackgroundTransparency = 1, ZIndex = 1})
UI.pageHost = make("Frame", UI.main, {Name = "Pages", Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 2})

main.onCollapse = function(collapsed, instant)
    local vertical = UI.collapseGlyph:FindFirstChild("Vertical")
    local target = UDim2.fromScale(1.8 / 18, collapsed and 11 / 18 or 0)
    if instant then vertical.Size = target else animate(vertical, {Size = target}, 0.3, Enum.EasingStyle.Back) end
    if instant then UI.headerLine.BackgroundTransparency = collapsed and 1 or 0.5
    else animate(UI.headerLine, {BackgroundTransparency = collapsed and 1 or 0.5}, 0.25) end
end

-- The logo picture is grayscale, so tinting it with the accent makes it follow the chosen color.
themeHooks[#themeHooks + 1] = function()
    animate(UI.logoImage, {ImageColor3 = P.accent:Lerp(Color3.new(1, 1, 1), 0.3)}, 0.35)
end

local function order(parent)
    local value = (parent:GetAttribute("order") or 0) + 1
    parent:SetAttribute("order", value)
    return value
end

local function newPage(id)
    local page = make("ScrollingFrame", UI.pageHost, {Name = id, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y, Visible = false, ScrollBarImageTransparency = 0.4, ZIndex = 2},
        {ScrollBarImageColor3 = "accent"})
    padding(page, 16, 18, 14, 18)
    make("UIListLayout", page, {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder})
    UI.page[id] = page
    return page
end

UI.sections, UI.cards = {}, {}
local function section(page, text)
    local heading = label(page, {Text = string.upper(text), Size = UDim2.new(1, 0, 0, 16), Font = Enum.Font.GothamBold,
        TextSize = 12, LayoutOrder = order(page)}, {TextColor3 = "sub"})
    UI.sections[#UI.sections + 1] = heading
    padding(heading, 10, 0, 0, 0)
    local mark = make("Frame", heading, {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -10, 0.5, 0),
        Size = UDim2.fromOffset(3, 11), BorderSizePixel = 0}, {BackgroundColor3 = "accent"})
    corner(mark, 2)
    return heading
end

local function card(page)
    local frame = Glass.add(make("Frame", page, {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0, LayoutOrder = order(page)}, {BackgroundColor3 = "card"}), 0)
    local round = corner(frame, 12)
    local edge = outline(frame, "stroke", 0.35)
    -- Style 2: the card edge glows in the chosen color from the left.
    local glow = make("UIGradient", edge, {Enabled = false})
    UI.cards[#UI.cards + 1] = {corner = round, edge = edge, glow = glow}
    make("UIListLayout", frame, {SortOrder = Enum.SortOrder.LayoutOrder})
    padding(frame, 0, 0, 4, 4)
    return frame
end

local function separator(parent)
    if (parent:GetAttribute("order") or 0) == 0 then return end
    local line = make("Frame", parent, {Size = UDim2.new(1, 0, 0, 1), BackgroundTransparency = 1, LayoutOrder = order(parent)})
    make("Frame", line, {Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -32, 1, 0), BorderSizePixel = 0,
        BackgroundTransparency = 0.5}, {BackgroundColor3 = "stroke"})
end

local function pressable(object)
    local scale = make("UIScale", object, {Scale = 1})
    connect(object.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            animate(scale, {Scale = 0.95}, 0.1)
        end
    end)
    connect(object.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            animate(scale, {Scale = 1}, 0.3, Enum.EasingStyle.Back)
        end
    end)
    return scale
end

local function button(parent, text, style, properties)
    local red = style == "red"
    local primary = style == "primary" or red
    local danger = style == "danger"
    local base = red and "danger" or (primary and "accent" or "field")
    local hover = red and "badHover" or (primary and "accentHover" or "cardHover")
    local props = {Text = text, AutoButtonColor = false, Font = Enum.Font.GothamBold, TextSize = 14,
        BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 36)}
    for key, value in pairs(properties or {}) do props[key] = value end
    local object = make("TextButton", parent, props,
        {BackgroundColor3 = base, TextColor3 = primary and "onAccent" or (danger and "bad" or "text")})
    corner(object, 9)
    local line
    if not primary then line = outline(object, "stroke", 0.15) end
    connect(object.MouseEnter, function()
        animate(object, {BackgroundColor3 = P[hover]})
        if line then animate(line, {Color = danger and P.bad or P.accent, Transparency = 0.45}) end
    end)
    connect(object.MouseLeave, function()
        animate(object, {BackgroundColor3 = P[base]})
        if line then animate(line, {Color = P.stroke, Transparency = 0.15}) end
    end)
    pressable(object)
    return object
end

local function buttonBar(page, count)
    local bar = make("Frame", page, {Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, LayoutOrder = order(page)})
    make("UIGridLayout", bar, {CellPadding = UDim2.fromOffset(8, 0), SortOrder = Enum.SortOrder.LayoutOrder,
        CellSize = UDim2.new(1 / count, -math.ceil(8 * (count - 1) / count) - 1, 0, 36)})
    return bar
end

local function toggleRow(parent, text, get, set, actionId)
    separator(parent)
    local row = make("TextButton", parent, {Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 46),
        BackgroundTransparency = 1, LayoutOrder = order(parent)})
    local hover = make("Frame", row, {Position = UDim2.fromOffset(6, 3), Size = UDim2.new(1, -12, 1, -6), BorderSizePixel = 0,
        BackgroundTransparency = 1}, {BackgroundColor3 = "cardHover"})
    corner(hover, 9)
    label(row, {Text = text, Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -150, 1, 0)})
    local chip
    if actionId then
        chip = label(row, {Text = "", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -70, 0.5, 0),
            Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, Font = Enum.Font.GothamBold,
            TextSize = 12, BackgroundTransparency = 0, TextXAlignment = Enum.TextXAlignment.Center, Visible = false},
            {TextColor3 = "sub", BackgroundColor3 = "field"})
        corner(chip, 6)
        padding(chip, 7, 7, 0, 0)
        UI.keyChips[#UI.keyChips + 1] = {chip = chip, id = actionId}
    end
    local switch = make("Frame", row, {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0),
        Size = UDim2.fromOffset(42, 24), BorderSizePixel = 0, BackgroundColor3 = P.off})
    corner(switch, 12)
    local knob = make("Frame", switch, {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0),
        Size = UDim2.fromOffset(18, 18), BorderSizePixel = 0, BackgroundColor3 = P.sub})
    corner(knob, 9)
    local last
    local function update(force)
        local on = get() == true
        if on == last and not force then return end
        last = on
        animate(switch, {BackgroundColor3 = on and P.accent or P.off}, 0.2)
        animate(knob, {Position = UDim2.new(0, on and 21 or 3, 0.5, 0), BackgroundColor3 = on and P.onAccent or P.sub},
            0.32, Enum.EasingStyle.Back)
    end
    UI.updates[#UI.updates + 1] = update
    connect(row.MouseEnter, function() animate(hover, {BackgroundTransparency = 0}) end)
    connect(row.MouseLeave, function() animate(hover, {BackgroundTransparency = 1}) end)
    connect(row.Activated, function()
        if not S.ready or S.closing then return end
        set(not get())
        update()
        if Hub.persist then Hub.persist() end
    end)
    update(true)
    return row
end

local function actionRow(parent, actionId)
    local action = Actions[actionId]
    return toggleRow(parent, action.label, action.get, action.set, actionId)
end

local function setActionValue(id, value)
    local action = Actions[id]
    if action and action.get() ~= value then action.set(value) end
end

Actions.toggle_ui = {label = "Show or hide the hub", get = function() return not S.hidden end,
    set = function(value) Hub.setHidden(not value) end}
Actions.auto_redeem = {label = "Auto redeem", get = function() return engine.enabled end,
    set = function(value) engine:setEnabled(value) if value and Hub.ensureSetup then Hub.ensureSetup() end end}
Actions.part_guesser = {label = "Auto part guesser", get = function() return engine.guess end,
    set = function(value) engine:setGuess(value) end}
Actions.auto_mode = {label = "Auto mode", get = function() return engine.autoMode end,
    set = function(value) engine:setAutoMode(value) if value and Hub.ensureSetup then Hub.ensureSetup() end end}
Actions.combine_parts = {label = "Combine parts", get = function() return engine.partsMode end,
    set = function(value) engine:setPartsMode(value) end}
Actions.fps_boost = {label = "FPS boost", get = function() return S.fps.enabled end,
    set = function(value) task.spawn(function()
        if value then S.waitPreviousFPS() end
        if not S.alive then return end
        S.fps:setEnabled(value)
        if requestRefresh then requestRefresh() end
    end) end}
Actions.freeze = {label = "Freeze", get = function() return helperFlag("frozen") end,
    set = function(value) local h = helper() if h then h.setFrozen(value) end end}
Actions.anti_ragdoll = {label = "Anti ragdoll", get = function() return helperFlag("antiRagdoll") end,
    set = function(value) local h = helper() if h then h.setAntiRagdoll(value) end end}
Actions.auto_buy = {label = "Auto buy brainrots", get = function() return helperFlag("autoBuy") end,
    set = function(value) local h = helper() if h then h.setAutoBuy(value) end end}
Actions.quick_grab = {label = "Quick grab and place", get = function() return helperFlag("quickGrab") end,
    set = function(value) local h = helper() if h then h.setQuickGrab(value) end end}
Actions.quick_sell = {label = "Quick sell", get = function() return helperFlag("quickSell") end,
    set = function(value) local h = helper() if h then h.setQuickSell(value) end end}

local Tabs = {
    {id = "redeem", icon = "redeem", name = "Redeem"},
    {id = "helper", icon = "helper", name = "Helper"},
    {id = "redeemed", icon = "gift", name = "Redeemed"},
    {id = "account", icon = "account", name = "Account"},
    {id = "settings", icon = "settings", name = "Settings"},
}

UI.indicator = make("Frame", UI.tabBar, {Name = "Indicator", Position = UDim2.new(0, 3, 0, 0),
    Size = UDim2.new(1 / #Tabs, -6, 1, 0), BorderSizePixel = 0, ZIndex = 3}, {BackgroundColor3 = "soft"})
corner(UI.indicator, 9)
UI.indicatorBar = make("Frame", UI.indicator, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0),
    Size = UDim2.new(0.42, 0, 0, 3), BorderSizePixel = 0, ZIndex = 4}, {BackgroundColor3 = "accent"})
corner(UI.indicatorBar, 2)
for index, tab in ipairs(Tabs) do
    local tabButton = make("TextButton", UI.tabBar, {Name = tab.id, Text = "", AutoButtonColor = false,
        Position = UDim2.fromScale((index - 1) / #Tabs, 0), Size = UDim2.fromScale(1 / #Tabs, 1),
        BackgroundTransparency = 1, ZIndex = 5})
    local content = make("Frame", tabButton, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, ZIndex = 5})
    make("UIListLayout", content, {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 7),
        VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder})
    local icon = glyph(content, tab.icon, 16)
    icon.LayoutOrder, icon.ZIndex = 1, 6
    for _, child in ipairs(icon:GetChildren()) do child.ZIndex = 6 end
    local name = label(content, {Text = tab.name, Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X,
        TextSize = 14, TextTruncate = Enum.TextTruncate.None, LayoutOrder = 2, ZIndex = 6}, {TextColor3 = "sub"})
    UI.tabs[tab.id] = {button = tabButton, icon = icon, name = name, index = index, data = tab}
    connect(tabButton.MouseEnter, function()
        if S.tab ~= tab.id then animate(name, {TextColor3 = P.text}) tintGlyph(icon, P.text) end
    end)
    connect(tabButton.MouseLeave, function()
        if S.tab ~= tab.id then animate(name, {TextColor3 = P.sub}) tintGlyph(icon, P.sub) end
    end)
    connect(tabButton.Activated, function() Hub.selectTab(tab.id) end)
end

function Hub.paintTabs(instant)
    local pill = S.style == 2
    for key, item in pairs(UI.tabs) do
        local active = key == S.tab
        local color = active and (pill and P.onAccent or P.text) or P.sub
        if instant then item.name.TextColor3 = color else animate(item.name, {TextColor3 = color}) end
        item.name.Font = active and Enum.Font.GothamBold or Enum.Font.GothamMedium
        pcall(function() item.name.FontFace = Font.new(FontFamily, active and Enum.FontWeight.Bold or Enum.FontWeight.Medium) end)
        tintGlyph(item.icon, active and (pill and P.onAccent or P.accent) or P.sub, instant and 0 or 0.2)
    end
end

function Hub.selectTab(id, instant)
    local tab = UI.tabs[id] or UI.tabs.redeem
    id = tab.data.id
    local changed = S.tab ~= id
    S.tab = id
    for key, page in pairs(UI.page) do
        local active = key == id
        page.Visible = active
        if active and (changed or instant) then
            page.Position = UDim2.fromOffset(0, instant and 0 or 14)
            if not instant then animate(page, {Position = UDim2.fromOffset(0, 0)}, 0.32) end
        end
    end
    Hub.paintTabs(instant)
    local target = UDim2.new((tab.index - 1) / #Tabs, 3, 0, S.style == 2 and 3 or 0)
    if instant then UI.indicator.Position = target else animate(UI.indicator, {Position = target}, 0.34, Enum.EasingStyle.Back) end
    if id == "redeemed" and Hub.renderHistory then
        Hub.renderHistory()
        if S.historyView == "everyone" and Hub.fetchShared then Hub.fetchShared() end
    end
    if id == "settings" and Hub.renderConfigs then Hub.renderConfigs() end
    if Hub.persist then Hub.persist() end
end

do
    local page = newPage("redeem")
    local status = card(page)
    status:FindFirstChildOfClass("UIPadding"):Destroy()
    padding(status, 16, 16, 14, 14)
    status:FindFirstChildOfClass("UIListLayout").Padding = UDim.new(0, 10)
    for index, entry in ipairs(painted) do
        if entry[1] == status and entry[2] == "BackgroundColor3" then table.remove(painted, index) break end
    end
    status.BackgroundColor3 = Color3.new(1, 1, 1)
    local glow = make("UIGradient", status, {Rotation = 20})
    themeHooks[#themeHooks + 1] = function()
        glow.Color = ColorSequence.new(P.card:Lerp(P.accent, 0.14), P.card)
    end
    themeHooks[#themeHooks]()

    local top = make("Frame", status, {Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = 1})
    UI.pulse = make("Frame", top, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 4, 0.5, 0),
        Size = UDim2.fromOffset(8, 8), BorderSizePixel = 0, BackgroundTransparency = 1, BackgroundColor3 = P.good})
    corner(UI.pulse, 11)
    UI.dot = make("Frame", top, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 4, 0.5, 0),
        Size = UDim2.fromOffset(8, 8), BorderSizePixel = 0, BackgroundColor3 = P.off})
    corner(UI.dot, 4)
    UI.status = label(top, {Text = "Connecting", Position = UDim2.fromOffset(18, 0), Size = UDim2.new(1, -110, 1, 0),
        Font = Enum.Font.GothamBold, TextSize = 16})
    UI.count = label(top, {Text = "", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, Font = Enum.Font.GothamBold, TextSize = 12,
        BackgroundTransparency = 0, TextXAlignment = Enum.TextXAlignment.Center}, {TextColor3 = "accent", BackgroundColor3 = "soft"})
    corner(UI.count, 7)
    padding(UI.count, 9, 9, 0, 0)
    local previewBox = make("Frame", status, {Size = UDim2.new(1, 0, 0, 34), BorderSizePixel = 0, LayoutOrder = 2},
        {BackgroundColor3 = "field"})
    corner(previewBox, 8)
    outline(previewBox, "stroke", 0.5)
    UI.preview = label(previewBox, {Text = "", Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0),
        Font = Enum.Font.RobotoMono, TextSize = 13}, {TextColor3 = "sub"})
    UI.track = make("Frame", status, {Size = UDim2.new(1, 0, 0, 4), BorderSizePixel = 0, LayoutOrder = 3,
        ClipsDescendants = true}, {BackgroundColor3 = "off"})
    corner(UI.track, 2)
    UI.fill = make("Frame", UI.track, {Size = UDim2.fromScale(0, 1), BorderSizePixel = 0, BackgroundColor3 = P.accent})
    corner(UI.fill, 2)

    section(page, "Redeemer")
    local redeemer = card(page)
    actionRow(redeemer, "auto_redeem")
    actionRow(redeemer, "part_guesser")
    actionRow(redeemer, "auto_mode")

    section(page, "Code parts")
    local parts = card(page)
    actionRow(parts, "combine_parts")
    separator(parts)
    local stepper = make("Frame", parts, {Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1, LayoutOrder = order(parts)})
    label(stepper, {Text = "Parts per code", Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -150, 1, 0)})
    local minus = button(stepper, "-", nil, {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -90, 0.5, 0),
        Size = UDim2.fromOffset(32, 32), TextSize = 18})
    UI.amount = label(stepper, {Text = "3", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -52, 0.5, 0),
        Size = UDim2.fromOffset(34, 32), Font = Enum.Font.GothamBold, TextSize = 17,
        TextXAlignment = Enum.TextXAlignment.Center}, {TextColor3 = "accent"})
    local plus = button(stepper, "+", nil, {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0),
        Size = UDim2.fromOffset(32, 32), TextSize = 18})
    connect(minus.Activated, function() engine:setAmount(engine.amount - 1) Hub.persist() end)
    connect(plus.Activated, function() engine:setAmount(engine.amount + 1) Hub.persist() end)

    local bar = buttonBar(page, 3)
    UI.clear = button(bar, "Clear", nil, {LayoutOrder = 1})
    UI.retype = button(bar, "Retype", "primary", {LayoutOrder = 2})
    UI.senderButton = button(bar, "Sender", nil, {LayoutOrder = 3})
end

do
    local page = newPage("helper")
    section(page, "Movement")
    local movement = card(page)
    actionRow(movement, "freeze")
    actionRow(movement, "anti_ragdoll")
    section(page, "Brainrots")
    local brainrots = card(page)
    actionRow(brainrots, "auto_buy")
    actionRow(brainrots, "quick_grab")
    actionRow(brainrots, "quick_sell")
    UI.helperStatus = label(page, {Text = "", Size = UDim2.new(1, 0, 0, 16), TextSize = 13, Font = Enum.Font.Gotham,
        LayoutOrder = order(page), Visible = false}, {TextColor3 = "sub"})
end

do
    local page = newPage("redeemed")
    local head = card(page)
    local row = make("Frame", head, {Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, LayoutOrder = 1})
    UI.historyCount = label(row, {Text = "", Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -130, 1, 0),
        Font = Enum.Font.GothamBold, TextSize = 17})
    UI.historyClear = button(row, "Clear", "danger", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(92, 34)})
    UI.viewSwitch = make("Frame", row, {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0),
        Size = UDim2.fromOffset(200, 34), BorderSizePixel = 0, Visible = false}, {BackgroundColor3 = "field"})
    corner(UI.viewSwitch, 9)
    UI.viewPill = make("Frame", UI.viewSwitch, {Position = UDim2.fromOffset(3, 3), Size = UDim2.new(0.5, -3, 1, -6),
        BorderSizePixel = 0}, {BackgroundColor3 = "soft"})
    corner(UI.viewPill, 7)
    UI.viewButtons = {}
    for index, view in ipairs({{"everyone", "Everyone"}, {"mine", "Mine"}}) do
        local option = make("TextButton", UI.viewSwitch, {Text = view[2], AutoButtonColor = false, BackgroundTransparency = 1,
            Position = UDim2.new((index - 1) * 0.5, 0, 0, 0), Size = UDim2.fromScale(0.5, 1), Font = Enum.Font.GothamBold,
            TextSize = 14, ZIndex = 2}, {TextColor3 = "sub"})
        UI.viewButtons[view[1]] = option
        connect(option.Activated, function() Hub.setHistoryView(view[1]) end)
    end
    UI.historyList = make("Frame", page, {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, LayoutOrder = order(page)})
    make("UIListLayout", UI.historyList, {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder})
end

do
    local accountPage = newPage("account")
    section(accountPage, "Flag check")
    UI.flagCheck = button(accountPage, "Check account", "red", {Size = UDim2.new(1, 0, 0, 44), TextSize = 16,
        LayoutOrder = order(accountPage)})
    connect(UI.flagCheck.Activated, function() Hub.checkFlag(Config.FlagCheckCode) end)

    local page = newPage("settings")
    section(page, "Configs")
    local configs = card(page)
    configs:FindFirstChildOfClass("UIPadding"):Destroy()
    padding(configs, 14, 14, 14, 14)
    configs:FindFirstChildOfClass("UIListLayout").Padding = UDim.new(0, 10)
    UI.configName = make("TextBox", configs, {Text = "", PlaceholderText = "Config name", ClearTextOnFocus = false,
        Size = UDim2.new(1, 0, 0, 38), Font = Enum.Font.GothamMedium, TextSize = 15, BorderSizePixel = 0,
        TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1},
        {BackgroundColor3 = "field", TextColor3 = "text", PlaceholderColor3 = "sub"})
    corner(UI.configName, 9)
    local nameLine = outline(UI.configName, "stroke", 0.15)
    padding(UI.configName, 12, 12, 0, 0)
    connect(UI.configName.Focused, function() animate(nameLine, {Color = P.accent, Transparency = 0}) end)
    local bar = make("Frame", configs, {Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, LayoutOrder = 2})
    make("UIGridLayout", bar, {CellPadding = UDim2.fromOffset(8, 0), SortOrder = Enum.SortOrder.LayoutOrder,
        CellSize = UDim2.new(1 / 3, -7, 0, 36)})
    UI.configSave = button(bar, "Save", "primary", {LayoutOrder = 1})
    UI.configLoad = button(bar, "Load", nil, {LayoutOrder = 2})
    UI.configDelete = button(bar, "Delete", "danger", {LayoutOrder = 3})
    UI.configStatus = label(configs, {Text = "", Size = UDim2.new(1, 0, 0, 16), TextSize = 13, Font = Enum.Font.Gotham,
        LayoutOrder = 3, Visible = false}, {TextColor3 = "sub"})
    UI.configList = make("Frame", configs, {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, LayoutOrder = 4})
    make("UIGridLayout", UI.configList, {CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.Name,
        CellSize = UDim2.new(0.5, -5, 0, 34)})
    connect(UI.configName.FocusLost, function() animate(nameLine, {Color = P.stroke, Transparency = 0.15}) end)
    local autoloadCard = card(page)
    toggleRow(autoloadCard, "Load this config on start",
        function() return S.autoload ~= nil and Hub.configSelected ~= nil and S.autoload == Hub.configSelected() end,
        function(value)
            local name = Hub.configSelected()
            if value and name then S.autoload = name Hub.configMessage(name .. " will load on start")
            elseif value then Hub.configMessage("Pick a config first")
            else S.autoload = nil end
            Hub.renderConfigs()
        end)

    section(page, "Keybinds")
    local binds = card(page)
    for _, id in ipairs(ActionOrder) do
        separator(binds)
        local row = make("Frame", binds, {Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, LayoutOrder = order(binds)})
        label(row, {Text = Actions[id].label, Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -140, 1, 0)})
        local bind = button(row, "None", nil, {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
            Size = UDim2.fromOffset(104, 30), TextSize = 13})
        UI.bindButtons[id] = bind
        connect(bind.Activated, function() Hub.beginCapture(id) end)
    end


    section(page, "Performance")
    local perf = card(page)
    actionRow(perf, "fps_boost")

    section(page, "Theme")
    local winterCard = card(page)
    toggleRow(winterCard, "Winter theme", function() return S.winter end, function(value)
        S.winter = value == true
        Hub.applyTheme()
    end)
    toggleRow(winterCard, "Avengers Hub theme", function() return S.avengers end, function(value)
        Hub.setAvengersTheme(value)
    end)
    toggleRow(winterCard, "Play intro on start", function() return S.intro end, function(value)
        S.intro = value == true
    end)
    toggleRow(winterCard, "New GUI style", function() return S.style == 2 end, function(value)
        S.style = value and 2 or 1
        Hub.applyStyle()
    end)
    local look = card(page)
    look:FindFirstChildOfClass("UIPadding"):Destroy()
    padding(look, 14, 14, 12, 12)
    -- The colors wrap onto more rows when they don't fit on one.
    local swatches = make("Frame", look, {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1})
    padding(swatches, 4, 4, 4, 4)
    make("UIGridLayout", swatches, {CellSize = UDim2.fromOffset(28, 28), CellPadding = UDim2.fromOffset(12, 12),
        SortOrder = Enum.SortOrder.LayoutOrder})
    for index, theme in ipairs(Themes) do
        local swatch = make("TextButton", swatches, {Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(28, 28),
            BackgroundColor3 = theme.swatch or theme.accent, BorderSizePixel = 0, LayoutOrder = index})
        corner(swatch, 14)
        -- A thin edge so the black and white swatches stay visible on any background.
        outline(swatch, "stroke", 0.1)
        local halo = make("Frame", swatch, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(1, 8, 1, 8), BackgroundTransparency = 1})
        corner(halo, 18)
        local ring = make("UIStroke", halo, {Thickness = 2, Transparency = 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, {Color = "text"})
        local swatchScale = pressable(swatch)
        connect(swatch.MouseEnter, function() animate(swatchScale, {Scale = 1.12}, 0.2, Enum.EasingStyle.Back) end)
        connect(swatch.MouseLeave, function() animate(swatchScale, {Scale = 1}, 0.2) end)
        UI.swatches[theme.id] = ring
        connect(swatch.Activated, function()
            Hub.applyTheme(theme.id)
            Hub.persist()
        end)
    end

    section(page, "Window size")
    local sizeCard = card(page)
    sizeCard:FindFirstChildOfClass("UIPadding"):Destroy()
    padding(sizeCard, 14, 14, 12, 12)
    sizeCard:FindFirstChildOfClass("UIListLayout").Padding = UDim.new(0, 10)
    label(sizeCard, {Text = "Hold any corner of the hub and drag it to make the hub bigger or smaller.",
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true,
        TextTruncate = Enum.TextTruncate.None, TextSize = 13, LayoutOrder = order(sizeCard)}, {TextColor3 = "sub"})
    local resetSize = button(sizeCard, "Reset size", nil, {LayoutOrder = order(sizeCard)})
    connect(resetSize.Activated, function()
        S.uiScale = nil
        Hub.layout()
        Hub.persist()
    end)
end

local sender = createWindow({name = "Sender", width = 330, height = 200, header = 50, z = 20, spin = 9,
    default = function(self)
        local area = viewport()
        local x = main.pos.X + (main.width * main.scaleValue) / 2 + (self.width * self.scaleValue) / 2 + 12
        if x + (self.width * self.scaleValue) / 2 > area.X then x = main.pos.X end
        return Vector2.new(x, main.pos.Y + 30)
    end})
sender.pos = savedVector(saved.senderX, saved.senderY)
UI.sender = sender.frame
do
    local head = make("Frame", UI.sender, {Size = UDim2.new(1, 0, 0, 50), BackgroundTransparency = 1, ZIndex = 22})
    UI.senderDrag = make("Frame", head, {Size = UDim2.new(1, -84, 1, 0), BackgroundTransparency = 1, Active = true, ZIndex = 22})
    label(UI.senderDrag, {Text = "Sender", Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -16, 1, 0),
        Font = Enum.Font.GothamBold, TextSize = 17, ZIndex = 23})
    UI.senderClose = iconButton(head, "close", -10)
    UI.senderCollapse, UI.senderCollapseGlyph = iconButton(head, "minus", -44)
    for _, item in ipairs({UI.senderClose, UI.senderCollapse}) do item.ZIndex = 23 end
    UI.senderBox = make("TextBox", UI.sender, {Position = UDim2.fromOffset(14, 52), Size = UDim2.new(1, -28, 0, 70),
        Text = "", PlaceholderText = "Message", ClearTextOnFocus = false,
        TextWrapped = true, MultiLine = true, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, Font = Enum.Font.GothamMedium, TextSize = 15, BorderSizePixel = 0, ZIndex = 22},
        {BackgroundColor3 = "field", TextColor3 = "text", PlaceholderColor3 = "sub"})
    corner(UI.senderBox, 9)
    local boxLine = outline(UI.senderBox, "stroke", 0.15)
    padding(UI.senderBox, 11, 11, 9, 9)
    connect(UI.senderBox.Focused, function() animate(boxLine, {Color = P.accent, Transparency = 0}) end)
    connect(UI.senderBox.FocusLost, function() animate(boxLine, {Color = P.stroke, Transparency = 0.15}) end)
    UI.senderStatus = label(UI.sender, {Text = "", Position = UDim2.fromOffset(16, 126), Size = UDim2.new(1, -32, 0, 18),
        TextSize = 13, Font = Enum.Font.Gotham, ZIndex = 22}, {TextColor3 = "sub"})
    UI.senderSend = button(UI.sender, "Send", "primary", {Position = UDim2.fromOffset(14, 150),
        Size = UDim2.new(1, -28, 0, 36), ZIndex = 22})
end
sender.onCollapse = function(collapsed, instant)
    local vertical = UI.senderCollapseGlyph:FindFirstChild("Vertical")
    local target = UDim2.fromScale(1.8 / 18, collapsed and 11 / 18 or 0)
    if instant then vertical.Size = target else animate(vertical, {Size = target}, 0.3, Enum.EasingStyle.Back) end
end

UI.float = make("TextButton", UI.gui, {Name = "Launcher", Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5),
    Size = UDim2.fromOffset(52, 52), BorderSizePixel = 0, Visible = false, ZIndex = 30}, {BackgroundColor3 = "card"})
corner(UI.float, 26)
do
    local ring = make("UIStroke", UI.float, {Thickness = 2, Color = Color3.new(1, 1, 1), ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
    local ringGradient = make("UIGradient", ring, {})
    themeHooks[#themeHooks + 1] = function()
        ringGradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, P.accent), ColorSequenceKeypoint.new(0.5, P.accentHover),
            ColorSequenceKeypoint.new(1, P.accent)})
    end
    themeHooks[#themeHooks]()
    Tween:Create(ringGradient, TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {Rotation = 360}):Play()
end
UI.floatScale = make("UIScale", UI.float, {Scale = 1})
UI.floatLetter = label(UI.float, {Text = "A", Size = UDim2.fromScale(1, 1), TextSize = 26, Font = Enum.Font.GothamBlack,
    TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 30}, {TextColor3 = "accent"})
-- The launcher shows the same color-following logo as the window.
UI.floatImage = make("ImageLabel", UI.float, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.new(1, -6, 1, -6), BackgroundTransparency = 1, Image = "", ScaleType = Enum.ScaleType.Crop, ZIndex = 31})
corner(UI.floatImage, 23)
themeHooks[#themeHooks + 1] = function()
    animate(UI.floatImage, {ImageColor3 = P.accent:Lerp(Color3.new(1, 1, 1), 0.3)}, 0.35)
end

S.floatPos = savedVector(saved.floatX, saved.floatY)

S.statsPos = savedVector(saved.statsX, saved.statsY)
UI.stats = make("Frame", UI.gui, {Name = "Stats", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(0, 32),
    AutomaticSize = Enum.AutomaticSize.X, BorderSizePixel = 0, BackgroundTransparency = 0.08, Active = true,
    ZIndex = 35}, {BackgroundColor3 = "bg"})
corner(UI.stats, 16)
outline(UI.stats, "stroke", 0.15)
padding(UI.stats, 14, 14, 0, 0)
make("UIListLayout", UI.stats, {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5),
    VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder})
do
    local function part(text, order, bold, role)
        return label(UI.stats, {Text = text, Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X,
            Font = bold and Enum.Font.GothamBold or Enum.Font.GothamMedium, TextSize = bold and 15 or 13,
            TextTruncate = Enum.TextTruncate.None, LayoutOrder = order, ZIndex = 36}, {TextColor3 = role})
    end
    UI.fpsValue = part("0", 1, true, "text")
    part("FPS", 2, false, "sub")
    make("Frame", UI.stats, {Size = UDim2.fromOffset(1, 14), BorderSizePixel = 0, BackgroundTransparency = 0.3,
        LayoutOrder = 3, ZIndex = 36}, {BackgroundColor3 = "stroke"})
    UI.pingValue = part("0", 4, true, "text")
    part("ms", 5, false, "sub")
end

UI.toast = make("CanvasGroup", UI.gui, {Name = "Toast", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 58),
    Size = UDim2.fromOffset(290, 62), BorderSizePixel = 0, GroupTransparency = 1, Visible = false, ZIndex = 40},
    {BackgroundColor3 = "bg"})
corner(UI.toast, 12)
outline(UI.toast, "stroke", 0.1)
UI.toastBar = make("Frame", UI.toast, {Position = UDim2.fromOffset(0, 0), Size = UDim2.new(0, 4, 1, 0), BorderSizePixel = 0,
    BackgroundColor3 = P.good, ZIndex = 41})
UI.toastDot = make("Frame", UI.toast, {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 18, 0.5, 0),
    Size = UDim2.fromOffset(10, 10), BorderSizePixel = 0, BackgroundColor3 = P.good, ZIndex = 41})
corner(UI.toastDot, 5)
UI.toastTitle = label(UI.toast, {Text = "", Position = UDim2.fromOffset(40, 11), Size = UDim2.new(1, -52, 0, 20),
    Font = Enum.Font.GothamBold, TextSize = 16, ZIndex = 41})
UI.toastDetail = label(UI.toast, {Text = "", Position = UDim2.fromOffset(40, 32), Size = UDim2.new(1, -52, 0, 18),
    TextSize = 13, Font = Enum.Font.Gotham, ZIndex = 41}, {TextColor3 = "sub"})

function Hub.toast(good, title, detail)
    S.toastToken = (S.toastToken or 0) + 1
    local token = S.toastToken
    local color = good and P.good or P.bad
    UI.toastBar.BackgroundColor3, UI.toastDot.BackgroundColor3 = color, color
    UI.toastTitle.Text, UI.toastDetail.Text = title, detail or ""
    UI.toast.Visible = true
    UI.toast.GroupTransparency = 1
    UI.toast.Position = UDim2.new(0.5, 0, 0, 40)
    animate(UI.toast, {GroupTransparency = 0, Position = UDim2.new(0.5, 0, 0, 58)}, 0.35, Enum.EasingStyle.Back)
    after(2.5, function()
        if S.toastToken ~= token then return end
        animate(UI.toast, {GroupTransparency = 1, Position = UDim2.new(0.5, 0, 0, 46)}, 0.25, Enum.EasingStyle.Quad)
        after(0.26, function() if S.toastToken == token then UI.toast.Visible = false end end)
    end)
end

function Hub.codeExists(success, message)
    if success then return true end
    local lower = stripTags(message):lower()
    return (lower:find("already", 1, true) ~= nil and lower:find("redeem", 1, true) ~= nil)
        or lower:find("expired", 1, true) ~= nil or lower:find("sold out", 1, true) ~= nil
        or lower:find("out of stock", 1, true) ~= nil
end

function Hub.verdict(seconds)
    local detail = string.format("Redeem took %.2fs", seconds)
    if seconds < 2 then Hub.toast(true, "Account not flagged", detail)
    else Hub.toast(false, "Account flagged", detail) end
end

function Hub.flagCheck(code, seconds, existing)
    if existing and seconds then Hub.verdict(seconds) end
end

function Hub.checkFlag(code)
    code = tostring(code or ""):gsub("[^%w]", "")
    if code == "" or S.flagBusy then return false end
    S.flagBusy = true
    if UI.flagCheck then UI.flagCheck.Text = "Checking" end
    local function finish()
        S.flagBusy = false
        if UI.flagCheck then UI.flagCheck.Text = "Check account" end
    end
    local deadline = os.clock() + 15
    local function attempt()
        if not S.alive then return end
        if not Code.box or not Code.box.Parent or not Code.button or not Code.button.Parent then refreshCodeObjects() end
        local box, confirm = Code.box, Code.button
        local ready = box and confirm and Code.responses and capable() and not Code.flight and not engine.pending
            and box.Active and Code.boxReady
        if not ready then
            if os.clock() < deadline then after(0.25, attempt) else finish() end
            return
        end
        local sentAt
        local flight = {box = box, code = code}
        flight.callback = function(success, message)
            local elapsed = os.clock() - (flight.startedAt or sentAt or os.clock())
            message = tostring(message or "")
            local existing = sentAt ~= nil and Hub.codeExists(success, message)
            defer(function()
                finish()
                if success then pcall(Hub.onRedeemed, code, message) end
                if existing then Hub.verdict(elapsed) end
            end)
        end
        Code.flight = flight
        local wrote = pcall(function() box.Text = code end)
        if not wrote or box.Text ~= code then Code.flight = nil finish() return end
        sentAt = os.clock()
        if not pcall(firesignal, confirm.Activated) then Code.flight = nil finish() return end
        Code.markStart(flight)
    end
    attempt()
    return true
end

local Tags = {byPlayer = {}, paints = {}}

function Tags.create()
    local gui = make("BillboardGui", nil, {Name = "StormHubTag", Size = UDim2.fromOffset(190, 32),
        StudsOffsetWorldSpace = Vector3.new(0, 1.9, 0), AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 150,
        ResetOnSpawn = false, ClipsDescendants = false, Enabled = false})
    local pill = make("Frame", gui, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1)})
    corner(pill, 14)
    padding(pill, 13, 13, 0, 0)
    make("UIListLayout", pill, {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Center})
    local gradient = make("UIGradient", pill, {Rotation = 0, Color = ColorSequence.new(P.accent, P.accentHover)})
    local ring = make("UIStroke", pill, {Thickness = 1.5, Transparency = 0.25, Color = P.accentHover,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
    Tags.paints[gradient] = ring
    label(pill, {Text = Config.ProductName, Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, Font = Enum.Font.GothamBold, TextSize = 15,
        TextTruncate = Enum.TextTruncate.None, TextStrokeTransparency = 0.75}, {TextColor3 = "onAccent"})
    gui.Parent = guiParent
    return gui, gradient
end

themeHooks[#themeHooks + 1] = function()
    for gradient, ring in pairs(Tags.paints) do
        if gradient.Parent then
            gradient.Color = ColorSequence.new(P.accent, P.accentHover)
            ring.Color = P.accentHover
        else
            Tags.paints[gradient] = nil
        end
    end
end

function Tags.adorn(record, character)
    if not character then record.gui.Enabled = false return end
    task.spawn(function()
        local head = character:WaitForChild("Head", 10)
        if head and S.alive and record.gui.Parent and character.Parent then
            record.gui.Adornee = head
            record.gui.Enabled = true
        end
    end)
end

function Tags.attach(target)
    local record = Tags.byPlayer[target]
    if not record then
        local gui, gradient = Tags.create()
        record = {gui = gui, gradient = gradient}
        record.connection = connect(target.CharacterAdded, function(character) Tags.adorn(record, character) end)
        Tags.byPlayer[target] = record
    end
    Tags.adorn(record, target.Character)
end

function Tags.detach(target)
    local record = Tags.byPlayer[target]
    if not record then return end
    Tags.byPlayer[target] = nil
    if record.connection then pcall(record.connection.Disconnect, record.connection) end
    Tags.paints[record.gradient] = nil
    pcall(function() record.gui:Destroy() end)
end

Tags.attach(player)
connect(Players.PlayerRemoving, function(target) if target ~= player then Tags.detach(target) end end)
S.restore[#S.restore + 1] = function()
    for target in pairs(Tags.byPlayer) do Tags.detach(target) end
end

local function clampStats(position)
    local area = viewport()
    local half = math.max(UI.stats.AbsoluteSize.X, 100) / 2
    return Vector2.new(math.clamp(position.X, half + 4, math.max(half + 4, area.X - half - 4)),
        math.clamp(position.Y, 4, math.max(4, area.Y - 36)))
end


do
    local frames, last = 0, os.clock()
    local perf = game:GetService("Stats"):FindFirstChild("PerformanceStats")
    connect(game:GetService("RunService").RenderStepped, function()
        frames += 1
        local now = os.clock()
        if now - last < 0.5 then return end
        local fps = frames / (now - last)
        frames, last = 0, now
        if not UI.stats.Visible then return end
        local ping
        if perf then pcall(function() ping = perf.Ping:GetValue() end) end
        if not ping then pcall(function() ping = player:GetNetworkPing() * 2000 end) end
        ping = math.floor((ping or 0) + 0.5)
        fps = math.floor(fps + 0.5)
        UI.fpsValue.Text, UI.pingValue.Text = tostring(fps), tostring(ping)
        UI.fpsValue.TextColor3 = fps >= 50 and P.text or (fps >= 30 and P.warn or P.bad)
        UI.pingValue.TextColor3 = ping < 100 and P.good or (ping < 200 and P.warn or P.bad)
    end)
end

local function clampFloat(position)
    local area = viewport()
    return Vector2.new(math.clamp(position.X, 32, math.max(32, area.X - 32)), math.clamp(position.Y, 32, math.max(32, area.Y - 32)))
end

function Hub.layout()
    local area = viewport()
    local touch = Input.TouchEnabled and not Input.MouseEnabled
    local compact = touch or area.X < 820 or area.Y < 520
    if compact then
        main.width, main.height = math.clamp(area.X - 20, 360, 540), math.clamp(area.Y - 20, 300, 400)
    else
        main.width, main.height = 660, 460
    end
    local header = compact and 50 or 58
    local chrome = header + (compact and 42 or 46)
    main.header = header
    Layout.compact, Layout.side, Layout.chrome = compact, 0, chrome
    -- The size you picked by dragging a corner wins; otherwise the hub fits itself to the screen.
    local fit = math.min((area.X - 16) / main.width, (area.Y - 16) / main.height)
    Layout.minScale, Layout.maxScale = 0.4, math.max(0.4, math.min(fit, 1.6))
    Layout.scale = S.uiScale and math.clamp(S.uiScale, Layout.minScale, Layout.maxScale) or math.clamp(fit, 0.45, 1)
    main:setScale(Layout.scale)
    main:applySize(false)
    local logo = compact and 34 or 40
    UI.side.Size = UDim2.new(1, 0, 0, chrome)
    UI.brand.Size = UDim2.new(1, 0, 0, header)
    UI.logo.Size = UDim2.fromOffset(logo, logo)
    UI.brandTitle.Position = UDim2.fromOffset(logo + 22, compact and 6 or 9)
    UI.brandTitle.TextSize = compact and 19 or 21
    UI.brandSub.Position = UDim2.fromOffset(logo + 23, compact and 29 or 33)
    UI.headerLine.Position = UDim2.new(0, 14, 0, header)
    UI.tabBar.Position = UDim2.fromOffset(10, header + 4)
    UI.tabBar.Size = UDim2.new(1, -20, 0, chrome - header - 9)
    UI.main.Position = UDim2.fromOffset(0, chrome)
    UI.main.Size = UDim2.new(1, 0, 1, -chrome)
    -- Tab names only show when each tab is wide enough; otherwise the tabs show just their icons.
    local showNames = (main.width - 20) / #Tabs >= 98
    for _, item in pairs(UI.tabs) do item.name.Visible = showNames end
    main:place()
    sender:setScale(math.clamp(math.min((area.X - 16) / sender.width, (area.Y - 16) / sender.height, 1), 0.45, 1))
    sender:applySize(false)
    if sender.pos then sender:place() end
    S.floatPos = clampFloat(S.floatPos or Vector2.new(area.X - 56, area.Y * 0.4))
    UI.float.Position = UDim2.fromOffset(S.floatPos.X, S.floatPos.Y)
    S.statsPos = clampStats(S.statsPos or Vector2.new(area.X / 2, 12))
    UI.stats.Position = UDim2.fromOffset(S.statsPos.X, S.statsPos.Y)
end

local function draggable(handle, getPosition, setPosition, finished)
    local drag
    connect(handle.InputBegan, function(input)
        if S.closing then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            drag = {input = input, start = input.Position, origin = getPosition(), moved = false}
        end
    end)
    connect(Input.InputChanged, function(input)
        if not drag then return end
        local mouse = drag.input.UserInputType == Enum.UserInputType.MouseButton1
        if (mouse and input.UserInputType ~= Enum.UserInputType.MouseMovement) or (not mouse and input ~= drag.input) then return end
        local delta = input.Position - drag.start
        if not drag.moved and Vector2.new(delta.X, delta.Y).Magnitude < 4 then return end
        drag.moved = true
        setPosition(drag.origin + Vector2.new(delta.X, delta.Y))
    end)
    connect(Input.InputEnded, function(input)
        if not drag then return end
        local mouse = drag.input.UserInputType == Enum.UserInputType.MouseButton1
        if input == drag.input or (mouse and input.UserInputType == Enum.UserInputType.MouseButton1) then
            local moved = drag.moved
            drag = nil
            if finished then finished(moved) end
        end
    end)
end

draggable(UI.drag, function() return main.pos end, function(position) main:place(position) end,
    function(moved) if moved then Hub.persist() end end)

-- Resize: hold any corner of the window and drag it. The whole hub scales and the opposite corner stays put.
UI.resizeHandles = {}
for _, spot in ipairs({{-1, -1}, {1, -1}, {-1, 1}, {1, 1}}) do
    local sx, sy = spot[1], spot[2]
    local ax, ay = sx > 0 and 1 or 0, sy > 0 and 1 or 0
    -- Small enough that they don't cover the close/minimize buttons or the edges of the bottom-row buttons.
    local reach = sy < 0 and 20 or 24
    local handle = make("TextButton", UI.window, {Name = "Resize", Text = "", AutoButtonColor = false,
        AnchorPoint = Vector2.new(ax, ay), Position = UDim2.fromScale(ax, ay), Size = UDim2.fromOffset(reach, reach),
        BackgroundTransparency = 1, ZIndex = 40})
    local marks = {}
    for _, horizontal in ipairs({true, false}) do
        local mark = make("Frame", handle, {AnchorPoint = Vector2.new(ax, ay),
            Position = UDim2.new(ax, ax == 1 and -5 or 5, ay, ay == 1 and -5 or 5),
            Size = horizontal and UDim2.fromOffset(12, 2) or UDim2.fromOffset(2, 12),
            BorderSizePixel = 0, BackgroundTransparency = 0.55, ZIndex = 41}, {BackgroundColor3 = "accent"})
        corner(mark, 1)
        marks[#marks + 1] = mark
    end
    UI.resizeHandles[#UI.resizeHandles + 1] = handle
    local drag
    local function highlight(on)
        for _, mark in ipairs(marks) do animate(mark, {BackgroundTransparency = on and 0 or 0.55}, 0.15) end
    end
    connect(handle.MouseEnter, function() highlight(true) end)
    connect(handle.MouseLeave, function() if not drag then highlight(false) end end)
    connect(handle.InputBegan, function(input)
        if S.closing or main.collapsed or not main.pos then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local scale = main.scaleValue
        local width, height = main.width * scale, main.height * scale
        local left, top = main.pos.X - width / 2, main.pos.Y
        drag = {input = input, start = input.Position, scale = scale, width = width, height = height,
            fixedX = sx > 0 and left or left + width, fixedY = sy > 0 and top or top + height}
        highlight(true)
    end)
    connect(Input.InputChanged, function(input)
        if not drag then return end
        local mouse = drag.input.UserInputType == Enum.UserInputType.MouseButton1
        if (mouse and input.UserInputType ~= Enum.UserInputType.MouseMovement) or (not mouse and input ~= drag.input) then return end
        local delta = input.Position - drag.start
        local grow = ((drag.width + sx * delta.X) / drag.width + (drag.height + sy * delta.Y) / drag.height) / 2
        local scale = math.clamp(drag.scale * grow, Layout.minScale or 0.4, Layout.maxScale or 1.6)
        local width, height = main.width * scale, main.height * scale
        local left = sx > 0 and drag.fixedX or drag.fixedX - width
        local top = sy > 0 and drag.fixedY or drag.fixedY - height
        main:setScale(scale)
        main:place(Vector2.new(left + width / 2, top))
    end)
    connect(Input.InputEnded, function(input)
        if not drag then return end
        local mouse = drag.input.UserInputType == Enum.UserInputType.MouseButton1
        if input == drag.input or (mouse and input.UserInputType == Enum.UserInputType.MouseButton1) then
            drag = nil
            highlight(false)
            S.uiScale = math.floor(main.scaleValue * 1000 + 0.5) / 1000
            Hub.persist()
        end
    end)
end
do
    -- No resizing while the hub is minimized to just its header.
    local collapseBefore = main.onCollapse
    main.onCollapse = function(collapsed, instant)
        collapseBefore(collapsed, instant)
        for _, handle in ipairs(UI.resizeHandles) do handle.Visible = not collapsed end
    end
end
draggable(UI.senderDrag, function() return sender.pos end, function(position) sender:place(position) end,
    function(moved) if moved then Hub.persist() end end)
draggable(UI.float, function() return S.floatPos end, function(position)
    S.floatPos = clampFloat(position)
    UI.float.Position = UDim2.fromOffset(S.floatPos.X, S.floatPos.Y)
end, function(moved)
    if moved then Hub.persist() else Hub.setHidden(false) end
end)
draggable(UI.stats, function() return S.statsPos end, function(position)
    S.statsPos = clampStats(position)
    UI.stats.Position = UDim2.fromOffset(S.statsPos.X, S.statsPos.Y)
end, function(moved) if moved then Hub.persist() end end)

function Hub.showLauncher(visible)
    S.floatToken = (S.floatToken or 0) + 1
    local token = S.floatToken
    if visible then
        UI.float.Visible = true
        UI.floatScale.Scale = 0
        animate(UI.floatScale, {Scale = 1}, 0.4, Enum.EasingStyle.Back)
    else
        animate(UI.floatScale, {Scale = 0}, 0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        task.delay(0.17, function() if S.floatToken == token then UI.float.Visible = false end end)
    end
end

function Hub.setHidden(hidden)
    if S.closing then return end
    hidden = hidden == true
    if hidden == S.hidden and (hidden or main.visible) then return end
    S.hidden = hidden
    if hidden then
        main:hide()
        if sender.visible then sender:hide() S.senderWasOpen = true end
        Hub.showLauncher(true)
    else
        Hub.showLauncher(false)
        main:show()
        if S.senderWasOpen then S.senderWasOpen = nil sender:show() end
    end
    for _, update in ipairs(UI.updates) do update() end
end

function Hub.openSender()
    if sender.visible then sender:hide() return end
    sender:place()
    sender:show()
end

function Hub.applyTheme(id)
    if id == "grape" then id = "storm" end
    if id == "strawberry" then id = "rose" end -- Existing saved color choice.
    if type(id) == "string" then
        for _, item in ipairs(Themes) do if item.id == id then S.theme = id end end
    end
    buildPalette(S.theme, S.winter)
    if UI.snow then UI.snow.Visible = S.winter end
    prunePainted()
    for _, entry in ipairs(painted) do entry[1][entry[2]] = P[entry[3]] end
    for _, hook in ipairs(themeHooks) do hook() end
    -- Window button icons (close, minimize) follow palette changes too, not just after a hover.
    for _, item in ipairs(UI.glyphs) do tintGlyph(item.box, P[item.role], 0) end
    for themeId, ring in pairs(UI.swatches) do
        animate(ring, {Transparency = themeId == S.theme and 0 or 1})
    end
    for _, update in ipairs(UI.updates) do update(true) end
    Hub.paintTabs(true)
    Hub.applyStyle()
    if Hub.refresh then Hub.refresh(true) end
end

-- GUI style 1 is the normal look. Style 2 (Settings > Theme > New GUI style) keeps the same layout but uses
-- a solid pill tab bar, a color wash in the header, a round logo, rounder corners, cards whose edge glows
-- in the chosen color, and colored section headings.
function Hub.applyStyle()
    local two = S.style == 2
    local windowCorner = UI.window:FindFirstChildOfClass("UICorner")
    if windowCorner then windowCorner.CornerRadius = UDim.new(0, two and 18 or 14) end
    UI.banner.Visible = two
    UI.logoCorner.CornerRadius = two and UDim.new(0.5, 0) or UDim.new(0, 10)
    UI.logoImageCorner.CornerRadius = UI.logoCorner.CornerRadius
    UI.tabBar.BackgroundColor3 = P.field
    UI.tabBar.BackgroundTransparency = two and 0 or 1
    UI.tabBarStroke.Transparency = two and 0.25 or 1
    UI.indicator.BackgroundColor3 = two and P.accent or P.soft
    UI.indicator.Size = UDim2.new(1 / #Tabs, -6, 1, two and -6 or 0)
    local tab = UI.tabs[S.tab]
    if tab then UI.indicator.Position = UDim2.new((tab.index - 1) / #Tabs, 3, 0, two and 3 or 0) end
    UI.indicatorBar.Visible = not two
    for _, item in ipairs(UI.cards) do
        item.corner.CornerRadius = UDim.new(0, two and 14 or 12)
        item.glow.Enabled = two
        if two then
            item.edge.Color = Color3.new(1, 1, 1)
            item.edge.Transparency = 0.2
            item.glow.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, P.accent),
                ColorSequenceKeypoint.new(0.35, P.stroke), ColorSequenceKeypoint.new(1, P.stroke)})
        else
            item.edge.Color = P.stroke
            item.edge.Transparency = 0.35
        end
    end
    for _, heading in ipairs(UI.sections) do heading.TextColor3 = two and P.accent or P.sub end
    Hub.paintTabs(true)
end

function Hub.refreshBinds()
    for id, bind in pairs(UI.bindButtons) do
        if S.capturing ~= id then bind.Text = keyText(S.binds[id]) end
    end
    for _, item in ipairs(UI.keyChips) do
        local key = S.binds[item.id]
        item.chip.Visible = key ~= nil and not Layout.compact
        item.chip.Text = keyText(key)
    end
end

function Hub.beginCapture(id)
    if S.capturing then
        local previousButton = UI.bindButtons[S.capturing]
        if previousButton then previousButton.Text = keyText(S.binds[S.capturing]) end
    end
    S.capturing = id
    UI.bindButtons[id].Text = "Press a key"
end

local function runAction(id)
    local action = Actions[id]
    if not action or not S.ready or S.closing then return end
    action.set(not action.get())
    for _, update in ipairs(UI.updates) do update() end
    Hub.persist()
end

connect(Input.InputBegan, function(input, processed)
    if not S.alive or S.closing then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if S.capturing then
        local id = S.capturing
        local keyCode = input.KeyCode
        S.capturing = nil
        if keyCode == Enum.KeyCode.Backspace then
            S.binds[id] = nil
        elseif keyCode ~= Enum.KeyCode.Escape and keyCode ~= Enum.KeyCode.Unknown then
            for other, name in pairs(S.binds) do if name == keyCode.Name then S.binds[other] = nil end end
            S.binds[id] = keyCode.Name
        end
        Hub.refreshBinds()
        Hub.persist()
        return
    end
    if processed or Input:GetFocusedTextBox() then return end
    local name = input.KeyCode.Name
    for id, key in pairs(S.binds) do
        if key == name then runAction(id) end
    end
end)

local function timeAgo(at)
    local seconds = math.max(0, os.time() - at)
    if seconds < 45 then return "Just now" end
    if seconds < 3600 then return math.floor(seconds / 60 + 0.5) .. "m ago" end
    if seconds < 86400 then return math.floor(seconds / 3600) .. "h ago" end
    return os.date("%b %d", at)
end

local MutationColors = {
    gold = Color3.fromRGB(255, 205, 64), diamond = Color3.fromRGB(110, 225, 255), rainbow = Color3.fromRGB(255, 120, 220),
    lava = Color3.fromRGB(255, 110, 50), bloodrot = Color3.fromRGB(220, 40, 60), candy = Color3.fromRGB(255, 140, 200),
    galaxy = Color3.fromRGB(150, 110, 255), radioactive = Color3.fromRGB(130, 255, 90), cursed = Color3.fromRGB(170, 60, 255),
    ["yin yang"] = Color3.fromRGB(225, 225, 225), celestial = Color3.fromRGB(150, 210, 255), divine = Color3.fromRGB(255, 240, 150),
}

local Icons = {templates = {}, waiting = {}}
function Icons.find(name)
    local models = ReplicatedStorage:FindFirstChild("Models")
    local animals = models and models:FindFirstChild("Animals")
    local found = animals and animals:FindFirstChild(name)
    if not found then
        local controllers = ReplicatedStorage:FindFirstChild("Controllers")
        local stream = controllers and controllers:FindFirstChild("AssetStreamController")
        local cache = stream and stream:FindFirstChild("AssetCache")
        found = cache and cache:FindFirstChild(name)
    end
    if not found or not found:IsA("Model") then return nil end
    local expected = found:GetAttribute("__AssetDescendantCount")
    if typeof(expected) == "number" and expected > #found:GetDescendants() then return nil end
    return found
end

function Icons.template(name)
    if Icons.templates[name] ~= nil then return Icons.templates[name] or nil end
    if Icons.waiting[name] then
        local deadline = os.clock() + 12
        while Icons.waiting[name] and os.clock() < deadline do task.wait(0.1) end
        return Icons.templates[name] or nil
    end
    Icons.waiting[name] = true
    local model = Icons.find(name)
    if not model then
        if Icons.assets == nil then
            local shared = ReplicatedStorage:FindFirstChild("Shared")
            local module = shared and shared:FindFirstChild("BrainrotAssets")
            local ok, assets = pcall(require, module)
            Icons.assets = ok and type(assets) == "table" and assets or false
        end
        if Icons.assets and type(Icons.assets.preload) == "function" then task.spawn(pcall, Icons.assets.preload, {name}) end
        local deadline = os.clock() + 10
        repeat
            task.wait(0.15)
            model = Icons.find(name)
        until model or os.clock() > deadline or not S.alive
    end
    Icons.templates[name] = model or false
    Icons.waiting[name] = nil
    return model
end

function Icons.render(holder, name)
    task.spawn(function()
        local template = Icons.template(name)
        if not template or not S.alive or not holder.Parent then return end
        pcall(function()
            local clone = template:Clone()
            for _, item in ipairs(clone:GetDescendants()) do
                if item:IsA("LuaSourceContainer") or item:IsA("Sound") or item:IsA("ParticleEmitter")
                    or item:IsA("Trail") or item:IsA("Beam") or item:IsA("BillboardGui") or item:IsA("ProximityPrompt")
                    or item:IsA("Light") then
                    item:Destroy()
                elseif item:IsA("BasePart") then
                    item.Anchored = true
                end
            end
            clone:PivotTo(CFrame.new())
            local view = Instance.new("ViewportFrame")
            view.BackgroundTransparency = 1
            view.Size = UDim2.fromScale(1, 1)
            view.ImageTransparency = 1
            view.Ambient = Color3.fromRGB(215, 215, 215)
            view.LightColor = Color3.fromRGB(255, 255, 255)
            view.LightDirection = Vector3.new(0.3, -0.6, 1)
            view.ZIndex = holder.ZIndex + 1
            local camera = Instance.new("Camera")
            camera.FieldOfView = 30
            camera.Parent = view
            view.CurrentCamera = camera
            clone.Parent = view
            local boxCFrame, size = clone:GetBoundingBox()
            local center = boxCFrame.Position
            local radius = math.max(size.X, size.Y) * 0.44 + size.Z * 0.1
            local distance = radius / math.tan(math.rad(camera.FieldOfView / 2))
            local direction = CFrame.Angles(0, math.rad(-25), 0):VectorToWorldSpace(Vector3.new(0, 0.18, -1).Unit)
            camera.CFrame = CFrame.lookAt(center + direction * distance, center)
            view.Parent = holder
            animate(view, {ImageTransparency = 0}, 0.35)
            local fallback = holder:FindFirstChild("Fallback")
            if fallback then fallback.Visible = false end
        end)
    end)
end

local function historyRow(entry, index, animated)
    local container = make("Frame", UI.historyList, {Size = UDim2.new(1, 0, 0, 68), BackgroundTransparency = 1, LayoutOrder = index})
    local row = Glass.add(make("Frame", container, {Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(animated and 30 or 0, 0),
        BorderSizePixel = 0}, {BackgroundColor3 = "card"}), 0)
    if animated then row.BackgroundTransparency = 1 end
    corner(row, 12)
    local line = outline(row, "stroke", animated and 1 or 0.35)
    if animated then
        task.delay(math.min(index - 1, 10) * 0.04, function()
            animate(row, {Position = UDim2.fromOffset(0, 0), BackgroundTransparency = Glass.alpha(0)}, 0.4)
            animate(line, {Transparency = 0.35}, 0.4)
        end)
    end
    local holder = make("Frame", row, {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 9, 0.5, 0),
        Size = UDim2.fromOffset(50, 50), BorderSizePixel = 0}, {BackgroundColor3 = "field"})
    corner(holder, 10)
    local fallback = glyph(holder, "gift", 20)
    fallback.Name = "Fallback"
    fallback.AnchorPoint, fallback.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
    if entry.reward then Icons.render(holder, entry.reward) end
    label(row, {Text = entry.code, Position = UDim2.fromOffset(70, 12), Size = UDim2.new(1, -160, 0, 20),
        Font = Enum.Font.RobotoMono, TextSize = 14})
    label(row, {Text = timeAgo(entry.at), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 13),
        Size = UDim2.fromOffset(84, 18), TextSize = 12, Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Right}, {TextColor3 = "sub"})
    if entry.player then
        label(row, {Text = "@" .. entry.player, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 38),
            Size = UDim2.fromOffset(130, 18), TextSize = 12, Font = Enum.Font.GothamMedium,
            TextXAlignment = Enum.TextXAlignment.Right}, {TextColor3 = "sub"})
    end
    local rewardLine = make("Frame", row, {Position = UDim2.fromOffset(70, 36),
        Size = UDim2.new(1, entry.player and -220 or -82, 0, 22), ClipsDescendants = true, BackgroundTransparency = 1})
    make("UIListLayout", rewardLine, {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6),
        VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder})
    label(rewardLine, {Text = entry.reward or "Unknown reward", Size = UDim2.fromOffset(0, 20),
        AutomaticSize = Enum.AutomaticSize.X, TextSize = 14, LayoutOrder = 1,
        Font = entry.reward and Enum.Font.GothamBold or Enum.Font.Gotham}, {TextColor3 = entry.reward and "accent" or "sub"})
    if entry.mutation and entry.mutation ~= "" then
        local color = MutationColors[entry.mutation:lower()]
        local chip = label(rewardLine, {Text = entry.mutation, Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X,
            TextSize = 12, Font = Enum.Font.GothamBold, BackgroundTransparency = 0, LayoutOrder = 2,
            TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = color or P.text}, {BackgroundColor3 = "field"})
        if not color then paint(chip, "TextColor3", entry.mutation == "Base" and "sub" or "text") end
        corner(chip, 6)
        padding(chip, 7, 7, 0, 0)
    end
end

function Hub.renderHistory(force)
    if not force and not S.historyDirty and UI.historyList:GetAttribute("built") then return end
    S.historyDirty = false
    UI.historyList:SetAttribute("built", true)
    for _, child in ipairs(UI.historyList:GetChildren()) do
        if not child:IsA("UIListLayout") then child:Destroy() end
    end
    prunePainted()
    Glass.prune()
    local list = S.historyView == "everyone" and (S.shared or {}) or history
    UI.historyCount.Text = #history == 1 and "1 code redeemed" or (#history .. " codes redeemed")
    if #list == 0 then
        local empty = Glass.add(make("Frame", UI.historyList, {Size = UDim2.new(1, 0, 0, 96), BorderSizePixel = 0, LayoutOrder = 1},
            {BackgroundColor3 = "card"}), 0)
        corner(empty, 12)
        outline(empty, "stroke", 0.35)
        local icon = glyph(empty, "gift", 26)
        icon.AnchorPoint, icon.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 20)
        label(empty, {Text = "No codes yet", Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 20), TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Center}, {TextColor3 = "sub"})
        return
    end
    for index, entry in ipairs(list) do historyRow(entry, index, not S.hidden) end
end

local function writeHistory()
    local list = {}
    for index, entry in ipairs(history) do
        list[index] = {code = entry.code, at = entry.at, reward = entry.reward, mutation = entry.mutation, message = entry.message}
    end
    local raw = Files.encode(list)
    if raw then Files.write(Paths.history, raw) end
end

local function saveHistory()
    if S.historySaveJob then return end
    S.historySaveJob = after(0.5, function()
        S.historySaveJob = nil
        writeHistory()
    end)
end

local httpRequest = (type(syn) == "table" and syn.request) or (type(http) == "table" and http.request)
    or (type(http_request) == "function" and http_request) or (type(request) == "function" and request)
    or (type(fluxus) == "table" and fluxus.request)

local serverReady = type(httpRequest) == "function" and type(Config.ServerUrl) == "string" and Config.ServerUrl ~= ""

local function serverCall(method, path, payload)
    if not serverReady then return nil end
    local ok, response = pcall(httpRequest, {
        Url = Config.ServerUrl:gsub("/+$", "") .. path, Method = method,
        Headers = {["Content-Type"] = "application/json", ["X-Hub-Key"] = tostring(Config.ServerKey or "")},
        Body = payload and Files.encode(payload) or nil,
    })
    if not ok or type(response) ~= "table" then return nil end
    return tonumber(response.StatusCode) or 0, Files.decode(response.Body)
end

local function cleanText(value, limit)
    if type(value) ~= "string" then return nil end
    value = stripTags(value):gsub("[%c]", ""):match("^%s*(.-)%s*$")
    if value == "" then return nil end
    return value:sub(1, limit)
end

function Hub.fetchShared(force)
    if not serverReady or S.fetching then return end
    if not force and S.sharedAt and os.clock() - S.sharedAt < 10 then return end
    S.fetching = true
    task.spawn(function()
        local status, data = serverCall("GET", "/recent?limit=40")
        defer(function()
            S.fetching = false
            S.sharedAt = os.clock()
            if status ~= 200 or type(data) ~= "table" or type(data.redeems) ~= "table" then return end
            local list, signature = {}, {}
            for _, item in ipairs(data.redeems) do
                local code = type(item) == "table" and cleanText(item.code, 60)
                if code and tonumber(item.at) then
                    list[#list + 1] = {code = code, at = tonumber(item.at), reward = cleanText(item.reward, 80),
                        mutation = cleanText(item.mutation, 40), player = cleanText(item.player, 20)}
                    signature[#signature + 1] = code .. ":" .. item.at
                end
                if #list >= 40 then break end
            end
            signature = table.concat(signature, "|")
            if signature == S.sharedSignature then return end
            S.shared, S.sharedSignature = list, signature
            if S.tab == "redeemed" and S.historyView == "everyone" and not S.hidden then Hub.renderHistory(true) end
        end)
    end)
end

function Hub.setHistoryView(view)
    if view == "everyone" and not serverReady then view = "mine" end
    S.historyView = view
    for key, option in pairs(UI.viewButtons) do
        animate(option, {TextColor3 = key == view and P.text or P.sub}, 0.2)
    end
    animate(UI.viewPill, {Position = view == "everyone" and UDim2.fromOffset(3, 3) or UDim2.new(0.5, 0, 0, 3)}, 0.3,
        Enum.EasingStyle.Back)
    UI.historyClear.Visible = view == "mine"
    Hub.renderHistory(true)
    if view == "everyone" then Hub.fetchShared() end
end

function Hub.sendWebhook(entry)
    local fields = {
        {name = "Player", value = player.Name, inline = true},
        {name = "Code", value = tostring(entry.code):sub(1, 60), inline = true},
    }
    if entry.reward then fields[#fields + 1] = {name = "Reward", value = entry.reward:sub(1, 80), inline = true} end
    if entry.mutation then fields[#fields + 1] = {name = "Mutation", value = entry.mutation:sub(1, 40), inline = true} end
    local payload = {
        username = Config.ProductName,
        allowed_mentions = {parse = {}},
        embeds = {{
            title = "Code redeemed",
            description = cleanText(entry.message, 200),
            color = 11158015,
            fields = fields,
            footer = {text = Config.ProductName},
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ", entry.at),
        }},
    }
    local body = Files.encode(payload)
    if not body then return false end
    local url = Config.WebhookUrl .. (Config.WebhookUrl:find("?", 1, true) and "&" or "?") .. "wait=true"
    for attempt = 1, 3 do
        local ok, response = pcall(httpRequest, {
            Url = url, Method = "POST",
            Headers = {["Content-Type"] = "application/json"}, Body = body,
        })
        local status = ok and type(response) == "table" and tonumber(response.StatusCode) or 0
        if status == 200 or status == 204 then return true end
        if status == 429 and attempt < 3 then
            local data = Files.decode(response.Body)
            local delay = math.max(0.1, type(data) == "table" and tonumber(data.retry_after) or 1)
            if delay > 30 then return false end
            task.wait(delay)
        elseif status >= 500 and attempt < 3 then
            task.wait(attempt)
        else
            return false
        end
    end
    return false
end

local function sendRedeem(entry)
    if entry.sent or entry.sending then return end
    local webhookReady = type(httpRequest) == "function" and type(Config.WebhookUrl) == "string" and Config.WebhookUrl ~= ""
    if not serverReady and not webhookReady then return end
    entry.sending = true
    task.spawn(function()
        if webhookReady and not entry.webhookSent then entry.webhookSent = Hub.sendWebhook(entry) end
        if serverReady and not entry.serverSent then
            local payload = {code = entry.code, reward = entry.reward, mutation = entry.mutation,
                player = player.Name, displayName = player.DisplayName, userId = player.UserId,
                message = stripTags(entry.message or ""):sub(1, 180)}
            entry.serverSent = serverCall("POST", "/redeem", payload) == 200
            if entry.serverSent then defer(function() Hub.fetchShared(true) end) end
        end
        entry.sent = (not webhookReady or entry.webhookSent) and (not serverReady or entry.serverSent)
        entry.sending = false
        if not entry.sent then warn(Config.ProductName .. ": redemption notification could not be delivered") end
    end)
end

function Hub.onRedeemed(code, message)
    S.session += 1
    local _, names = recognizeReward(message)
    local entry = {code = code, at = os.time(), message = stripTags(message):sub(1, 200),
        reward = type(names) == "table" and names[1] or nil, clock = os.clock()}
    table.insert(history, 1, entry)
    while #history > Config.HistoryLimit do table.remove(history) end
    S.historyDirty = true
    saveHistory()
    if S.tab == "redeemed" and not S.hidden then Hub.renderHistory() end
    after(8, function() sendRedeem(entry) end)
    if requestRefresh then requestRefresh() end
end

function Hub.onRewardSpawned(record)
    for _, entry in ipairs(history) do
        if entry.code == record.code and entry.clock and os.clock() - entry.clock < 120 then
            entry.reward = record.name or entry.reward
            entry.mutation = record.mutation
            S.historyDirty = true
            saveHistory()
            if S.tab == "redeemed" and not S.hidden then Hub.renderHistory() end
            sendRedeem(entry)
            return
        end
    end
end

connect(UI.historyClear.Activated, function()
    table.clear(history)
    S.historyDirty = true
    saveHistory()
    Hub.renderHistory(true)
end)

local function configPath(name) return Paths.configs .. "/" .. name .. ".json" end
local function cleanName(value)
    return (tostring(value or ""):gsub("[^%w%s%-_]", ""):gsub("^%s+", ""):gsub("%s+$", "")):sub(1, 32)
end
function Hub.configSelected()
    local name = cleanName(UI.configName.Text)
    return name ~= "" and name or nil
end
function Hub.configMessage(text)
    UI.configStatus.Text = text
    UI.configStatus.Visible = true
    UI.configStatus.TextTransparency = 1
    animate(UI.configStatus, {TextTransparency = 0}, 0.25)
    local stamp = os.clock()
    S.configMessageAt = stamp
    after(3.5, function()
        if S.configMessageAt ~= stamp then return end
        animate(UI.configStatus, {TextTransparency = 1}, 0.3)
        after(0.31, function() if S.configMessageAt == stamp then UI.configStatus.Visible = false end end)
    end)
end

local function collectConfig()
    local manual = engine.autoMode and engine.manualBeforeAuto or engine
    local binds = {}
    for id, key in pairs(S.binds) do binds[id] = key end
    return {
        version = 3,
        redeemer = {enabled = manual.enabled == true, guess = manual.guess == true, partsMode = manual.partsMode == true,
            amount = engine.amount, autoMode = engine.autoMode},
        fpsBoost = S.fps.enabled,
        helper = {freeze = helperFlag("frozen"), anti_ragdoll = helperFlag("antiRagdoll"), auto_buy = helperFlag("autoBuy"),
            quick_grab = helperFlag("quickGrab"), quick_sell = helperFlag("quickSell")},
        binds = binds, theme = S.theme, winter = S.winter, avengers = S.avengers, style = S.style,
    }
end

local function applyConfig(data)
    if type(data) ~= "table" then return false end
    local redeemer = type(data.redeemer) == "table" and data.redeemer or {}
    if type(redeemer.amount) == "number" then engine:setAmount(redeemer.amount) end
    if engine.autoMode then engine:setAutoMode(false) end
    engine:setPartsMode(redeemer.partsMode == true)
    engine:setGuess(redeemer.guess == true)
    engine:setEnabled(redeemer.enabled == true)
    if redeemer.autoMode == true then engine:setAutoMode(true) end
    if redeemer.enabled or redeemer.autoMode then Hub.ensureSetup() end
    if type(data.fpsBoost) == "boolean" then setActionValue("fps_boost", data.fpsBoost) end
    if type(data.helper) == "table" then
        for id, value in pairs(data.helper) do
            if Actions[id] and type(value) == "boolean" and (value or helperState) then setActionValue(id, value) end
        end
    end
    if type(data.binds) == "table" then
        S.binds = {}
        for id, key in pairs(data.binds) do if Actions[id] then S.binds[id] = validKey(key) end end
        Hub.refreshBinds()
    end
    if type(data.winter) == "boolean" then S.winter = data.winter end
    if type(data.avengers) == "boolean" then Hub.setAvengersTheme(data.avengers) end
    if data.style == 1 or data.style == 2 then S.style = data.style end
    Hub.applyTheme(type(data.theme) == "string" and data.theme or nil)
    for _, update in ipairs(UI.updates) do update() end
    if requestRefresh then requestRefresh() end
    return true
end

function Hub.renderConfigs()
    for _, child in ipairs(UI.configList:GetChildren()) do
        if not child:IsA("UIGridLayout") then child:Destroy() end
    end
    prunePainted()
    local selected = Hub.configSelected()
    for _, path in ipairs(Files.list(Paths.configs)) do
        local name = tostring(path):gsub("\\", "/"):match("([^/]+)%.json$")
        if name then
            local chip = button(UI.configList, name, name == selected and "primary" or nil,
                {Name = name, TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd})
            if S.autoload == name and name ~= selected then
                local mark = chip:FindFirstChildOfClass("UIStroke")
                if mark then mark.Color, mark.Transparency = P.accent, 0 end
            end
            connect(chip.Activated, function()
                UI.configName.Text = name
                Hub.renderConfigs()
                for _, update in ipairs(UI.updates) do update() end
            end)
        end
    end
end

connect(UI.configSave.Activated, function()
    local name = Hub.configSelected()
    if not name then Hub.configMessage("Type a name first") return end
    if not Files.available then Hub.configMessage("Your executor can't save files") return end
    local raw = Files.encode(collectConfig())
    if raw and Files.write(configPath(name), raw) then Hub.configMessage("Saved " .. name)
    else Hub.configMessage("Couldn't save " .. name) end
    Hub.renderConfigs()
end)
connect(UI.configLoad.Activated, function()
    local name = Hub.configSelected()
    if not name then Hub.configMessage("Pick a config to load") return end
    local data = Files.decode(Files.read(configPath(name)))
    if data and applyConfig(data) then
        Hub.configMessage("Loaded " .. name)
        Hub.persist()
    else
        Hub.configMessage("Couldn't find " .. name)
    end
end)
connect(UI.configDelete.Activated, function()
    local name = Hub.configSelected()
    if not name then Hub.configMessage("Pick a config to delete") return end
    if not Files.exists(configPath(name)) then Hub.configMessage("Couldn't find " .. name) return end
    if S.confirmDelete ~= name then
        S.confirmDelete = name
        UI.configDelete.Text = "Sure?"
        after(3, function()
            if S.confirmDelete == name then S.confirmDelete = nil UI.configDelete.Text = "Delete" end
        end)
        return
    end
    S.confirmDelete = nil
    UI.configDelete.Text = "Delete"
    Files.delete(configPath(name))
    if S.autoload == name then S.autoload = nil end
    UI.configName.Text = ""
    Hub.configMessage("Deleted " .. name)
    Hub.renderConfigs()
    Hub.persist()
end)
connect(UI.configName.FocusLost, function()
    Hub.renderConfigs()
    for _, update in ipairs(UI.updates) do update() end
end)

function Hub.persist(immediate)
    if not S.alive or S.restoring then return end
    local function write()
        S.persistJob = nil
        local manual = engine.autoMode and engine.manualBeforeAuto or engine
        local value = {
            version = 3,
            enabled = manual.enabled == true, guess = manual.guess == true, partsMode = manual.partsMode == true,
            partsModeBeforeGuess = manual.partsModeBeforeGuess == true,
            amount = engine.amount, autoMode = engine.autoMode,
            fpsBoost = S.fps.enabled, theme = S.theme, themeRevision = 4, winter = S.winter, autoload = S.autoload,
            avengers = S.avengers, intro = S.intro, uiScale = S.uiScale, style = S.style,
            binds = S.binds, tab = S.tab, collapsed = main.collapsed,
            x = main.pos and math.floor(main.pos.X), y = main.pos and math.floor(main.pos.Y),
            senderX = sender.pos and math.floor(sender.pos.X), senderY = sender.pos and math.floor(sender.pos.Y),
            floatX = S.floatPos and math.floor(S.floatPos.X), floatY = S.floatPos and math.floor(S.floatPos.Y),
            statsX = S.statsPos and math.floor(S.statsPos.X), statsY = S.statsPos and math.floor(S.statsPos.Y),
        }
        if engine.autoMode and engine.manualBeforeAuto then
            value.manualBeforeAuto = {enabled = manual.enabled == true, guess = manual.guess == true,
                partsMode = manual.partsMode == true}
        end
        local raw = Files.encode(value)
        if raw and raw ~= S.lastSettings then
            if Files.write(Paths.settings, raw) then S.lastSettings = raw end
        end
    end
    if immediate then
        if S.persistJob then cancelJob(S.persistJob) end
        write()
    elseif not S.persistJob then
        S.persistJob = after(0.4, write)
    end
end

local function setPulse(active, color)
    UI.pulse.BackgroundColor3 = color
    if active == S.pulsing then return end
    S.pulsing = active
    if S.pulseTween then S.pulseTween:Cancel() S.pulseTween = nil end
    UI.pulse.Size = UDim2.fromOffset(8, 8)
    UI.pulse.BackgroundTransparency = 1
    if active then
        UI.pulse.BackgroundTransparency = 0.3
        S.pulseTween = Tween:Create(UI.pulse, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1),
            {Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1})
        S.pulseTween:Play()
    end
end

local function setSweep(active)
    if active == S.sweeping then return end
    S.sweeping = active
    if S.sweepTween then S.sweepTween:Cancel() S.sweepTween = nil end
    UI.fill.Position = UDim2.fromScale(0, 0)
    if active then
        UI.fill.Size = UDim2.fromScale(0.3, 1)
        S.sweepTween = Tween:Create(UI.fill, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            {Position = UDim2.fromScale(0.7, 0)})
        S.sweepTween:Play()
    else
        S.lastFraction = nil
    end
end

local refreshQueued = false
function Hub.refresh(force)
    if not S.alive then return end
    for _, update in ipairs(UI.updates) do update(force) end
    local e = engine
    local collected = #e.parts
    local target = e.partsMode and e.amount or 1
    local shown = math.min(collected, target)
    local statusText = sentence(e.status)
    if UI.status.Text ~= statusText then
        UI.status.Text = statusText
        UI.status.TextTransparency = 0.6
        animate(UI.status, {TextTransparency = 0}, 0.25)
    end
    UI.amount.Text = tostring(e.amount)
    animate(UI.amount, {TextTransparency = e.partsMode and 0 or 0.55}, 0.2)
    UI.count.Text = e.autoWaiting and "Armed" or (e.guess and (collected .. (collected == 1 and " part" or " parts"))
        or (e.partsMode and (shown .. " of " .. target) or (shown .. " of 1")))
    local previewText = collected > 0 and table.concat(e.parts, " + ")
        or (e.autoWaiting and "Waiting for Sammy" or "Waiting for parts")
    if UI.preview.Text ~= previewText or force then
        UI.preview.Text = previewText
        animate(UI.preview, {TextColor3 = collected > 0 and P.text or P.sub}, 0.2)
    end
    local active = e.enabled or e.autoMode
    local dotColor = e.pending and P.warn or (e.halted and P.bad) or (active and P.good) or P.off
    animate(UI.dot, {BackgroundColor3 = dotColor}, 0.25)
    setPulse(active and not e.halted, dotColor)
    setSweep(e.pending ~= nil and not e.halted)
    UI.fill.BackgroundColor3 = e.pending and P.warn or P.accent
    if not S.sweeping then
        local fraction = (e.guess or e.autoWaiting) and 0 or math.clamp(shown / target, 0, 1)
        if S.lastFraction ~= fraction or force then
            S.lastFraction = fraction
            animate(UI.fill, {Size = UDim2.fromScale(fraction, 1)}, 0.3)
        end
    end
    UI.gui:SetAttribute("status", e.status)
    UI.gui:SetAttribute("enabled", e.enabled)
    UI.gui:SetAttribute("auto_mode", e.autoMode)
    UI.gui:SetAttribute("submissions", e.submissions or 0)
    UI.gui:SetAttribute("last_submitted", e.lastSubmitted)
end

requestRefresh = function()
    if refreshQueued or not S.alive then return end
    refreshQueued = true
    defer(function()
        refreshQueued = false
        if S.alive then Hub.refresh() end
    end)
end

function Hub.helperChanged()
    if S.helperQueued or not S.alive then return end
    S.helperQueued = true
    defer(function()
        S.helperQueued = false
        local h = helperState
        local text = ""
        if h and h.alive then
            if h.autoBuy then text = sentence(h.buyerMessage) .. ", " .. (h.confirmed or 0) .. " bought"
            elseif h.lastError then text = sentence(h.lastError) end
        end
        UI.helperStatus.Text = text
        UI.helperStatus.Visible = text ~= ""
        for _, update in ipairs(UI.updates) do update() end
    end)
end

connect(UI.clear.Activated, function()
    S.ledger, S.retypeSafety = {}, false
    engine:clear(true)
end)
connect(UI.retype.Activated, function()
    Hub.ensureSetup()
    local ok, reason = S.retypeReplay:run()
    if not ok then engine.status = reason requestRefresh() end
end)
connect(UI.senderButton.Activated, function() Hub.openSender() end)
connect(UI.senderClose.Activated, function() sender:hide() end)
connect(UI.senderCollapse.Activated, function() sender:setCollapsed(not sender.collapsed) end)
connect(UI.collapseButton.Activated, function()
    Hub.setHidden(true)
    Hub.persist()
end)
do
    local sendNumber = 0
    local function senderMessage(text)
        UI.senderStatus.Text = text
        UI.senderStatus.TextTransparency = 1
        animate(UI.senderStatus, {TextTransparency = 0}, 0.25)
    end
    connect(UI.senderSend.Activated, function()
        local message = UI.senderBox.Text:match("^%s*(.-)%s*$")
        if message == "" then senderMessage("Type a message first") return end
        if not Code.remote or not Code.remote:IsDescendantOf(ReplicatedStorage) then
            senderMessage("Still connecting to the game") return
        end
        if type(firesignal) ~= "function" then senderMessage("Your executor needs firesignal") return end
        sendNumber += 1
        local id = "stormhub-local-test:" .. tostring(os.clock()) .. ":" .. sendNumber
        local ok = pcall(firesignal, Code.remote.OnClientEvent, message, 4, nil, "Top", Config.SammyUserId, id, false)
        senderMessage(ok and "Sent" or "Couldn't send it")
        if ok then UI.senderBox.Text = "" end
    end)
end

S.snapshot = function()
    local snapshot = engine:snapshot()
    snapshot.version = 3
    snapshot.submissionLedger = S.ledger
    snapshot.fpsBoost = S.fps.enabled
    snapshot.theme, snapshot.autoload, snapshot.binds, snapshot.tab = S.theme, S.autoload, S.binds, S.tab
    snapshot.winter, snapshot.themeRevision = S.winter, 4
    snapshot.avengers, snapshot.intro, snapshot.uiScale, snapshot.style = S.avengers, S.intro, S.uiScale, S.style
    snapshot.collapsed = main.collapsed
    snapshot.x, snapshot.y = main.pos and main.pos.X, main.pos and main.pos.Y
    snapshot.senderX, snapshot.senderY = sender.pos and sender.pos.X, sender.pos and sender.pos.Y
    snapshot.floatX, snapshot.floatY = S.floatPos and S.floatPos.X, S.floatPos and S.floatPos.Y
    snapshot.statsX, snapshot.statsY = S.statsPos and S.statsPos.X, S.statsPos and S.statsPos.Y
    return snapshot
end

S.stop = function()
    if not S.alive then return end
    S.stopping = true
    startup.closeCapture()
    pcall(Hub.persist, true)
    if S.historySaveJob then
        cancelJob(S.historySaveJob)
        S.historySaveJob = nil
        writeHistory()
    end
    pcall(S.retypeReplay.stop, S.retypeReplay)
    if rewardHighlighter then pcall(rewardHighlighter.stop, rewardHighlighter) end
    S.alive = false
    if helperState then pcall(helperState.stop) end
    pcall(engine.stop, engine)
    for _, connection in ipairs(S.connections) do pcall(connection.Disconnect, connection) end
    for _, undo in ipairs(S.restore) do pcall(undo) end
    for thread in pairs(S.jobs) do pcall(task.cancel, thread) end
    pcall(function() UI.gui:Destroy() end)
    if S.fps then
        -- Undoing the FPS boost touches every object in the map and takes a few seconds,
        -- so it runs in the background instead of holding up a newly executed copy.
        S.fpsRestoring = true
        task.spawn(function()
            elevate()
            pcall(S.fps.stop, S.fps)
            S.fpsRestoring = false
        end)
    end
    if env[KEY] == S then env[KEY] = nil end
    S.stopping = false
end

connect(UI.closeButton.Activated, function()
    if S.closing then return end
    pcall(Hub.persist, true)
    S.closing = true
    if sender.visible then sender:hide() end
    if UI.float.Visible then Hub.showLauncher(false) end
    main:hide(function() S.stop() end)
end)
connect(UI.gui.Destroying, function() if S.alive and not S.stopping then task.defer(S.stop) end end)
connect(UI.gui:GetPropertyChangedSignal("AbsoluteSize"), function() Hub.layout() Hub.refreshBinds() end)
connect(playerGui.DescendantAdded, function(child)
    if child.Name == "Codes" or child.Name == "TextBox" or child.Name == "Confirm" then
        if S.objectRefreshQueued then return end
        S.objectRefreshQueued = true
        defer(function()
            S.objectRefreshQueued = false
            refreshCodeObjects()
            engine:wake()
        end)
    end
end)

local function bindNotificationRemote()
    local notification = Code.notification
    if not notification or type(notification.Start) ~= "function" then return false end
    local ok, upvalues = pcall(debug.getupvalues, notification.Start)
    if not ok then return false end
    local found
    for _, value in pairs(upvalues) do
        if typeof(value) == "Instance" and value:IsA("RemoteEvent") and value:IsDescendantOf(ReplicatedStorage) then
            if found and found ~= value then Code.readyReason = "Announcement Event Is Ambiguous" return false end
            found = value
        end
    end
    if not found then return false end
    if Code.remote == found and Code.announceConnection and Code.announceConnection.Connected then return true end
    if Code.announceConnection then Code.announceConnection:Disconnect() end
    if Code.watchConnection then Code.watchConnection:Disconnect() Code.watchConnection = nil end
    Code.remote = found
    local function dispatch(message, duration, sound, location, sender, messageId, remove)
        local routed, routeError = pcall(S.route, false, message, duration, sound, location, sender, messageId, remove)
        if not routed then warn(Config.ProductName .. ": announcement route failed: " .. tostring(routeError)) end
        pcall(S.retypeReplay.capture, S.retypeReplay, message, duration, sound, location, sender, messageId, remove)
    end
    Code.announceConnection = connect(found.OnClientEvent, dispatch)
    startup.closeCapture()
    local buffered = startup.events
    startup.events = {}
    for _, args in ipairs(buffered) do
        local capturedAt = tonumber(args._stormhubCapturedAt)
        if not capturedAt or os.clock() - capturedAt <= Config.StartupEventTTL then
            dispatch(table.unpack(args, 1, args.n))
        end
    end
    Code.watchConnection = connect(found.AncestryChanged, function()
        if S.alive and not found:IsDescendantOf(ReplicatedStorage) and Code.remote == found then
            Code.announceConnection:Disconnect()
            Code.announceConnection, Code.watchConnection, Code.remote = nil, nil, nil
            Code.readyReason = "Announcement Event Changed, Reconnecting"
            defer(function() bindNotificationRemote() engine:wake() end)
        end
    end)
    return true
end

local function installResponses()
    if Code.responses then return end
    local function normalizeSource(value)
        return (tostring(value or ""):gsub("^[@=]", ""):gsub("^game%.", ""))
    end
    local expectedSource = normalizeSource(Code.script:GetFullName())
    local notification = Code.notification
    local canRelease = type(debug.getupvalues) == "function" and type(debug.setupvalue) == "function"
    local function releaseBox(box, submitFunction, thread)
        if not canRelease or type(submitFunction) ~= "function" or type(thread) ~= "thread" then return end
        task.defer(function()
            if not S.alive or box ~= Code.box or not box.Parent or box.Active or Code.flight then return end
            if coroutine.status(thread) ~= "suspended" then return end
            local ok, values = pcall(debug.getupvalues, submitFunction)
            if not ok or type(values) ~= "table" then return end
            local busyIndex, boxFound
            for index, value in pairs(values) do
                if value == true then
                    if busyIndex then return end
                    busyIndex = index
                elseif value == box then
                    boxFound = true
                end
            end
            if not busyIndex or not boxFound then return end
            if not pcall(task.cancel, thread) then return end
            pcall(debug.setupvalue, submitFunction, busyIndex, false)
            box.Text = ""
            box.PlaceholderText = "Code Here..."
            box.Selectable = true
            box.Active = true
        end)
    end
    local originals = {}
    for _, name in ipairs({"Success", "Error"}) do
        if type(notification[name]) ~= "function" then error("notification response methods changed") end
        originals[name] = notification[name]
    end
    for _, name in ipairs({"Success", "Error"}) do
        local original = originals[name]
        local wrapper
        wrapper = function(self, message, ...)
            local pending = Code.flight
            if S.alive and pending and not pending.box.Active and normalizeSource(debug.info(2, "s")) == expectedSource then
                Code.flight = nil
                local submitFunction = debug.info(2, "f")
                local thread = coroutine.running()
                local ok, err = pcall(pending.callback, name == "Success", tostring(message or ""))
                if not ok then warn(Config.ProductName .. ": " .. tostring(err)) end
                releaseBox(pending.box, submitFunction, thread)
            end
            return original(self, message, ...)
        end
        notification[name] = wrapper
        S.restore[#S.restore + 1] = function() if notification[name] == wrapper then notification[name] = original end end
    end
    Code.responses = true
end

local function setup()
    if not capable() then
        Code.readyReason = "Executor Missing Required Signal Or Debug Support"
        engine.status = Code.readyReason requestRefresh()
        return
    end
    local controllers = ReplicatedStorage:WaitForChild("Controllers", 15)
    local noticeScript = controllers and controllers:WaitForChild("NotificationController", 15)
    Code.script = controllers and controllers:WaitForChild("CodesController", 15)
    if not S.alive then return end
    if not noticeScript or not Code.script then engine.status = "Game Controllers Unavailable" requestRefresh() return end
    local ok, result = pcall(require, noticeScript)
    if not S.alive then return end
    if not ok or type(result) ~= "table" then engine.status = "Notification Controller Unavailable" requestRefresh() return end
    Code.notification = result
    local flagsScript = resolve(ReplicatedStorage, {"Shared", "Flags", "CodesFlags"})
    if flagsScript then pcall(function() Code.flags = require(flagsScript) end) end
    if Code.flags and Code.flags.Enabled and Code.flags.Enabled.Changed then
        local function updateCodesEnabled()
            local got, value = pcall(function() return Code.flags.Enabled:Get() end)
            Code.enabled = got and value == true
            engine:wake()
        end
        connect(Code.flags.Enabled.Changed, updateCodesEnabled)
        updateCodesEnabled()
    end
    local connected, err = pcall(installResponses)
    if not connected then
        engine.status = "Response Listener Unavailable"
        UI.gui:SetAttribute("error", tostring(err))
        requestRefresh()
        return
    end
    refreshCodeObjects()
    if not bindNotificationRemote() then
        engine.status = "Waiting For The Announcement Event"
        for retry = 1, 5 do
            after(retry * 2, function()
                if Code.remote and Code.announceConnection and Code.announceConnection.Connected then return end
                if bindNotificationRemote() then
                    engine.status = engine.enabled and "Waiting For Announcement..." or "Auto Redeem Off"
                    requestRefresh()
                    engine:wake()
                end
            end)
        end
    end
    local net = resolve(ReplicatedStorage, {"Packages", "Net"})
    if net then
        connect(net.ChildAdded, function(child)
            if child:IsA("RemoteEvent") and not (Code.remote and Code.announceConnection and Code.announceConnection.Connected) then
                defer(function()
                    if not (Code.remote and Code.announceConnection and Code.announceConnection.Connected) then
                        bindNotificationRemote()
                        engine:wake()
                    end
                end)
            end
        end)
    end
    if Code.remote then Code.readyReason = nil end
    if not engine.enabled and not engine.autoMode then engine.status = "Auto Redeem Off" end
    engine:wake()
    requestRefresh()
end

do
    local started = false
    function Hub.ensureSetup()
        if started or not S.alive then return end
        started = true
        defer(function()
            local ok, err = pcall(setup)
            if not ok then
                UI.gui:SetAttribute("error", tostring(err))
                engine.status = "Connection Setup Failed"
                requestRefresh()
            end
            if not Code.responses then started = false end
        end)
    end
end

-- Avengers Hub theme: loads the background picture and turns the theme on or off.
local Avengers = {image = nil, loading = false, fadeToken = 0}

function Avengers.download(url)
    if type(httpRequest) == "function" then
        local ok, response = pcall(httpRequest, {Url = url, Method = "GET"})
        if ok and type(response) == "table" and tonumber(response.StatusCode) == 200 and type(response.Body) == "string" then
            return response.Body
        end
    end
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and type(body) == "string" then return body end
    return nil
end

Avengers.pictureTypes = {".jpg", ".png", ".jpeg"}
Avengers.soundTypes = {".mp3", ".ogg", ".wav"}

-- The intro music, background picture and logo are built into this script (see the very bottom of the file).
-- On first run they're saved to the StormHub folder; your own files with the same names there take priority.
Avengers.embedded = {}

function Avengers.decode(data)
    data = data:gsub("[^%w%+/]", "")
    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local values = {}
    for i = 1, 64 do values[alphabet:byte(i)] = i - 1 end
    local length = #data
    local out = buffer.create(math.floor(length * 3 / 4))
    local o = 0
    for i = 1, length - 3, 4 do
        local a, b, c, d = string.byte(data, i, i + 3)
        local n = values[a] * 262144 + values[b] * 4096 + values[c] * 64 + values[d]
        buffer.writeu8(out, o, bit32.rshift(n, 16))
        buffer.writeu8(out, o + 1, bit32.band(bit32.rshift(n, 8), 255))
        buffer.writeu8(out, o + 2, bit32.band(n, 255))
        o += 3
    end
    local rest = length % 4
    if rest >= 2 then
        local a, b, c = string.byte(data, length - rest + 1, length)
        local n = values[a] * 262144 + values[b] * 4096 + (c and values[c] or 0) * 64
        buffer.writeu8(out, o, bit32.rshift(n, 16))
        o += 1
        if rest == 3 then
            buffer.writeu8(out, o, bit32.band(bit32.rshift(n, 8), 255))
            o += 1
        end
    end
    return buffer.readstring(out, 0, o)
end

function Avengers.ensureEmbedded()
    if Avengers.embeddedReady or #Avengers.embedded == 0 then return end
    Avengers.embeddedReady = true
    if not Files.available or not Avengers.customAsset() then return end
    for _, item in ipairs(Avengers.embedded) do
        local present = false
        for _, ext in ipairs(item.types) do
            if Files.exists(Config.Folder .. "/" .. item.name .. ext) then present = true break end
        end
        if not present then
            local ok, bytes = pcall(Avengers.decode, item.data)
            if ok and type(bytes) == "string" and #bytes == item.size then
                Files.write(Config.Folder .. "/" .. item.name .. item.ext, bytes)
            end
        end
    end
end

function Avengers.customAsset()
    return (type(getcustomasset) == "function" and getcustomasset)
        or (type(getsynasset) == "function" and getsynasset) or nil
end

-- Returns a content id for StormHub/<name> with the first matching extension, if the executor can load it.
function Avengers.localFile(name, extensions)
    local custom = Avengers.customAsset()
    if not custom then return nil end
    for _, ext in ipairs(extensions) do
        local path = Config.Folder .. "/" .. name .. ext
        if Files.exists(path) then
            local ok, id = pcall(custom, path)
            if ok and type(id) == "string" and id ~= "" then return id end
        end
    end
    return nil
end

function Avengers.assetId(value)
    if type(value) == "number" then value = tostring(value) end
    if type(value) ~= "string" or value == "" then return nil end
    return value:match("^%d+$") and ("rbxassetid://" .. value) or value
end

function Avengers.load()
    Avengers.ensureEmbedded()
    local id = Avengers.localFile("avengers-bg", Avengers.pictureTypes)
    if id then return id end
    local url = Config.AvengersThemeUrl
    if Avengers.customAsset() and type(url) == "string" and url ~= "" then
        local body = Avengers.download(url)
        local ext = type(body) == "string" and ((body:sub(1, 4) == "\137PNG" and ".png")
            or (body:sub(1, 3) == "\255\216\255" and ".jpg")) or nil
        if ext and Files.write(Config.Folder .. "/avengers-bg" .. ext, body) then
            id = Avengers.localFile("avengers-bg", {ext})
            if id then return id end
        end
    end
    id = Avengers.assetId(Config.AvengersThemeAssetId)
    if id then return id end
    if not Avengers.customAsset() then return nil, "Your executor can't load pictures" end
    return nil, "Add avengers-bg.jpg to StormHub"
end

function Hub.applyAvengers()
    local active = S.avengers == true and Avengers.image ~= nil
    Glass.active = active
    Glass.prune()
    for _, item in ipairs(Glass.items) do
        animate(item.object, {BackgroundTransparency = Glass.alpha(item.normal)}, 0.3)
    end
    local bg = UI.avengersBg
    Avengers.fadeToken += 1
    local token = Avengers.fadeToken
    if active then
        bg.Image = Avengers.image
        if not bg.Visible then bg.ImageTransparency, bg.Visible = 1, true end
        animate(bg, {ImageTransparency = math.clamp(tonumber(Config.AvengersThemeDim) or 0.5, 0, 0.95)}, 0.4)
    elseif bg.Visible then
        animate(bg, {ImageTransparency = 1}, 0.25)
        task.delay(0.26, function()
            if Avengers.fadeToken == token then bg.Visible = false end
        end)
    end
end

function Hub.setAvengersTheme(value)
    S.avengers = value == true
    if not S.avengers or Avengers.image then Hub.applyAvengers() return end
    if Avengers.loading then return end
    Avengers.loading = true
    task.spawn(function()
        elevate()
        local ok, image, reason = pcall(Avengers.load)
        Avengers.loading = false
        if not S.alive then return end
        if ok and image then
            Avengers.image = image
        elseif S.avengers then
            S.avengers = false
            Hub.toast(false, "Avengers theme", ok and reason or "Couldn't load the picture")
            Hub.persist()
        end
        Hub.applyAvengers()
        for _, update in ipairs(UI.updates) do update() end
    end)
end

-- Shows the color-following logo in the window header and on the launcher button.
-- Uses StormHub/avengers-logo.jpg (built in; replace that file to use your own picture).
function Hub.loadLogo()
    Avengers.ensureEmbedded()
    local id = Avengers.localFile("avengers-logo", Avengers.pictureTypes)
    if not id then return end
    local tint = P.accent:Lerp(Color3.new(1, 1, 1), 0.3)
    for _, pair in ipairs({{UI.logoImage, UI.logoLetter}, {UI.floatImage, UI.floatLetter}}) do
        pair[1].Image = id
        pair[1].ImageColor3 = tint
        pair[2].Visible = false
    end
end

-- Avengers Hub intro (Settings > Theme > Play intro on start): on a white screen a voice says "I am Thanos",
-- the words crumble to dust on a snap, then a big bang reveals the hub.
-- The voice is built in. To use your own clip instead, put it in the StormHub folder as intro-voice.mp3
-- (or .ogg), or set Config.IntroVoiceId. The snap and bang sounds are built in too.
local Intro = {
    voiceAt = 0.50, -- the voice line starts here (it's spoken slowly, about 2.9 seconds)
    words = {{"I", 0.53}, {"AM", 1.15}, {"THANOS", 1.88}}, -- each word appears with the built-in voice
    gather = 3.55, -- the words start to glow before the snap
    snap = 4.40,
    dust = 4.90, -- half a second after the snap, a big wave of dust blows across the screen
    bang = 5.50,
    length = 6.30, -- the hub opens here while the intro fades out
    font = "rbxasset://fonts/families/Oswald.json",
}

function Hub.playIntro(done)
    local RunService = game:GetService("RunService")
    local accent, white, black = P.accent, Color3.new(1, 1, 1), Color3.new(0, 0, 0)
    local gold, ink = Color3.fromRGB(214, 168, 70), Color3.fromRGB(22, 22, 26)
    local closing, finished, shake = false, false, 0
    local gui, sfx, voice, skipButton
    local connections = {}

    local function cleanup()
        closing, finished = true, true
        for _, connection in ipairs(connections) do pcall(connection.Disconnect, connection) end
        if gui then pcall(gui.Destroy, gui) end
        if sfx then pcall(sfx.Destroy, sfx) end
        if voice then pcall(voice.Destroy, voice) end
    end
    Intro.cleanup = cleanup
    S.restore[#S.restore + 1] = cleanup

    local function finish()
        if finished then return end
        finished = true
        if done then defer(done) end
    end

    local function close(fast)
        if closing then return end
        closing = true
        finish()
        if skipButton then skipButton.Visible = false end
        local fadeTime = fast and 0.3 or 0.6
        for _, sound in ipairs({sfx, voice}) do
            if sound then
                animate(sound, {Volume = 0}, fast and 0.35 or 1.4, Enum.EasingStyle.Quad)
                task.delay(fast and 0.4 or 1.5, function() pcall(sound.Destroy, sound) end)
            end
        end
        for _, object in ipairs(gui:GetDescendants()) do
            local goal
            if object:IsA("TextLabel") or object:IsA("TextButton") then
                goal = {TextTransparency = 1, BackgroundTransparency = 1}
            elseif object:IsA("ImageLabel") then
                goal = {ImageTransparency = 1, BackgroundTransparency = 1}
            elseif object:IsA("GuiObject") then
                goal = {BackgroundTransparency = 1}
            elseif object:IsA("UIStroke") then
                goal = {Transparency = 1}
            end
            if goal then pcall(animate, object, goal, fadeTime, Enum.EasingStyle.Quad) end
        end
        local fading = gui
        task.delay(fadeTime + 0.05, function()
            for _, connection in ipairs(connections) do pcall(connection.Disconnect, connection) end
            pcall(fading.Destroy, fading)
        end)
    end

    local function at(seconds, callback)
        task.delay(seconds, function()
            if not closing then pcall(callback) end
        end)
    end
    local function setFont(object)
        pcall(function() object.FontFace = Font.new(Intro.font, Enum.FontWeight.Bold) end)
    end
    local function round(object)
        make("UICorner", object, {CornerRadius = UDim.new(0.5, 0)})
    end

    Avengers.ensureEmbedded()
    local camera = workspace.CurrentCamera
    local view = camera and camera.ViewportSize or viewport()
    if view.X < 2 or view.Y < 2 then view = viewport() end
    local short = math.min(view.X, view.Y)
    gui = make("ScreenGui", nil, {Name = "AvengersIntro", IgnoreGuiInset = true, ResetOnSpawn = false,
        DisplayOrder = 1000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
    -- Cover the whole screen, including the strips phones keep clear for the camera, so nothing flickers at the edges.
    pcall(function() gui.ScreenInsets = Enum.ScreenInsets.None end)
    -- White backdrop with a faint grey edge; it turns dark at the bang behind the title.
    local backdrop = make("Frame", gui, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1.3, 1.3), BorderSizePixel = 0, BackgroundColor3 = white, BackgroundTransparency = 1, ZIndex = 1})
    local backdropColor = make("UIGradient", backdrop, {Rotation = 90, Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(226, 226, 230)), ColorSequenceKeypoint.new(0.5, white),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(226, 226, 230))})})
    local stage = make("Frame", gui, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2})

    -- Layer 3: faint dust drifting across the white.
    for _ = 1, 40 do
        local dot = math.random(1, 3)
        local x, y = math.random(), math.random()
        local mote = make("Frame", stage, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, y),
            Size = UDim2.fromOffset(dot, dot), BorderSizePixel = 0, ZIndex = 3, BackgroundTransparency = 1,
            BackgroundColor3 = math.random() < 0.3 and gold or Color3.fromRGB(150, 150, 158)})
        round(mote)
        animate(mote, {BackgroundTransparency = math.random(50, 85) / 100}, 0.8 + math.random())
        animate(mote, {Position = UDim2.fromScale(x - 0.04 - math.random() * 0.05, y - 0.03 - math.random() * 0.06)},
            Intro.snap + 1, Enum.EasingStyle.Linear)
    end

    -- Layer 5: the words "I AM THANOS", appearing with the voice.
    local wordSize = math.clamp(math.floor(view.Y * 0.13), 40, 130)
    local line = make("Frame", stage, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47),
        Size = UDim2.new(1, 0, 0, wordSize), BackgroundTransparency = 1, ZIndex = 5})
    make("UIListLayout", line, {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, math.floor(wordSize * 0.3)),
        SortOrder = Enum.SortOrder.LayoutOrder})
    local push = make("UIScale", line, {Scale = 1})
    local words = {}
    for index, entry in ipairs(Intro.words) do
        local word = make("TextLabel", line, {Text = entry[1], Size = UDim2.fromOffset(0, wordSize),
            AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Font = Enum.Font.GothamBlack,
            TextSize = wordSize, TextColor3 = white, TextTransparency = 1, LayoutOrder = index, ZIndex = 5})
        setFont(word)
        make("UIGradient", word, {Rotation = 90, Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(70, 62, 50)), ColorSequenceKeypoint.new(1, ink)})})
        local edge = make("UIStroke", word, {Color = gold, Thickness = math.max(1.5, wordSize * 0.02), Transparency = 1})
        words[index] = {label = word, edge = edge, at = entry[2]}
    end

    -- Layer 6-8: shockwaves, sparks, flash and the title for the bang.
    local flashFrame = make("Frame", stage, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1.3, 1.3), BorderSizePixel = 0, BackgroundColor3 = white, BackgroundTransparency = 1, ZIndex = 7})
    local titleSize = math.clamp(math.floor(view.Y * 0.14), 42, 140)
    local title = make("TextLabel", stage, {Text = "AVENGERS HUB", AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.47), Size = UDim2.new(1, 0, 0, titleSize), BackgroundTransparency = 1,
        Font = Enum.Font.GothamBlack, TextSize = titleSize, TextColor3 = white, TextTransparency = 1, ZIndex = 8})
    setFont(title)
    make("UIGradient", title, {Rotation = 90, Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(212, 216, 226)),
        ColorSequenceKeypoint.new(0.56, Color3.fromRGB(150, 156, 170)), ColorSequenceKeypoint.new(1, Color3.fromRGB(225, 228, 236))})})
    local titleEdge = make("UIStroke", title, {Color = accent, Thickness = math.max(2, titleSize * 0.03), Transparency = 1})
    local titleScale = make("UIScale", title, {Scale = 1.35})

    -- Above the stage: cinematic bars and the Skip intro button (top left, below Roblox's own buttons).
    for _, anchor in ipairs({0, 1}) do
        local edgeBar = make("Frame", gui, {AnchorPoint = Vector2.new(0.5, anchor), Position = UDim2.fromScale(0.5, anchor),
            Size = UDim2.fromScale(1.3, 0), BorderSizePixel = 0, BackgroundColor3 = black, ZIndex = 3})
        animate(edgeBar, {Size = UDim2.fromScale(1.3, 0.08)}, 0.8, Enum.EasingStyle.Quart)
    end
    skipButton = make("TextButton", gui, {Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(18, 72),
        Size = UDim2.fromOffset(136, 38), BackgroundColor3 = Color3.fromRGB(12, 12, 16), BackgroundTransparency = 1,
        BorderSizePixel = 0, ZIndex = 10})
    round(skipButton)
    local skipStroke = make("UIStroke", skipButton, {Color = white, Thickness = 1.2, Transparency = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
    local skipText = make("TextLabel", skipButton, {Text = "SKIP INTRO", Position = UDim2.fromOffset(18, 0),
        Size = UDim2.new(1, -46, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = white, TextTransparency = 1, ZIndex = 11})
    -- "\u{BB}" is the double arrow, written as a code so executors can't garble it into an extra "A".
    local skipArrow = make("TextLabel", skipButton, {Text = "\u{BB}", AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -16, 0.5, -1), Size = UDim2.fromOffset(18, 22), BackgroundTransparency = 1,
        Font = Enum.Font.GothamBlack, TextSize = 22, TextColor3 = accent, TextTransparency = 1, ZIndex = 11})
    pressable(skipButton)
    connections[#connections + 1] = skipButton.Activated:Connect(function() close(true) end)
    connections[#connections + 1] = skipButton.MouseEnter:Connect(function()
        if not closing then animate(skipStroke, {Color = accent, Transparency = 0}) end
    end)
    connections[#connections + 1] = skipButton.MouseLeave:Connect(function()
        if not closing then animate(skipStroke, {Color = white, Transparency = 0.55}) end
    end)

    -- Effects
    local function quake(amount) shake = math.max(shake, amount) end
    local function flash(color, strength, duration)
        if closing then return end
        flashFrame.BackgroundColor3 = color
        flashFrame.BackgroundTransparency = 1 - strength
        animate(flashFrame, {BackgroundTransparency = 1}, duration or 0.35, Enum.EasingStyle.Quad)
    end
    local function shockwave(color, diameter, thickness, duration)
        if closing then return end
        local wave = make("Frame", stage, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47),
            Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, ZIndex = 6})
        round(wave)
        local stroke = make("UIStroke", wave, {Color = color, Thickness = thickness or 8, Transparency = 0.05})
        animate(wave, {Size = UDim2.fromOffset(diameter, diameter)}, duration or 0.75, Enum.EasingStyle.Quart)
        animate(stroke, {Transparency = 1, Thickness = 1}, duration or 0.75, Enum.EasingStyle.Quad)
        task.delay((duration or 0.75) + 0.05, function() pcall(wave.Destroy, wave) end)
    end
    local function sparks(count, colors)
        if closing then return end
        local origin = UDim2.fromScale(0.5, 0.47)
        for _ = 1, count do
            local dot = math.random(3, 6)
            local piece = make("Frame", stage, {AnchorPoint = Vector2.new(0.5, 0.5), Position = origin,
                Size = UDim2.fromOffset(dot, dot), BorderSizePixel = 0, ZIndex = 6,
                BackgroundColor3 = colors[math.random(1, #colors)]})
            round(piece)
            local direction = math.random() * math.pi * 2
            local distance = short * (0.2 + math.random() * 0.4)
            local life = 0.5 + math.random() * 0.5
            animate(piece, {Position = origin + UDim2.fromOffset(math.cos(direction) * distance * 1.6, math.sin(direction) * distance),
                BackgroundTransparency = 1, Size = UDim2.fromOffset(1, 1)}, life, Enum.EasingStyle.Quad)
            task.delay(life, function() pcall(piece.Destroy, piece) end)
        end
    end
    -- The snap turns each word into dust that drifts away.
    local function crumble(word, delay)
        task.delay(delay, function()
            if closing then return end
            local origin = stage.AbsolutePosition
            local position, size = word.label.AbsolutePosition, word.label.AbsoluteSize
            for _ = 1, math.clamp(math.floor(size.X / 6), 18, 70) do
                local x = position.X - origin.X + math.random() * size.X
                local y = position.Y - origin.Y + size.Y * (0.15 + math.random() * 0.7)
                local dot = math.random(2, 4)
                local piece = make("Frame", stage, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y),
                    Size = UDim2.fromOffset(dot, dot), BorderSizePixel = 0, ZIndex = 5,
                    BackgroundColor3 = ({ink, Color3.fromRGB(95, 85, 72), gold})[math.random(1, 3)]})
                local life = 0.9 + math.random() * 0.8
                animate(piece, {Position = UDim2.fromOffset(x + short * (0.1 + math.random() * 0.35), y - short * (0.05 + math.random() * 0.25)),
                    BackgroundTransparency = 1}, life, Enum.EasingStyle.Sine)
                task.delay(life, function() pcall(piece.Destroy, piece) end)
            end
            animate(word.label, {TextTransparency = 1}, 0.35, Enum.EasingStyle.Quad)
            animate(word.edge, {Transparency = 1}, 0.35, Enum.EasingStyle.Quad)
        end)
    end
    -- Half a second after the snap: a big wave of dust grains and soft puffs blows across the screen.
    local dustColors = {ink, Color3.fromRGB(95, 85, 72), Color3.fromRGB(140, 128, 110), gold}
    local function dustGrain(puff)
        if closing then return end
        local x = -0.05 + math.random() * 0.6
        local y = 0.15 + math.random() * 0.75
        local size = puff and math.random(14, 34) or math.random(2, 5)
        local piece = make("Frame", stage, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, y),
            Size = UDim2.fromOffset(size, size), BorderSizePixel = 0, ZIndex = puff and 4 or 5,
            BackgroundColor3 = dustColors[math.random(1, #dustColors)],
            BackgroundTransparency = puff and 0.86 + math.random() * 0.08 or 0.1 + math.random() * 0.4})
        round(piece)
        local life = 1.0 + math.random() * 0.9
        animate(piece, {Position = UDim2.fromScale(x + 0.45 + math.random() * 0.45, y - 0.08 - math.random() * 0.25),
            BackgroundTransparency = 1, Size = UDim2.fromOffset(size * (puff and 2 or 0.6), size * (puff and 2 or 0.6))},
            life, Enum.EasingStyle.Sine)
        task.delay(life, function() pcall(piece.Destroy, piece) end)
    end
    local function dustStorm()
        local stopAt = os.clock() + 0.7
        task.spawn(function()
            while not closing and os.clock() < stopAt do
                for _ = 1, 6 do dustGrain(false) end
                if math.random() < 0.5 then dustGrain(true) end
                task.wait(0.02)
            end
        end)
        quake(3)
    end

    connections[#connections + 1] = RunService.RenderStepped:Connect(function(dt)
        shake *= math.exp(-dt * 9)
        if shake < 0.3 then shake = 0 end
        stage.Position = UDim2.new(0.5, (math.random() - 0.5) * 2 * shake, 0.5, (math.random() - 0.5) * 2 * shake)
    end)

    gui.Parent = guiParent
    animate(backdrop, {BackgroundTransparency = 0}, 0.25, Enum.EasingStyle.Quad)
    animate(skipButton, {BackgroundTransparency = 0.3}, 0.3)
    animate(skipStroke, {Transparency = 0.55}, 0.3)
    animate(skipText, {TextTransparency = 0}, 0.3)
    animate(skipArrow, {TextTransparency = 0}, 0.3)

    -- Sounds: the built-in snap-and-bang track, plus the voice (your own intro-voice file if you added one).
    local volume = math.clamp(tonumber(Config.IntroVolume) or 0.8, 0, 3)
    local soundService = game:GetService("SoundService")
    local sfxId = Avengers.localFile("avengers-sfx-long", Avengers.soundTypes)
    local ownVoice = Avengers.localFile("intro-voice", Avengers.soundTypes) or Avengers.assetId(Config.IntroVoiceId)
    local voiceId = ownVoice or Avengers.localFile("avengers-voice-slow", Avengers.soundTypes)
    if sfxId then
        sfx = make("Sound", nil, {Name = "AvengersIntroSfx", SoundId = sfxId, Volume = volume})
        sfx.Parent = soundService
    end
    if voiceId then
        voice = make("Sound", nil, {Name = "AvengersIntroVoice", SoundId = voiceId, Volume = volume})
        voice.Parent = soundService
    end
    local deadline = os.clock() + (ownVoice and 2 or 0.8)
    while not closing and os.clock() < deadline
        and ((sfx and not sfx.IsLoaded) or (voice and not voice.IsLoaded)) do
        task.wait()
    end
    if closing then return end
    if sfx then sfx:Play() end
    at(Intro.voiceAt, function() if voice then voice:Play() end end)

    -- 0.0: slow push toward the words.
    animate(push, {Scale = 1.06}, Intro.snap, Enum.EasingStyle.Linear)

    -- 0.5-3.4: "I AM THANOS", spoken slowly.
    for _, word in ipairs(words) do
        at(word.at, function()
            word.edge.Thickness = math.max(4, wordSize * 0.06)
            animate(word.label, {TextTransparency = 0}, 0.3, Enum.EasingStyle.Quad)
            animate(word.edge, {Transparency = 0.3, Thickness = math.max(1.5, wordSize * 0.02)}, 0.5, Enum.EasingStyle.Quad)
            quake(word.label.Text == "THANOS" and 4 or 2)
        end)
    end

    -- 3.55: the words start to glow gold right before the snap.
    at(Intro.gather, function()
        for _, word in ipairs(words) do
            animate(word.edge, {Transparency = 0, Thickness = math.max(2.5, wordSize * 0.04)}, Intro.snap - Intro.gather)
        end
    end)
    at(Intro.gather + 0.4, function() quake(2) end)
    at(Intro.snap - 0.25, function() quake(3) end)

    -- 4.4: the snap. The words turn to dust, and half a second later a wave of dust blows across.
    at(Intro.snap, function()
        flash(gold, 0.35, 0.3)
        shockwave(gold, short * 0.9, 4, 0.5)
        quake(6)
        for index, word in ipairs(words) do crumble(word, 0.05 + (index - 1) * 0.08) end
    end)
    at(Intro.dust, dustStorm)

    -- The big bang: the screen turns dark, AVENGERS HUB slams in, then the hub loads.
    at(Intro.bang, function()
        flash(white, 1, 0.9)
        backdropColor.Color = ColorSequence.new(Color3.fromRGB(6, 6, 9))
        shockwave(accent, math.max(view.X, view.Y) * 1.3, 12, 0.8)
        task.delay(0.08, function() shockwave(white, math.max(view.X, view.Y) * 1.1, 8, 0.85) end)
        sparks(46, {white, accent, gold})
        quake(22)
        animate(title, {TextTransparency = 0}, 0.15)
        animate(titleEdge, {Transparency = 0.1}, 0.15)
        animate(titleScale, {Scale = 1}, 0.45, Enum.EasingStyle.Back)
    end)
    task.delay(Intro.length, function() close(false) end)
end

S.restoring = true
S.historyView = serverReady and "everyone" or "mine"
UI.viewSwitch.Visible = serverReady
UI.historyCount.Visible = not serverReady
UI.historyClear.Visible = S.historyView == "mine"
UI.viewPill.Position = S.historyView == "everyone" and UDim2.fromOffset(3, 3) or UDim2.new(0.5, 0, 0, 3)
themeHooks[#themeHooks + 1] = function()
    for key, option in pairs(UI.viewButtons) do option.TextColor3 = key == S.historyView and P.text or P.sub end
end
function Hub.syncPresence()
    if not serverReady or S.presenceBusy then return end
    local jobId = tostring(game.JobId or "")
    if jobId == "" then return end
    S.presenceBusy = true
    task.spawn(function()
        local status, data = serverCall("POST", "/presence", {userId = player.UserId, jobId = jobId, player = player.Name})
        defer(function()
            S.presenceBusy = false
            if status ~= 200 or type(data) ~= "table" or type(data.users) ~= "table" then return end
            local active = {}
            for _, id in ipairs(data.users) do
                local target = Players:GetPlayerByUserId(tonumber(id) or 0)
                if target and target ~= player then active[target] = true end
            end
            for target in pairs(active) do Tags.attach(target) end
            for target in pairs(Tags.byPlayer) do
                if target ~= player and not active[target] then Tags.detach(target) end
            end
        end)
    end)
end

if serverReady then
    local function poll()
        if S.tab == "redeemed" and S.historyView == "everyone" and not S.hidden then Hub.fetchShared(true) end
        after(15, poll)
    end
    after(15, poll)
    local function presenceLoop()
        Hub.syncPresence()
        after(30, presenceLoop)
    end
    after(2, presenceLoop)
end
Hub.layout()
Hub.refreshBinds()
Hub.applyTheme(S.theme)
Hub.selectTab(S.tab, true)
S.ready = true
defer(function() pcall(Hub.loadLogo) end)
if S.intro then
    -- The hub is already built behind the intro and pops in as the intro fades out.
    defer(function()
        local function showHub()
            if S.alive and not S.closing and not S.hidden and not main.visible then Hub.setHidden(false) end
        end
        local ok, err = pcall(Hub.playIntro, showHub)
        if not ok then
            warn(Config.ProductName .. ": intro failed: " .. tostring(err))
            if Intro.cleanup then pcall(Intro.cleanup) end
            showHub()
        end
    end)
else
    Hub.setHidden(false)
end
Hub.refresh(true)
S.restoring = false
Hub.ensureSetup()
if saved.fpsBoost == true then
    defer(function()
        S.waitPreviousFPS()
        if not S.alive then return end
        S.fps:setEnabled(true)
        requestRefresh()
    end)
end
if S.avengers then defer(function() Hub.setAvengersTheme(true) end) end
if S.autoload and not previousSnapshot then
    defer(function()
        local data = Files.decode(Files.read(configPath(S.autoload)))
        if data then
            UI.configName.Text = S.autoload
            applyConfig(data)
        end
    end)
end

-- ================================================================================================
-- Built-in media for the Avengers intro and theme (base64). Saved to the StormHub folder on first run.
-- Nothing to edit below this line.
-- ================================================================================================
-- background picture
Avengers.embedded[#Avengers.embedded + 1] = {name = "avengers-bg", ext = ".jpg", types = Avengers.pictureTypes, size = 133741, data = [[
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
JJGD3r1erMxyuV6vVgH/2Q==]]}
-- logo: the "A" from the Avengers picture, in grayscale so it can take any color
Avengers.embedded[#Avengers.embedded + 1] = {name = "avengers-logo", ext = ".jpg", types = Avengers.pictureTypes, size = 5337, data = [[
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
GWSUnqcaC2POP//Z]]}
-- built-in voice line "I am Thanos" (synthesized, original)
Avengers.embedded[#Avengers.embedded + 1] = {name = "avengers-voice-slow", ext = ".mp3", types = Avengers.soundTypes, size = 52036, data = [[
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
/SuHpgwFB+SA+idiszBVc1I60XYmmZwulV+UtP/7cmTjAAI+PU3p5hNCN2HabTDJIYkUfzXnsGqJFRCmNPYM4dv1JinmDNMWaaac
dUyVu5Iep3jFK2zf/aIEp0CvjkdiYUBCQzolEiotNp7XPqlZnCIHoudlavNT/WhS1wsxeIFt9NNytKaFf4q+8e1Wv9En11aXArAC
nQlmapHweTKTzcW8uKoY6pVwwMHJ4INJVVmgSZWdSEpnrNKtmCjXmbjQUHzJiWlWkSBlJ5t1fG0ErMQZSh35JaK8cxdpNqSqFWbP
zZJssNShJNlOPQCQQ+P0hCAmyqOVAgnpsXnKqEKJmDqvDk51V2Uj323QCDP0TZzEA1O6LMUfrvX952y9jdO7/5X1zQWMdjD7J8o7
ZQQRHskdfUlGViRIpLDCn6zOainXtdZS9jtOGzrRg0MTiVARLyiQolqG//twZOeAAlo9zGmDFHBDw2mNMSNUR8SFLaewZUD7kCZ0
wYoJFEJ02NiC1emuuomTeFJYikVLJqAkCrgAAjJFKYhAQbQjS0j82aFRkR3tvbmVjbf0EDKMTUEsWKJ6EuQSVl/oL0nR7o31Xet/
WMvv2gAAhIUP1kSJpUKhLPQMOmZbl+hv6l/y/zfb0N7SyluYCMJnypYFSx6oGi3/iWWK9HkiP8jU8NSIAAHMgkBuBhURqq04BJOJ
b0nd7lcSjTqwVDUsPcNOyp1IiPHmoyPnf/57s/1u+6tyKnNKkfEoDUgz5s0acBiSj0E8qaZ43Kmiyyrhrkaa5mXIJGZGRpr3JIiK
AyzD4uNzfuVJxooDLMPQWjRpxR8blTRZcXmzUnHFhkyEhdnFQJCo0XQNuaQrVdXV1aSU4av/5f/7cmTsAQKbNsYp40tSRgY5HDBm
XkekuxinhGzA4A6jpJCNYZLDI1ls/n2wyNWslQyNWtl9lBAwcssoIGDCORk1kqGTKGBg4JFCwuysVFiX/xRv8UbLCwqxYqKCR8Wq
TEFNRTMuMTAwqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq
qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq
qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq//twRO+I
gb0oQ8kmETA2AMiaCCYCCRTurEME1ME0G5cEkI4IqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqpM
QU1FMy4xMDCqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq
qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq
qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq
qqqqqqqqqv/7cmR0j/AAAGkAAAAIAAANIAAAAQAAAaQAAAAgAAA0gAAABKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq
qqqqqqqqqqqqqqqqTEFNRTMuMTAwqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq
qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq
qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq
qqqqqqqqqqqqqqqqqqqqqqqqqqqq//twZHUP8AAAaQAAAAgAAA0gAAABAAABpAAAACAAADSAAAAEqqqqqqqqqqqqqqqqqqqqqqqq
qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqkxBTUUzLjEwMKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq
qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq
qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq
qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqv/7cGR1D/AAAGkAAAAIAAANIAAAAQAAAaQAAAAgAAA0gAAABKqqqqqq
qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqTEFNRTMuMTAwqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq
qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq
qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq
qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqr/+3JkdI/wAABpAAAACAAADSAAAAEAAAGkAAAA
IAAANIAAAASqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq
qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq
qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq
qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqg==]]}
-- built-in snap and big bang sounds (original)
Avengers.embedded[#Avengers.embedded + 1] = {name = "avengers-sfx-long", ext = ".mp3", types = Avengers.soundTypes, size = 91533, data = [[
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
rMaPIQU0//tyRN8AAeMeR4MMGOA+wfotPMNlyPCLGQwwZ0kWECNlpgyp4oKDSCI4CuLLCp3WRDTF6CJ3LFdDFPka3bfS3bGPKku2
7ozrvXgu7+NyxVVMQU1FMy4xMDBVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV
VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV
VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV
VVVVVVVVVVVVVVVVVVVVVVVVVVX/+3BE4gjBthfEEwkQYDdiiJJkwygGGBb67BjCQOmFHwmQjKBVVVVVVVVVVVVVVVVVVVVVVVVV
VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV
VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV
VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV
VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV]]}
