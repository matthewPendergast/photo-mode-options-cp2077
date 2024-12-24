local PMO = {
    modules = {
        config = require('config.lua'),
        data = require('modules/data.lua'),
    },
    external = {
        cron = require('external/Cron.lua'),
    },
}

local menuController = {
    page = {
        camera = 0,
        dof = 1,
        pose = 2,
        characters = 3,
        lighting = 4,
        effect = 5,
        stickers = 6,
        loadSave = 7,
    },
    attributeKey = {
        -- New attributeKeys
        freezeAnim = 9200,
        lockLookAtCamera = 9201,
        setHeadSuppress = 9202,
        setHeadWeight = 9203,
        setChestSuppress = 9204,
        setChestWeight = 9205,
        transitionSpeed = 9206,
        toggleMovementType = 9207,
        xPos = 9208,
        yPos = 9209,
        zPos = 9210,
        rollAngle = 9211,
        pitchAngle = 9212,
        yawAngle = 9213,
        equipment = 9214,
        setTime = 9501,
        -- Reference attributeKeys
        rotate = 7,
        leftRight = 8,
        closeFar = 9,
        exposure = 10,
        lookAtCamera = 15,
        dofEnabled = 26,
        characterVisible = 27,
        facialExpression = 28,
        upDown = 37,
        collision = 39,
    },
    menuItem = {
        freezeAnim = nil,
        toggleMovementType = nil,
        lockLookAtCamera = nil,
        setHeadSuppress = nil,
        setHeadWeight = nil,
        setChestSuppress = nil,
        setChestWeight = nil,
        transitionSpeed = nil,
        xPos = nil,
        yPos = nil,
        zPos = nil,
        rollAngle = nil,
        pitchAngle = nil,
        yawAngle = nil,
        equipment = nil,
        lookAtCamera = nil,
        setTime = nil,
        initialized = false,
    },
}

local localizable = {
    menuItem = {
        animation = {
            { key = 'freezeAnim', label = 'Freeze Animation'},
        },
        lookAt = {
            { key = 'lockLookAtCamera', label = 'Lock \'Look At Camera\'' },
            { key = 'setHeadSuppress', label = 'Set Head Suppress' },
            { key = 'setHeadWeight', label = 'Set Head Weight' },
            { key = 'setChestSuppress', label = 'Set Chest Suppress' },
            { key = 'setChestWeight', label = 'Set Chest Weight' },
            { key = 'transitionSpeed', label = 'Transition Speed' },
        },
        movement = {
            { key = 'toggleMovementType', label = 'Set Pose Movement Type' },
            { key = 'xPos', label = 'X' },
            { key = 'yPos', label = 'Y' },
            { key = 'zPos', label = 'Z' },
            { key = 'rollAngle', label = 'Roll' },
            { key = 'pitchAngle', label = 'Pitch' },
            { key = 'yawAngle', label = 'Yaw' },
        },
        equipment = {
            { key = 'equipment', label = 'Equipment' },
        },
        world = {
            { key = 'setTime', label = 'Set Time of Day' },
        },
    },
    optionSelectorValues = {
        freezeAnim = { 'Off', 'On' },
        toggleMovementType = { 'Alternate', 'Default' },
        lockLookAtCamera = { 'Unlocked', 'Locked' },
        lookAtPreset = { 'Full Body', 'Head Only', 'Eyes Only'},
    },
}

local state = {
    isDefaultMovementScheme = false,
    isPuppetTeleported = false,
    dof = {
        isInitialized = false,
        isFinalized = false,
    },
    equipment = {
        silverhandArm = false,
        headSlot = false,
        faceSlot = false,
        outerChestSlot = false,
        innerChestSlot = false,
        pantsSlot = false,
        shoesSlot = false,
        underwearTop = false,
        underwearBottom = true,
        armsCWSlot = false,
    },
    time = {
        hour = nil,
        minute = nil,
    },
}

local outfit = {
    silverhandArm = '',
    headSlot = '',
    faceSlot = '',
    outerChestSlot = '',
    innerChestSlot = '',
    pantsSlot = '',
    shoesSlot = '',
    underwearTop = '',
    underwearBottom = '',
    armsCWSlot = '',
}

local transform = {
    position = { x = 0.0, y = 0.0, z = 0.0, w = 1 },
    orientation = { roll = 0, pitch = 0, yaw = 0 },
}

local transactionSystem = nil
local photoModePlayerEntityComponent = nil
local pmPuppet = nil
local gender = nil
local movementStep = 0.1

-- Menu Controller Functions --

---@param photoModeController gameuiPhotoModeMenuController
---@param category string
---@param page integer
local function AddMenuItems(photoModeController, category, page)
    for _, item in ipairs(localizable.menuItem[category]) do
        local key = item.key
        local label = item.label
        local attribute = menuController.attributeKey[key]
        photoModeController:AddMenuItem(label, attribute, page, false)
    end
end

---@param photoModeController gameuiPhotoModeMenuController
local function AssignMenuItems(photoModeController)
    menuController.menuItem = {} -- Clear or initialize the table
    for _, items in pairs(localizable.menuItem) do
        for _, item in ipairs(items) do
            local key = item.key
            local attribute = menuController.attributeKey[key]
            menuController.menuItem[key] = photoModeController:GetMenuItem(attribute)
        end
    end
end

local function SetupEquipmentData()
    for _, slot in ipairs(PMO.modules.data.attachmentSlots) do
        local success, itemName = pcall(function()
            local item = transactionSystem:GetItemInSlot(pmPuppet, TweakDBID.new(slot))
            if not item then
                return nil
            end

            local line = tostring(item:GetItemData():GetID())
            if not line then
                return nil
            end

            -- Parse the line for the item name
            return string.match(line, "%-%-%[%[%s*(%S.-%S)%s*%-%-%]%]")
        end)

        if success and itemName then
            --print(slot, itemName)
            -- To Do: Store in outfit table for toggle settings and toggle state to true
        else
            --print(slot, 'No item found')
            -- To Do: Set outfit table to '' at this slot's index and toggle state to false
        end
    end
end

---@param menuItem PhotoModeMenuListItem
---@param photoModeController gameuiPhotoModeMenuController
---@param isVisible boolean
---@param gridData table
---@param elements integer
---@param elementsInRow integer
local function SetupGridSelector(menuItem, photoModeController, isVisible, gridData, elements, elementsInRow)
    menuItem.photoModeController = photoModeController
    menuItem:GetRootWidget():SetVisible(isVisible)
    menuItem.GridRoot:SetVisible(true)
    menuItem.ScrollBarRef:SetVisible(false)
    menuItem.OptionSelectorRef:SetVisible(false)
    menuItem:SetIsEnabled(true)
    menuItem:SetupGridSelector(nil, elements, elementsInRow)

    for i, item in ipairs(gridData) do
        -- Handle gender differences
        if gender == 'Male' then
            if item.optionData == 8006 then
                goto continue
            end
            if item.optionData == 8007 then
                item.atlasResource = PMO.modules.data.equipmentGridDataAlternate[1].atlasResource
                item.imagePart = PMO.modules.data.equipmentGridDataAlternate[1].imagePart
            end
        end
        menuItem.GridSelector:SetGridButtonImage(
            i - 1,
            ResRef.FromString(item.atlasResource),
            item.imagePart,
            item.optionData
        )
        menuItem.GridSelector:SetGridButtonImageForceVisible(i - 1)
        ::continue::
    end
    menuItem.GridSelector.SelectedIndex = -1
    menuItem.GridSelector:UpdateSelectedState()
    menuItem.GridSelector.SliderWidget:SetVisible(false)
end

---@param menuItem PhotoModeMenuListItem
---@param photoModeController gameuiPhotoModeMenuController
---@param isVisible boolean
---@param values string[]
local function SetupOptionSelector(menuItem, photoModeController, isVisible, values)
    menuItem.photoModeController = photoModeController
    menuItem:GetRootWidget():SetVisible(isVisible)
    menuItem.GridRoot:SetVisible(false)
    menuItem.ScrollBarRef:SetVisible(false)
    menuItem.OptionSelectorRef:SetVisible(true)
    menuItem:SetIsEnabled(true)
    menuItem.OptionSelector:Clear()
    menuItem.OptionSelector.values = values
    menuItem.OptionSelector.index = 0
    menuItem.OptionLabelRef:SetText(menuItem.OptionSelector.values[1])
end

---@param menuItem PhotoModeMenuListItem
---@param photoModeController gameuiPhotoModeMenuController
---@param isVisible boolean
---@param startVal float
---@param minVal float
---@param maxVal float
---@param step float
---@param showPercents bool
local function SetupScrollBar(menuItem, photoModeController, isVisible, startVal, minVal, maxVal, step, showPercents)
    menuItem.photoModeController = photoModeController
    menuItem:GetRootWidget():SetVisible(isVisible)
    menuItem.GridRoot:SetVisible(false)
    menuItem.OptionSelectorRef:SetVisible(false)
    menuItem.ScrollBarRef:SetVisible(true)
    menuItem:SetIsEnabled(true)
    menuItem:SetupScrollBar(startVal, minVal, maxVal, step, showPercents)
end

local function SetLookAtPresetVisibility(boolean)
    menuController.menuItem.lockLookAtCamera:GetRootWidget():SetVisible(boolean)
    menuController.menuItem.setHeadSuppress:GetRootWidget():SetVisible(boolean)
    menuController.menuItem.setHeadWeight:GetRootWidget():SetVisible(boolean)
    menuController.menuItem.setChestSuppress:GetRootWidget():SetVisible(boolean)
    menuController.menuItem.setChestWeight:GetRootWidget():SetVisible(boolean)
    menuController.menuItem.transitionSpeed:GetRootWidget():SetVisible(boolean)
end

---@param photoModeController gameuiPhotoModeMenuController
---@param visible boolean
---@param sameVisibility boolean|nil
local function SetDefaultMovementSchemeVisibility(photoModeController, visible, sameVisibility)
    -- Optional third parameter sets all movement scheme menu items to use the second parameter
    sameVisibility = sameVisibility or false
    local itemsToToggle = {
        {controller = photoModeController:GetMenuItem(menuController.attributeKey.toggleMovementType), toggle = true},
        {controller = photoModeController:GetMenuItem(menuController.attributeKey.rotate), toggle = visible},
        {controller = photoModeController:GetMenuItem(menuController.attributeKey.leftRight), toggle = visible},
        {controller = photoModeController:GetMenuItem(menuController.attributeKey.closeFar), toggle = visible},
        {controller = photoModeController:GetMenuItem(menuController.attributeKey.upDown), toggle = visible},
        {controller = menuController.menuItem.xPos, toggle = not visible},
        {controller = menuController.menuItem.yPos, toggle = not visible},
        {controller = menuController.menuItem.zPos, toggle = not visible},
        {controller = menuController.menuItem.rollAngle, toggle = not visible},
        {controller = menuController.menuItem.pitchAngle, toggle = not visible},
        {controller = menuController.menuItem.yawAngle, toggle = not visible},
    }

    for _, item in ipairs(itemsToToggle) do
        if item.controller then
            if sameVisibility then
                item.toggle = visible
            end
            item.controller:GetRootWidget():SetVisible(item.toggle)
        end
    end
end

---@param photoModeController gameuiPhotoModeMenuController
local function CycleLookAtCamera(photoModeController)
    for i = 0, 1 do
        menuController.menuItem.lookAtCamera.OptionSelector:Prior()
        menuController.menuItem.lookAtCamera.OptionLabelRef:SetText(menuController.menuItem.lookAtCamera.OptionSelector.values[2])
        menuController.menuItem.lookAtCamera:StartArrowClickedEffect(menuController.menuItem.lookAtCamera.LeftArrow)
        photoModeController:OnAttributeUpdated(menuController.attributeKey.lookAtCamera, i, true)
        menuController.menuItem.lookAtCamera:OnSliderHandleReleased()
    end
end

-- Misc Functions --

---@param character gamePuppet
---@param transformTable table
---@param keyPath string
---@param value float
---@param operation string ('increment'|'set')
local function UpdateCharacterTransform(character, transformTable, keyPath, value, operation)
    local worldTransform = character:GetWorldTransform()
    local worldOrientation = worldTransform:GetOrientation():ToEulerAngles()

    -- Update position
    transform.position.x = worldTransform.Position:GetX()
    transform.position.y = worldTransform.Position:GetY()
    transform.position.z = worldTransform.Position:GetZ()

    -- Update orientation
    transform.orientation.roll = worldOrientation.roll
    transform.orientation.pitch = worldOrientation.pitch
    transform.orientation.yaw = worldOrientation.yaw

    -- Separate keyPath into keys
    local keys = {}
    for key in string.gmatch(keyPath, '[^.]+') do
        table.insert(keys, key)
    end

    -- Locate the nested value to be updated
    local field = transformTable
    for i = 1, #keys - 1 do
        field = field[keys[i]]
    end

    -- Update the affected transform value
    local finalKey = keys[#keys]
    if operation == 'increment' then
        field[finalKey] = field[finalKey] + value
    elseif operation == 'set' then
        field[finalKey] = value
    end

    -- Setup new position and orientation values
    local position = Vector4.new(transform.position.x, transform.position.y, transform.position.z, transform.position.w)
    local orientation = EulerAngles.new(transform.orientation.roll, transform.orientation.pitch, transform.orientation.yaw)

    -- Disable foot snap while Photo Mode puppet is being moved
    pmPuppet:SetIndividualTimeDilation(PMO.modules.data.timeOnArg[1], PMO.modules.data.timeOnArg[2], PMO.modules.data.timeOnArg[3], PMO.modules.data.timeOnArg[1], PMO.modules.data.timeOnArg[1], PMO.modules.data.timeOnArg[4])
    Game.GetTeleportationFacility():Teleport(character, position, orientation)
    PMO.external.cron.After(0.25, function()
        pmPuppet:SetIndividualTimeDilation(PMO.modules.data.timeOffArg[1], PMO.modules.data.timeOffArg[2], PMO.modules.data.timeOffArg[3], PMO.modules.data.timeOffArg[1], PMO.modules.data.timeOffArg[1], PMO.modules.data.timeOffArg[4])
    end)
end

---@param buttonData integer
local function UpdateEquipmentStatus(buttonData)
    for i, gridData in ipairs(PMO.modules.data.equipmentGridData) do
        if buttonData == gridData.optionData then
            local stateKey = PMO.modules.data.equipment.keys[i]
            local isEquipped = state.equipment[stateKey]

            if isEquipped then
                transactionSystem:RemoveItemFromAnySlot(pmPuppet, ItemID.CreateQuery(PMO.modules.data.equipment[stateKey][2]))
            else
                if not transactionSystem:HasItem(Game.GetPlayer(), ItemID.CreateQuery(PMO.modules.data.equipment[stateKey][2])) then
                    transactionSystem:GiveItem(Game.GetPlayer(), ItemID.CreateQuery(PMO.modules.data.equipment[stateKey][2]), 1)
                end
                photoModePlayerEntityComponent:PutOnFakeItemFromMainPuppet(ItemID.CreateQuery(PMO.modules.data.equipment[stateKey][2]))
            end

            state.equipment[stateKey] = not isEquipped

            -- Auto-equip underwear items when shirt or pants are removed
            if (buttonData - 1) == PMO.modules.data.equipmentGridData[4].optionData then
                if not state.equipment.innerChestSlot and not state.equipment.underwearTop then
                    UpdateEquipmentStatus(PMO.modules.data.equipmentGridData[8].optionData)
                end
            elseif (buttonData - 1) == PMO.modules.data.equipmentGridData[5].optionData then
                if not state.equipment.pantsSlot and not state.equipment.underwearBottom then
                    UpdateEquipmentStatus(PMO.modules.data.equipmentGridData[9].optionData)
                end
            end

            break
        end
    end
end

---@param sliderValue float
local function SetTime(sliderValue)
    local hour = math.floor(sliderValue / 60)
    local minute = sliderValue % 60
    local offset = (hour == 0) and (hour + 1) or (hour - 1)
    Game.GetTimeSystem():SetGameTimeByHMS(hour, minute, 0)
    PMO.external.cron.After(0.5, function()
        -- Cycle time to clear out high exposure from time change
        Game.GetTimeSystem():SetGameTimeByHMS(offset, minute, 0)
        Game.GetTimeSystem():SetGameTimeByHMS(hour, minute, 0)
    end)
end

-- CET Event Handling --

registerForEvent('onTweak', function()
    -- Set full functionality for base Idle/Action poses
    for _, poseName in ipairs(PMO.modules.data.photoModePoses) do
        TweakDB:SetFlat(poseName .. PMO.modules.data.poseAttributes[1], true)
        TweakDB:SetFlat(poseName .. PMO.modules.data.poseAttributes[2], {CName'None'})
        TweakDB:SetFlat(poseName .. PMO.modules.data.poseAttributes[3], {CName'None'})
        TweakDB:SetFlat(poseName .. PMO.modules.data.poseAttributes[4], CName(PMO.modules.data.preset[1]))
        TweakDB:SetFlat(poseName .. PMO.modules.data.poseAttributes[5], PMO.modules.data.poseValues[1])
    end

    -- Setup unavailable poses
    local offset = Vector3.new(0.0, 0.0, 0.75)
    for i, poseName in ipairs(PMO.modules.data.photoModePosesUnnamed) do
        TweakDB:SetFlat(poseName .. PMO.modules.data.poseAttributes[6], CName(PMO.modules.data.photoModePosesNamed[i]))
        -- Exclude ladder pose from being repositioned
        if i ~= 1 then
            TweakDB:SetFlat(poseName .. PMO.modules.data.poseAttributes[7], offset)
        end
    end

    -- Add unavailable poses to the options
    local femalePoses = TweakDB:GetFlat(PMO.modules.data.characterPoses[1])
    local malePoses = TweakDB:GetFlat(PMO.modules.data.characterPoses[2])
    for _, poseName in ipairs(PMO.modules.data.photoModePoses) do
        local AddUnavailablePoses = function(targetPoses)
            for _, existingName in ipairs(targetPoses) do
                -- If pose is already in the main list, don't append it
                if existingName == poseName then
                    return
                end
            end
            table.insert(targetPoses, poseName)
        end
        AddUnavailablePoses(femalePoses)
        AddUnavailablePoses(malePoses)
    end
    TweakDB:SetFlat(PMO.modules.data.characterPoses[1], femalePoses)
    TweakDB:SetFlat(PMO.modules.data.characterPoses[2], malePoses)

    -- Enable full rotation for character poses
    TweakDB:SetFlat(PMO.modules.data.preset[2], 360.0)
    TweakDB:SetFlat(PMO.modules.data.preset[3], 360.0)
    TweakDB:SetFlat(PMO.modules.data.preset[4], 360.0)

    -- Set custom aperture setting
    TweakDB:SetFlat(PMO.modules.data.attributes[1], PMO.modules.config.aperture)

    -- Disable collision mechanics
    local array = {}
    for i = 1, 27 do
        array[i] = 0.0
    end
    TweakDB:SetFlat(PMO.modules.data.attributes[2], array)
    TweakDB:SetFlat(PMO.modules.data.attributes[3], array)
    TweakDB:SetFlat(PMO.modules.data.attributes[4], 0.0)
    TweakDB:SetFlat(PMO.modules.data.attributes[5], 0.0)
    TweakDB:SetFlat(PMO.modules.data.attributes[6], 0.0)

    -- Set higher pose position values
    TweakDB:SetFlat(PMO.modules.data.attributes[7], 10.0)
    TweakDB:SetFlat(PMO.modules.data.attributes[8], 10.0)

    -- Reduce limits on camera settings
    TweakDB:SetFlat(PMO.modules.data.cameraSettings[1], 150.0)
    TweakDB:SetFlat(PMO.modules.data.cameraSettings[2], 1.0)
    TweakDB:SetFlat(PMO.modules.data.cameraSettings[3], 180.0)
    TweakDB:SetFlat(PMO.modules.data.cameraSettings[4], -180.0)
    TweakDB:SetFlat(PMO.modules.data.cameraSettings[5], -180.0)
    TweakDB:SetFlat(PMO.modules.data.cameraSettings[6], 180.0)
    TweakDB:SetFlat(PMO.modules.data.cameraSettings[7], -180.0)
    TweakDB:SetFlat(PMO.modules.data.cameraSettings[8], 180.0)
end)

registerForEvent('onInit', function()
    Override('gameuiPhotoModeMenuController', 'AddMenuItem',
    function(this, label, attributeKey, page, isAdditional, wrappedMethod)
        if attributeKey == menuController.attributeKey.facialExpression then
            AddMenuItems(this, 'animation', page)
        end
        if attributeKey == menuController.attributeKey.rotate then
            AddMenuItems(this, 'lookAt', page)
            AddMenuItems(this, 'movement', page)
            AddMenuItems(this, 'equipment', page)
        end
        if attributeKey == menuController.attributeKey.exposure then
            AddMenuItems(this, 'world', page)
        end
        wrappedMethod(label, attributeKey, page, isAdditional)
    end)

    Override('gameuiPhotoModeMenuController', 'OnShow',
    function(this, reversedUI, wrappedMethod)
        local result = wrappedMethod(reversedUI)

        -- Store current time for resetting upon Photo Mode exit
        local gameTime = Game.GetTimeSystem():GetGameTime()
        state.time.hour = gameTime:Hours(gameTime)
        state.time.minute = gameTime:Minutes(gameTime)

        -- Setup default slider value for Set Time based on current time
        local currentTime = (state.time.hour * 60 + state.time.minute)

        -- Store persistent Menu Item data
        AssignMenuItems(this)
        menuController.menuItem.lookAtCamera = this:GetMenuItem(menuController.attributeKey.lookAtCamera)

        -- Store persistent character data
        gender = string.gmatch(tostring(Game.GetPlayer():GetResolvedGenderName()), '%-%-%[%[%s*(%a+)%s*%-%-%]%]')()
        transactionSystem = Game.GetTransactionSystem()

        -- Setup Menu Items
        SetupOptionSelector(menuController.menuItem.freezeAnim, this, false, localizable.optionSelectorValues.freezeAnim)
        SetupOptionSelector(menuController.menuItem.toggleMovementType, this, false, localizable.optionSelectorValues.toggleMovementType)
        SetupOptionSelector(menuController.menuItem.lockLookAtCamera, this, false, localizable.optionSelectorValues.lockLookAtCamera)
        SetupScrollBar(menuController.menuItem.setHeadSuppress, this, false, 0.0, 0.0, 1.0, .01, true)
        SetupScrollBar(menuController.menuItem.setHeadWeight, this, false, 0.0, 0.0, 1.0, .01, true)
        SetupScrollBar(menuController.menuItem.setChestSuppress, this, false, 0.0, 0.0, 1.0, .01, true)
        SetupScrollBar(menuController.menuItem.setChestWeight, this, false, 0.0, 0.0, 0.5, .005, true)
        SetupScrollBar(menuController.menuItem.transitionSpeed, this, false, 70.0, 1.0, 140.0, 1.0, true)
        SetupScrollBar(menuController.menuItem.rollAngle, this, true, 0.0, -180.0, 180.0, 1.0, true)
        SetupScrollBar(menuController.menuItem.pitchAngle, this, true, 0.0, -180.0, 180.0, 1.0, true)
        SetupScrollBar(menuController.menuItem.yawAngle, this, true, transform.orientation.yaw, -180.0, 180.0, 1.0, true)
        SetupScrollBar(menuController.menuItem.xPos, this, true, 0.0, -10.0, 10.0, movementStep, true)
        SetupScrollBar(menuController.menuItem.yPos, this, true, 0.0, -10.0, 10.0, movementStep, true)
        SetupScrollBar(menuController.menuItem.zPos, this, true, 0.0, -10.0, 10.0, movementStep, true)
        SetupGridSelector(menuController.menuItem.equipment, this, true, PMO.modules.data.equipmentGridData, #PMO.modules.data.equipmentGridData, 5)
        SetupScrollBar(menuController.menuItem.setTime, this, true, currentTime, 0.0, 1439, 5, true)

        -- Reset Depth of Field state checks
        state.dof.isFinalized = false
        state.dof.isInitialized = false

        -- Setup UI
        SetLookAtPresetVisibility(false)
        this:GetChildWidgetByPath(PMO.modules.data.widgetPath[1]):SetHeight(1400.0)

        menuController.menuItem.initialized = true
        return result
    end)

    Observe('gameuiPhotoModeMenuController', 'OnHide',
    function(this)
        -- Deactivate locked Look At if it's still active
        GameOptions.SetFloat(PMO.modules.data.category[1], PMO.modules.data.key[1], 3.0)
        -- Restore original game time
        Game.GetTimeSystem():SetGameTimeByHMS(state.time.hour, state.time.minute, 0)
    end)

    ObserveAfter("gameuiPhotoModeMenuController", "OnAttributeSelected",
    function(this, attributeKey)
        if attributeKey == menuController.attributeKey.equipment then
            menuController.menuItem.equipment.GridSelector.SelectedIndex = 0
            menuController.menuItem.equipment.GridSelector:UpdateSelectedState()
        end
    end)


    Override("gameuiPhotoModeMenuController", "OnSetAttributeOptionEnabled",
    function(this, attributeKey, enabled, wrappedMethod)
        if not state.isDefaultMovementScheme then
            local positionKeys = {
                [menuController.attributeKey.rotate] = true,
                [menuController.attributeKey.leftRight] = true,
                [menuController.attributeKey.closeFar] = true,
                [menuController.attributeKey.upDown] = true,
            }
            -- Hide default movement controls for persistent setting (when implemented)
            if positionKeys[attributeKey] then
                enabled = false
            end
        end
        local result = wrappedMethod(attributeKey, enabled)
        return result
    end)

    ObserveAfter('gameuiPhotoModeMenuController', 'OnAttributeUpdated',
    function(this, attributeKey, attributeValue, doApply)
        if menuController.menuItem.initialized then
            -- If 'Freeze Animation' is toggled
            if attributeKey == menuController.attributeKey.freezeAnim then
                local label = menuController.menuItem.freezeAnim.OptionLabelRef:GetText()
                if label == localizable.optionSelectorValues.freezeAnim[1] then
                    pmPuppet:SetIndividualTimeDilation(PMO.modules.data.timeOffArg[1], PMO.modules.data.timeOffArg[2], PMO.modules.data.timeOffArg[3], PMO.modules.data.timeOffArg[1], PMO.modules.data.timeOffArg[1], PMO.modules.data.timeOffArg[4])
                elseif label == localizable.optionSelectorValues.freezeAnim[2] then
                    pmPuppet:SetIndividualTimeDilation(PMO.modules.data.timeOnArg[1], PMO.modules.data.timeOnArg[2], PMO.modules.data.timeOnArg[3], PMO.modules.data.timeOnArg[1], PMO.modules.data.timeOnArg[1], PMO.modules.data.timeOnArg[4])
                end
            end
            -- If 'Set Pose Movement Type' is changed
            if attributeKey == menuController.attributeKey.toggleMovementType then
                local label = menuController.menuItem.toggleMovementType.OptionLabelRef:GetText()
                if label == localizable.optionSelectorValues.toggleMovementType[1] then
                    state.isDefaultMovementScheme = false
                    SetDefaultMovementSchemeVisibility(this, state.isDefaultMovementScheme)
                elseif label == localizable.optionSelectorValues.toggleMovementType[2] then
                    state.isDefaultMovementScheme = true
                    SetDefaultMovementSchemeVisibility(this, state.isDefaultMovementScheme)
                end
            end
            -- Activates after game has finished setting up Depth of Field
            if attributeKey == menuController.attributeKey.dofEnabled and not state.dof.isFinalized then
                state.dof.isInitialized = true
            end
            -- If 'Character Visible' is toggled
            if attributeKey == menuController.attributeKey.characterVisible then
                if attributeValue == 0 then
                    SetDefaultMovementSchemeVisibility(this, false, true)
                elseif attributeValue == 1 then
                    SetDefaultMovementSchemeVisibility(this, state.isDefaultMovementScheme)
                end
            end
            -- If 'Look At Camera' is changed
            if attributeKey == menuController.attributeKey.lookAtCamera then
                -- Necessary to fix issue with indexing and attributeValue becoming decoupled during initialization
                menuController.menuItem.lookAtCamera.OptionSelector:SetCurrIndex(attributeValue)
                if attributeValue == 1 then
                    SetLookAtPresetVisibility(true)
                    this:GetChildWidgetByPath(PMO.modules.data.widgetPath[1]):SetHeight(1400.0)
                elseif attributeValue == 0 then
                    SetLookAtPresetVisibility(false)
                    this:GetChildWidgetByPath(PMO.modules.data.widgetPath[1]):SetHeight(1400.0)
                    if menuController.menuItem.lockLookAtCamera.OptionSelector.index == 1 then
                        menuController.menuItem.lockLookAtCamera.OptionSelector:Prior()
                        GameOptions.SetFloat(PMO.modules.data.category[1], PMO.modules.data.key[1], 3.0)
                    end
                end
            end
            -- If 'Lock Look At Camera' is changed
            if attributeKey == menuController.attributeKey.lockLookAtCamera then
                local label = menuController.menuItem.lockLookAtCamera.OptionLabelRef:GetText()
                if label == localizable.optionSelectorValues.lockLookAtCamera[1] then
                    GameOptions.SetFloat(PMO.modules.data.category[1], PMO.modules.data.key[1], 3.0)
                elseif label == localizable.optionSelectorValues.lockLookAtCamera[2] then
                    GameOptions.SetFloat(PMO.modules.data.category[1], PMO.modules.data.key[1], 0.0)
                end
            end
            -- If Preset values are updated
            if attributeKey == menuController.attributeKey.setHeadSuppress then
                TweakDB:SetFlat(PMO.modules.data.preset[5], menuController.menuItem.setHeadSuppress:GetSliderValue())
                CycleLookAtCamera(this)
            end
            if attributeKey == menuController.attributeKey.setHeadWeight then
                TweakDB:SetFlat(PMO.modules.data.preset[6], menuController.menuItem.setHeadWeight:GetSliderValue())
                CycleLookAtCamera(this)
            end
            if attributeKey == menuController.attributeKey.setChestSuppress then
                TweakDB:SetFlat(PMO.modules.data.preset[7], menuController.menuItem.setChestSuppress:GetSliderValue())
                CycleLookAtCamera(this)
            end
            if attributeKey == menuController.attributeKey.setChestWeight then
                TweakDB:SetFlat(PMO.modules.data.preset[8], menuController.menuItem.setChestWeight:GetSliderValue())
                CycleLookAtCamera(this)
            end
            if attributeKey == menuController.attributeKey.transitionSpeed then
                TweakDB:SetFlat(PMO.modules.data.preset[9], menuController.menuItem.transitionSpeed:GetSliderValue())
                TweakDB:SetFlat(PMO.modules.data.preset[10], menuController.menuItem.transitionSpeed:GetSliderValue())
                CycleLookAtCamera(this)
            end
            -- If new movement options are changed
            if attributeKey == menuController.attributeKey.xPos then
                local offset = movementStep * menuController.menuItem.xPos.inputDirection
                UpdateCharacterTransform(pmPuppet, transform, 'position.x', offset, 'increment')
            end
            if attributeKey == menuController.attributeKey.yPos then
                local offset = movementStep * menuController.menuItem.yPos.inputDirection
                UpdateCharacterTransform(pmPuppet, transform, 'position.y', offset, 'increment')
            end
            if attributeKey == menuController.attributeKey.zPos then
                local offset = movementStep * menuController.menuItem.zPos.inputDirection
                UpdateCharacterTransform(pmPuppet, transform, 'position.z', offset, 'increment')
            end
            if attributeKey == menuController.attributeKey.rollAngle then
                UpdateCharacterTransform(pmPuppet, transform, 'orientation.roll', menuController.menuItem.rollAngle:GetSliderValue(), 'set')
            end
            if attributeKey == menuController.attributeKey.pitchAngle then
                UpdateCharacterTransform(pmPuppet, transform, 'orientation.pitch', menuController.menuItem.pitchAngle:GetSliderValue(), 'set')
            end
            if attributeKey == menuController.attributeKey.yawAngle then
                UpdateCharacterTransform(pmPuppet, transform, 'orientation.yaw', menuController.menuItem.yawAngle:GetSliderValue(), 'set')
            end
            if attributeKey == menuController.attributeKey.setTime then
                SetTime(menuController.menuItem.setTime:GetSliderValue())
            end
        end
    end)

    ObserveAfter("PhotoModeMenuListItem", "GridElementAction",
    function(this, elementIndex, buttonData)
        UpdateEquipmentStatus(buttonData)
    end)

    ObserveAfter('gameuiPhotoModeMenuController', 'OnIntroAnimEnded',
    function(this, e)
        -- Disable collision by default
        local colMenuItem = this:GetMenuItem(menuController.attributeKey.collision)
        colMenuItem.OptionSelector:SetCurrIndex(0)
        this:OnAttributeUpdated(menuController.attributeKey.collision, 0, true)
        colMenuItem:OnSliderHandleReleased()

        -- To Do: this function call is too early
        --SetupEquipmentData()

        -- Revert Look At setting if active upon entering Photo Mode
        if menuController.menuItem.lookAtCamera:GetSelectedOptionIndex() == 1 then
            menuController.menuItem.lookAtCamera.OptionSelector:SetCurrIndex(0)
            menuController.menuItem.lookAtCamera.OptionLabelRef:SetText(menuController.menuItem.lookAtCamera.OptionSelector.values[1])
            menuController.menuItem.lookAtCamera:StartArrowClickedEffect(menuController.menuItem.lookAtCamera.LeftArrow)
            this:OnAttributeUpdated(menuController.attributeKey.lookAtCamera, 0, true)
            menuController.menuItem.lookAtCamera:OnSliderHandleReleased()
        end
    end)

    Observe('gameuiPhotoModeMenuController', 'GetCurrentSelectedMenuListItem',
    function(this)
        -- Set Depth of Field to Off
        if menuController.menuItem.initialized and state.dof.isInitialized and not state.dof.isFinalized then
            state.dof.isFinalized = true
            local dofMenuItem = this:GetMenuItem(menuController.attributeKey.dofEnabled)
            dofMenuItem.OptionSelector:SetCurrIndex(0)
            this:OnAttributeUpdated(menuController.attributeKey.dofEnabled, 0, true)
            dofMenuItem:OnSliderHandleReleased()
        end
    end)

    Observe('PhotoModePlayerEntityComponent', 'ListAllCurrentItems',
    function(this)
        -- Retrieve Photo Mode data for persistent access
        photoModePlayerEntityComponent = this
        pmPuppet = this.fakePuppet
        -- Retrieve Photo Mode puppet's initial yaw for UI display value
        transform.orientation.yaw = this.fakePuppet:GetWorldYaw()
    end)
end)

registerForEvent('onUpdate', function(deltaTime)
    PMO.external.cron.Update(deltaTime)
end)

return PMO