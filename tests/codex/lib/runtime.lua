-- Shared client boundary for the runtime regression tests. Production modules stay real.
local H = dofile('tests/claude/lib/helpers.lua')

function H.boot(flavor)
	local ns = H.setup()
	C_AddOns.GetAddOnMetadata = function(_, field)
		if field == 'X-SlimARK-Flavor' then return flavor or 'retail' end
		return '2.1.1'
	end
	H.tickers = {}
	C_Timer.NewTicker = function(interval, fn)
		local ticker = { interval = interval, fn = fn }
		function ticker:Cancel() self.cancelled = true end
		H.tickers[#H.tickers + 1] = ticker
		return ticker
	end
	H.load('Config.lua')
	H.load('Core.lua')
	H.fire('ADDON_LOADED', 'SlimARK-UI')
	return ns
end

function H.noErrors()
	for _, line in ipairs(H.prints) do
		assert(not line:find('ERROR ', 1, true), line)
	end
end

return H
