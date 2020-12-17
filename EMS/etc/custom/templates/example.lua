
------------------------------------------------------------------------------
-- An example template, showing how to define properties, services,
-- and tasks.
------------------------------------------------------------------------------

-- ------------------------------------------------------------------------------------------------
-- The require statements pull a specified shape's functionality into the
-- template. A shape can define properties, services, and tasks, just like a
-- template. If the template defines a property, service, or task with the
-- same name as one defined in a shape, then the definition in the shape will
-- be ignored.  Therefore, you must take care not to define characteristics
-- with duplicate names.
--

-- require "yourshape"

-- ------------------------------------------------------------------------------------------------
-- This line is required in all user defined templates. 'template.example'
-- should be replaced with the name of template, for example: 'template.mydevice'.
--

module ("templates.example", thingworx.template.extend)

-- ------------------------------------------------------------------------------------------------
-- DataShapes describe the structure of an InfoTable. DataShapes that are declared can be used
-- as the input or out for services, or for generating strongly typed data structures. Each
-- DataShape is defined using a series or tables, each table representing the definition of 
-- a field within the DataShape. These fields must have a 'name' and a 'baseType'. They may
-- also include a 'description' and an 'ordinal', as well as an 'aspects' table that can provide
-- additional information, such as a defaultValue or a dataShape, if the field's baseType is an
-- InfoTable.

dataShapes.MeterReading(
  { name = "Temp", baseType = "INTEGER" },
  { name = "Amps", baseType = "NUMBER" },
  { name = "Status", baseType = "STRING", aspects = {defaultValue="Unknown"} },
  { name = "Readout", baseType = "TEXT" },
  { name = "Location", baseType = "LOCATION" }
)

dataShapes.PropertyInfoTable(
  { name = "Label", baseType = "STRING" },
  { name = "Value", baseType = "INTEGER" }
)

dataShapes.AllPropertyBaseTypes (
  { name = "Boolean", baseType = "BOOLEAN" },
  { name = "Datetime", baseType = "DATETIME" },
  { name = "GroupName", baseType = "GROUPNAME" },
  { name = "HTML", baseType = "HTML" },
  { name = "Hyperlink", baseType = "HYPERLINK" },
  { name = "Image", baseType = "IMAGE" },
  { name = "Imagelink", baseType = "IMAGELINK" },
  { name = "Integer", baseType = "INTEGER" },
  { name = "Json", baseType = "JSON" },
  { name = "Location", baseType = "LOCATION" },
  { name = "MashupName", baseType = "MASHUPNAME" },
  { name = "MenuName", baseType = "MENUNAME" },
  { name = "Number", baseType = "NUMBER" },
  { name = "Query", baseType = "QUERY" },
  { name = "String", baseType = "STRING" },
  { name = "Text", baseType = "TEXT" },
  { name = "ThingName", baseType = "THINGNAME" },
  { name = "UserName", baseType = "USERNAME" },
  { name = "XML", baseType = "XML" }
)

dataShapes.ExampleEvent(
  { name = "value", baseType = "STRING" },
  { name = "label", baseType = "STRING" },
  { name = "count", baseType = "INTEGER" },
  { name = "time",  baseType = "DATETIME" }
)

-- ------------------------------------------------------------------------------------------------
-- Properties are defined using Lua tables. The table format is as follows:
--     baseType: The ThingWorx base type for the property. Required.
--     dataChangeType: ALWAYS, VALUE, ON, OFF or NEVER. Provides a default value for the
--                     Data Change Type field of the property definition on the server, if the
--                     property is initially created using ThingWorx's Manage Bindings function.
--     dataChangeThreshold: Provides a default value for the Data Change Threshold field of the
--                          property definition on the server, if the property is initially
--                          created using ThingWorx's Manage Bindings function.
--     pushType: ALWYAS, VALUE, or NEVER. Each property in the properties table can be
--                     monitored, and on change its value can be pushed to the server. A
--                     pushType of ALWAYS or VALUE should be used if the property is to
--                     be pushed. Defaults to NEVER.
--     pushThreshold: For properties with a baseType of NUMBER and a pushType of VALUE, this
--                    attribute indicated how much a property must change by in order for it
--                    to be pushed to the server.
--     handler: The name of the handler to use for property reads/writes. The current set of
--              handler options are 'script', 'inmemory', 'http', 'https', or 'generator. The
--              default handler is 'inmemory'. The 'script', 'http', and 'https' handlers will
--              use the key field to determine the endpoint to execute their reads/writes on.
--     key: A key that the handler can use to look up or set the property's value. In the case
--          of a script, this is a URL path. For http or https handlers, this field should contain
--          a URL, not including the protocol. Not required for handers that are inmemory or nil.
--     value: The default value for the property. This will be updated as the property's value
--            changes during execution. Defaults to 0.
--     time: The last time, in milliseconds since the epoch, that the property was updated.
--           When Things are created from this template, this value will be automatically set to
--           the current time, unless a default is provided in the property definition.
--     quality: The quality of the property's value. A default should be provided if a default
--              value is defined. Otherwise it will default to GOOD for properties with no
--              handler, and UNKNOWN for properties with a handler.
--     scanRate: How frequently this property should be inspected for a change event.
--               Specified in milliseconds. The global default is 5000.
--     cacheTime: Used to initialize a property's cache time value at the server. This value
--                defaults to -1 for property's with a dataChangeType of NEVER, and 0 for
--                property's with a dataChangeType of ALWAYS or VALUE. If a different value
--                is specified it will be used by the server as the initial value and is only
--                applied when using the server's browse functionality to bind the property.
--
-- Note: Custom handlers can specify other property attributes. When a handler is utilized to
--       read or write a property, the entire property table is passed to the handler.
--

properties.InMemory_Boolean  =     { baseType="BOOLEAN",  pushType="NEVER", value=true }
properties.InMemory_Datetime =     { baseType="DATETIME", pushType="NEVER", value=os.time() * 1000 }
properties.InMemory_GroupName =    { baseType="GROUPNAME", pushType="NEVER", value="Administrators" }
properties.InMemory_HTML =         { baseType="HTML", pushType="NEVER", value="<html><body><h1>Default Value</h1></body></html>" }
properties.InMemory_Hyperlink =    { baseType="HYPERLINK", pushType="NEVER", value="http://www.thingworx.com" }
properties.InMemory_Image =        { baseType="IMAGE", pushType="NEVER", value="" }
properties.InMemory_Imagelink =    { baseType="IMAGELINK", pushType="NEVER", value="http://www.thingworx.com" }
properties.InMemory_InfoTable =    { baseType="INFOTABLE", pushType="NEVER", dataShape="AllPropertyBaseTypes" }
properties.InMemory_Integer =      { baseType="INTEGER", pushType="NEVER", value=1 }
properties.InMemory_Json =         { baseType="JSON", pushType="NEVER", value="{}" }
properties.InMemory_Large_String = { baseType="STRING", pushType="NEVER", value=string.rep("Lorem ipsum dolorsi ", 15000) .. "the end"  }
properties.InMemory_Location =     { baseType="LOCATION", pushType="NEVER", value = { latitude=40.03, longitude=-75.62, elevation=103 }, pushType="NEVER" }
properties.InMemory_MashupName =   { baseType="MASHUPNAME", pushType="NEVER", value="MashupName" }
properties.InMemory_MenuName =     { baseType="MENUNAME", pushType="NEVER", value="MenuName" }
properties.InMemory_Number =       { baseType="NUMBER", pushType="NEVER", value=1 }
properties.InMemory_Query =        { baseType="QUERY", pushType="NEVER", value="{}" }
properties.InMemory_String =       { baseType="STRING", pushType="NEVER", value="Default value 1" }
properties.InMemory_Text =         { baseType="TEXT", pushType="NEVER", value="Default value 1" }
properties.InMemory_ThingName =    { baseType="THINGNAME", pushType="NEVER", value="ThingName" }
properties.InMemory_UserName =     { baseType="USERNAME", pushType="NEVER", value="UserName" }
properties.InMemory_XML =          { baseType="XML", pushType="NEVER", value='<?xml version="1.0" encoding="utf-8" standalone="no"?><Root><Child>Test</Child></Root>' }

properties.Pushed_InMemory_Boolean  =   { baseType="BOOLEAN",  pushType="VALUE", value=false }
properties.Pushed_InMemory_Datetime =   { baseType="DATETIME", pushType="VALUE", value=os.time() * 1000 }
properties.Pushed_InMemory_GroupName =  { baseType="GROUPNAME", pushType="VALUE", value="Administrators" }
properties.Pushed_InMemory_HTML =       { baseType="HTML", pushType="VALUE", value="<html><body><h1>Default Value</h1></body></html>" }
properties.Pushed_InMemory_Hyperlink =  { baseType="HYPERLINK", pushType="VALUE", value="http://www.thingworx.com" }
properties.Pushed_InMemory_Image =      { baseType="IMAGE", pushType="VALUE", value="" }
properties.Pushed_InMemory_Imagelink =  { baseType="IMAGELINK", pushType="VALUE", value="http://www.thingworx.com" }
properties.Pushed_InMemory_InfoTable =  { baseType="INFOTABLE", pushType="VALUE", dataShape="AllPropertyBaseTypes" }
properties.Pushed_InMemory_Integer =    { baseType="INTEGER", pushType="VALUE", value=1 }
properties.Pushed_InMemory_Json =       { baseType="JSON", pushType="VALUE", value="{}" }
properties.Pushed_InMemory_Location =   { baseType="LOCATION", pushType="VALUE", value={ latitude=40.03, longitude=-75.62, elevation=103 }}
properties.Pushed_InMemory_MashupName = { baseType="MASHUPNAME", pushType="VALUE", value="MashupName" }
properties.Pushed_InMemory_MenuName =   { baseType="MENUNAME", pushType="VALUE", value="MenuName" }
properties.Pushed_InMemory_Number =     { baseType="NUMBER",   pushType="VALUE", value=2 }
properties.Pushed_InMemory_Query =      { baseType="QUERY", pushType="VALUE", value="{}" }
properties.Pushed_InMemory_String =     { baseType="STRING",   pushType="VALUE", value="Default value 2"}
properties.Pushed_InMemory_Text =       { baseType="TEXT", pushType="VALUE", value="Default value 1" }
properties.Pushed_InMemory_ThingName =  { baseType="THINGNAME", pushType="VALUE", value="ThingName" }
properties.Pushed_InMemory_UserName =   { baseType="USERNAME", pushType="VALUE", value="UserName" }
properties.Pushed_InMemory_XML =        { baseType="XML", pushType="VALUE", value='<?xml version="1.0" encoding="utf-8" standalone="no"?><Root><Child>Test</Child></Root>' }

properties.SAF_Client_Number = { baseType="NUMBER", pushType="VALUE", value=0 }
properties.SAF_Server_Number = { baseType="NUMBER", pushType="NEVER", value=0 }

properties.ValidationString =  { baseType="STRING",   pushType="VALUE", value="00000000"}

properties.AutoPush =  { baseType="INTEGER",   pushType="VALUE", handler="generator", functionType="ramp", minValue=0, maxValue=999999 }

properties.Incrementing_Number   = { baseType="NUMBER", value=0, handler="generator", functionType="ramp", minValue=10, maxValue=1000 }
properties.Incrementing_DateTime = { baseType="DATETIME", handler="generator", functionType="ramp", minValue="1999-4-1 4:00:00", maxValue="2002-1-17 8:00:00", step="86400" }

properties.Pushed_Incrementing_Number   = { baseType="NUMBER",   pushType="VALUE", handler="generator", functionType="ramp", minValue=1, maxValue=1000 }
properties.Pushed_Incrementing_DateTime = { baseType="DATETIME", pushType="VALUE", handler="generator", functionType="ramp", minValue="1999-4-1 4:00:00", maxValue="2002-1-17 8:00:00", step="86400" }
properties.Pushed_Incrementing_Location = { baseType="LOCATION", pushType="VALUE", handler="generator", functionType="ramp", minValue="0", maxValue="1000" }

properties.Random_String   = { baseType="STRING",   pushType="NEVER", handler="generator", functionType="random" }
properties.Random_Number   = { baseType="NUMBER",   pushType="NEVER", handler="generator", functionType="random", minValue=0, maxValue=100, qualityPercent=90, errorQualityStatus="BAD" }
properties.Random_DateTime = { baseType="DATETIME", pushType="NEVER", handler="generator", functionType="random", minValue="2012-11-10 7:00:00", maxValue="2012-11-10 8:00:00" }
properties.Random_Location = { baseType="LOCATION", pushType="NEVER", handler="generator", functionType="random" }

properties.Pushed_Random_String   = { baseType="STRING",   pushType="ALWAYS", handler="generator", functionType="random" }
properties.Pushed_Random_Number   = { baseType="NUMBER",   pushThreshold=50,  handler="generator", functionType="random", minValue=0, maxValue=100, qualityPercent=90, errorQualityStatus="BAD" }
properties.Pushed_Random_DateTime = { baseType="DATETIME", pushType="ALWAYS", handler="generator", functionType="random", minValue="2012-11-10 7:00:00", maxValue="2012-11-10 8:00:00" }
properties.Pushed_Random_Location = { baseType="LOCATION", pushType="ALWAYS", handler="generator", functionType="random" }

properties.Pushed_Sin_Number    = { baseType="NUMBER", pushType="ALWAYS", scanRate=p_data.scanRate or 1000,  handler="generator", functionType="sin",    minValue=0, maxValue=359 }
properties.Pushed_Cos_Number    = { baseType="NUMBER", pushType="ALWAYS", scanRate=p_data.scanRate or 5000,  handler="generator", functionType="cos",    minValue=0, maxValue=359 }
properties.Pushed_Square_Number = { baseType="NUMBER", pushType="ALWAYS", scanRate=p_data.scanRate or 10000, handler="generator", functionType="square", minValue=0, maxValue=100 }

--
-- Examples of Properties that access another script for their value.  Only the String property supports writes.
-- See the etc/custom/scripts/sample.lua script for an example of how to implement a script.
--
properties.Script_Number = { baseType="NUMBER", pushType="NEVER", handler="script", key="sample/property/number" }
properties.Script_String = { baseType="STRING", pushType="NEVER", handler="script", key="sample/property/string" }
properties.Script_Boolean = { baseType="BOOLEAN", pushType="NEVER", handler="script", key="sample/property/boolean" }
properties.Script_Datetime = { baseType="DATETIME", pushType="NEVER", handler="http", key="localhost:8001/scripts/sample/property/datetime" }
properties.Script_Location = { baseType="LOCATION", pushType="NEVER", handler="http", key="localhost:8001/scripts/sample/property/location" }

properties.Script_Pushed_Number = { baseType="NUMBER", pushType="ALWAYS", handler="script", key="sample/property/number" }
properties.Script_Pushed_String = { baseType="STRING", pushType="ALWAYS", handler="script", key="sample/property/string" }
properties.Script_Pushed_Boolean = { baseType="BOOLEAN", pushType="ALWAYS", handler="script", key="sample/property/boolean" }
properties.Script_Pushed_Datetime = { baseType="DATETIME", pushType="ALWAYS", handler="script", key="sample/property/datetime" }
properties.Script_Pushed_Location = { baseType="LOCATION", pushType="ALWAYS", handler="script", key="sample/property/location" }
--]]

-- ------------------------------------------------------------------------------------------------
-- Service definitions provide metadata about the defined services. This metadata is used when
-- browsing services from the ThingWorx server. The name of the service definition must match
-- the name of the service it is defining. Each service definition can contain the following
-- fields, each with their own set of definition parameters:
--
--    input: Describes an input parameter to the service. At runtime, each input parameter can
--           be looked up inside of the 'data' table passed into the service. The valid input
--           fields are: name, baseType, description
--    output: A description of the output produced by the service. Valid fields are: baseType
--            and description.
--    description: A description of the service
--

serviceDefinitions.ValidateString (
  input { name="value", baseType="STRING", description="String value to send" },
  output { baseType="STRING", description="" },
  description { "Validate String Push" }
)

serviceDefinitions.Add(
  input { name="p1", baseType="NUMBER", description="The first addend of the operation" },
  input { name="p2", baseType="NUMBER", description="The second addend of the operation" },
  output { baseType="NUMBER", description="The sum of the two parameters" },
  description { "Add two numbers" }
)

serviceDefinitions.Subtract(
  input { name="p1", baseType="NUMBER", description="The number to subtract from" },
  input { name="p2", baseType="NUMBER", description="The number to subtract from p1" },
  output { baseType="NUMBER", description="The difference of the two parameters" },
	description { "Subtract one number from another" }
)

serviceDefinitions.FireExampleEvent(
  input { name="value", baseType="STRING", description="String Data For the event" },
  output { baseType="NOTHING", description="" },
	description { "Fire the ExampleEvent" }
)

serviceDefinitions.WhatTimeIsIt(
  output { baseType="DATETIME", description="" },
	description { "Returns the current time" }
)

serviceDefinitions.WhereAmI(
  output { baseType="LOCATION", description="" },
	description { "Returns the current location" }
)

serviceDefinitions.DateDiff(
  input { name="date1", baseType="DATETIME", description="The time subtract from" },
  input { name="date2", baseType="DATETIME", description="The time to subtract from date1" },
  output { baseType="NUMBER", description="" },
	description { "Returns the difference of the two times" }
)

serviceDefinitions.StringRepeat(
  input { name="str", baseType="STRING", description="The string to repeat" },
  input { name="size", baseType="NUMBER", description="Size of the response, in KB" },
  output { baseType="STRING", description="A long string" },
	description { "A service that returns a long string" }
)

serviceDefinitions.GetMeterReading(
  output { baseType="INFOTABLE", description="The meter's current readings", aspects={dataShape="MeterReading"} },
  description { "Returns the meter's current readgins" }
)

-- ------------------------------------------------------------------------------------------------
-- The following services test all possible Base Types

serviceDefinitions.Push_Boolean (
  input { name="value", baseType="BOOLEAN", description="" },
  output { baseType="BOOLEAN", description="" },
  description { "Used to push a value to platform." }
)

serviceDefinitions.Push_Datetime (
  input { name="value", baseType="DATETIME", description="" },
  output { baseType="DATETIME", description="" },
  description { "Used to push a value to platform." }
)

serviceDefinitions.Push_GroupName (
  input { name="value", baseType="GROUPNAME", description="" },
  output { baseType="GROUPNAME", description="" },
  description { "Used to push a value to platform." }
)

serviceDefinitions.Push_HTML (
  input { name="value", baseType="HTML", description="" },
  output { baseType="HTML", description="" },
  description { "Used to push a value to platform." }
)

serviceDefinitions.Push_Hyperlink (
  input { name="value", baseType="HYPERLINK", description="" },
  output { baseType="HYPERLINK", description="" },
  description { "Used to push a value to platform." }
)

serviceDefinitions.Push_Image (
  input { name="value", baseType="IMAGE", description="" },
  output { baseType="IMAGE", description="" },
  description { "Used to push a value to platform." }
)

serviceDefinitions.Push_Imagelink (
  input { name="value", baseType="IMAGELINK", description="" },
  output { baseType="IMAGELINK", description="" },
  description { "Used to push a value to platform." }
)

serviceDefinitions.Push_InfoTable (
  input { name="value", baseType="INFOTABLE", description="", aspects={dataShape="AllPropertyBaseTypes" } },
  output { baseType="INFOTABLE", description="", aspects={dataShape="AllPropertyBaseTypes"} },
  description { "Used to push a value to platform." }
)

serviceDefinitions.Push_Integer (
  input { name="value", baseType="INTEGER", description="" },
  output { baseType="INTEGER", description="" },
  description { "Used to push a value to platform." }
)

serviceDefinitions.Push_Json (
  input { name="value", baseType="JSON", description="" },
  output { baseType="JSON", description="" },
  description { "Used to push a value to platform." }
)

serviceDefinitions.Push_Location (
  input { name="value", baseType="LOCATION", description="" },
  output { baseType="LOCATION", description="" },
  description { "Used to push a value to platform." }
)

serviceDefinitions.Push_MashupName (
  input { name="value", baseType="MASHUPNAME", description="" },
  output { baseType="MASHUPNAME", description="" },
  description { "Used to push a value to platform." }
)

serviceDefinitions.Push_MenuName (
  input { name="value", baseType="MENUNAME", description="" },
  output { baseType="MENUNAME", description="" },
  description { "Used to push a value to platform." }
)

serviceDefinitions.Push_Number (
  input { name="value", baseType="NUMBER", description="" },
  output { baseType="NUMBER", description="" },
  description { "Used to push a value to platform." }
)

serviceDefinitions.Push_String (
  input { name="value", baseType="STRING", description="" },
  output { baseType="STRING", description="" },
  description { "Used to push a value to platform." }
)

serviceDefinitions.Push_Query (
  input { name="value", baseType="QUERY", description="" },
  output { baseType="QUERY", description="" },
  description { "Used to push a value to platform." }
)

serviceDefinitions.Push_Text (
  input { name="value", baseType="TEXT", description="" },
  output { baseType="TEXT", description="" },
  description { "Used to push a value to platform." }
)

serviceDefinitions.Push_ThingName (
  input { name="value", baseType="THINGNAME", description="" },
  output { baseType="THINGNAME", description="" },
  description { "Used to push a value to platform." }
)

serviceDefinitions.Push_UserName (
  input { name="value", baseType="USERNAME", description="" },
  output { baseType="USERNAME", description="" },
  description { "Used to push a value to platform." }
)

serviceDefinitions.Push_XML (
  input { name="value", baseType="XML", description="" },
  output { baseType="XML", description="" },
  description { "Used to push a value to platform." }
)

serviceDefinitions.StartStoreAndForwardTest (
  input { name="delay", baseType="INTEGER", description="The number of seconds to wait before sending data" },
  input { name="count", baseType="INTEGER", description="The number of times to push" },
  output { baseType="INTEGER", description="Approximate duration of the test" }
)

serviceDefinitions.ServiceCallFromServer(
  input { name="stringData", baseType="STRING", description="String data" },
  input { name="integerData", baseType="INTEGER", description="Integer data" },
  output { baseType="NOTHING", description=""}
)

-- ------------------------------------------------------------------------------------------------
-- Services are defined as Lua functions. These can be executed remotely from the server and must
-- provide a valid response, via their return statement. The signature for the functions must be:
--   me: A table that refers to the Thing.
--   headers: A table of HTTP headers.
--   query: The query paramters from the HTTP request.
--   data: A Lua table containing the parameters to the service call.
--
-- A service must return the following values (in this order):
--   * A HTTP return code (200 for success)
--   * The response date, in the form of a JSON string. This can be created from a Lua table using
--     json.encode, or tw_utils.encodeData().
--

services.ValidateString = function(me, headers, query, data)
  if not data.value then
    return 400, "You must provide the 'value' parameter"
  end
  local count = string.sub(data.value, (string.len(data.value) - 7))
  log.force(me.name, "Incoming Value: "..count)
  me:setProperty("ValidationString", nil, nil, data)
  return 200, data.value
end

services.Add = function(me, headers, query, data)
  if not data.p1 or not data.p2 then
    return 400, "You must provide the parameters p1 and p2"
  end
  return 200, data.p1 + data.p2
end

services.Subtract = function(me, headers, query, data)
  if not data.p1 or not data.p2 then
    return 400, "You must provide the parameters p1 and p2"
  end
  return 200, data.p1 - data.p2
end

services.FireExampleEvent = function(me, headers, query, data)
  if not data.value then
    return 400, "You must provide the 'value' parameter."
  end
  me.example_event_count = (me.example_event_count or 0) + 1
  tw_mutex.lock()
  local ds = DataShape.ExampleEvent:clone()
  tw_mutex.unlock()
  local it = tw_infotable.createInfoTable(ds)
  local success, err = it:addRow({
    value = data.value,
    label = me.name,
    count = me.example_event_count,
    time = os.time() * 1000
  })
  
  if err then return 400, err end
  return server.fireEvent("ExampleEvent", it:toTable())
end

services.WhatTimeIsIt = function(me)
  return 200, os.time() * 1000
end

services.WhereAmI = function(me)
  return 200, { latitude = 40.033056, longitude = -75.627778, elevation = 338 }
end

services.DateDiff = function(me, headers, query, data)
  if not data.date1 or not data.date2 then
    return 400, "You must provide the parameters date1 and date2"
  end

  return 200, data.date1 - data.date2
end

services.StringRepeat = function(me, headers, query, data)
  if not data.size or not data.str then
    return 400, "You must provide the parameters 'str' and 'size'"
  end

  local resp = string.rep(data.str, data.size)

  return 200, resp
end

services.GetMeterReading = function(me, headers, query, data)
  tw_mutex.lock()
  local ds = DataShape.MeterReading:clone()
  tw_mutex.unlock()

  local it = tw_infotable.createInfoTable(ds)
  
  local success, err = it:addRow({
    Temp = 82,
    Amps = 15,
    Status = "Running",
    Readout = "Monitoring all systems",
    Location = { latitude = 43.156803, longitude = -77.607443, elevation = 505 }
  })
  
  if err then return 400, err end
  return 200, it
end

services.Push_Boolean = function(me, headers, query, data)
  if data.value == nil then  -- check for nil, not boolean, since data.value might == false
    return 400, "You must provide the 'value' parameter"
  end
  me:setProperty("Pushed_InMemory_Boolean", nil, nil, data)
  return 200, data.value
end

services.Push_Datetime = function(me, headers, query, data)
  if not data.value then
    return 400, "You must provide the 'value' parameter"
  end
  me:setProperty("Pushed_InMemory_Datetime", nil, nil, data)
  return 200, data.value
end

services.Push_GroupName = function(me, headers, query, data)
  if not data.value then
    return 400, "You must provide the 'value' parameter"
  end
  me:setProperty("Pushed_InMemory_GroupName", nil, nil, data)
  return 200, data.value
end

services.Push_HTML = function(me, headers, query, data)
  if not data.value then
    return 400, "You must provide the 'value' parameter"
  end
  me:setProperty("Pushed_InMemory_HTML", nil, nil, data)
  return 200, data.value
end

services.Push_Hyperlink = function(me, headers, query, data)
  if not data.value then
    return 400, "You must provide the 'value' parameter"
  end
  me:setProperty("Pushed_InMemory_Hyperlink", nil, nil, data)
  return 200, data.value
end

services.Push_Image = function(me, headers, query, data)
  if not data.value then
    return 400, "You must provide the 'value' parameter"
  end
  me:setProperty("Pushed_InMemory_Image", nil, nil, data)
  return 200, data.value
end

services.Push_Imagelink = function(me, headers, query, data)
  if not data.value then
    return 400, "You must provide the 'value' parameter"
  end
  me:setProperty("Pushed_InMemory_Imagelink", nil, nil, data)
  return 200, data.value
end

services.Push_InfoTable = function(me, headers, query, data)
  if not data.value then
    return 400, "You must provide the 'value' parameter"
  end
  
  local success, error
  
  -- Have to create an InfoTable for property that we want to set
  tw_mutex.lock()
  local ds = DataShape.AllPropertyBaseTypes:clone()
  tw_mutex.unlock()

  local propIt = tw_infotable.createInfoTable(ds)
  for _,row in pairs(data.value.rows) do
    success, err = propIt:addRow(row)
    if err then return 400, err end
  end
  
  -- Now, place the prop InfoTable into a container InfoTable
  
  local ds = tw_datashape.createDataShape("Pushed_InMemory_InfoTable", "INFOTABLE", nil, {dataShape="AllPropertyBaseTypes"})
  local it = tw_infotable.createInfoTable(ds)
  success, err = it:addRow({Pushed_InMemory_InfoTable = propIt})

  if err then return 400, err end

  me:setProperty("Pushed_InMemory_InfoTable", nil, nil, it:toTable())
  return 200, propIt
end

services.Push_Integer = function(me, headers, query, data)
  if not data.value then
    return 400, "You must provide the 'value' parameter"
  end
  me:setProperty("Pushed_InMemory_Integer", nil, nil, data)
  return 200, data.value
end

services.Push_Json = function(me, headers, query, data)
  if not data.value then
    return 400, "You must provide the 'value' parameter"
  end
  me:setProperty("Pushed_InMemory_Json", nil, nil, data)
  return 200, data.value
end

services.Push_Location = function(me, headers, query, data)
  if not data.value then
    return 400, "You must provide the 'value' parameter"
  end
  me:setProperty("Pushed_InMemory_Location", nil, nil, data)
  return 200, data.value
end

services.Push_MashupName = function(me, headers, query, data)
  if not data.value then
    return 400, "You must provide the 'value' parameter"
  end
  me:setProperty("Pushed_InMemory_MashupName", nil, nil, data)
  return 200, data.value
end

services.Push_MenuName = function(me, headers, query, data)
  if not data.value then
    return 400, "You must provide the 'value' parameter"
  end
  me:setProperty("Pushed_InMemory_MenuName", nil, nil, data)
  return 200, data.value
end

services.Push_Number = function(me, headers, query, data)
  if not data.value then
    return 400, "You must provide the 'value' parameter"
  end
  me:setProperty("Pushed_InMemory_Number", nil, nil, data)
  return 200, data.value
end

services.Push_String = function(me, headers, query, data)
  if not data.value then
    return 400, "You must provide the 'value' parameter"
  end
  me:setProperty("Pushed_InMemory_String", nil, nil, data)
  return 200, data.value
end

services.Push_Query = function(me, headers, query, data)
  if not data.value then
    return 400, "You must provide the 'value' parameter"
  end
  me:setProperty("Pushed_InMemory_Query", nil, nil, data)
  return 200, data.value
end

services.Push_Text = function(me, headers, query, data)
  if not data.value then
    return 400, "You must provide the 'value' parameter"
  end
  me:setProperty("Pushed_InMemory_Text", nil, nil, data)
  return 200, data.value
end

services.Push_ThingName = function(me, headers, query, data)
  if not data.value then
    return 400, "You must provide the 'value' parameter"
  end
  me:setProperty("Pushed_InMemory_ThingName", nil, nil, data)
  return 200, data.value
end

services.Push_UserName = function(me, headers, query, data)
  if not data.value then
    return 400, "You must provide the 'value' parameter"
  end
  me:setProperty("Pushed_InMemory_UserName", nil, nil, data)
  return 200, data.value
end

services.Push_XML = function(me, headers, query, data)
  if not data.value then
    return 400, "You must provide the 'value' parameter"
  end
  me:setProperty("Pushed_InMemory_XML", nil, nil, data)
  return 200, data.value
end

local testRunning = 0
local delay = 0
local messageCount = 0

services.StartStoreAndForwardTest = function(me, headers, query, data)
  if not data.delay then
    return 400, "You must provide the 'delay' parameter"
  end
  if not data.count then
    return 400, "You must provide the 'count' parameter"
  end
  delay = data.delay * 1000
  messageCount = data.count
  testRunning = 1
  return 200, data.delay + (data.count * (p_data.taskRate / 1000))
end

services.ServiceCallFromServer = function(me, headers, query, data)
  if not data.stringData then
    return 400, "You must provide the 'stringData' parameter"
  end
  if not data.integerData then
    return 400, "You must provide the 'integerData' parameter"
  end
  
  return 200
end
-- ------------------------------------------------------------------------------------------------
-- Tasks are Lua functions that are executed periodically by the ThingWorx Lua framework. They
-- can be used to execute background tasks, monitor resources, and fire events.
--

tasks.Compare = function(me)
  -- Do task
end

tasks.RunStoreAndForwardTest = function(me)
	if (testRunning > 0) then
		log.force(me.name, "Test is running")
		if(delay > 0) then
			delay = delay - p_data.taskRate
			log.force(me.name, "Remaining time: "..delay)
			if(delay <= 0) then
				delay = 0
			end
		elseif(delay == 0) then
			if(messageCount > 0) then
				log.force(me.name, "Send message #: "..messageCount)

				local ds = tw_datashape.createDataShape("Source", "STRING")
				ds:addField("Type", "STRING")
				ds:addField("StringData", "STRING")
				ds:addField("IntegerData", "INTEGER")
				local it = tw_infotable.createInfoTable(ds)
				it:addRow({Source = "Client", Type="Service", StringData="Test", IntegerData = messageCount})
				server.invoke("UpdateStoreAndForwardData", it)

				local data = {}
				data.value = messageCount
				me:setProperty("SAF_Client_Number", nil, nil, data)
				messageCount = messageCount - 1
			else
				log.force(me.name, "Test Complete!")
				testRunning = 0
				delay = 0
				messageCount = 0
			end
		end
	end
end

