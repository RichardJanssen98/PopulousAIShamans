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
include("UtilPThings.lua")
include("UtilRefs.lua")

AIShaman = {tribe = 0, blastAllowed = 0, lightningAllowed = 0, ghostsAllowed = 0, insectPlagueAllowed = 0, spellDelay = 0, ghostsSpecialDelay = 0, insectPlagueSpecialDelay = 0, dodgeLightning = 0,
allies = 0, dodgeBlast = 0, blastTrickAllowed = 0, overrideRechargeSpeed = 0, aggroRange = 0, maxDistanceFromWater = 0}
AIShaman.__index = AIShaman

function AIShaman:new (o, tribe, blastAllowed, lightningAllowed, ghostsAllowed, insectPlagueAllowed, dodgeLightning, allies, dodgeBlast, blastTrickAllowed, overrideRechargeSpeed, aggroRange, maxDistanceFromWater)
  local o = o or {}
  setmetatable(o, AIShaman)
  o.tribe = tribe
  o.blastAllowed = blastAllowed
  o.lightningAllowed = lightningAllowed
  o.ghostsAllowed = ghostsAllowed
  o.insectPlagueAllowed = insectPlagueAllowed
  o.dodgeLightning = dodgeLightning

  o.spellDelay = 0
  o.ghostsSpecialDelay = 0
  o.insectPlagueSpecialDelay = 0
  o.lightningSpecialDelay = 0

  o.enemyCastDelay = 0

  o.maxDistanceFromWater = maxDistanceFromWater

  o.allies = allies

  o.manaCostBlast = SPELL_COST(M_SPELL_BLAST)
  o.manaCostGhostArmy = SPELL_COST(M_SPELL_GHOST_ARMY)
  o.manaCostInsectPlague = SPELL_COST(M_SPELL_INSECT_PLAGUE)
  o.manaCostLightning = SPELL_COST(M_SPELL_LIGHTNING_BOLT)

  o.smartCastsBlast = 0
  o.smartCastsGhosts = 0
  o.smartCastsLightning = 0

  o.maxSmartCastsBlast = 4
  o.maxSmartCastsGhosts = 4
  o.maxSmartCastsLightning = 4
  o.aimLight = 0

  o.didDodgeOnCast = 0
  o.didDodgeOnCastTick = 0
  o.dodgeDelay = 12
  o.followEnemyDelay = 0

  o.blastTrickDelay = 0
  o.wasInBlastTrickRange = 0
  o.waitForEnemyBlast = nil
  o.waitForEnemyBlastTick = 0
  o.amIFlying = 0
  o.flyingShamanTick = 0

  o.overrideRechargeSpeed = overrideRechargeSpeed
  o.aggroRange = aggroRange
  o.blastTrickAllowed = blastTrickAllowed
  o.dodgeBlast = dodgeBlast

  o.nearWaterBool = 0
  o.targetThatIsInAir = nil
  o.chanceToHitAir = 0
  o.enemyShamanNearby = 0
  o.distToEnemyShaman = 0
  o.currentDistToEnemyShaman = 0
  o.overrideDelayCast = 0
  o.overrideEnrageBlast = 0

  o.blastsFailedUpdated = 0
  o.blastFailedTarget = nil
  o.blastsFailedBeforeAngry = 3
  o.blastBadMouthed = 0
  o.blastsFailed = 0
  o.lightsMissed = 0

  o.combatInitialized = 0
  o.maxMissedLightsBeforeRandomising = 4
  o.target = nil
  o.shaman = nil
  o.tribeName = nil
  o.isAlly = false

  o.ignoreChase = 0

  return o
end

function AIShaman:handleShamanCombat()
  self.shaman = getShaman(self.tribe)
  local enemyShamans = {}
  for i=0, 7 do 
    local tempShaman = getShaman(i)
    if (tempShaman ~= nil) then
      if (tempShaman.Owner ~= self.tribe) then
        --Check if the shaman is one of my allies
        if (self.allies ~= 0) then
          for _,v in pairs(self.allies) do
            if v == tempShaman.Owner then
              self.isAlly = true
              break
            else
              self.isAlly = false
            end
          end
        end

        --If it's not an ally add it to the enemyShamans list
        if (self.isAlly == false or tableLength(self.allies) < 1) then
          table.insert(enemyShamans, tempShaman)
        end
      end
    end
  end

  for i, t in pairs(enemyShamans) do
     --have to initialize once, otherwise it keeps resetting self.target as it doesn't always find an enemy in the list.
     if (self.combatInitialized == 0) then
        self.target = nil
        self.combatInitialized = 1
     end
     
     if (self.shaman ~= nil) then
       self.distToEnemyShaman = get_world_dist_xyz(self.shaman.Pos.D3, t.Pos.D3)
        if (self.distToEnemyShaman < self.aggroRange) then

          if (self.currentDistToEnemyShaman == 0) then
            self.target = t
            self.enemyShamanNearby = 1
            self.currentDistToEnemyShaman = self.distToEnemyShaman
          end
          
          if (self.distToEnemyShaman < self.currentDistToEnemyShaman) then
            self.target = t
            self.enemyShamanNearby = 1
            self.currentDistToEnemyShaman = self.distToEnemyShaman
          end
        end
     end
  end

  self.currentDistToEnemyShaman = 0

  if (self.tribe == 0) then
    self.tribeName = "Blue"
  elseif (self.tribe == 1) then
    self.tribeName = "Dakini"
  elseif (self.tribe == 2) then
    self.tribeName = "Chumara"
  elseif (self.tribe == 3) then
    self.tribeName = "Matak"
  elseif (self.tribe == 4) then
    self.tribeName = "Cyan"
  elseif (self.tribe == 5) then
    self.tribeName = "Magenta"
  elseif (self.tribe == 6) then
    self.tribeName = "Black"
  elseif (self.tribe == 7) then
    self.tribeName = "Orange"
  end

  if (self.shaman ~= nil) then
    if (self.target ~= nil) then
      self:resetSpellsMissed()
    end
    if (self.target ~= nil) then 
      self:handleBlastTrick()
      self:handleBlastEnrageVariables()
      self:dodgeSpellsAndFollowEnemyShaman()
      self:castGhostsOnShaman()
      self:castLightningOnShaman()
      self:castBlastOnShaman()
      self:sendGhostsToEnemyShaman()
    end

    self:defendShamanInMelee()
    self:counterGhostArmies()
    self:checkSpellDelay()
  end
end

--Reset enemy self.target and lights missed when the enemy shaman or my shaman dies
function AIShaman:resetSpellsMissed()
  if (self.target ~= nil) then
    if (self.enemyShamanNearby == 1 and (self.shaman == nil or self.target == nil or self.target.State == S_PERSON_DYING or self.target.State == S_PERSON_ELECTROCUTED)) then
      self.enemyShamanNearby = 0
      self.lightsMissed = 0
      self.blastsFailed = 0
      self.target = nil
    end

    if (self.target ~= nil) then
      if (get_world_dist_xyz(self.shaman.Pos.D3, self.target.Pos.D3) > self.aggroRange or self.target.State == S_PERSON_DYING or self.target.State == S_PERSON_ELECTROCUTED) then
        self.enemyShamanNearby = 0
        self.lightsMissed = 0
        self.blastsFailed = 0
        self.target = nil
      end
    else
      self.enemyShamanNearby = 0
      self.lightsMissed = 0
      self.blastsFailed = 0
    end
  else
    self.enemyShamanNearby = 0
    self.lightsMissed = 0
    self.blastsFailed = 0
  end
end

--Check if I can cast Swarm, if not then cast Blast if someone is fighting me
--Insect Plague will only be cast if the tribe has 4 times the cost, this due to Lightning Bolt being more important and it costs twice as much as Insect Plague.
--Thus the shaman will only cast Insect Plague if they would be able to cast two Lightning Bolts.
function AIShaman:defendShamanInMelee()
  if (self.shaman.State == S_PERSON_FIGHT_PERSON_2 and self.insectPlagueAllowed == 1 and MANA(self.tribe) > (self.manaCostInsectPlague * 4) and self.spellDelay == 0 and self.insectPlagueSpecialDelay == 0) then
    createThing(T_SPELL, M_SPELL_INSECT_PLAGUE, self.shaman.Owner, self.shaman.Pos.D3, false, false)
    self.spellDelay = 24
    self.insectPlagueSpecialDelay = 240
    self.blastTrickDelay = 12
    GIVE_MANA_TO_PLAYER(self.tribe, self.manaCostInsectPlague * -1)
    return false
  elseif (self.shaman.State == S_PERSON_FIGHT_PERSON_2 and self.blastAllowed == 1 and MANA(self.tribe) > self.manaCostBlast and self.spellDelay == 0  and self.smartCastsBlast < self.maxSmartCastsBlast) then
    createThing(T_SPELL, M_SPELL_BLAST, self.shaman.Owner, self.shaman.Pos.D3, false, false)
    self.spellDelay = 24
    self.smartCastsBlast = self.smartCastsBlast + 1
    self.blastTrickDelay = 12
    GIVE_MANA_TO_PLAYER(self.tribe, self.manaCostBlast * -1)
    return false
  end
end

function AIShaman:handleBlastTrick()
  --Extra check to make sure the shaman does not blast trick an enemy shaman outside of range.
  if (self.target ~= nil) then
    if (get_world_dist_xyz(self.shaman.Pos.D3, self.target.Pos.D3) < 1500 + self.shaman.Pos.D3.Ypos*3 and self.wasInBlastTrickRange == 0 and is_thing_on_ground(self.shaman) == 1) then
      self.wasInBlastTrickRange = 1
    elseif (get_world_dist_xyz(self.shaman.Pos.D3, self.target.Pos.D3) > 1500 + self.shaman.Pos.D3.Ypos*3 and is_thing_on_ground(self.shaman) == 1 and self.wasInBlastTrickRange == 1) then
      self.wasInBlastTrickRange = 0
    end
  end
  --Do the Blast Trick
  local groundHeightBelowShaman = point_altitude(self.shaman.Pos.D2.Xpos, self.shaman.Pos.D2.Zpos)
  if (((((self.shaman.Pos.D3.Ypos - groundHeightBelowShaman) <= 500 and (self.shaman.Pos.D3.Ypos - groundHeightBelowShaman) >= 300) and self.flyingShamanTick >= 5 and self.flyingShamanTick <= 12) or self.flyingShamanTick >= 13) and self.blastTrickAllowed == 1 and self.shaman.State ~= S_PERSON_ELECTROCUTED and get_world_dist_xyz(self.shaman.Pos.D3, self.target.Pos.D3) < 4000 and self.blastTrickDelay == 0 and self.smartCastsBlast < self.maxSmartCastsBlast and self.wasInBlastTrickRange == 1) then
    local blast = createThing(T_SPELL, M_SPELL_BLAST, self.shaman.Owner, self.target.Pos.D3, false, false)
    local rng_s_click = G_RANDOM(2) + 1

    if (rng_s_click == 1) then --Give the AI a 1/2 chance to S click the Blast Trick on the enemy
      blast.u.Spell.TargetThingIdx:set(self.target.ThingNum)
    end
    self.spellDelay = 24 + G_RANDOM(11)
    self.blastTrickDelay = 12
    self.smartCastsBlast = self.smartCastsBlast + 1
    GIVE_MANA_TO_PLAYER(self.tribe, self.manaCostBlast * -1)
    
    self.waitForEnemyBlast = G_RANDOM(10) + 1

    return false
  elseif (((((self.shaman.Pos.D3.Ypos - groundHeightBelowShaman) <= 500 and (self.shaman.Pos.D3.Ypos - groundHeightBelowShaman) >= 300) and self.flyingShamanTick >= 5 and self.flyingShamanTick <= 12) or self.flyingShamanTick >= 13) and self.blastTrickAllowed == 1 and self.shaman.State ~= S_PERSON_ELECTROCUTED and self.blastTrickDelay == 0 and self.smartCastsBlast < self.maxSmartCastsBlast) then --Blast myself if enemy is too far
    createThing(T_SPELL, M_SPELL_BLAST, self.shaman.Owner, self.shaman.Pos.D3, false, false)
    self.spellDelay = 24 + G_RANDOM(11)
    self.blastTrickDelay = 12
    self.smartCastsBlast = self.smartCastsBlast + 1
    GIVE_MANA_TO_PLAYER(self.tribe, self.manaCostBlast * -1)

    self.waitForEnemyBlast = G_RANDOM(10) + 1

    return false
  end
end

function AIShaman:handleBlastEnrageVariables()
  if (self.target ~= nil) then
    if (self.target.State == S_PERSON_SPELL_TRANCE and self.blastsFailedUpdated == 0 and get_world_dist_xyz(self.shaman.Pos.D3, self.target.Pos.D3) < 3500) then
      self.enemyCastDelay = 24
      self.blastsFailedUpdated = 1
      self.blastsFailed = self.blastsFailed + 1
      self.blastFailedTarget = self.target
    end
  end

  if (self.blastsFailedUpdated == 1 and self.blastFailedTarget ~= nil) then
    if (self.blastFailedTarget.State ~= S_PERSON_SPELL_TRANCE) then
      self.blastsFailedUpdated = 0
      self.blastFailedTarget = nil
    end
  end
end
      
function AIShaman:dodgeSpellsAndFollowEnemyShaman()
    local currentCommand = get_thing_curr_cmd_list_ptr(self.shaman)    

    if (currentCommand == nil) then
      currentCommand = Commands.new()
      currentCommand.CommandType = CMD_NONE
    end

    local onPosition = is_person_near_cmd_area(self.shaman, currentCommand)
    
  --Dodge lightning if needed, otherwise only try to dodge blast
    if (self.dodgeLightning == 1 and self.shaman.State ~= S_PERSON_FIGHT_PERSON_2) then
      --Dodge lightning being cast on me

      if (get_world_dist_xyz(self.target.Pos.D3, self.shaman.Pos.D3) < 5900 + self.target.Pos.D3.Ypos*3 and self.target.State == S_PERSON_SPELL_TRANCE) then
        SearchMapCells(CIRCULAR, 0, 0, 4, world_coord2d_to_map_idx(self.shaman.Pos.D2), function(me)
          if (is_map_elem_land_or_coast(me) > 0) then
            local c2d = Coord2D.new()
            map_ptr_to_world_coord2d(me, c2d)
            local c3d = Coord3D.new()
            coord2D_to_coord3D(c2d, c3d)
            if (get_world_dist_xyz(self.shaman.Pos.D3, c3d) >= 2000 and self.didDodgeOnCast == 0) then
              self.didDodgeOnCastTick = GetTurn() + 16
              command_person_go_to_coord2d(self.shaman, c2d)
              self.didDodgeOnCast = 1
              return false
            end
          end
          return true
        end)
      elseif (get_world_dist_xyz(self.target.Pos.D3, self.shaman.Pos.D3) < self.aggroRange and self.followEnemyDelay == 0 and MANA(self.tribe) > self.manaCostLightning * 2 and self.blastAllowed == 1 and (currentCommand.CommandType ~= CMD_HEAD_PRAY or (currentCommand.CommandType == CMD_HEAD_PRAY and onPosition == 0)) and self.ignoreChase == 0) then --If enemy in aggro range and I don't have enough mana for 2 lightning bolts walk to them,  but only if I can use blast
        local c2d = Coord2D.new()
        local m = MapPosXZ.new()
        m.Pos = world_coord3d_to_map_idx(self.target.Pos.D3)
        map_xz_to_world_coord2d(m.XZ.X, m.XZ.Z, c2d)
        command_person_go_to_coord2d(self.shaman, c2d)
        self.followEnemyDelay = 24
        self.dodgeDelay = 28
      elseif (everyPow(self.dodgeDelay, 1) and get_world_dist_xyz(self.target.Pos.D3, self.shaman.Pos.D3) < 6000 + self.target.Pos.D3.Ypos*3 and (currentCommand.CommandType ~= CMD_HEAD_PRAY or (currentCommand.CommandType == CMD_HEAD_PRAY and onPosition == 0)) and self.ignoreChase == 0) then
        SearchMapCells(CIRCULAR, 0, 0, 4, world_coord2d_to_map_idx(self.shaman.Pos.D2), function(me)
          if (is_map_elem_land_or_coast(me) > 0) then
            local c2d = Coord2D.new()
            map_ptr_to_world_coord2d(me, c2d)
            SearchMapCells(CIRCULAR, 0, 0, self.maxDistanceFromWater, world_coord2d_to_map_idx(c2d), function(meRoundTwo) --Check if this location is near water, if so do NOT dodge there
              if (is_map_elem_all_sea(meRoundTwo) > 0) then
                self.nearWaterBool = 1
                return false
              else
                return true
              end
            end)
            if (self.nearWaterBool == 1) then
              self.nearWaterBool = 0
              return true
            else
              local c3d = Coord3D.new()
              coord2D_to_coord3D(c2d, c3d)
              if (get_world_dist_xyz(self.shaman.Pos.D3, c3d) >= 2000 and self.didDodgeOnCast == 0) then
                command_person_go_to_coord2d(self.shaman, c2d)
                self.dodgeDelay = G_RANDOM(11)+20 --Dodge at least every second with a max delay of 2 seconds
                return false
              end
            end
          end
          return true
        end)
      elseif (get_world_dist_xyz(self.target.Pos.D3, self.shaman.Pos.D3) < self.aggroRange and self.followEnemyDelay == 0 and (currentCommand.CommandType ~= CMD_HEAD_PRAY or (currentCommand.CommandType == CMD_HEAD_PRAY and onPosition == 0)) and self.ignoreChase == 0) then --If enemy in aggro range walk towards them
        local c2d = Coord2D.new()
        local m = MapPosXZ.new()
        m.Pos = world_coord3d_to_map_idx(self.target.Pos.D3)
        map_xz_to_world_coord2d(m.XZ.X, m.XZ.Z, c2d)
        command_person_go_to_coord2d(self.shaman, c2d)
        self.followEnemyDelay = 36
      end
    elseif (self.dodgeBlast == 1 and self.shaman.State ~= S_PERSON_FIGHT_PERSON_2 and (currentCommand.CommandType ~= CMD_HEAD_PRAY or (currentCommand.CommandType == CMD_HEAD_PRAY and onPosition == 0)) and self.ignoreChase == 0) then   --Dodging blasts
      if (everyPow(self.dodgeDelay, 1) and get_world_dist_xyz(self.target.Pos.D3, self.shaman.Pos.D3) < 3092 + self.target.Pos.D3.Ypos*3) then
        SearchMapCells(CIRCULAR, 0, 0, 4, world_coord2d_to_map_idx(self.shaman.Pos.D2), function(me)
          if (is_map_elem_land_or_coast(me) > 0) then
            local c2d = Coord2D.new()
            map_ptr_to_world_coord2d(me, c2d)
            SearchMapCells(CIRCULAR, 0, 0, self.maxDistanceFromWater, world_coord2d_to_map_idx(c2d), function(meRoundTwo) --Check if this location is near water, if so do NOT dodge there
              if (is_map_elem_all_sea(meRoundTwo) > 0) then
                self.nearWaterBool = 1
                return false
              else
                return true
              end
            end)
            if (self.nearWaterBool == 1) then
              self.nearWaterBool = 0
              return true
            else
              local c3d = Coord3D.new()
              coord2D_to_coord3D(c2d, c3d)
              if (get_world_dist_xyz(self.shaman.Pos.D3, c3d) >= 2000 and self.didDodgeOnCast == 0) then
                command_person_go_to_coord2d(self.shaman, c2d)
                self.dodgeDelay = G_RANDOM(11)+20 --Dodge at least every second with a max delay of 2 seconds
                return false
              end
            end
          end
          return true
        end)
      elseif (get_world_dist_xyz(self.target.Pos.D3, self.shaman.Pos.D3) < self.aggroRange and self.followEnemyDelay == 0 and (currentCommand.CommandType ~= CMD_HEAD_PRAY or (currentCommand.CommandType == CMD_HEAD_PRAY and onPosition == 0)) and self.ignoreChase == 0) then
        local c2d = Coord2D.new()
        local m = MapPosXZ.new()
        m.Pos = world_coord3d_to_map_idx(self.target.Pos.D3)
        map_xz_to_world_coord2d(m.XZ.X, m.XZ.Z, c2d)
        command_person_go_to_coord2d(self.shaman, c2d)
        self.followEnemyDelay = 36
      end
    end
end

function AIShaman:castGhostsOnShaman()
  if (get_world_dist_xyz(self.shaman.Pos.D3, self.target.Pos.D3) < 3400 + self.shaman.Pos.D3.Ypos*3 and self.ghostsAllowed == 1 and MANA(self.tribe) > self.manaCostGhostArmy and self.spellDelay == 0 and self.ghostsSpecialDelay == 0 and self.smartCastsGhosts < self.maxSmartCastsGhosts and self.enemyCastDelay > 13 and self.enemyCastDelay < 36) then
    if (is_thing_on_ground(self.shaman) == 1) then
      createThing(T_SPELL, M_SPELL_GHOST_ARMY, self.shaman.Owner, self.target.Pos.D3, false, false)
      self.spellDelay = 24 + G_RANDOM(13)
      self.ghostsSpecialDelay = 120 + G_RANDOM(30)
      self.blastTrickDelay = 12
      self.smartCastsGhosts = self.smartCastsGhosts + 1
      GIVE_MANA_TO_PLAYER(self.tribe, self.manaCostGhostArmy * -1)
    end
  end

  --Send ghosts to enemy self.shaman.
  if (self.target ~= nil and self.shaman ~= nil) then
    if (everyPow(36, 1)) then
      self:sendGhostsToEnemyShaman()
    end
  end
end

function AIShaman:castLightningOnShaman()
  if (get_world_dist_xyz(self.shaman.Pos.D3, self.target.Pos.D3) < 5000 + self.shaman.Pos.D3.Ypos*3 and self.lightningAllowed == 1 and MANA(self.tribe) > self.manaCostLightning and self.spellDelay == 0 and self.lightningSpecialDelay == 0) then
    self.aimLight = 1
    local overrideMaxSmartCasts = 0
              
    --Give AI a random chance to S click after missing lights out of rage
    if (self.smartCastsLightning < self.maxSmartCastsLightning) then
      if (self.lightsMissed >= self.maxMissedLightsBeforeRandomising-1) then
        local giveUpAndSClick = G_RANDOM(2) + 1
        if (giveUpAndSClick == 1) then
          self.aimLight = 0
        end
      else --Give AI a small random chance to S click.
        local randomSClick = G_RANDOM(3) + 1
        if (randomSClick == 1) then
          self.aimLight = 0
        end
      end
    end
              
    --S Click when enemy too close and override max smart casts so AI prioritizes Lightning over Blast in close range
    if (get_world_dist_xyz(self.shaman.Pos.D3, self.target.Pos.D3) < 3000 + self.shaman.Pos.D3.Ypos*3) then
      self.aimLight = 0
      overrideMaxSmartCasts = 1
    end

    if (is_thing_on_ground(self.shaman) == 1 and self.aimLight == 0 and (self.smartCastsLightning < self.maxSmartCastsLightning or overrideMaxSmartCasts == 1)) then
      local light = createThing(T_SPELL, M_SPELL_LIGHTNING_BOLT, self.shaman.Owner, self.target.Pos.D3, false, false)
      light.u.Spell.TargetThingIdx:set(self.target.ThingNum)
      self.spellDelay = 24 + G_RANDOM(6)
      self.lightningSpecialDelay = 30 + G_RANDOM(20)
      self.blastTrickDelay = 12
      self.smartCastsLightning = self.smartCastsLightning + 1
      GIVE_MANA_TO_PLAYER(self.tribe, self.manaCostLightning * -1)
      return false
    elseif (is_thing_on_ground(self.shaman) == 1 and self.aimLight == 1) then
        self.lightsMissed = self.lightsMissed + 1
        local aimLoc = Coord3D.new()
        local c2d = Coord2D.new()
        local xLoc = 0
        local zLoc = 0

        --If I missed 2 lights then aim into a random direction (including if the self.target stood still)
        --There's a higher chance to aim in front instead of a random direction.
        if (self.target.State == S_PERSON_GOTO_BASE_AND_WAIT or self.target.State == S_PERSON_WAIT_AT_POINT or self.target.State == S_PERSON_SPELL_TRANCE) then
          xLoc = self.target.Pos.D3.Xpos
          zLoc = self.target.Pos.D3.Zpos
        elseif (self.lightsMissed <= self.maxMissedLightsBeforeRandomising) then
          xLoc = self.target.Pos.D3.Xpos + (10 * self.target.Move.Velocity.X)
          zLoc = self.target.Pos.D3.Zpos + (10 * self.target.Move.Velocity.Z)
        else
          local randomDirection = G_RANDOM(14)
          if (randomDirection == 0) then
            xLoc = self.target.Pos.D3.Xpos + (6 * self.target.Move.Velocity.X)
            zLoc = self.target.Pos.D3.Zpos + (-6 * self.target.Move.Velocity.Z)
          elseif (randomDirection == 1) then
            xLoc = self.target.Pos.D3.Xpos + (6 * self.target.Move.Velocity.X)
            zLoc = self.target.Pos.D3.Zpos + (self.target.Move.Velocity.Z)
          --Removed code for aiming straight behind. Keeping it commented just in case this needs to be turned on in the future.
          --elseif (randomDirection == 2) then
            --xLoc = self.target.Pos.D3.Xpos + (self.target.Move.Velocity.X)
            --zLoc = self.target.Pos.D3.Zpos + (6 * self.target.Move.Velocity.Z)
          elseif (randomDirection == 2) then
            xLoc = self.target.Pos.D3.Xpos
            zLoc = self.target.Pos.D3.Zpos
          elseif (randomDirection == 3) then
            xLoc = self.target.Pos.D3.Xpos + (self.target.Move.Velocity.X)
            zLoc = self.target.Pos.D3.Zpos + (-6 * self.target.Move.Velocity.Z)
          elseif (randomDirection == 4) then
            xLoc = self.target.Pos.D3.Xpos + (-6 * self.target.Move.Velocity.X)
            zLoc = self.target.Pos.D3.Zpos + (6 * self.target.Move.Velocity.Z)
          elseif (randomDirection == 5) then
            xLoc = self.target.Pos.D3.Xpos + (-6 * self.target.Move.Velocity.X)
            zLoc = self.target.Pos.D3.Zpos + (self.target.Move.Velocity.Z)
          elseif (randomDirection == 6) then
            xLoc = self.target.Pos.D3.Xpos + (-6 * self.target.Move.Velocity.X)
            zLoc = self.target.Pos.D3.Zpos + (-6 * self.target.Move.Velocity.Z)
          elseif (randomDirection >= 7) then --Aim in front just in case
            xLoc = self.target.Pos.D3.Xpos + (10 * self.target.Move.Velocity.X)
            zLoc = self.target.Pos.D3.Zpos + (10 * self.target.Move.Velocity.Z)
          end
        end
                  
        c2d.Xpos = xLoc
        c2d.Zpos = zLoc
        coord2D_to_coord3D(c2d, aimLoc)
        createThing(T_SPELL, M_SPELL_LIGHTNING_BOLT, self.shaman.Owner, aimLoc, false, false)
        self.spellDelay = 24 + G_RANDOM(6)
        self.lightningSpecialDelay = 30 + G_RANDOM(20)
        self.blastTrickDelay = 12

        --If it's not overridden then add smartcasts
        if (overrideMaxSmartCasts == 0) then
          self.smartCastsLightning = self.smartCastsLightning + 1
        end
                  
        GIVE_MANA_TO_PLAYER(self.tribe, self.manaCostLightning * -1)

        overrideMaxSmartCasts = 0
        return false
    end
  end
end

function AIShaman:castBlastOnShaman()
  --Check if the target is in the air so that the AI can play around that.
  if (self.waitForEnemyBlast == nil) then
    self.waitForEnemyBlast = G_RANDOM(10) + 1
  end

  if (is_thing_on_ground(self.target) == 0) then
    self.targetThatIsInAir = self.target
  end

  if (get_world_dist_xyz(self.shaman.Pos.D3, self.target.Pos.D3) < 2500 + self.shaman.Pos.D3.Ypos*3 and self.blastAllowed == 1 and MANA(self.tribe) > self.manaCostBlast and self.spellDelay == 0  and (self.smartCastsBlast < self.maxSmartCastsBlast and is_thing_on_ground(self.shaman) == 1 and ((self.targetThatIsInAir == self.target and self.chanceToHitAir == 1) or self.targetThatIsInAir ~= self.target)) and (self.waitForEnemyBlast >= 5 or self.overrideDelayCast == 1)) then   
    self.blastsFailed = 0

    local blast = createThing(T_SPELL, M_SPELL_BLAST, self.shaman.Owner, self.target.Pos.D3, false, false)
    blast.u.Spell.TargetThingIdx:set(self.target.ThingNum)
                
    self.spellDelay = 24 + G_RANDOM(25)
    self.blastTrickDelay = 12
    self.smartCastsBlast = self.smartCastsBlast + 1

    --Set chance for blasting enemy in the sky for the next blast
    self.chanceToHitAir = G_RANDOM(10) +1

    GIVE_MANA_TO_PLAYER(self.tribe, self.manaCostBlast * -1)

    self.waitForEnemyBlast = G_RANDOM(10) + 1
    return false
  end

  if (self.overrideEnrageBlast == 1) then
    if (get_world_dist_xyz(self.shaman.Pos.D3, self.target.Pos.D3) < 2500 and self.overrideEnrageBlast == 1) then
      self.overrideEnrageBlast = 0
      --log_msg(self.tribe, "Enemy in range")
    end
  end

  --Enraged blasts for when a player tries to exploit the AI by blasting them when they are not in range.
  local targetCurrentCommand = get_thing_curr_cmd_list_ptr(self.target)
  if (targetCurrentCommand == nil) then
    targetCurrentCommand = Commands.new()
    targetCurrentCommand.CommandType = CMD_NONE
  end

  local currentCommand = get_thing_curr_cmd_list_ptr(self.shaman)    
  if (currentCommand == nil) then
    currentCommand = Commands.new()
    currentCommand.CommandType = CMD_NONE
  end

  if ((get_world_dist_xyz(self.shaman.Pos.D3, self.target.Pos.D3) < 3800) and (self.blastsFailed >= self.blastsFailedBeforeAngry or (self.overrideEnrageBlast == 1 and (targetCurrentCommand.CommandType == CMD_HEAD_PRAY or currentCommand.CommandType == CMD_HEAD_PRAY))) and self.spellDelay == 0 and MANA(self.tribe) > self.manaCostBlast and is_thing_on_ground(self.shaman) == 1 and self.targetThatIsInAir ~= self.target and self.blastAllowed == 1) then
    if (get_world_dist_xyz(self.shaman.Pos.D3, self.target.Pos.D3) < 2500 and self.overrideEnrageBlast == 0) then
      self.blastsFailed = 0
      local blast = createThing(T_SPELL, M_SPELL_BLAST, self.shaman.Owner, self.target.Pos.D3, false, false)
      blast.u.Spell.TargetThingIdx:set(self.target.ThingNum)
                
      self.smartCastsBlast = self.smartCastsBlast + 1
      self.spellDelay = 24 + G_RANDOM(25)
    else
      if (self.blastBadMouthed == 0 and self.overrideEnrageBlast == 0) then
        log_msg(self.tribe, self.tribeName..": Fight me without that cheesy stuff, "..get_player_name(self.target.Owner, true))
        self.blastBadMouthed = 1
      end
                
      local aimLoc = Coord3D.new()
      local c2d = Coord2D.new()
      local xLoc = 0
      local zLoc = 0

      local deltaX = (virtPos(self.target.Pos.D3.Xpos) - virtPos(self.shaman.Pos.D3.Xpos))
      local deltaZ = (virtPos(self.target.Pos.D3.Zpos) - virtPos(self.shaman.Pos.D3.Zpos))


      local distanceToTarget = get_world_dist_xyz(self.shaman.Pos.D3, self.target.Pos.D3)

      xLoc = self.shaman.Pos.D3.Xpos + ((2700) * (deltaX/distanceToTarget))
      zLoc = self.shaman.Pos.D3.Zpos + ((2700) * (deltaZ/distanceToTarget))

      xLoc = math.floor(xLoc)
      zLoc = math.floor(zLoc)
              
      c2d.Xpos = xLoc
      c2d.Zpos = zLoc
      coord2D_to_coord3D(c2d, aimLoc)
      createThing(T_SPELL, M_SPELL_BLAST, self.shaman.Owner, aimLoc, false, false)
      --log_msg(self.tribe, "Blast Special")
      self.spellDelay = 16
                
      --Set chance for blasting enemy in the sky for the next blast
      self.chanceToHitAir = G_RANDOM(10) +1
    end

      self.blastTrickDelay = 12
      GIVE_MANA_TO_PLAYER(self.tribe, self.manaCostBlast * -1)
    return false
  end

  if (get_world_dist_xyz(self.shaman.Pos.D3, self.target.Pos.D3) < 2500 + self.shaman.Pos.D3.Ypos*3 and self.blastAllowed == 1 and MANA(self.tribe) > self.manaCostBlast and self.spellDelay == 0  and (self.smartCastsBlast < self.maxSmartCastsBlast and is_thing_on_ground(self.shaman) == 1 and ((self.targetThatIsInAir == self.target and self.chanceToHitAir == 1) or self.targetThatIsInAir ~= self.target)) and self.waitForEnemyBlast <= 4 and self.waitForEnemyBlastTick == 0) then
    self.waitForEnemyBlastTick = G_RANDOM(40) + 24
  end
end

--TO DO: call this and make sure "t" is filled by a preacher that is nearby the shaman.
--Call this function when in defend mode.
function AIShaman:combatPreachers()
  if (t.Owner ~= self.tribe and t.Model == M_PERSON_RELIGIOUS and self.isAlly == false and self.enemyShamanNearby == 0) then
    if (get_world_dist_xyz(self.shaman.Pos.D3, t.Pos.D3) < 2600 + self.shaman.Pos.D3.Ypos*3 and t.Model == M_PERSON_RELIGIOUS and self.blastAllowed == 1 and MANA(self.tribe) > self.manaCostBlast and self.spellDelay == 0  and self.smartCastsBlast < self.maxSmartCastsBlast) then
      if (is_thing_on_ground(self.shaman) == 1) then
        local blast = createThing(T_SPELL, M_SPELL_BLAST, self.shaman.Owner, t.Pos.D3, false, false)
        blast.u.Spell.TargetThingIdx:set(t.ThingNum)
        self.spellDelay = 24 + G_RANDOM(13)
        self.blastTrickDelay = 12
        self.smartCastsBlast = self.smartCastsBlast + 1
        --Set chance for blasting enemy in the sky for the next blast
        self.chanceToHitAir = G_RANDOM(10) +1

        GIVE_MANA_TO_PLAYER(self.tribe, self.manaCostBlast * -1)
        return false
      end
    end
    
    --Go towards a preacher.
    if (get_world_dist_xyz(self.shaman.Pos.D3, t.Pos.D3) < self.aggroRange and t.Model == M_PERSON_RELIGIOUS and self.followEnemyDelay == 0 and MANA(self.tribe) > self.manaCostBlast and self.blastAllowed == 1) then
      local c2d = Coord2D.new()
      local m = MapPosXZ.new()
      m.Pos = world_coord3d_to_map_idx(t.Pos.D3)
      map_xz_to_world_coord2d(m.XZ.X, m.XZ.Z, c2d)
      command_person_go_to_coord2d(self.shaman, c2d)
      self.followEnemyDelay = 24
      return false
    end
  end
end

function AIShaman:counterGhostArmies()  
  if (self.ghostsAllowed == 1 and everyPow(12, 1)) then
    SearchMapCells(CIRCULAR, 0, 0, 6, world_coord3d_to_map_idx(self.shaman.Pos.D3), function(me) 
      me.MapWhoList:processList(function(t)
        if (t.Type == T_PERSON) then
            if (self.allies ~= 0) then
              for _,v in pairs(self.allies) do
              if v == t.Owner then
                self.isAlly = true
                break
              else
                self.isAlly = false
              end
            end
          end

          if (t.Owner ~= self.tribe and self.isAlly == false and get_world_dist_xyz(self.shaman.Pos.D3, t.Pos.D3) < 3100 + self.shaman.Pos.D3.Ypos*3 and t.Flags2 & TF2_THING_IS_A_GHOST_PERSON ~= 0) then
            --Destroy ghost armies near me with ghost armies or blast if ghost armies are not ready
            if (get_world_dist_xyz(self.shaman.Pos.D3, t.Pos.D3) < 600 and self.blastAllowed == 1 and MANA(self.tribe) > self.manaCostBlast and self.spellDelay == 0) then
              if(is_thing_on_ground(self.shaman) == 1) then
                local blast = createThing(T_SPELL, M_SPELL_BLAST, self.shaman.Owner, t.Pos.D3, false, false)
                blast.u.Spell.TargetThingIdx:set(t.ThingNum)
                self.spellDelay = 12
                self.blastTrickDelay = 12
                GIVE_MANA_TO_PLAYER(self.tribe, self.manaCostBlast * -1)
                return false
              end
            elseif (get_world_dist_xyz(self.shaman.Pos.D3, t.Pos.D3) < 3000 + self.shaman.Pos.D3.Ypos*3 and self.ghostsAllowed == 1 and MANA(self.tribe) > self.manaCostGhostArmy and self.spellDelay == 0 and self.ghostsSpecialDelay == 0) then
              if(is_thing_on_ground(self.shaman) == 1) then
                local ghosts = createThing(T_SPELL, M_SPELL_GHOST_ARMY, self.shaman.Owner, t.Pos.D3, false, false)
                ghosts.u.Spell.TargetThingIdx:set(t.ThingNum)
                self.spellDelay = 12
                self.blastTrickDelay = 12
                self.ghostsSpecialDelay = 48
                GIVE_MANA_TO_PLAYER(self.tribe, self.manaCostGhostArmy * -1)
                return false
              end
            elseif (get_world_dist_xyz(self.shaman.Pos.D3, t.Pos.D3) < 1500 + self.shaman.Pos.D3.Ypos*3 and self.blastAllowed == 1 and MANA(self.tribe) > self.manaCostBlast and self.spellDelay == 0 and self.enemyCastDelay > 13 and self.enemyCastDelay < 36) then
              if(is_thing_on_ground(self.shaman) == 1) then
                local blast = createThing(T_SPELL, M_SPELL_BLAST, self.shaman.Owner, t.Pos.D3, false, false)
                blast.u.Spell.TargetThingIdx:set(t.ThingNum)
                self.spellDelay = 12 + G_RANDOM(13)
                self.blastTrickDelay = 12
                GIVE_MANA_TO_PLAYER(self.tribe, self.manaCostBlast * -1)
                return false
              end
            end
          end
        end
        return true
      end)
      return true
    end)
  end
end

function AIShaman:sendGhostsToEnemyShaman()
  local myGhosts = {}

  ProcessGlobalTypeList(T_PERSON, function(t)
    if (t.Owner == self.tribe and t.Flags2 & TF2_THING_IS_A_GHOST_PERSON ~= 0 and (t.State == S_PERSON_AWAITING_COMMAND or t.State == S_PERSON_WANDER or t.State == S_PERSON_WAIT_IN_BLDG or t.State == S_PERSON_WAIT_FIRST_APPEAR or t.State == S_PERSON_WAIT_AT_POINT or t.State == S_PERSON_BASE_WANDER or t.State == S_PERSON_UNDER_COMMAND)) then
      table.insert(myGhosts, t)
    end
    return true
  end)

  myUnitCount = tableLength(myGhosts)

  if (myUnitCount > 0) then
    for i, unit in pairs(myGhosts) do
      local cmd = Commands.new()
      cmd.CommandType = CMD_ATTACK_TARGET
      cmd.u.TargetIdx:set(self.target.ThingNum)
      unit.Flags = unit.Flags | (1<<4)
      add_persons_command(unit, cmd, 0)
    end
  end
end

function AIShaman:setIgnoreChase(value)
  self.ignoreChase = value
end

function AIShaman:setOverrideDelayCast(value)
  self.overrideDelayCast = value
end

function AIShaman:setOverrideEnrageBlast(value)
  self.overrideEnrageBlast = value
end

function AIShaman:getIgnoreChase()
  return self.ignoreChase
end

function AIShaman:getTarget()
  return self.target
end

function tableLength(Table)
  local count = 0
  for _ in pairs(Table) do count = count + 1 end
  return count
end

function AIShaman:checkSpellDelay()
  if (self.blastsFailed == 0 and self.blastBadMouthed == 1) then
    self.blastBadMouthed = 0
  end

  if (self.shaman ~= nil) then
    if (self.amIFlying == 0 and is_thing_on_ground(self.shaman) ~= 1) then
      self.amIFlying = 1 
      self.waitForEnemyBlast = G_RANDOM(10) + 1
    elseif (self.amIFlying == 1 and is_thing_on_ground(self.shaman) == 1) then
      self.amIFlying = 0
    end
  end

  if (self.shaman ~= nil) then
    if (self.blastsFailed >= 1 and self.shaman.State == S_PERSON_SPELL_TRANCE and is_thing_on_ground(self.shaman)) then
      self.blastsFailed = 0
    end
  end
  

  if (self.targetThatIsInAir ~= nil) then
    if (is_thing_on_ground(self.targetThatIsInAir) == 1) then
      self.targetThatIsInAir = nil
    end
  end

  if (self.shaman ~= nil) then
    if (is_thing_on_ground(self.shaman) ~= 1) then
      self.flyingShamanTick = self.flyingShamanTick + 1
    end
    if (is_thing_on_ground(self.shaman) == 1 and self.flyingShamanTick >= 1) then
      self.flyingShamanTick = 0
    end
  end

  if (self.waitForEnemyBlastTick >= 1) then
    self.waitForEnemyBlastTick = self.waitForEnemyBlastTick - 1
    
    if (self.waitForEnemyBlastTick == 0) then
      self.waitForEnemyBlast = 10
    end
  end

  --Update spellDelay each turn
  if (self.spellDelay > 0) then
    if (self.shaman ~= nil ) then
      if (self.spellDelay == 1 and is_thing_on_ground(self.shaman) ~= 1) then
      --Don't do it, otherwise there's a chance the shaman double blasts
      else
        self.spellDelay = self.spellDelay - 1
      end
    else
      self.spellDelay = 0
    end 
  end

  if (self.blastTrickDelay > 0) then
    if (self.shaman ~= nil) then
      if (self.blastTrickDelay == 1 and is_thing_on_ground(self.shaman) ~= 1) then
     --Don't do it, otherwise there's a chance the shaman double blasts
      else
        self.blastTrickDelay = self.blastTrickDelay - 1
      end
    else
      self.blastTrickDelay = 0
    end
    
  end

  --Update ghostsSpecialDelay each turn
  if (self.ghostsSpecialDelay > 0) then
    self.ghostsSpecialDelay = self.ghostsSpecialDelay - 1
  end

  if (self.lightningSpecialDelay > 0) then
    self.lightningSpecialDelay = self.lightningSpecialDelay - 1
  end

  if (self.enemyCastDelay > 0 ) then
    self.enemyCastDelay = self.enemyCastDelay - 1
  end

  if (self.insectPlagueSpecialDelay > 0) then
    self.insectPlagueSpecialDelay = self.insectPlagueSpecialDelay - 1
  end

  if (GetTurn() >= self.didDodgeOnCastTick) then
    self.didDodgeOnCast = 0
  end

  if (self.followEnemyDelay > 0 ) then
    self.followEnemyDelay = self.followEnemyDelay - 1
  end

  --Old code to give AI an artificial cooldown on spells instead of using actual mana, keeping it here just in case the AI using mana messes with their attack times
  --Can increase charge rate if more followers in future?
  --Half time at 80+ followers
  --Recharge smart casts of Blast (6 seconds)
  if (_gsi.Players[self.tribe].NumPeople < 80 and self.overrideRechargeSpeed == 0) then
    if (everyPow(72, 1)) then
      if (self.smartCastsBlast ~= 0) then
        self.smartCastsBlast = self.smartCastsBlast -1
      end
    end
    --Recharge smart casts of Lightning (30 seconds)
    if (everyPow(360, 1)) then
      if (self.smartCastsLightning ~= 0) then
        self.smartCastsLightning = self.smartCastsLightning -1
      end
    end

    --Recharge smart casts of Ghost Army (2 seconds)
    if (everyPow(24, 1)) then
      if (self.smartCastsGhosts ~= 0) then
        self.smartCastsGhosts = self.smartCastsGhosts -1
      end
    end
  elseif (_gsi.Players[self.tribe].NumPeople >= 80 or self.overrideRechargeSpeed == 1) then
    --Recharge smart casts of Blast (3 seconds)
    if (everyPow(36, 1)) then
      if (self.smartCastsBlast ~= 0) then
        self.smartCastsBlast = self.smartCastsBlast -1
      end
    end
    --Recharge smart casts of Lightning (15 seconds)
    if (everyPow(180, 1)) then
      if (self.smartCastsLightning ~= 0) then
        self.smartCastsLightning = self.smartCastsLightning -1
      end
    end

    --Recharge smart casts of Ghost Army (1 seconds)
    if (everyPow(12, 1)) then
      if (self.smartCastsGhosts ~= 0) then
        self.smartCastsGhosts = self.smartCastsGhosts -1
      end
    end
  end
end

function virtPos(pos)
  if (pos < 0) then
    pos = pos + 65535
  end
  return pos
end