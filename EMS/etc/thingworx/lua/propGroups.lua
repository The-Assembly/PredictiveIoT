--------------------------------------------------------------------
-- A package to handle property groups as they are requested
-- via a callback from the Palantiri Script Resource
--------------------------------------------------------------------
local base = _G
local p_data, ps_logger, ps_rap, ps_ext, ps_http, ps_dir, ps_utils, ps_script =
	  p_data, ps_logger, ps_rap, ps_ext, ps_http, ps_dir, ps_utils, ps_script

module("propGroups")

------------------------------------------------------------------
-- A utility funtion for handling groups or property requests.
-- Retrieves the current value of the parameters in the items group.
-- @param access_func The function used to access value of the item
-- @param items A table containing strings of the names of the items to 
--              retrieve.  The table may contain funcntions in the form
--              of sub-tables with the following format.
--              <pre>{ f="calulate_pct", "cpu.0.utilization", 100, }</pre>
--              where if is assumed to be a function in the p_data table
--              and the other table elements are parameters to pass to
--              the funciton.  Sring parameters are evaluated using the
--              access function before beign passed to function "f".
--       
--               A complete input table may look something like the following:
-- <pre>{ "memory.used", cpu_pct={ f="calulate_pct", "cpu.0.utilization", 100, }, disk_free="disk.0.free"}</pre>
--
-- @return A table with the results of calling access_func and evaluating
--         any inline functions.  Input table indicies are preserved.
--
function getGroup(access_func, items)
	if (base.type(items) ~= "table") then
		ps_logger.error("groups::getGroup", "parameter items not a table")
		return nil
	end
	-- Now we have a table, proceess each item, remebering that an item
	-- could be a function in the p_data table
	local result = {}
	for k,v in base.pairs(items) do
		-- Check if this is a function or not, it will start with p_data
		-- if it is a function call
		if (base.type(v) == "table") then
			-- this is a function so extract the function params
			local func = p_data[v.f]
			local temp = {}
			for k1, v1 in base.pairs(v) do
				-- if this is a number we leave it alone
				if k1 ~= "f" then 
					if (base.type(v1) == "number") then temp[k1] = v1 end
					-- if it is a string we try to access the value
					-- if that doesn't work we just pass the string to the func
					if (base.type(v1) == "string") then
						temp[k1] = access_func(v1) 	
						if temp[k1] == nil then temp[k1] = v1 end
					end
					ps_logger.debug("groups::getGroup", "Added " .. k1 .. "=" .. temp[k1] .. " to temp table")
				end
			end
			result[k] = func(base.unpack(temp))
		else
			-- this is a property
			result[k] = access_func(v)
		end
	end
	return result
end

