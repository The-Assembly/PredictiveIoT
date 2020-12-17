------------------------------------------------------------------
-- fullCopy
-- Returns a fully populated copy of a table
--
-- Inputs -  original - the base table, this table and any sub-tables
--                         may have a combination of numeric and string indicies
--
-- Returns - a table containing a one for one copy of the original
------------------------------------------------------------------
table.fullCopy = function(original)
	local lookup_table = {}
	local function _copy(object)
		if type(object) ~= "table" then
			return object
		elseif lookup_table[object] then
			return lookup_table[object]
		end
		local new_table = {}
		lookup_table[object] = new_table
		for index, value in pairs(object) do
			new_table[_copy(index)] = _copy(value)
		end
		return new_table
	end
	return _copy(original)
end

------------------------------------------------------------------
-- sparseCopy
-- Returns a sparsley populated copy of a table
--
-- Inputs -  original - the base table, this table and any sub-tables
--                         may have a combination of numeric and string indicies
--           branch -an array containing the branch of the table to traverse
--
-- Returns - a table containing only the elements of the original
--           table that are part of the specified branch, or nil
--           if the branch does not exist.  Also returns the type
--           of the leaf node.  All indicies in the
--           returned table are the same as those found in the
--           original table.
------------------------------------------------------------------
table.sparseCopy = function(original, branch)
	-- Check the inputs
	if (type(original) ~= "table") or (type(branch) ~= "table") then return nil end
	-- We need to make a copy so we don't screw up the original
	local copy = table.fullCopy(original)
	if type(copy) ~= "table" then
		ps_logger.debug("tablex::sparseCopy", "Error creating copy of original")
		return nil
	end
    -- Prune the table
	local temp = copy
	for i = 1, table.maxn(branch) do
		-- Any of these entries should be a table since we are stopping before the last
		-- path part
		ps_logger.debug("tablex::sparseCopy", "Checking for branch at " .. branch[i])
		-- Check this level of the table for a valid branch.  Remove all other branches
		if type(temp) == "table" then
			for k,v in pairs(temp) do
				if k ~= branch[i] and k ~= tonumber(branch[i]) then
					ps_logger.debug("tablex::sparseCopy", "Pruning branch " .. k)
					temp[k] = nil
				end
			end
		else
			-- We are at a leaf, so just return what we have
			ps_logger.debug("tablex::sparseCopy", "At a leaf: " .. branch[i])
			return copy, type(temp)
		end
		temp = temp[branch[i]] or temp[tonumber(branch[i])]
	end
	ps_logger.debug("tablex::sparseCopy", "Returning copy")
	return copy, type(temp)
end

------------------------------------------------------------------
-- containsKey
-- Returns the given table, if the table contains a specified
-- key.
--
-- Inputs - t - The table to examine.
--          k - The key to look for in t.
--
-- Returns - t, if t contains the key k. Nil otherwise.
------------------------------------------------------------------
table.containsKey = function(t, k)
    if not t then return nil end
    for key,_ in pairs(t) do
        if key == k then return t end
    end
    return nil
end

------------------------------------------------------------------
-- containsValue
-- Returns the given table, if the table contains a specified
-- value.
--
-- Inputs - t - The table to examine.
--          v - The value to look for in t.
--
-- Returns - t, if t contains the value v. Nil otherwise.
------------------------------------------------------------------
table.containsValue = function(t, v)
    if not t then return nil end
    for _,val in pairs(t) do
        if val == v then return t end
    end
    return nil
end

------------------------------------------------------------------
-- toXml
-- Returns an XML representation of a table
--
-- Inputs -  root - the name ot use for the doc root
--           t - the table to convert
--           indent -- the indention to use for sub-elements
--
-- Returns - a string with the XML data
------------------------------------------------------------------
table.toXml = function(root, t, indent)
    local out = ""
    local ind = ""
	root = root or "root"
    if indent then ind = indent .. "  " end
	local out = ""
	-- Check to see if this is a string or a number
	local term = root:sub(1, root:find("%s+"))
	if (type(t) == "number" or type(t) == "string" or type(t) == "boolean") then
		-- if we are just getting a single value (prefix == nil) just return the value
		out = out .. string.format("%s<%s>%s</%s>\n", ind, root, tostring(t), term)
    elseif type(t) == "table" then
		if #t == 0 then out = out .. string.format("%s<%s>\n", ind, root) end
        for k,v in orderedPairs(t) do
		  k_ = k
		  if type(k) == "number" then k_ = root .. ' id="' .. k .. '"' end
          out = out .. string.format("%s\n", table.toXml(k_, v, ind:sub(1,-2)))
        end
		if #t == 0 then out = out .. string.format("%s</%s>\n", ind, term) end
	elseif type(t) ~= "nil" then
        out = out .. string.format("%s<%s>%s</%s>\n", ind, root, type(t), term)
    end
	return out
end


------------------------------------------------------------------
-- toFlatTable
-- Flattens a table to contain only scalar values
--
-- Inputs -  t - the table to convert
--           out_t - the working output table
--           prefix -- a prefix to add for the keys (default = "")
--
-- Returns - a table with only string,boolena,number,nil values (no tables)
------------------------------------------------------------------
table.toFlatTable = function(t, out_t, prefix)
	if not out_t then out_t = {} end
	-- Check to see if this is a string or a number
	local type_t = type(t)
	if (type_t == "number" or type_t == "string" or type_t == "boolean") then
		-- if we are just getting a single value (prefix == nil) just return the value
		if prefix then out_t[tostring(prefix)] = t end
    elseif type_t == "table" then
		if (prefix ~= nil) then prefix = prefix .. "." else prefix = "" end
		if t[0] then zero_index = t[0] t[0] = nil end	-- If a table has a zero index ordered pairs will fail
        for k,v in orderedPairs(t) do
			local new_prefix = prefix .. tostring(k)
			out_t = table.toFlatTable(v, out_t, new_prefix)
        end
		t[0] = zero_index
	else
		out_t["ERROR"] = "Cannot covert " .. type(t) .. " types"
    end
	return out_t
end

------------------------------------------------------------------
-- toString
-- returns the contents of a table in a single CSV separated row
--
-- Inputs - t - the item to be formatted
--        - prefix - a prefix to prepend to the key name (defaults to "")
--        - leafType - not used.  For backward compatibility only
--        - query - may define the delimiter (default = "=").  Entries
--             that contain the delim are quotated
--
-- Returns - the formatted string.
------------------------------------------------------------------
table.toString = function(t, prefix, query)
	-- Flatten the table
	local flat = {}
	flat = table.toFlatTable(t, flat, prefix)
	-- Convert to a string
	local delim = "="
	if type(query) == "table" and query["delim"] then
		delim = query["delim"]
	end
	local result = ""
	for k,v in orderedPairs(flat) do
		-- Take care of any exisiting delims by quotating the string
		local key, value
		if string.find(tostring(k), delim) then
			key = string.format("\"%s\"", k)
		else
			key = tostring(k)
		end
		if string.find(tostring(v), delim) then
			value = string.format("\"%s\"", v)
		else
			value = tostring(v)
		end
		result = string.format("%s%s%s\n%s", key, delim, value, result)
	end
	return result
end

------------------------------------------------------------------
-- toHtml
-- returns the contents of a table in MTML format
-- scalar elements are converted to stings without links
-- subtable elements are converted to links
--
-- Inputs - t - the item to be formatted
--        - root - a root to prepend to the link(defaults to "")
--
-- Returns - the formatted string.
------------------------------------------------------------------
table.toHtml = function(t, root)
	-- Convert to HTML with links
	local result = "<table class='palantiriTable'>\n"
	if t[0] then -- If a table has a zero index ordered pairs will fail
		result = result .. "<tr class='palantiriRow'><td>"
		if type(t[0]) == "table" then
			result = result .. "<a href='".. root .. "/" .. 0 .. "'></td><td>" .. 0 .. "</a></td></tr>\n"
		else
			result = result .. "0</td><td>" .. t[0] or "nil" .. "</td></tr>\n"
		end
		t[0] = nil
	end
	for k,v in orderedPairs(t) do
		result = result .. "<tr class='palantiriRow'><td>"
		if type(v) == "table" then
			result = result .. "<a href='".. root .. "/" .. k .. "'>" .. k .. "</a></td></tr>\n"
		else
			result = result .. k .. "</td><td>" .. (v or "nil") .. "</td></tr>\n"
		end
	end
	result = result .. "</table>\n"
	return result
end
------------------------------------------------------------------

------------------------------------------------------------------
-- toCsv
-- returns the contents of a table in a single CSV separated row
--
-- Inputs - t - the item to be formatted
--        - prefix - a prefix to prepend to the key name (defaults to "")
--        - query - may have "headers" set to true if a header row should be included
--
-- Returns - the formatted string.
------------------------------------------------------------------
table.toCsv = function(t, prefix, query)
	-- Flatten the table
	local flat = {}
	flat = table.toFlatTable(t, flat, prefix)
	-- Convert to a single CSV row (or two rows if headers are desired)
	local header_row = ""
	local result = ""
	for k,v in orderedPairs(flat) do
		-- Take care of any exisiting commas by quotating the string
		if string.find(k,",") then
			header_row = string.format("\"%s\",%s", k, header_row)
		else
			header_row = string.format("%s,%s", k, header_row)
		end
		if string.find(tostring(v),",") then
			result = string.format("\"%s\", %s", v, result)
		else
			result = string.format("%s,%s", tostring(v), result)
		end
	end
	if type(query) == "table" and query["headers"] == true then result = string.format("%s\n%s", header_row, result) end
	return result
end
------------------------------------------------------------------
------------------------------------------------------------------
-- toContentTypeString
-- serializes a table/value in the requested contentType (text/plain, text/html, text/xml, text/csv)
--
-- Inputs - the item to formatted
--        - the desired contentType
--        - the type of the leaf of this table
--        - a prefix to prepend to the key name (defaults to "")
--        - query - the query string table.  Some formatting may
--             have additional parameters (e.g. headers, or delimiter)
--
-- Returns - the formatted string
------------------------------------------------------------------
function table.toContentTypeString(t, contentType, query, prefix, link_root)
	-- If content-type XML we pass that off to a different handler
	if (contentType == "text/xml") or (contentType == "application/xml") then
		return '<?xml version="1.0" encoding="UTF-8"?>\n' .. table.toXml(prefix, t)
	end
	if (contentType == "text/html") then return table.toHtml(t, link_root) end
	if (contentType == "text/csv") then return table.toCsv(t, prefix, query) end
	if (contentType == "text/x-lua-table") then return ps_utils.serializeTable(t) end
	if (contentType == "application/json") then
		-- To minimize dependencies only load the json library when first called
		-- it is possible to pass it in by hijacking the 'prefix' parameter
		if not table_to_json then table_to_json = prefix
			if not table_to_json then table_to_json = require("json") end
		end
		return table_to_json.encode(t)
	end
	return table.toString(t, prefix, query)
end
------------------------------------------------------------------
---------------------------------------------------------------------------------
-- Ordered table iterator, where f is the ordering function.  Default is ascending.
---------------------------------------------------------------------------------
function orderedPairs(t, f)
    local a = {}
    for n in pairs(t) do table.insert(a, n) end
    table.sort(a, f)
    local i = 0      -- iterator variable
    local iter = function ()   -- iterator function
	   i = i + 1
	   if a[i] == nil then return nil
	   else return a[i], t[a[i]]
	   end
    end
    return iter
end

------------------------------------------------------------------
-- fromCsv
-- Converts a CSV string to a table of tables.
-- Each row of the csv is converted to a table.
--
-- Inputs -  csv - a csv formatted string
--           useName - a number indicating which
--                     element to use a a name for
--                     the table entry.  Defaults to nil
--                     meaning the returned table is numrically
--                     indexed
--			 headerRow - if true, the first row is used as the
--                       names for the entries in the row tables
-- Returns - a table of tables, defaulting to both being numerically indexed
------------------------------------------------------------------
function table.fromCsv(csv, useName, headerRow)
    if type(csv) ~= "string" then return nil end
	useName = tonumber(useName)
	-- Convert each row to a table
	local temp = {}
	-- Do a little clean up of EOL
	csv = string.gsub(csv,"\r\n", "\n")
	for w in string.gmatch(csv, "[^\n]+") do
       table.insert(temp, w)
	end
	local names = {}
	local result = {}
	local row = 1
	for _,v in ipairs(temp) do
		local column = 0
		local key
		local line = v .. ','        -- ending comma
		local t = {}        -- table to collect fields
		local fieldstart = 1
		repeat
			 -- set our table key
			 column = column + 1
			 if headerRow == true and row > 1 then
			   key = result[1][column] or column
			 else
			   key = column
			 end
			-- next field is quoted? (start with `"'?)
			if string.find(line, '^"', fieldstart) then
			  local a, c
			  local i  = fieldstart
			  repeat
				-- find closing quote
				a, i, c = string.find(line, '"("?)', i+1)
			  until c ~= '"'    -- quote not followed by quote?
			  if not i then break end
			  local f = string.sub(line, fieldstart+1, i-1)
			  t[key] = string.gsub(f, '""', '"')
			  fieldstart = string.find(line, ',', i) + 1
			else                -- unquoted; find next comma
			  local nexti = string.find(line, ',', fieldstart)
			  t[key] = string.sub(line, fieldstart, nexti-1)
			  fieldstart = nexti + 1
			end
		until fieldstart > string.len(line)
		if useName and #t > 0 then result[tostring(t[useName])] = t
		else table.insert(result, t) end
		if headerRow == true and row == 1 then result[1] = t end
		row = row + 1
	end
	if headerRow == true then table.remove(result, 1) end
	return result
end
