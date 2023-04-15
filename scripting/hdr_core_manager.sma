#include <amxmodx>
#include <amxmisc>
#include <fakemeta_util>

#include <hdr_const>

#include <time>
#include <nvault>

new const PLUGIN[] = "HDR: Core Manager"
new const PLUGIN_CVAR[] = "hdr_core_manager"

// Global Variables
new bool:g_bRandomized, bool:g_bStarting, bool:g_bFirstRound, bool:g_bEnabled, bool:g_bRestart, bool:g_bConnected[MAX_PLAYERS + 1]
new g_iHudSync, g_iActivator, g_iNextActivator, g_iThinker

new g_pSvRestart, g_pAutoBalance, g_pLimitTeams

enum _:eCvars
{
	TOGGLE,
	BLOCK_SPRAY,
	BLOCK_RADIO,
	BLOCK_KILL,
	BLOCK_MONEY,
	GIVE_USP,
	GAME_NAME,
	NO_FALL_DAMAGE,
	REMOVE_BUY_ZONE,
	BLOCK_HUDS
}
new g_eCvars[eCvars]


enum _:eForwardIds
{
	PLAYER_SPAWN,
	ROUND_STARTED,
	ACTIVATORS_WIN,
	RUNNERS_WIN,
	NEW_ACTIVATOR,
	ROUND_END
}

new g_iForward[eForwardIds], g_iForwardReturns[eForwardIds]


new TeamName:g_iTeam[MAX_PLAYERS + 1]
new bool:g_bSolid[MAX_PLAYERS + 1]
new bool:g_bHasSemiclip[MAX_PLAYERS + 1]

#define SEMICLIP_DISTANCE 260.0 /* 512.0 */

// Playtime feature
new gVault
new g_iPlayer_Connections[MAX_PLAYERS + 1], g_iPlayer_PlayedTime[MAX_PLAYERS + 1]

stock get_user_total_playtime(id)
{
	return g_iPlayer_PlayedTime[id] + get_user_time(id)
}

public plugin_init()
{
	register_plugin(PLUGIN, MOD_VERSION, MOD_AUTHOR);
	register_cvar(PLUGIN_CVAR, MOD_VERSION, FCVAR_SERVER | FCVAR_SPONLY)
	set_cvar_string(PLUGIN_CVAR, MOD_VERSION)

	register_dictionary("time.txt")

	bind_pcvar_num(create_cvar("hdr_active", "1", FCVAR_NONE, "Whether the HDR Mod is enabled or not", true, 0.0, true, 1.0), g_eCvars[TOGGLE])
	bind_pcvar_num(create_cvar("hdr_block_spray", "1", FCVAR_NONE, "Whether player can spray on the map or not", true, 0.0, true, 1.0), g_eCvars[BLOCK_SPRAY])
	bind_pcvar_num(create_cvar("hdr_block_radio", "1", FCVAR_NONE, "Whether player can use radio menus", true, 0.0, true, 1.0), g_eCvars[BLOCK_RADIO])
	bind_pcvar_num(create_cvar("hdr_block_kill", "1", FCVAR_NONE, "Whether player can kill themself or not", true, 0.0, true, 1.0), g_eCvars[BLOCK_KILL])
	bind_pcvar_num(create_cvar("hdr_block_money", "1", FCVAR_NONE, "Whether player can view money hud or not", true, 0.0, true, 1.0), g_eCvars[BLOCK_MONEY])
	bind_pcvar_num(create_cvar("hdr_give_usp", "1", FCVAR_NONE, "Whether Runner(Ct) will spawn with USP", true, 0.0, true, 1.0), g_eCvars[GIVE_USP])
	bind_pcvar_num(create_cvar("hdr_custom_game_name", "1", FCVAR_NONE, "Whether there will be custom game name for the mod or not", true, 0.0, true, 1.0), g_eCvars[GAME_NAME])
	bind_pcvar_num(create_cvar("hdr_nfd_activator", "1", FCVAR_NONE, "Whether Activator(Terrorist) will be immune to fall damage", true, 0.0, true, 1.0), g_eCvars[NO_FALL_DAMAGE])
	bind_pcvar_num(create_cvar("hdr_remove_buyzone", "1", FCVAR_NONE, "Whether to remove buyzones from maps", true, 0.0, true, 1.0), g_eCvars[REMOVE_BUY_ZONE])
	bind_pcvar_num(create_cvar("hdr_remove_hud_messages", "1", FCVAR_NONE, "Whether hud messages to be printed out or not", true, 0.0, true, 1.0), g_eCvars[BLOCK_HUDS])

	// ReAPI
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultReload, "CBasePlayerWeapon_DefaultReload", true)
	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn", false)
	RegisterHookChain(RG_CBasePlayer_ImpulseCommands, "CBasePlayer_ImpulseCommands")
	RegisterHookChain(RG_CBasePlayer_GiveDefaultItems, "CBasePlayer_GiveDefaultItems")

	RegisterHookChain(RG_CSGameRules_FlPlayerFallDamage, "CSGameRules_FlPlayerFallDamage", true)
	RegisterHookChain(RG_CSGameRules_OnRoundFreezeEnd, "CSGameRules_OnRoundFreezeEnd")
	RegisterHookChain(RG_RoundEnd, "RoundEnd", true)

	// Terrorist Check
	g_iThinker = rg_create_entity("info_target")

	if (!is_nullent(g_iThinker))
	{
		set_entvar(g_iThinker, var_classname, "DeathRun_Thinker")
		set_entvar(g_iThinker, var_nextthink, get_gametime() + 20.0)

		g_bRestart = true

		SetThink(g_iThinker, "Thinking_Entity")
	}
	else
	{
		set_task_ex(15.0, "CheckTerrorists", .flags = SetTask_Repeat)
			
		// Lets make restart after 20 seconds from map start.
		set_task(20.0, "RestartRound")
	}

	// FakeMeta
	register_forward(FM_ClientKill, "FWD_ClientKill")

	register_forward(FM_PlayerPreThink, "FM__PlayerPreThink")
	register_forward(FM_PlayerPostThink, "FM__PlayerPostThink")
	register_forward(FM_AddToFullPack, "FM__AddToFullPack", 1)

	register_event_ex("ResetHUD", "eResetHUD_Ex", RegisterEvent_Single)


	g_iForward[ACTIVATORS_WIN] = CreateMultiForward("HDR_On_Activator_Win", ET_IGNORE, FP_CELL)
	g_iForward[RUNNERS_WIN] = CreateMultiForward("HDR_On_Runners_Win", ET_IGNORE, FP_CELL)
	g_iForward[ROUND_STARTED] = CreateMultiForward("HDR_On_Round_Started", ET_IGNORE, FP_CELL)
	g_iForward[PLAYER_SPAWN] = CreateMultiForward("HDR_On_Player_Spawn", ET_IGNORE, FP_CELL)
	g_iForward[NEW_ACTIVATOR] = CreateMultiForward("HDR_On_New_Activator", ET_IGNORE, FP_CELL)
	g_iForward[ROUND_END] = CreateMultiForward("HDR_On_Round_End", ET_IGNORE, FP_CELL)
	
	g_pSvRestart = get_cvar_pointer("sv_restart")
	g_pAutoBalance = get_cvar_pointer("mp_autoteambalance")
	g_pLimitTeams = get_cvar_pointer("mp_limitteams")

	register_clcmd("radio1", "Block_RadioCommands")
	register_clcmd("radio2", "Block_RadioCommands")
	register_clcmd("radio3", "Block_RadioCommands")

	// Playtime feature
	register_clcmd("say /pt", "Command_PlayTimeCheck")
	register_clcmd("say /playtime", "Command_PlayTimeCheck")

	gVault = nvault_open("HDR_PlayTime_Data")
	
	g_bFirstRound = true
	g_iHudSync = CreateHudSyncObj()
}

public plugin_natives()
{
	register_library("hdr_core")

	register_native("hdr_get_activator", "native_hdr_get_activator")
	register_native("hdr_get_next_activator", "native_hdr_get_next_activator")
	register_native("hdr_set_next_activator", "native_hdr_set_next_activator")

	register_native("hdr_get_user_playtime", "native_hdr_get_user_playtime")
}

public native_hdr_get_activator(iPlugin, iParams)
{
	return g_iActivator
}

public native_hdr_get_next_activator(iPlugin, iParams)
{
	return g_iNextActivator
}

public native_hdr_set_next_activator(iPlugin, iParams)
{
	enum
	{
		arg_index = 1
	}
	new id = get_param(arg_index)

	g_iNextActivator = id
}

public native_hdr_get_user_playtime(iPlugin, iParams)
{
	enum
	{
		arg_index = 1
	}
	new id = get_param(arg_index)

	return get_user_total_playtime(id)
}

public plugin_cfg()
{
	if (contain(MapName, "deathrun_") == -1 || !g_eCvars[TOGGLE])
		g_bEnabled = false
	else
		g_bEnabled = true

	if (g_eCvars[REMOVE_BUY_ZONE])
		rg_map_buy_status(true)
	else
		rg_map_buy_status(false)

	if (g_eCvars[GAME_NAME])
		set_member_game(m_GameDesc, "HDR")
	else
		set_member_game(m_GameDesc, "Counter-Strike")

}

public CBasePlayerWeapon_DefaultReload(const iWeapon, iClipSize, iAnim, Float:fDelay)
{
	new id = get_member(iWeapon, m_pPlayer)

	if (rg_get_user_active_weapon(id) == WEAPON_USP)
		set_task(fDelay, "Update_USP_BPAmmo", id)
}

public Update_USP_BPAmmo(id)
{
	if (is_user_alive(id) && rg_has_item_by_name(id, "weapon_usp"))
		rg_set_user_bpammo(id, WEAPON_USP, rg_get_weapon_info(WEAPON_USP, WI_MAX_ROUNDS))
}

public RoundEnd(WinStatus:iStatus, ScenarioEventEndRound:iEvent, Float:tmDelay)
{
	if (!g_bEnabled || g_bFirstRound)
		return HC_CONTINUE

	static iPlayers[MAX_PLAYERS], iNum, id

	switch(iEvent)
	{
		case ROUND_TERRORISTS_WIN, ROUND_HOSTAGE_NOT_RESCUED:
		{
			client_print(0, print_center, "Activators Win!")

			get_players_ex(iPlayers, iNum, GetPlayers_MatchTeam|GetPlayers_ExcludeBots, "TERRORIST")
			
			for (--iNum; iNum >= 0; iNum--)
			{
				id = iPlayers[iNum]
				
				rg_set_user_score(id, rg_get_user_frags(id) + 3, rg_get_user_deaths(id), true)
				ExecuteForward(g_iForward[ACTIVATORS_WIN], g_iForwardReturns[ACTIVATORS_WIN], id)
			}
		}
		case ROUND_CTS_WIN:
		{
			client_print(0, print_center, "Runners Win!")

			get_players_ex(iPlayers, iNum, GetPlayers_MatchTeam|GetPlayers_ExcludeBots, "CT")
			
			for (--iNum; iNum >= 0; iNum--)
			{
				id = iPlayers[iNum]
				ExecuteForward(g_iForward[RUNNERS_WIN], g_iForwardReturns[RUNNERS_WIN], id)
			}
		}
	}
	Randomize_Activator()
	ExecuteForward(g_iForward[ROUND_END], g_iForwardReturns[ROUND_END], 0)
	return HC_CONTINUE
}

public Randomize_Activator()
{
	if (!g_bEnabled || g_bFirstRound || g_bRandomized)
		return HDR_CONTINUE

	g_bRandomized = true

	new iPlayers[MAX_PLAYERS], iNum, id
	get_players_ex(iPlayers, iNum, GetPlayers_ExcludeBots)

	if (iNum <= 1)
		return HDR_CONTINUE

	static TeamName:iTeam

	if (!is_user_connected(g_iNextActivator))
	{
		g_iActivator = iPlayers[random(iNum)]
	}
	else
	{
		g_iActivator = g_iNextActivator
		g_iNextActivator = 0
	}

	iTeam = rg_get_user_team(g_iActivator)

	if (iTeam == HDR_ACTIVATOR || iTeam == HDR_RUNNER)
	{
		rg_set_user_team(g_iActivator, HDR_ACTIVATOR)

		PCC(0, "!t%n !yis now the !tActivator!y!", g_iActivator)

		if (!g_bRestart && !is_nullent(g_iThinker))
			set_entvar(g_iThinker, var_nextthink, get_gametime() + 15.0)
	}
	else
	{
		g_bRandomized = false
		Randomize_Activator()
	}

	for (--iNum; iNum >= 0; iNum--)
	{
		id = iPlayers[iNum]
		
		if (id != g_iActivator)
			rg_set_user_team(id, HDR_RUNNER)
	}

	ExecuteForward(g_iForward[NEW_ACTIVATOR], g_iForwardReturns[NEW_ACTIVATOR], g_iActivator)

	return HDR_CONTINUE
}

public CSGameRules_OnRoundFreezeEnd()
{
	if (!g_bEnabled)
		return HC_CONTINUE

	g_bRandomized = false
	g_bStarting = false

	static iActivatorsNum, iRunnersNum, iTotalPlayers

	iActivatorsNum = get_playersnum_ex(GetPlayers_ExcludeBots|GetPlayers_MatchTeam, "TERRORIST")
	iRunnersNum = get_playersnum_ex(GetPlayers_ExcludeBots|GetPlayers_MatchTeam, "CT")

	iTotalPlayers = iActivatorsNum + iRunnersNum

	if (iTotalPlayers <= 1)
	{
		if (g_eCvars[BLOCK_HUDS])
		{
			PCC(0, "Not enough players to start !gDeathrun!y!")
		}
		else
		{
			set_hudmessage(0, 128, 0, -1.0, 0.1, 0, 4.0, 4.0, 0.5, 0.5, 4)
			ShowSyncHudMsg(0, g_iHudSync, "Not enough players to start Deathrun!")
		}
		return HC_CONTINUE
	}

	set_pcvar_num(g_pAutoBalance, 0)
	set_pcvar_num(g_pLimitTeams, 0)

	if (g_bFirstRound)
	{
		if (g_eCvars[BLOCK_HUDS])
		{
			PCC(0, "Starting in!g 10 seconds!y.")
		}
		else
		{
			set_hudmessage(0, 128, 0, -1.0, 0.1, 0, 4.0, 4.0, 0.5, 0.5, 4)
			ShowSyncHudMsg(0, g_iHudSync, "Starting in 10 seconds.")
		}

		if (!is_nullent(g_iThinker))
		{
			g_bRestart = true
			set_entvar(g_iThinker, var_nextthink, get_gametime() + 9.0)
		} 
		else
		{
			set_task(9.0, "RestartRound")
		}
		
		g_bStarting = true
		g_bFirstRound = false
	}
	ExecuteForward(g_iForward[ROUND_STARTED], g_iForwardReturns[ROUND_STARTED], 0)
	return HC_CONTINUE
}

public Thinking_Entity(iEntity)
{
	if (g_bRestart)
	{
		g_bRestart = false
		RestartRound()
	}
	else
	{
		CheckActivators()
	}
	set_entvar(iEntity, var_nextthink, get_gametime() + 15.0)
}

public CheckActivators()
{
	if (!g_bEnabled || g_bFirstRound || g_bStarting)
		return HDR_CONTINUE

	static iActivatorsNum, iRunnersNum, iTotalPlayers

	iActivatorsNum = get_playersnum_ex(GetPlayers_ExcludeBots|GetPlayers_MatchTeam, "TERRORIST")
	iRunnersNum = get_playersnum_ex(GetPlayers_ExcludeBots|GetPlayers_MatchTeam, "CT")

	iTotalPlayers = iActivatorsNum + iRunnersNum

	if (iTotalPlayers <= 1)
	{
		if (g_eCvars[BLOCK_HUDS])
		{
			PCC(0, "Not enough players to start !gDeathrun!y!")
		}
		else
		{
			set_hudmessage(0, 128, 0, -1.0, 0.1, 0, 4.0, 4.0, 0.5, 0.5, 4)
			ShowSyncHudMsg(0, g_iHudSync, "Not enough players to start Deathrun!")
		}
		return HDR_CONTINUE
	}

	if (iActivatorsNum == 0)
	{
		new iPlayers[MAX_PLAYERS], iNum, id
		get_players_ex(iPlayers, iNum, GetPlayers_ExcludeDead|GetPlayers_MatchTeam, "CT")

		if (g_eCvars[BLOCK_HUDS])
		{
			PCC(0, "No !tterrorist !ydetected, restarting !gnow!y.")
		}
		else
		{
			set_hudmessage(0, 128, 0, -1.0, 0.1, 0, 4.0, 4.0, 0.5, 0.5, 4)
			ShowSyncHudMsg(0, g_iHudSync, "No terrorist detected, restarting now.")
		}
		
		for (--iNum; iNum >= 0; iNum--)
		{
			id = iPlayers[iNum]

			user_silentkill(id)
		}
		set_task(0.9, "Randomize_Activator")
	}
	return HDR_CONTINUE
}
public client_putinserver(id)
{
	g_bConnected[id] = true

	new szName[MAX_NAME_LENGTH]
	get_user_name(id, szName, charsmax(szName))
	set_task(0.1, "Load", id, szName, sizeof(szName))

	set_task(0.1, "Update_Teams_For_New_Connect", id)
}

public Update_Teams_For_New_Connect(id)
{
	if (is_user_connected(id) && get_member(id, m_iJoiningState) == JOINED)
	{
		if (rg_get_user_team(id) == HDR_ACTIVATOR)
			rg_set_user_team(id, HDR_RUNNER)
	}
}

public client_disconnected(id)
{
	g_bConnected[id] = false

	new szName[MAX_NAME_LENGTH]
	get_user_name(id, szName, charsmax(szName))
		
	Save(id, szName)

	if (id == g_iActivator)
	{
		static iActivatorsNum, iRunnersNum, iTotalPlayers

		iActivatorsNum = get_playersnum_ex(GetPlayers_ExcludeBots|GetPlayers_MatchTeam, "TERRORIST")
		iRunnersNum = get_playersnum_ex(GetPlayers_ExcludeBots|GetPlayers_MatchTeam, "CT")

		iTotalPlayers = iActivatorsNum + iRunnersNum

		if (iTotalPlayers >= 2)
		{
			g_iActivator = random(iRunnersNum)
			rg_set_user_team(g_iActivator, HDR_ACTIVATOR)
			rg_round_respawn(g_iActivator)

			ExecuteForward(g_iForward[NEW_ACTIVATOR], g_iForwardReturns[NEW_ACTIVATOR], g_iActivator)

			PCC(0, "!t%n!y has left the game. !g%n!y is now the !tActivator!y.", id, g_iActivator)
		}
	}
	else
	{
		CheckActivators()
	}
	
	if(!g_bRestart && !is_nullent(g_iThinker))
		set_entvar(g_iThinker, var_nextthink, get_gametime() + 15.0)
}

public CBasePlayer_GiveDefaultItems(id)
{
	if (is_user_alive(id) && g_bEnabled)
	{
		if (rg_get_user_team(id) == HDR_ACTIVATOR)
			rg_remove_all_items(id)
	}
}

public CBasePlayer_Spawn(id)
{
	if (is_user_alive(id) && g_bEnabled)
	{
		block_user_radio(id)

		rg_remove_all_items(id)
		rg_give_item(id, "weapon_knife")

		g_iTeam[id] = rg_get_user_team(id)

		if (g_eCvars[GIVE_USP] && rg_get_user_team(id) == HDR_RUNNER)
			rg_give_item_ex(id, "weapon_usp", GT_APPEND, -1, -1)

		ExecuteForward(g_iForward[PLAYER_SPAWN], g_iForwardReturns[PLAYER_SPAWN], id)
	}
}

public eResetHUD_Ex(id)
{
	if (g_bEnabled && g_eCvars[BLOCK_MONEY])
	{
		set_member(id, m_iHideHUD, HIDEHUD_FLASHLIGHT|HIDEHUD_MONEY)
	}
}

public FWD_ClientKill(const id)
{
	if (!g_bEnabled || !is_user_alive(id))
		return FMRES_IGNORED

	if (g_eCvars[BLOCK_KILL] || rg_get_user_team(id) == HDR_ACTIVATOR)
	{
		client_print(id, print_center, "You can't kill yourself!")
		client_print(id, print_console, "You can't kill yourself!")

		return FMRES_SUPERCEDE
	}
	return FMRES_IGNORED
}

public CBasePlayer_ImpulseCommands(const id)
{
	if (g_bEnabled && g_eCvars[BLOCK_SPRAY])
	{
		static iImpulse
		iImpulse = get_entvar(id, var_impulse)

		if (iImpulse == 201 && is_user_alive(id))
		{
			client_print(id, print_center, "Spray's not allowed on this server!")
			set_entvar(id, var_impulse, 0)
			return HC_SUPERCEDE
		}
	}
	return HC_CONTINUE
}
public CSGameRules_FlPlayerFallDamage(id)
{
	if (g_bEnabled && g_eCvars[NO_FALL_DAMAGE])
	{
		static Float:iFallDamage
		iFallDamage = Float:GetHookChainReturn(ATYPE_FLOAT)

		if (iFallDamage > 0.0)
		{
			SetHookChainReturn(ATYPE_FLOAT, 0.0)
			return HC_SUPERCEDE
		}
	}
	return HC_CONTINUE
}

public Block_RadioCommands(id)
{
	if (g_bEnabled && g_eCvars[BLOCK_RADIO])
		return HDR_HANDLED_MAIN

	return HDR_CONTINUE
}

public Command_PlayTimeCheck(id)
{
	if (is_user_connected(id))
	{
		new szTime[128]
		get_time_length(id, get_user_total_playtime(id), timeunit_seconds, szTime, charsmax(szTime))
		PCC(id, "Jumper: !g%n !y>> [!tPlayTime: !g%s !y| !tConnects: !g%i!y]", id, szTime, g_iPlayer_Connections[id])
		return HDR_CONTINUE
	}
	return HDR_HANDLED
}

public RestartRound()
{
	set_pcvar_num(g_pSvRestart, 1)
}

FirstThink()
{
	new iPlayers[MAX_PLAYERS], iNum, id
	get_players_ex(iPlayers, iNum, GetPlayers_ExcludeDead)

	for (--iNum; iNum >= 0; iNum--)
	{
		id = iPlayers[iNum]
		g_bSolid[id] = pev(id, pev_solid) == SOLID_SLIDEBOX ? true : false
	}
}

public FM__PlayerPreThink(id)
{
	static i, LastThink
	
	if (LastThink > id)
	{
		FirstThink()
	}
	
	LastThink = id

	if (!g_bSolid[id])
	{
		return FMRES_IGNORED
	}
	
	new iPlayers[MAX_PLAYERS], iNum
	get_players_ex(iPlayers, iNum, GetPlayers_ExcludeDead)

	for (--iNum; iNum >= 0; iNum--)
	{
		i = iPlayers[iNum]

		if (!g_bSolid[i] || id == i)
			continue

		if (g_iTeam[i] == g_iTeam[id])
		{
			set_pev(i, pev_solid, SOLID_NOT)
			g_bHasSemiclip[i] = true
		}
	}
	
	return FMRES_IGNORED
}

public FM__PlayerPostThink(id)
{
	new iPlayers[MAX_PLAYERS], iNum, iPlayer
	get_players_ex(iPlayers, iNum, GetPlayers_ExcludeDead)

	for (--iNum; iNum >= 0; iNum--)
	{
		iPlayer = iPlayers[iNum]

		if (g_bHasSemiclip[iPlayer])
		{
			set_pev(iPlayer, pev_solid, SOLID_SLIDEBOX)
			g_bHasSemiclip[iPlayer] = false
		}
	}
}

public FM__AddToFullPack(es, e, ent, host, hostflags, player, pSet)
{
	if (player)
	{
		static Float:flDistance
		flDistance = fm_entity_range(host, ent)
		
		if (g_bSolid[host] && g_bSolid[ent] && g_iTeam[host] == g_iTeam[ent] && flDistance < SEMICLIP_DISTANCE)
		{
			set_es(es, ES_Solid, SOLID_NOT)
			set_es(es, ES_RenderMode, kRenderTransAlpha)
			set_es(es, ES_RenderAmt, floatround(flDistance) / 1)
		}
	}
	
	return FMRES_IGNORED
}
// Mistrick
stock block_user_radio(id)
{
	const m_iRadiosLeft = 192;
	set_pdata_int(id, m_iRadiosLeft, 0);
}

// Playtime feature
public Load(szName[], id)
{
	if (!is_user_connected(id))
		return
	
	new szData[64]
	
	if(nvault_get(gVault, szName, szData, charsmax(szData)))
	{
		replace_all(szData, charsmax(szData), "#", " ")
		
		new szTime[32], szConnections[11]
		parse(szData, szTime, charsmax(szTime), szConnections, charsmax(szConnections))
		
		g_iPlayer_PlayedTime[id] = str_to_num(szTime)
		g_iPlayer_Connections[id] = str_to_num(szConnections)
		g_iPlayer_Connections[id]++
	} 
	else 
	{
		g_iPlayer_PlayedTime[id] = 0
		g_iPlayer_Connections[id] = 1
	}
}

public Save(id, szName[])
{
	new szData[64]
	formatex(szData, charsmax(szData), "%i#%i", get_user_total_playtime(id), g_iPlayer_Connections[id])
	nvault_set(gVault, szName, szData)
}