-- Automatic Pipe Light - specialization injector
-- Farming Simulator 25

local modSpecName = g_currentModName .. ".autoPipeLight" -- mod name + specialization name
local oldValidateTypes = TypeManager.validateTypes -- store the original function

TypeManager.validateTypes = function(self, ...)
    -- Check if the vehicle type is a vehicle and has the required specializations, but not the AutoPipeLight specialization
    if self.typeName == "vehicle" then
        local vehicleTypes = g_vehicleTypeManager:getTypes() -- get all vehicle types

        -- Loop through all vehicle types and add the AutoPipeLight specialization if the conditions are met
        for typeName, typeEntry in pairs(vehicleTypes) do
            local specializations = typeEntry.specializations -- get the specializations for the current vehicle type

            -- Check if the vehicle type has the Pipe and Lights specializations, but not the AutoPipeLight specialization
            if SpecializationUtil.hasSpecialization(Pipe, specializations)
            and SpecializationUtil.hasSpecialization(Lights, specializations)
            and not SpecializationUtil.hasSpecialization(AutoPipeLight, specializations) then
                g_vehicleTypeManager:addSpecialization(typeName, modSpecName) -- add the AutoPipeLight specialization to the vehicle type
            end
        end
    end

    return oldValidateTypes(self, ...) -- call the original validateTypes function to ensure normal behavior
end
