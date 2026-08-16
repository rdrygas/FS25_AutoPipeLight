-- Automatic Pipe Light - specialization injector
-- Farming Simulator 25

local modSpecName = g_currentModName .. ".autoPipeLight"
local oldValidateTypes = TypeManager.validateTypes

TypeManager.validateTypes = function(self, ...)
    if self.typeName == "vehicle" then
        local vehicleTypes = g_vehicleTypeManager:getTypes()

        for typeName, typeEntry in pairs(vehicleTypes) do
            local specializations = typeEntry.specializations

            if SpecializationUtil.hasSpecialization(Pipe, specializations)
            and SpecializationUtil.hasSpecialization(Lights, specializations)
            and not SpecializationUtil.hasSpecialization(AutoPipeLight, specializations) then
                g_vehicleTypeManager:addSpecialization(typeName, modSpecName)
            end
        end
    end

    return oldValidateTypes(self, ...)
end
