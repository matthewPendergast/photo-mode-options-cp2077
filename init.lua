local PMO = {
    modules = {
        config = require('config.lua'),
        data = require('modules/data.lua'),
    }
}

local menuController = {
    attributeKey = {
        lockLookAtCamera = 9100,
        setHeadSuppress = 9101,
        setHeadWeight = 9102,
        setChestSuppress = 9103,
        setChestWeight = 9104,
        lookAtCamera = 15,
    },
    menuItem = {
        lockLookAtCamera = nil,
        setHeadSuppress = nil,
        setHeadWeight = nil,
        setChestSuppress = nil,
        setChestWeight = nil,
        lookAtCamera = nil,
        initialized = false,
    }
}

local localizable = {
    menuItem = {
        lockLookAtCamera = '- Lock \'Look At Camera\'',
        setHeadSuppress = '- Set Head Suppress',
        setHeadWeight = '- Set Head Weight',
        setChestSuppress = '- Set Chest Suppress',
        setChestWeight = '- Set Chest Weight',
    },
    optionSelectorValues = {
        lockLookAtCamera = { 'Unlocked', 'Locked' },
        lookAtPreset = { 'Full Body', 'Head Only', 'Eyes Only'},
    },
}

local menuItemKeys = {
    'lockLookAtCamera', 'setHeadSuppress', 'setHeadWeight', 'setChestSuppress', 'setChestWeight',
}

-- Menu Controller Functions --

---@param photoModeController gameuiPhotoModeMenuController
---@param page integer
local function AddMenuItems(photoModeController, page)
    for _, key in ipairs(menuItemKeys) do
        photoModeController:AddMenuItem(localizable.menuItem[key], menuController.attributeKey[key], page, false)
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
---@param minVal float
---@param maxVal float
---@param step float
local function SetupScrollBar(menuItem, photoModeController, isVisible, minVal, maxVal, step)
    menuItem.photoModeController = photoModeController
    menuItem:GetRootWidget():SetVisible(isVisible)
    menuItem.GridRoot:SetVisible(false)
    menuItem.OptionSelectorRef:SetVisible(false)
    menuItem.ScrollBarRef:SetVisible(true)
    menuItem:SetIsEnabled(true)
    menuItem:SetupScrollBar(0, minVal, maxVal, step, false)
end

local function SetLookAtPresetVisibility(boolean)
    menuController.menuItem.lockLookAtCamera:GetRootWidget():SetVisible(boolean)
    menuController.menuItem.setHeadSuppress:GetRootWidget():SetVisible(boolean)
    menuController.menuItem.setHeadWeight:GetRootWidget():SetVisible(boolean)
    menuController.menuItem.setChestSuppress:GetRootWidget():SetVisible(boolean)
    menuController.menuItem.setChestWeight:GetRootWidget():SetVisible(boolean)
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

-- CET Event Handling --

registerForEvent('onTweak', function()
    TweakDB:SetFlat(PMO.modules.data.attributes[1], PMO.modules.config.aperture)
end)

registerForEvent('onInit', function()
    Override('gameuiPhotoModeMenuController', 'AddMenuItem',
    function(this, label, attributeKey, page, isAdditional, wrappedMethod)
        wrappedMethod(label, attributeKey, page, isAdditional)
        if attributeKey == menuController.attributeKey.lookAtCamera then
            AddMenuItems(this, page)
        end
    end)

    Override('gameuiPhotoModeMenuController', 'OnShow',
    function(this, reversedUI, wrappedMethod)
        local result = wrappedMethod(reversedUI)
        AssignMenuItems(this)
        menuController.menuItem.lookAtCamera = this:GetMenuItem(menuController.attributeKey.lookAtCamera)

        -- Setup MenuItems
        SetupOptionSelector(menuController.menuItem.lockLookAtCamera, this, false, localizable.optionSelectorValues.lockLookAtCamera)
        SetupScrollBar(menuController.menuItem.setHeadSuppress, this, false, 0.0, 1.0, .01)
        SetupScrollBar(menuController.menuItem.setHeadWeight, this, false, 0.0, 1.0, .01)
        SetupScrollBar(menuController.menuItem.setChestSuppress, this, false, 0.0, 1.0, .01)
        SetupScrollBar(menuController.menuItem.setChestWeight, this, false, 0.0, 0.5, .01)

        SetLookAtPresetVisibility(false)
        this:GetChildWidgetByPath(PMO.modules.data.widgetPath[1]):SetHeight(600.0)
        menuController.menuItem.initialized = true
        return result
    end)

    Observe('gameuiPhotoModeMenuController', 'OnHide',
    function(this)
        GameOptions.SetFloat(PMO.modules.data.category[1], PMO.modules.data.key[1], 3.0)
    end)

    ObserveAfter('gameuiPhotoModeMenuController', 'OnAttributeUpdated',
    function(this, attributeKey, attributeValue, doApply)
        if menuController.menuItem.initialized then
            -- If 'Look At Camera' is changed
            if attributeKey == menuController.attributeKey.lookAtCamera then
                -- Necessary to fix issue with indexing and attributeValue becoming decoupled during initialization
                menuController.menuItem.lookAtCamera.OptionSelector:SetCurrIndex(attributeValue)
                if attributeValue == 1 then
                    SetLookAtPresetVisibility(true)
                    this:GetChildWidgetByPath(PMO.modules.data.widgetPath[1]):SetHeight(1000.0)
                elseif attributeValue == 0 then
                    SetLookAtPresetVisibility(false)
                    this:GetChildWidgetByPath(PMO.modules.data.widgetPath[1]):SetHeight(600.0)
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
                TweakDB:SetFlat(PMO.modules.data.preset[1], menuController.menuItem.setHeadSuppress:GetSliderValue())
                CycleLookAtCamera(this)
            end
            if attributeKey == menuController.attributeKey.setHeadWeight then
                TweakDB:SetFlat(PMO.modules.data.preset[2], menuController.menuItem.setHeadWeight:GetSliderValue())
                CycleLookAtCamera(this)
            end
            if attributeKey == menuController.attributeKey.setChestSuppress then
                TweakDB:SetFlat(PMO.modules.data.preset[3], menuController.menuItem.setChestSuppress:GetSliderValue())
                CycleLookAtCamera(this)
            end
            if attributeKey == menuController.attributeKey.setChestWeight then
                TweakDB:SetFlat(PMO.modules.data.preset[4], menuController.menuItem.setChestWeight:GetSliderValue())
                CycleLookAtCamera(this)
            end
        end
    end)

    ObserveAfter("gameuiPhotoModeMenuController", "OnAnimationEnded",
    ---@param this gameuiPhotoModeMenuController
    ---@param animationType Uint32
    function(this, animationType)
        -- Revert Look At setting if active upon exiting Photo Mode
        if menuController.menuItem.lookAtCamera:GetSelectedOptionIndex() == 1 and animationType == 0 then
            menuController.menuItem.lookAtCamera.OptionSelector:SetCurrIndex(0)
            menuController.menuItem.lookAtCamera.OptionLabelRef:SetText(menuController.menuItem.lookAtCamera.OptionSelector.values[1])
            menuController.menuItem.lookAtCamera:StartArrowClickedEffect(menuController.menuItem.lookAtCamera.LeftArrow)
            this:OnAttributeUpdated(menuController.attributeKey.lookAtCamera, 0, true)
            menuController.menuItem.lookAtCamera:OnSliderHandleReleased()
        end
    end)
end)

return PMO