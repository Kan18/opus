-- Install Opus OS

local jsonsuccess, json = pcall(require, "json")
if not jsonsuccess then
    shell.run("wget https://raw.githubusercontent.com/rxi/json.lua/bee7ee3431133009a97257bde73da8a34e53c15c/json.lua json.lua")
end

json = jsonsuccess and json or require("json")

term.clear()
term.setCursorPos(1,1)
print("Downloading Opus...")
local start = os.epoch("utc")
local opusJsonHandle = http.get("https://raw.githubusercontent.com/Kan18/opus/develop-1.8/install/opus.json")
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

print("Cleaning up...")
if not jsonsuccess then
    fs.delete("json.lua")
end

print("Done! Rebooting in 3 seconds (press Enter key to stop)...")
local stopped = false
parallel.waitForAny(
    function() 
        sleep(3) 
    end, 
    function() 
        read() 
        stopped = true
    end
)

print("Rebooting...")
if not stopped then
    os.reboot()
end