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
include("AIPrayLogic.lua")

computer_init_player(_gsi.Players[TRIBE_CYAN])
computer_init_player(_gsi.Players[TRIBE_PINK])
computer_init_player(_gsi.Players[TRIBE_BLACK])

botSpells = {M_SPELL_BLAST}
botAllies = {TRIBE_CYAN, TRIBE_PINK, TRIBE_BLACK}

for u,v in ipairs(botSpells) do
    PThing.SpellSet(TRIBE_CYAN, v, TRUE, FALSE)
end

for u,v in ipairs(botSpells) do
    PThing.SpellSet(TRIBE_PINK, v, TRUE, FALSE)
end

for u,v in ipairs(botSpells) do
    PThing.SpellSet(TRIBE_BLACK, v, TRUE, FALSE)
end

set_players_allied(TRIBE_BLUE, TRIBE_RED)
set_players_allied(TRIBE_RED, TRIBE_BLUE)
set_players_allied(TRIBE_BLUE, TRIBE_YELLOW)
set_players_allied(TRIBE_YELLOW, TRIBE_BLUE)
set_players_allied(TRIBE_RED, TRIBE_YELLOW)
set_players_allied(TRIBE_YELLOW, TRIBE_RED)

set_players_allied(TRIBE_CYAN, TRIBE_PINK)
set_players_allied(TRIBE_PINK, TRIBE_CYAN)
set_players_allied(TRIBE_CYAN, TRIBE_BLACK)
set_players_allied(TRIBE_BLACK, TRIBE_CYAN)
set_players_allied(TRIBE_PINK, TRIBE_BLACK)
set_players_allied(TRIBE_BLACK, TRIBE_PINK)

WRITE_CP_ATTRIB(TRIBE_CYAN, ATTR_AWAY_BRAVE, 0)
WRITE_CP_ATTRIB(TRIBE_CYAN, ATTR_AWAY_MEDICINE_MAN, 100)
WRITE_CP_ATTRIB(TRIBE_PINK, ATTR_AWAY_BRAVE, 0)
WRITE_CP_ATTRIB(TRIBE_PINK, ATTR_AWAY_MEDICINE_MAN, 100)
WRITE_CP_ATTRIB(TRIBE_BLACK, ATTR_AWAY_BRAVE, 0)
WRITE_CP_ATTRIB(TRIBE_BLACK, ATTR_AWAY_MEDICINE_MAN, 100)

SET_MARKER_ENTRY(TRIBE_CYAN, 0, 5, 5, 1, 0, 0, 0)
SET_MARKER_ENTRY(TRIBE_PINK, 1, 5, 5, 1, 0, 0, 0)
SET_MARKER_ENTRY(TRIBE_BLACK, 2, 5, 5, 1, 0, 0, 0)

AIShamanCyan = AIShaman:new(nil, TRIBE_CYAN, 1, 1, 1, 0, 1, botAllies, 0, 1, 1, 10000, 7)
AIShamanPink = AIShaman:new(nil, TRIBE_PINK, 1, 1, 1, 0, 1, botAllies, 0, 1, 1, 10000, 7)
AIShamanBlack = AIShaman:new(nil, TRIBE_BLACK, 1, 1, 1, 0, 1, botAllies, 0, 1, 1, 10000, 7)

AIPrayLogicCyan = AIPrayLogic:new(nil, TRIBE_CYAN, TRIBE_BLUE, 1, 4, 140, 200, 2, 92, 130, 156, 132, 84, 130, 146, 122)
AIPrayLogicPink = AIPrayLogic:new(nil, TRIBE_PINK, TRIBE_RED, 1, 4, 140, 200, 2, 92, 130, 156, 132, 84, 130, 146, 122)
AIPrayLogicBlack = AIPrayLogic:new(nil, TRIBE_BLACK, TRIBE_YELLOW, 1, 4, 140, 200, 2, 92, 130, 156, 132, 84, 130, 146, 122)

function OnTurn()
    --Simulate 160 pop for mana regen to reduce lag
    if (everyPow(1, 1)) then
        GIVE_MANA_TO_PLAYER(TRIBE_BLUE, 668)
        GIVE_MANA_TO_PLAYER(TRIBE_RED, 668)
        GIVE_MANA_TO_PLAYER(TRIBE_YELLOW, 668)
        GIVE_MANA_TO_PLAYER(TRIBE_CYAN, 668)
        GIVE_MANA_TO_PLAYER(TRIBE_PINK, 668)
        GIVE_MANA_TO_PLAYER(TRIBE_BLACK, 668)
    end

    if (GetTurn() > 128) then
       AIShamanCyan:handleShamanCombat()
       AIShamanPink:handleShamanCombat()
       AIShamanBlack:handleShamanCombat()

       if (GetTurn() == 130) then
        MARKER_ENTRIES(TRIBE_CYAN, 0, -1, -1, -1)
        MARKER_ENTRIES(TRIBE_PINK, 1, -1, -1, -1)
        MARKER_ENTRIES(TRIBE_BLACK, 2, -1, -1, -1)

        AIPrayLogicCyan:SetShamanLogicAndAllyPrayLogic(AIShamanCyan, AIPrayLogicPink)
        AIPrayLogicCyan:SetShamanLogicAndAllyPrayLogic(AIShamanCyan, AIPrayLogicBlack)

        AIPrayLogicPink:SetShamanLogicAndAllyPrayLogic(AIShamanPink, AIPrayLogicCyan)
        AIPrayLogicPink:SetShamanLogicAndAllyPrayLogic(AIShamanPink, AIPrayLogicBlack)

        AIPrayLogicBlack:SetShamanLogicAndAllyPrayLogic(AIShamanBlack, AIPrayLogicCyan)
        AIPrayLogicBlack:SetShamanLogicAndAllyPrayLogic(AIShamanBlack, AIPrayLogicPink)
       end
    end

    if (GetTurn() > 134) then
        AIPrayLogicCyan:HandleLogic()

        AIPrayLogicPink:HandleLogic()

        AIPrayLogicBlack:HandleLogic()
    end
end