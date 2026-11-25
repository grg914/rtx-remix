# Painkiller RTX — experimental performance branch

Target: GOG Painkiller RTX, Ryzen 7 9700X, RTX 5060 Ti 16 GB; 3840x2160 DLSS Performance, no Frame Generation. No changes to texture resolution, sampling rate, light bounces or scene assets.

## Source baseline

This repository is a superproject, not the renderer. The DXVK submodule is pinned to the installed Painkiller-specific revision `24af3f49cfd326e7d79de84632dfb07809ae286a`. The toolkit pin remains unchanged. The previous DXVK pin `0a6cd5b1ee814ec390c358e0c9c32ece8895ddc0` diverges from the PK build (152 ahead, 91 behind at comparison time); do not deploy its generic binaries over GOG's custom runtime.

The PK changelog confirms GPU skinning and the shared-BLAS preserve-path optimization already exist. Keep `rtx.skinningMaxCpuVertices = 0` and the original BLAS retention (600) initially.

## Backport 1: shader work elimination (experimental)

Source: [NVIDIA upstream commit 9919be38082c](https://github.com/NVIDIAGameWorks/dxvk-remix/commit/9919be38082c389033cf61a5710b13b8e8ab2684). This is a selective backport, not a full cherry-pick. All eight old hunk contexts across five files were found in the pinned PK source by static text comparison. No actual git apply, build or GPU benchmark was run when preparing this branch.

- Light shaping: avoid computing a power when the focus exponent is disabled.
- Alpha blend: avoid redundant neighbor geometry reads and neighbor searches when disabled.
- Ray Reconstruction: only read secondary albedo and roughness when a secondary surface exists.
- Skinning: accumulate the remainder weight while reading the existing weights rather than in a separate pass.
- Texture sampling: use exp2 for base-two LOD bias (same mathematical expression; floating-point rounding can differ).

These are intended to preserve the rendered result; compiler behavior, numerical equivalence, temporal stability and performance must be validated. No claim of a measured FPS gain.

## Apply and build on Windows

Clone this branch in a new directory:
```powershell
git clone --branch painkiller-performance https://github.com/grg914/rtx-remix.git
cd rtx-remix
git submodule update --init --recursive dxvk-remix
.\painkiller\Apply-ShaderBackport.ps1
.\painkiller\Apply-ShaderBackport.ps1 -Apply
cd dxvk-remix
.\build_dxvk_all_ninja.ps1
```
Check the pinned renderer's README and dependency access if initialization or compilation fails. Build matched renderer and bridge binaries from the same tree; never overwrite the sole GOG installation. Use a separate test copy, keep the original runtime and dependency DLLs, and verify the build's startup log. To undo the local source patch from the superproject root: `git -C dxvk-remix apply -R ../painkiller/patches/0001-selective-shader-optimizations.patch`.

## Bridge tests (independent of shader patch)

The supplied installed bridge.conf contains only `exposeRemixApi = True`. Preserve this setting: the PK integration uses the Remix API.

Test the redundant setter suppression alone, then the shared heap alone. The profiles are examples for the installed bridge.conf, not defaults for all games. Restore the original file before switching profiles. Do not increase queue capacity without evidence of queue stalls. Do not enable dynamic buffer shared heap initially.

## Benchmark / acceptance gate

Use the original runtime first, then a clean build from the pinned source without patch, then the patched build. Keep settings, driver, level, camera, path, V-Sync and frame cap identical; disable FG. Warm up shader caches and repeat each 60-second capture three times. Measure FPS, median frametime, 1% low FPS, GPU Busy and VRAM using PresentMon/NVIDIA overlay. Test empty rooms, dense combat, alpha particles, animated enemies, reflective surfaces and level transitions. Compare screenshots and video for missing lights, ghosting, skinning, particle artifacts and texture sharpness. Reject regressions or changes that fail to produce repeatable gains. Compare the bridge profiles separately, not simultaneously with the patch.

## Later source candidates (not applied)

- [d3485031359e](https://github.com/NVIDIAGameWorks/dxvk-remix/commit/d3485031359ef12ea25776413b20ca9234fdd613): instance identification and cluster repair; conflicts in PK source and default repair cap may alter temporal quality. Not suitable for blind backport.
- [923c61528d5a](https://github.com/NVIDIAGameWorks/dxvk-remix/commit/923c61528d5a35f84c7669b3d3a5c671c4b09644): removes unused allocations with FG off; substantial dependencies on newer resource/shader architecture, defer.
- [e7cb9d2a0a4d](https://github.com/NVIDIAGameWorks/dxvk-remix/commit/e7cb9d2a0a4d3207edd2741e1f3db365e200c70d): removes unused NRD resources, but mixed with other architectural changes; isolate and test if GPU-bound.
- Other parts of 9919be38082c were excluded to avoid dependency/semantic risks. No changes to the PK light identity path.

This branch contains an actual patch to five renderer source files, stored in the parent repository because the renderer resides in an externally hosted Git submodule. It does not contain compiled DLLs.
