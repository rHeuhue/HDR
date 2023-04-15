#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <sqlx>

#include <hdr_const>

new const PLUGIN[] = "HDR: Lives System"
new const PLUGIN_CVAR[] = "hdr_lives_system"

//#define NEW_SQL
#define NEEDED_ACCESS ADMIN_RCON
#define LOG_FILE

#define EXPENSIVE_RESPAWN

enum _:PlData
{
	gLoaded,
	gAuthed,
	gLifes,
	gIncreaseLifes,
	gVip,
	gHudVip
}

new UserData[MAX_PLAYERS + 1][PlData]

new bool:g_Sql_Ready = false

new Handle:g_SqlConnection
new Handle:g_SqlTuple

new g_Error[512]

new g_iMaxPlayers

new const DataBase[] = "dr_lifes"

#define UPDATE_INTERVAL 1.0
#define NEXT_UPDATE 0.6

new const g_szClassNameHud[] = "LifesHud"
new g_iSync

enum
{
	SECTION_SYSTEM = 1,
	SECTION_CVARS,
	SECTION_HUD_MESSAGE
}

enum _:DataItems
{
	LS_VIP_FLAG[6],
	LS_MAX_LIVES,
	LS_KILL,
	LS_HEADSHOT,
	LS_HEGRENADE,
	LS_KILLER_MESSAGE,
	LS_D_HUD_STATUS,
	LS_D_HUD_MESSAGE,
	LS_D_HUD_CUSTOM_COLOR,
	LS_HUD_COLOR_RED,
	LS_HUD_COLOR_GREEN,
	LS_HUD_COLOR_BLUE,
	Float:LS_HUD_COORD_X,
	Float:LS_HUD_COORD_Y,
	LS_HUD_EFFECTS
}

new g_eItems[DataItems]

new Float:g_iNextGamble[33]

#if defined EXPENSIVE_RESPAWN
new g_iRespawnCounter[33]
#endif

#if defined LOG_FILE
new g_szLogFile[128]
#endif

public plugin_init()
{
	register_plugin(PLUGIN, MOD_VERSION, MOD_AUTHOR)
	register_cvar(PLUGIN_CVAR, MOD_VERSION, FCVAR_SERVER | FCVAR_SPONLY)
	set_cvar_string(PLUGIN_CVAR, MOD_VERSION)
	
	register_event("DeathMsg", "HookDeathMsg", "a")
	register_forward(FM_Sys_Error, "fw_ServerDown")
	register_forward(FM_GameShutdown, "fw_ServerDown")
	register_forward(FM_ServerDeactivate, "fw_ServerDown")
	register_forward(FM_ClientUserInfoChanged, "fwdClientUserInfoChanged")
	
	register_clcmd("say", "hook_say")
	register_clcmd("say_team", "hook_say")
	
	register_clcmd("Lives_Amount", "Command_Lives_Amount", NEEDED_ACCESS)
	register_concmd("amx_reload_lives", "Command_ReloadFile", ADMIN_BAN)
	
	#if defined EXPENSIVE_RESPAWN
	register_logevent("eRoundEnded", 2, "1=Round_End")
	#endif
	
	g_iSync = CreateHudSyncObj()
	
	g_iMaxPlayers = get_maxplayers()
	
	set_task(25.0, "AdvertiseCommands", .flags="b")
}
#if defined EXPENSIVE_RESPAWN
public eRoundEnded()
{
	for (new id = 0; id <= g_iMaxPlayers; id++)
	{
		if(is_user_connected(id))
			g_iRespawnCounter[id] = 0
	}
}
#endif
public Command_ReloadFile(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED
	
	ReadCvarsFile()
		
	return PLUGIN_HANDLED
}
public plugin_precache()
{
	ReadCvarsFile()
	set_task(1.0, "MySql_Init")
	
	#if defined LOG_FILE
	new szLogDir[] = "addons/amxmodx/logs/Lives_System_Logs"
	if(!dir_exists(szLogDir))
	{
		mkdir(szLogDir)
	}
	
	new szDate[16], szTitle[126]
	get_time("%Y%m%d", szDate, charsmax(szDate))
		
	formatex(g_szLogFile, charsmax(g_szLogFile), "%s/lives_system_%s.txt", szLogDir, szDate)
	if(!file_exists(g_szLogFile))
	{
		new szTimeCode[2][16]
		get_time("%d.%m.%Y", szTimeCode[0], charsmax(szTimeCode[]))
		get_time("%H:%M:%S", szTimeCode[1], charsmax(szTimeCode[]))
		formatex(szTitle, charsmax(szTitle), ">> %s <<^n>> Lives System <<^n>> Started at: %s, %s <<", MOD_PREFIX, szTimeCode[0], szTimeCode[1])
		write_file(g_szLogFile, szTitle)
	}
	#endif
}
ReadCvarsFile()
{
	static szConfigsDir[64], iFile, szCvarFile[64]
	get_configsdir(szConfigsDir, charsmax(szConfigsDir))
	formatex(szCvarFile, charsmax(szCvarFile), "/HDR_Lives.ini")
	add(szConfigsDir, charsmax(szConfigsDir), szCvarFile)
	iFile = fopen(szConfigsDir, "rt")
	
	if (iFile)
	{
		static szLineData[160], szKey[32], szValue[128], iSection
		
		while (!feof(iFile))
		{
			fgets(iFile, szLineData, charsmax(szLineData))
			trim(szLineData)
			
			switch (szLineData[0])
			{
				case EOS, ';': continue
				case '[':
				{
					if (szLineData[strlen(szLineData) - 1] == ']')
					{
						if (containi(szLineData, "ls core") != -1)
							iSection = SECTION_SYSTEM
						else if (containi(szLineData, "ls cvars") != -1)
							iSection = SECTION_CVARS
						else if (containi(szLineData, "ls hud") != -1)
							iSection = SECTION_HUD_MESSAGE
					}					
					else
						continue
				}
				default:
				{
					strtok(szLineData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=')
					trim(szKey)
					trim(szValue)
					
					if (is_eos_line(szValue))
						continue
						
					switch(iSection)
					{
						case SECTION_SYSTEM:
						{
							if (equal(szKey, "LS_VIP_FLAG"))
								copy(g_eItems[LS_VIP_FLAG], charsmax(g_eItems[LS_VIP_FLAG]), szValue)
						}
						case SECTION_CVARS:
						{
							if (equal(szKey, "LS_MAX_LIVES"))
								g_eItems[LS_MAX_LIVES] = str_to_num(szValue)
							else if (equal(szKey, "LS_KILL"))
								g_eItems[LS_KILL] = str_to_num(szValue)
							else if (equal(szKey, "LS_HEADSHOT"))
								g_eItems[LS_HEADSHOT] = str_to_num(szValue)
							else if (equal(szKey, "LS_HE_GRENADE"))
								g_eItems[LS_HEGRENADE] = str_to_num(szValue)
							else if (equal(szKey, "LS_KILLER_MESSAGE"))
								g_eItems[LS_KILLER_MESSAGE] = clamp(on_off(szValue),false, true)
						}
						case SECTION_HUD_MESSAGE:
						{
							if (equal(szKey, "LS_D_HUD_MESSAGE_STATUS"))
							{
								g_eItems[LS_D_HUD_STATUS] = clamp(on_off(szValue), false, true)
								
								if (g_eItems[LS_D_HUD_STATUS])
								{
									new iEnt = rg_create_entity("info_target")

									if (!is_nullent(iEnt))
									{
										set_entvar(iEnt, var_classname, g_szClassNameHud)
										set_entvar(iEnt, var_nextthink, get_gametime() + UPDATE_INTERVAL)

										SetThink(iEnt, "displayLifesHud")
									}
								}
							}
							else if (equal(szKey, "LS_D_HUD_MESSAGE"))
								g_eItems[LS_D_HUD_MESSAGE] = clamp(hud_dhud(szValue), false, true)
							else if (equal(szKey, "LS_D_HUD_COORD_X"))
								g_eItems[LS_HUD_COORD_X] = _:str_to_float(szValue)
							else if (equal(szKey, "LS_D_HUD_COORD_Y"))
								g_eItems[LS_HUD_COORD_Y] = _:str_to_float(szValue)
							else if (equal(szKey, "LS_D_HUD_EFFECTS"))
								g_eItems[LS_HUD_EFFECTS] = str_to_num(szValue)
						}
					}
				}
			}
		}
		fclose(iFile)
	}
}

stock bool:is_eos_line(szString[]) return szString[0] == EOS ? true : false
stock bool:hud_dhud(szString[]) return szString[0] == 'd' ? true : false
stock bool:on_off(szString[]) return szString[1] == 'n' ? true : false

public AdvertiseCommands()
{
	for (new id = 1; id <= 32; id++)
	{
		if (!is_user_connected(id))
			continue
		
		switch(random_num(0, 5))
		{
			case 0: 
			{
				if (!UserData[id][gVip])
				{
					PCC(id, "Write in chat!g /vip!y or !g/getvip!y to see how to become!t VIP!y.")
				}
				else
				{
					PCC(id, "Write in chat !g/lifes!y or !g/mylifes!y to see your own lifes.")
				}
			}
			case 1:
			{
				if (g_eItems[LS_D_HUD_STATUS])
				{
					PCC(id, "Write in chat !g/viphud!y to !tenable!y/!tdisable!g VIP Hud Status!y.")
				}
				else
				{
					PCC(id, "Write in chat !g/respawn!y or !g/revive!y to use life.")
				}
			}
			case 2: PCC(id, "Write in chat !g/respawn!y or !g/revive!y to use life.");
			case 3: PCC(id, "Write in chat !g/give !t<!gname!t> <!glife amount!t> !yto give other player lifes.")
			case 4: PCC(id, "Write in chat !g/lifes!y or !g/mylifes!y to see your own lifes.")
			case 5: PCC(id, "Write in chat !g/gamble !t<!gamount!t> !yto try your luck!")
		}
		//Save_MySql(id)
	}
}

public fw_ServerDown()
{ 
	for (new id = 0; id <= g_iMaxPlayers; id++)
	{
		if (is_user_connected(id))
		{
			#if defined NEW_SQL
			new szName[32]
			get_user_name(id, szName, charsmax(szName))
			Save_Data(id, szName)
			#else
			Save_MySql(id)
			#endif
		}
	}
}

public displayLifesHud(iEnt)
{
	if (g_eItems[LS_D_HUD_STATUS])
	{
		if(is_nullent(iEnt))
			return
		
		new iPlayers[32], iNum, id, ef = g_eItems[LS_HUD_EFFECTS], Float:x = g_eItems[LS_HUD_COORD_X], Float:y = g_eItems[LS_HUD_COORD_Y]
		get_players(iPlayers, iNum, "ach")
		
		for (new i = 0; i < iNum; i++)
		{
			id = iPlayers[i]
			UserData[id][gVip] = (get_user_flags(id) & read_flags(g_eItems[LS_VIP_FLAG])) ? true : false
			new iLives = UserData[id][gLifes]
			
			if (0 <= iLives <= 100) g_eItems[LS_D_HUD_MESSAGE] ? set_dhudmessage(255, 255, 255, x, y, ef, 1.0, 1.0) : set_hudmessage(255, 255, 255, x, y, ef, 1.0, 1.0)
			else if (101 <= iLives <= 200) g_eItems[LS_D_HUD_MESSAGE] ? set_dhudmessage(255, 0, 255, x, y, ef, 1.0, 1.0) : set_hudmessage(255, 0, 255, x, y, ef, 1.0, 1.0)
			else if (201 <= iLives <= 250) g_eItems[LS_D_HUD_MESSAGE] ? set_dhudmessage(0, 255, 0, x, y, ef, 1.0, 1.0) : set_hudmessage(0, 255, 0, x, y, ef, 1.0, 1.0)
			else if (251 <= iLives <= 350) g_eItems[LS_D_HUD_MESSAGE] ? set_dhudmessage(0, 255, 255, x, y, ef, 1.0, 1.0) : set_hudmessage(0, 255, 255, x, y, ef, 1.0, 1.0)
			else if (351 <= iLives <= 450) g_eItems[LS_D_HUD_MESSAGE] ? set_dhudmessage(255, 0, 0, x, y, ef, 1.0, 1.0) : set_hudmessage(255, 0, 0, x, y, ef, 1.0, 1.0)
			else if (451 <= iLives <= g_eItems[LS_MAX_LIVES] - 1) g_eItems[LS_D_HUD_MESSAGE] ? set_dhudmessage(255, 127, 0, x, y, ef, 1.0, 1.0) : set_hudmessage(255, 127, 0, x, y, ef, 1.0, 1.0)
			else if (iLives == g_eItems[LS_MAX_LIVES]) g_eItems[LS_D_HUD_MESSAGE] ? set_dhudmessage(255, 255, 42, x, y, ef, 1.0, 1.0) : set_hudmessage(255, 255, 42, x, y, ef, 1.0, 1.0)
			else if (iLives >  g_eItems[LS_MAX_LIVES]) g_eItems[LS_D_HUD_MESSAGE] ? set_dhudmessage(random(256), random(256), random(256), x, y, ef, 1.0, 1.0) : set_hudmessage(random(256), random(256), random(256), x, y, ef, 1.0, 1.0)
			
			new szMessage[128], iLen
			
			iLen = formatex(szMessage, charsmax(szMessage), "%s%s: %i ", iLives > 1 ? "Live" : "Life", iLives <= 1 ? "" : "s", iLives)
			
			if (UserData[id][gHudVip])
			{
				iLen += formatex(szMessage[iLen], charsmax(szMessage) - iLen, "| VIP: %s", UserData[id][gVip] ? "Activated" : "Not Activated")
			}
			
			g_eItems[LS_D_HUD_MESSAGE] == 1 ? show_dhudmessage(id, szMessage) : ShowSyncHudMsg( id, g_iSync, szMessage)
		}
		set_entvar(iEnt, var_nextthink, get_gametime() + NEXT_UPDATE)
	}
}
public client_putinserver(id)
{
	UserData[id][gVip] = (get_user_flags(id) & read_flags(g_eItems[LS_VIP_FLAG])) ? true : false
		
	UserData[id][gHudVip] = true
	UserData[id][gLifes] = 0
	UserData[id][gLoaded] = false
	UserData[id][gIncreaseLifes] = 0
		
	g_iNextGamble[id] = -5000.0
	
	#if defined NEW_SQL
	new szName[32]
	get_user_name(id, szName, charsmax(szName))
	set_task(0.2, "Load_Data", id, szName, sizeof(szName))
	#else
	UserData[id][gAuthed] = true
	//Load_MySql(id)
	set_task(1.0, "Load_MySql", id)
	#endif
}
public client_disconnected(id)
{
	new szName[32]
	get_user_name(id, szName, charsmax(szName))
	#if defined LOG_FILE
	new szTimeCode[16]
	get_time("%H:%M:%S", szTimeCode, charsmax(szTimeCode))
	
	new szLogMessage[256]
	formatex(szLogMessage, charsmax(szLogMessage), "[DISCONNECT] [%s] User: %s | Lives: %i", szTimeCode, szName, UserData[id][gLifes])
	write_file(g_szLogFile, szLogMessage)
	//log_to_file("LOG_LIVES_DISCONNECT.txt", "User: %s | Lives: %i", szName, UserData[id][gLifes])
	#endif
	
	if (UserData[id][gAuthed])
	{
		#if defined NEW_SQL
		Save_Data(id, szName)
		#else
		Save_MySql(id)
		#endif
		
		UserData[id][gAuthed] = false
	}
}
public hook_say(id)
{
	new szArgs[192], szArgCmd[32], szArgName[32], szArgLife[10]
	read_args(szArgs, charsmax(szArgs))
	remove_quotes(szArgs)
	parse(szArgs, szArgCmd, charsmax(szArgCmd), szArgName, charsmax(szArgName), szArgLife, charsmax(szArgLife))
	
	new szName[32], szTargetName[32], iTarget
	
	if (equali(szArgCmd,"/give"))
	{
		iTarget = cmd_target(id, szArgName, 0)
		
		UserData[iTarget][gIncreaseLifes] = str_to_num(szArgLife)
		
		get_user_name(id, szName, charsmax(szName))
		get_user_name(iTarget, szTargetName, charsmax(szTargetName ))
		
		
		if (equal(szArgName, ""))
		{
			PCC(id,"Syntax: !g/give !y<!tname!y> <!tamount!y>")
			return PLUGIN_HANDLED
		}
		
		if (!iTarget)
		{
			PCC(id,"I can't find player with the name!g %s!y.", szArgName)
			return PLUGIN_HANDLED
		}
		
		if (id == iTarget)
		{
			PCC(id,"You can't give!g lives!y to yourself.")
			return PLUGIN_HANDLED
		}
		
		if (UserData[id][gLifes] < UserData[iTarget][gIncreaseLifes])
		{
			PCC(id,"You don't have enough!g lives!y.")
			return PLUGIN_HANDLED
		}
		
		if (UserData[iTarget][gIncreaseLifes] <= 0)
		{
			PCC(id,"You can give only!g positive life amount!y.")
			return PLUGIN_HANDLED
		}
		
		if (!UserData[id][gVip] && UserData[iTarget][gIncreaseLifes] > 50)
		{
			PCC(id, "Only !tVIP Users !ycan give more than !g50 Lives!y!")
			return PLUGIN_HANDLED
		}
		
		if (UserData[iTarget][gIncreaseLifes] >= 0)
		{
			UserData[id][gLifes] -= UserData[iTarget][gIncreaseLifes]
			UserData[iTarget][gLifes] += UserData[iTarget][ gIncreaseLifes]
			PCC(0, "!t%s!y give!g %d li%s!y to!t %s!y.", szName, UserData[iTarget][gIncreaseLifes], UserData[iTarget][gIncreaseLifes] > 1 ? "ves" : "fe", szTargetName)
			
			#if defined LOG_FILE
			new szTimeCode[16]
			get_time("%H:%M:%S", szTimeCode, charsmax(szTimeCode))
			
			new szLogMessage[256]
			formatex(szLogMessage, charsmax(szLogMessage), "[GIVE] [%s] <%s> give <%d> li%s to <%s>", szTimeCode, szName, UserData[iTarget][gIncreaseLifes], UserData[iTarget][gIncreaseLifes] > 1 ? "ves" : "fe", szTargetName)
			write_file(g_szLogFile, szLogMessage)
			#endif
			//log_to_file("LIFES_GIVE.log", "<%s> give <%d> li%s to <%s>", szName, UserData[iTarget][gIncreaseLifes], UserData[iTarget][gIncreaseLifes] > 1 ? "ves" : "fe", szTargetName)
		}
	}
	if(equali(szArgCmd, "/life"))
	{
		iTarget = cmd_target(id, szArgName, 0)
		
		if (get_user_flags(id) & NEEDED_ACCESS)
		{
			get_user_name(iTarget, szTargetName, charsmax(szTargetName))
			
			if (equal(szArgName, ""))
			{
				PCC(id,"Syntax: !g/life !y<!tname!y>")
				return PLUGIN_HANDLED
			}
			if (!iTarget)
			{
				PCC(id,"I can't find player with the name!g %s!y.", szArgName)
				return PLUGIN_HANDLED
			}
			PCC(id,"!t%s!y has!g %i Li%s!y.", szTargetName, UserData[iTarget][gLifes], UserData[iTarget][gLifes] > 1 ? "ves" : "fe")
			return PLUGIN_HANDLED
		}
		else
		{
			PCC(id, "You don't have access to this command!")
			return PLUGIN_HANDLED
		}
	}
	if (equali(szArgCmd, "/respawn") || equali(szArgCmd, "/revive"))
	{
		iTarget = cmd_target(id, szArgName, 0)
		
		if (get_user_flags(id) & NEEDED_ACCESS && !equal(szArgName, ""))
		{
			get_user_name(id, szName, charsmax(szName))
			get_user_name(iTarget, szTargetName, charsmax(szTargetName))
			
			if (is_user_alive(iTarget) || get_user_team(iTarget) == 3)
			{
				PCC(id,"!t%s !ymust be dead to respawn!", szTargetName)
				return PLUGIN_HANDLED
			}
			
			if (!iTarget)
			{
				PCC(id,"I can't find player with the name!g %s!y.", szArgName)
				return PLUGIN_HANDLED
			}
			
			PCC(0, "!t%s !yhas respawned !t%s!y!", szName, szTargetName)
			rg_round_respawn(iTarget)
		}
		else
		{
			if (is_user_alive(id) || get_user_team(id) == 3)
			{
				PCC(id,"You must be dead to use lives.")
				return PLUGIN_HANDLED
			}
			
			#if defined EXPENSIVE_RESPAWN
			if (g_iRespawnCounter[id] == 3)
			{
				PCC(id, "You have respawned maximum times for this round!")
				PCC(id, "Get !tVIP+ !yat [!g%s!y] for unlimited respawns per round!", MOD_AUTHOR_DISCORD)
				return PLUGIN_HANDLED
			}
			
			if (g_iRespawnCounter[id] < 3)
			{
				if (UserData[id][gLifes] >= g_iRespawnCounter[id] && UserData[id][gLifes] != 0)
				{
					rg_round_respawn(id)
					if (UserData[id][gVip])
					{
						UserData[id][gLifes]--
					}
					else
					{
						g_iRespawnCounter[id]++
						UserData[id][gLifes] -= g_iRespawnCounter[id]
						PCC(id, "You have revived yourself for !g%i lives!y. [!g%i!y/!t3!y respawns]", g_iRespawnCounter[id], g_iRespawnCounter[id])
						PCC(id, "Get !tVIP+ !yat [!g%s!y] for unlimited respawns per round!", MOD_AUTHOR_DISCORD)
					}
				}
				else
				{
					PCC(id,"You don't have enough!g lives!y to!t respawn!y.")
					return PLUGIN_HANDLED
				}
			}
			#else
			if (UserData[id][gLifes] >= 1)
			{
				rg_round_respawn(id)
				UserData[id][gLifes]--
			}
			else
			{
				PCC(id,"You don't have enough!g lives!y to!t respawn!y.")
				return PLUGIN_HANDLED
			}
			#endif
		}
	}
	if (equali(szArgCmd, "/mylifes") || equali(szArgCmd, "/lifes") || equali(szArgCmd, "/lives"))
	{
		PCC(id,"Lives:!g %d", UserData[id][gLifes])
		return PLUGIN_HANDLED
	}
	if (equali(szArgCmd, "/prune"))
	{
		if (!is_user_connected(id))
			return PLUGIN_HANDLED
		
		if (get_user_flags(id) & NEEDED_ACCESS)
		{
			TruncateTableMenu(id)
			return PLUGIN_HANDLED
		}
		else
		{
			PCC(id, "You don't have access to this command!")
			return PLUGIN_HANDLED
		}
	}
	if (equali(szArgCmd, "/viphud"))
	{
		if (!is_user_connected(id))
			return PLUGIN_HANDLED
		
		if (g_eItems[LS_D_HUD_STATUS])
		{
			UserData[id][gHudVip] = !UserData[id][gHudVip]
			PCC(id, "Switched to !g%s", UserData[id][gHudVip] ? "VIP Hud Message" : "Simple Hud")
			return PLUGIN_HANDLED
		}
		return PLUGIN_HANDLED
	}
	if (equali(szArgCmd, "/vip") || equali(szArgCmd, "/getvip"))
	{
		PCC(id,"Visit!g %s!y to buy !tVIP Privileges!y.", MOD_AUTHOR_DISCORD)
		return PLUGIN_HANDLED
	}
	if (equali(szArgCmd, "/livesmenu") || equal(szArgCmd, "/lm"))
	{
		if (!is_user_connected(id))
			return PLUGIN_HANDLED
			
		if (get_user_flags(id) & NEEDED_ACCESS)
		{
			ToggleLivesMenu(id)
			return PLUGIN_HANDLED
		}
		else
		{
			PCC(id, "You don't have access to this command!")
			return PLUGIN_HANDLED
		}
	}
	
	if (equali(szArgCmd, "/gamble"))
	{
		if(!is_str_num(szArgName))
		{
			PCC(id, "Syntax: !g/gamble !y<!tamount!y>")
			return PLUGIN_HANDLED
		}
		
		if (get_gametime() < g_iNextGamble[id] + (UserData[id][gVip] ? 30.0 : 60.0))
		{
			new iTime = floatround(g_iNextGamble[id] + (UserData[id][gVip] ? 30.0 : 60.0) - get_gametime() + 1)
		
			PCC(id, "Please wait !t%i second%s !yto use gamble again!", iTime, iTime == 1 ? "" : "s")
			return PLUGIN_HANDLED
		}
		
		new g_iAmount = str_to_num(szArgName)
		
		new szGamblerName[32]
		get_user_name(id, szGamblerName, charsmax(szGamblerName))
		
		if (!UserData[id][gVip])
		{
			if (g_iAmount < 1)
			{
				PCC(id, "The minimum amount to gamble on is !t1 Life!y!")
				return PLUGIN_HANDLED
			}
			
			if (g_iAmount > 50)
			{
				PCC(id, "The maximum amount to gamble on is !t50 Lives!y!")
				return PLUGIN_HANDLED
			}
			
			if (g_iAmount >= g_eItems[LS_MAX_LIVES])
			{
				PCC(id, "You have the maximum amount of !t%i Li%s!y allowed to gamble!", g_eItems[LS_MAX_LIVES], g_eItems[LS_MAX_LIVES] > 1 ? "ves" : "fe")
				return PLUGIN_HANDLED
			}
		}
		
		if (g_iAmount > UserData[id][gLifes])
		{
			PCC(id, "You don't have this amount of!g Lives^1 to gamble.")
			return PLUGIN_HANDLED
		}
		
		switch(random_num(1, 100))
		{
			case 1..50:
			{
				PCC(0, "!t%s !yjust gambled on !g%i Li%s !yand !tWon!y!", szGamblerName, g_iAmount, g_iAmount > 1 ? "ves" : "fe")
				
				UserData[id][gLifes] += g_iAmount
			}
			case 51..100:
			{
				PCC(0, "!t%s !yjust gambled on !g%i Li%s !yand !tLost!y!", szGamblerName, g_iAmount, g_iAmount > 1 ? "ves" : "fe")
				
				UserData[id][gLifes] -= g_iAmount
			}
		}
		g_iNextGamble[id] = get_gametime()
	}
	return PLUGIN_CONTINUE
}
public HookDeathMsg()
{
	new iKiller = read_data(1)
	new iVictim = read_data(2)
	new iHead = read_data(3)
	
	new kill_message[126], vip_message[126], szVictimName[32]
	
	get_user_name(iVictim, szVictimName, charsmax(szVictimName))
	
	if (iKiller != iVictim && is_user_connected(iKiller) && UserData[iKiller][gLifes] <= g_eItems[LS_MAX_LIVES])
	{		
		new szWeapon[32]
		read_data(4, szWeapon, charsmax(szWeapon))
			
		if (equal(szWeapon, "grenade"))
		{
			UserData[iKiller][gIncreaseLifes] = g_eItems[LS_HEGRENADE]
			formatex(kill_message, charsmax(kill_message), " !ywith!t HE Grenade!y")
		}
		else
		{
			UserData[iKiller][gIncreaseLifes] = iHead ? g_eItems[LS_HEADSHOT] : g_eItems[LS_KILL]
			iHead ? formatex(kill_message, charsmax(kill_message), " !ywith!t HeadShot!y") : formatex(kill_message, charsmax(kill_message), "")
		}
		UserData[iKiller][gLifes] += UserData[iKiller][gVip] ?  (UserData[iKiller][gIncreaseLifes] + 1) : UserData[iKiller][gIncreaseLifes]
		
		if(g_eItems[LS_KILLER_MESSAGE])
		{
			UserData[iKiller][gVip] ? formatex(vip_message, charsmax(vip_message), " !y(Bonus:!t %i Lifes!y for!g VIP Users!y)", UserData[iKiller][gIncreaseLifes]) : formatex(vip_message, charsmax(vip_message), " !y(buy!g VIP!y to get more!t Lifes!y)")
			PCC(iKiller, "You received!g %d Lives!y for killing!t %s%s%s", UserData[iKiller][gIncreaseLifes], szVictimName, kill_message, vip_message)
		}
	}
	return PLUGIN_CONTINUE
}
public MySql_Init()
{
	new Host[32], User[32], Pass[32], Db[32]
	get_cvar_string("amx_sql_host", Host, charsmax(Host))
	get_cvar_string("amx_sql_user", User, charsmax(User))
	get_cvar_string("amx_sql_pass", Pass, charsmax(Pass))
	get_cvar_string("amx_sql_db", Db, charsmax(Db))
	
	g_SqlTuple = SQL_MakeDbTuple(Host, User, Pass, Db)
	
	new ErrorCode
	g_SqlConnection = SQL_Connect(g_SqlTuple, ErrorCode, g_Error, charsmax(g_Error))
	
	if (g_SqlConnection == Empty_Handle)
		set_fail_state(g_Error)
	
	new Handle:Queries
	
	Queries = SQL_PrepareQuery(g_SqlConnection, "CREATE TABLE IF NOT EXISTS %s (name varchar(64), lifes INT(11))" , DataBase)
	
	if (!SQL_Execute(Queries))
	{
		SQL_QueryError(Queries, g_Error, charsmax(g_Error))
		set_fail_state(g_Error)
	}
	
	SQL_FreeHandle(Queries)
	
	g_Sql_Ready = true
	
	#if !defined NEW_SQL
	for (new id = 1; id <= g_iMaxPlayers; id++)
	{
		if (UserData[id][gAuthed])
		{
			Load_MySql(id)
		}
	}
	#endif
}
#if defined NEW_SQL
public Save_Data(id, szName[])
{
	new szTemp[512]
	
	if (UserData[id][gLifes] >= g_eItems[LS_MAX_LIVES])
	{
		UserData[id][gLifes] = g_eItems[LS_MAX_LIVES]
	}
			
	format(szTemp,charsmax(szTemp), "UPDATE `%s` SET `lifes` = '%i' WHERE `name` = '%s';", DataBase, UserData[id][gLifes], szName)
	SQL_ThreadQuery(g_SqlTuple, "IgnoreHandle", szTemp)
}
public Load_Data(szName[], id)
{
	if (!is_user_connected(id) || !g_Sql_Ready)
		return
	
	new ErrorCode
	new Handle:SqlConnection = SQL_Connect(g_SqlTuple, ErrorCode, g_Error, 511)
	
	SQL_QuoteString(SqlConnection, szName, 32, szName)
	
	if (g_SqlTuple == Empty_Handle)
	{
		log_amx(g_Error)
		return
	}
	new Handle:Query = SQL_PrepareQuery(SqlConnection, "SELECT * FROM %s WHERE name = '%s';", DataBase, szName)
	
	if (!SQL_Execute(Query))
	{
		SQL_QueryError(Query, g_Error, 511)
		log_amx(g_Error)
		return
	}
	if (SQL_NumResults(Query) > 0)
	{
		parse_loaded_data(id, "", 0)
	}
	else
	{
		register_new_player(id)
	}
	SQL_FreeHandle(Query)
	SQL_FreeHandle(SqlConnection)
	
	UserData[id][gAuthed] = true
}
public parse_loaded_data(id, szData[], iLen)
{
	new szName[32]
	get_user_name(id, szName, charsmax(szName))

	new ErrorCode
	new Handle:SqlConnection = SQL_Connect(g_SqlTuple, ErrorCode, g_Error, 511)
	
	SQL_QuoteString(SqlConnection, szName, 31, szName)
	
	if(SqlConnection == Empty_Handle)
	{
		log_amx(g_Error)
		return 
	}
	
	new Handle:Query = SQL_PrepareQuery(SqlConnection, "SELECT lifes FROM %s WHERE name = '%s';", DataBase, szName)
	
	if(!SQL_Execute(Query))
	{
		SQL_QueryError(Query, g_Error, 511)
		log_amx(g_Error)
	}
	
	if( SQL_NumResults(Query) > 0)
	{
		UserData[id][gLifes] = SQL_ReadResult(Query, 0)
		
		#if defined LOG_FILE
		new szTimeCode[16]
		get_time("%H:%M:%S", szTimeCode, charsmax(szTimeCode))
			
		new szLogMessage[256]
		formatex(szLogMessage, charsmax(szLogMessage), "[CONNECT | OLD] [%s] User: %s | Lives: %i", szTimeCode, szName, UserData[id][gLifes])
		write_file(g_szLogFile, szLogMessage)
		#endif
		//log_to_file("LOG_LIVES_CONNECT.txt", "User: %s | Lives: %i", szName, UserData[id][gLifes])
	}
	SQL_FreeHandle(Query)
	SQL_FreeHandle(SqlConnection)
}
public register_new_player(id)
{
	new szName[32]
	get_user_name(id, szName, charsmax(szName))
	
	new ErrorCode
	new Handle:SqlConnection = SQL_Connect(g_SqlTuple, ErrorCode, g_Error, 511)
	
	SQL_QuoteString(SqlConnection, szName, 31, szName)
	
	if(SqlConnection == Empty_Handle)
	{
		log_amx(g_Error)
		return 
	}
	
	new Handle:Query = SQL_PrepareQuery(SqlConnection, "INSERT INTO %s VALUES ('%s','0');", DataBase, szName)
	
	if(!SQL_Execute(Query))
	{
		SQL_QueryError(Query, g_Error, 511)
		log_amx(g_Error)
	}
	
	SQL_FreeHandle(Query)
	SQL_FreeHandle(SqlConnection)
	
	UserData[id][gLifes] = 0
	#if defined LOG_FILE
	new szTimeCode[16]
	get_time("%H:%M:%S", szTimeCode, charsmax(szTimeCode))
			
	new szLogMessage[256]
	formatex(szLogMessage, charsmax(szLogMessage), "[CONNECT | NEW] [%s] User: %s | Lives: %i", szTimeCode, szName, UserData[id][gLifes])
	write_file(g_szLogFile, szLogMessage)
	#endif
	//log_to_file("LOG_LIVES_CONNECT.txt", "*NEW* User: %s | Lives: %i", szName, UserData[id][gLifes])
}
#else
public Load_MySql(id)
{
	if (g_Sql_Ready)
	{
		if (g_SqlTuple == Empty_Handle)
			set_fail_state(g_Error)
		
		new szPlayerName[32], szQuotedName[64], szTemp[512]
		get_user_name(id, szPlayerName, charsmax(szPlayerName))
		SQL_QuoteString(g_SqlConnection, szQuotedName, charsmax(szQuotedName), szPlayerName)
		
		new Data[1]
		Data[0] = id
		
		format(szTemp,charsmax(szTemp),"SELECT * FROM `%s` WHERE `name` = '%s'", DataBase, szQuotedName)
		SQL_ThreadQuery(g_SqlTuple,"register_client", szTemp, Data, 1)
	}
}
public register_client(FailState, Handle:Query, Error[], Errcode, Data[], DataSize)
{
	if (FailState == TQUERY_CONNECT_FAILED)
		log_amx("Load - Could not connect to SQL database.  [%d] %s", Errcode, Error)
	else if (FailState == TQUERY_QUERY_FAILED)
		log_amx("Load Query failed. [%d] %s", Errcode, Error)
	
	new id = Data[0]
	
	new szName[32]
	get_user_name(id, szName, charsmax(szName))
	
	if (SQL_NumResults(Query) < 1)
	{	
		new szQuotedName[64]
		SQL_QuoteString(g_SqlConnection, szQuotedName, charsmax(szQuotedName), szName)
		
		new szTemp[512]
		format(szTemp, charsmax(szTemp), "INSERT INTO `%s` VALUES ('%s','0');", DataBase, szQuotedName)
		SQL_ThreadQuery(g_SqlTuple, "IgnoreHandle", szTemp)
	}
	else
	{
		UserData[id][gLifes] = SQL_ReadResult(Query, 1)
	}
	
	UserData[id][gLoaded] = true
	#if defined LOG_FILE
	new szTimeCode[16]
	get_time("%H:%M:%S", szTimeCode, charsmax(szTimeCode))
			
	new szLogMessage[256]
	formatex(szLogMessage, charsmax(szLogMessage), "[CONNECT] [%s] User: %s | Lives: %i", szTimeCode, szName, UserData[id][gLifes])
	write_file(g_szLogFile, szLogMessage)
	#endif
	//log_to_file("LOG_LIVES_CONNECT.txt", "User: %s | Lives: %i", szName, UserData[id][gLifes])
	
	return PLUGIN_HANDLED
}
public Save_MySql( id )
{
	if (UserData[id][gLoaded])
	{
		new szTemp[512], szName[32], szQuotedName[64]
		get_user_name(id, szName, charsmax(szName))
		SQL_QuoteString(g_SqlConnection, szQuotedName, charsmax (szQuotedName), szName)
		
		if (UserData[id][gLifes] >= g_eItems[LS_MAX_LIVES]) UserData[id][gLifes] = g_eItems[LS_MAX_LIVES]
			
		format(szTemp,charsmax(szTemp), "UPDATE `%s` SET `lifes` = '%i' WHERE `name` = '%s';", DataBase, UserData[id][ gLifes], szQuotedName)
		SQL_ThreadQuery(g_SqlTuple, "IgnoreHandle", szTemp)
	}
}
#endif
public IgnoreHandle(FailState, Handle:Query,Error[], Errcode,Data[], DataSize)
{
	SQL_FreeHandle(Query)
	
	return PLUGIN_HANDLED
}
public plugin_end()
{
	if (g_SqlConnection != Empty_Handle)
		SQL_FreeHandle(g_SqlConnection)
}
public plugin_natives()
{	
	register_library("deathrun_lifes")
	
	register_native("get_user_lives", "_get_user_lives")
	register_native("set_user_lives", "_set_user_lives")
	
	register_native("get_max_lives", "_get_max_lives")
}
public _get_user_lives(iPlugin, iParams)
{
	return UserData[get_param(1)][gLifes]
}
public _set_user_lives(iPlugin, iParams)
{
	new id = get_param(1)
	UserData[id][gLifes] = max(0, get_param(2))
	return UserData[id][gLifes]
}
public _get_max_lives(iPlugin, iParams)
{
	return g_eItems[LS_MAX_LIVES]
}
public fwdClientUserInfoChanged(id)
{
	if (!is_user_connected(id))
		return FMRES_IGNORED
	
	new szNewName[32], szOldName[32]
	get_user_name(id, szOldName, charsmax(szOldName))
	get_user_info(id, "name", szNewName, charsmax(szNewName))
	
	if (!equali(szNewName, szOldName))
	{
		#if defined NEW_SQL
		Save_Data(id, szOldName)
		set_task(0.1, "Load_Data", id, szNewName, sizeof(szNewName))
		#else
		Save_MySql(id)
		UserData[id][gLifes] = 0
		UserData[id][gAuthed] = true
		UserData[id][gLoaded] = false
		set_task(0.1, "Load_MySql", id)
		#endif
		return FMRES_HANDLED
	}
	return FMRES_IGNORED
}
public TruncateTableMenu(id)
{
	static szMenuTitle[126]
	formatex(szMenuTitle, charsmax(szMenuTitle ), "\r[\yDeathrun Lives DataBase\r] \wAre you sure you want to empty database?")
	
	new iMenu = menu_create(szMenuTitle, "TruncateTableMenuFunc")
	
	menu_additem(iMenu, "Yes", "1", 0 )
	menu_additem(iMenu, "No", "2", 0 )
	
	menu_setprop(iMenu, MPROP_EXIT, MEXIT_NEVER)
	menu_display(id, iMenu, 0)
	return PLUGIN_HANDLED
}
public TruncateTableMenuFunc(id, iMenu, Item)
{
	switch(++Item)
	{
		case 1:
		{
			new Handle:iTruncate
			iTruncate = SQL_PrepareQuery(g_SqlConnection, "TRUNCATE TABLE `%s`" , DataBase)
			if (SQL_Execute(iTruncate))
			{
				PCC(id,"The table was cleared successfully!")
			} 
			else
			{
				PCC(id,"There was a problem, the table is!g not cleared!y!" )
			}
			SQL_FreeHandle(iTruncate)
		}
		case 2:
		{
			return PLUGIN_CONTINUE
		}
	}
	menu_destroy(iMenu)
	return PLUGIN_HANDLED
}

/* ================================================
	Admin Live Menus & Commands
================================================ */
new g_iPlayer[MAX_PLAYERS + 1], g_iMenuType[MAX_PLAYERS + 1]

public Command_LivesAdminMenu(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED
		
	ToggleLivesMenu(id)
	
	return PLUGIN_HANDLED
}
public ToggleLivesMenu(id)
{
	static szTitle[64]
	formatex(szTitle, charsmax(szTitle), "%s^n^t^t\wAdmin \yLives \rMenu", MOD_MENU_PREFIX)
	new iMenu = menu_create(szTitle, "livesmenu_handler")
	
	menu_additem(iMenu, "\yGive \dPlayer \rLives")
	menu_additem(iMenu, "\yTake \dPlayer \rLives")
	
	menu_setprop(iMenu, MPROP_NUMBER_COLOR, "\w")
	menu_display(id, iMenu, 0)
	return PLUGIN_HANDLED
}
public livesmenu_handler(id, iMenu, Item)
{
	if (Item == MENU_EXIT)
	{
		menu_destroy(iMenu)
		return PLUGIN_HANDLED
	}
	
	PlayerLivesMenu(id, ++Item)
	
	menu_destroy(iMenu)
	return PLUGIN_HANDLED
}

public PlayerLivesMenu(id, iType)
{
	static szTitle[64]
	formatex(szTitle, charsmax(szTitle), "%s^n^t^tChoose Player to %s Lives", MOD_MENU_PREFIX, iType == 1 ? "Give" : "Take")
	new iMenu = menu_create(szTitle, "lives_handler")
	
	g_iMenuType[id] = iType
	
	new iPlayers[32], iNum, iPlayer
	new szName[34], szTempID[10]
	get_players(iPlayers, iNum)
	
	for(new i; i < iNum; i++)
	{
		iPlayer = iPlayers[i]
		if(!is_user_connected(iPlayer))
			continue
		
		get_user_name(iPlayer, szName, sizeof szName - 1)
		num_to_str(iPlayer, szTempID, charsmax(szTempID))
		menu_additem(iMenu, szName, szTempID)
	}
	menu_setprop(iMenu, MPROP_EXITNAME, "Go back..")
	menu_display(id, iMenu, 0)
	return PLUGIN_HANDLED
}
public lives_handler(id, iMenu, Item)
{
	if (Item == MENU_EXIT)
	{
		ToggleLivesMenu(id)
		g_iMenuType[id] = 0
		return PLUGIN_HANDLED
	}
	
	new szData[6], iName[64], iAccess, iCallBack
	menu_item_getinfo(iMenu, Item, iAccess, szData, charsmax(szData), iName, charsmax(iName), iCallBack)
	
	g_iPlayer[id] = str_to_num(szData)
	
	if (!is_user_connected(g_iPlayer[id]))
	{
		g_iPlayer[id] = 0
		PCC(id, "The player you chose is not in the server.")
		return PLUGIN_HANDLED
	}
	
	PCC(id, "Player !t%s !yhas !g%i Li%s!y.", iName, UserData[g_iPlayer[id]][gLifes], UserData[g_iPlayer[id]][gLifes] > 1 ? "ves" : "fe")
	
	client_cmd(id, "messagemode Lives_Amount")
	PCC(id, "Type in the new value to !t%s!g lives!y, or!g !cancel!y to cancel!", g_iMenuType[id] == 1 ? "give" : "take")
	menu_destroy(iMenu)
	return PLUGIN_HANDLED
}
public Command_Lives_Amount(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED
		
	if (!g_iPlayer[id])
		return PLUGIN_HANDLED
		
	if (!is_user_connected(g_iPlayer[id]))
	{
		PCC(id, "The player you chose is not in the server.")
		return PLUGIN_HANDLED
	}
	
	new szArgs[12]
	read_argv(1, szArgs, charsmax(szArgs))
	
	if (equali(szArgs, "!cancel", 7))
	{
		PlayerLivesMenu(id, g_iMenuType[id])
		return PLUGIN_HANDLED
	}
	/*
	new g_szNums[][] = { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9" }
	
	for(new i = 0; i < sizeof(g_szNums); i++)
	{
		if(!equal(szArgs, g_szNums[i]))
		{
			PCC(id, "You must use only numbers!")
			PCC(id, "Please !gre-enter!y your new amount or!g !cancel!y to cancel!!")
			client_cmd(id, "messagemode Lives_Amount")
			return PLUGIN_HANDLED
		}
	}*/
	
	new iLives = str_to_num(szArgs)
	
	new szNames[2][32]
	get_user_name(id, szNames[0], charsmax(szNames[]))
	get_user_name(g_iPlayer[id], szNames[1], charsmax(szNames[]))
	
	if (iLives < 0)
	{
		PCC(id, "You can !t%s !yonly positive amount!", g_iMenuType[id] == 1 ? "give" : "take")
		PCC(id, "Please !gre-enter!y your new amount or!g !cancel!y to cancel!!")
		client_cmd(id, "messagemode Lives_Amount")
		return PLUGIN_HANDLED
	}
	
	if (UserData[g_iPlayer[id]][gLifes] == 0 && g_iMenuType[id] == 2)
	{
		g_iPlayer[id] = 0
		g_iMenuType[id] = 0
		PCC(id, "Player !t%s !ydon't have enough!g lives!y!", szNames[1])
		ToggleLivesMenu(id)
		return PLUGIN_HANDLED
	}
	
	switch (g_iMenuType[id])
	{
		case 1:
		{
			UserData[g_iPlayer[id]][gLifes] += iLives
			if (iLives > g_eItems[LS_MAX_LIVES])
				PCC(0, "ADMIN !g%s: !ygave !t%i Lives !yto !g%s!y.", szNames[0], g_eItems[LS_MAX_LIVES], szNames[1])
			else
				PCC(0, "ADMIN !g%s: !ygave !t%i Li%s !yto !g%s!y.", szNames[0], iLives, iLives > 1 ? "ves"  : "fe", szNames[1])
		
			if (UserData[g_iPlayer[id]][gLifes] > g_eItems[LS_MAX_LIVES])
			{
				UserData[g_iPlayer[id]][gLifes] = g_eItems[LS_MAX_LIVES]
			}
		}
		case 2:
		{
			UserData[g_iPlayer[id]][gLifes] -= iLives
			PCC(0, "ADMIN !g%s: !ytook !t%i Li%s !yfrom !g%s!y.", szNames[0], iLives, iLives > 1 ? "ves"  : "fe", szNames[1])
		
			if (UserData[g_iPlayer[id]][gLifes] < 0)
			{
				UserData[g_iPlayer[id]][gLifes] = 0
			}
		}
	}
	
	#if defined LOG_FILE
	new szTimeCode[16]
	get_time("%H:%M:%S", szTimeCode, charsmax(szTimeCode))
			
	new szLogMessage[256]
	formatex(szLogMessage, charsmax(szLogMessage), "[%s] ADMIN %s: %s %i lives %s %s", szTimeCode, szNames[0], g_iMenuType[id] == 1 ? "gave" : "took", iLives, g_iMenuType[id] == 1 ? "to" : "from", szNames[1])
	write_file(g_szLogFile, szLogMessage)
	#endif
	
	g_iPlayer[id] = 0
	g_iMenuType[id] = 0

	#if defined NEW_SQL
	Save_Data(id, szNames[1])
	set_task(0.1, "Load_Data", id, szNames[1], sizeof(szNames[]))
	#else
	Save_MySql(id)
	UserData[id][gLifes] = 0
	UserData[id][gAuthed] = true
	UserData[id][gLoaded] = false
	set_task(0.1, "Load_MySql", id)
	#endif
	
	ToggleLivesMenu(id)
	return PLUGIN_HANDLED
}
