local PMO = {
    modules = {
        config = require('config.lua'),
        data = require('modules/data.lua'),
    }
}

local menuController = {
    attributeKey = {
        lookAtCamera = 15,
        lookAtTarget = 9100,
        setEyePos = 9101,
    },
    menuItem = {
        initialized = false,
        lookAtTarget = nil,
        setEyePos = nil,
    }
}

local localizable = {
    menuItem = {
        lookAtTarget = 'Look At Target',
        setEyePosX = 'Set Eye Position',
    },
}

-- CET Event Handling --

registerForEvent('onTweak', function()
    TweakDB:SetFlat(PMO.modules.data.attributes[1], PMO.modules.config.aperture)
end)

registerForEvent('onInit', function()

    Override("gameuiPhotoModeMenuController", "AddMenuItem",
    function(this, label, attributeKey, page, isAdditional, wrappedMethod)
        wrappedMethod(label, attributeKey, page, isAdditional)
        if attributeKey == menuController.attributeKey.lookAtCamera then
            this:AddMenuItem(localizable.menuItem.lookAtTarget, menuController.attributeKey.lookAtTarget, page, false)
            this:AddMenuItem(localizable.menuItem.setEyePosX, menuController.attributeKey.setEyePos, page, false)
        end
    end)

    Override("gameuiPhotoModeMenuController", "OnShow",
    function(this, reversedUI, wrappedMethod)
        local result = wrappedMethod(reversedUI)
        menuController.menuItem.lookAtTarget = this:GetMenuItem(menuController.attributeKey.lookAtTarget)
        menuController.menuItem.setEyePos = this:GetMenuItem(menuController.attributeKey.setEyePos)

        menuController.menuItem.lookAtTarget.GridRoot:SetVisible(false)
        menuController.menuItem.lookAtTarget.ScrollBarRef:SetVisible(false)
        menuController.menuItem.lookAtTarget.OptionSelector:Clear()
        menuController.menuItem.lookAtTarget.OptionSelector.values = { 'Off', 'On' }
        menuController.menuItem.lookAtTarget.OptionSelector.index = 0
        menuController.menuItem.lookAtTarget.OptionLabelRef:SetText(menuController.menuItem.lookAtTarget.OptionSelector.values[1])
        menuController.menuItem.lookAtTarget.photoModeController = this

        menuController.menuItem.setEyePos.GridRoot:SetVisible(false)
        menuController.menuItem.setEyePos.OptionSelectorRef:SetVisible(false)
        menuController.menuItem.setEyePos:GetRootWidget():SetVisible(false)
        menuController.menuItem.setEyePos.photoModeController = this

        menuController.menuItem.initialized = true
        return result
    end)

    ObserveAfter("gameuiPhotoModeMenuController", "OnAttributeUpdated",
    function(this, attributeKey, attributeValue, doApply)
        if menuController.menuItem.initialized and attributeKey == menuController.attributeKey.lookAtTarget then
            local label = menuController.menuItem.lookAtTarget.OptionLabelRef:GetText()
            if label == 'On' then
                menuController.menuItem.setEyePos:GetRootWidget():SetVisible(true)
            elseif label == 'Off' then
                menuController.menuItem.setEyePos:GetRootWidget():SetVisible(false)
            end
        end
    end)
end)

return PMO