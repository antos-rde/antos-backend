local model = {}

model.get = function(name, tbl, data)
    local mod = {
        name = tbl,
        db = DBModel:new{db = name}
    }
    function mod:close()
        self.db:close()
    end
    function mod:open()
        self.db:open()
    end
    function mod:createTable(m)
        return self.db:createTable(self.name,m)
    end
    function mod:insert(m)
        return self.db:insert(self.name,m)
    end
    function mod:get(id)
        return self.db:get(self.name, id)
    end
    function mod:getAll()
        return self.db:getAll(self.name)
    end
    function mod:find(cond)
        return self.db:find(self.name, cond)
    end
    function mod:update(m)
        return self.db:update(self.name, m)
    end
    function mod:available()
        return self.db:available(self.name)
    end
    function mod:delete(cond)
        return self.db:delete(self.name, cond)
    end
    function mod:deleteByID(id)
        return self.db:deleteByID(self.name, id)
    end
    mod:open()

    if mod:available() then return mod end
    if data == nil then return nil end
    local meta = {}
    --print(JSON.encode(data))
    for k,v in pairs(data) do
        if type(v) == "number" or type(v) == "boolean" then
            meta[k] = "NUMERIC"
        else
            meta[k] = "TEXT"
        end
    end
    mod:createTable(meta)
    return mod
end
return model