--[==[
Copyright (c) 2024 jerome DOT laurens AT u-bourgogne DOT fr
This file is part of the __SyncTeX__ package testing framework.

## License
 
 Permission is hereby granted, free of charge, to any person
 obtaining a copy of this software and associated documentation
 files (the "Software"), to deal in the Software without
 restriction, including without limitation the rights to use,
 copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the
 Software is furnished to do so, subject to the following
 conditions:
 
 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 OTHER DEALINGS IN THE SOFTWARE
 
 Except as contained in this notice, the name of the copyright holder
 shall not be used in advertising or otherwise to promote the sale,
 use or other dealings in this Software without prior written
 authorization from the copyright holder.
 
--]==]

local match = string.match
local gsub = string.gsub
local format = string.format
local ipairs = ipairs

local separator = package.config:sub(1,1)
local lfs = package.loaded.lfs
local path_dir_auplib = lfs.currentdir() ..'/auplib/'
local kpathsea = package.loaded.kpse.new("kpsewhich")
local pl

do
  local already = false
  for _,v in ipairs(arg) do
    if v == "--local_penlight" then
    -- try the local distribution, if any
      already = true
      print('Local penlight distribution')
      package.path = path_dir_auplib.."lua_modules/share/lua/5.3/?.lua;"..package.path
      pcall(function ()
        pl = require('pl.import_into')()
      end)
      break
    end
  end
  if not pl then
    local p = kpathsea:find_file('penlight.lua')
    print('Penlight distribution at '..p)
    assert(p)
    local dir = match(p, "^(.*/)[^/"..separator.."]*/[^/"..separator.."]*$")
    package.path = dir.."?/?.lua;"..package.path
    local status, _ = pcall(function ()
      pl = require('penlight')
    end)
    -- final possibility: local distribution if not already tested before
    if not status and not already then
      package.path = path_dir_auplib.."lua_modules/share/lua/5.3/?.lua;"..package.path
      pl = require('pl.import_into')()
    end
  end
end
assert(pl)
package.path = path_dir_auplib.."?.lua;"..package.path
local raise = pl.utils.raise

---@class AUP
---@field _VERSION string
---@field _DESCRIPTION string
---@field module table
---@field dbg AUPDBG
---@field PL table
---@field short_path fun(self: AUP, p: string?)
---@field import_l3build fun(self: AUP, env: table)
---@field l3build_proxy AUPL3BuildProxy
---@field uuid fun(): string
---@field pushd fun(dir: string):boolean, string?
---@field popd fun():boolean, string?

local AUP = {
  _VERSION = '0.1',
  _DESCRIPTION = 'SyncTeX testing framework',
  module = {},
  PL = pl,
}
setmetatable(AUP, {
  -- lazy table
  __index = function(t, key)
    if key == "l3build_proxy" then
      local ans = t:import_l3build()
      t.l3build_proxy = ans
      return ans
    end
  end
})

setmetatable(AUP.module, {
  -- lazy table
  __index = function(t, key)
    print(key)
    local path = path_dir_auplib..'/aup_'..key..'.lua'
    print("path: "..AUP:short_path(path))
    local f, err = loadfile(path)
    if err then
      raise(err)
    end
    if not f then
      print(debug.traceback())
      error('Unknown AUP module '.. key)
    end
    local value = assert(f())
    t[key] = value
    package.loaded['auplib/'..key] = value
    return value
  end
})

-- from https://gist.github.com/jrus/3197011
local random = math.random
local randomseed = math.randomseed
local time = os.time
local clock = os.clock
---Build a uuid.
---@return string
function AUP.uuid()
  randomseed(tonumber(tostring(time()):reverse():sub(1, 9))+clock()*1000000)
  local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
  local ans = gsub(template, '[xy]', function (c)
    local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
    return format('%x', v)
  end)
  return ans
end

function AUP:import_l3build(env)
  local importer = self.module.l3build
  self.l3build_proxy = importer(env)
  self.import_l3build = function(e) end
end

local PL = AUP.PL
local path = PL.path
local List = PL.List
local currentdir = path.currentdir
local chdir = path.chdir
local relpath = path.relpath

local pushd_stack = List()

---Sort of command line pushd emulation.
---@param dir string
---@return boolean
---@return string?
function AUP.pushd(dir)
  local cwd = currentdir()
  local ans, err = chdir(dir)
  if ans then
    pushd_stack:append(cwd)
  end
  return ans, err
end

---Sort of command line popd emulation.
---@return boolean
---@return string
function AUP.popd()
  if not #pushd_stack then
    return false, "popd without a pushd"
  end
  return chdir(assert(pushd_stack:pop()))
end

AUP._cwd = currentdir()

---Return the argument relative to the initial current directory.
---This is used to keep some information private.
---This is not full proofed.
---@param p string?
---@return string
function AUP:short_path(p)
  p = p or currentdir()
  return List({'...', relpath(p, self._cwd)})
    :filter(function(x) return #x >0 end)
    :join('/')
end

package.loaded.auplib = AUP
package.loaded.AUP = AUP

AUP.dbg = AUP.module.dbg()

print("AUP loaded")
