import("lib.detect.find_program")
import("core.project.config")

function _get_gen_path()
  return path.join(path.absolute(config.builddir()), ".gens", "aui")
end

function _get_aui_package(target)
  -- Get the aui package from target
  for _, pkg in pairs(target:pkgs()) do
    if pkg:name() == "aui" then
      return pkg
    end
  end
  return nil
end

function _pack_asset(assets_dir, asset_path, aui_installdir)
  local toolbox_path = path.join(aui_installdir, "bin", "aui.toolbox")

  if not os.isfile(toolbox_path) then
    toolbox_path = path.join(aui_installdir, "bin", "aui.toolbox.exe")
  end

  if not os.isfile(toolbox_path) then
    toolbox_path = find_program("aui.toolbox")
  end

  wprint("Using toolbox: " .. toolbox_path)
  os.execv(toolbox_path, {
    "pack",
    assets_dir,
    asset_path,
    path.join(_get_gen_path(), hash.sha256(asset_path) .. ".cpp")
  })
end

function assets(target)
  -- Get aui package install directory
  local aui_pkg = _get_aui_package(target)
  if not aui_pkg then
    raise("aui package not found in target")
  end

  local aui_installdir = aui_pkg:installdir()
  wprint("AUI package install directory: " .. aui_installdir)
  local assets_dir = path.join(path.absolute(target:scriptdir()), "assets")
  for _, file in ipairs(os.files(path.join(assets_dir, "**"))) do
    _pack_asset(assets_dir, file, aui_installdir)
  end

  -- Add generated files to the target
  target:add("files", path.join(_get_gen_path(), "**.cpp"))
end

-- Defines aui_enable_tests(target_name).
-- Include in xmake.lua with:
--   includes("xmake/aui_tests.lua")
-- Then call after the main target definition:
--   aui_enable_tests("example_app")
--
-- Mirrors CMake aui_enable_tests():
--   - Creates a "Tests" binary target excluded from the default build
--   - Globs tests/**.cpp
--   - Generates a gmock main entry point
--   - For executable parents: copies their sources, includes, and defines
--   - For library parents: links against the parent target
--
-- Build with:  xmake build Tests
-- Run with:   xmake run Tests

function aui_enable_tests(parent_name)
    if not os.isdir("tests") then
        raise("aui_enable_tests: tests/ directory not found")
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

            -- Generate the gmock entry point (mirrors CMake's test_main_Tests.cpp)
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

            local parent = project.target(parent_name)
            if not parent then return end

            if parent:kind() == "binary" then
                -- Executable parent: pull its real sources directly into Tests so
                -- the same translation units are available without linking a binary.
                local added_dirs = {}
                for _, f in ipairs(parent:sourcefiles()) do
                    -- Skip generated files that have not been produced yet
                    if os.isfile(f) then
                        target:add("files", f)
                        -- Treat the source file's directory as an implicit include dir
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
                -- Library parent: link directly
                target:add("deps", parent_name)
            end
        end)
    target_end()
end
