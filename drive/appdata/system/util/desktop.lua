--[[pod_format="raw",created="2024-05-06 07:18:08",modified="2024-05-06 07:26:33",revision=7]]
notify("whatup")
create_process("/appdata/system/wallpapers/biplane.p64",{
	window_attribs = {
		wallpaper = true,
		workspace = "new"
	}
})
--[[
create_process("/system/apps/filenav.p64",{
	 -- window attribs of the desktop program launching the desktop filenav
	argv = {"-desktop", "/desktop"},
	window_attribs = {
		workspace = "new", -- same workspace as the wallpaper
		width = 480, height = 270,
		x = 0, y = 0, z = 1, -- desktop is -1000 (head.lua)
		has_frame = false,
		moveable = false,
		resizeable = false,
		desktop_filenav = true
	}
})
]]--