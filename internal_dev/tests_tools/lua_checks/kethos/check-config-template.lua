return {
    runtime = {
        version = "Lua 5.1",
        builtin = {
            basic = "disable",
            debug = "disable",
            io = "disable",
            math = "disable",
            os = "disable",
            package = "disable",
            string = "disable",
            table = "disable",
            utf8 = "disable",
        },
    },
    workspace = {
        library = {
            -- quoted placeholder tokens; run_luals_ketho.ps1 replaces each whole
            -- string (quotes included) with the real annotation path as a Lua string
            "__KETHO_CORE__",
            "__KETHO_FRAMEXML__",
        },
        ignoreDir = {
            ".vscode",
            "libs",
            "internal_dev/tests_tools/lua_checks/.lua-language-server",
            "internal_dev/tests_tools/lua_checks/.luals-check",
            "internal_dev/tests_tools/lua_checks/.luacheck-logs",
            "internal_dev/tests_tools/lua_checks/.luacheck-meta",
        },
    },
    diagnostics = {
        ignoredFiles = "Disable",
        globals = {
            "SlashCmdList",
            "ColorPickerFrame",
            "SOUNDKIT",
            "AddonCompartmentFrame",
            "BuffFrame",
            "DebuffFrame",
            "PanelTemplates_SetNumTabs",
            "PanelTemplates_UpdateTabs",
            "PanelTemplates_TabResize",
            "StaticPopupDialogs",
            "StaticPopup_Show",
            "PanelTemplates_SelectTab",
            "PanelTemplates_DeselectTab",
            "Settings",
            "STANDARD_TEXT_FONT",
            "PlayerFrame",
            "MinimalSliderWithSteppersMixin",
            "CreateMinimalSliderFormatter",
        },
        disable = {
            "assign-type-mismatch",
        },
        unusedLocalExclude = {
            "_*",
        },
    },
    type = {
        weakUnionCheck = true,
    },
}
