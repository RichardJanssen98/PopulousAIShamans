import(Module_System)
import(Module_Players)
import(Module_Defines)
import(Module_PopScript)
import(Module_Game)
import(Module_Objects)
import(Module_Map)
import(Module_Person)
import(Module_Commands)
include("UtilPThings.lua")
include("UtilRefs.lua")
include("AIShaman.lua")

computer_init_player(_gsi.Players[TRIBE_CYAN])

botSpells = {M_SPELL_BLAST}

for u,v in ipairs(botSpells) do
    PThing.SpellSet(TRIBE_CYAN, v, TRUE, FALSE)
end

WRITE_CP_ATTRIB(TRIBE_CYAN, ATTR_AWAY_BRAVE, 0)
WRITE_CP_ATTRIB(TRIBE_CYAN, ATTR_AWAY_MEDICINE_MAN, 100)

SET_MARKER_ENTRY(TRIBE_CYAN, 0, 4, 4, 1, 0, 0, 0)

cyanIsGoingToPray = 0
cyanPrayTick = 0
cyanCurrentCommand = nil
cyanGoingToDefend = 0
cyanDefendTick = 0

AIShamanCyan = AIShaman:new(nil, TRIBE_CYAN, 0, 1, 0, 0, 1, 0, 0, 0, 1, 10000, 7)

function OnTurn()
    --Simulate 160 pop for mana regen to reduce lag
    if (everyPow(1, 1)) then
        GIVE_MANA_TO_PLAYER(TRIBE_BLUE, 668)
        GIVE_MANA_TO_PLAYER(TRIBE_CYAN, 668)
    end
    
    if (GetTurn() > 128) then
       AIShamanCyan:handleShamanCombat()

       if (GetTurn() == 130) then
        MARKER_ENTRIES(TRIBE_CYAN, 0, -1, -1, -1)
       end
    end

    HandlePraying(TRIBE_CYAN, 200, 2, 92, 130)

    if (everyPow(120, 1) and cyanIsGoingToPray ~= 1) then --Stop the AI from spawn camping
        MOVE_SHAMAN_TO_MARKER(TRIBE_CYAN, 1)
    end

    if (cyanPrayTick > 0) then
      cyanPrayTick = cyanPrayTick - 1
    end

    if (cyanPrayTick == 0 and cyanIsGoingToPray == 1 and cyanCurrentCommand.CommandType ~= CMD_HEAD_PRAY) then
      cyanIsGoingToPray = 0
    end
end
function HandlePraying(pn, prayTick, headMarker, enemyHeadX, enemyHeadZ)
  local shaman = getShaman(pn)
  local enemyShaman = getShaman(TRIBE_BLUE)

  if (shaman ~= nil) then
    local cyanCurrentCommand = get_thing_curr_cmd_list_ptr(shaman)    
  end
  
  if (cyanCurrentCommand == nil) then
    cyanCurrentCommand = Commands.new()
    cyanCurrentCommand.CommandType = CMD_NONE
  end

  if (shaman ~= nil) then
    local c2d = Coord2D.new()
    map_xz_to_world_coord2d(enemyHeadX, enemyHeadZ, c2d)
    SearchMapCells(CIRCULAR, 0, 0, 2, world_coord2d_to_map_idx(c2d), function(me)
      me.MapWhoList:processList(function(t)
      if (t.Type == T_PERSON and t.Model == M_PERSON_MEDICINE_MAN) then
        if (t.Owner ~= pn and cyanGoingToDefend == 0) then
          command_person_go_to_coord2d(shaman, c2d)
          cyanGoingToDefend = 1
          cyanDefendTick = 60
        end
      end
      return true
    end)
    return true
    end)
    if (everyPow(prayTick, 1) and cyanIsGoingToPray == 0 and cyanGoingToDefend == 0) then
        PRAY_AT_HEAD(pn, 1, headMarker)
        cyanIsGoingToPray = 1
        cyanPrayTick = 360
    end
    
    if (enemyShaman == nil and cyanIsGoingToPray == 0) then
      PRAY_AT_HEAD(pn, 1, headMarker)
      cyanIsGoingToPray = 1
      cyanPrayTick = 360
    end
  end 

  if (cyanDefendTick > 0 and cyanGoingToDefend == 1) then
    cyanDefendTick = cyanDefendTick - 1 
    if (cyanDefendTick == 0) then
      cyanGoingToDefend = 0
    end
  end

  if (shaman ~= nil) then
      if (shaman.State == S_PERSON_DYING or shaman.State == S_PERSON_ELECTROCUTED or shaman.State == S_PERSON_DROWNING or enemyShaman ~= nil and cyanIsGoingToPray == 1) then
        cyanIsGoingToPray = 0
        cyanPrayTick = 0
        AIShamanCyan:setIgnoreChase(0)
      end
    elseif (cyanIsGoingToPray == 1) then
      cyanIsGoingToPray = 0
      cyanPrayTick = 0
      AIShamanCyan:setIgnoreChase(0)
    end
end