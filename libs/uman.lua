local uman={}

uman.userinfo = function(user)
	local info = {}
	local uid = ulib.uid(user)
	if uid then
		-- create the following directory structure if does not exists
		local dir = require('vfs').ospath("home:///.antos", user)
		if not ulib.exists(dir) then
			ulib.mkdir(dir)
			ulib.chown(dir, uid.id, uid.gid)
		end
		local setting_dir = dir.."/settings"
		if not ulib.exists(setting_dir) then
			ulib.mkdir(setting_dir)
			ulib.chown(setting_dir, uid.id, uid.gid)
		end
		local desktop_dir = dir.."/desktop"
		if not ulib.exists(desktop_dir) then
			ulib.mkdir(desktop_dir)
			ulib.chown(desktop_dir, uid.id, uid.gid)
		end
		-- read the setting
		-- use the decodeFile function of JSON instead
		local file =  require('vfs').ospath("home:///").."/.antos/settings/settings.json"
		local st = JSON.decodeFile(file)
		if(st) then
			info = st
		end
		info.user = {
			username = user,
			id = uid.id,
			name = user,
			groups = uid.groups
		}
		--print(JSON.encode(info))
		return info
	else 
		return {}
	end
end

return uman