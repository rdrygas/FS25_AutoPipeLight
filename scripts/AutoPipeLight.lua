-- Automatic Pipe Light
-- Farming Simulator 25
--
-- Behaviour:
--   * pipe starts unfolding / is unfolded at night -> pipe light is switched on once
--   * pipe starts folding / is folded             -> pipe light is switched off once
--   * dawn while pipe is open                     -> only the light bit previously added
--                                                     automatically by this mod is removed
--   * manual light changes are not continuously overwritten by the mod
--   * attached auger wagons are supported through Lights:getIsActiveForLights()
--
-- The script first tries to identify a dedicated light type used by lights physically
-- mounted on the pipe. If this cannot be determined, light type 4 is used as a fallback.

AutoPipeLight = {}

AutoPipeLight.FALLBACK_LIGHT_TYPE = 4
AutoPipeLight.DEBUG = false

-- Debug print with vehicle name prefix. The vehicle name is taken from the config file path, which is not guaranteed to be unique.
local function debugPrint(vehicle, text, ...)
    if not AutoPipeLight.DEBUG then
        return
    end

    local vehicleName = vehicle.configFileName or "unknown vehicle"
    print(string.format("[AutoPipeLight] %s: %s", vehicleName, string.format(text, ...)))
end

-- Check if a scenegraph node is valid. The node may be nil or 0, which is not a valid node.
local function isValidNode(node)
    return node ~= nil and node ~= 0
end

-- Check if a scenegraph node is part of the pipe animation. 
-- This is used to identify lights that are physically mounted on the pipe, 
-- even if the vehicle does not explicitly expose them in spec_pipe.nodes.
local function isNodeInPipeAnimation(vehicle, pipeSpec, node)
    if pipeSpec.animation == nil
    or pipeSpec.animation.name == nil
    or vehicle.getAnimationByName == nil then
        return false
    end

    local animation = vehicle:getAnimationByName(pipeSpec.animation.name)
    if animation == nil then
        return false
    end

    -- Keyframe animations may index curves directly by scenegraph node.
    if animation.curvesByNode ~= nil and animation.curvesByNode[node] ~= nil then
        return true
    end

    -- Standard vehicle animations keep their animated nodes in parts / values.
    if animation.parts ~= nil then
        for _, part in pairs(animation.parts) do
            if part.node == node then
                return true
            end

            if part.animationValues ~= nil then
                for _, animationValue in pairs(part.animationValues) do
                    if animationValue.node == node then
                        return true
                    end
                end
            end
        end
    end

    return false
end

-- Check if a scenegraph node is related to the pipe. A light is treated as a pipe light if one
-- of its parents is an explicit Pipe node or participates in the pipe animation.
local function isNodeRelatedToPipe(vehicle, node)
    if not isValidNode(node) then
        return false
    end

    local pipeSpec = vehicle.spec_pipe
    if pipeSpec == nil then
        return false
    end

    -- Walk from the light towards the root. A light is treated as a pipe light if one
    -- of its parents is an explicit Pipe node or participates in the pipe animation.
    local currentNode = node
    local depth = 0

    while isValidNode(currentNode) and currentNode ~= getRootNode() and depth < 64 do
        if pipeSpec.nodes ~= nil then
            for _, pipeNode in ipairs(pipeSpec.nodes) do
                if pipeNode.node == currentNode then
                    return true
                end
            end
        end

        if isNodeInPipeAnimation(vehicle, pipeSpec, currentNode) then
            return true
        end

        -- Last-resort heuristic for mod vehicles whose pipe animation hierarchy is not
        -- exposed in a way that can be matched above. Keep it close to the light node
        -- to avoid accidentally classifying unrelated vehicle lights as pipe lights.
        if depth <= 5 then
            local nodeName = getName(currentNode)
            if nodeName ~= nil then
                nodeName = string.lower(nodeName)
                if string.find(nodeName, "pipe", 1, true) ~= nil
                or string.find(nodeName, "unload", 1, true) ~= nil then
                    return true
                end
            end
        end

        currentNode = getParent(currentNode)
        depth = depth + 1
    end

    return false
end

-- Add the light types used by a light to the usage table. 
-- The usage table is indexed by light type and contains a table with two boolean fields: pipe and other. 
-- The pipe field is true if the light type is used by a pipe-mounted light, 
-- and the other field is true if the light type is used by a non-pipe-mounted light. 
-- The usage table is used to detect which light types are used by pipe-mounted lights and which are used by other lights.
local function addLightUsage(vehicle, light, usage)
    if light == nil or not isValidNode(light.node) or light.lightTypes == nil then
        return
    end

    local isPipeLight = isNodeRelatedToPipe(vehicle, light.node)
    local maxLightState = vehicle.spec_lights.maxLightState or -1

    for _, lightType in pairs(light.lightTypes) do
        -- Negative values and the dynamically added light types (brake, reverse,
        -- indicators, etc.) are not suitable for the manual light mask controlled here.
        if type(lightType) == "number" and lightType >= 0 and lightType <= maxLightState then
            local entry = usage[lightType]
            if entry == nil then
                entry = {pipe = false, other = false}
                usage[lightType] = entry
            end

            if isPipeLight then
                entry.pipe = true
            else
                entry.other = true
            end
        end
    end
end

-- Detect which light types are used by pipe-mounted lights and which are used by other lights.
-- Returns a bitmask of the light types used by pipe-mounted lights and a string indicating the detection method used. 
-- The detection method can be "detected-unique", "detected-custom", "fallback-type4", or "none".
local function detectPipeLightMask(vehicle)
    local lightsSpec = vehicle.spec_lights
    if lightsSpec == nil then
        return 0, "none"
    end

    local usage = {}

    if lightsSpec.staticLights ~= nil then
        for _, lights in pairs(lightsSpec.staticLights) do
            for _, light in ipairs(lights) do
                addLightUsage(vehicle, light, usage)
            end
        end
    end

    if lightsSpec.realLights ~= nil then
        for _, profile in pairs(lightsSpec.realLights) do
            for _, lights in pairs(profile) do
                for _, light in ipairs(lights) do
                    addLightUsage(vehicle, light, usage)
                end
            end
        end
    end

    -- Best case: a light type is used by a pipe-mounted light and nowhere else.
    local uniquePipeMask = 0
    for lightType, entry in pairs(usage) do
        if entry.pipe and not entry.other then
            uniquePipeMask = bitOR(uniquePipeMask, 2 ^ lightType)
        end
    end

    if uniquePipeMask ~= 0 then
        return uniquePipeMask, "detected-unique"
    end

    -- Second choice: a custom light type (4 or higher) used on the pipe. Base manual
    -- light types occupy the lower range, so a pipe-mounted custom type is a safer
    -- choice than reusing a normal front/back work-light type.
    local customPipeMask = 0
    for lightType, entry in pairs(usage) do
        if entry.pipe and lightType >= AutoPipeLight.FALLBACK_LIGHT_TYPE then
            customPipeMask = bitOR(customPipeMask, 2 ^ lightType)
        end
    end

    if customPipeMask ~= 0 then
        return customPipeMask, "detected-custom"
    end

    -- Compatibility fallback. Use type 4 only when no pipe-mounted light type could
    -- be identified and the vehicle actually exposes this type in its manual mask.
    if (lightsSpec.maxLightState or -1) >= AutoPipeLight.FALLBACK_LIGHT_TYPE then
        return 2 ^ AutoPipeLight.FALLBACK_LIGHT_TYPE, "fallback-type4"
    end

    return 0, "none"
end

-- Set the light types mask of the vehicle, but mark the change as internal so that
-- onLightsTypesMaskChanged does not reset the autoOwnedMask. This is used to avoid 
-- treating automatic light changes as manual changes.
local function setMaskInternal(vehicle, newMask)
    local state = vehicle.autoPipeLightState
    local lightsSpec = vehicle.spec_lights

    if state == nil or lightsSpec == nil or newMask == lightsSpec.lightsTypesMask then
        return
    end

    state.internalMaskChange = true
    vehicle:setLightsTypesMask(newMask)
    state.internalMaskChange = false

    -- Normally onLightsTypesMaskChanged updates this synchronously. Keep a fallback
    -- assignment in case another mod changes the event flow.
    state.lastObservedMask = vehicle.spec_lights.lightsTypesMask
end

-- Switch on the pipe light automatically if it is not already on. 
-- This is called when the pipe is unfolded at night.
local function switchOnAutomatically(vehicle)
    local state = vehicle.autoPipeLightState
    local lightsSpec = vehicle.spec_lights

    if state == nil or lightsSpec == nil or state.pipeLightMask == 0 then
        return
    end

    local currentMask = lightsSpec.lightsTypesMask
    local missingMask = bitAND(state.pipeLightMask, bitNOT(currentMask))

    if missingMask == 0 then
        -- The player (or another system) already had the pipe light enabled.
        -- Do not claim ownership, so dawn will not switch it off automatically.
        state.autoOwnedMask = 0
        return
    end

    state.autoOwnedMask = missingMask
    setMaskInternal(vehicle, bitOR(currentMask, state.pipeLightMask))
end

-- Switch off the pipe light automatically if it is on. 
-- This is called when the pipe is folded, regardless of whether it is day or night.
local function switchOffBecausePipeFolded(vehicle)
    local state = vehicle.autoPipeLightState
    local lightsSpec = vehicle.spec_lights

    if state == nil or lightsSpec == nil or state.pipeLightMask == 0 then
        return
    end

    local currentMask = lightsSpec.lightsTypesMask
    local newMask = bitAND(currentMask, bitNOT(state.pipeLightMask))

    state.autoOwnedMask = 0
    setMaskInternal(vehicle, newMask)
end

-- Remove the light types that were automatically added by this mod.
-- This is called at dawn or when the player stops controlling the vehicle.
local function removeAutomaticLight(vehicle)
    local state = vehicle.autoPipeLightState
    local lightsSpec = vehicle.spec_lights

    if state == nil or lightsSpec == nil or state.autoOwnedMask == 0 then
        return
    end

    local currentMask = lightsSpec.lightsTypesMask
    local newMask = bitAND(currentMask, bitNOT(state.autoOwnedMask))

    state.autoOwnedMask = 0
    setMaskInternal(vehicle, newMask)
end

-- Check if the vehicle has the required specializations for AutoPipeLight.
function AutoPipeLight.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Pipe, specializations)
       and SpecializationUtil.hasSpecialization(Lights, specializations)
end

-- Initialize the AutoPipeLight specialization. 
-- This function is called when the specialization is registered.
function AutoPipeLight.initSpecialization()
end

-- Register event listeners for the AutoPipeLight specialization. 
-- This function is called when the specialization is registered.
function AutoPipeLight.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", AutoPipeLight)
    SpecializationUtil.registerEventListener(vehicleType, "onLoadFinished", AutoPipeLight)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", AutoPipeLight)
    SpecializationUtil.registerEventListener(vehicleType, "onLightsTypesMaskChanged", AutoPipeLight)
end

-- Initialize the AutoPipeLight state when the vehicle is loaded. 
-- This function is called when the vehicle is loaded from a savegame or created in the game.
function AutoPipeLight:onLoad(savegame)
    self.autoPipeLightState = {
        pipeLightMask = 0,
        detectionMethod = "none",
        autoOwnedMask = 0,
        internalMaskChange = false,
        lastObservedMask = 0,
        lastPipeOpen = nil,
        lastNight = nil,
        lastPlayerControlled = nil,
        ready = false
    }
end

-- Finalize the AutoPipeLight state when the vehicle has finished loading.
function AutoPipeLight:onLoadFinished(savegame)
    local state = self.autoPipeLightState
    if state == nil or self.spec_lights == nil or self.spec_pipe == nil then
        return
    end

    state.pipeLightMask, state.detectionMethod = detectPipeLightMask(self)
    state.lastObservedMask = self.spec_lights.lightsTypesMask or 0
    state.ready = true

    debugPrint(self, "pipe light mask=%d (%s)", state.pipeLightMask, state.detectionMethod)
end

-- Handle changes to the light types mask. 
-- This function is called when the light types mask is changed, either by the player or by another system.
function AutoPipeLight:onLightsTypesMaskChanged(lightsTypesMask)
    local state = self.autoPipeLightState
    if state == nil then
        return
    end

    local previousMask = state.lastObservedMask

    if previousMask ~= nil
    and not state.internalMaskChange
    and state.pipeLightMask ~= 0
    and bitAND(previousMask, state.pipeLightMask) ~= bitAND(lightsTypesMask, state.pipeLightMask) then
        -- A manual light command changed the pipe-light bit. Stop treating the current
        -- light state as owned by the automatic action, so the player keeps control.
        state.autoOwnedMask = 0
    end

    state.lastObservedMask = lightsTypesMask
end

-- Update the AutoPipeLight state on each tick.
function AutoPipeLight:onUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local state = self.autoPipeLightState
    if state == nil or not state.ready or state.pipeLightMask == 0 then
        return
    end

    local pipeSpec = self.spec_pipe
    if pipeSpec == nil or not pipeSpec.hasMovablePipe then
        return
    end

    -- targetState changes as soon as folding/unfolding is requested, so the lamp reacts
    -- immediately instead of waiting for the complete pipe animation to finish.
    local pipeOpen = pipeSpec.targetState ~= nil and pipeSpec.targetState > 1

    local environment = g_currentMission ~= nil and g_currentMission.environment or nil
    local isNight = environment ~= nil and environment.isSunOn == false

    -- Lights:getIsActiveForLights() also follows the attacher chain. Therefore an auger
    -- wagon attached to the tractor currently driven by the player is considered active.
    local playerControlled = self.getIsActiveForLights ~= nil and self:getIsActiveForLights(false)

    local firstUpdate = state.lastPipeOpen == nil
    local pipeChanged = not firstUpdate and pipeOpen ~= state.lastPipeOpen
    local nightChanged = not firstUpdate and isNight ~= state.lastNight
    local controlChanged = not firstUpdate and playerControlled ~= state.lastPlayerControlled

    if playerControlled then
        if not pipeOpen then
            -- On first acquisition of control, or whenever the pipe is folded, make sure
            -- the pipe light is off. This happens once per relevant state transition.
            if firstUpdate or pipeChanged or controlChanged then
                switchOffBecausePipeFolded(self)
            end
        elseif isNight then
            -- Automatic switch-on is event-like: opening the pipe, nightfall, or entering
            -- the vehicle triggers it once. A later manual light command is left alone.
            if firstUpdate or pipeChanged or nightChanged or controlChanged then
                switchOnAutomatically(self)
            end
        else
            -- At dawn remove only the bit that this mod itself added. If the player had
            -- already enabled that light manually, it is left untouched.
            if nightChanged or controlChanged then
                removeAutomaticLight(self)
            end
        end
    elseif controlChanged and state.lastPlayerControlled == true then
        -- The mod only owns automatic lighting while the player controls the vehicle.
        -- Remove only an automatically added bit; never reset the player's other lights.
        removeAutomaticLight(self)
    end

    state.lastPipeOpen = pipeOpen
    state.lastNight = isNight
    state.lastPlayerControlled = playerControlled
end
