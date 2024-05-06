--[[pod_format="raw",created="2024-03-17 09:09:02",modified="2024-03-17 23:50:14",revision=51]]
-- UTILITY: 'merge' command
--   by ahrotahn <reh@ahrotahn.net>
--   recursively copies source directories over a destination directory
-- v1: inception

local NAME = "merge"

function usage()
	print("usage: "..NAME.." [options] <src...> <dst>")
	print(" Recursively merges source directories into a destination")
	print("Options:")
	print("  -u|--unmerge - Will attempt to undo a merge, removing src files from dst")
	print("  -g|--gentle - Will make an in-place backup (file.ext.bak) before overwriting files")
	print("  -p|--paranoid - Will simply not overwrite files and will continue merging")
end	

function merge(src, dst, gentle, dir)
	if (src:sub(-1) == "/") src = src:sub(1,-2)
	if (dst:sub(-1) == "/") dst = dst:sub(1,-2)
	dir = dir or "/"
	gentle = gentle or 0
	--print("merge("..pod(src)..", "..pod(dst)..", "..pod(gentle)..", "..pod(dir)..")")
	
	local files,dirs = {},{}
	for entry in all(ls(src..dir)) do
		--print("entry: "..entry)
		local type = fstat(src..dir..entry)
		local rpath = dir..entry
		if type == "folder" then
			if fstat(dst..rpath) != "folder" then
				--print("mkdir "..dst..rpath)
				mkdir(dst..rpath)
				add(dirs, dst..rpath)
			end

			local results = merge(src, dst, gentle, dir..entry.."/")
			foreach(results["files"], function(v) add(files, v) end)
			foreach(results["dirs"], function(v) add(dirs, v) end)
		elseif type == "file" then
			local clobbery = (fstat(dst..rpath) == "file")
			if clobbery and gentle == 1 then
				print("!! gently setting aside "..dst..rpath)
				cp(dst..rpath, dst..rpath..".bak")
			elseif clobbery and gentle == 2 then
				print("!! won't clobber "..dst..rpath)
			end
			
			if (not clobbery) or gentle < 2 then
				--print("cp "..src..rpath.." "..dst..rpath)
				cp(src..rpath, dst..rpath)
				add(files, dst..rpath)
			end
		end
	end
	
	return {files=files, dirs=dirs}
end

function unmerge(src, dst, dir)
	dir = dir or "/"
	
	local files, dirs = {}, {}

	-- remove all files first by drilling all the way in
	-- then removing files on the way out
	for entry in all(ls(src..dir)) do
		if fstat(src..dir..entry) == "folder" then
			local result = unmerge(src, dst, dir..entry.."/")
			foreach(result["files"], function(v) add(files, v) end)
			foreach(result["dirs"], function(v) add(dirs, v) end)
		end
	end
	
	for entry in all(ls(src..dir)) do
		local rpath = dir..entry
		if fstat(src..dir..entry) != "folder" then
			rm(dst..rpath)
			add(files, dst..rpath)
		end
	end
	
	-- then check all dirs for emptiness and rm those
	if fstat(dst..dir) == "folder" and #ls(dst..dir) == 0 then
		rm(dst..dir)
		add(dirs, dst..dir)
	end
	
	return {files=files, dirs=dirs}
end

if env().prog_name:basename() == NAME..".lua" then
	cd(env().path)
	local args = env().argv
	if #args < 1 then
		usage()
		exit(1)
	end
	
	local gentleness = 0
	local anti = false
	
	local srcs = {}
	for arg in all(args) do
		if arg == "-g" or arg == "--gentle" then
			print("I'll be gentle and make in-place backups before clobbering")
			gentleness = 1
		elseif arg == "-p" or arg == "--paranoid" then
			print("I'll be paranoid and simply not clobber, but will keep working")
			gentleness = 2
		elseif arg == "-u" or arg == "--unmerge" then
			anti = true
		else
			add(srcs, arg)
		end
	end
	local dst = deli(srcs)
	
	local files,dirs = 0,0
	for src in all(srcs) do
		if fstat(src) == "folder" then
			local results = nil
			if anti then
				results = unmerge(src, dst)
			else
				results = merge(src, dst, gentleness)
			end
			
			files += #results["files"]
			dirs += #results["dirs"]
		end
	end
	
	if anti then
		print("Unmerge complete.")
		print(" Removed "..files.." file(s)")
		print(" Cleaned "..dirs.." empty dir(s)")
	else
		print("Merge complete.")
		print(" Created "..dirs.." dir(s)")
		print(" Copied "..files.." file(s)")
	end
end