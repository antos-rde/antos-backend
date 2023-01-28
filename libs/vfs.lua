local vfs = {}

vfs.ospath = function(path)
    local user = SESSION.user
    local prefix = string.match(path, "%a+:/")
    local os_path = nil
    if (prefix ~= nil) then
        local suffix = string.gsub(path, prefix, "")
        if prefix == "home:/" then
            os_path = string.format(VFS_HOME, user) .. '/' .. suffix
        elseif prefix == "desktop:/" then
            os_path = string.format(VFS_HOME, user) .. "/.desktop/" .. suffix
        elseif prefix == "shared:/" then
            os_path = require("shared").ospath(ulib.trim(suffix, "/"))
        elseif prefix == "os:/" then
            os_path = WWW_ROOT .. "/" .. suffix
        else
            return nil
        end
        while os_path:match("//") do
            os_path = os_path:gsub("//","/")
        end
        return os_path
    else
        return nil;
    end
end

vfs.delete = function(path)
    local r, m = vfs.checkperm(path, "write")
    if r then
        if ulib.delete(m) then
            -- change permission
            return true, nil
        else
            return false, "Cant not delete the file"
        end
    else
        return r, m
    end
end

vfs.exists = function(path)
    local osfile = vfs.ospath(path)
    return ulib.exists(osfile)
end

vfs.fileinfo = function(vfspath)
    local ospath = vfs.ospath(vfspath)
    if ospath then
        if (ulib.exists(ospath) == false) then
            return false, "File not found"
        end
        local r = ulib.file_stat(ospath)
        if (r.error ~= nil) then
            return false, r.error
        end
        r.path = vfspath
        r.name = utils.basename(vfspath)
        r.mime = std.mimeOf(r.name)
        return true, r
    else
        return false, "Resource not found"
    end
end

vfs.mkdir = function(path)
    local file = utils.basename(path)
    local folder = string.gsub(path, utils.escape_pattern(file) .. "$", "")
    local r, m = vfs.checkperm(folder, "write")

    if r then
        local osfile = m .. "/" .. file
        local uid = ulib.uid(SESSION.user)
        ulib.mkdir(osfile)
        -- change permission
        ulib.chown(osfile, uid.id, uid.gid)
        return true, nil
    else
        return r, m
    end
end

vfs.move = function(src, dest)
    local file = utils.basename(dest)
    local folder = string.gsub(dest, utils.escape_pattern(file), "")

    local sp, sm = vfs.checkperm(src, "write")
    if sp then
        local dp, dm = vfs.checkperm(folder, "write")
        if dp then
            ulib.move(sm, dm .. "/" .. file)
            -- change permission
            return true, nil
        else
            return dp, dm
        end
    else
        return sp, sm
    end
end

vfs.write = function(path, data)
    local file = utils.basename(path)
    local folder = string.gsub(path, utils.escape_pattern(file), "")

    local r, m = vfs.checkperm(folder, "write")
    if r then
        local osfile = m .. "/" .. file

        if ulib.exists(osfile) then
            local r1, m1 = vfs.checkperm(path, "write")
            if not r1 then
                return r1, m1 .. ": " .. path
            end
        end

        local uid = ulib.uid(SESSION.user)
        --
        if data ~= "" then
            local header = string.match(data, "^data%:[%w%.-%+]+%/[%w%.-%+]+;base64,")
            if header ~= nil then
                local b64data = string.gsub(data, utils.escape_pattern(header), "")
                local barr = enc.b64decode(b64data)

                barr:fileout(osfile)
                --[[ if std.isBinary(osfile) then
					
				else
					local f = io.open(osfile, "w")
					f:write(bytes.__tostring(barr))
					f:close()
				end ]]
            else
                return false, "Wrong data format"
            end
        else
            slice.new(0):fileout(osfile)
        end
        -- f:close()
        -- change permission
        ulib.chown(osfile, uid.id, uid.gid)
        return true, nil
    else
        return r, m .. ": " .. folder
    end
end

vfs.upload = function(path)
    if (not path) then
        return false, "Unknown upload destination, abort!"
    end
    local r, m = vfs.checkperm(path, "write")
    if (r) then
        local uid = ulib.uid(SESSION.user)
        local index = 0
        while (REQUEST.multipart["upload-" .. index] ~= nil) do
            local file_data = JSON.decodeString(REQUEST.multipart["upload-" .. index])

            local file = m .. "/" .. file_data.file
            local ret = ulib.move(file_data.tmp, file)
            if not ret then
                ret = ulib.send_file(file_data.tmp, file)
            end
            if not ret then
                return false, "Unable to copy file"
            end
            ulib.chown(file, uid.id, uid.gid)
            index = index + 1
        end
        if (index == 0) then
            return false, "No file is uploaded"
        end
        return true, index
    else
        return r, m
    end
end

vfs.checkperm = function(path, right)
	if path:match("^shared:/.*") then
		if right == "write" then
			return false, "Shared file is readonly"
		else
			return true
		end
	end
    local osfile = vfs.ospath(path)
    local perm = vfs.perm(osfile)
    -- print(osfile)
    if not ulib.exists(osfile) then
        return false, "Resource does not exist"
    end
    -- check if user own the file
    if perm ~= nil then
        if perm[right] == true then
            -- print("Permission granted")
            return true, osfile
        else
            LOG_INFO("Permission denie")
            return false, "You dont have " .. right .. " permission on this file"
        end
    else
        return false, "User is unrecognized"
    end
end

vfs.perm = function(file)
    local user = SESSION.user
    local uid = ulib.uid(user)
    local st = ulib.file_stat(file)
    -- check if user own the file
    if uid ~= nil and st ~= nil and st.perm ~= nil then
        -- print(JSON.encode({uid, st}))
        if (uid.id == st.uid) then -- the user owned the file
            -- print("file belong to user")
            return st.perm.owner
        elseif uid.groups and uid.groups[st.gid] then
            -- print("User belong to this group")	
            return st.perm.group
        else
            -- print("User belong to other")
            return st.perm.other
        end
    else
        return nil
    end
end

vfs.readDir = function(vfspath)
    if (string.sub(vfspath, -1) == "/") then
        prefix = string.sub(vfspath, 1, -2)
    else
        prefix = vfspath
    end
    local ospath = vfs.ospath(vfspath)
    local r = ulib.read_dir(ospath, prefix)
    if (r.error ~= nil) then
        return nil
    end
    -- add extra mime type 
    for k, v in pairs(r) do
        v.mime = std.mimeOf(v.filename)
    end
    return r
end

return vfs
