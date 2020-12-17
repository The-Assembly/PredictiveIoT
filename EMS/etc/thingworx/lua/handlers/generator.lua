require "log"
require "tablex"
--require "json"

module("handlers.generator", thingworx.handler.extend)

cache = {}

function read(me, pt, headers, query)

    tw_utils.scopelock(function() -- mutex protect this entire read handler

	------------------------------------------------------------------------
	-- Validation
	------------------------------------------------------------------------
	--validate baseType, if it does not exist return an error
	local baseType = pt.baseType
	if(not baseType) then
		return 500, "Invalid or missing baseType specified for property:  "..pt.name
	end

	--validate functionType, if it does not exist, default it to user
	local functionType = "user"
	if (not pt.functionType) then
		log.warn("generator", "functionType not specified... setting to 'user'")
	else
		functionType = pt.functionType:lower()
	end

	------------------------------------------------------------------------
	-- Initialize cache (first time through only)
	------------------------------------------------------------------------
	if(not cache[pt.name]) then
		--default cache value, min, and max
		cache[pt.name] = {functionType=functionType, value=0, minValue=0, maxValue=100}

		local minValue = nil
		local maxValue = nil
		local initialValue = nil

		--Set min and max based on info set in the config
		if ((baseType == "NUMBER") or (baseType == "INTEGER")) then
			minValue = tonumber(pt.minValue)
			if (not minValue) then
				log.warn("generator", "minValue for property [%s] is invalid or not set, defaulting to 0", pt.name)
				minValue = 0
			end
			maxValue = tonumber(pt.maxValue)
			if (not maxValue) then
				log.warn("generator", "maxValue for property [%s] is invalid or not set, defaulting to 100", pt.name)
				maxValue = 100
			end

			initialValue = minValue
		elseif (baseType == "DATETIME") then
			-- Date pattern must be in the following format: yyyy-mm-dd hh:mm:ss
			local datePattern = "(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)"
			if (pt.maxValue) then
				local year,mon,day,hour,min,sec = pt.maxValue:match(datePattern)
				maxValue = os.time({year=year, month=mon, day=day, hour=hour, min=min, sec=sec})
				if (not maxValue) then
					log.warn("generator", "maxValue for property [%s] is invalid or not set (setting to now)", pt.name)
				end
			end
			if (not maxValue) then
				--set to current time if nothing is specified or an error occurred
				maxValue = os.time()
			end

			if (pt.minValue) then
				local year,mon,day,hour,min,sec = pt.minValue:match(datePattern)
				minValue = os.time({year=year, month=mon, day=day, hour=hour, min=min, sec=sec})
				if (not minValue) then
					log.warn("generator", "minValue for property [%s] is invalid or not set (setting to now minus 1 hour)", pt.name)
				end
			end
			if (not minValue) then
				--set to max time minus an hour if nothing is specified or an error occurred
				minValue = maxValue - 86400
			end

			initialValue = minValue * 1000
		elseif (baseType == "STRING") then
			initialValue = ""
		elseif (baseType == "LOCATION") then
			initialValue = { latitude=0, longitude=0, elevation=0 }
		elseif (functionType == "user") then
			if (not pt.value) then
				log.error("generator", "value for property [%s] is invalid or not set", pt.name)
			end
			initialValue = pt.value
		else
			return 500, "baseType ["..baseType.."] for property ["..pt.name.."] not supported"
		end

		cache[pt.name].minValue = minValue
		cache[pt.name].maxValue = maxValue
		cache[pt.name].value = initialValue
	end

	------------------------------------------------------------------------
	-- Perform calculations
	------------------------------------------------------------------------

	--set local min and max values based on cache
	local minValue = cache[pt.name].minValue
	local maxValue = cache[pt.name].maxValue

	--perform function (if user function, don't need the base type)
	if(functionType == "user") then
		--User set value, just set it if it changed
		if pt.next then
			pt.value = pt.next.value
			pt.time = pt.next.time
			pt.quality = pt.next.quality
			cache[pt.name].value = pt.value
		end
	else
		if((baseType == "NUMBER") or (baseType == "INTEGER")) then
			local val = tonumber(cache[pt.name].value) or minValue
			local step = tonumber(pt.step) or 1
			if(functionType == "ramp") then
				if(val < maxValue) then
					val = val + step
				else
					val = minValue
				end
				pt.value = val
				cache[pt.name].value = pt.value
			elseif(functionType == "random") then
				math.randomseed(os.time())
				val = math.random(minValue, maxValue)
				pt.value = math.random(minValue, maxValue)
				cache[pt.name].value = pt.value
			elseif(functionType == "sin") then
				if(val < maxValue) then
					val = val + step
				else
					val = minValue
				end
				local sinVal = math.sin(math.pi/180*val)
				pt.value = sinVal
				cache[pt.name].value = val
			elseif(functionType == "cos") then
				if(val < maxValue) then
					val = val + step
				else
					val = minValue
				end
				local cosVal = math.cos(math.pi/180*val)
				pt.value = cosVal
				cache[pt.name].value = val
			elseif(functionType == "square") then
				if(val > minValue) then
					val = minValue
				else
					val = maxValue
				end
				pt.value = val
				cache[pt.name].value = pt.value
			else
				return 500, "Unsupported function ["..functionType.."] for property ["..pt.name.."]"
			end
		elseif(baseType == "STRING") then
				math.randomseed(os.time())
				if(functionType == "random") then
				--First generate random size from 1-100
				local length = tonumber(pt.step) or math.random(100)
				local stringVal = ""
				for i=1, length, 1 do
					--now random ascii character (32-126)
					local char = math.random(32,126)
					stringVal = stringVal..string.char(char)
				end
				pt.value = stringVal
				cache[pt.name].value = stringVal
			else
				return 500, "Unsupported function ["..functionType.."] for property ["..pt.name.."]"
			end
		elseif(baseType == "DATETIME") then
			local step = tonumber(pt.step) or 1
			if(functionType == "ramp") then
				local val = tonumber(cache[pt.name].value) / 1000
				if (val < maxValue) then
					val = val + step
				else
					val = minValue
				end
				pt.value = val * 1000
				cache[pt.name].value = val * 1000
			elseif(functionType == "random") then
				math.randomseed(os.time())
				local diff = math.abs(maxValue-minValue)
				--log.warn("generator", "Min: %s,   Max: %s,  Diff: %s", tostring(minValue), tostring(maxValue), tostring(diff))
				local val = 0
				local offset = math.random(1, diff)
				if (diff > 0) then
					val = minValue + offset
				else
					val = maxValue - offset
				end
				pt.value = val * 1000
				cache[pt.name].value = val * 1000
			else
				return 500, "Unsupported function ["..functionType.."] for property ["..pt.name.."]"
			end
    elseif(baseType == "LOCATION") then
      if(functionType == "ramp") then
        if(not pt.value.elevation) then
          pt.value.elevation = minValue
        elseif(pt.value.elevation < (maxValue or 8440)) then
				  pt.value.elevation = (pt.value.elevation or 0) + 1
				else
				  pt.value.elevation = minValue
				end
				cache[pt.name].value = pt.value
			elseif(functionType == "random") then
        pt.value.latitude  = math.random(-90, 90)
        pt.value.longitude = math.random(-180, 180)
        pt.value.elevation = math.random(0, 8840)
				cache[pt.name].value = pt.value
			else
				return 500, "Unsupported function ["..functionType.."] for property ["..pt.name.."]"
      end
		end
		--Set the time and quality
		pt.time = os.time() * 1000
		pt.quality = "GOOD"
		--If we want to simulate bad quality, check for it here
		if(pt.qualityPercent) then
			local qualityPercent = tonumber(pt.qualityPercent)
			local randomErrorPercent = math.random(1,100)
			if(randomErrorPercent > qualityPercent) then
				pt.quality = pt.errorQualityStatus
			end
		end
	end

	--always set next to nil, just in case it was set and it is not used
	pt.next = nil

    end) -- End of scopelock

	return 200
end

function write(me, pt, headers, query, data)

    tw_utils.scopelock(function()
        log.warn("generate:write", "BEGIN")
        pt.next = {
            value = data.value,
            time = os.time() * 1000,
            quality = data.quality or "GOOD"
        }
    end)

	return 200, "Success"
end
