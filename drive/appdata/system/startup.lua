--[[pod_format="raw",created="2024-05-05 19:54:07",modified="2024-05-06 01:56:26",revision=16]]
create_process("/appdata/369/picophone.p64.png", {window_attribs = {
	workspace = "tooltray",
	x=350, y=25,
	width=127, height=205
}})

--[[
workspace can be
- new         -- opens in new (need to figure out details)
- current     -- opens in currently open workspace
- tooltray	 -- opens in tooltray, cannot have border
]]--


--[[
width = win.width, height = win.height,
x = win.x, y = win.y, z = win.z + 1, -- desktop is -1000 (head.lua)

title = "",

has_frame = false,
moveable = false,
resizeable = false,
autoclose = true,            -- used for screensavers?

workspace = "current",
show_in_workspace = true,    -- immediately show running process

desktop_filenav = true,
pwc_output = true,           -- replace existing pwc_output process			
]]--

--[[
	menuitem{
		id = 1,
		label = "Test",
		shortcut = "CTRL-E",
		action = function()
			debug.string="testing!!!"
		end,
	}
]]--
 