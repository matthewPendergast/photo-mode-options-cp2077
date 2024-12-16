local PMO = {
    modules = {
        config = require('config.lua'),
        data = require('modules/data.lua'),
    }
}

local menuController = {
    attributeKey = {
        lookAtCamera = 15,
        lockLookAtCamera = 9100,
        lookAtPreset = 9101,
        setEyesSuppress = 9102,
        setHeadSuppress = 9103,
        setHeadWeight = 9104,
        setChestSuppress = 9105,
        setChestWeight = 9106,
    },
    menuItem = {
        initialized = false,
        lockLookAtCamera = nil,
        lookAtPreset = nil,
        setEyesSuppress = nil,
        setHeadSuppress = nil,
        setHeadWeight = nil,
        setChestSuppress = nil,
        setChestWeight = nil,
    }
}

local localizable = {
    menuItem = {
        lockLookAtCamera = '- Lock \'Look At Camera\'',
        lookAtPreset = '- \'Look At Camera\' Preset',
        setEyesSuppress = '- Set Eyes Suppress',
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

-- Menu Controller Functions --

---@param menuItem PhotoModeMenuListItem
---@param photoModeController gameuiPhotoModeMenuController
---@param isVisible boolean
---@param values string[]
function SetupOptionSelector(menuItem, photoModeController, isVisible, values)
    menuItem.photoModeController = photoModeController
    menuItem:GetRootWidget():SetVisible(isVisible)
    menuItem.GridRoot:SetVisible(false)
    menuItem.ScrollBarRef:SetVisible(false)
    menuItem.OptionSelectorRef:SetVisible(true)
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
function SetupScrollBar(menuItem, photoModeController, isVisible, minVal, maxVal)
    menuItem.photoModeController = photoModeController
    menuItem:GetRootWidget():SetVisible(isVisible)
    menuItem.GridRoot:SetVisible(false)
    menuItem.OptionSelectorRef:SetVisible(false)
    menuItem.ScrollBarRef:SetVisible(true)
    menuItem:SetupScrollBar(0.5, 0.0, 1.0, 0.01, false)
end

---@param isHeadActive boolean
---@param isChestActive boolean
function SetLookAtPresetVisibility(isEyeActive, isHeadActive, isChestActive)
    menuController.menuItem.setEyesSuppress:GetRootWidget():SetVisible(isEyeActive)
    menuController.menuItem.setHeadSuppress:GetRootWidget():SetVisible(isHeadActive)
    menuController.menuItem.setHeadWeight:GetRootWidget():SetVisible(isHeadActive)
    menuController.menuItem.setChestSuppress:GetRootWidget():SetVisible(isChestActive)
    menuController.menuItem.setChestWeight:GetRootWidget():SetVisible(isChestActive)
end

-- CET Event Handling --

registerForEvent('onTweak', function()
    TweakDB:SetFlat(PMO.modules.data.attributes[1], PMO.modules.config.aperture)
end)

registerForEvent('onInit', function()
    Override("gameuiPhotoModeMenuController", "AddMenuItem",
    function(this, label, attributeKey, page, isAdditional, wrappedMethod)
        wrappedMethod(label, attributeKey, page, isAdditional)
        if attributeKey == menuController.attributeKey.lookAtCamera then
            this:AddMenuItem(localizable.menuItem.lockLookAtCamera, menuController.attributeKey.lockLookAtCamera, page, false)
            this:AddMenuItem(localizable.menuItem.lookAtPreset, menuController.attributeKey.lookAtPreset, page, false)
            this:AddMenuItem(localizable.menuItem.setEyesSuppress, menuController.attributeKey.setEyesSuppress, page, false)
            this:AddMenuItem(localizable.menuItem.setHeadSuppress, menuController.attributeKey.setHeadSuppress, page, false)
            this:AddMenuItem(localizable.menuItem.setHeadWeight, menuController.attributeKey.setHeadWeight, page, false)
            this:AddMenuItem(localizable.menuItem.setChestSuppress, menuController.attributeKey.setChestSuppress, page, false)
            this:AddMenuItem(localizable.menuItem.setChestWeight, menuController.attributeKey.setChestWeight, page, false)
        end
    end)

    Override("gameuiPhotoModeMenuController", "OnShow",
    function(this, reversedUI, wrappedMethod)
        local result = wrappedMethod(reversedUI)
        -- Retrieve MenuItems
        menuController.menuItem.lockLookAtCamera = this:GetMenuItem(menuController.attributeKey.lockLookAtCamera)
        menuController.menuItem.lookAtPreset = this:GetMenuItem(menuController.attributeKey.lookAtPreset)
        menuController.menuItem.setEyesSuppress = this:GetMenuItem(menuController.attributeKey.setEyesSuppress)
        menuController.menuItem.setHeadSuppress = this:GetMenuItem(menuController.attributeKey.setHeadSuppress)
        menuController.menuItem.setHeadWeight = this:GetMenuItem(menuController.attributeKey.setHeadWeight)
        menuController.menuItem.setChestSuppress = this:GetMenuItem(menuController.attributeKey.setChestSuppress)
        menuController.menuItem.setChestWeight = this:GetMenuItem(menuController.attributeKey.setChestWeight)

        -- Setup MenuItems
        SetupOptionSelector(menuController.menuItem.lockLookAtCamera, this, false, localizable.optionSelectorValues.lockLookAtCamera)
        SetupOptionSelector(menuController.menuItem.lookAtPreset, this, false, localizable.optionSelectorValues.lookAtPreset)
        SetupScrollBar(menuController.menuItem.setEyesSuppress, this, false, 0.0, 1.0)
        SetupScrollBar(menuController.menuItem.setHeadSuppress, this, false, 0.0, 1.0)
        SetupScrollBar(menuController.menuItem.setHeadWeight, this, false, 0.0, 1.0)
        SetupScrollBar(menuController.menuItem.setChestSuppress, this, false, 0.0, 1.0)
        SetupScrollBar(menuController.menuItem.setChestWeight, this, false, 0.0, 1.0)

        this:GetChildWidgetByPath('options_panel'):SetHeight(600.0)
        menuController.menuItem.initialized = true
        return result
    end)

    Observe("gameuiPhotoModeMenuController", "OnHide",
    function(this)
        GameOptions.SetFloat("LookAt", "MaxIterationsCount", 3.0)
    end)

    ObserveAfter("gameuiPhotoModeMenuController", "OnAttributeUpdated",
    function(this, attributeKey, attributeValue, doApply)
        if menuController.menuItem.initialized then
            -- If 'Look At Camera' is changed
            if attributeKey == menuController.attributeKey.lookAtCamera then
                if attributeValue == 1 then
                    menuController.menuItem.lockLookAtCamera:GetRootWidget():SetVisible(true)
                    menuController.menuItem.lookAtPreset:GetRootWidget():SetVisible(true)
                    this:GetChildWidgetByPath('options_panel'):SetHeight(800.0)
                elseif attributeValue == 0 then
                    menuController.menuItem.lockLookAtCamera:GetRootWidget():SetVisible(false)
                    menuController.menuItem.lookAtPreset:GetRootWidget():SetVisible(false)
                    SetLookAtPresetVisibility(false, false, false)
                    this:GetChildWidgetByPath('options_panel'):SetHeight(600.0)
                    if menuController.menuItem.lockLookAtCamera.OptionSelector.index == 1 then
                        menuController.menuItem.lockLookAtCamera.OptionSelector:Prior()
                        GameOptions.SetFloat("LookAt", "MaxIterationsCount", 3.0)
                    end
                end
            end
            -- If 'Lock Look At Camera' is changed
            if attributeKey == menuController.attributeKey.lockLookAtCamera then
                local label = menuController.menuItem.lockLookAtCamera.OptionLabelRef:GetText()
                if label == 'Locked' then
                    GameOptions.SetFloat("LookAt", "MaxIterationsCount", 0.0)
                elseif label == 'Unlocked' then
                    GameOptions.SetFloat("LookAt", "MaxIterationsCount", 3.0)
                end
            end
            -- If 'Look At Camera' Preset is changed
            if attributeKey == menuController.attributeKey.lookAtPreset then
                local label = menuController.menuItem.lookAtPreset.OptionLabelRef:GetText()
                if label == 'Full Body' then
                    SetLookAtPresetVisibility(true, true, true)
                elseif label == 'Head Only' then
                    SetLookAtPresetVisibility(true, true, false)
                elseif label == 'Eyes Only' then
                    SetLookAtPresetVisibility(true, false, false)
                end
            end
        end
    end)

    Observe("gameuiPhotoModeMenuController", "OnAttributeSelected",
    ---@param this gameuiPhotoModeMenuController
    ---@param attributeKey Uint32
    function(this, attributeKey)
        if attributeKey == menuController.attributeKey.lookAtPreset then
            local label = menuController.menuItem.lookAtPreset.OptionLabelRef:GetText()
            if label == 'Full Body' then
                SetLookAtPresetVisibility(true, true, true)
                this:GetChildWidgetByPath('options_panel'):SetHeight(1200.0)
            elseif label == 'Head Only' then
                SetLookAtPresetVisibility(true, true, false)
            elseif label == 'Eyes Only' then
                SetLookAtPresetVisibility(true, false, false)
            end
        elseif attributeKey == 7 or attributeKey == menuController.attributeKey.lockLookAtCamera then
            SetLookAtPresetVisibility(false, false, false)
        end
    end)
end)

return PMO