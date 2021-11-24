import(Module_System)
import(Module_Players)
import(Module_Defines)
import(Module_PopScript)
import(Module_Game)
import(Module_Objects)
import(Module_Map)
import(Module_Commands)
import(Module_Math)
import(Module_Person)
import(Module_Table)
include("UtilPThings.lua")
include("UtilRefs.lua")

AIPrayLogic = {}
AIPrayLogic.__index = AIPrayLogic

function AIPrayLogic:new(o, tribe, enemyTribe, idleMarker, defendAllyMarker, idleMovementDelay, tryPrayTick, headMarker, enemyDefendX, enemyDefendZ, objectiveHeadX, objectiveHeadZ, defendHeadX, defendHeadZ, defendMarkerX, defendMarkerZ)
	local o = o or {}
	setmetatable(o, AIPrayLogic)

	o.tribe = tribe
	o.idleMarker = idleMarker
	o.defendAllyMarker = defendAllyMarker
	o.idleMovementDelay = idleMovementDelay
	o.enemyTribe = enemyTribe
	o.tryPrayTick = tryPrayTick
	o.headMarker = headMarker
	o.enemyDefendX = enemyDefendX
	o.enemyDefendZ = enemyDefendZ

	o.allyPrayLogicList = {}
	o.MyShamanLogic = nil
	o.shaman = nil
	o.enemyShaman = nil
	o.closestEnemyShaman = nil

	o.isGoingToPray = 0
	o.calledAlliesForHelp = 0
	o.prayTick = 0
	o.currentCommand = 0
	o.won = 0
	o.goingToDefend = 0

	o.amIOnLocation = 0
	o.foundMyselfOnLocation = 0
	o.shamansOnDefendLocation = {}
	o.resetDefendingTick = -1
	o.shouldIBlastOutOfRange = 0

	o.objectiveHead = nil
	o.defendHead = nil
	o.objectiveHeadX = objectiveHeadX
	o.objectiveHeadZ = objectiveHeadZ
	o.defendHeadX = defendHeadX
	o.defendHeadZ = defendHeadZ
	o.inHeadRange = 0

	o.defendMarkerX = defendMarkerX
	o.defendMarkerZ = defendMarkerZ

	o.shamanDead = 0

	return o
end

function AIPrayLogic:SetShamanLogicAndAllyPrayLogic(myShamanLogic, allyPrayLogic)
	self.MyShamanLogic = myShamanLogic
	table.insert(self.allyPrayLogicList, allyPrayLogic)
	
	c2d = Coord2D.new()
	map_xz_to_world_coord2d(self.objectiveHeadX, self.objectiveHeadZ, c2d)
	SearchMapCells(CIRCULAR, 0, 0, 0, world_coord2d_to_map_idx(c2d), function(me)
		me.MapWhoList:processList(function(p)
			if (p.Type == T_GENERAL) then
				if (p.Model == M_GENERAL_TRIGGER) then
					self.objectiveHead = p
				end
			end
		return true
		end)
	return true
	end)

	map_xz_to_world_coord2d(self.defendHeadX, self.defendHeadZ, c2d)
	SearchMapCells(CIRCULAR, 0, 0, 0, world_coord2d_to_map_idx(c2d), function(me)
		me.MapWhoList:processList(function(p)
			if (p.Type == T_GENERAL) then
				if (p.Model == M_GENERAL_TRIGGER) then
					self.defendHead = p
				end
			end
		return true
		end)
	return true
	end)
end

function AIPrayLogic:HandleLogic()
	if (everyPow(self.idleMovementDelay, 1) and self.isGoingToPray == 0 and self.goingToDefend == 0 and self.MyShamanLogic:getIgnoreChase() == 0) then
		if (self:CheckIfAllyIsPraying() == 1) then
			MOVE_SHAMAN_TO_MARKER(self.tribe, self.defendAllyMarker)
		else
			MOVE_SHAMAN_TO_MARKER(self.tribe, self.idleMarker)
		end
	end

	self:UpdateVariables()
	self:HandlePraying()
end

function AIPrayLogic:CheckIfAllyIsPraying()
	local isAllyPraying = 0
	for _, ally in pairs (self.allyPrayLogicList) do
		if (ally.isGoingToPray == 1) then
			isAllyPraying = 1
			break
		end
	end

	return isAllyPraying
end

function AIPrayLogic:UpdateVariables()
	if (self.prayTick > 0) then
		self.prayTick = self.prayTick - 1
	end

	if (self.isGoingToPray == 1 and self.prayTick == 0 and self.currentCommand.CommandType ~= CMD_HEAD_PRAY) then
		self.isGoingToPray = 0
		self.MyShamanLogic:setIgnoreChase(0)
	end

	if (_gsi.Players[self.enemyTribe].NumPeople == 0 and self.won == 0) then
		self.won = 1
		self.MyShamanLogic:setIgnoreChase(0)
	end

	if (self.resetDefendingTick > 0) then
		self.resetDefendingTick = self.resetDefendingTick - 1
	end
end

function AIPrayLogic:HandlePraying()
	self.shaman = getShaman(self.tribe)
	self.enemyShaman = getShaman(self.enemyTribe)

	if (self.shaman ~= nil) then
		self.currentCommand = get_thing_curr_cmd_list_ptr(self.shaman)

		--On shaman respawn move immediately please.
		if (self.shamanDead == 1) then
			self.shamanDead = 0
			--log_msg(self.tribe, "Just reincarnated")
			if (self:CheckIfAllyIsPraying() == 1) then
				MOVE_SHAMAN_TO_MARKER(self.tribe, self.defendAllyMarker)
			else
				MOVE_SHAMAN_TO_MARKER(self.tribe, self.idleMarker)
			end
		end
	end

	if (self.currentCommand == nil) then
		self.currentCommand = Commands.new()
		self.currentCommand.CommandType = CMD_NONE
	end

	if (self.shaman ~= nil) then
		--Handle moving to defend allied Gargoyle
		local enemyc2d = Coord2D.new()
		self.amIOnLocation = 0

		map_xz_to_world_coord2d(self.enemyDefendX, self.enemyDefendZ, enemyc2d)
		self.shamansOnDefendLocation = {}

		SearchMapCells(CIRCULAR, 0, 0, 3, world_coord2d_to_map_idx(enemyc2d), function(me)
        me.MapWhoList:processList(function(t)
					table.insert(self.shamansOnDefendLocation, t)
        return true
      end)
    return true
    end)

		for i, sham in pairs(self.shamansOnDefendLocation) do
				if (sham.Type == T_PERSON and sham.Model == M_PERSON_MEDICINE_MAN and self.currentCommand.CommandType ~= CMD_HEAD_PRAY) then
					if (sham.Owner == self.tribe) then
						self.amIOnLocation = 1
						self.foundMyselfOnLocation = 1

						if (self.MyShamanLogic ~= nil) then
							self.MyShamanLogic:setIgnoreChase(0)
							self.MyShamanLogic:setOverrideDelayCast(1)
							self.MyShamanLogic:setOverrideEnrageBlast(1)
						end
						--log_msg(self.tribe, "On location")
						self.resetDefendingTick = 36
					end
        end
		end

		--Defend my ally praying if we are ahead by 40 ticks
		if (self.objectiveHead.u ~= nil and self.defendHead.u ~= nil) then
			if (self.objectiveHead.u.Trigger ~= nil and self.defendHead.u.Trigger ~= nil) then
				if (everyPow(24, 1) and self.objectiveHead.u.Trigger.PrayCount - 40 > self.defendHead.u.Trigger.PrayCount and self.currentCommand.CommandType ~= CMD_HEAD_PRAY) then
					local defendMarker2D = Coord2D.new()
					map_xz_to_world_coord2d(self.defendMarkerX, self.defendMarkerZ, defendMarker2D)

					if (get_world_dist_xz(defendMarker2D, self.shaman.Pos.D2) <= 2560) then
						self.MyShamanLogic:setIgnoreChase(0)
						self.MyShamanLogic:setOverrideDelayCast(1)
					else
						MOVE_SHAMAN_TO_MARKER(self.tribe, self.defendAllyMarker)
						self.MyShamanLogic:setIgnoreChase(1)
						self.MyShamanLogic:setOverrideDelayCast(1)
					end

					self.resetDefendingTick = 36
				end	
			end
		end

		if (self.foundMyselfOnLocation == 0) then
			if (self.objectiveHead.u ~= nil and self.defendHead.u ~= nil) then
				if (self.objectiveHead.u.Trigger ~= nil and self.defendHead.u.Trigger ~= nil) then
					for i, sham in pairs(self.shamansOnDefendLocation) do
						if ((sham.Owner == TRIBE_BLUE or sham.Owner == TRIBE_RED or sham.Owner == TRIBE_YELLOW or sham.Owner == TRIBE_GREEN) and self.goingToDefend == 0 and ((self.currentCommand.CommandType ~= CMD_HEAD_PRAY and self.objectiveHead.u.Trigger.PrayCount - 40 < self.defendHead.u.Trigger.PrayCount) or (self.currentCommand.CommandType == CMD_HEAD_PRAY and self.objectiveHead.u.Trigger.PrayCount - 8 < self.defendHead.u.Trigger.PrayCount))) then
							self.amIOnLocation = 0
							self.goingToDefend = 1
							self.isGoingToPray = 0
							self.prayTick = self.tryPrayTick
							command_person_go_to_coord2d(self.shaman, c2d)
							log_msg(self.tribe, "Defending")
							if (self.MyShamanLogic ~= nil) then
								self.MyShamanLogic:setIgnoreChase(1)
								self.MyShamanLogic:setOverrideDelayCast(1)
								self.MyShamanLogic:setOverrideEnrageBlast(0)
							end
						elseif (everyPow(self.idleMovementDelay, 1) and self.objectiveHead.u.Trigger.PrayCount - 40 > self.defendHead.u.Trigger.PrayCount and self.currentCommand.CommandType ~= CMD_HEAD_PRAY) then
							MOVE_SHAMAN_TO_MARKER(self.tribe, self.defendAllyMarker)
						end
					end
				end
			end
		end

		self.foundMyselfOnLocation = 0

		if (self.resetDefendingTick == 0) then
			self.resetDefendingTick = -1
			self.amIOnLocation = 0
			self.goingToDefend = 0
			self.isGoingToPray = 0
			self.prayTick = 0

			if (self.MyShamanLogic ~= nil) then
				self.MyShamanLogic:setIgnoreChase(0)
				self.MyShamanLogic:setOverrideDelayCast(0)
				self.MyShamanLogic:setOverrideEnrageBlast(0)
			end
			
			--log_msg(self.tribe, "ResetDefending")
		end
		------------------------------

		--Try to pray every now and then
		if (everyPow(self.tryPrayTick, 1) and self.isGoingToPray == 0 and self:CheckIfAllyIsPraying() == 0 and self.won == 0 and self.goingToDefend == 0) then
      PRAY_AT_HEAD(self.tribe, 1, self.headMarker)
      self.isGoingToPray = 1
      self.prayTick = self.tryPrayTick

			if (self.MyShamanLogic ~= nil) then
				self.MyShamanLogic:setIgnoreChase(1)
				self.MyShamanLogic:setOverrideDelayCast(1)
				self.MyShamanLogic:setOverrideEnrageBlast(0)
			end
      
			self.foundMyselfOnLocation = 0
			--log_msg(self.tribe, "Praying")
		end
		
		--If enemy shaman that I am linked to dies, go pray.
		if (self.enemyShaman == nil and self.isGoingToPray == 0 and self:CheckIfAllyIsPraying() == 0 and self.won == 0 and self.goingToDefend == 0) then
			PRAY_AT_HEAD(self.tribe, 1, self.headMarker)
			self.isGoingToPray = 1
			self.prayTick = self.tryPrayTick

			if (self.MyShamanLogic ~= nil) then
				self.MyShamanLogic:setIgnoreChase(1)
				self.MyShamanLogic:setOverrideDelayCast(1)
				self.MyShamanLogic:setOverrideEnrageBlast(0)
			end
				
			self.foundMyselfOnLocation = 0
			--log_msg(self.tribe, "Praying enemy dead")
		end
	end

	--If I am going to pray and enemy shaman is alive and I am currently not praying yet stop.
	if (self.isGoingToPray == 1 and self.enemyShaman ~= nil and self.currentCommand.CommandType ~= CMD_HEAD_PRAY) then
		self.isGoingToPray = 0
		self.prayTick = 0
		
		if (self.MyShamanLogic ~= nil) then
			self.MyShamanLogic:setIgnoreChase(0)
			self.MyShamanLogic:setOverrideDelayCast(0)
			self.MyShamanLogic:setOverrideEnrageBlast(0)
		end
		
		self.foundMyselfOnLocation = 0
		--log_msg(self.tribe, "Stop praying, enemy is Alive")
	end

	--Special logic on how to protect the shaman when she is praying and an enemy shaman is approaching.
	if (self.currentCommand.CommandType == CMD_HEAD_PRAY) then
		self.shouldIBlastOutOfRange = G_RANDOM(2) + 1
		self.inHeadRange = 0

		--50/50 chance the AI will try to keep approaching shamans at range
		--Only keep approaching shamans at range if I am actually ON the head
		if (self.shaman ~= nil) then
			if (self.shouldIBlastOutOfRange == 1) then
				SearchMapCells(CIRCULAR, 0, 0, 1, world_coord3d_to_map_idx(self.shaman.Pos.D3), function(me)
						me.MapWhoList:processList(function(t)
							if (t.Type == T_SCENERY) then
								if (t.Model == M_SCENERY_HEAD) then

									if (self.MyShamanLogic ~= nil) then
										self.MyShamanLogic:setOverrideEnrageBlast(1)
										self.inHeadRange = 1
										return false
									end
								end
							end
						return true
					end)
				return true
				end)
			end
		end

		--Stop waiting for enemy blasts during this, just keep blasting.
		if (self.MyShamanLogic ~= nil) then
			self.MyShamanLogic:setOverrideDelayCast(1)
		end	

		--If I am no longer near the gargoyle turn off special blasting behaviour.
		if (self.inHeadRange == 0) then
			self.MyShamanLogic:setOverrideEnrageBlast(0)
			self.MyShamanLogic:setOverrideDelayCast(0)
		end
	end

	--Call allies to defend me if I am praying and close to the head.
	if (self.shaman ~= nil) then
		local objc2d = Coord2D.new()
		map_xz_to_world_coord2d(self.objectiveHeadX, self.objectiveHeadZ, objc2d)

		if (self.currentCommand.CommandType == CMD_HEAD_PRAY and get_world_dist_xz(self.shaman.Pos.D2, objc2d) < 512 and self.isGoingToPray == 1 and self.calledAlliesForHelp == 0) then
			--log_msg(self.tribe, "Calling allies")
			self.calledAlliesForHelp = 1
			for i, al in pairs(self.allyPrayLogicList) do
				al:goDefendAlly()
			end
		end

		if (get_world_dist_xz(self.shaman.Pos.D2, objc2d) > 2500 and self.calledAlliesForHelp == 1) then
			self.calledAlliesForHelp = 0
		end
	end

	--Get closest enemy shaman and if they are casting while I am protecting an ally who is praying walk towards the ally so I get blasted towards them instead of away.
	self.closestEnemyShaman = self.MyShamanLogic:getTarget()
	local defendMarker2D = Coord2D.new()
	map_xz_to_world_coord2d(self.defendMarkerX, self.defendMarkerZ, defendMarker2D)

	if (self.closestEnemyShaman ~= nil and self.shaman ~= nil) then
		if (get_world_dist_xz(defendMarker2D, self.shaman.Pos.D2) >= 1500 and self.closestEnemyShaman.State == S_PERSON_SPELL_TRANCE and self:CheckIfAllyIsPraying() == 1) then
			--log_msg(self.tribe, "Moving back to Ally")
			MOVE_SHAMAN_TO_MARKER(self.tribe, self.defendAllyMarker)
		end
	end

	--Reset values if shaman is dead or dying.
	if (self.shaman ~= nil) then
		if (self.shaman.State == S_PERSON_DYING or self.shaman.State == S_PERSON_ELECTROCUTED or self.shaman.State  == S_PERSON_DROWNING and (self.isGoingToPray == 1 or self.goingToDefend == 1)) then
			self.isGoingToPray = 0
			self.goingToDefend = 0
			self.prayTick = 0
			self.foundMyselfOnLocation = 0
			self.shamanDead = 1
			self.calledAlliesForHelp = 0

			if (self.MyShamanLogic ~= nil) then
				self.MyShamanLogic:setIgnoreChase(0)
				self.MyShamanLogic:setOverrideDelayCast(0)
				self.MyShamanLogic:setOverrideEnrageBlast(0)
			end
			--log_msg(self.tribe, "Dieing")
		end
	elseif (self.isGoingToPray == 1 or self.goingToDefend == 1) then
		self.isGoingToPray = 0
		self.prayTick = 0
		self.goingToDefend = 0
		self.foundMyselfOnLocation = 0
		self.shamanDead = 1
		self.calledAlliesForHelp = 0
		
		if (self.MyShamanLogic ~= nil) then
			self.MyShamanLogic:setIgnoreChase(0)
			self.MyShamanLogic:setOverrideDelayCast(0)
			self.MyShamanLogic:setOverrideEnrageBlast(0)
		end
		--log_msg(self.tribe, "I am nil")
	end

	--Double check if ally isn't already praying
	if (self.shaman ~= nil) then
		if (self.isGoingToPray == 1 or self.currentCommand.CommandType == CMD_HEAD_PRAY) then
			if (self:CheckIfAllyIsPraying() == 1) then
				self.isGoingToPray = 0
				self.prayTick = 0
				self.calledAlliesForHelp = 0

				if (self.MyShamanLogic ~= nil) then
					self.MyShamanLogic:setIgnoreChase(0)
					self.MyShamanLogic:setOverrideDelayCast(0)
					self.MyShamanLogic:setOverrideEnrageBlast(0)
				end
				
				self.goingToDefend = 0
				self.foundMyselfOnLocation = 0
				self.currentCommand = Commands.new()
				self.currentCommand.CommandType = CMD_NONE
				--log_msg(self.tribe, "Ally is praying already")
			end
		end
	end

	--Am I praying and enemy is ahead? Stop and help defend.
	if (self.shaman ~= nil) then
		if (self.objectiveHead.u ~= nil and self.defendHead.u ~= nil) then
			if (self.objectiveHead.u.Trigger ~= nil and self.defendHead.u.Trigger ~= nil) then
				if (self.currentCommand.CommandType == CMD_HEAD_PRAY and self.objectiveHead.u.Trigger.PrayCount - 12 < self.defendHead.u.Trigger.PrayCount and self.defendHead.u.Trigger.PrayCount > 0) then
					self.amIOnLocation = 0
					self.goingToDefend = 1
					self.isGoingToPray = 0
					self.prayTick = self.tryPrayTick
					command_person_go_to_coord2d(self.shaman, c2d)
					--log_msg(self.tribe, "Defending1")
					if (self.MyShamanLogic ~= nil) then
						self.MyShamanLogic:setIgnoreChase(1)
						self.MyShamanLogic:setOverrideDelayCast(1)
						self.MyShamanLogic:setOverrideEnrageBlast(0)
					end
				end
			end
		end
	end
end

--Function that allies can call when they are going to pray to ask for back up.
function AIPrayLogic:goDefendAlly()
	if (self.defendHead.u ~= nil and self.objectiveHead.u ~= nil) then
		if (self.defendHead.u.Trigger ~= nil and self.objectiveHead.u.Trigger ~= nil) then
			if (self.objectiveHead.u.Trigger.PrayCount >= self.defendHead.u.Trigger.PrayCount) then
				local defendMarker2D = Coord2D.new()
				map_xz_to_world_coord2d(self.defendMarkerX, self.defendMarkerZ, defendMarker2D)

				MOVE_SHAMAN_TO_MARKER(self.tribe, self.defendAllyMarker)
				self.MyShamanLogic:setIgnoreChase(1)
				self.MyShamanLogic:setOverrideDelayCast(1)
			end
		end
	end
end