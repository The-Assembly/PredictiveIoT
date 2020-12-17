
local base = _G
local p_data = base.p_data
local pairs = base.pairs
local string = base.string
local table = base.table
local json = base.json
local log = base.log
local type = base.type
local fmt = string.format
local DataShape = base.DataShape

--------------------------------------------------------------------------------
-- A Shape that allows a querying of the Thing's metadata
--------------------------------------------------------------------------------
module ("shapes.metadata")

properties = {}
services = {}
tasks = {}

local definedServiceDefinitions
local serviceDefinitions
--------------------------------------------------------------------------------
-- Returns the serviceDefinitions and definedServiceDefinitions tables used for the metadata
--         The serviceDefinitions table is a table of actual service definitions where the
--         definedServiceDefinitions is a table of the definitions to be used by the GetMetadata call
--
-- @param parent A reference to the template table
--
-- @return serviceDefinitions table, definedServiceDefinitions table (empty)
--
function init(parent)
	--Create metatable for allowing user to easily map service definition inputs,outputs, and description
    definedServiceDefinitions = definedServiceDefinitions or {}
    serviceDefinitions = serviceDefinitions or base.setmetatable({}, {
		__index = function(t, key)
			-- This is the function that is returned when an entry is looked up in the
			-- serviceDefinition table (assuming that entry isn't already there).
			-- When it is executed it iterates over all of its parameters and calls each one.
			-- Each of these functions should handle placing whatever they define into the
			-- 'definedServiceDefinitions' table.
			return function(...)
				for _,func in base.ipairs({...}) do
					--[[ code for debugging, left in because it is helpful in inderstanding what is happening
					local x = base.getfenv()
					log.debug("---<>---", str(x._NAME))
					for k,v in pairs(x) do
						log.debug("---<>---", "%s %s", k, v)
					end
					--]]
					base.setfenv(func, parent)
					func(key)
				end
			end
		end,
	})

  serviceDefinitions.GetMetadata(
    output { baseType="INFOTABLE", description="An Infotable describing this Edge Thing", aspects={dataShape="EMPTY"} },
    description { "Get the Metadata that describes this Edge Thing, including Property and Service definitions." },
    private { true }
  )

  return serviceDefinitions, definedServiceDefinitions
end

--------------------------------------------------------------------------------
-- Returns the metadata of a Thing (list of properties, services, and implemented shapes)
--
-- @param me A reference to the current Thing
-- @param headers The headers from the REST request invoking the service
-- @param query The query parameters from the REST request invoking the service
-- @param data Empty table
--
-- @return 200, "{properties:{},services:{},implementedShapes{},isSystemObject=false,type="Things",name="<name of thing>"}"
--
services.GetMetadata = function(me, headers, query, data)
	--Local create property function used to catch errors
	local function createProperty(pt)

        --Create the base property definition
        local property = {
            tags={},
            name        = pt.name,
            --sourceName  = me.name,
            sourceType  = "ThingShape",
            category    = "",
            baseType    = pt.init.baseType or "STRING",
            description = pt.init.description or "",
            aspects = {
                isPersistent        = false,
                dataChangeType      = pt.init.dataChangeType or "VALUE",
                isReadOnly          = false,
                dataChangeThreshold = pt.init.dataChangeThreshold or 0,
                cacheTime           = pt.init.cacheTime,
                pushType            = pt.init.pushType or "VALUE",
                pushThreshold       = pt.init.pushThreshold or 0,
                defaultValue        = pt.value,
                dataShape           = pt.dataShape
			},
            ordinal = 0,
            --uri = "/Thingworx/Things/" .. me.name .. "/Properties/" .. pt.name
        }
        
        if pt.dataShape then
            local ds = DataShape[pt.dataShape]:toTable()
            property.dataShape = {
                aspects = { dataShape = pt.dataShape },
                fieldDefinitions = ds.fieldDefinitions
            }
            property.aspects.defaultValue = nil
        else
            if pt.baseType == "INFOTABLE" and p_data.useShapes == false then
                property.dataShape = {
                    aspects = { dataShape = "None" },
                    fieldDefinitions = {}
            }
            property.aspects.defaultValue = nil
            end
        end
                
        return property
    end

	--Local create service function used to catch errors
	local function createService(name, serviceDefinition)
		--create the base service definition
		local service = {
			name=name,
			tags={},
			sourceType="Thing",
			category="",
			--sourceName=me.name,
			description="",
			--uri="/Thingworx/Things/"..me.name.."/Services/"..name,
			Inputs={
				tags={},
				description="",
				name="",
				fieldDefinitions={}
			},
			Outputs={
				tags={},
				description="",
				name="",
                baseType="",
				fieldDefinitions={}
			}
		}

		if(serviceDefinition.output.name) then
			--output name (default to "result")
			local outputName = "result"
			if(serviceDefinition.output.name) then outputName = serviceDefinition.output.name end
			--baseType (default to "NOTHING")
			local baseType = "NOTHING"
			if(serviceDefinition.output.baseType) then baseType = serviceDefinition.output.baseType end
			--description (default to "")
			local description = ""
			if(serviceDefinition.output.description) then description = serviceDefinition.output.description end

      service.Outputs.name = "result"
      service.Outputs.baseType = baseType

      if baseType == "INFOTABLE" then
        local dataShape = DataShape[serviceDefinition.output.aspects.dataShape]:toTable()
        service.Outputs.fieldDefinitions = dataShape.fieldDefinitions
        service.Outputs.aspects = serviceDefinition.output.aspects
      else
        service.Outputs.fieldDefinitions[serviceDefinition.output.name] = {}
        service.Outputs.fieldDefinitions[serviceDefinition.output.name].name = outputName
        service.Outputs.fieldDefinitions[serviceDefinition.output.name].baseType = baseType
        service.Outputs.fieldDefinitions[serviceDefinition.output.name].description = description
        service.Outputs.fieldDefinitions[serviceDefinition.output.name].ordinal=0
      end
    end

		if(serviceDefinition.inputs) then
			for t,r in pairs(serviceDefinition.inputs) do
				service.Inputs.fieldDefinitions[t] = {}
				local baseType = r.baseType or "STRING"
				local description = r.description or ""

        if baseType == "INFOTABLE" then
          local dataShape = DataShape[r.aspects.dataShape]:toTable()
          service.Inputs.fieldDefinitions[t].dataShape = {fieldDefinitions = dataShape.fields}
          service.Inputs.fieldDefinitions[t].baseType = baseType
          service.Inputs.fieldDefinitions[t].description = description
          service.Inputs.fieldDefinitions[t].name = t
          service.Inputs.fieldDefinitions[t].ordinal=0
          service.Inputs.fieldDefinitions[t].aspects = r.aspects
        else
          service.Inputs.fieldDefinitions[t].baseType = baseType
          service.Inputs.fieldDefinitions[t].description = description
          service.Inputs.fieldDefinitions[t].name = t
          service.Inputs.fieldDefinitions[t].ordinal=0
				end
			end
		end

		return service
	end

	local thingProps = {}
	local thingServices = {}
	local shapes = {}
	--Construct the properties
	for k,v in pairs(me.properties) do
		local privateProperty = false
		if (v.private) then
			local privateType = type(v.private)
			if (privateType == "string") then
				if (v.private:lower() == "true") then
					privateProperty = true
				end
			elseif (privateType == "boolean") then
				if (v.private == true) then
					privateProperty = true
				end
			end
		end

		if (privateProperty == false) then
			local status, property = base.pcall(createProperty, v)
			if(status) then
				thingProps[k] = property
			else
				log.error(me.name, "Error in property definition:  " .. k .. " - " .. property)
			end
		end
	end

	--Construct the services
	for k,v in pairs(me.definedServiceDefinitions) do
    if not v.private then
      local status, service = base.pcall(createService, k, v)
      if(status) then
        thingServices[k] = service
      else
        log.error(me.name, "Error in service definition:  " .. k .. " - " .. service)
      end
    end
	end

	--Construct the implementd shapes
	for name,t in pairs(base.package.loaded) do
		start,stop = name:find("shapes%.")
		if start == 1 then
			table.insert(shapes, string.sub(name, stop+1))
		end
	end

	--Create the result with the properties and services
	local desc = ""
	if(me.description) then desc=me.description end
	local result = {isSystemObject=false, description=desc, name=me.identifier or me.name, ["type"]="Things", propertyDefinitions=thingProps, serviceDefinitions=thingServices, implementedShapes=shapes}
	-- add this toJson function so that the result can be encoded by the core handler. Bit of a hack.
    result.toJson = function(self) return json.encode(self) end
    --Return the result as JSON
	return 200, result
end

--
-- The following three functions are used for service definition definitions
--

-- Function used for mapping a service definition input (can be multiple)
function input(inputTable)
	return function(svc_name)
		-- Inititalize the service definition if it hasn't been already
		definedServiceDefinitions[svc_name] = definedServiceDefinitions[svc_name] or { inputs = {}, output = {name = "result", baseType="NOTHING", description=""}, description = "" }

		--make sure there was a name for the input, otherwise, don't add it
		local name = inputTable.name
		if(name) then
			--set the defaults for the input (in case they were not passed in)
			definedServiceDefinitions[svc_name].inputs[name] = {baseType = "STRING", description=""}

			--set any properties based on the values in the table passed in
			if(inputTable.baseType) then
				definedServiceDefinitions[svc_name].inputs[name].baseType = inputTable.baseType
			end

			if(inputTable.description) then
				definedServiceDefinitions[svc_name].inputs[name].description = inputTable.description
			end

			if(inputTable.default) then
				definedServiceDefinitions[svc_name].inputs[name].default = inputTable.default
			end
			
			if (inputTable.aspects) then
		        definedServiceDefinitions[svc_name].inputs[name].aspects = inputTable.aspects
            end
        
            if inputTable.baseType == "INFOTABLE" then
                if (not inputTable.aspects or not inputTable.aspects.dataShape) then
                    error(fmt("The service definition %s has an input type of INFOTABLE, but no data shape specified", svc_name))
                end
            end
		end
	end
end

-- Function used for defining a service definition output (can only have one)
function output(outputTable)
	return function(svc_name)
		-- Inititalize the service definition if it hasn't been already
		definedServiceDefinitions[svc_name] = definedServiceDefinitions[svc_name] or { inputs = {}, output = {name = "result", baseType="NOTHING", description=""}, description = "" }

		--set the defaults for the output (in case they were not passed in, name is always "result")
		definedServiceDefinitions[svc_name].output = {name="result", baseType="NOTHING", description=""}

		--set any propertes based on the values in the table passed in
		if(outputTable.baseType) then
			definedServiceDefinitions[svc_name].output.baseType = outputTable.baseType
		end
		if(outputTable.description) then
			definedServiceDefinitions[svc_name].output.description = outputTable.description
		end
		if (outputTable.aspects) then
		    definedServiceDefinitions[svc_name].output.aspects = outputTable.aspects
        end
        
        if outputTable.baseType == "INFOTABLE" then
            if (not outputTable.aspects or not outputTable.aspects.dataShape) then
                error(fmt("The service definition %s has an output type of INFOTABLE, but no data shape specified", svc_name))
            end
        end
	end
end

-- Function used for defining the defintion of a service definition (can only have one)
function description(descTable)
	return function(svc_name)
		-- Inititalize the service definition if it hasn't been already
		definedServiceDefinitions[svc_name] = definedServiceDefinitions[svc_name] or { inputs = {}, output = {name = "result", baseType="NOTHING", description=""}, description = "" }
		-- Add the description (if one was passed in)
		if(#descTable > 0) then
			definedServiceDefinitions[svc_name].description = descTable[1]
		end
	end
end

function private(isPriv)
	return function(svc_name)
		-- Inititalize the service definition if it hasn't been already
		definedServiceDefinitions[svc_name] = definedServiceDefinitions[svc_name] or { inputs = {}, output = {name = "result", baseType="NOTHING", description=""}, description = "" }
		-- Add the description (if one was passed in)
		if isPriv then
			definedServiceDefinitions[svc_name].private = true
		end
	end
end
