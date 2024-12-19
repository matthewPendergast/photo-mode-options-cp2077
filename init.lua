local PMO = {
    modules = {
        config = require('config.lua'),
        data = require('modules/data.lua'),
    }
}

local menuController = {
    page = {
        pose = 2,
    },
    attributeKey = {
        -- New attributeKeys
        toggleMovementType = 9000,
        lockLookAtCamera = 9200,
        setHeadSuppress = 9201,
        setHeadWeight = 9202,
        setChestSuppress = 9203,
        setChestWeight = 9204,
        transitionSpeed = 9205,
        xPos = 9206,
        yPos = 9207,
        zPos = 9208,
        rollAngle = 9209,
        pitchAngle = 9210,
        yawAngle = 9211,
        -- Reference attributeKeys
        rotate = 7,
        leftRight = 8,
        closeFar = 9,
        lookAtCamera = 15,
        dofEnabled = 26,
        upDown = 37,
        collision = 39,
    },
    menuItem = {
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
        lookAtCamera = nil,
        initialized = false,
    }
}

local localizable = {
    menuItem = {
        toggleMovementType = 'Set Pose Movement Type',
        lockLookAtCamera = 'Lock \'Look At Camera\'',
        setHeadSuppress = 'Set Head Suppress',
        setHeadWeight = 'Set Head Weight',
        setChestSuppress = 'Set Chest Suppress',
        setChestWeight = 'Set Chest Weight',
        transitionSpeed = 'Transition Speed',
        xPos = 'X',
        yPos = 'Y',
        zPos = 'Z',
        rollAngle = 'Roll',
        pitchAngle = 'Pitch',
        yawAngle = 'Yaw',
    },
    optionSelectorValues = {
        toggleMovementType = { 'Alternate', 'Default' },
        lockLookAtCamera = { 'Unlocked', 'Locked' },
        lookAtPreset = { 'Full Body', 'Head Only', 'Eyes Only'},
    },
}

local menuItemKeys = {
    'toggleMovementType', 'lockLookAtCamera', 'setHeadSuppress', 'setHeadWeight', 'setChestSuppress', 'setChestWeight', 'transitionSpeed',
    'xPos', 'yPos', 'zPos', 'rollAngle', 'pitchAngle', 'yawAngle',
}

local state = {
    isDefaultMovementScheme = false,
    dof = {
        isInitialized = false,
        isFinalized = false,
    },
}

local transform = {
    position = { x = 0.0, y = 0.0, z = 0.0, w = 1 },
    orientation = { roll = 0, pitch = 0, yaw = 0 },
}

local fakePuppet = nil
local movementStep = 0.1

-- Menu Controller Functions --

---@param photoModeController gameuiPhotoModeMenuController
---@param labelSet string[]
---@param attributeSet integer[]
---@param page integer
local function AddMenuItems(photoModeController, labelSet, attributeSet, page)
    for _, key in ipairs(menuItemKeys) do
        photoModeController:AddMenuItem(labelSet[key], attributeSet[key], page, false)
    end
end

---@param photoModeController gameuiPhotoModeMenuController
local function AssignMenuItems(photoModeController)
    for _, key in ipairs(menuItemKeys) do
        menuController.menuItem[key] = photoModeController:GetMenuItem(menuController.attributeKey[key])
    end
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
local function SetupScrollBar(menuItem, photoModeController, isVisible, startVal, minVal, maxVal, step)
    menuItem.photoModeController = photoModeController
    menuItem:GetRootWidget():SetVisible(isVisible)
    menuItem.GridRoot:SetVisible(false)
    menuItem.OptionSelectorRef:SetVisible(false)
    menuItem.ScrollBarRef:SetVisible(true)
    menuItem:SetIsEnabled(true)
    menuItem:SetupScrollBar(startVal, minVal, maxVal, step, true)
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
local function SetDefaultMovementSchemeVisibility(photoModeController, boolean)
    photoModeController:GetMenuItem(menuController.attributeKey.rotate):GetRootWidget():SetVisible(boolean)
    photoModeController:GetMenuItem(menuController.attributeKey.leftRight):GetRootWidget():SetVisible(boolean)
    photoModeController:GetMenuItem(menuController.attributeKey.closeFar):GetRootWidget():SetVisible(boolean)
    photoModeController:GetMenuItem(menuController.attributeKey.upDown):GetRootWidget():SetVisible(boolean)
    menuController.menuItem.xPos:GetRootWidget():SetVisible(not boolean)
    menuController.menuItem.yPos:GetRootWidget():SetVisible(not boolean)
    menuController.menuItem.zPos:GetRootWidget():SetVisible(not boolean)
    menuController.menuItem.rollAngle:GetRootWidget():SetVisible(not boolean)
    menuController.menuItem.pitchAngle:GetRootWidget():SetVisible(not boolean)
    menuController.menuItem.yawAngle:GetRootWidget():SetVisible(not boolean)
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

    Game.GetTeleportationFacility():Teleport(character, position, orientation)
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
        if attributeKey == menuController.attributeKey.lookAtCamera then
            AddMenuItems(this, localizable.menuItem, menuController.attributeKey, page)
        end
        wrappedMethod(label, attributeKey, page, isAdditional)
    end)

    Override('gameuiPhotoModeMenuController', 'OnShow',
    function(this, reversedUI, wrappedMethod)
        local result = wrappedMethod(reversedUI)

        -- Store persistent Menu Item data
        AssignMenuItems(this)
        menuController.menuItem.lookAtCamera = this:GetMenuItem(menuController.attributeKey.lookAtCamera)

        -- Setup Menu Items
        SetupOptionSelector(menuController.menuItem.toggleMovementType, this, false, localizable.optionSelectorValues.toggleMovementType)
        SetupOptionSelector(menuController.menuItem.lockLookAtCamera, this, false, localizable.optionSelectorValues.lockLookAtCamera)
        SetupScrollBar(menuController.menuItem.setHeadSuppress, this, false, 0.0, 0.0, 1.0, .01)
        SetupScrollBar(menuController.menuItem.setHeadWeight, this, false, 0.0, 0.0, 1.0, .01)
        SetupScrollBar(menuController.menuItem.setChestSuppress, this, false, 0.0, 0.0, 1.0, .01)
        SetupScrollBar(menuController.menuItem.setChestWeight, this, false, 0.0, 0.0, 0.5, .005)
        SetupScrollBar(menuController.menuItem.transitionSpeed, this, false, 70.0, 1.0, 140.0, 1.0)
        SetupScrollBar(menuController.menuItem.rollAngle, this, true, 0.0, -180.0, 180.0, 1.0)
        SetupScrollBar(menuController.menuItem.pitchAngle, this, true, 0.0, -180.0, 180.0, 1.0)
        SetupScrollBar(menuController.menuItem.yawAngle, this, true, transform.orientation.yaw, -180.0, 180.0, 1.0)
        SetupScrollBar(menuController.menuItem.xPos, this, true, 0.0, -10.0, 10.0, movementStep)
        SetupScrollBar(menuController.menuItem.yPos, this, true, 0.0, -10.0, 10.0, movementStep)
        SetupScrollBar(menuController.menuItem.zPos, this, true, 0.0, -10.0, 10.0, movementStep)

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
        GameOptions.SetFloat(PMO.modules.data.category[1], PMO.modules.data.key[1], 3.0)
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
            -- If 'Set Pose Movement Type' is changed
            if attributeKey == menuController.attributeKey.toggleMovementType then
                local label = menuController.menuItem.toggleMovementType.OptionLabelRef:GetText()
                if label == localizable.optionSelectorValues.toggleMovementType[1] then
                    state.isDefaultMovementScheme = false
                    SetDefaultMovementSchemeVisibility(this, false)
                elseif label == localizable.optionSelectorValues.toggleMovementType[2] then
                    state.isDefaultMovementScheme = true
                    SetDefaultMovementSchemeVisibility(this, true)
                end
            end
            -- Activates after game has finished setting up Depth of Field
            if attributeKey == menuController.attributeKey.dofEnabled and not state.dof.isFinalized then
                state.dof.isInitialized = true
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
                UpdateCharacterTransform(fakePuppet, transform, 'position.x', offset, 'increment')
            end
            if attributeKey == menuController.attributeKey.yPos then
                local offset = movementStep * menuController.menuItem.yPos.inputDirection
                UpdateCharacterTransform(fakePuppet, transform, 'position.y', offset, 'increment')
            end
            if attributeKey == menuController.attributeKey.zPos then
                local offset = movementStep * menuController.menuItem.zPos.inputDirection
                UpdateCharacterTransform(fakePuppet, transform, 'position.z', offset, 'increment')
            end
            if attributeKey == menuController.attributeKey.rollAngle then
                UpdateCharacterTransform(fakePuppet, transform, 'orientation.roll', menuController.menuItem.rollAngle:GetSliderValue(), 'set')
            end
            if attributeKey == menuController.attributeKey.pitchAngle then
                UpdateCharacterTransform(fakePuppet, transform, 'orientation.pitch', menuController.menuItem.pitchAngle:GetSliderValue(), 'set')
            end
            if attributeKey == menuController.attributeKey.yawAngle then
                UpdateCharacterTransform(fakePuppet, transform, 'orientation.yaw', menuController.menuItem.yawAngle:GetSliderValue(), 'set')
            end
        end
    end)

    ObserveAfter('gameuiPhotoModeMenuController', 'OnIntroAnimEnded',
    function(this, e)
        -- Disable collision by default
        local colMenuItem = this:GetMenuItem(menuController.attributeKey.collision)
        colMenuItem.OptionSelector:SetCurrIndex(0)
        this:OnAttributeUpdated(menuController.attributeKey.collision, 0, true)
        colMenuItem:OnSliderHandleReleased()

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
        -- Retrieve Photo Mode puppet for persistent access
        fakePuppet = this.fakePuppet
        -- Retrieve Photo Mode puppet's initial yaw for UI display value
        transform.orientation.yaw = fakePuppet:GetWorldYaw()
    end)
end)

return PMO