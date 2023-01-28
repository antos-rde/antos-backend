require("silk.core.sqlite")
local TUNNEL_KEYCHAIN = __api__.tmpdir.."/channels/antunnel_keychain"
function fail(msg)
    std.custom_header("Connection", "close")
    std.json()
    std.t(JSON.encode({
        error = msg
    }))
end

function result(obj)
    std.custom_header("Connection", "close")
    std.json()
    std.t(JSON.encode({
        result = obj,
        error = false
    }))
end

function die(msg)
    fail(msg)
    debug.traceback = nil
    error("Permission denied")
    return false
end

-- check if the sysdb is create, otherwise create the table
function sysdb()
    local meta = {}
    meta.sessionid = ""
    meta.username = ""
    meta.stamp = 0
    return require("dbmodel").get("sysdb", "sessions", meta)
end

function is_auth()
    local sessionid = nil
    if SESSION.sessionid and SESSION.sessionid ~= '0' then
        sessionid = SESSION.sessionid
        -- should be used only by API call
    elseif REQUEST.sessionid and REQUEST.sessionid ~= '0' then
        sessionid = REQUEST.sessionid
    elseif REQUEST.access_token and REQUEST.access_token ~= '0' then
        sessionid = REQUEST.access_token
    end
    if sessionid == nil then
        return false
    end
    -- query session id from database
    local db = sysdb()
    if db == nil then
        return false
    end
    local cond = {
        exp = {
            ["="] = {
                sessionid = sessionid
            }
        }
    }
    local data = db:find(cond)
    db:close()
    if data == nil or data[1] == nil then
        return false
    end
    -- TODO check the stamp
    SESSION.user = data[1].username
    local f = io.open(TUNNEL_KEYCHAIN, "w")
    if f then
        f:write(sessionid .. SESSION.user)
        f:close()
    end
    return true
end

function auth_or_die(msg)
    if (is_auth() == false) then
        die(msg)
    end
end
