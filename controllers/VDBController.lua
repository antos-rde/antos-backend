BaseController:subclass(
    "VDBController",
    {
        registry = {},
        models = {}
    }
)

function VDBController:actionnotfound(...)
    return self:index(table.unpack({...}))
end

function VDBController:index(...)
    local api = {
        description = "This api handle database operation",
        actions = {
            ["/save"] = "Save a record to a table",
            ["/get"] = "Get all records or Get a record by id",
            ["/select"] = "Select records by a condition",
            ["/delete"] = "Delete record(s) by condition or by id"
        }
    }
    result(api)
    return false
end

function VDBController:save(...)
    auth_or_die("User unauthorized. Please login")
    local rq = (JSON.decodeString(REQUEST.json))
    if (rq ~= nil and rq.table ~= nil) then
        local model = require("dbmodel").get(SESSION.user, rq.table, rq.data)
        local ret
        if model == nil then
            fail("Cannot get table metadata:" .. rq.table)
        else
            if (rq.data.id ~= nil) then
                rq.data.id = tonumber(rq.data.id)
                ret = model:update(rq.data)
            else
                ret = model:insert(rq.data)
            end
            model:close()
            if ret == true then
                result(ret)
            else
                fail("Cannot modify/update table " .. rq.table)
            end
        end
    else
        fail("Unknown database request")
    end
    return false
end

function VDBController:get(...)
    auth_or_die("User unauthorized. Please login")
    local rq = (JSON.decodeString(REQUEST.json))
    if (rq ~= nil and rq.table ~= nil) then
        local model = require("dbmodel").get(SESSION.user, rq.table, nil)
        local ret
        if model == nil then
            fail("Cannot get table metadata:" .. rq.table)
        else
            if (rq.id == nil) then
                ret = model:getAll()
            else
                ret = model:get(rq.id)
            end
            model:close()
            result(ret)
        end
    else
        fail("Unknown database request")
    end
end

function VDBController:select(...)
    auth_or_die("User unauthorized. Please login")
    local rq = (JSON.decodeString(REQUEST.json))
    if (rq ~= nil and rq.table ~= nil) then
        local model = require("dbmodel").get(SESSION.user, rq.table, nil)
        local ret
        if model == nil then
            fail("Cannot get table metadata:" .. rq.table)
        else
            if (rq.cond == nil) then
                model:close()
                return fail("Unknow condition")
            else
                ret = model:find(rq.cond)
            end
            model:close()
            result(ret)
        end
    else
        fail("Unknown database request")
    end
end

function VDBController:delete(...)
    auth_or_die("User unauthorized. Please login")
    local rq = (JSON.decodeString(REQUEST.json))
    if (rq ~= nil and rq.table ~= nil) then
        local model = require("dbmodel").get(SESSION.user, rq.table, nil)
        local ret
        if model == nil then
            fail("Cannot get table metadata:" .. rq.table)
        else
            if (rq.id == nil) then
                if (rq.cond) then
                    ret = model:delete(rq.cond)
                    model:close()
                else
                    model:close()
                    return fail("Unknow element to delete")
                end
            else
                ret = model:deleteByID(rq.id)
                model:close()
            end
            if ret then
                result(ret)
            else
                fail("Querry error or database is locked")
            end
        end
    else
        fail("Unknown database request")
    end
end
