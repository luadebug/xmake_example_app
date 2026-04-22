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

-- Locate aui.toolbox binary. On macOS the AUI cmake build wraps every
-- executable in a MACOSX_BUNDLE, so the binary lives inside an .app bundle.
function _find_toolbox(aui_installdir)
  -- Linux / Windows
  local p = path.join(aui_installdir, "bin", "aui.toolbox")
  if os.isfile(p) then return p end

  p = path.join(aui_installdir, "bin", "aui.toolbox.exe")
  if os.isfile(p) then return p end

  -- macOS: cmake installs the .app bundle, so the real binary is inside it
  p = path.join(aui_installdir, "bin", "aui.toolbox.app", "Contents", "MacOS", "aui.toolbox")
  if os.isfile(p) then return p end

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

  local toolbox_path = _find_toolbox(aui_installdir)
  if not toolbox_path then
    raise("aui.toolbox not found. Checked bin/, bin/aui.toolbox.app/Contents/MacOS/, and PATH under " .. aui_installdir)
  end

  local assets_dir = path.join(path.absolute(target:scriptdir()), "assets")
  for _, file in ipairs(os.files(path.join(assets_dir, "**"))) do
    _pack_asset(assets_dir, file, toolbox_path)
  end

  target:add("files", path.join(_get_gen_path(), "**.cpp"))
end
