-- Specify available build configurations
add_rules("mode.release", "mode.debug")

-- Specify compile commands output directory and LSP to analyze C++ code files and highlight IntelliSense
add_rules("plugin.compile_commands.autoupdate", {outputdir = ".vscode", lsp = "clangd"})

-- Specify C++ standard to use, as AUI uses C++20 by default
set_languages("c++20")

-- CI_PROJECT_VERSION
set_version("0.0.14")

-- Download aui package to use for targets later
add_requires("aui 7.1.2")

includes("xmake/aui_tests.lua")

target("example_app")
    set_kind("binary")
    -- Adjust AUI_PP_STRINGIZE(AUI_CMAKE_PROJECT_VERSION) value
    add_defines("AUI_CMAKE_PROJECT_VERSION=7.1.2")
    -- Add source code and headers to target
    add_files("src/*.cpp")
    add_headerfiles("src/*.h")
    -- Add AUI package to target while linking only required components
    add_packages("aui", {components = {"core", "image", "views", "xml"}})
    -- Resolve linking by grouping AUI components into link groups
    add_linkgroups("aui.views", "aui.xml", "aui.image", "aui.core", {whole = true})
    -- Pack assets before building the target
    on_prepare(function(target)
        import("xmake.aui", {alias = "aui"})
        aui.assets(target)
    end)
target_end()

aui.enable_tests("example_app")
