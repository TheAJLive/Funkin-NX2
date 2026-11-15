#!/usr/bin/env python3
"""Exercise the native touch sampler with synthetic SDL devices and fingers."""
import pathlib
import subprocess
import tempfile

root = pathlib.Path(__file__).resolve().parents[2]
source = (root / 'source/nx/controls/NXTouchControls.hx').read_text()
native = source.split("@:cppFileCode('", 1)[1].split("')", 1)[0]
with tempfile.TemporaryDirectory() as folder:
    directory = pathlib.Path(folder)
    (directory / 'SDL2').mkdir()
    (directory / 'SDL2/SDL.h').write_text('''
#include <vector>
using SDL_TouchID = int;
struct SDL_Finger { float x; };
static std::vector<std::vector<SDL_Finger>> devices;
static int SDL_GetNumTouchDevices() { return devices.size(); }
static SDL_TouchID SDL_GetTouchDevice(int i) { return i; }
static int SDL_GetNumTouchFingers(SDL_TouchID i) { return devices[i].size(); }
static SDL_Finger* SDL_GetTouchFinger(SDL_TouchID i, int j) { return &devices[i][j]; }
''')
    (directory / 'test.cpp').write_text(native + '''
#include <cassert>
int main() {
  assert(nx_touchLaneMask() == 0);
  devices = {{{0.0f}, {0.249f}}};
  assert(nx_touchLaneMask() == 1);
  devices = {{{0.25f}, {0.499f}}};
  assert(nx_touchLaneMask() == 2);
  devices = {{{0.5f}, {0.749f}}};
  assert(nx_touchLaneMask() == 4);
  devices = {{{0.75f}, {1.0f}}};
  assert(nx_touchLaneMask() == 8);
  devices = {{{0.1f}, {0.3f}, {0.6f}, {0.9f}}};
  assert(nx_touchLaneMask() == 15);
  devices = {{{0.1f}, {0.2f}}};
  assert(nx_touchLaneMask() == 1);
  devices[0].erase(devices[0].begin());
  assert(nx_touchLaneMask() == 1);
  devices[0].clear();
  assert(nx_touchLaneMask() == 0);
  devices = {{{0.1f}}, {{0.9f}}};
  assert(nx_touchLaneMask() == 9);
  devices = {{{-0.1f}, {1.1f}}};
  assert(nx_touchLaneMask() == 0);
}
''')
    subprocess.run(['g++', '-std=c++11', '-Wall', '-Wextra', '-Werror', '-I', folder,
                    str(directory / 'test.cpp'), '-o', str(directory / 'test')], check=True)
    subprocess.run([str(directory / 'test')], check=True)
print('Touch sampler: boundaries, chords, shared lanes, release, multiple devices and invalid coordinates passed.')
