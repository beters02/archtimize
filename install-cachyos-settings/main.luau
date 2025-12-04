local fs = require("@lune/fs")
local move = {}

-- move files cross device (different mount points) if necessary
local function safeMove(from, to)
    local ok = pcall(function()
        fs.move(from, to)
    end)

    if not ok then
        print("Moving files cross-device. This usually happens when theres multiple partitions or mount points.")
        local data = fs.readFile(from)
        fs.writeFile(to, data)
        fs.removeFile(from)
    end
end

local function recurse(fromDir, toDir, v)
    local newFromDir = fromDir.."/"..v
    local newToDir = toDir.."/"..v
    if fs.isDir(newFromDir) then

        -- ensure all to directories exist
        if not fs.isDir(newToDir) then
            fs.writeDir(newToDir)
        end

        for i, v in pairs(fs.readDir(newFromDir)) do
            recurse(newFromDir, newToDir, v)
        end
        return
    end
    table.insert(move, {from = newFromDir, to = newToDir})
end

local function getMovePaths(folderName)
    for i, v in pairs(fs.readDir("../CachyOS-Settings/usr")) do
        local fromDir = "../CachyOS-Settings/"..folderName
        local toDir = "/"..folderName
        recurse(fromDir, toDir, v)
    end
end

getMovePaths("usr")
getMovePaths("etc")

for i, v in pairs(move) do
    if fs.isFile(v.to) then
        safeMove(v.to, v.to .. "_cos_backup") -- create a backup of the current setting file
    end
    safeMove(v.from, v.to)
end