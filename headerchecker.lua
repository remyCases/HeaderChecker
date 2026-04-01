-- Copyright (C) 2026 Rémy Cases
-- See LICENSE file for extended copyright information.
-- This file is part of HeaderChecker project from https://github.com/remyCases/HeaderChecker.

local extension_whitelist = {
    -- c#
    ["cs"] = "//",
    -- c
    ["c"] = "//",
    ["h"] = "//",
    -- python
    ["py"] = "#",
    -- lua
    ["lua"] = "--",
    -- nim
    ["nim"] = "#",
    -- rust
    ["rs"] = "//",
    -- gnucobol
    ["cob"] = "*>",
    -- zig
    ["zig"] = "//",
    -- asm
    ["s"] = "#",
}

local blacklist = {
    "obj", ".venv", "nimcache", "target", ".git", ".zig%-cache", "build"
}

local function is_blacklisted(path)
    for _, pattern in ipairs(blacklist) do
        if string.match(path, "[/\\]" .. pattern .. "[/\\]")
            or string.match(path, "^" .. pattern .. "[/\\]") then
            return true
        end
    end
    return false
end

local function correct_first_line(comment_format, line)
    return string.match(
        line,
        comment_format .. " Copyright %(C%) (%d*) Rémy Cases"
    ) ~= nil
end

local function correct_second_line(comment_format, line)
    return string.match(
        line,
        comment_format .. " See LICENSE file for extended copyright information."
    ) ~= nil
end

local function correct_third_line(comment_format, line)
    local project_name = string.match(
        line,
        comment_format .. " This file is part of (%w+) project from https://github.com/remyCases/%w+."
    )
    local project_url =  string.match(
        line,
        comment_format .. " This file is part of %w+ project from https://github.com/remyCases/(%w+)."
    )
    return project_name == project_url
end

local RED = "\27[31m"
local GREEN = "\27[32m"
local END = "\27[0m"
local search = ""
local absolute
local absolute_path

if arg[2] == "-s" then
    search = string.format("dir %s /b /s /a-d", arg[1])
    absolute = function (path)
        return path
    end
else
    search = string.format("dir %s /b /a-d", arg[1])
    absolute = function (path)
        return string.format("%s/%s", arg[1], path)
    end
end

for path in io.popen(search):lines() do
    local extension = string.match(path, "%.(%w*)$")
    local comment_format = extension_whitelist[extension]
    if not comment_format then
        goto next_file
    end
    absolute_path = absolute(path)

    if is_blacklisted(absolute_path) then
        goto next_file
    end

    local ctr = 0
    local check_shebang = false
    for line in io.lines(absolute_path) do

        if not check_shebang
            and extension == "lua"
            and string.match(line, "#!") then
            print("found shebang", line)
            check_shebang = true
            goto next_line
        end

        ctr = ctr + 1
        if ctr == 1 then
            if not correct_first_line(comment_format, line) then
                goto error_handling
            end
        elseif ctr==2 then
            if not correct_second_line(comment_format, line) then
                goto error_handling
            end
        elseif ctr==3 then
            if not correct_third_line(comment_format, line) then
                goto error_handling
            end
            break
        end
        ::next_line::
    end
    print(string.format(GREEN .. "%s".. END, absolute_path))
    ::next_file::
end
goto end_script

::error_handling::
print(string.format(RED .. "Invalid header for %s" .. END, absolute_path))
goto end_script

::end_script::