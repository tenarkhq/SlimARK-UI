-- Shared test helpers for the tests in tests/claude. Plain Lua 5.1, no WoW client:
-- the real addon files are loaded into a stand-in WoW environment with fake frames and
-- fake API functions whose answers each test sets. Run every test from the repository root:
--   lua5.1 tests/claude/<name>.lua      (luajit works as well)
local H = {}
local realPrint = print
local luaXpcall = xpcall

H.root = 'SlimARK-UI/'
H.now = 1000
H.combat = false
H.frames = {}
H.timers = {}
H.prints = {}

local failures, passes = 0, 0

function H.check(cond, message)
	if cond then
		passes = passes + 1
		realPrint('ok    ' .. message)
	else
		failures = failures + 1
		realPrint('FAIL  ' .. message)
	end
end

function H.equal(actual, expected, message)
	H.check(actual == expected, message .. ' (expected ' .. tostring(expected) .. ', got ' .. tostring(actual) .. ')')
end

function H.done()
	realPrint(('%d passed, %d failed'):format(passes, failures))
	os.exit(failures == 0 and 0 or 1)
end

------------------------------------------------------------------------
-- Fake frames. Only the widget methods listed here exist; a method the code calls that is
-- missing here fails loudly, so the list grows with the code under test. Fields that are not
-- set stay nil, as on a real frame.
------------------------------------------------------------------------
local Fake = {}
local methods = {}
Fake.__index = function(self, key) return methods[key] end

local function new(kind, name, parent)
	local f = setmetatable({ _kind = kind or 'Frame', _name = name, _parent = parent, _shown = true,
		_alpha = 1, _attributes = {}, _events = {}, _scripts = {}, _hooks = {}, _calls = {} }, Fake)
	table.insert(H.frames, f)
	if name then _G[name] = f end
	return f
end
H.NewFrame = new

local function record(self, name, ...)
	local list = self._calls[name] or {}
	self._calls[name] = list
	table.insert(list, { ... })
end

-- Methods that only record that they were called.
for _, name in ipairs({
	'SetPoint', 'ClearAllPoints', 'SetAllPoints', 'SetSize', 'SetWidth', 'SetHeight', 'SetScale',
	'SetFrameLevel', 'SetFrameStrata', 'SetColorTexture', 'SetTexture', 'SetTexCoord', 'SetVertexColor',
	'SetGradient', 'SetStatusBarTexture', 'SetStatusBarColor', 'SetMinMaxValues', 'SetValue',
	'SetReverseFill', 'SetHorizTile', 'SetVertTile', 'SetFont', 'SetShadowOffset', 'SetShadowColor',
	'SetJustifyH', 'SetJustifyV', 'SetWordWrap', 'SetTextColor', 'RegisterForClicks', 'RegisterForDrag',
	'EnableMouse', 'EnableMouseWheel', 'SetMovable', 'SetClampedToScreen', 'Tag', 'AddGroup', 'AddSlot',
	'SetHideCountdownNumbers', 'SetDrawEdge', 'SetSwipeColor', 'SetAtlas', 'SetDesaturated',
	'SetAlphaFromBoolean', 'SetVertexColorFromBoolean', 'SetTimerDuration', 'SetMaskTexture',
	'SetFormattedText', 'SetFrameLevel', 'SetToplevel', 'SetParent', 'StartMoving', 'StopMovingOrSizing',
	'SetEnabled', 'Enable', 'Disable', 'SetChecked', 'SetDamageAbsorbClampMode', 'Play', 'Stop',
	'SetLooping', 'SetFromAlpha', 'SetToAlpha', 'SetDuration', 'SetNormalFontObject', 'SetMaxLines',
	'SetNonSpaceWrap', 'SetObeyStepOnDrag', 'SetCooldown', 'Clear', 'SetCooldownFromDurationObject',
}) do
	methods[name] = function(self, ...) record(self, name, ...) end
end

function methods:GetName() return self._name end
function methods:GetParent() return self._parent end
function methods:GetObjectType() return self._kind end
function methods:IsObjectType(kind) return self._kind == kind end
function methods:GetFrameLevel() return 1 end
function methods:GetWidth() return 100 end
function methods:GetHeight() return 20 end
function methods:GetScale() return 1 end
function methods:GetEffectiveScale() return 1 end
function methods:GetLeft() return 0 end
function methods:GetRight() return 100 end
function methods:GetTop() return 100 end
function methods:GetBottom() return 0 end
function methods:GetUnboundedStringWidth() return 50 end
function methods:GetStringHeight() return 14 end
function methods:IsMouseOver() return false end
function methods:IsProtected() return false end
function methods:IsForbidden() return false end

function methods:Show() self._shown = true end
function methods:Hide() self._shown = false end
function methods:SetShown(shown) self._shown = shown and true or false end
function methods:IsShown() return self._shown end
function methods:IsVisible() return self._shown end
function methods:SetAlpha(a) self._alpha = a end
function methods:GetAlpha() return self._alpha end

function methods:SetID(id) self._id = id end
function methods:GetID() return self._id end
function methods:GetPoint() return nil end
function methods:SetText(text) self._text = text end
function methods:GetText() return self._text end
function methods:SetAttribute(key, value) self._attributes[key] = value end
function methods:GetAttribute(key) return self._attributes[key] end
function methods:SetRolesets(value) record(self, 'SetRolesets', value) self._roleset = value end

function methods:SetScript(name, fn) self._scripts[name] = fn end
function methods:GetScript(name) return self._scripts[name] end
function methods:HookScript(name, fn)
	local old = self._scripts[name]
	self._scripts[name] = function(...)
		if old then old(...) end
		return fn(...)
	end
end
function methods:RegisterEvent(event) self._events[event] = true end
function methods:RegisterUnitEvent(event, ...) self._events[event] = { ... } end
function methods:UnregisterEvent(event) self._events[event] = nil end
function methods:UnregisterAllEvents() record(self, 'UnregisterAllEvents') self._events = {} end
function methods:IsEventRegistered(event) return self._events[event] ~= nil end

function methods:CreateTexture() return new('Texture', nil, self) end
function methods:CreateFontString() return new('FontString', nil, self) end
function methods:CreateAnimationGroup() return new('AnimationGroup', nil, self) end
function methods:CreateAnimation() return new('Animation', nil, self) end
function methods:CreateAuras() return new('Frame', nil, self) end
function methods:GetStatusBarTexture()
	self._barTexture = self._barTexture or new('Texture', nil, self)
	return self._barTexture
end
function methods:GetFontString()
	self._fontString = self._fontString or new('FontString', nil, self)
	return self._fontString
end
function methods:GetNormalTexture() return nil end
function methods:GetHighlightTexture() return nil end

function H.calls(frame, name) return frame._calls[name] or {} end
function H.lastCall(frame, name)
	local list = frame._calls[name]
	return list and list[#list]
end

------------------------------------------------------------------------
-- Events: every fake frame with an OnEvent script and that event registered gets it.
------------------------------------------------------------------------
function H.fire(event, ...)
	for _, f in ipairs(H.frames) do
		local script = f._scripts.OnEvent
		if script and f._events[event] then script(f, event, ...) end
	end
end

-- Runs the C_Timer callbacks that are due, in order.
function H.runTimers(seconds)
	H.now = H.now + (seconds or 0)
	local due = {}
	for i = #H.timers, 1, -1 do
		local t = H.timers[i]
		if t.at <= H.now then
			table.insert(due, 1, t)
			table.remove(H.timers, i)
		end
	end
	for _, t in ipairs(due) do t.fn() end
end

------------------------------------------------------------------------
-- The stand-in WoW environment.
------------------------------------------------------------------------
local function autoEnum()
	local count = 0
	return setmetatable({}, { __index = function(t, k)
		local sub = setmetatable({}, { __index = function(s, name)
			count = count + 1
			rawset(s, name, count)
			return count
		end })
		rawset(t, k, sub)
		return sub
	end })
end

function H.setup()
	H.frames, H.timers, H.prints = {}, {}, {}
	H.now, H.combat, H.secret = 1000, false, nil
	-- Every environment starts from fresh SavedVariables: nothing learned in one test leaks into the next.
	_G.SlimARKDB, _G.SlimARKCharDB = nil, nil
	_G.UIParent = new('Frame', 'UIParent')
	_G.CreateFrame = function(kind, name, parent) return new(kind, name, parent) end
	_G.GetPhysicalScreenSize = function() return 2560, 1600 end
	_G.InCombatLockdown = function() return H.combat end
	_G.GetTime = function() return H.now end
	_G.issecretvalue = function(v) return H.secret ~= nil and H.secret[v] == true end
	_G.Enum = autoEnum()
	_G.CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end
	_G.CreateUnitHealPredictionCalculator = function() return new('Calculator') end
	_G.C_AddOns = { GetAddOnMetadata = function() return '2.1.0' end, IsAddOnLoaded = function() return false end }
	_G.C_Timer = {
		After = function(delay, fn) table.insert(H.timers, { at = H.now + delay, fn = fn }) end,
		NewTicker = function(delay, fn)
			local ticker = { Cancel = function(self) self.cancelled = true end }
			return ticker
		end,
	}
	_G.SlashCmdList = {}
	_G.strtrim = function(s) return (s:gsub('^%s+', ''):gsub('%s+$', '')) end
	_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
	_G.tinsert = table.insert
	_G.print = function(...)
		local parts = {}
		for i = 1, select('#', ...) do parts[i] = tostring((select(i, ...))) end
		table.insert(H.prints, table.concat(parts, ' '))
	end
	_G.hooksecurefunc = function(target, name, fn)
		if type(target) == 'string' then
			target, name, fn = _G, target, name
		end
		local old = target[name]
		target[name] = function(...)
			local results = { old(...) }
			fn(...)
			return unpack(results)
		end
	end
	_G.geterrorhandler = function() return function(err) table.insert(H.prints, 'ERROR ' .. tostring(err)) end end
	-- WoW's xpcall hands extra arguments to the function (Lua 5.1's does not).
	_G.xpcall = function(fn, handler, ...)
		local n, args = select('#', ...), { ... }
		return luaXpcall(function() return fn(unpack(args, 1, n)) end, handler)
	end
	H.ns = {}
	return H.ns
end

-- Loads an addon file the way the client does: with the addon name and the shared table.
function H.load(file)
	local chunk, err = loadfile(H.root .. file)
	if not chunk then error(err) end
	chunk('SlimARK-UI', H.ns)
end

H.print = realPrint

return H
