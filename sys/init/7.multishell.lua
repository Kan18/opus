local Blit     = require('opus.ui.blit')
local Config   = require('opus.config')
local Util     = require('opus.util')

local colors     = _G.colors
local fs         = _G.fs
local kernel     = _G.kernel
local keys       = _G.keys
local os         = _G.os
local printError = _G.printError
local shell      = _ENV.shell
local window     = _G.window

local parentTerm = _G.device.terminal
local w,h = parentTerm.getSize()
local overviewId
local tabsDirty = false
local closeInd = Util.getVersion() >= 1.76 and '\215' or '*'
local multishell = { }

shell.setEnv('multishell', multishell)

kernel.window.reposition(1, 2, w, h - 1)

local config = {
	standard = {
		textColor  = colors.lightGray,
		tabBarTextColor = colors.lightGray,
		focusTextColor = colors.white,
		backgroundColor = colors.gray,
		tabBarBackgroundColor = colors.gray,
		focusBackgroundColor = colors.gray,
		errorColor = colors.black,
	},
	color = {
		textColor  = colors.lightGray,
		tabBarTextColor = colors.lightGray,
		focusTextColor = colors.white,
		backgroundColor = colors.gray,
		tabBarBackgroundColor = colors.gray,
		focusBackgroundColor = colors.gray,
		errorColor = colors.red,
	},
}
Config.load('multishell', config)

local _colors = parentTerm.isColor() and config.color or config.standard
local palette = parentTerm.isColor() and Blit.colorPalette or Blit.grayscalePalette

local function redrawMenu()
	if not tabsDirty then
		os.queueEvent('multishell_redraw')
		tabsDirty = true
	end
end

function multishell.getFocus()
	local currentTab = kernel.getFocused()
	return currentTab.uid
end

function multishell.setFocus(tabId)
	return kernel.raise(tabId)
end

function multishell.getTitle(tabId)
	local tab = kernel.find(tabId)
	return tab and tab.title
end

function multishell.setTitle(tabId, title)
	local tab = kernel.find(tabId)
	if tab then
		tab.title = title
		redrawMenu()
	end
end

function multishell.getCurrent()
	local runningTab = kernel.getCurrent()
	return runningTab and runningTab.uid
end

function multishell.getTab(tabId)
	return kernel.find(tabId)
end

function multishell.terminate(tabId)
	os.queueEvent('multishell_terminate', tabId)
end

function multishell.getTabs()
	return kernel.routines
end

function multishell.launch( tProgramEnv, sProgramPath, ... )
	-- backwards compatibility
	return multishell.openTab({
		env = tProgramEnv,
		path = sProgramPath,
		args = { ... },
	})
end

function multishell.openTab(tab)
	if not tab.title and tab.path then
		tab.title = fs.getName(tab.path):match('([^%.]+)')
	end
	tab.title = tab.title or 'untitled'
	tab.window = tab.window or window.create(parentTerm, 1, 2, w, h - 1, false)
	tab.onExit = function(self, result, err)
		if not result and err and err ~= 'Terminated' or (err and err ~= 0) then
			self.terminal.setBackgroundColor(colors.black)
			if tonumber(err) then
				self.terminal.setTextColor(colors.orange)
				print('Process exited with error code: ' .. err)
			elseif err then
				printError(tostring(err))
			end
			self.terminal.setTextColor(colors.white)
			print('\nPress enter to close')
			self.isDead = true
			self.hidden = false
			redrawMenu()
			while true do
				local e, code = os.pullEventRaw('key')
				if e == 'terminate' or e == 'key' and code == keys.enter then
					break
				end
			end
		end
	end

	local routine = kernel.run(tab)

	if tab.focused then
		multishell.setFocus(routine.uid)
	else
		redrawMenu()
	end
	return routine.uid
end

function multishell.hideTab(tabId)
	local tab = kernel.find(tabId)
	if tab then
		tab.hidden = true
		kernel.lower(tab.uid)
		redrawMenu()
	end
end

function multishell.unhideTab(tabId)
	local tab = kernel.find(tabId)
	if tab then
		tab.hidden = false
		redrawMenu()
	end
end

function multishell.getCount()
	return #kernel.routines
end

kernel.hook('kernel_focus', function()
	redrawMenu()
end)

kernel.hook('multishell_terminate', function(_, eventData)
	local tab = kernel.find(eventData[1])
	if tab and not tab.isOverview then
		if coroutine.status(tab.co) ~= 'dead' then
			tab:resume("terminate")
		end
	end
	return true
end)

kernel.hook('terminate', function()
	return kernel.getFocused().isOverview
end)

kernel.hook('multishell_redraw', function()
	tabsDirty = false

	local blit = Blit(w, {
		bg = _colors.tabBarBackgroundColor,
		fg = _colors.textColor,
		palette = palette,
	})

	local currentTab = kernel.getFocused()

	for _,tab in pairs(kernel.routines) do
		if tab.hidden and tab ~= currentTab then
			tab.width = 0
		else
			tab.width = #tab.title + 1
		end
	end

	local function width()
		local tw = 0
		Util.each(kernel.routines, function(t) tw = tw + t.width end)
		return tw
	end

	while width() > w - 3 do
		local tab = select(2,
			Util.spairs(kernel.routines, function(a, b) return a.width > b.width end)())
		tab.width = tab.width - 1
	end

	local function compareTab(a, b)
		if a.hidden then return false end
		return b.hidden or a.uid < b.uid
	end

	local tabX = 0
	for _,tab in Util.spairs(kernel.routines, compareTab) do
		if tab.width > 0 then
			tab.sx = tabX + 1
			tab.ex = tabX + tab.width
			tabX = tabX + tab.width
			if tab ~= currentTab then
				local textColor = tab.isDead and _colors.errorColor or _colors.textColor
				blit:write(tab.sx, tab.title:sub(1, tab.width - 1),
					_colors.backgroundColor, textColor)
			end
		end
	end

	if currentTab then
		if currentTab.sx then
			local textColor = currentTab.isDead and _colors.errorColor or _colors.focusTextColor
			blit:write(currentTab.sx - 1,
				' ' .. currentTab.title:sub(1, currentTab.width - 1) .. ' ',
				_colors.focusBackgroundColor, textColor)
		end
		if not currentTab.noTerminate then
			blit:write(w, closeInd, nil, _colors.focusTextColor)
		end
	end

	parentTerm.setCursorPos(1, 1)
	parentTerm.blit(blit.text, blit.fg, blit.bg)

	if currentTab and currentTab.window then
		currentTab.window.restoreCursor()
	end

	return true
end)

kernel.hook('term_resize', function(_, eventData)
	if not eventData[1] then                            --- TEST
		w,h = parentTerm.getSize()

		local windowHeight = h-1

		for _,key in pairs(Util.keys(kernel.routines)) do
			local tab = kernel.routines[key]
			local x,y = tab.window.getCursorPos()
			if y > windowHeight then
				tab.window.scroll(y - windowHeight)
				tab.window.setCursorPos(x, windowHeight)
			end
			tab.window.reposition(1, 2, w, windowHeight)
		end

		redrawMenu()
	end
end)

kernel.hook('mouse_click', function(_, eventData)
	if not eventData[4] then
		local x, y = eventData[2], eventData[3]

		if y == 1 then
			if x == 1 then
				multishell.setFocus(overviewId)
			elseif x == w then
				local currentTab = kernel.getFocused()
				if currentTab then
					multishell.terminate(currentTab.uid)
				end
			else
				for _,tab in pairs(kernel.routines) do
					if not tab.hidden and tab.sx then
						if x >= tab.sx and x <= tab.ex then
							multishell.setFocus(tab.uid)
							break
						end
					end
				end
			end
			return true
		end
		eventData[3] = eventData[3] - 1
	end
end)

kernel.hook({ 'mouse_up', 'mouse_drag' }, function(_, eventData)
	if not eventData[4] then
		eventData[3] = eventData[3] - 1
	end
end)

kernel.hook('mouse_scroll', function(_, eventData)
	if not eventData[4] then
		if eventData[3] == 1 then
			return true
		end
		eventData[3] = eventData[3] - 1
	end
end)

kernel.hook('kernel_ready', function()
	overviewId = multishell.openTab({
		path = config.launcher or 'sys/apps/Overview.lua',
		isOverview = true,
		noTerminate = true,
		focused = true,
		title = '+',
	})

	multishell.openTab({
		path = 'sys/apps/shell.lua',
		args = { 'sys/apps/autorun.lua' },
		title = 'Autorun',
	})
end)
