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

--- @type AUP
local AUP = package.loaded.AUP

local AUPCommand = AUP.module.Command

local pushd = AUP.pushd
local popd  = AUP.popd

local dbg = AUP.dbg

local PL = AUP.PL

local currentdir = PL.path.currentdir
local relpath = PL.path.relpath
local basename = PL.path.basename

local getdirectories = PL.dir.getdirectories
local makepath = PL.dir.makepath

local List = PL.List
--- @alias List {}

--- @alias StringsByString { string: string[] }

--- @class AUPUnits
--- @field uuid string
--- @field build_dir string
--- @field check fun(self: AUPUnits)
--- @field check_suite fun(self: AUPUnits, dir: string?, units: string[]?)
--- @field check_unit fun(self: AUPUnits, unit: string)
--- @field load fun(self: AUPUnits, name: string), class methods
--- @field test_setup fun(self: AUPUnits)
--- @field test fun(self: AUPUnits)
--- @field test_teardown fun(self: AUPUnits)
--- @field test_currentdir fun(self: AUPUnits, exclude: table?)
--- @field get_current_tmp_dir fun(self: AUPUnits): string
--- @field fail fun(self: AUPUnits, message: string)
--- @field print_failed fun(self: AUPUnits): integer
--- @field _failures List

local AUPUnits = PL.class.AUPUnits()

--- Initialize an `AUPUnits` instance
function AUPUnits:_init()
  local arguments = AUP.arguments
  assert(arguments, "Internal error")
  --self:super()   -- call the ancestor initializer if needed
  self.build_dir = assert(arguments.build_dir)
  self.uuid = assert(arguments.uuid)
  self._keep_tmp = false
  local engine_suites = {}
  local library_suites = {}
  local dev_suites = {}
  local units_by_engine_suite = {}
  local units_by_library_suite = {}
  local units_by_dev_suite = {}
  local current_suite = nil
  local current_units = {}
  local current_suites = library_suites
  local units_by_current_suite = units_by_library_suite
  local iterator = arguments:iterator()
  local entry = iterator:next()
  dbg:write(1, "**** Managing arguments")
  while(entry) do
    dbg:write(1, "entry.key:%s"%{entry.key})
    dbg:write(1, "entry.value:%s"%{entry.value})
    if entry.key == 'suite' then
      table.insert(current_suites, entry.value)
      if current_suite then
        -- If current_suite is nil, keep the actual current_units table
        -- otherwise create a new one
        units_by_current_suite[current_suite] = current_units
        current_units = {}
      end
      current_suite = entry.value
      dbg:printf(1, "suite: %s\n", current_suite)
      iterator:consume()
    elseif entry.key == 'unit' then
      table.insert(current_units, entry.value)
      dbg:printf(1, "suite: %s, unit: %s\n", current_suite, entry.value)
      iterator:consume()
    elseif entry.key == 'engine' then
      if current_suites ~= engine_suites then
        dbg:write(1, "mode: engine")
        if current_suite then
          units_by_current_suite[current_suite] = current_units
        end
        current_suites = engine_suites
        units_by_current_suite = units_by_engine_suite
        -- no reasonable default value for current_suite
        current_suite = nil
        current_units = {}
      end
      iterator:consume()
    elseif entry.key == 'library' then
      if current_suites ~= library_suites then
        dbg:write(1, "mode: library")
        if current_suite then
          units_by_current_suite[current_suite] = current_units
        end
        current_suites = library_suites
        units_by_current_suite = units_by_library_suite
        -- no reasonable default value for current_suite
        current_suite = nil
        current_units = {}
      end
      iterator:consume()
    elseif entry.key == 'dev' then
      if current_suites ~= dev_suites then
        dbg:write(1, "mode: dev")
        if current_suite then
          units_by_current_suite[current_suite] = current_units
        end
        current_suites = dev_suites
        units_by_current_suite = units_by_dev_suite
        -- no reasonable default value for current_suite
        current_suite = nil
        current_units = {}
      end
      iterator:consume()
    elseif entry.key == 'keep_tmp' then
      dbg:write(1, "keep tmp directory")
      self._keep_tmp = true
      iterator:consume()
    else
      dbg:write(1, "Unconsumed: %s->%s"%{entry.key, entry.value})
    end
    entry = iterator:next()
  end
  if current_suite then
    units_by_current_suite[current_suite] = current_units
    current_suite = nil
    current_units = nil
  end
  self._test_suites = {
    engine = engine_suites,
    library = library_suites,
    dev = dev_suites,
  }
  self._units_by_suite = {
    engine = units_by_engine_suite,
    library = units_by_library_suite,
    dev = units_by_dev_suite,
  }
  self._engine = {
    test_suites = self._test_suites.engine,
    units_by_suite = self._units_by_suite.engine,
  }
  self._library = {
    test_suites = self._test_suites.library,
    units_by_suite = self._units_by_suite.library,
  }
  self._dev = {
    test_suites = self._test_suites.dev,
    units_by_suite = self._units_by_suite.dev,
  }
  dbg:printf(10, "%s\n", self)
  dbg:write(10, self)
  self._cwd = currentdir()
  self._current_suite = nil
  self._current_unit = nil
  self._failures = List.new()
end

function AUPUnits:__tostring()
  local ans = PL.pretty.write (self)
  return 'AUPUnits: '..ans
end

--- Load a file in the current directory.
--- Class method.
--- @param self unknown
--- @param name string
function AUPUnits:load(name)
  local f = loadfile(name..'.lua')
  if f then
    if dbg:level_get()>1 then
      print("Loading "..(PL.path.abspath(name..'.lua')))
    else
      dbg:write(1,"Loading "..name..'.lua')
    end
    f()
  else
    dbg:write(1, "No "..name..'.lua')
  end
end

--- Load the `test_setup.lua` of the current directory, if any.
function AUPUnits:test_setup()
  print('Test setup for '..AUP:short_path())
  self:load('test_setup')
end

--- Load the `test.lua` of the current directory, if any.
function AUPUnits:test()
  print('Test for '..AUP:short_path())
  self:load('test')
end

--- Load the `test_teardown.lua` of the current directory, if any.
function AUPUnits:test_teardown()
  print('Test teardown for '..AUP:short_path())
  self:load('test_teardown')
end

--- Run all the tests
--- @param self AUPUnits
function AUPUnits:check()
  self:test_setup()
  for _,key in ipairs({'_library', '_engine', '_dev'}) do
    if pushd('test'.. key ..'/') then
      self:test_setup()
      local mode = self[key]
      if mode.test_suites then
        for _,suite in ipairs(mode.test_suites) do
          self:check_suite(suite, mode.units_by_suite[suite])
        end--for
        self:test_teardown()
      else
        self:test()
      end--mode.test_suites
      popd()
    end
  end-- for '_library', '_engine'
  self:test_teardown()
end

--- Run all the tests in the given directory
--- @param self AUPUnits
--- @param suite string|string[]?
--- @param units string[]?
function AUPUnits:check_suite(suite, units)
  if suite then
    if type(suite) == "table" then
      units = suite
      suite = "."
    end
  else
    suite = "."
  end
  if pushd(suite) then
    ---@diagnostic disable-next-line: inject-field
    self._current_suite = suite
    print('▶︎ Tests in directory: '..currentdir())
    self:test_setup()
    if units and #units > 0 then
      for _,unit in ipairs(units) do
        self:check_unit(unit)
      end
    else--if not units then
      self:test()
    end
    self:test_teardown()
    ---@diagnostic disable-next-line: inject-field
    self._current_suite = nil
    popd()
  else
    print('▶︎ No test for suite: "'..suite..'".')
  end
end

--- Run all the tests for the given unit.
--- `unit` is a folder in the current working directory.
--- @param self AUPUnits
--- @param unit string
function AUPUnits:check_unit(unit)
  if pushd(unit) then
    ---@diagnostic disable-next-line: inject-field
    self._current_unit = unit
    print('▶︎▶︎▶︎ Unit '..unit..':')
    self:test()
    ---@diagnostic disable-next-line: inject-field
    self._current_unit = nil
    popd()
  else
    print('▶︎▶︎▶︎ No test for unit "'..unit..'".')
  end
end

--- Run tests in the current working directory.
--- @param exclude table?
function AUPUnits:test_currentdir(exclude)
  local dirs = getdirectories()
  for _,p in ipairs(dirs) do
    local bn = basename(p)
    local list = List(exclude)
    if not list:contains(bn) then
      self:check_suite(bn)
    end
  end
end

--- Setup the overall temporary directory.
function AUPUnits:setup_tmp_dir()
  if self._tmp_dir==nil then
    -- create a temporary file
    local tmp_dir = PL.path.splitpath(PL.path.tmpname())
    self._tmp_dir = PL.path.join(tmp_dir, 'SyncTeX', self.uuid)
    makepath(self._tmp_dir)
  end
end

--- Teardown the overall temporary directory.
function AUPUnits:teardown_tmp_dir()
  if self._keep_tmp then
    print('Temporary directory: %s'%{self._tmp_dir})
  elseif self._tmp_dir~=nil then
    dbg:write(1, 'Removing directory ', self._tmp_dir)
    local status, error_msg = pcall(function() PL.dir.rmtree(self._tmp_dir) end)
    if not status then
      print('Could not complete action because of:')
      print(error_msg)
    end
  end
end

--- Run tests in the current working directory.
--- @return string
function AUPUnits:get_current_tmp_dir()
  local relative = relpath(currentdir(), self._cwd)
  self:setup_tmp_dir()
  local p = PL.path.join(self._tmp_dir, relative)
  makepath(p)
  return p
end

--- Declares a failure.
--- @param message string
function AUPUnits:fail(message)
  self._failures:append({
    suite = self._current_suite,
    unit = self._current_unit,
    message = message,
  })
end

--- Declares a failure.
--- @return integer
function AUPUnits:print_failed()
  if self._failures:len()>0 then
    print("FAIL:")
    for _,t in ipairs(self._failures) do
      local l = List.new()
      if t.suite then
        l:append("suite: "..t.suite)
      end
      if t.unit then
        l:append("unit: "..t.unit)
      end
      if t.message then
        l:append("message: "..t.message)
      end
      print("  "..l:concat("/"))
    end
  end
  return self._failures:len()
end

return {
  Units = AUPUnits
}