--hero_earth_spirit.lua

CreateEmptyTalents("earth_spirit")

imba_earth_spirit_stone_caller = class({})

LinkLuaModifier("modifier_imba_stone_remnant_status", "hero/hero_earth_spirit", LUA_MODIFIER_MOTION_NONE)

local function FindStoneRemnant(pos, radius)
	local stones = Entities:FindAllInSphere(pos, radius)
	local stone = nil
	for _, sto in pairs(stones) do
		if (string.find(sto:GetName(), "npc_")) and sto:HasModifier("modifier_imba_stone_remnant_status") and not sto:HasModifier("modifier_imba_boulder_smash_motion") then
			stone = sto
			break
		end
	end
	return stone
end

function imba_earth_spirit_stone_caller:IsHiddenWhenStolen() 	return false end
function imba_earth_spirit_stone_caller:IsRefreshable() 		return true end
function imba_earth_spirit_stone_caller:IsStealable() 			return false end
function imba_earth_spirit_stone_caller:IsNetherWardStealable()	return false end
function imba_earth_spirit_stone_caller:IsTalentAbility() return true end

function imba_earth_spirit_stone_caller:CastFilterResultTarget(target)
	if target ~= self:GetCaster() then
		return UF_FAIL_CUSTOM
	end
end

function imba_earth_spirit_stone_caller:GetCustomCastErrorTarget(target) return "dota_hud_error_cant_cast_on_other" end

function imba_earth_spirit_stone_caller:OnUpgrade() AbilityChargeController:AbilityChargeInitialize(self, self:GetSpecialValueFor("charge_restore_time"), self:GetSpecialValueFor("max_charges"), 1, true, true) end

function imba_earth_spirit_stone_caller:OnSpellStart()
	local caster = self:GetCaster()
	local pos = self:GetCursorPosition()
	if self:GetCursorTarget() == caster then
		pos = caster:GetAbsOrigin() + caster:GetForwardVector() * 100
	end
	local stone = CreateUnitByName("npc_imba_earth_spirit_stone", pos, false, caster, caster, caster:GetTeamNumber())
	stone:SetForwardVector(caster:GetForwardVector())
	stone:AddNewModifier(caster, self, "modifier_imba_stone_remnant_status", {})
	stone:AddNewModifier(caster, self, "modifier_kill", {duration = self:GetSpecialValueFor("duration")})
end

modifier_imba_stone_remnant_status = class({})

function modifier_imba_stone_remnant_status:CheckState() return {[MODIFIER_STATE_INVULNERABLE] = true, [MODIFIER_STATE_UNSELECTABLE] = true, [MODIFIER_STATE_STUNNED] = true, [MODIFIER_STATE_NO_HEALTH_BAR] = true, [MODIFIER_STATE_NO_UNIT_COLLISION] = true} end

function modifier_imba_stone_remnant_status:OnCreated()
	if IsServer() then
		self:GetParent():EmitSound("Hero_EarthSpirit.StoneRemnant.Impact")
		local pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_earth_spirit/espirit_stoneremnant.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetParent())
		ParticleManager:SetParticleControl(pfx, 1, self:GetParent():GetAbsOrigin() + Vector(0,0,1200))
		self:AddParticle(pfx, false, false, 15, false, false)
	end
end

function modifier_imba_stone_remnant_status:OnDestroy()
	if IsServer() then
		self:GetParent():EmitSound("Hero_EarthSpirit.StoneRemnant.Destroy")
	end
end

imba_earth_spirit_boulder_smash = class({})

LinkLuaModifier("modifier_imba_boulder_smash_slow", "hero/hero_earth_spirit", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_imba_boulder_smash_silent", "hero/hero_earth_spirit", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_imba_boulder_smash_motion", "hero/hero_earth_spirit", LUA_MODIFIER_MOTION_NONE)

function imba_earth_spirit_boulder_smash:IsHiddenWhenStolen() 		return false end
function imba_earth_spirit_boulder_smash:IsRefreshable() 			return true end
function imba_earth_spirit_boulder_smash:IsStealable() 				return true end
function imba_earth_spirit_boulder_smash:IsNetherWardStealable()	return true end
function imba_earth_spirit_boulder_smash:GetCastRange()
	self.range = self.range or 50000
	if IsServer() then
		return self:GetSpecialValueFor("rock_search_aoe") + self.range
	else
		return self:GetSpecialValueFor("rock_search_aoe")
	end
end

function imba_earth_spirit_boulder_smash:CastFilterResultTarget(target)
	if target:IsInvulnerable() then
		return UF_FAIL_INVULNERABLE
	end
	if target == self:GetCaster() or not target:IsHero() then
		return UF_FAIL_CUSTOM
	end
end

function imba_earth_spirit_boulder_smash:GetCustomCastErrorTarget(target)
	if target == self:GetCaster() then
		return "#dota_hud_error_cant_cast_on_self"
	elseif not target:IsHero() then
		return "dota_hud_error_cant_cast_on_other"
	end
end

function imba_earth_spirit_boulder_smash:OnSpellStart()
	local caster = self:GetCaster()
	local target = self:GetCursorTarget() or FindStoneRemnant(caster:GetAbsOrigin(), self:GetSpecialValueFor("rock_search_aoe"))
	if not target then
		self:EndCooldown()
		self:RefundManaCost()
		return
	end
	local pos0 = target:GetAbsOrigin()
	if target:HasModifier("modifier_imba_stone_remnant_status") then
		pos0 = self:GetCursorPosition()
	end
	caster:EmitSound("Hero_EarthSpirit.BoulderSmash.Cast")
	target:EmitSound("Hero_EarthSpirit.BoulderSmash.Target")
	local direction = (pos0 - caster:GetAbsOrigin()):Normalized()
	local pos = caster:GetAbsOrigin() + direction * 100
	pos = GetGroundPosition(pos, nil)
	if target:HasModifier("modifier_imba_stone_remnant_status") then
		target:SetAbsOrigin(pos)
	end

	--Motion 
	local speed = self:GetSpecialValueFor("speed")
	local distance = target:HasModifier("modifier_imba_stone_remnant_status") and self:GetSpecialValueFor("rock_distance") or self:GetSpecialValueFor("unit_distance")
	local duration = distance / speed
	local buff = target:AddNewModifier(caster, self, "modifier_imba_boulder_smash_motion", {duration = duration})
	if buff:CheckMotionControllers() then
		buff.direction = direction
		if not target:HasModifier("modifier_imba_stone_remnant_status") then
			local pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_earth_spirit/espirit_bouldersmash_target_trail.vpcf", PATTACH_ABSORIGIN_FOLLOW, target)
			ParticleManager:SetParticleControl(pfx, 1, direction)
			buff:AddParticle(pfx, false, false, 15, false, false)
		end
		buff.pos = target:GetAbsOrigin()
		buff.hitted = {}
		buff:StartIntervalThink(FrameTime())
	end
end

modifier_imba_boulder_smash_motion = class({})

function modifier_imba_boulder_smash_motion:IsDebuff()			return false end
function modifier_imba_boulder_smash_motion:IsHidden() 			return true end
function modifier_imba_boulder_smash_motion:IsPurgable() 		return false end
function modifier_imba_boulder_smash_motion:IsPurgeException() 	return false end
function modifier_imba_boulder_smash_motion:IsMotionController() return true end
function modifier_imba_boulder_smash_motion:GetMotionControllerPriority() return DOTA_MOTION_CONTROLLER_PRIORITY_LOW end
function modifier_imba_boulder_smash_motion:CheckState() return {[MODIFIER_STATE_NO_UNIT_COLLISION] = true} end

function modifier_imba_boulder_smash_motion:OnCreated()
	if IsServer() then
		if self:GetParent():HasModifier("modifier_imba_stone_remnant_status") then
			local pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_earth_spirit/espirit_bouldersmash_pushrocks.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetParent())
			self:AddParticle(pfx, false, false, 15, false, false)
		end
		local pfx_smoke = ParticleManager:CreateParticle("particles/units/heroes/hero_earth_spirit/espirit_boouldersmash_groundsmoketrail.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetParent())
		self:AddParticle(pfx_smoke, false, false, 15, false, false)
	end
end

function modifier_imba_boulder_smash_motion:OnIntervalThink()
	if self:GetParent():HasModifier("modifier_imba_stone_remnant_status") then
		local enemies = FindUnitsInRadius(self:GetCaster():GetTeamNumber(), self.pos, nil, self:GetAbility():GetSpecialValueFor("radius"), DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES, FIND_ANY_ORDER, false)
		for _, enemy in pairs(enemies) do
			if not IsInTable(enemy, self.hitted) then
				self.hitted[#self.hitted+1] = enemy
				if not enemy:IsMagicImmune() then
					enemy:AddNewModifier(self:GetCaster(), self:GetAbility(), "modifier_imba_stunned", {duration = self:GetAbility():GetSpecialValueFor("stun_duration")})
				else
					enemy:AddNewModifier(self:GetCaster(), self:GetAbility(), "modifier_imba_boulder_smash_slow", {duration = self:GetAbility():GetSpecialValueFor("stun_duration")})
				end
				if enemy:IsAttackImmune() then
					enemy:AddNewModifier(self:GetCaster(), self:GetAbility(), "modifier_imba_boulder_smash_silent", {duration = self:GetAbility():GetSpecialValueFor("stun_duration")})
				end
				ApplyDamage({victim = enemy, attacker = self:GetCaster(), damage = self:GetAbility():GetSpecialValueFor("rock_damage"), ability = self:GetAbility(), damage_type = self:GetAbility():GetAbilityDamageType()})
				enemy:EmitSound("Hero_EarthSpirit.BoulderSmash.Damage")
			end
		end
	end
	GridNav:DestroyTreesAroundPoint(self.pos, 80, true)
	local distance = self:GetAbility():GetSpecialValueFor("speed") / (1.0 / FrameTime())
	local next_pos = self.pos + self.direction * distance
	next_pos = GetGroundPosition(next_pos, nil)
	self.pos = next_pos
	self:GetParent():SetAbsOrigin(self.pos)
end

function modifier_imba_boulder_smash_motion:OnDestroy()
	if IsServer() and not self:GetParent():HasModifier("modifier_imba_stone_remnant_status") then
		FindClearSpaceForUnit(self:GetParent(), self:GetParent():GetAbsOrigin(), true)
		self.pos = nil
		self.direction = nil
		self.hitted = nil
	end
end

modifier_imba_boulder_smash_slow = class({})

function modifier_imba_boulder_smash_slow:IsDebuff()			return true end
function modifier_imba_boulder_smash_slow:IsHidden() 			return false end
function modifier_imba_boulder_smash_slow:IsPurgable() 			return true end
function modifier_imba_boulder_smash_slow:IsPurgeException() 	return true end
function modifier_imba_boulder_smash_slow:DeclareFunctions() return {MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE} end
function modifier_imba_boulder_smash_slow:GetModifierMoveSpeedBonus_Percentage() return (0 - self:GetAbility():GetSpecialValueFor("ms_slow")) end
function modifier_imba_boulder_smash_slow:GetEffectName() return "particles/units/heroes/hero_earth_spirit/espirit_bouldersmash_silence.vpcf" end
function modifier_imba_boulder_smash_slow:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end

modifier_imba_boulder_smash_silent = class({})

function modifier_imba_boulder_smash_silent:IsDebuff()			return true end
function modifier_imba_boulder_smash_silent:IsHidden() 			return false end
function modifier_imba_boulder_smash_silent:IsPurgable() 		return true end
function modifier_imba_boulder_smash_silent:IsPurgeException() 	return true end
function modifier_imba_boulder_smash_silent:GetEffectName() return "particles/generic_gameplay/generic_silence.vpcf" end
function modifier_imba_boulder_smash_silent:GetEffectAttachType() return PATTACH_OVERHEAD_FOLLOW end
function modifier_imba_boulder_smash_silent:ShouldUseOverheadOffset() return true end
function modifier_imba_boulder_smash_silent:CheckState() return {[MODIFIER_STATE_SILENCED] = true} end

imba_earth_spirit_rolling_boulder = class({})

LinkLuaModifier("modifier_imba_rolling_boulder_motion", "hero/hero_earth_spirit", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_imba_rolling_boulder_motion_delay", "hero/hero_earth_spirit", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_imba_rolling_boulder_slow", "hero/hero_earth_spirit", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_imba_rolling_boulder_extra_slow", "hero/hero_earth_spirit", LUA_MODIFIER_MOTION_NONE)

function imba_earth_spirit_rolling_boulder:IsHiddenWhenStolen() 	return false end
function imba_earth_spirit_rolling_boulder:IsRefreshable() 			return true end
function imba_earth_spirit_rolling_boulder:IsStealable() 			return true end
function imba_earth_spirit_rolling_boulder:IsNetherWardStealable()	return false end

function imba_earth_spirit_rolling_boulder:OnSpellStart()
	local caster = self:GetCaster()
	local pos = self:GetCursorPosition()
	local delay = self:GetSpecialValueFor("delay")
	local direction = (pos - caster:GetAbsOrigin()):Normalized()
	local speed = self:GetSpecialValueFor("speed")
	local distance = self:GetSpecialValueFor("distance")
	local speed_rock = self:GetSpecialValueFor("rock_speed")
	local distance_rock = self:GetSpecialValueFor("rock_distance")
	local buff = caster:AddNewModifier(caster, self, "modifier_imba_rolling_boulder_motion", {})
	buff.total = 0
	buff.direction = direction
	buff.speed = speed
	buff.distance = distance
	buff.speed_rock = speed_rock
	buff.distance_rock = distance_rock
	buff.hitted = {}
	caster:AddNewModifier(caster, self, "modifier_imba_rolling_boulder_motion_delay", {duration = delay})
	caster:StartGestureWithPlaybackRate(ACT_DOTA_CAST_ABILITY_2_ES_ROLL_START, 1.0 / delay)
	caster:EmitSound("Hero_EarthSpirit.RollingBoulder.Cast")
end

modifier_imba_rolling_boulder_motion_delay = class({})

function modifier_imba_rolling_boulder_motion_delay:IsDebuff()			return false end
function modifier_imba_rolling_boulder_motion_delay:IsHidden() 			return true end
function modifier_imba_rolling_boulder_motion_delay:IsPurgable() 		return false end
function modifier_imba_rolling_boulder_motion_delay:IsPurgeException() 	return false end

function modifier_imba_rolling_boulder_motion_delay:OnCreated()
	if IsServer() then
		self:StartIntervalThink(FrameTime())
	end
end

function modifier_imba_rolling_boulder_motion_delay:OnIntervalThink()
	if self:GetParent():IsStunned() or self:GetParent():IsNightmared() or self:GetParent():IsHexed() then
		self:GetParent():RemoveModifierByName("modifier_imba_rolling_boulder_motion")
		self:Destroy()
	end
end

function modifier_imba_rolling_boulder_motion_delay:OnDestroy()
	if IsServer() and self:GetParent():HasModifier("modifier_imba_rolling_boulder_motion") then
		local buff = self:GetParent():FindModifierByName("modifier_imba_rolling_boulder_motion")
		if buff:CheckMotionControllers() then
			buff:StartIntervalThink(FrameTime())
			self:GetParent():EmitSound("Hero_EarthSpirit.RollingBoulder.Loop")
		end
	end
end

modifier_imba_rolling_boulder_motion = class({})

function modifier_imba_rolling_boulder_motion:IsDebuff()			return false end
function modifier_imba_rolling_boulder_motion:IsHidden() 			return true end
function modifier_imba_rolling_boulder_motion:IsPurgable() 			return false end
function modifier_imba_rolling_boulder_motion:IsPurgeException() 	return false end
function modifier_imba_rolling_boulder_motion:IsMotionController() return true end
function modifier_imba_rolling_boulder_motion:GetMotionControllerPriority() return DOTA_MOTION_CONTROLLER_PRIORITY_LOW end
function modifier_imba_rolling_boulder_motion:CheckState() return {[MODIFIER_STATE_NO_UNIT_COLLISION] = true, [MODIFIER_STATE_ROOTED] = true, [MODIFIER_STATE_DISARMED] = true} end
function modifier_imba_rolling_boulder_motion:DeclareFunctions() return {MODIFIER_PROPERTY_OVERRIDE_ANIMATION} end
function modifier_imba_rolling_boulder_motion:GetOverrideAnimation() return ACT_DOTA_CAST_ABILITY_2_ES_ROLL end

function modifier_imba_rolling_boulder_motion:OnCreated()
	if IsServer() then
		local pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_earth_spirit/espirit_rollingboulder.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetParent())
		ParticleManager:SetParticleControlEnt(pfx, 3, self:GetParent(), PATTACH_ABSORIGIN_FOLLOW, "attach_hitloc", self:GetParent():GetAbsOrigin(), true)
		self:AddParticle(pfx, false, false, 15, false, false)
	end
end

function modifier_imba_rolling_boulder_motion:OnIntervalThink()
	local ability = self:GetAbility()
	if self:GetStackCount() == 0 then
		local stone = FindStoneRemnant(self:GetParent():GetAbsOrigin(), ability:GetSpecialValueFor("radius"))
		if stone then
			self:SetStackCount(1)
			self:GetParent():EmitSound("Hero_EarthSpirit.RollingBoulder.Stone")
			stone:ForceKill(false)
		end

		if self.total >= self.distance then
			self:Destroy()
			return
		end
		local distance = self.speed / (1.0 / FrameTime())
		if self.distance - self.total < distance then
			distance = self.distance - self.total
		end
		local next_pos = GetGroundPosition(self:GetParent():GetAbsOrigin() + self.direction * distance, nil)
		self.total = self.total + distance
		self:GetParent():SetAbsOrigin(next_pos)
	end
	if self:GetStackCount() == 1 then
		if self.total >= self.distance_rock then
			self:Destroy()
			return
		end
		local distance = self.speed_rock / (1.0 / FrameTime())
		if self.distance_rock - self.total < distance then
			distance = self.distance_rock - self.total
		end
		local next_pos = GetGroundPosition(self:GetParent():GetAbsOrigin() + self.direction * distance, nil)
		self.total = self.total + distance
		self:GetParent():SetAbsOrigin(next_pos)
	end
	GridNav:DestroyTreesAroundPoint(self:GetParent():GetAbsOrigin(), 80, true)
	local enemies = FindUnitsInRadius(self:GetParent():GetTeamNumber(), self:GetParent():GetAbsOrigin(), nil, ability:GetSpecialValueFor("radius"), DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
	for _, enemy in pairs(enemies) do
		if not IsInTable(enemy, self.hitted) then
			self.hitted[#self.hitted+1] = enemy
			ApplyDamage({victim = enemy, attacker = self:GetParent(), ability = ability, damage = ability:GetSpecialValueFor("damage"), damage_type = ability:GetAbilityDamageType()})
			if self:GetStackCount() == 1 then
				enemy:AddNewModifier(self:GetParent(), ability, "modifier_imba_rolling_boulder_slow", {duration = ability:GetSpecialValueFor("slow_duration")})
			end
			if enemy:IsRealHero() then
				enemy:EmitSound("Hero_EarthSpirit.RollingBoulder.Target")
				self:SetStackCount(2)
				local direction = (enemy:GetAbsOrigin() - self:GetParent():GetAbsOrigin()):Normalized()
				self:GetParent():SetAbsOrigin(enemy:GetAbsOrigin() + direction * 100)
				self:Destroy()
			end
		end
	end
end

function modifier_imba_rolling_boulder_motion:OnDestroy()
	if IsServer() then
		self:GetParent():EmitSound("Hero_EarthSpirit.RollingBoulder.Destroy")
		self:GetParent():StopSound("Hero_EarthSpirit.RollingBoulder.Loop")
	end
end

modifier_imba_rolling_boulder_slow = class({})

function modifier_imba_rolling_boulder_slow:IsDebuff()			return true end
function modifier_imba_rolling_boulder_slow:IsHidden() 			return false end
function modifier_imba_rolling_boulder_slow:IsPurgable() 		return true end
function modifier_imba_rolling_boulder_slow:IsPurgeException() 	return true end
function modifier_imba_rolling_boulder_slow:DestroyOnExpire() return false end
function modifier_imba_rolling_boulder_slow:DeclareFunctions() return {MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE} end
function modifier_imba_rolling_boulder_slow:GetModifierMoveSpeedBonus_Percentage() return (self:GetStackCount() == self:GetAbility():GetSpecialValueFor("slow_count") and (0 - self:GetAbility():GetSpecialValueFor("move_slow") or 0)) end

function modifier_imba_rolling_boulder_slow:OnCreated()
	if IsServer() then
		self:StartIntervalThink(0.1)
		self:SetStackCount(self:GetAbility():GetSpecialValueFor("slow_count"))
	end
end

function modifier_imba_rolling_boulder_slow:OnIntervalThink()
	if self:GetElapsedTime() >= self:GetDuration() then
		self:SetStackCount(self:GetStackCount() - 1)
		self:SetDuration(self:GetDuration(), true)
		self:GetParent():RemoveModifierByName("modifier_imba_rolling_boulder_extra_slow")
		self:GetParent():AddNewModifier(self:GetCaster(), self:GetAbility(), "modifier_imba_rolling_boulder_extra_slow", {duration = self:GetDuration()})
		if self:GetStackCount() == 0 then
			self:Destroy()
		end
	end
end

modifier_imba_rolling_boulder_extra_slow = class({})

function modifier_imba_rolling_boulder_extra_slow:IsDebuff()			return true end
function modifier_imba_rolling_boulder_extra_slow:IsHidden() 			return false end
function modifier_imba_rolling_boulder_extra_slow:IsPurgable() 			return true end
function modifier_imba_rolling_boulder_extra_slow:IsPurgeException() 	return true end
function modifier_imba_rolling_boulder_extra_slow:DeclareFunctions() return {MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE} end
function modifier_imba_rolling_boulder_extra_slow:GetModifierMoveSpeedBonus_Percentage() return (0 - self:GetAbility():GetSpecialValueFor("move_slow") * (self:GetRemainingTime() / self:GetDuration())) end
