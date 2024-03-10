
-- the rewrite rule for the framework
-- should be something like this
-- ^\/apps\/+(.*)$ = /apps/router.lua?r=<1>&<query>
-- some global variables
package.path = _SERVER["LIB_DIR"].."/lua/?.lua"
require("silk.api")
-- crypto lib
enc = require("enc")
WWW_ROOT = __ROOT__.."/os"

-- add aditional paths
package.path = package.path..";"..WWW_ROOT .. '/libs/?.lua'
-- require needed library
require("common")

DIR_SEP = "/"
VFS_HOME = os.getenv("HOME_ROOT")
if not VFS_HOME then
    VFS_HOME="/home"
end

LOG_DEBUG("VFS_HOME=%s", VFS_HOME)

-- class path: path.to.class
CONTROLLER_ROOT = "os.controllers"
MODEL_ROOT = "os.models"
-- file path: path/to/file
VIEW_ROOT = WWW_ROOT..DIR_SEP.."views"

if HEADER.Host then
    HTTP_ROOT= "https://"..HEADER["Host"]
else
    HTTP_ROOT = "https://os.lxsang.me"
end

-- registry object store global variables
local REGISTRY = {}
-- set logging level
REGISTRY.logger = Logger:new{ level = Logger.INFO}
--REGISTRY.db = DBHelper:new{db="sysdb"}
REGISTRY.layout = 'default'
REGISTRY.fileaccess = true

--REGISTRY.db:open()
local router = Router:new{registry = REGISTRY}
REGISTRY.router = router
router:setPath(CONTROLLER_ROOT)

router:delegate()
--if REGISTRY.db then REGISTRY.db:close() end

