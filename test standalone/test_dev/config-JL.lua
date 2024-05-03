--[[
Copyright (c) 2024 jerome DOT laurens AT u-bourgogne DOT fr
This file is a bridge to the __SyncTeX__ package testing framework.

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
 
--]]

--[=====[
If this file is not named `config-template.lua`,
it is an amended copy of the original `config-template.lua`,
renamed as `config-⟨mode⟩.lua`.
Here `⟨mode⟩` is a unique spaceless string identifier.
Usage

  meson test -C build --test-args " --dev_mode=⟨mode⟩"


The original file is tracked by the versioning system whereas the copies
are not.

A `config-defaults.lua` file is always loaded first, if it exists.
Only then `config-⟨mode⟩.lua` is loaded, of course when `⟨mode⟩` is provided.

Copies are meant to declare the setup for development of engines,
in particular where is located the `TeX` distribution and where are located
the binaries.

--]=====]

local AUP = package.loaded.AUP
local AUPCommand = AUP.module.Command
local AUPFmtUtil = AUP.module.FmtUtil

-- location of the reliable official binaries
AUPCommand.set_tex_bin_dir("/usr/local/texlive/2222/bin/universal-darwin")
-- location of the development binaries
AUPCommand.set_tex_dev_bin_dir("/Volumes/Users/GitHub/jlaurens/texlive-source/Work/texk/web2c")

AUPCommand.set_ENV(
  'TEXMFROOT', "/usr/local/texlive/2222",
  'TEXMFDIST', "/usr/local/texlive/2222/texmf-dist",
  'TEXMFCNF', "/usr/local/texlive/2222/texmf-dist/web2c",
  'TEXMFSYSVAR', "/usr/local/texlive/2222/texmf-var"
)