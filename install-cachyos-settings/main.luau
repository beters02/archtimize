local fs = require("@lune/fs")
local move = {}

local function recurse(fromDir, toDir, v)
    local newFromDir = fromDir.."/"..v
    local newToDir = toDir.."/"..v
    if fs.isDir(newFromDir) then

        -- ensure all directories exist
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
        fs.move(v.to, v.to .. "_cos_backup") -- create a backup of the current setting file
    end
    fs.move(v.from, v.to)
end