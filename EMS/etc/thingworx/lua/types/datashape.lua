
require "json"

local base = _G
local pairs = base.pairs
local ipairs = base.ipairs
local unpack = base.unpack
local assert = base.assert
local table = base.table
local print = base.print
local log = base.log
local tw_mutex = base.tw_mutex
local tw_utils = base.tw_utils
local fmt = base.string.format
local p_data = base.p_data

-- The table of all defined data shapes
base.DataShape = {}

-- A table used for creating data shapes.
dataShapes = setmetatable({}, {__index = function(t, key)
  
  return function(...)
    local fields = {...}
    local first = fields[1] or {}
    local ds = tw_datashape.createDataShape(first.name, first.baseType, first.description, first.aspects)
    for i = 2,#fields do
      local field = fields[i]
      ds:addField(field.name, field.baseType, field.description, field.aspects)
    end
    tw_mutex.lock()
    base.DataShape[key] = ds
    tw_mutex.unlock()
    return ds
  end
end})
