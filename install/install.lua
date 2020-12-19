local success, json = pcall(require, "json")
if not fs.exists("json.lua") then
    shell.run("wget https://raw.githubusercontent.com/rxi/json.lua/bee7ee3431133009a97257bde73da8a34e53c15c/json.lua json.lua")
     -- This JSON library seems to work extremely well
end

local json = require("json")


term.clear()
term.setCursorPos(1,1)
print("Downloading Opus...")
local start = os.epoch("utc")
local opusJsonHandle = http.get("https://raw.githubusercontent.com/Kan18/opus/develop-1.8/opus.json")
local opusJson = opusJsonHandle.readAll()
opusJsonHandle.close()
print("Downloaded " .. math.floor((#opusJson)/1000) .. "KB in " .. os.epoch("utc") - start .. "ms." )

print("Decoding JSON...")
local opus = json.decode(opusJson)

print("Making directories...")
for _i, directory in pairs(opus.directories) do 
    fs.makeDir(directory)
end

print("Writing files...")
for filename, source in pairs(opus.sources) do
    local handle = fs.open(filename, "w")
    handle.write(source)
    handle.close()
end
print("Done! Rebooting...")
os.reboot()