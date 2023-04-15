#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <engine>
#include <fun>
#include <hamsandwich>

#include <hdr_const>

new const PLUGIN[] = "HDR: Race System"
new const PLUGIN_CVAR[] = "hdr_race_system"

/* ==============================================
	DeathRun Touch System Begins Here!
============================================== */
const ADMIN_ACCESS = ADMIN_BAN

new const g_szEntString[] = "info_target"
new const g_szClassname_Start[] = "DRStartLine"
new const g_szClassname_Finish[] = "DRFinishLine"

new g_szDirectory[512], g_szMap[32], szDir[64]
new g_szFilename_Start[512], g_szFilename_Finish[512]

new Array:g_aZones_Start, Array:g_aZones_Finish
new Trie:g_tZones_Start, Trie:g_tZones_Finish
new bool:g_blBuilding[MAX_PLAYERS + 1]
new Float:g_flBuildOrigin[MAX_PLAYERS + 1][2][3]
new g_iBuildStage[MAX_PLAYERS + 1]
new g_iCurrentZone[MAX_PLAYERS + 1][2]

new bool:g_blHighlight_Start[MAX_PLAYERS + 1], bool:g_blHighlight_Finish[MAX_PLAYERS + 1]
new g_iZoneSprite

new g_iTotalZones_Start
new g_iTotalZones_Finish

#define TASK_SHOWZONES_START 377737
#define TASK_SHOWZONES_FINISH 377738

#define ZONE_SPRITE "sprites/laserbeam.spr"
#define ZONE_STARTFRAME 1
#define ZONE_FRAMERATE 1
#define ZONE_LIFE 12
#define ZONE_WIDTH 5
#define ZONE_NOISE 0
#define ZONE_COLOR_SELECTED_RED 0
#define ZONE_COLOR_SELECTED_GREEN random(256)
#define ZONE_COLOR_SELECTED_BLUE 255
#define ZONE_BRIGHTNESS 255
#define ZONE_SPEED 0
#define ZONE_VIEWDISTANCE 800.0
#define ZONE_RACE_TEAM 2
#define START_ZONE_COLOR_RED 0
#define START_ZONE_COLOR_GREEN 255
#define START_ZONE_COLOR_BLUE 0
#define FINISH_ZONE_COLOR_RED 255
#define FINISH_ZONE_COLOR_GREEN 0
#define FINISH_ZONE_COLOR_BLUE 0

#define BEAM_SPRITE "sprites/lgtning.spr"
#define BEAM_STARTFRAME 0
#define BEAM_FRAMERATE 10
#define BEAM_LIFE 2
#define BEAM_WIDTH 15
#define BEAM_NOISE 2
#define BEAM_COLOR_RED 255
#define BEAM_COLOR_GREEN 0
#define BEAM_COLOR_BLUE 0
#define BEAM_COLOR_SELECT_RED 0
#define BEAM_COLOR_SELECT_GREEN random(256)
#define BEAM_COLOR_SELECT_BLUE 255
#define BEAM_BRIGHTNESS 255
#define BEAM_SPEED 30
	
new g_iBeamSprite

new g_iType[MAX_PLAYERS + 1], bool:g_iFinishSelect, bool:g_iStartSelect, bool:g_iStartTouched[MAX_PLAYERS + 1], bool:g_iFinishTouched[MAX_PLAYERS + 1]


/* ==============================================
	DeathRun RACE System Begins Here!
============================================== */
#define MYSQL_SUPPORT
#define COLOR_RACERS
#define TASK_START_RACE 377739

new g_iChallenger[MAX_PLAYERS + 1], g_iTimeToRace[MAX_PLAYERS + 1]
new g_bUserRacing[MAX_PLAYERS + 1]
new Float:g_flHisTime[MAX_PLAYERS + 1], Float:g_flSpawnOrigin[eHDR_FXYZ]
new g_iFinish[MAX_PLAYERS + 1] = false

new g_bRaceOffline[MAX_PLAYERS + 1]

#if defined MYSQL_SUPPORT
#include <sqlx>

new const TABLE[] = "DR_RaceSystem"

new g_iWins[MAX_PLAYERS + 1]
new g_iLosses[MAX_PLAYERS + 1]
new g_iTotalRaces[MAX_PLAYERS + 1]
new szPlayerName[MAX_PLAYERS + 1][64]
new szName[64]


new Handle:g_SqlTuple
new bool:g_bDownload_Data[MAX_PLAYERS + 1] = { false }

new g_sBuffer[4096]
new Style[] = "<meta charset=UTF-8><style>body{font-family:Arial;}img{margin-bottom:10px;}th{background:#57b9ff;color:#FFF;padding:5px;border-bottom:2px #24a4ff solid;text-align:left}td{padding:3px;border-bottom:1px #8aceff dashed}table{color:#2c75ff;background:#FFF;font-size:12px}h2,h3{color:#333;font-family:Verdana}#c{background:#F0F7E2}#r{height:10px;background:#717171}#clr{background:none;color:#575757;font-size:20px}</style>"
#endif

native get_user_lives(id)
native set_user_lives(id, iLives)

const g_iLivesBet = 3
const g_iRPBet = 1

new g_iRacePoints[MAX_PLAYERS + 1]

#if defined COLOR_RACERS

/*
enum
{
	REDZ = 0,
	REDORANGE,
	ORANGE,
	YELLOWORANGE,
	PEACH,
	YELLOW,
	LEMONYELLOW,
	JUNGLEGREEN,
	YELLOWGREEN,
	GREEN,
	AQUAMARINE,
	BABYBLUE,
	SKYBLUE,
	BLUE,
	VIOLET,
	PINK,
	MAGENTA,
	MAHOGANY,
	TAN,
	LIGHTBROWN,
	BROWN,
	GRAY,
	WHITE
}
*/
new g_pColor[MAX_PLAYERS + 1]

enum _:eColors
{
	COLOR_NAME[32], R, G, B
}

new gColors[][eColors] =
{
	{ "Red", 		255, 0, 0 	},
	{ "Red Orange", 		255, 69, 0 	},
	{ "Orange",		255, 165, 0 	},
	{ "Yellow Orange", 	255, 204, 0	},
	{ "Peach", 		255, 218, 185 	},
	{ "Yellow", 		255, 255, 0 	},
	{ "Lemon Yellow", 	255, 255, 102 	},
	{ "Jungle Green", 	41, 171, 135 	},
	{ "Yellow Green", 	154, 205, 50 	},
	{ "Green", 		0, 128, 0 	},
	{ "Aquamarine", 		127, 255, 212 	},
	{ "Baby Blue", 		173, 216, 230 	},
	{ "Sky Blue", 		135, 206, 235 	},
	{ "Blue", 		0, 0, 255	},
	{ "Violet", 		238, 130, 238 	},
	{ "Hot Pink", 		255, 105, 180 	},
	{ "Magenta", 		255, 0, 255	},
	{ "Mahogany", 		103, 10, 10 	},
	{ "Tan", 		210, 180, 140 	},
	{ "Light Brown", 	244, 164, 96 	},
	{ "Brown", 		165, 42, 42	},
	{ "Gray", 		128, 128, 128 	},
	{ "White", 		255, 255, 255 	}
}

#endif

public plugin_init()
{
	register_plugin(PLUGIN, MOD_VERSION, MOD_AUTHOR)
	register_cvar(PLUGIN_CVAR, MOD_VERSION, FCVAR_SERVER | FCVAR_SPONLY)
	set_cvar_string(PLUGIN_CVAR, MOD_VERSION)
	
	/* ==============================================
	DeathRun RACE System Begins Here!
	============================================== */
	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn", true)
	
	register_clcmd("say /race", "cmdRace")
	register_clcmd("say_team /race", "cmdRace")
	register_clcmd("say /racead", "cmdRaceOffline")
	register_clcmd("say /raceoff", "cmdRaceOffline")
	register_clcmd("say /rad", "cmdRaceOffline")
	register_forward(FM_Think, "fwd_Think")
	register_event("DeathMsg", "OnPlayerDeath", "a")
	
	new iEnt = find_ent_by_class(iEnt, "info_player_start")
	pev(iEnt, pev_origin, g_flSpawnOrigin)
	
	CreateAdEntitys()
	
	#if defined MYSQL_SUPPORT
	register_logevent("Event_RoundEnd", 2, "0=World triggered", "1=Round_End")
	register_logevent("Event_RoundEnd", 2, "0=World triggered", "1&Restart_Round")
	register_logevent("Event_RoundEnd", 2, "0=World triggered", "1=Game_Commencing")
	

	register_cvar("amx_race_host", "192.168.88.2")
	register_cvar("amx_race_user", "itaniumservers_ivo")
	register_cvar("amx_race_pass", "mgEuf#SI5(gn")
	register_cvar("amx_race_db", "itaniumservers_dr")

	/*register_cvar("amx_race_host", "185.148.145.237")
	register_cvar("amx_race_user", "arenapl_csbg")
	register_cvar("amx_race_pass", "8tGzNbD49jRZp8L7")
	register_cvar("amx_race_db", "arenapl_csbg")*/
	
	MySql_Init()
	
	register_clcmd("say /rank","Command_Rank")
	register_clcmd("say /top10","Command_Top10")
	#endif
	/* ==============================================
	DeathRun Touch System Begins Here!
	============================================== */
	register_clcmd("say /racemenu", "Command_RaceMenu", ADMIN_ACCESS)
	register_clcmd("say /rm", "Command_RaceMenu", ADMIN_ACCESS)
	register_clcmd("drop", "selectPoint")
	
	register_touch(g_szClassname_Start, "player", "fwdTouchStart")
	register_touch(g_szClassname_Finish, "player", "fwdTouchFinish")
	
	get_mapname(g_szMap, charsmax(g_szMap))
	strtolower(g_szMap)
	
	get_datadir(g_szDirectory, charsmax(g_szDirectory))
	formatex(szDir, charsmax(szDir), "/DR_Race_System/%s", g_szMap)
	add(g_szDirectory, charsmax(g_szDirectory), szDir)
	formatex(g_szFilename_Start, charsmax(g_szFilename_Start), "%s/Start.txt", g_szDirectory)
	formatex(g_szFilename_Finish, charsmax(g_szFilename_Finish), "%s/Finish.txt", g_szDirectory)
	
	if (!dir_exists(g_szDirectory))
		mkdir(g_szDirectory)
	
	g_aZones_Start = ArrayCreate(5, 1)
	g_tZones_Start = TrieCreate()
	
	g_aZones_Finish = ArrayCreate(5, 1)
	g_tZones_Finish = TrieCreate()
	
	fileRead(0)
	fileRead2(0)

	register_clcmd("_rp", "giverp")
}
public giverp(id)
{
	g_iRacePoints[id] += 1000
	return PLUGIN_HANDLED
}
public plugin_precache()
{
	g_iZoneSprite = precache_model(ZONE_SPRITE)
	
	g_iBeamSprite = precache_model(BEAM_SPRITE)
}
public plugin_end()
{
	fileRead(1)
	fileRead2(1)
	
	ArrayDestroy(g_aZones_Start)
	TrieDestroy(g_tZones_Start)
	
	ArrayDestroy(g_aZones_Finish)
	TrieDestroy(g_tZones_Finish)
	
	#if defined MYSQL_SUPPORT
	SQL_FreeHandle(g_SqlTuple)
	#endif
}

fileRead(iWrite)
{
	new iFilePointer
	
	switch(iWrite)
	{
		case 0:
		{
			iFilePointer = fopen(g_szFilename_Start, "rt")
	
			if (iFilePointer)
			{
				new szData[200], szPoint[6][32]
				new Float:flPoint[2][3]
				
				while (!feof(iFilePointer))
				{
					fgets(iFilePointer, szData, charsmax(szData))
					trim(szData)
					
					if (szData[0] == EOS || szData[0] == ';')
						continue
						
					parse(szData, szPoint[0], charsmax(szPoint[]), szPoint[1], charsmax(szPoint[]), szPoint[2], charsmax(szPoint[]),
					szPoint[3], charsmax(szPoint[]), szPoint[4], charsmax(szPoint[]), szPoint[5], charsmax(szPoint[]))
					
					for (new i; i < 3; i++)
						flPoint[0][i] = str_to_float(szPoint[i])
						
					for (new i; i < 3; i++)
						flPoint[1][i] = str_to_float(szPoint[i + 3])
					
					CreateZone_Start(flPoint[0], flPoint[1])
				}
			}
		}
		case 1:
		{
			delete_file(g_szFilename_Start)
			
			if (!g_iTotalZones_Start)
				return
				
			iFilePointer = fopen(g_szFilename_Start, "wt")
			
			new szCoords[200], szZone[5], iZone
			
			for (new i; i < g_iTotalZones_Start; i++)
			{
				iZone = ArrayGetCell(g_aZones_Start, i)
				num_to_str(iZone, szZone, charsmax(szZone))
				TrieGetString(g_tZones_Start, szZone, szCoords, charsmax(szCoords))
				fprintf(iFilePointer, "%s^n", szCoords)
			}
		}
	}
	
	fclose(iFilePointer)
}

fileRead2(iWrite)
{
	new iFilePointer
	
	switch(iWrite)
	{
		case 0:
		{
			iFilePointer = fopen(g_szFilename_Finish, "rt")
	
			if (iFilePointer)
			{
				new szData[200], szPoint[6][32]
				new Float:flPoint[2][3]
				
				while (!feof(iFilePointer))
				{
					fgets(iFilePointer, szData, charsmax(szData))
					trim(szData)
					
					if (szData[0] == EOS || szData[0] == ';')
						continue
						
					parse(szData, szPoint[0], charsmax(szPoint[]), szPoint[1], charsmax(szPoint[]), szPoint[2], charsmax(szPoint[]),
					szPoint[3], charsmax(szPoint[]), szPoint[4], charsmax(szPoint[]), szPoint[5], charsmax(szPoint[]))
					
					for (new i; i < 3; i++)
						flPoint[0][i] = str_to_float(szPoint[i])
						
					for (new i; i < 3; i++)
						flPoint[1][i] = str_to_float(szPoint[i + 3])
					
					CreateZone_Finish(flPoint[0], flPoint[1])
				}
			}
		}
		case 1:
		{
			delete_file(g_szFilename_Finish)
			
			if (!g_iTotalZones_Finish)
				return
				
			iFilePointer = fopen(g_szFilename_Finish, "wt")
			
			new szCoords[200], szZone[5], iZone
			
			for (new i; i < g_iTotalZones_Finish; i++)
			{
				iZone = ArrayGetCell(g_aZones_Finish, i)
				num_to_str(iZone, szZone, charsmax(szZone))
				TrieGetString(g_tZones_Finish, szZone, szCoords, charsmax(szCoords))
				fprintf(iFilePointer, "%s^n", szCoords)
			}
		}
	}
	
	fclose(iFilePointer)
}


public fwdTouchStart(iZone, id)
{
	if (get_user_team(id) != ZONE_RACE_TEAM)
		return
	
	if (g_iStartTouched[id])
		return
		
	if (g_bUserRacing[id])
	{
		g_iStartTouched[id] = true
		g_iFinishTouched[id] = false
		
		client_print(id, print_center, "..:: GO GO GO ::..")
	}
}
public fwdTouchFinish(iZone, id)
{
	if (get_user_team(id) != ZONE_RACE_TEAM)
		return
	
	if (g_iFinishTouched[id] || !g_bUserRacing[id] || !g_iStartTouched[id])
		return
	
	g_iFinishTouched[id] = true
	g_iStartTouched[id] = false
	fwPlayerFinished(id)
}

public selectPoint(id)
{
	if (!g_blBuilding[id])
		return PLUGIN_CONTINUE
	
	new Float:flPointOrigin[3], flUserOrigin[3]
	get_user_origin(id, flUserOrigin, 3)
	IVecFVec(flUserOrigin, flPointOrigin)
	
	g_flBuildOrigin[id][g_iBuildStage[id]] = flPointOrigin
	
	draw_beam(id)

	switch(g_iBuildStage[id])
	{
		case 0:
		{
			g_iBuildStage[id]++
			PCC(id, "Press !g^"G^" !yto set the !tsecond !ypoint!")
		}
		case 1:
		{
			g_iBuildStage[id]--
			g_blBuilding[id] = false
			
			if (g_iStartSelect)
			{
				CreateZone_Start(g_flBuildOrigin[id][0], g_flBuildOrigin[id][1])
				PCC(id, "!tStart Line!y created successfully!")
			}
			else if (g_iFinishSelect)
			{
				CreateZone_Finish(g_flBuildOrigin[id][0], g_flBuildOrigin[id][1])
				PCC(id, "!tFinish Line!y created successfully!")
			}
		}
	}
	menu_reopen(id)
	return PLUGIN_HANDLED
}
public Command_RaceMenu(id)
{
	if (!(get_user_flags(id) & ADMIN_ACCESS))
	{
		PCC(id, "You have no access to this command!")
		return PLUGIN_HANDLED
	}
	
	g_iType[id] = -1
	
	new iMenu = menu_create("DeathRun Race Admin Menu", "handler_USB")
	
	menu_additem(iMenu, "Start Line")
	menu_additem(iMenu, "Finish Line")
	
	menu_display(id, iMenu, 0)
	return PLUGIN_HANDLED
}
public handler_USB(id, iMenu, Item)
{
	if (Item == MENU_EXIT)
	{
		menu_destroy(iMenu)
		return PLUGIN_HANDLED
	}
	
	RaceMenu(id, Item)
	
	menu_destroy(iMenu)
	return PLUGIN_HANDLED
}
public RaceMenu(id, iType)
{
	new szTitle[128], szItem[64]
	
	formatex(szTitle, charsmax(szTitle), "\rDeathRun Race Admin Menu")
	
	new iMenu = menu_create(szTitle, "handler_RaceMenu")
	
	g_iType[id] = iType
	
	switch(iType)
	{
		case 0:
		{
			formatex(szItem, charsmax(szItem), "%s", g_blBuilding[id] ? "\rCancel Start Line" : "Add a New Start Line")
			menu_additem(iMenu, szItem, "")
			
			formatex(szItem, charsmax(szItem), "%s", g_blHighlight_Start[id] ? "\rHide Start Line" : "Highlight Start Line")
			menu_additem(iMenu, szItem, "")
			
			formatex(szItem, charsmax(szItem), "%sSelect Start Line", g_iTotalZones_Start ? "" : "\d")
			menu_additem(iMenu, szItem, "")
			
			formatex(szItem, charsmax(szItem), "%sDelete Start Line", g_iTotalZones_Start && is_zone_start(g_iCurrentZone[id][0]) ? "" : "\d")
			menu_additem(iMenu, szItem, "")
			
			formatex(szItem, charsmax(szItem), "%sTeleport To Start Line", g_iTotalZones_Start && is_zone_start(g_iCurrentZone[id][0]) ? "" : "\d")
			menu_additem(iMenu, szItem, "")
		}
		case 1:
		{
			formatex(szItem, charsmax(szItem), "%s", g_blBuilding[id] ? "\rCancel Finish Line" : "Add a New Finish Line")
			menu_additem(iMenu, szItem, "")
			
			formatex(szItem, charsmax(szItem), "%s", g_blHighlight_Finish[id] ? "\rHide Finish Line" : "Highlight Finish Line")
			menu_additem(iMenu, szItem, "")
			
			formatex(szItem, charsmax(szItem), "%sSelect Finish Line", g_iTotalZones_Finish ? "" : "\d")
			menu_additem(iMenu, szItem, "")
			
			formatex(szItem, charsmax(szItem), "%sDelete Finish Line", g_iTotalZones_Finish && is_zone_finish(g_iCurrentZone[id][0]) ? "" : "\d")
			menu_additem(iMenu, szItem, "")
			
			formatex(szItem, charsmax(szItem), "%sTeleport To Finish Line", g_iTotalZones_Finish && is_zone_finish(g_iCurrentZone[id][0]) ? "" : "\d")
			menu_additem(iMenu, szItem, "")
		}
	}
	
	menu_display(id, iMenu, 0)
	return PLUGIN_HANDLED
}
public handler_RaceMenu(id, iMenu, Item)
{
	if (Item == MENU_EXIT)
	{
		menu_destroy(iMenu)
		Command_RaceMenu(id)
		return PLUGIN_HANDLED
	}
	
	switch(Item)
	{
		case 0:
		{
			if (g_iType[id] == 0 && g_iTotalZones_Start > 0)
			{
				PCC(id, "You can have only !t1 Start Lines!y on map!")
				RaceMenu(id, g_iType[id])
				return PLUGIN_CONTINUE
			}
			else if (g_iType[id] == 1 && g_iTotalZones_Finish > 0)
			{
				PCC(id, "You can have only !t1 Finish Lines!y on map!")
				RaceMenu(id, g_iType[id])
				return PLUGIN_CONTINUE
			}
			if (g_iType[id] == 0)
			{
				g_iStartSelect = true
				g_iFinishSelect = false
			}
			else if (g_iType[id] == 1)
			{
				g_iStartSelect = false
				g_iFinishSelect = true
			}
			if (g_blBuilding[id])
			{
				g_iBuildStage[id] = 0
				g_blBuilding[id] = false
				PCC(id, "Building mode canceled.")
			}
			else
			{
				g_blBuilding[id] = true
				PCC(id, "Press !g^"G^" !yto set the !tfirst !ypoint!")
			}
		}
		case 1:
		{
			if (g_iType[id] == 0)
			{
				if (g_blHighlight_Start[id])
				{
					g_blHighlight_Start[id] = false
					remove_task(id + TASK_SHOWZONES_START)
					PCC(id, "!tStart Line !gHighlight !yhas been !tdisabled!y!")
				}
				else
				{
					g_blHighlight_Start[id] = true
					set_task(1.0, "showZones_Start", id + TASK_SHOWZONES_START, "", 0, "b", 0)
					PCC(id, "!tStart Line !gHighlight !yhas been !tenabled!y!")
				}
			}
			else if (g_iType[id] == 1)
			{
				if (g_blHighlight_Finish[id])
				{
					g_blHighlight_Finish[id] = false
					remove_task(id + TASK_SHOWZONES_START)
					PCC(id, "!tFinish Line !gHighlight !yhas been !tdisabled!y!")
				}
				else
				{
					g_blHighlight_Finish[id] = true
					set_task(1.0, "showZones_Finish", id + TASK_SHOWZONES_FINISH, "", 0, "b", 0)
					PCC(id, "!tFinish Line !gHighlight !yhas been !tenabled!y!")
				}
			}
		}
		case 2:
		{
			if (g_iType[id] == 0)
			{
				if (g_iTotalZones_Start)
				{
					menu_destroy(iMenu)
					menuSelect(id)
					return PLUGIN_HANDLED
				}
				else noZones_Start(id)
			}
			else if (g_iType[id] == 1)
			{
				if (g_iTotalZones_Finish)
				{
					menu_destroy(iMenu)
					menuSelect(id)
					return PLUGIN_HANDLED
				}
				else noZones_Finish(id)
			}
		}
		case 3:
		{
			if (g_iType[id] == 0)
			{
				if (is_zone_start(g_iCurrentZone[id][0]))
				{
					PCC(id, "You have removed the !gStart Line!y.")
					player_remove_zone_start(id)
				}
				else invalidZone_Start(id)
			}
			else if (g_iType[id] == 1)
			{
				if (is_zone_finish(g_iCurrentZone[id][0]))
				{
					PCC(id, "You have removed the !gFinish Line!y.")
					player_remove_zone_finish(id)
				}
				else invalidZone_Finish(id)
			}
		}
		case 4:
		{
			if (g_iType[id] == 0)
			{
				if (is_zone_start(g_iCurrentZone[id][0]))
				{
					new Float:flOrigin[3]
					pev(g_iCurrentZone[id][0], pev_origin, flOrigin)
					set_pev(id, pev_origin, flOrigin)
					PCC(id, "Teleported to !gStart Line!y.")
				}
				else invalidZone_Start(id)
			}
			else if (g_iType[id] == 1)
			{
				if (is_zone_finish(g_iCurrentZone[id][0]))
				{
					new Float:flOrigin[3]
					pev(g_iCurrentZone[id][0], pev_origin, flOrigin)
					set_pev(id, pev_origin, flOrigin)
					PCC(id, "Teleported to !gFinish Line!y.")
				}
				else invalidZone_Finish(id)
			}
		}
	}
	
	menu_destroy(iMenu)
	RaceMenu(id, g_iType[id])
	return PLUGIN_HANDLED
}
public menuSelect(id)
{
	new szTitle[128], szItem[64], szTemp[32], szZone[5], iZone
	
	formatex(szTitle, charsmax(szTitle), "\wSelect Menu")
	new iMenu = menu_create(szTitle, "handler_Select")
	
	formatex(szItem, charsmax(szItem), "\rGo back")
	menu_additem(iMenu, szItem, "0")
	
	formatex(szItem, charsmax(szItem), "\rDeselect")
	menu_additem(iMenu, szItem, "1")
	
	if (g_iType[id] == 0)
	{
		for (new i; i < g_iTotalZones_Start; i++)
		{
			iZone = ArrayGetCell(g_aZones_Start, i)
			num_to_str(iZone, szZone, charsmax(szZone))
			formatex(szItem, charsmax(szItem), "Start Line", iZone)
			
			if (g_iCurrentZone[id][0] == iZone)
			{
				formatex(szTemp, charsmax(szTemp), " \y[SELECTED]")
				add(szItem, charsmax(szItem), szTemp)
			}
			
			menu_additem(iMenu, szItem, szZone)
		}
	}
	else if (g_iType[id] == 1)
	{
		for (new i; i < g_iTotalZones_Finish; i++)
		{
			iZone = ArrayGetCell(g_aZones_Finish, i)
			num_to_str(iZone, szZone, charsmax(szZone))
			formatex(szItem, charsmax(szItem), "Finish Line", iZone)
			
			if (g_iCurrentZone[id][0] == iZone)
			{
				formatex(szTemp, charsmax(szTemp), " \y[SELECTED]")
				add(szItem, charsmax(szItem), szTemp)
			}
			
			menu_additem(iMenu, szItem, szZone)
		}
	}
	
	menu_display(id, iMenu, 0)
	return PLUGIN_HANDLED
}

public handler_Select(id, iMenu, Item)
{
	switch(Item)
	{
		case MENU_EXIT:
		{
			menu_destroy(iMenu)
			Command_RaceMenu(id)
			return PLUGIN_HANDLED
		}
		case 0:
		{
			menu_destroy(iMenu)
			RaceMenu(id, g_iType[id])
			return PLUGIN_HANDLED
		}
		case 1:
		{
			g_iCurrentZone[id][0] = 0
			PCC(id, "%s Line deselected.", g_iType[id] == 0 ? "Start" : "Finish")
			menu_destroy(iMenu)
			menuSelect(id)
			return PLUGIN_HANDLED
		}
	}
	
	new szData[6], iName[64], iAccess, iCallback
	menu_item_getinfo(iMenu, Item, iAccess, szData, charsmax(szData), iName, charsmax(iName), iCallback)
	new iKey = str_to_num(szData)
	
	g_iCurrentZone[id][0] = iKey
	g_iCurrentZone[id][1] = Item - 2
	PCC(id, "Selected !g%s Line", g_iType[id] == 0 ? "Start" : "Finish")
	
	draw_beam(id, iKey)
	
	menu_destroy(iMenu)
	menuSelect(id)
	return PLUGIN_HANDLED
}

CreateZone_Start(Float:flFirstPoint[3], Float:flSecondPoint[3])
{
	new Float:flCenter[3], Float:flSize[3]
	new Float:flMins[3], Float:flMaxs[3]
	
	for (new i; i < 3; i++)
	{
		flCenter[i] = (flFirstPoint[i] + flSecondPoint[i]) / 2.0
		flSize[i] = get_float_difference(flFirstPoint[i], flSecondPoint[i])
		flMins[i] = flSize[i] / -2.0
		flMaxs[i] = flSize[i] / 2.0
	}
	
	new iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, g_szEntString))
	
	if (pev_valid(iEnt))
	{
		engfunc(EngFunc_SetOrigin, iEnt, flCenter)
		set_pev(iEnt, pev_classname, g_szClassname_Start)
		dllfunc(DLLFunc_Spawn, iEnt)
		set_pev(iEnt, pev_movetype, MOVETYPE_NONE)
		set_pev(iEnt, pev_solid, SOLID_TRIGGER)
		engfunc(EngFunc_SetSize, iEnt, flMins, flMaxs)
	}
	
	new szCoords[200], szZone[5]
	formatex(szCoords, charsmax(szCoords), "%f %f %f %f %f %f", flFirstPoint[0], flFirstPoint[1], flFirstPoint[2], flSecondPoint[0], flSecondPoint[1], flSecondPoint[2])
	num_to_str(iEnt, szZone, charsmax(szZone))
	TrieSetString(g_tZones_Start, szZone, szCoords)
	ArrayPushCell(g_aZones_Start, iEnt)
	g_iTotalZones_Start++
}
CreateZone_Finish(Float:flFirstPoint[3], Float:flSecondPoint[3])
{
	new Float:flCenter[3], Float:flSize[3]
	new Float:flMins[3], Float:flMaxs[3]
	
	for (new i; i < 3; i++)
	{
		flCenter[i] = (flFirstPoint[i] + flSecondPoint[i]) / 2.0
		flSize[i] = get_float_difference(flFirstPoint[i], flSecondPoint[i])
		flMins[i] = flSize[i] / -2.0
		flMaxs[i] = flSize[i] / 2.0
	}
	
	new iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, g_szEntString))
	
	if (pev_valid(iEnt))
	{
		engfunc(EngFunc_SetOrigin, iEnt, flCenter)
		set_pev(iEnt, pev_classname, g_szClassname_Finish)
		dllfunc(DLLFunc_Spawn, iEnt)
		set_pev(iEnt, pev_movetype, MOVETYPE_NONE)
		set_pev(iEnt, pev_solid, SOLID_TRIGGER)
		engfunc(EngFunc_SetSize, iEnt, flMins, flMaxs)
	}
	
	new szCoords[200], szZone[5]
	formatex(szCoords, charsmax(szCoords), "%f %f %f %f %f %f", flFirstPoint[0], flFirstPoint[1], flFirstPoint[2], flSecondPoint[0], flSecondPoint[1], flSecondPoint[2])
	num_to_str(iEnt, szZone, charsmax(szZone))
	TrieSetString(g_tZones_Finish, szZone, szCoords)
	ArrayPushCell(g_aZones_Finish, iEnt)
	g_iTotalZones_Finish++
}

public showZones_Start(id)
{
	id -= TASK_SHOWZONES_START
	
	if (!is_user_connected(id))
	{
		remove_task(id + TASK_SHOWZONES_START)
		return
	}
	
	new iMins[3], iMaxs[3], iEnt
	new Float:flUserOrigin[3], Float:flOrigin[3], Float:flMins[3], Float:flMaxs[3]
	new bool:blCurrentZone
	pev(id, pev_origin, flUserOrigin)
	
	while ((iEnt = find_ent_by_class(iEnt, g_szClassname_Start)))
	{
		blCurrentZone = (iEnt == g_iCurrentZone[id][0]) ? true : false
		
		pev(iEnt, pev_origin, flOrigin)
		
		if (get_distance_f(flUserOrigin, flOrigin) > ZONE_VIEWDISTANCE)
			continue
		
		pev(iEnt, pev_mins, flMins)
		pev(iEnt, pev_maxs, flMaxs)
	
		flMins[0] += flOrigin[0]
		flMins[1] += flOrigin[1]
		flMins[2] += flOrigin[2]
		flMaxs[0] += flOrigin[0]
		flMaxs[1] += flOrigin[1]
		flMaxs[2] += flOrigin[2]
		
		FVecIVec(flMins, iMins)
		FVecIVec(flMaxs, iMaxs)

		draw_line_start(id, blCurrentZone, iMaxs[0], iMaxs[1], iMaxs[2], iMins[0], iMaxs[1], iMaxs[2])
		draw_line_start(id, blCurrentZone, iMaxs[0], iMaxs[1], iMaxs[2], iMaxs[0], iMins[1], iMaxs[2])
		draw_line_start(id, blCurrentZone, iMaxs[0], iMaxs[1], iMaxs[2], iMaxs[0], iMaxs[1], iMins[2])
		draw_line_start(id, blCurrentZone, iMins[0], iMins[1], iMins[2], iMaxs[0], iMins[1], iMins[2])
		draw_line_start(id, blCurrentZone, iMins[0], iMins[1], iMins[2], iMins[0], iMaxs[1], iMins[2])
		draw_line_start(id, blCurrentZone, iMins[0], iMins[1], iMins[2], iMins[0], iMins[1], iMaxs[2])
		draw_line_start(id, blCurrentZone, iMins[0], iMaxs[1], iMaxs[2], iMins[0], iMaxs[1], iMins[2])
		draw_line_start(id, blCurrentZone, iMins[0], iMaxs[1], iMins[2], iMaxs[0], iMaxs[1], iMins[2])
		draw_line_start(id, blCurrentZone, iMaxs[0], iMaxs[1], iMins[2], iMaxs[0], iMins[1], iMins[2])
		draw_line_start(id, blCurrentZone, iMaxs[0], iMins[1], iMins[2], iMaxs[0], iMins[1], iMaxs[2])
		draw_line_start(id, blCurrentZone, iMaxs[0], iMins[1], iMaxs[2], iMins[0], iMins[1], iMaxs[2])
		draw_line_start(id, blCurrentZone, iMins[0], iMins[1], iMaxs[2], iMins[0], iMaxs[1], iMaxs[2])
	}
}

public showZones_Finish(id)
{
	id -= TASK_SHOWZONES_FINISH
	
	if (!is_user_connected(id))
	{
		remove_task(id + TASK_SHOWZONES_FINISH)
		return
	}
	
	new iMins[3], iMaxs[3], iEnt
	new Float:flUserOrigin[3], Float:flOrigin[3], Float:flMins[3], Float:flMaxs[3]
	new bool:blCurrentZone
	pev(id, pev_origin, flUserOrigin)
	
	while ((iEnt = find_ent_by_class(iEnt, g_szClassname_Finish)))
	{
		blCurrentZone = (iEnt == g_iCurrentZone[id][0]) ? true : false
		
		pev(iEnt, pev_origin, flOrigin)
		
		if (get_distance_f(flUserOrigin, flOrigin) > ZONE_VIEWDISTANCE)
			continue
		
		pev(iEnt, pev_mins, flMins)
		pev(iEnt, pev_maxs, flMaxs)
	
		flMins[0] += flOrigin[0]
		flMins[1] += flOrigin[1]
		flMins[2] += flOrigin[2]
		flMaxs[0] += flOrigin[0]
		flMaxs[1] += flOrigin[1]
		flMaxs[2] += flOrigin[2]
		
		FVecIVec(flMins, iMins)
		FVecIVec(flMaxs, iMaxs)

		draw_line_finish(id, blCurrentZone, iMaxs[0], iMaxs[1], iMaxs[2], iMins[0], iMaxs[1], iMaxs[2])
		draw_line_finish(id, blCurrentZone, iMaxs[0], iMaxs[1], iMaxs[2], iMaxs[0], iMins[1], iMaxs[2])
		draw_line_finish(id, blCurrentZone, iMaxs[0], iMaxs[1], iMaxs[2], iMaxs[0], iMaxs[1], iMins[2])
		draw_line_finish(id, blCurrentZone, iMins[0], iMins[1], iMins[2], iMaxs[0], iMins[1], iMins[2])
		draw_line_finish(id, blCurrentZone, iMins[0], iMins[1], iMins[2], iMins[0], iMaxs[1], iMins[2])
		draw_line_finish(id, blCurrentZone, iMins[0], iMins[1], iMins[2], iMins[0], iMins[1], iMaxs[2])
		draw_line_finish(id, blCurrentZone, iMins[0], iMaxs[1], iMaxs[2], iMins[0], iMaxs[1], iMins[2])
		draw_line_finish(id, blCurrentZone, iMins[0], iMaxs[1], iMins[2], iMaxs[0], iMaxs[1], iMins[2])
		draw_line_finish(id, blCurrentZone, iMaxs[0], iMaxs[1], iMins[2], iMaxs[0], iMins[1], iMins[2])
		draw_line_finish(id, blCurrentZone, iMaxs[0], iMins[1], iMins[2], iMaxs[0], iMins[1], iMaxs[2])
		draw_line_finish(id, blCurrentZone, iMaxs[0], iMins[1], iMaxs[2], iMins[0], iMins[1], iMaxs[2])
		draw_line_finish(id, blCurrentZone, iMins[0], iMins[1], iMaxs[2], iMins[0], iMaxs[1], iMaxs[2])
	}
}

draw_beam(id, iZone = 0)
{
	new iUserOrigin[3], iPointOrigin[3]
	get_user_origin(id, iUserOrigin)
	
	if (iZone && pev_valid(iZone))
	{
		new Float:flOrigin[3]
		pev(iZone, pev_origin, flOrigin)
		FVecIVec(flOrigin, iPointOrigin)
	}
	else get_user_origin(id, iPointOrigin, 3)
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMPOINTS)
	write_coord(iUserOrigin[0])
	write_coord(iUserOrigin[1])
	write_coord(iUserOrigin[2])
	write_coord(iPointOrigin[0])
	write_coord(iPointOrigin[1])
	write_coord(iPointOrigin[2])
	write_short(g_iBeamSprite)
	write_byte(BEAM_STARTFRAME)
	write_byte(BEAM_FRAMERATE)
	write_byte(BEAM_LIFE)
	write_byte(BEAM_WIDTH)
	write_byte(BEAM_NOISE)
	write_byte(iZone ? BEAM_COLOR_SELECT_RED : BEAM_COLOR_RED)
	write_byte(iZone ? BEAM_COLOR_SELECT_GREEN : BEAM_COLOR_GREEN)
	write_byte(iZone ? BEAM_COLOR_SELECT_BLUE : BEAM_COLOR_BLUE)
	write_byte(BEAM_BRIGHTNESS)
	write_byte(BEAM_SPEED)
	message_end()
}

draw_line_start(id, bool:blCurrentZone, x1, y1, z1, x2, y2, z2)
{
	message_begin(id ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, SVC_TEMPENTITY, _, id ? id : 0)
	write_byte(TE_BEAMPOINTS)
	write_coord(x1)
	write_coord(y1)
	write_coord(z1)
	write_coord(x2)
	write_coord(y2)
	write_coord(z2)
	write_short(g_iZoneSprite)
	write_byte(ZONE_STARTFRAME)
	write_byte(ZONE_FRAMERATE)
	write_byte(ZONE_LIFE)
	write_byte(ZONE_WIDTH)
	write_byte(ZONE_NOISE)
	write_byte(blCurrentZone ? ZONE_COLOR_SELECTED_RED : START_ZONE_COLOR_RED)
	write_byte(blCurrentZone ? ZONE_COLOR_SELECTED_GREEN : START_ZONE_COLOR_GREEN)
	write_byte(blCurrentZone ? ZONE_COLOR_SELECTED_BLUE : START_ZONE_COLOR_BLUE)
	write_byte(ZONE_BRIGHTNESS)
	write_byte(ZONE_SPEED)
	message_end()
}

draw_line_finish(id, bool:blCurrentZone, x1, y1, z1, x2, y2, z2)
{
	message_begin(id ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, SVC_TEMPENTITY, _, id ? id : 0)
	write_byte(TE_BEAMPOINTS)
	write_coord(x1)
	write_coord(y1)
	write_coord(z1)
	write_coord(x2)
	write_coord(y2)
	write_coord(z2)
	write_short(g_iZoneSprite)
	write_byte(ZONE_STARTFRAME)
	write_byte(ZONE_FRAMERATE)
	write_byte(ZONE_LIFE)
	write_byte(ZONE_WIDTH)
	write_byte(ZONE_NOISE)
	write_byte(blCurrentZone ? ZONE_COLOR_SELECTED_RED : FINISH_ZONE_COLOR_RED)
	write_byte(blCurrentZone ? ZONE_COLOR_SELECTED_GREEN : FINISH_ZONE_COLOR_GREEN)
	write_byte(blCurrentZone ? ZONE_COLOR_SELECTED_BLUE : FINISH_ZONE_COLOR_BLUE)
	write_byte(ZONE_BRIGHTNESS)
	write_byte(ZONE_SPEED)
	message_end()
}

menu_reopen(id)
{
	new iNewMenu, iMenu = player_menu_info(id, iMenu, iNewMenu)
	
	if (iMenu)
	{
		show_menu(id, 0, "^n", 1)
		RaceMenu(id, g_iType[id])
	}
}

noZones_Start(id)
	PCC(id, "There aren't any start lines on this map.")
	
invalidZone_Start(id)
	PCC(id, "Invalid start line selected, please choose an other one.")

noZones_Finish(id)
	PCC(id, "There aren't any finish lines on this map.")
	
invalidZone_Finish(id)
	PCC(id, "Invalid finish line selected, please choose an other one.")
	
player_remove_zone_start(id)
{
	new szZone[5]
	num_to_str(g_iCurrentZone[id][0], szZone, charsmax(szZone))
	ArrayDeleteItem(g_aZones_Start, g_iCurrentZone[id][1])
	TrieDeleteKey(g_tZones_Start, szZone)
	remove_entity(g_iCurrentZone[id][0])
	g_iCurrentZone[id][0] = 0
	g_iCurrentZone[id][1] = 0
	g_iTotalZones_Start--
}
player_remove_zone_finish(id)
{
	new szZone[5]
	num_to_str(g_iCurrentZone[id][0], szZone, charsmax(szZone))
	ArrayDeleteItem(g_aZones_Finish, g_iCurrentZone[id][1])
	TrieDeleteKey(g_tZones_Finish, szZone)
	remove_entity(g_iCurrentZone[id][0])
	g_iCurrentZone[id][0] = 0
	g_iCurrentZone[id][1] = 0
	g_iTotalZones_Finish--
}

bool:is_zone_start(iEnt)
{
	if (!pev_valid(iEnt))
		return false
		
	new szClass[32]
	pev(iEnt, pev_classname, szClass, charsmax(szClass))
	return equal(szClass, g_szClassname_Start) ? true : false
}

bool:is_zone_finish(iEnt)
{
	if (!pev_valid(iEnt))
		return false
		
	new szClass[32]
	pev(iEnt, pev_classname, szClass, charsmax(szClass))
	return equal(szClass, g_szClassname_Finish) ? true : false
}

Float:get_float_difference(Float:flNumber1, Float:flNumber2)
	return (flNumber1 > flNumber2) ? (flNumber1 - flNumber2) : (flNumber2 - flNumber1)

/* ==============================================
	DeathRun RACE System Begins Here!
============================================== */
	
public plugin_natives()
{
	register_native("get_user_race_points", "_get_user_race_points")
	register_native("set_user_race_points", "_set_user_race_points")
}
public _get_user_race_points(iPlugin, iParams)
{
	return g_iRacePoints[get_param(1)]
}
public _set_user_race_points(iPlugin, iParams)
{
	new id = get_param(1)
	g_iRacePoints[id] = max(0, get_param(2))
	return g_iRacePoints[id]
}
public fwd_Think(iEnt)
{
	new iNum, iTemp[33], bool:bContinue
	new szBuffer[1024]
	pev(iEnt, pev_classname, szBuffer, 1023)
	
	if (equal(szBuffer, "msgent"))
	{
		switch(random_num(1, 4))
		{
			case 1:
			{
				PCC(0, "Want to challenge someone to race? Type !g/race !yand challange a player!")
			}
			case 2:
			{
				PCC(0, "For !twinning !ya race you can get!g 3 lives!y!")
			}
			#if defined MYSQL_SUPPORT
			case 3:
			{
				PCC(0, "You want to see your !gRank !yand !gWins!y? Write in chat !g/rank")
			}
			case 4:
			{
				PCC(0, "Want to see !gTop10 Racers!y? Write in chat !g/top10")
			}
			#endif
		}
		set_pev(iEnt, pev_nextthink, get_gametime() + 45.0)
	} 
	else if (equal(szBuffer, "racesent"))
	{
		new szName[2][64]
		
		PrintChatColor(0, PRINT_COLOR_PLAYERTEAM, "!tCurrent Races!g:")
		
		for (new i = 1; i <=  33; i++)
		{
			bContinue = false
			
			for (new iID = 0; iID < 33; iID++)
			{
				if (iTemp[iID] == i)
					bContinue = true
			}
			
			if (!is_user_connected(i) || !g_bUserRacing[i] || bContinue)
				continue
			
			get_user_name(i, szName[0], 63)	
			get_user_name(g_iChallenger[i], szName[1], 63)
			
			PrintChatColor(0, PRINT_COLOR_PLAYERTEAM, "!y..:: !g%s !tVS. !g%s!y ::..", szName[0], szName[1])
			
			iTemp[iNum] = i
			iNum++
			iTemp[iNum] = g_iChallenger[i]
			iNum++
		}
		
		if (iNum < 2)
		{
			PrintChatColor(0, PRINT_COLOR_PLAYERTEAM, "!g* !tNo one is racing!")
		}
		
		set_pev(iEnt, pev_nextthink, get_gametime() + 90.0)
	}
	
	return FMRES_IGNORED
}

public client_connect(id)
{
	g_iFinish[id] = true
	
	if (task_exists(id + TASK_START_RACE))
	{
		remove_task(id + TASK_START_RACE)
	}
		
	g_bUserRacing[id] = false
	g_bRaceOffline[id] = false
	
	if (1 <= g_iChallenger[g_iChallenger[id]] <= 32)
	{
		g_iChallenger[g_iChallenger[id]] = 0
		g_flHisTime[g_iChallenger[id]] = 0.0
	}
	g_flHisTime[id] = 0.0
	g_iChallenger[id] = 0
	
	#if defined MYSQL_SUPPORT
	get_user_name(id, szName, charsmax(szName))
	
	if (strcmp(szPlayerName[id], szName))
	{
		g_iWins[id] = 0
		g_iLosses[id] = 0
		g_iTotalRaces[id] = 0
		g_iRacePoints[id] = 0
		g_bDownload_Data[id] = false
		Load_Data(id)
	}
	#endif
}

public client_disconnected(id)
{
	if (task_exists(id + TASK_START_RACE))
	{
		remove_task(id + TASK_START_RACE)
	}
	
	g_bUserRacing[id] = false
	g_bRaceOffline[id] = false
	
	if (1 <= g_iChallenger[g_iChallenger[id]] <= 32)
	{
		g_iChallenger[g_iChallenger[id]] = 0
		g_flHisTime[g_iChallenger[id]] = 0.0
	}
	
	g_flHisTime[id] = 0.0
	g_iChallenger[id] = 0
	
	#if defined MYSQL_SUPPORT
	Save_Data(id)
	#endif
}

public OnPlayerDeath()
{
	new iChallenged = read_data(2)
	
	if (g_bUserRacing[iChallenged] && is_user_connected(iChallenged) && is_user_connected(g_iChallenger[iChallenged]))
	{
		new szName[32], szLoserName[32]
		get_user_name(iChallenged, szLoserName, charsmax(szLoserName))
		get_user_name(g_iChallenger[iChallenged], szName, charsmax(szName))
			
		PCC(0, "!t%s !ywon the race, because !t%s!y died", szName, szLoserName)
		
		#if defined MYSQL_SUPPORT
		PCC(g_iChallenger[iChallenged], "You got !g%i Lives !y and !g%i Race Points !yfor winning the race!", g_iLivesBet, g_iRPBet)
		g_iWins[g_iChallenger[iChallenged]]++
		g_iLosses[iChallenged]++
		g_iTotalRaces[g_iChallenger[iChallenged]]++
		g_iTotalRaces[iChallenged]++
		g_iRacePoints[g_iChallenger[iChallenged]] += g_iRPBet
		
		if (g_iRacePoints[iChallenged] >= 1)
		{
			PCC(iChallenged, "You lost !g%i Lives !yand !g%i Race Points !yfor !tlosing!y the race!", g_iLivesBet, g_iRPBet)
			g_iRacePoints[iChallenged] -= g_iRPBet
		}
		else
		{
			PCC(iChallenged, "You lost !g%i Lives !yfor !tlosing!y the race!", g_iLivesBet)
		}
		set_user_lives(g_iChallenger[iChallenged], get_user_lives(g_iChallenger[iChallenged]) + (g_iLivesBet * 2))
		
		Save_Data(iChallenged)
		set_task(0.1, "Load_Data", iChallenged)
		#endif
		
		#if defined COLOR_RACERS
		set_user_rendering(iChallenged)
		set_user_rendering(g_iChallenger[iChallenged])
		#endif
		
		g_iFinish[iChallenged] = true
			
		g_bUserRacing[iChallenged] = false
		g_bUserRacing[g_iChallenger[iChallenged]] = false
			
		g_flHisTime[iChallenged] = 0.0
		g_flHisTime[g_iChallenger[iChallenged]] = 0.0
			
		g_iChallenger[g_iChallenger[iChallenged]] = 0
		g_iChallenger[iChallenged] = 0	
	}
	
	return PLUGIN_CONTINUE
	
}

public fwPlayerFinished(id)
{
	if (!g_bUserRacing[id])
		return PLUGIN_CONTINUE
		
	new szName[64], szLoserName[32]
	get_user_name(id, szName, charsmax(szName))
	get_user_name(g_iChallenger[id], szLoserName, charsmax(szLoserName))
	
	new Float:iTime
	iTime = get_gametime() - g_flHisTime[id]
	
	show_finish_message(id, iTime, szName, szLoserName)
	
	#if defined MYSQL_SUPPORT
	g_iLosses[g_iChallenger[id]]++
	g_iWins[id]++
	g_iTotalRaces[id]++
	g_iTotalRaces[g_iChallenger[id]]++
	g_iRacePoints[id] += g_iRPBet
	
	if (g_iRacePoints[g_iChallenger[id]] >= 1)
	{
		PCC(g_iChallenger[id], "You lost !g%i Lives !yand !g%i Race Points !yfrom !t%s !ybecause you lost the race!", g_iLivesBet, g_iRPBet, szName)
		g_iRacePoints[g_iChallenger[id]] -= g_iRPBet
	}
	else
	{
		PCC(g_iChallenger[id], "You lost !g%i Lives !yfrom !t%s !ybecause you lost the race!", g_iLivesBet, szName)
	}
	PCC(id, "You got !g%i Lives !y and !g%i Race Points !yfor winning the race!", g_iLivesBet, g_iRPBet)
	
	set_user_lives(id, get_user_lives(id) + (g_iLivesBet * 2))
	
	Save_Data(id)
	set_task(0.1, "Load_Data", id)
	#endif
	
	#if defined COLOR_RACERS
	if (is_user_connected(id))
		set_user_rendering(id)
		
	if (is_user_connected(g_iChallenger[id]))
		set_user_rendering(g_iChallenger[id])
	#endif
	
	set_pev(g_iChallenger[id], pev_origin, g_flSpawnOrigin)
	
	g_iFinish[id] = true
	
	g_bUserRacing[id] = false
	g_bUserRacing[g_iChallenger[id]] = false
	
	g_flHisTime[id] = 0.0
	g_flHisTime[g_iChallenger[id]] = 0.0
	
	g_iChallenger[g_iChallenger[id]] = 0
	g_iChallenger[id] = 0
	
	return PLUGIN_CONTINUE
}

public show_finish_message(id, Float:flRunTime, const szRunnerName[], const szBadRunner[])
{
	new iMin, iSec, iMS
	
	iMin = floatround(flRunTime / 60.0, floatround_floor) >= 1 ? floatround(flRunTime / 60.0, floatround_floor) : 0
	iSec = floatround(flRunTime - iMin * 60.0, floatround_floor)
	iMS = floatround((flRunTime - (iMin * 60.0 + iSec)) * 100.0, floatround_floor)
	
	PCC(0, "!t%s !ywon the race against !t%s !ywith time !g%02i:%02i.%02i", szRunnerName, szBadRunner, iMin, iSec, iMS)
}

public cmdRaceOffline(id)
{
	g_bRaceOffline[id] = !g_bRaceOffline[id]
	PCC(id, "Switched to !g%s !ymode.", g_bRaceOffline[id] ? "offline" : "online")
	return PLUGIN_HANDLED
}

public cmdRace(id)
{
	if (g_iTotalZones_Start + g_iTotalZones_Finish <= 1)
	{
		PCC(id, "You cannot race at the moment, because there is no !t%s !gLine!y!", g_iTotalZones_Start > 0 ? "Finish" : "Start")
		return PLUGIN_HANDLED
	}
	
	if (g_bUserRacing[id] || !g_iFinish[id])
	{
		PCC(id, "You cannot race at the moment, because you are !tracing already!y!")
		return PLUGIN_HANDLED
	}
	
	if (cs_get_user_team(id) == CS_TEAM_T)
	{
		PCC(id, "You cannot race at the moment, because you are !tTerrorist!y!")
		return PLUGIN_HANDLED
	}
	
	if (!is_user_alive(id))
	{
		PCC(id, "You cannot race at the moment, because you are not !talive!y!")
		return PLUGIN_HANDLED
	}
	
	if (get_user_team(id) == 3)
	{
		PCC(id, "You cannot race at the moment, because you are !tspectator!y!")
		return PLUGIN_HANDLED
	}
		
	#if defined MYSQL_SUPPORT
	if (get_user_lives(id) < g_iLivesBet)
	{
		PCC(id, "You must have atleast !g3 Lives!y to race someone!")
		return PLUGIN_HANDLED
	}
	#endif
	
	new iMenu = menu_create("\y[\rFPS-Games\y] \wDeathRun Race", "SelectPlayer_Handle")
	
	new szName[32], szTempID[12], szDescription[64]
	new iPlayers[32], iNum, pChallenged
	get_players(iPlayers, iNum)
	
	menu_additem(iMenu, "\r[!]\yUpdate players\r[!]^n^t^t \yChallenge a player:^n", "0")
	
	for (new i; i < iNum; i++)
	{
		pChallenged = iPlayers[i]
		if (!is_user_alive(pChallenged) || get_user_team(pChallenged) != ZONE_RACE_TEAM || pChallenged == id)
			continue
		
		get_user_name(pChallenged, szName, charsmax(szName))
		if (g_bRaceOffline[pChallenged])
		{
			formatex(szDescription, charsmax(szDescription), "\d%s \y[\rOffline\y]", szName)
		}
		else
		{
			formatex(szDescription, charsmax(szDescription), g_bUserRacing[pChallenged] ? "\d%s \y[\rIn Race\y]" : "%s", szName)
		}
		num_to_str(pChallenged, szTempID, charsmax(szTempID))
		
		menu_additem(iMenu, szDescription, szTempID, 0, menu_makecallback("ChallangeMenu_Callback"))
	}
	
	menu_display(id, iMenu)
	return PLUGIN_HANDLED
}
public ChallangeMenu_Callback(id, iMenu, Item)
{
	new szInfo[6], szName[64]
	new iAccess, iCallBack
	menu_item_getinfo(iMenu, Item, iAccess, szInfo, charsmax(szInfo), szName,charsmax(szName), iCallBack)
	
	new iTempID = str_to_num(szInfo)
	
	if (g_bUserRacing[iTempID] || !is_user_alive(iTempID) || get_user_team(iTempID) != ZONE_RACE_TEAM
	|| g_bRaceOffline[iTempID])
	{
		return ITEM_DISABLED
	}
	
	#if defined MYSQL_SUPPORT
	if (get_user_lives(iTempID) < 3)
	{
		return ITEM_DISABLED
	}
	#endif
	return ITEM_ENABLED
}
public SelectPlayer_Handle(id, iMenu, Item)
{
	if (Item == MENU_EXIT)
	{
		menu_destroy(iMenu)
		return PLUGIN_HANDLED
	}
	
	new iAccess, iChallenged, iCallBack
	new szInfo[64]
	menu_item_getinfo(iMenu, Item, iAccess, szInfo, 63, _, _, iCallBack)
	iChallenged = str_to_num(szInfo)
	
	switch(Item)
	{
		case 0: cmdRace(id)
	}
	
	if (is_user_alive(iChallenged) && !g_bUserRacing[iChallenged])
	{
		new szName[32], szTName[32]
		get_user_name(id, szName, charsmax(szName))
		get_user_name(iChallenged, szTName, charsmax(szTName))
		PCC(0, "Player !t%s !ywants to race with !t%s!y!", szName, szTName)
		
		g_iChallenger[id] = iChallenged
		g_iChallenger[iChallenged] = id
		
		AskPlayer(iChallenged, id)
	}
	menu_destroy(iMenu)
	return PLUGIN_CONTINUE
	
}

public AskPlayer(id, iChallenged)
{
	new szName[64], szTitle[128]
	get_user_name(iChallenged, szName, charsmax(szName))
	formatex(szTitle, charsmax(szTitle), "%s^n^t^t\wDeathRun Race^n^n\wRace VS. \r%s \w?", MOD_MENU_PREFIX, szName)
	
	new iMenu = menu_create(szTitle, "AskPlayer_Handle")
	
	menu_additem(iMenu, "\yYes", "1")
	menu_additem(iMenu, "\rNo", "2")
	
	menu_setprop(iMenu, MPROP_EXIT, MEXIT_NEVER)
	menu_display(id, iMenu)
	
	return PLUGIN_HANDLED
}

public AskPlayer_Handle(id, iMenu, Item)
{
	new szInfo[6], szName[64], szChallengerName[32], szChallengedName[32]
	new iAccess, iCallBack
	menu_item_getinfo(iMenu, Item, iAccess, szInfo, charsmax(szInfo), szName, charsmax(szName), iCallBack)
	new iKey = str_to_num(szInfo)
	
	get_user_name(id, szChallengerName, charsmax(szChallengerName))
	get_user_name(g_iChallenger[id], szChallengedName, charsmax(szChallengedName))
	
	switch(iKey)
	{
		case 1:
		{
			if (g_bUserRacing[g_iChallenger[id]])
			{
				PCC(id, "You were late, !t%s!y is in race right now.", szChallengedName)
				return PLUGIN_HANDLED
			}
			
			if (!is_user_alive(id))
			{
				PCC(id, "You must be !talive !yto race!")
				return PLUGIN_HANDLED
			}
			if (!is_user_alive(g_iChallenger[id]))
			{
				PCC(id, "!t%s has died/disconnected", szChallengedName)
				return PLUGIN_HANDLED
			}
			
			if (!g_iChallenger[id])
			{
				menu_destroy(iMenu)
				return PLUGIN_HANDLED
			}
			else
			{
				PCC(g_iChallenger[id],"!t%s !yaccepted to race with you!", szChallengerName)
			
				g_iTimeToRace[id] = 3
				g_iChallenger[g_iChallenger[id]] = id
				g_bUserRacing[id] = true
				g_bUserRacing[g_iChallenger[id]] = true
				
				#if defined MYSQL_SUPPORT
				set_user_lives(id, get_user_lives(id) - g_iLivesBet)
				set_user_lives(g_iChallenger[id], get_user_lives(g_iChallenger[id]) - g_iLivesBet)
				#endif
				
				set_pev(id, pev_origin, g_flSpawnOrigin)
				set_pev(g_iChallenger[id], pev_origin, g_flSpawnOrigin)
				
				set_pev(id, pev_fixangle, 1)
				set_pev(g_iChallenger[id], pev_fixangle, 1)
				
				set_pev(id, pev_flags, pev(id, pev_flags) | FL_FROZEN)
				set_pev(g_iChallenger[id], pev_flags, pev(g_iChallenger[id], pev_flags) | FL_FROZEN)
				
				#if defined COLOR_RACERS
				if (is_user_connected(id))
					g_pColor[id] = random(sizeof gColors)
					
				if (is_user_connected(g_iChallenger[id]))
					g_pColor[g_iChallenger[id]] = random(sizeof gColors)
				#endif
				
				set_task(1.0, "StartRace", id + TASK_START_RACE, _, _, "a", g_iTimeToRace[id])
			}
			return PLUGIN_HANDLED
		}
		case 2:
		{
			PCC(g_iChallenger[id], "!t%s !yrefused to race with you!", szChallengerName)
			g_iChallenger[id] = 0
		}
	}
	menu_destroy(iMenu)
	return PLUGIN_HANDLED
}

public StartRace(id)
{
	id -= TASK_START_RACE
	
	g_iTimeToRace[id]--
	
	if (g_iTimeToRace[id] > 0)
	{
		PCC(id, "The race will begin in !g%i seconds!y!", g_iTimeToRace[id])
		PCC(g_iChallenger[id], "The race will begin in !g%i seconds!y!", g_iTimeToRace[id])
	} 
	else 
	{
		PrintChatColor(id, PRINT_COLOR_PLAYERTEAM,"!g           ..:: !tGo !gGo !tGo !g::..")
		PrintChatColor(id, PRINT_COLOR_PLAYERTEAM, "!g..:: !tGood Luck !g& !tHave Fun !g::..")
		
		PrintChatColor(g_iChallenger[id], PRINT_COLOR_PLAYERTEAM, "!g           ..:: !tGo !gGo !tGo !g::..")
		PrintChatColor(g_iChallenger[id], PRINT_COLOR_PLAYERTEAM, "!g..:: !tGood Luck !g& !tHave Fun !g::..")
		
		set_pev(id, pev_flags, pev(id, pev_flags) & ~FL_FROZEN)
		set_pev(g_iChallenger[id], pev_flags, pev(g_iChallenger[id], pev_flags) & ~FL_FROZEN)
		
		g_flHisTime[id] = get_gametime()
		g_flHisTime[g_iChallenger[id]] = get_gametime()
		
		#if defined COLOR_RACERS
		if (is_user_connected(id))
		{
			set_user_rendering(id, kRenderFxGlowShell, 
			gColors[g_pColor[id]][R], 
			gColors[g_pColor[id]][G], 
			gColors[g_pColor[id]][B], 
			kRenderNormal, 16)
		}
		
		if (is_user_connected(g_iChallenger[id]))
		{
			set_user_rendering(g_iChallenger[id], kRenderFxGlowShell, 
			gColors[g_pColor[g_iChallenger[id]]][R], 
			gColors[g_pColor[g_iChallenger[id]]][G], 
			gColors[g_pColor[g_iChallenger[id]]][B], 
			kRenderNormal, 16)
		}
		#endif
		
		if (task_exists(id + TASK_START_RACE))
		{
			remove_task(id + TASK_START_RACE)
		}
	}
	
	return PLUGIN_CONTINUE
}
public CreateAdEntitys()
{
	new iEnt[2]
	
	iEnt[0] = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	set_pev(iEnt[0], pev_classname, "msgent")
	set_pev(iEnt[0], pev_nextthink, get_gametime() + 120.0)
	
	iEnt[1] = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	set_pev(iEnt[1], pev_classname, "racesent")
	set_pev(iEnt[1], pev_nextthink, get_gametime() + 90.0)
	
	dllfunc(DLLFunc_Think, iEnt[0])
	dllfunc(DLLFunc_Think, iEnt[1])
}

#if defined MYSQL_SUPPORT

public Event_RoundEnd()
{
	for(new i = 1; i < 33; i++)
	{
		if (!g_iFinish[i] && g_bUserRacing[i])
		{
			if (is_user_connected(i) && is_user_connected(g_iChallenger[i]))
			{
				set_user_lives(i, get_user_lives(i) + g_iLivesBet)
				set_user_lives(g_iChallenger[i], get_user_lives(g_iChallenger[i]) + g_iLivesBet)
				
				set_user_rendering(i)
				set_user_rendering(g_iChallenger[i])
			}
		}
	}
}

public client_authorized(id)
{
	get_user_name(id, szPlayerName[id], charsmax(szPlayerName[]))
}

public MySql_Init()
{
	new Host[32], User[32], Pass[32], DB[32]
	get_cvar_string("amx_race_host", Host, 31)
	get_cvar_string("amx_race_user", User, 31)
	get_cvar_string("amx_race_pass", Pass, 31)
	get_cvar_string("amx_race_db", DB, 31)
	g_SqlTuple = SQL_MakeDbTuple(Host,User,Pass,DB)
	
	new error, szError[128]
	new Handle:hConn = SQL_Connect(g_SqlTuple,error,szError, 127)
	if (error)
	{
		log_amx("Error: %s", szError)
		return
	}
	
	new Handle:Queries = SQL_PrepareQuery(hConn,"CREATE TABLE IF NOT EXISTS `%s` (name VARCHAR(64) NOT NULL, wins INT(10) NOT NULL DEFAULT 0, lost INT(10) NOT NULL DEFAULT 0, race_points INT(10) NOT NULL DEFAULT 0, total_races INT(10) NOT NULL DEFAULT 0, PRIMARY KEY(name))", TABLE)
	
	SQL_Execute(Queries)
	SQL_FreeHandle(Queries)
	SQL_FreeHandle(hConn)
}

public Load_Data(id)
{
	new name[64], szTemp[512]
	get_user_name(id, name, 63)
	replace_all(name, 63, "'", "\'")
	replace_all(name, 63, "`", "\`")
	
	new data[1]
	data[0] = id
	
	formatex(szTemp,charsmax(szTemp),"SELECT * FROM `%s` WHERE `name` = '%s'", TABLE, name)
	SQL_ThreadQuery(g_SqlTuple, "register_client", szTemp, data, sizeof(data))
}

public register_client(failstate, Handle:query, error[],errcode, data[], datasize)
{
	if (failstate != TQUERY_SUCCESS)
	{
		log_amx("<Query> Error: %s", error)
		return
	}
	
	new id = data[0]
	
	if (!is_user_connected(id) && !is_user_connecting(id))
	{
		return
	}
	
	if (SQL_NumRows(query))
	{
		SQL_ReadResult(query, SQL_FieldNameToNum(query, "name"), szName, 63)
		g_iWins[id]  = SQL_ReadResult(query, SQL_FieldNameToNum(query, "wins"))
		g_iLosses[id]  = SQL_ReadResult(query, SQL_FieldNameToNum(query, "lost"))
		g_iRacePoints[id] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "race_points"))
		g_iTotalRaces[id] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "total_races"))
		g_bDownload_Data[id] = true
	} 
	else
	{
		get_user_name(id, szName, charsmax(szName))
		replace_all(szName, charsmax(szName), "'", "\'")
		replace_all(szName, charsmax(szName), "`", "\`")
		
		new szTemp[512], data[1]
		data[0] = id
		formatex(szTemp, charsmax(szTemp), "INSERT INTO `%s` (`name`, `wins`,`lost`,`race_points`,`total_races`) VALUES ('%s','%d','%d','%d','%d')", TABLE, szName, g_iWins[id], g_iLosses[id], g_iRacePoints[id], g_iTotalRaces[id])
		SQL_ThreadQuery(g_SqlTuple, "IgnoreHandleInsert", szTemp, data, 1)
	}
}
public Save_Data(id)
{	
	if (!g_bDownload_Data[id])
	{
		Load_Data(id)
		return PLUGIN_HANDLED
	}
	
	new szTemp[512]
	get_user_name(id, szName, charsmax(szName))
	replace_all(szName, charsmax(szName), "'", "\'")
	replace_all(szName, charsmax(szName), "`", "\`")
	
	formatex(szTemp, charsmax(szTemp),"UPDATE `%s` SET `wins` = '%d',`lost` = '%d',`race_points` = '%d',`total_races` = '%d' WHERE `name` = '%s'", TABLE, g_iWins[id], g_iLosses[id], g_iRacePoints[id], g_iTotalRaces[id], szName)
	SQL_ThreadQuery(g_SqlTuple, "IgnoreHandleSave", szTemp)
	
	return PLUGIN_CONTINUE
}

public IgnoreHandleInsert(failstate, Handle:query, error[], errnum, data[], size)
{
	if (failstate != TQUERY_SUCCESS)
	{
		log_amx("<Query> Error: %s", error)
		return
	}
	g_bDownload_Data[data[0]] = true
}

public IgnoreHandleSave(failstate, Handle:query, error[], errnum, data[], size)
{
	if (failstate != TQUERY_SUCCESS)
	{
		log_amx("<Query> Error: %s", error)
		return
	}
}

public CBasePlayer_Spawn(id)
{
	if (is_user_alive(id))
	{
		#if defined MYSQL_SUPPORT
		Save_Data(id)
		set_task(0.1, "Load_Data", id)
		#endif
		
		g_bUserRacing[id] = false
		g_bUserRacing[g_iChallenger[id]] = false
		
		g_flHisTime[id] = 0.0
		g_flHisTime[g_iChallenger[id]] = 0.0
		
		g_iChallenger[g_iChallenger[id]] = 0
		g_iChallenger[id] = 0
		g_iFinish[id] = true
	}
}

public Command_Top10(id)
{
	new szTemp[512], data[1]
	data[0] = id
	format(szTemp,charsmax(szTemp),"SELECT * FROM `%s` ORDER BY wins DESC LIMIT 0,10", TABLE)
	SQL_ThreadQuery(g_SqlTuple,"Sql_Top", szTemp, data, 1)
}

public Sql_Top(FailState, Handle:Query, Error[], Errcode, pPlayer[], DataSize)
{
	if (FailState == TQUERY_CONNECT_FAILED)
		log_amx("Load - Could not connect to SQL database.  [%d] %s", Errcode, Error)
	else if (FailState == TQUERY_QUERY_FAILED)
		log_amx("Load Query failed. [%d] %s", Errcode, Error)

	new id
	id = pPlayer[0]
	
	new iRow = SQL_NumResults(Query)
	
	new szNames[12][64], szWins[12], szLosses[12], szTotalRaces[12], szRacePoints[12]
	
	if (SQL_MoreResults(Query))
	{
		for (new i = 0; i < iRow; i++)
		{
			SQL_ReadResult(Query, 0, szNames[i], 63)
			szWins[i] = SQL_ReadResult(Query, 1)
			szLosses[i] = SQL_ReadResult(Query, 2)
			szRacePoints[i] = SQL_ReadResult(Query, 3)
			szTotalRaces[i] = SQL_ReadResult(Query, 4)
			
			SQL_NextRow(Query)
		}
	}
	if (iRow > 0)
	{
		new iLen=0
		iLen = format(g_sBuffer[iLen], 4095, Style)
		iLen += format(g_sBuffer[iLen], 4095 - iLen, "<body><table width=100%% border=0 align=center cellpadding=0 cellspacing=1>")
		iLen += format(g_sBuffer[iLen], 4095 - iLen, "<tr><th>%s<th>%s<th>%s<th>%s<th>%s<th>%s</tr>","#", "Name", "Wins", "Losses", "RP", "Total Races")
		
		
		for (new i = 0; i < iRow; i++)
		{
			replace_all(szNames[i], 63, "&", "&amp;")
			replace_all(szNames[i], 63, "<", "&lt;")
			replace_all(szNames[i], 63, ">", "&gt;")
			
			iLen += format(g_sBuffer[iLen], 4095 - iLen, "<tr><td>%i<td><b>%s</b><td>%i<td>%i<td>%i<td>%i", i + 1, szNames[i], szWins[i], szLosses[i], szRacePoints[i], szTotalRaces[i])
		}
		show_motd(id, g_sBuffer, "Top 10 Racers")
	}	
	
	return PLUGIN_HANDLED
}

public Command_Rank(id)
{
	new Data[1]
	Data[0] = id
	
	if (is_user_connected(id))
	{
		new szTemp[512]
		format(szTemp,charsmax(szTemp),"SELECT COUNT(*) FROM `%s` WHERE `wins` >= %d", TABLE, g_iWins[id])
		SQL_ThreadQuery(g_SqlTuple,"Rank", szTemp, Data, 1)
	}
	return PLUGIN_CONTINUE
}

public Rank(FailState,Handle:Query,Error[],Errcode,Data[],DataSize)
{
	if(FailState == TQUERY_CONNECT_FAILED)
		log_amx("Load - Could not connect to SQL database.  [%d] %s", Errcode, Error)
	else if(FailState == TQUERY_QUERY_FAILED)
		log_amx("Load Query failed. [%d] %s", Errcode, Error)
	
	new iCount = 0
	iCount = SQL_ReadResult(Query,0)
	
	if (iCount == 0)
	{
		iCount = 1
	}
	
	new id
	id = Data[0]
	PCC(id, "Your rank is !t%i !ywith !g%i Wins!y, !g%i Losses!y and !g%i Race Points !y(!tRP!y)!y from !g%i Races!y.", iCount, g_iWins[id], g_iLosses[id], g_iRacePoints[id], g_iTotalRaces[id])
	
	return PLUGIN_HANDLED
}

public client_infochanged(id)
{
	if (!is_user_connected(id))
		return PLUGIN_HANDLED
	
	new szNewName[32], szOldName[32]
	get_user_name(id, szOldName, charsmax(szOldName))
	get_user_info(id, "name", szNewName, charsmax(szNewName))
	
	if (!equal(szNewName, szOldName))
	{
		Save_Data(id)
		
		g_iWins[id] = 0
		g_iLosses[id] = 0
		g_iTotalRaces[id] = 0
		g_bDownload_Data[id] = false
		set_task(0.1, "Load_Data", id)
		
		return PLUGIN_HANDLED
	}
	
	return PLUGIN_HANDLED
}

#endif