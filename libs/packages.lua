local packages = {}
local vfs = require("vfs")
local uid = ulib.uid(SESSION.user)

packages._cache = function(y)
    local p = vfs.ospath(y)
	local file_path = p .. "/packages.json"
    local f = io.open(file_path, "w")
    local has_cache = false
    local i = 1
    local meta = {}
	
    if not f then
		-- store it is temporal file
		file_path = string.format("%s/%s.packages.json",__api__.tmpdir, enc.sha1(p))
        f = io.open(file_path, "w")
    end
    if f then
		LOG_DEBUG("Cache package files into: %s", file_path)
        local files = vfs.readDir(y)
        for k, v in pairs(files) do
            if v.type == "dir" then
                local f1 = io.open(vfs.ospath(v.path .. "/package.json"))
                if f1 then

                    local name = utils.basename(v.path)
                    local mt = JSON.decodeString(f1:read("*all"))
                    mt.path = v.path
                    meta[name] = mt
                    f1:close()
                    has_cache = true;
                end
            end
        end
        f:write(JSON.encode(meta))
        f:close()
        if has_cache == false then
            ulib.delete(file_path);
        end
    end
end

-- we will change this later
packages.list = function(paths)
    std.json()
    local ret = {
        result = {},
        error = false
    }
    for k, v in pairs(paths) do
		local p = vfs.ospath(v)
		local f1 = p.."/packages.json"
		local f2 = string.format("%s/%s.packages.json",__api__.tmpdir, enc.sha1(p))

        if not ulib.exists(f1) and not ulib.exists(f2) then
            packages._cache(v)
        end
		local osp = f1
		if not ulib.exists(osp) then
			osp = f2
		end
        if ulib.exists(osp) then
            LOG_DEBUG("Use package cache files at: %s", osp)
            local data = JSON.decodeFile(osp)
            if data then
                for k1,v1 in pairs(data) do
                    ret.result[k1] = v1
                end
            end
        end
    end
    std.t(JSON.encode(ret))
end

-- generate the packages caches
packages.cache = function(args)
    -- perform a packages caches
    for x, y in pairs(args.paths) do
        packages._cache(y)
    end
    result(true)
end
-- install a function from zip file
packages.install = function(args)
    local path = vfs.ospath(args.dest)
    local zip = vfs.ospath(args.zip)
    if (ulib.exists(path) == false) then
        -- create directory if not exist
        ulib.mkdir(path)
        -- change permission
        ulib.chown(path, uid.id, uid.gid)
    end
    -- extract the zip file to it
    if (ulib.unzip(zip, path)) then
        -- read metadata
        local meta = JSON.decodeFile(path .. "/metadata.json")
        meta.path = args.dest
        meta.scope = "user"
        local f = io.open(path .. "/package.json", "w")
        if f then
            f:write(JSON.encode(meta))
            f:close()
        end
        result(true)
    else
        fail("Problem extracting zip file")
    end

end
-- uninstall the package
packages.uninstall = function(path)
    local osf = vfs.ospath(path)
    if (osf and ulib.exists(osf)) then
        -- remove it
        ulib.delete(osf)
        result(true)
    else
        fail("Cannot find package")
    end
end
-- set user packages environment
packages.init = function(paths)
    if (paths) then
        for k, v in pairs(paths) do
            local p = vfs.ospath(v)
            if p and (ulib.exists(p) == false) then
                ulib.mkdir(p)
                -- change permission
                ulib.chown(p, uid.id, uid.gid)
            end
        end
    end
end

return packages
