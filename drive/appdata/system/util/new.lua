--[[pod_format="raw",created="2024-03-15 03:34:54",modified="2024-03-18 01:37:50",revision=223]]
-- UTILITY: 'new' command
--   by ahrotahn <reh@ahrotahn.net>
--   creates and loads a new cartridge based on a template cartridge
-- v1.0: inception
-- v1.1: tidy up my files into my own appdata dir

-- source template cart (must exist!)
source_template_dir = "/appdata/new"
source_template = source_template_dir.."/template.p64"

if(fstat(source_template_dir) != "folder") mkdir(source_template_dir)

if fstat(source_template) != "folder" then
	print("ERROR: no source template found at "..source_template)
	print("This template is a required foundation of the newly loaded cart,")
	print(" and an excellent place to customize the starting-point of your carts.")
	print("Suggestion:")
	print(" 1. Restart Picotron to get a blank cartridge")
	print(" 2. Edit the 'initial state' as you'd like. Code, gfx, sfx, maps, etc. Any or none.")
	print("  This will be how all your new carts will start.")
	print(" 3. In terminal: save "..source_template)
	print(" 4. Try me again :)")
	exit(1)
end

-- determine useful default filename
today = split(split(date(), " ")[1], "-", false)
today = today[1] .. today[2] .. today[3]

default_filename_prefix = "/untitled_" .. today .. "_"
default_filename = default_filename_prefix .. "00.p64"

inst = 0
while fstat(default_filename) do
	inst += 1
	
	sinst = inst
	if(inst<10) sinst = "0"..inst
	
	default_filename = default_filename_prefix .. sinst .. ".p64"
end

-- remove currently loaded cartridge
rm("/ram/cart")

-- create new one
local result = cp(source_template, "/ram/cart/")
if (result) then
	print(result)
	exit(1)
end

-- set current project filename
store("/ram/system/pwc.pod", default_filename)

-- tell window manager to clear out all workspaces
send_message(3, {event="clear_project_workspaces"})

dat = fetch_metadata("/ram/cart")
if (dat) dat = dat.workspaces

-- create workspaces (copied from /system/util/load.lua, thx zep)
if (type(dat) == "table") then
	-- open in background (don't show in workspace)
	local edit_argv = {"-b"}

	for i=1,#dat do
		local ti = dat[i]
		local location = ti.location
		if (location) then
			add(edit_argv, "/ram/cart/"..location)
		end
	end

	-- open all at once
	create_process("/system/util/open.lua",
		{
			argv = edit_argv,
			pwd = "/ram/cart"
		}
	)
end

print("new cart initialized: " .. default_filename)