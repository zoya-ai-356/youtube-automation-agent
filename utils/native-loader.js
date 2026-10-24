const fs = require('fs');
const path = require('path');
const os = require('os');

// In environments where the project directory is on a noexec filesystem (such as Android /mnt/storage or /sdcard),
// dynamic linker fails to map native .node shared objects with PROT_EXEC.
// This transparent loader intercepts process.dlopen and copies the native addon to /tmp before loading.
(function setupNativeLoader() {
  if (global.__nativeLoaderInitialized) return;
  global.__nativeLoaderInitialized = true;

  const tmpDir = path.join(os.tmpdir(), 'node_native_cache');
  try {
    fs.mkdirSync(tmpDir, { recursive: true });
  } catch (err) {
    // Ignore if exists
  }

  // Pre-copy and prepare libvips for sharp if present
  try {
    const sharpLibvipsDir = path.join(__dirname, '..', 'node_modules', '@img', 'sharp-libvips-linux-arm64', 'lib');
    if (fs.existsSync(sharpLibvipsDir)) {
      const vipsFiles = fs.readdirSync(sharpLibvipsDir);
      for (const file of vipsFiles) {
        const src = path.join(sharpLibvipsDir, file);
        const dest = path.join(tmpDir, file);
        if (!fs.existsSync(dest) && fs.statSync(src).isFile()) {
          fs.copyFileSync(src, dest);
        }
      }
      const vipsTarget = path.join(tmpDir, 'libvips-cpp.so.8.17.3');
      if (fs.existsSync(vipsTarget)) {
        try {
          process.dlopen(module, vipsTarget, (os.constants.dlopen.RTLD_LAZY || 1) | (os.constants.dlopen.RTLD_GLOBAL || 256));
        } catch (_) {}
      }
    }
  } catch (_) {}

  const origDlopen = process.dlopen;
  process.dlopen = function (mod, filename, flags) {
    if (filename && (filename.startsWith('/mnt/') || filename.startsWith('/sdcard/') || filename.startsWith('/storage/'))) {
      const destFile = path.join(tmpDir, path.basename(filename));
      try {
        if (!fs.existsSync(destFile) || fs.statSync(destFile).size !== fs.statSync(filename).size) {
          fs.copyFileSync(filename, destFile);
        }
        if (flags !== undefined) {
          return origDlopen.call(this, mod, destFile, flags);
        }
        return origDlopen.call(this, mod, destFile);
      } catch (copyErr) {
        // Fallback to original if copy fails
      }
    }
    if (flags !== undefined) {
      return origDlopen.call(this, mod, filename, flags);
    }
    return origDlopen.call(this, mod, filename);
  };
})();
