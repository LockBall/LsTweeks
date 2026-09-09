---@diagnostic disable: undefined-global

local product = assert(arg[1], "missing Ketho TACT product")
local expectedBranch = assert(arg[2], "missing managed Gethe branch")
local blizzardResources = assert(arg[3], "missing pinned BlizzardInterfaceResources path")

require("luasrc.config")

local pathlib = require("path")
local util = require("wowdoc")
local products = require("wowdoc.products")
local git = require("wowdoc.git")

function util:DownloadAndRun(url, path)
    local branch, fileName = url:match("Ketho/BlizzardInterfaceResources/([^/]+)/Resources/([^/]+%.lua)$")
    if branch then
        assert(branch == expectedBranch, "Ketho requested an unexpected BlizzardInterfaceResources branch")
        return assert(loadfile(pathlib.join(blizzardResources, fileName)))()
    end
    error("unexpected unpinned Ketho download: " .. url)
end

GETHE_BRANCH = products:GetBranch(product)
assert(GETHE_BRANCH == expectedBranch, "TACT product does not match the managed Gethe branch")

function git:checkout(url, branch)
    assert(url == "https://github.com/Gethe/wow-ui-source", "Ketho requested an unexpected source repository")
    assert(branch == expectedBranch, "Ketho requested an unexpected Gethe branch")
    print("Using the managed wow-ui-source checkout at " .. branch)
end

local loader = require("wowdoc.loader")
loader:main(product, true)

local literals = require("luasrc.annotate.literals")
util:WriteFileMeta(pathlib.join(ANNOTATIONS_DATA, "Event.lua"), literals:GetEventLiterals())
util:WriteFileMeta(pathlib.join(ANNOTATIONS_DATA, "CVar.lua"), literals:GetCVarLiterals())
util:WriteFileMeta(pathlib.join(ANNOTATIONS_DATA, "Enum.lua"), literals:GetEnumTable())

require("luasrc.annotate.prepend_meta")
