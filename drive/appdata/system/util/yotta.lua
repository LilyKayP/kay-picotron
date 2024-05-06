--[[pod_format="raw",created="2024-03-16 21:44:35",modified="2024-05-05 21:18:49",revision=468]]
-- yotta: a "package" "manager" for Picotron
--  by ahrotahn <reh@ahrotahn.net>
-- v1.0: initial hideous beautiful version
-- v1.1: better overwrite handling (crc32 comparison)

local VERSION = "1.1"
local MIGRATION = 2

local YF_VER = 1
local YF_DIR = "lib"
local YF_TRACKFILE = "yottafile.pod"
local YF_DEFAULT = YF_DIR.."/" .. YF_TRACKFILE
--local YF_SYS = "/appdata/system/global_yottafile.pod"
local YF_SYS = "/appdata/yotta/global_yottafile.pod"

-- gentleness controls action upon file conflict
--  0 (clobbers), 1 (backs up), 2 (skips)
-- default backs up. controllable with -f and -g
local gentleness = 1

function usage()
	print("usage: yotta [command]")
	print("commands:")
	print(" version - reveal version number")
	print(" init - initialize a yottafile for the current directory")
	print(" list - list the current dependencies")
	print("   -v - verbose: list all tracked files under each dependency")
	print(" add [cart] - add a cart ref as dependency (but don't add/remove anything yet)")
	print(" remove [cart] - remove a cart ref as dependency (but don't add/remove anythin yet)")
	print(" apply - make the current directory match a yottafile")
	print("   (this is what actually adds and removes files!)")
	print(" force - this is an apply that will reinstall every dep (for updates?)")
	print(" util install [-f|-g] [cart] - globally install utility cart ref")
	print("   -f - be forceful. overwrites destination files that differ from the source.")
	print("   -g - be gentle. won't copy over files that differ from the source.")
	print("   (by default, it will create a backup of the different destination and copy like normal)")
	print(" util uninstall [cart] - globally uninstall utility cart ref")
	print(" util list - list all tracked util cart refs and their files")
end

function migrate()
	local migrationfile = "/appdata/yotta/migration.txt"
	local prev_version = 1
	if fstat(migrationfile) == "file" then
		prev_version = tonum(tostr(fetch(migrationfile)))
	end
	
	if prev_version == MIGRATION then
		-- nothing to do
		return
	elseif prev_version > MIGRATION then
		print("** warning: running older yotta version than what's installed!")
		print("   i'll still do as you ask but, you know, this is weird.")
		print("   so, your mileage may vary")
		return
	end
		
	if prev_version <= 1 then
		-- make the yotta app dir (should already exist..)
		if(fstat("/appdata/yotta") != "folder") mkdir("/appdata/yotta")
		
		-- copy the old global yottafile to the new location
		local old_global = "/appdata/system/global_yottafile.pod"
		if(fstat(old_global) == "file") mv(old_global, YF_SYS)
		
		-- if an old version of yotta installed us we should check
		-- for lingering new .crcs files to clean those up.
		-- won't happen in the future, .crcs are ignored then.
		-- this will only run once on yotta upgrade from v1.0
		if fstat(YF_SYS) == "file" then
			local yf = read_yottafile(YF_SYS)
			for norm,v in pairs(yf.tracked) do
				for trk in all(yf.tracked[norm]) do
					if trk:sub(-5) == ".crcs" then
						rm(trk)
						del(yf.tracked[norm], trk)
					end
				end
			end
			write_yottafile(yf, YF_SYS)
		end
	end
	
	-- update our migration number
	store(migrationfile, tostr(MIGRATION))
end

function download_bbs_cart(id)
	-- ok, yes, yes zep, i know you said this isn't a public api
	-- but i do so like to live dangerously.
	-- return fetch("http://picotron-dev.local/"..id)
	return fetch("https://www.lexaloffle.com/bbs/get_cart.php?cat=8&lid="..id)
	-- i'm placing it up top in an easy-to-access place in case
	-- it needs to be manually edited by end-users in the future
	-- to comply with some kind of eventual future public api
	-- to get everything running again.
end

function read_yottafile(yfp)
	yfp = yfp or YF_DEFAULT
	local raw = fetch(yfp)

	if raw._yf_version == 1 then
		return {
			tags = raw.tags,
			deps = raw.deps,
			tracked = raw.tracked
		}
	else
		print("ERROR: unknown yottafile version: " .. raw._yf_version)
		print("Malformed or future yottafile? Maybe update yotta or pick a real target?")
		exit(1)
	end
end

function write_yottafile(yf, yfp)
	yfp = yfp or YF_DEFAULT
	store(yfp, {
		_yf_version = YF_VER,
		tags = yf.tags,
		deps = yf.deps,
		tracked = yf.tracked
	})
end

function normalize_cart_ref(ref)
	if ref:sub(1,1) == "#" then
		-- BBS id
		ref = "_bbs_" .. ref:sub(2)
	else
		-- filename
		ref = fullpath(ref):basename()
		if (ref:sub(-4) == ".png") ref = ref:sub(1, -5)
		if (ref:sub(-4) == ".p64") ref = ref:sub(1, -5)
	end
	
	ref = table.concat(split(ref, "-", false), "_")
	ref = table.concat(split(ref, ".", false), "_")
	-- TODO: figure out more bad fs symbols to fix probably lmao

	return ref
end

function install_ref(ref, yfp, dest_dir, owner_ref)
	yfp = yfp or YF_DEFAULT
	owner_ref = owner_ref or ref
	
	local norm_name = normalize_cart_ref(ref)
	dest_dir = dest_dir or "./"..YF_DIR.."/"..norm_name
	local tmp_cart = "/ram/_yotta_temp.p64"

	-- fetch cart data
	if ref:sub(1,1) == "#" then
		-- BBS download
		tmp_cart ..= ".png"
		local data = download_bbs_cart(ref:sub(2))	
			
		if type(data) != "string" or #data <= 0 then
			print("ERROR: could not acquire BBS cart with ID: " .. ref);
			exit(1)
		end
		
		rm(tmp_cart)
		store(tmp_cart, data)
	else
		-- file path
		
		local filename = fullpath(ref)
		if fstat(filename) != "folder" then
			filename = filename..".p64"
			if fstat(filename) != "folder" then
				filename = filename..".png"
				if fstat(filename) != "folder" then
					print("ERROR: could not acquire filesystem cart with path: " .. ref)
					exit(1)
				end
			end
		end

		if (filename:sub(-8) == ".p64.png") tmp_cart ..= ".png"
		cp(filename, tmp_cart)
	end
	
	-- does target have /export
	local exports_dir = tmp_cart .. "/exports"
	if not fstat(exports_dir) then
		print("WARNING: specified ref ("..ref..") has no exports. IGNORING REF!")
		return false
	end
	
	if yfp == YF_SYS then
		-- overlay exports onto root fs
		-- kind of yikes ig
		local yf = nil
		local conflict_handler = function(src, dst)
			-- conflict! dst already exists
			if gentleness == 0 then
				print("** overwriting "..dst)
				return true
			end	
		
			if(not yf) yf = read_yottafile(yfp)
			local safe_hashes = {}
			if fstat(src..".crcs") == "file" then
				local extras = split(fetch(src..".crcs"), ":", false)
				foreach(extras, function(v) add(safe_hashes, v) end)
			end
			local current_hash = tostr(crc32(src))
			add(safe_hashes, current_hash)
			
			local dst_hash = tostr(crc32(dst))

			if count(safe_hashes, dst_hash) > 0 then
				-- safe to overwrite
				if dst_hash != current_hash then
					print("** upgrading: "..dst)
				end
				return true
			end
			
			if gentleness == 1 then
				print("** backed up: "..dst..".bak")
				-- made a backup, let's continue
				cp(dst, dst..".bak")
				return true
			end
			
			-- don't do it
			print("** file exists, skipping: "..dst)
			return false
		end
		
		local result = merge(exports_dir, "", conflict_handler)
		foreach(result.files, function(v) yf_add_track(ref, v, yfp) end)
		foreach(result.dirs, function(v) yf_add_track(ref, v, yfp) end)
	else
		if fstat(dest_dir) != "folder" then
			mkdir(dest_dir)
			yf_add_track(ref, dest_dir, yfp)
		end
	
		-- extract exports into appropriate CWD locations
		for exp in all(ls(exports_dir)) do
			local full = fullpath(exports_dir.."/"..exp)
			local ext = exp:sub(-4)
			local dest = dest_dir.."/"..full:basename()
			local lua = (ext == ".lua")
		
			if ext == ".gfx" or ext == ".sfx" or ext == ".map" then
				-- allow gfx, sfx, and map exports!
				dest = "./"..ext:sub(-3).."/"..norm_name.."_"..full:basename()
			end
		
			print("copying src:"..exp.." => dst:"..dest)
			cp(full, fullpath(dest))
			yf_add_track(ref, dest, yfp)
		end
	end

	-- clean up...
	rm(tmp_cart)
end

function yf_add_track(ref, file, yfp)
	local yf = read_yottafile(yfp)
	local norm = normalize_cart_ref(ref)
	if type(yf.tracked[norm]) != "table" then
		yf.tracked[norm] = {}
	end
	if count(yf.tracked[norm], file) == 0 then
		add(yf.tracked[norm], file)
	end
	if type(yf.tracked._refs) != "table" then
		yf.tracked._refs = {}
	end
	if count(yf.tracked._refs, ref) == 0 then
		add(yf.tracked._refs, ref)
	end
	write_yottafile(yf, yfp)
end

function yf_remove_track(ref, file, yfp)
	local yf = read_yottafile(yfp)
	local norm = normalize_cart_ref(ref)
	if type(yf.tracked[norm]) != "table" then
		return
	end
	while count(yf.tracked[norm], file) > 0 do
		del(yf.tracked[norm], file)
	end
	if #yf.tracked[norm] == 0 then
		deli(yf.tracked, norm)
		del(yf.tracked._refs, ref)
	end
	write_yottafile(yf, yfp)
end

function uninstall_ref(ref, yfp)
	yfp = yfp or YF_DEFAULT
	local norm_name = normalize_cart_ref(ref)
	local yf = read_yottafile(yfp)
	
	if type(yf.tracked[norm_name]) != "table" then
		return
	end
	
	for file in all(yf.tracked[norm_name]) do
		local type = fstat(fullpath(file))
		if type != "folder" then
			rm(fullpath(file))
			yf_remove_track(ref, file, yfp)
		end
	end
	
	for file in all(yf.tracked[norm_name]) do
		local type = fstat(fullpath(file))
		if type == "folder" then
			if #ls(fullpath(file)) == 0 then
				-- remove folders originally added by this ref that are now empty
				rm(fullpath(file))
			end
			
			yf_remove_track(ref, file, yfp)
		end
	end
end

function merge(src, dst, conflict_fn, dir)
	conflict_fn = conflict_fn or function(source, dest)
		cp(dest, dest..".bak")
		return true
	end
	dir = dir or "/"
	
	local dirs = {}
	local files = {}
	
	for entry in all(ls(src..dir)) do
		local type = fstat(src..dir..entry)
		local rpath = dir..entry
		if type == "folder" then
			if fstat(dst..rpath) != "folder" then
				mkdir(dst..rpath)
			end

			local inner = merge(src, dst, conflict_fn, dir..entry.."/")
			foreach(inner.dirs, function(v) add(dirs, v) end)
			foreach(inner.files, function(v) add(files, v) end)
		elseif type == "file" and rpath:sub(-5) != ".crcs" then
			if fstat(dst..rpath) == nil
			or conflict_fn(src..rpath, dst..rpath) == true then			
				add(files, dst..rpath)
				cp(src..rpath, dst..rpath)
			end
		end
	end
	
	return {
		dirs = dirs,
		files = files
	}
end

function yf_init(yfp)
	yfp = yfp or YF_DEFAULT
	
	if fstat(yfp) then
		return
	end

	local tags = {
		created = date()
	}
	
	print("initializing yottafile at: " .. fullpath(yfp))
	
	if yfp != YF_SYS and fstat(YF_DIR) != "folder" then
		mkdir(YF_DIR)
	end
	
	write_yottafile({
		deps = {},
		tags = tags,
		tracked = {
			_refs = {}
		}
	}, yfp)
end

function yf_list(verbose, yfp)
	verbose = verbose or false
	yfp = yfp or YF_DEFAULT
	
	local yf = read_yottafile(yfp)
	print("list of current "..(yfp == YF_SYS and "system-level utilities" or "dependencies")..":")
	
	for dep in all(yf.deps) do
		local norm = normalize_cart_ref(dep)
		print("  "..dep.." (\""..norm.."\")")
		if verbose or util then
			for file in all(yf.tracked[norm]) do
				print("    " .. file)
			end
		end
	end
end	

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
			if(not __crc32_silent) printh("** crc32: cannot hash unknown file type: "..ftype)
			return false
		end
	end
	
	return _crc32_str(data)
end

--
-- entry
--

cd(env().path)
migrate()

local argv = env().argv
if (#argv < 1) then
	usage()
	exit(1)
end

local command = argv[1]

if count({"version", "init", "util", "help"}, command) == 0
and fstat(YF_DEFAULT) != "file" then
	print("ERROR: No yottafile present")
	print("")
	usage()
	exit(1)
end

if command == "version" then
	print("yotta version v"..VERSION)
elseif command == "init" then
	yf_init()
elseif command == "list" then
	yf_list(argv[2] == "-v")
elseif command == "add" then
	for i = 2, #argv do
		local ref = argv[i]

		local yf = read_yottafile()
		if count(yf.deps, ref) == 0 then
			print("adding "..ref)
			add(yf.deps, ref)
			write_yottafile(yf)
		else
			print(ref.." was already added")
		end
	end
	print("run `yotta apply` to install or `yotta force` to update dependencies in "..YF_DIR.."/")
elseif command == "remove" then
	for i = 2, #argv do
		local ref = argv[i]
		local yf = read_yottafile()
		
		for dep in all(yf.deps) do
			if normalize_cart_ref(dep) == ref then
				print("assuming "..ref.." = "..dep)
				ref = dep
				break
			end
		end
	
		if count(yf.deps, ref) > 0 then
			print("removing "..ref)
			while count(yf.deps, ref) > 0 do
				del(yf.deps, ref)
			end
			write_yottafile(yf)
		else
			print(ref.." was already not present")
		end
	end
	print("run `yotta apply` or `yotta force` to remove dependencies from "..YF_DIR.."/")
elseif command == "apply" or command == "force" then
	local yf = read_yottafile()
	local force = (command == "force")
	local adds,dels,upds = 0,0,0

	for ref in all(yf.tracked._refs) do
		if count(yf.deps, ref) == 0 then
			print("removing dependency: "..ref)
			uninstall_ref(ref)
			dels += 1
		end
	end
	
	for ref in all(yf.deps) do
		if force or count(yf.tracked._refs, ref) == 0 then
			local updating = count(yf.tracked._refs, ref) > 0
			print((updating and "updating" or "adding") .. " dependency: "..ref)
			install_ref(ref)
			if(updating) upds += 1
			if(not updating) adds += 1
		end
	end
	
	print(adds.." installed")
	if(force) print(upds.." updated")
	print(dels.." removed")
elseif command == "util" then
	yf_init(YF_SYS)
	
	subcommand = argv[2]
	if subcommand == "install" or subcommand == "uninstall" or subcommand == "update" then
		-- lmao sry
		if(subcommand == "update") subcommand = "updat"
		
		refs = {}
		for i = 3, #argv do
			local arg = argv[i]
			if arg == "-f" then
				gentleness = 0
			elseif arg == "-g" then
				gentleness = 2
			else
				add(refs, arg)
			end
		end
		for i = 1, #refs do
			local ref = refs[i]
			local yf = read_yottafile(YF_SYS)
			if subcommand != "install" then
				-- allow specifying ref by installed short name
				for dep in all(yf.deps) do
					if normalize_cart_ref(dep) == ref then
						print("assuming "..ref.." = "..dep)
						ref = dep
						break
					end
				end
			end	
		
			print(subcommand.."ing utility: "..ref)

			if subcommand != "updat" then
				if subcommand == "install" then 
					if count(yf.deps, ref) == 0 then
						add(yf.deps, ref)
					end
				elseif subcommand == "uninstall" then
					while count(yf.deps, ref) > 0 do
						del(yf.deps, ref)
					end
				end
				write_yottafile(yf, YF_SYS)
			end
		
			if subcommand != "install" then
				uninstall_ref(ref, YF_SYS)
			end	

			if subcommand != "uninstall" then
				install_ref(ref, YF_SYS)
			end
		end
	elseif subcommand == "list" then
		yf_list(true, YF_SYS)
	else
		usage()
		exit((subcommand != "help") and 1 or 0)
	end
else
	usage()
	exit((command != "help") and 1 or 0)
end