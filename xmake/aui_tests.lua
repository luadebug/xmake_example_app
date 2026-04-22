-- Loaded via includes("xmake/aui_tests.lua") at description phase.
-- Defines aui.enable_tests(parent_name) as a global table method.
--
-- aui here is a description-phase global table; it does not conflict with
-- the local aui imported inside on_prepare (which is a separate build-phase
-- module). The local import shadows this global only within that closure.
--
-- Build with:  xmake -b Tests
-- Run with:   xmake run Tests

aui = aui or {}

function aui.enable_tests(parent_name)
    if not os.isdir("tests") then
        raise("aui.enable_tests: tests/ directory not found")
    end

    add_requires("gtest", {system = false})

    target("Tests")
        set_kind("binary")
        set_default(false)
        set_languages("c++20")
        add_defines("AUI_TESTS_MODULE=1")
        add_files("tests/**.cpp")
        add_includedirs("tests")
        add_packages("gtest")
        add_packages("aui", {components = {"core", "image", "views", "xml"}})
        add_linkgroups("aui.views", "aui.xml", "aui.image", "aui.core", {whole = true})
        on_prepare(function(target)
            import("core.project.project")
            import("core.project.config")

            -- Workaround for clang-cl toolchain bug where /WHOLEARCHIVE is ignored in shared library linking
            if is_plat("windows") then
                import("core.tool.toolchain")
                local host_toolchain
                host_toolchain = toolchain.load("clang-cl", {plat = "windows", arch = os.arch()})
                if host_toolchain:check() then
                    target:add("ldflags", "/WHOLEARCHIVE:aui.views.lib", { force = true })
                    target:add("ldflags", "/WHOLEARCHIVE:aui.xml.lib", { force = true })
                    target:add("ldflags", "/WHOLEARCHIVE:aui.image.lib", { force = true })
                    target:add("ldflags", "/WHOLEARCHIVE:aui.core.lib", { force = true })
                    target:add("shflags", "/WHOLEARCHIVE:aui.views.lib", { force = true })
                    target:add("shflags", "/WHOLEARCHIVE:aui.xml.lib", { force = true })
                    target:add("shflags", "/WHOLEARCHIVE:aui.image.lib", { force = true })
                    target:add("shflags", "/WHOLEARCHIVE:aui.core.lib", { force = true })
                end
            end

            -- Generate the gmock entry point
            local gen_dir = path.join(path.absolute(config.builddir()), ".gens", "aui_tests")
            os.mkdir(gen_dir)
            local main_file = path.join(gen_dir, "test_main.cpp")
            io.writefile(main_file, [[
#include <gmock/gmock.h>

int main(int argc, char **argv) {
#ifdef __linux__
#ifdef AUI_CATCH_UNHANDLED
    extern void aui_init_signal_handler();
    aui_init_signal_handler();
#endif
#endif
    testing::InitGoogleMock(&argc, argv);
    return RUN_ALL_TESTS();
}
]])
            target:add("files", main_file)

            -- Mirror the parent target's real sources, include dirs, and defines
            local parent = project.target(parent_name)
            if not parent then return end

            if parent:kind() == "binary" then
                local added_dirs = {}
                for _, f in ipairs(parent:sourcefiles()) do
                    if os.isfile(f) then
                        target:add("files", f)
                        local d = path.directory(f)
                        if not added_dirs[d] then
                            added_dirs[d] = true
                            target:add("includedirs", d)
                        end
                    end
                end
                for _, d in ipairs(parent:get("includedirs") or {}) do
                    target:add("includedirs", d)
                end
                for _, def in ipairs(parent:get("defines") or {}) do
                    target:add("defines", def)
                end
            else
                target:add("deps", parent_name)
            end
        end)
    target_end()
end
