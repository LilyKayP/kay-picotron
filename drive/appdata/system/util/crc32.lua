--[[pod_format="raw",created="2024-03-15 03:34:54",modified="2024-03-21 22:17:54",revision=536]]
-- UTILITY: 'crc32' command
--   by ahrotahn <reh@ahrotahn.net>
--   calculates file crc32 hashes and manages .crcs hashlists
-- v1.0: inception

local NAME = "crc32"

local function usage()
	print("usage: "..NAME.." [-s|-p] [-a <crcs>|-d <crcs>|-r <crcs>|-V] <input>")
	print(" Calculate and output CRC32 hash of input file, directory, or string")
	print("Options:")
	print("  -s|--string - Don't treat input as path, only as string (default: auto)")
	print("  -p|--path - Don't treat input as string, only as path (default: auto)")
	print("  -a|--append <crcs> - Append hash to .crcs file (if not present)")
	print("    (crcs argument not provided when using -V|--version)")
	print("  -d|--delete <crcs> - Delete hash from .crcs file (if present)")
	print("    (crcs argument not provided when using -V|--version)")
	print("  -r|--replace <crcs> - Empty .crcs file and add only this hash")
	print("    (crcs argument not provided when using -V|--version)")
	print("  -V|--version - For every file that exists in input directory,")
	print("    add the CRC32 for that file to the relevant .crcs in the path")
	print("    alongside the file. (Useful for yotta upgrade .crcs)")
	print("    If you override the action with -d or -r it will be obeyed.")
	print("    (Default -V action is -a to append)")
end	

__crc32_silent = false

local crc32_initialized = false
local crc32_table = {}

local function _crc32_init()
	local poly = 0xEDB88320
	for i = 0, 255 do
		local crc = i
		for j = 1, 8 do
			crc = (crc & 1) ~= 0 and (poly ~ (crc >> 1)) or (crc >> 1)
		end
   		crc32_table[i] = crc
	end
end

local function _crc32_str(str)
	if(not crc32_initialized) _crc32_init()

	local crc = 0xFFFFFFFF
	for i = 1, #str do
		local byte = string.byte(str, i)
		crc = crc32_table[(crc ~ byte) & 0xFF] ~ (crc >> 8)
	end
	return crc ~ 0xFFFFFFFF
end

function crc32(data, file)
	if file == nil then
		file = (fstat(data) != "nil")
	end
	
	if file then
		local ftype = fstat(data)
		if ftype == "file" then
			data = fetch(data)
		elseif ftype == "folder" then
			-- recursively calculate. eek
			local subcrcs = {}
			for entry in all(ls(data)) do
				add(subcrcs, crc32(data.."/"..entry))
			end
			data = table.concat(subcrcs, ":")
		elseif ftype == nil then
			file = false
		else
			if(not __crc32_silent) printh("** crc32: cannot hash unknown fs type: "..ftype)
			return false
		end
	end
	
	return _crc32_str(data)
end

local function _crcs_edit(file, hash, mode)
	local hashes = {}
	
	if mode != "replace" then
		if fstat(file) == "file" then
			local orig = fetch(file)
			hashes = split(orig, ":", false)
		end
		
		if mode == "append" and count(hashes, hash) == 0 then
			add(hashes, hash)
		elseif mode == "delete" then
			while count(hashes, hash) > 0 do
				del(hashes, hash)
			end
		end
	else
		hashes = {hash}
	end
	
	if #hashes == 0 then
		rm(file)
	else
		store(file, table.concat(hashes, ":"))
	end
end

local function _crcs_version(target, dest, mode, dir)
	-- generate hashes of everything in target
	-- and write them into dest
	
	if(mode == "none") mode = "append"
	dir = dir or "/"

	for entry in all(ls(target..dir)) do
		local rpath = dir..entry
		local ftype = fstat(target..rpath)
		if ftype == "folder" then
			_crcs_version(target, dest, mode, rpath.."/")
		elseif ftype == "file" and rpath:sub(-5) != ".crcs" then
			local dst_ftype = fstat(dest..rpath)
			if dst_ftype == "file" then
				local target_hash = tostr(crc32(target..rpath, true))
				print(target_hash.." "..target..rpath)
				_crcs_edit(dest..rpath..".crcs", target_hash, mode)
			end
		end
	end
end

if env().prog_name:basename() == NAME..".lua" then
	cd(env().path)
	local args = env().argv
	if #args < 1 then
		usage()
		exit(1)
	end
	
	local type = "auto"
	local mode = "none"
	local version = (count(args, "-V") + count(args, "--version")) > 0
	local flagarg = nil
	
	local input = {}
	local i = 1
	while i <= #args do
		local arg = args[i]
				
		if arg == "-s" or arg == "--string" then
			type = "string"
		elseif arg == "-p" or arg == "--path" then
			type = "path"
		elseif arg == "-a" or arg == "--append" then
			if not version then
				flagarg = args[i+1]
				i += 1
			end
			mode = "append"
		elseif arg == "-d" or arg == "--delete" then
			if not version then
				flagarg = args[i+1]
				i += 1
			end
			mode = "delete"
		elseif arg == "-r" or arg == "--replace" then
			if not version then
				flagarg = args[i+1]
				i += 1
			end
			mode = "replace"
		elseif arg != "-V" and arg != "--version" then
			add(input, arg)
		end
		
		i += 1
	end
	input = table.concat(input, " ")
		
	if type == "auto" then
		if fstat(input) == "file" or fstat(input) == "folder" then
			type = "file"
		else
			type = "string"
		end
	end
	
	if type == "file" and fstat(input) == nil then
		print("ERROR: file not found: '"..input.."'")
		exit(1)
	end
	
	if mode == "none" and version then
		mode = "append"
	end
	
	if version then
		_crcs_version(input, input, mode)
	else
		local hash = tostr(crc32(input, (type == "file")))
		print(hash.." "..input)
		_crcs_edit(flagarg, hash, mode)
	end
end