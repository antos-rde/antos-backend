BaseController:subclass(
    "SystemController",
    {
        registry = {},
        models = {}
    }
)

function SystemController:actionnotfound(...)
    return self:index(table.unpack({...}))
end

function SystemController:index(...)
    local api = {
        description = "This api handle system operations",
        actions = {
            ["/packages"] = "Handle all operation relate to package: list, install, cache, uninstall",
            ["/settings"] = "Save user setting",
            ["/application"] = "Call a specific server side application api",
            ["/apigateway"] = "Gateway for executing custom server side code"
        }
    }
    result(api)
    return false
end

function SystemController:packages(...)
    auth_or_die("User unauthorized. Please login")
    local rq = (JSON.decodeString(REQUEST.json))
    local packages = require("packages")
    packages.init(rq.args.paths)
    if rq ~= nil then
        -- check user command here
        if (rq.command == "install") then
            packages.install(rq.args)
        elseif rq.command == "cache" then
            packages.cache(rq.args)
        elseif rq.command == "list" then
            packages.list(rq.args.paths)
        elseif rq.command == "uninstall" then
            packages.uninstall(rq.args.path)
        else
            fail("Uknown packages command")
        end
    else
        fail("Uknown request")
    end
end

function SystemController:settings(...)
    auth_or_die("User unauthorized. Please login")
    local user = SESSION.user
    if user then
        local ospath = require("vfs").ospath("home:///", user)
        if REQUEST and REQUEST.json then
            local file_path = ospath .. "/" .. ".settings.json"
            local f = io.open(file_path, "w")
            if f then
                f:write(REQUEST.json)
                f:close()
                -- TODO: maybe use ulib
                os.execute("chmod o-r "..file_path)
                result(true)
            else
                fail("Cannot save setting")
            end
        else
            fail("No setting founds")
        end
    else
        fail("User not found")
    end
end

function SystemController:application(...)
    auth_or_die("User unauthorized. Please login")
    local rq = nil
    if REQUEST.json ~= nil then
        rq = (JSON.decodeString(REQUEST.json))
    else
        rq = REQUEST
    end

    if rq.path ~= nil then
        local pkg = require("vfs").ospath(rq.path)
        if pkg == nil then
            pkg = WWW_ROOT .. "/packages/" .. rq.path
        --die("unkown request path:"..rq.path)
        end
        pkg = pkg .. "/api.lua"
        if ulib.exists(pkg) then
            dofile(pkg).exec(rq.method, rq.arguments)
        else
            fail("Uknown  application handler: " .. pkg)
        end
    else
        fail("Uknown request")
    end
end

function SystemController:apigateway(...)
    local args={...}
    local use_ws = false
    if REQUEST and REQUEST.ws == "1" then
        -- override the global cout command
        cout = std.ws.t
        echo = std.ws.t
        use_ws = true
    else
        cout = function(e)
            std.json()
            echo(e)
        end
    --    std.json()
    end
    local exec_with_user_priv = function(data)
        local uid = ulib.uid(SESSION.user)
        if not ulib.setgid(uid.gid) or not ulib.setuid(uid.id) then
            cout("Cannot set permission to execute the code")
            return
        end
        local r, e
        e = "{'error': 'Unknow function'}"
        -- set env var
        local home = ulib.home_dir(uid.id)
        ulib.setenv("USER", SESSION.user, 1)
        ulib.setenv("LOGNAME", SESSION.user, 1)
        if home then
            ulib.setenv("HOME", home, 1)
            ulib.setenv("PWD", home,1)
            local paths = ""
            if ulib.exists(home.."/bin") then
                paths = home.."/bin:"
            end
            if ulib.exists(home.."/.local/bin") then
                paths = paths..home.."/.local/bin:"
            end
            --local envar = ulib.getenv("PATH")
            --if envar then
            --    paths = paths..envar
            --end
            paths = paths.."/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/bin"
            ulib.setenv("PATH", paths,1)
        end
        -- run the code as user
        if data.code then
            r, e = load(data.code)
            if r then
                local status, result = pcall(r)
                if result then
                    if (status) then
                        cout(JSON.encode(result))
                    else
                        cout(result)
                    end
                end
            else
                cout(e)
            end
        elseif data.path then
            local ospath = require("vfs").ospath(data.path)
            r, e = loadfile(ospath)
            if r then
                local status, result = pcall(r, data.parameters)
                if result then
                    if (status) then
                        cout(JSON.encode(result))
                    else
                        cout(result)
                    end
                end
            else
                cout(e)
            end
        else
            cout(e)
        end
    end

    if (is_auth()) then
        local pid = ulib.fork()--std.pfork(HTTP_REQUEST.id)
        if (pid == -1) then
            cout("{'error':'Cannot create process'}")
        elseif pid > 0 then -- parent
            -- wait for the child exit or websocket exit
            ulib.waitpid(pid, 0)
            --ulib.kill(pid)
            LOG_INFO("Parent exit")
        else -- child
            if use_ws then
                if std.ws.enable() then
                    -- read header
                    local header = std.ws.header()
                    if header then
                        if header.mask == 0 then
                            LOG_WARN("Web socket Data is not masked")
                            std.ws.close(1012)
                        elseif header.opcode == std.ws.CLOSE then
                            LOG_DEBUG("Websocket Connection closed")
                            -- std.ws.close(1000)
                        elseif header.opcode == std.ws.TEXT then
                            -- read the file
                            local data = std.ws.read(header)
                            if data then
                                data = (JSON.decodeString(tostring(data)))
                                exec_with_user_priv(data)
                                std.ws.close(1011)
                            else
                                print("Error: Invalid  request")
                                std.ws.close(1011)
                            end
                        end
                    else
                        std.ws.close(1011)
                    end
                else
                    fail("Web socket is not available.")
                end
            else
                if REQUEST.path then
                    exec_with_user_priv(REQUEST)
                elseif REQUEST.json then
                    data = JSON.decodeString(REQUEST.json)
                    exec_with_user_priv(data)
                elseif args and #args > 0 then
                    -- data is encoded in url safe base64
                    local encoded = args[1]:gsub('_', '/'):gsub('-', '+')
                    if #encoded % 4 == 2 then
                        encoded = encoded.."=="
                    elseif #encoded %4 == 3 then
                        encoded = encoded.."="
                    end
                    local decoded = enc.b64decode(encoded)
                    data = JSON.decodeString(tostring(decoded))
                    if data and data.path then
                        exec_with_user_priv(data)
                    else
                        fail("Unknown request")
                    end
                else
                    fail("Unkown request")
                end
            end
            print("Child exit")
            ulib.kill(-1)
        end
    else
        cout('{"error":"User unauthorized. Please login"}')
    end
end
