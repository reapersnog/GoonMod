----------
-- Payday 2 GoonMod, Weapon Customizer Beta, built on 12/30/2014 6:10:13 PM
-- Copyright 2014, James Wilkinson, Overkill Software
----------

CloneClass( BlackMarketManager )

local INV_TO_CRAFT = Idstring("inventory_to_crafted")
local CRAFT_TO_INV = Idstring("crafted_to_inventroy")
local INV_ADD = Idstring("add_to_inventory")
local INV_REMOVE = Idstring("remove_from_inventory")
local CRAFT_ADD = Idstring("add_to_crafted")
local CRAFT_REMOVE = Idstring("remove_from_crafted")

Hooks:RegisterHook("BlackMarketManagerPostSetup")
function BlackMarketManager._setup(self)
	self.orig._setup(self)
	Hooks:Call("BlackMarketManagerPostSetup", self)
end

Hooks:RegisterHook("BlackMarketManagerModifyGetInventoryCategory")
function BlackMarketManager.get_inventory_category(self, category)

	local t = {}

	for global_value, categories in pairs(self._global.inventory) do
		if categories[category] then

			for id, amount in pairs(categories[category]) do
				table.insert(t, {
					id = id,
					global_value = global_value,
					amount = amount
				})
			end

		end
	end

	Hooks:Call("BlackMarketManagerModifyGetInventoryCategory", self, category, t)

	return t

end

function BlackMarketManager:get_mods_on_weapon(category, slot)
	local _global = Global.blackmarket_manager
	if not _global.crafted_items[category] or not _global.crafted_items[category][slot] then
		return
	end
	return _global.crafted_items[category][slot].blueprint
end

function BlackMarketManager:on_traded_weapon(category, slot, remove_mods, skip_verification)

	local _global = Global.blackmarket_manager
	if not _global.crafted_items[category] or not _global.crafted_items[category][slot] then
		return
	end

	local global_values = _global.crafted_items[category][slot].global_values or {}
	local blueprint = _global.crafted_items[category][slot].blueprint
	local default_blueprint = managers.weapon_factory:get_default_blueprint_by_factory_id( _global.crafted_items[category][slot].factory_id )
	
	for i, default_part in ipairs(default_blueprint) do
		table.delete(blueprint, default_part)
	end

	-- Remove mods if we traded them
	if remove_mods then

		for k, part_id in pairs(blueprint) do
			local global_value = global_values[part_id] or "normal"
			self:add_to_inventory(global_value, "weapon_mods", part_id, true)
			self:alter_global_value_item(global_value, category, slot, part_id, CRAFT_REMOVE)
		end

	end

	_global.crafted_items[category][slot] = nil
	if not skip_verification then
		self:_verfify_equipped_category(category)
		if category == "primaries" then
			self:_update_menu_scene_primary()
		elseif category == "secondaries" then
			self:_update_menu_scene_secondary()
		end

	end

end

function BlackMarketManager:on_traded_mod(part_id)

	-- Find mod using part id
	for k, v in pairs( tweak_data.blackmarket["weapon_mods"] ) do
		if k == part_id then

			-- Get global value and amount of mod
			local global_value = v.global_value or v.dlc or "normal"
			local mod_amt = self:get_item_amount(global_value, "weapon_mods", part_id, true)

			-- Check if we have the mod before trying to remove it
			if mod_amt > 0 then
				self:remove_item(global_value, "weapon_mods", part_id)
			end

		end
	end

end

function BlackMarketManager:on_received_traded_mod(part_id)

	local success, err = pcall(function()

	-- Find mod using part id
	for k, v in pairs( tweak_data.blackmarket["weapon_mods"] ) do
		if k == part_id then

			-- Get global value and add mod
			local global_value = v.global_value or v.dlc or "normal"
			Print("global_value: " .. global_value)
			managers.blackmarket:add_to_inventory(global_value, "weapon_mods", part_id, true)

		end
	end

	end)
	if not success then Print("[Error] " .. err) end

end

function BlackMarketManager:get_mask_slot_data(mask)

	local category = "masks"
	if not Global.blackmarket_manager.crafted_items[category] then
		return nil
	end

	local slot
	if type(mask) == "table" then
		slot = mask.slot
	end
	if type(mask) == "number" then
		slot = mask
	end

	return Global.blackmarket_manager.crafted_items[category][slot]

end

function BlackMarketManager:get_mask_data(mask_id)
	return tweak_data.blackmarket.masks[mask_id]
end

function BlackMarketManager:get_mask_name(mask)
	return managers.localization:text(tweak_data.blackmarket.masks[mask].name_id)
end

function BlackMarketManager:get_mask_mod_data(mod_id, category)
	return tweak_data.blackmarket[category][mod_id]
end

function BlackMarketManager:get_mask_mod_name(mod, category)
	return managers.localization:text(tweak_data.blackmarket[category][mod].name_id)
end

function BlackMarketManager:get_free_mask_slot()

	local unlocked_mask_slots = Global.blackmarket_manager.unlocked_mask_slots
	local mask_slots = Global.blackmarket_manager.crafted_items.masks

	for i = 1, #unlocked_mask_slots, 1 do
		if mask_slots[i] == nil then
			return i
		end
	end

	return nil

end

function BlackMarketManager:has_all_dlc_for_mask(mask_id)

	-- Get mask data
	local mask_data = tweak_data.blackmarket.masks[mask_id]
	if mask_data == nil then
		return
	end

	-- Check if user has DLC for mask
	local dlc = mask_data.dlc
	if dlc ~= nil then
		if not managers.dlc:has_dlc(dlc) then
			return dlc
		end
	end

	return true

end

function BlackMarketManager:has_all_dlc_for_mask_mod(mod_id, category)

	-- Get part data
	local part_data = tweak_data.blackmarket[category][mod_id]
	if part_data == nil then
		return
	end
	local part_global_value = part_data.global_value or part_data.dlc or "normal"

	-- Check user has DLC
	local dlc = part_data.dlc
	if dlc ~= nil then
		if not managers.dlc:has_dlc(dlc) then
			return dlc
		end
	end

	return true

end

function BlackMarketManager:has_all_dlc_for_mask_and_parts(mask_id, material, pattern, color)

	-- Get mask part data
	local mask_data = tweak_data.blackmarket.masks[mask_id]
	local material_data = tweak_data.blackmarket.materials[material]
	local pattern_data = tweak_data.blackmarket.textures[pattern]
	local color_data = tweak_data.blackmarket.colors[color]

	if mask_data == nil then
		return
	end
	if material_data == nil then
		return
	end
	if pattern_data == nil then
		return
	end
	if color_data == nil then
		return
	end

	-- Get DLCs
	local dlcs_to_test = {}
	if mask_data.dlc ~= nil then
		table.insert( dlcs_to_test, mask_data.dlc )
	end
	if material_data.dlc ~= nil then
		table.insert( dlcs_to_test, material_data.dlc )
	end
	if pattern_data.dlc ~= nil then
		table.insert( dlcs_to_test, pattern_data.dlc )
	end
	if color_data.dlc ~= nil then
		table.insert( dlcs_to_test, color_data.dlc )
	end

	-- Test DLCs
	local dlcs_failed = nil
	for k, v in pairs(dlcs_to_test) do
		if not managers.dlc:has_dlc(v) then

			if dlcs_failed == nil then
				dlcs_failed = {}
			end

			dlcs_failed[v] = true

		end
	end

	-- Return result
	if dlcs_failed ~= nil then
		return dlcs_failed
	end
	return true

end

function BlackMarketManager:add_traded_mask_to_inventory(mask_id)
	self:add_traded_mask_part_to_inventory(mask_id, "masks")
end

function BlackMarketManager:add_traded_mask_part_to_inventory(part_id, category)

	-- Get part data
	local part_data = tweak_data.blackmarket[category][part_id]
	if part_data == nil then
		return
	end
	local part_global_value = part_data.global_value or part_data.dlc or "normal"
	if part_data.infamous then
		part_global_value = "infamous"
	end

	-- Add it to inventory
	self:add_to_inventory(part_global_value, category, part_id, false)

end

function BlackMarketManager:add_traded_mask_to_free_slot(mask_id)

	-- Get free mask slot
	local slot = self:get_free_mask_slot()
	if slot == nil then
		return
	end

	-- Get mask data
	local mask_data = tweak_data.blackmarket.masks[mask_id]
	if mask_data == nil then
		return
	end
	local mask_global_value = mask_data.global_value or mask_data.dlc or "normal"

	-- Add mask to inventory
	self:on_buy_mask_to_inventory(mask_id, mask_global_value, slot)

end

function BlackMarketManager:add_traded_modded_mask_to_free_slot(mask_id, material, pattern, color)

	local success, err = pcall(function()

	-- Get free mask slot
	local slot = self:get_free_mask_slot()
	if slot == nil then
		return
	end

	-- Get mask part data
	local mask_data = tweak_data.blackmarket.masks[mask_id]
	local material_data = tweak_data.blackmarket.materials[material]
	local pattern_data = tweak_data.blackmarket.textures[pattern]
	local color_data = tweak_data.blackmarket.colors[color]

	if mask_data == nil then
		return
	end
	if material_data == nil then
		return
	end
	if pattern_data == nil then
		return
	end
	if color_data == nil then
		return
	end

	-- Global values
	local mask_global_value = mask_data.global_value or mask_data.dlc or "normal"
	local material_global_value = material_data.global_value or material_data.dlc or "normal"
	local pattern_global_value = pattern_data.global_value or pattern_data.dlc or "normal"
	local color_global_value = color_data.global_value or color_data.dlc or "normal"

	-- Add mask to inventory
	self:on_buy_mask_to_inventory(mask_id, mask_global_value, slot)

	-- Start customizing mask
	self:start_customize_mask(slot)

	-- Setup customized mask data
	self._customize_mask.slot = slot
	self._customize_mask.materials = {id = material, global_value = material_global_value}
	self._customize_mask.textures = {id = pattern, global_value = pattern_global_value}
	self._customize_mask.colors = {id = color, global_value = color_global_value}

	-- Add cash to automatically craft mask
	local amount = managers.money:get_mask_crafting_price_modified(self._customize_mask.mask_id, self._customize_mask.global_value, self:get_customized_mask_blueprint(), {})
	managers.money:_add_to_total(amount, {no_offshore = true})

	-- Finish customizing mask and add to inventory
	self:finish_customize_mask()

	end)
	if not success then Print("[Error] " .. err) end

end

function BlackMarketManager:remove_mask_from_inventory(mask_slot)

	local category = mask_slot.category
	local slot = mask_slot.slot

	managers.blackmarket:alter_global_value_item(mask_slot.global_value, category, slot, mask_slot.mask_id, INV_REMOVE)
	Global.blackmarket_manager.crafted_items[category][slot] = nil

end

function BlackMarketManager:remove_mask_mod_from_inventory(mod_id, category)
	local data = managers.blackmarket:get_mask_mod_data(mod_id, category)
	local global_value = data.global_value or data.dlc or "normal"
	managers.blackmarket:remove_item(global_value, category, mod_id)
end
-- END OF FILE
