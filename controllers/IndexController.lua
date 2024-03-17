BaseController:subclass(
    "IndexController",
    {
        registry = {},
        models = {}
    }
)

function IndexController:actionnotfound(...)
    return self:index(table.unpack({...}))
end

function IndexController:index(...)
    html()
    std.f(WWW_ROOT..DIR_SEP.."index.html")
end

function IndexController:doc(...)
    local api = {
        author = "Xuan Sang LE",
        email = "xsang.le@gmail.com",
        api_name = "AntOS API",
        version = API_VERSION,
        documents = {
            vfs = HTTP_ROOT.."/VFS",
            user = HTTP_ROOT.."/user",
            system = HTTP_ROOT.."/system"
        }
    }
    result(api)
    return false
end