import("lib.detect.find_program")
import("core.project.config")

function _get_gen_path()
  return path.join(path.absolute(config.builddir()), ".gens", "aui")
end

function _get_aui_package(target)
  for _, pkg in pairs(target:pkgs()) do
    if pkg:name() == "aui" then
      return pkg
    end
  end
  return nil
end

-- Locate aui.toolbox binary. Checks the aui package bin dir first, then the
-- aui-toolbox package (needed on macOS where the cmake build omits the binary),
-- and finally falls back to PATH.
function _find_toolbox(aui_installdir, target)
  local p = path.join(aui_installdir, "bin", "aui.toolbox")
  if os.isfile(p) then return p end

  p = path.join(aui_installdir, "bin", "aui.toolbox.exe")
  if os.isfile(p) then return p end

  -- aui-toolbox is a separate package that builds the toolbox via xmake;
  -- required as a fallback when the aui cmake build does not install it.
  for _, pkg in pairs(target:pkgs()) do
    if pkg:name() == "aui-toolbox" then
      local suffix = is_host("windows") and ".exe" or ""
      p = path.join(pkg:installdir(), "bin", "aui.toolbox" .. suffix)
      if os.isfile(p) then return p end
    end
  end

  return find_program("aui.toolbox")
end

function _pack_asset(assets_dir, asset_path, toolbox_path)
  wprint("Using toolbox: " .. toolbox_path)
  os.execv(toolbox_path, {
    "pack",
    assets_dir,
    asset_path,
    path.join(_get_gen_path(), hash.sha256(asset_path) .. ".cpp")
  })
end

function assets(target)
  local aui_pkg = _get_aui_package(target)
  if not aui_pkg then
    raise("aui package not found in target")
  end

  local aui_installdir = aui_pkg:installdir()
  wprint("AUI package install directory: " .. aui_installdir)

  local toolbox_path = _find_toolbox(aui_installdir, target)
  if not toolbox_path then
    raise("aui.toolbox not found. Checked: "
      .. aui_installdir .. "/bin/, the aui-toolbox package, and PATH. "
      .. "Ensure add_requires('aui-toolbox 7.1.2') is in xmake.lua.")
  end

  local assets_dir = path.join(path.absolute(target:scriptdir()), "assets")
  for _, file in ipairs(os.files(path.join(assets_dir, "**"))) do
    _pack_asset(assets_dir, file, toolbox_path)
  end

  target:add("files", path.join(_get_gen_path(), "**.cpp"))
end
