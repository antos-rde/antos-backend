local uman={}

uman.userinfo = function(user)
	local info = {}
	local uid = ulib.uid(user)
	if uid then
		-- read the setting
		-- use the decodeFile function of JSON instead
		local file =  require('vfs').ospath("home:///").."/.settings.json"
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