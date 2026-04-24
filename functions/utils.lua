local addon_name, addon = ...

-- Full recursive overwrite copy: every key in src is written into dest.
-- Use after table.wipe(dest) to restore a DB table from defaults.
function addon.deep_copy_into(src, dest)
    for k, v in pairs(src) do
        if type(v) == "table" then
            dest[k] = {}
            addon.deep_copy_into(v, dest[k])
        else
            dest[k] = v
        end
    end
end

-- Recursive fill-missing copy: only writes keys that are absent in dest.
-- Use to apply defaults onto an existing DB without overwriting user values.
function addon.apply_defaults(src, dest)
    for k, v in pairs(src) do
        if type(v) == "table" then
            dest[k] = dest[k] or {}
            addon.apply_defaults(v, dest[k])
        else
            if dest[k] == nil then dest[k] = v end
        end
    end
end
