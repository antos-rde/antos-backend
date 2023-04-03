BaseController:subclass(
    "UserController",
    {
        registry = {},
        models = {}
    }
)

function UserController:actionnotfound(...)
    return self:index(table.unpack({...}))
end

function UserController:index(...)
    local api = {
        description = "This api handle the user authentification",
        actions = {
            ["/auth"] = "Return user information if a user is alreay logged in",
            ["/login"] = "Perform a login operation",
            ["/logout"] = "Perform a logout operation"
        }
    }
    result(api)
    return false
end
--[[
    request query: none
    return:

]]
function UserController:auth(...)
    auth_or_die("User unauthorized. Please login")
    local user = require("uman").userinfo(SESSION.user)
    result(user)
    return false
end

--[[ request:
        {"username":"mrsang", "password":"pass"}
    return:
        {} ]]
function UserController:login(...)
    if REQUEST.json ~= nil then
        local request = JSON.decodeString(REQUEST.json)
        local r = ulib.auth(request.username,request.password)
        if r == true then
            local salt = utils.generate_salt(20)
            local cookie = {sessionid=enc.sha1(request.username..request.password..salt)} -- iotos_user = request.username
            local db = sysdb();
            if db == nil then return fail("Cannot setup session") end
            local cond = {where = { sessionid = cookie.sessionid }}
            local data = db:find(cond)
            --print(data)
            if data == nil or data[1] == nil then
                --print("insert new data")
                data = {sessionid = cookie.sessionid, username=request.username, stamp=os.time(os.date("!*t"))}
            else
                data = data[1]
                --print("Update old data")
                data.stamp = os.time(os.date("!*t"))
            end
            if data.id == nil then
                db:insert(data)
            else
                db:update(data)
            end
            db:close()
            for k,v in pairs(cookie) do
                --- TODO: add expire date to cookie
                std.setCookie(k.."="..v, "Path=/")
            end
            std.json()
            SESSION.user = request.username
            local user = {
                result = require("uman").userinfo(request.username),
                error = false
            }
            std.t(JSON.encode(user))
        else
            fail("Invalid login")
        end
    else
        fail("Invalid request")
    end
    return false    
end

function UserController:logout(...)
    if SESSION.sessionid ~= nil and SESSION.sessionid ~= '0' then
        local cookie = {sessionid='0'}
        local db = sysdb()
        if db ~= nil then
            local cond = {where = { sessionid = SESSION.sessionid }}
            db:delete(cond)
            db:close()
        end
        for k,v in pairs(cookie) do
            std.setCookie(k.."="..v, "Path=/")
        end
    end
    std.json()
    std.t(JSON.encode({error=false,result=true}))
end