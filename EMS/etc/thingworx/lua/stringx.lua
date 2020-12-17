
require "tablex"
local base = _G
local type, pairs, error = type, pairs, error
local p_data, ps_logger, ps_rap, ps_ext, ps_http, ps_dir, ps_utils, ps_script =
	  p_data, ps_logger, ps_rap, ps_ext, ps_http, ps_dir, ps_utils, ps_script
local string, table = string, table

--------------------------------------------------------------------------------
-- This module extends the core Lua string library with some commonly used 
-- utility functions.
--
module("stringx")

------------------------------------------------------------------
-- Parses a delimiter separated string into tokens and returns 
-- them in a table.
--
-- @param s The string to parse.
-- @param delimiter The delimiter to split the string on.
--
-- @return A table with the individual string components and the 
--         number of elelments in the table.
------------------------------------------------------------------
function stringToTable(s, delimiter)
	local delim
	if s == nil then return nil end
	if (delimiter == nil) then 
		delim = "%S+" 
	else
		delim = "[^" .. delimiter .. "]+"
	end
	local temp = {}
	local x = 1
	for w in string.gmatch(s, delim) do
       temp[x] = w
	   x = x + 1
	end
	return temp, table.maxn(temp)
end

-----------------------------------------------------------------
-- @class function
-- @name split
-- @description An alias for stringToTable that is added to the 
--              core string library.
-- @param s The string to parse.
-- @param delimiter The delimiter to split the string on.
--
split = stringToTable
string.split = stringToTable
