# Python 3 script for encoding all of Opus OS into a JSON file for quick installation
# TODO: minification, compression

import json
import os

sources = {}
directorieslist = []

def addFileToSources(filePath):
    with open(filePath, "r") as fileHandle:
        sources[filePath] = fileHandle.read()

# Manual adding for things not in sys folder that should be included
addFileToSources("startup.lua")
addFileToSources("LICENSE.md")

for root, directories, files in os.walk("sys"):
    for directory in directories:
        print(os.path.join(root, directory))
        directorieslist.append(os.path.join(root, directory))
    for file in files:
        print(os.path.join(root, file))
        addFileToSources(os.path.join(root, file))


with open("opus.json", "w") as fileHandle:
    fileHandle.write(json.dumps({"directories": directorieslist, "sources": sources}))

