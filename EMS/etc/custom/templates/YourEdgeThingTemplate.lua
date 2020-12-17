module ("templates.YourEdgeThingTemplate", thingworx.template.extend)

properties.failure = {baseType="NUMBER", pushType = "ALWAYS", value=0}

properties.s1_fb1 = {baseType="NUMBER", pushType = "ALWAYS", value=0}
properties.s1_fb2 = {baseType="NUMBER", pushType = "ALWAYS", value=0}
properties.s1_fb3 = {baseType="NUMBER", pushType = "ALWAYS", value=0}
properties.s1_fb4 = {baseType="NUMBER", pushType = "ALWAYS", value=0}
properties.s1_fb5 = {baseType="NUMBER", pushType = "ALWAYS", value=0}

properties.s2_fb1 = {baseType="NUMBER", pushType = "ALWAYS", value=0}
properties.s2_fb2 = {baseType="NUMBER", pushType = "ALWAYS", value=0}
properties.s2_fb3 = {baseType="NUMBER", pushType = "ALWAYS", value=0}
properties.s2_fb4 = {baseType="NUMBER", pushType = "ALWAYS", value=0}
properties.s2_fb5 = {baseType="NUMBER", pushType = "ALWAYS", value=0}

serviceDefinitions.GetSystemProperties(
    output { baseType="BOOLEAN", description="" },
    description { "updates properties" }
)

services.GetSystemProperties = function(me, headers, query, data)
    queryHardware()
    return 200, true
end

function queryHardware()
    math.randomseed( tonumber(tostring(os.time()):reverse():sub(1,6)) )

    local temp = math.random(10)

    if temp < 6 then
        properties.failure.value=0
        properties.s1_fb1.value=161+math.random()
        properties.s1_fb2.value=180+math.random()
        properties.s1_fb3.value=190+math.random()
        properties.s1_fb4.value=176+math.random()
        properties.s1_fb5.value=193+math.random()
        properties.s2_fb1.value=130+math.random()
        properties.s2_fb2.value=200+math.random()
        properties.s2_fb3.value=195+math.random()
        properties.s2_fb4.value=165+math.random()
        properties.s2_fb5.value=190+math.random()
    else
        properties.failure.value=1
        properties.s1_fb1.value=90+math.random()
        properties.s1_fb2.value=170+math.random()
        properties.s1_fb3.value=170+math.random()
        properties.s1_fb4.value=95+math.random()
        properties.s1_fb5.value=190+math.random()
        properties.s2_fb1.value=165+math.random()
        properties.s2_fb2.value=195+math.random()
        properties.s2_fb3.value=190+math.random()
        properties.s2_fb4.value=140+math.random()
        properties.s2_fb5.value=190+math.random()
    end
end

tasks.refreshProperties = function(me)
    queryHardware()
end
