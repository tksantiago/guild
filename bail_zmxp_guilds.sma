#include < amxmodx >
#include < amxmisc >
#include < cstrike >
#include < hamsandwich >
#include < fakemeta >
#include < zombieplague_zmxp >

#include < bail_sqlx >
#include < bail_registro >
#include < bail_zombiexp >
#include < bail_global >
#include < bail_colorchat >

#define PLUGIN "[ZMXP] Guilds Manager"
#define VERSION "5.0"

#define GUILD_LIMIT 10

new const MESSAGE_TAG_GUILD[] = "[GUILD]"

new bool:xPlayerGuildMember[ MAX_PLAYERS+1 ]
new xGuildID[ MAX_PLAYERS+1 ]
new bool:xGuildLider[ MAX_PLAYERS+1 ];
new xGuildName[ MAX_PLAYERS+1 ][ 33 ];
new xGuildTag[ MAX_PLAYERS+1 ][ 33 ];
new xGuildMembers[ MAX_PLAYERS+1 ];
new xGuildPoints[ MAX_PLAYERS+1 ];
new xGuildaRank[ MAX_PLAYERS+1 ];
new bool:xPlayerConnected[33]
new bool:g_GuildaVoice[33] = false

new g_GuildaBankSaque[33]


new xTryingToInvite[33]
new xPlayerInviter[33]

new g_BancoSaqueLider[33]
new g_BancoSaqueLiderQuantia[33]

new totalrank, xMaxPlayers, g_msgid_SayText

new g_typed[192], g_message[192], g_name[32], g_team

// Guilda Menu
const KEYSMENU = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9|MENU_KEY_0
const KEYSINVITE = (1<<0)|(1<<1)

// MYSQL
new CvarMysqlPersistent
new Handle:gDbTuple
new Handle:gDbConnect
new bool:gPersistentTemp
static error[128]

new CvarCostGuild

/** INVENTARIO DA GUILD **/
new xGuildMaxSlots[ MAX_PLAYERS+1 ];
new xGuildItem[ MAX_PLAYERS+1 ][ 1024 ];
new xGuildItens[ MAX_PLAYERS+1 ]

public plugin_init(){
	RegisterPlugin( PLUGIN, VERSION, AUTHOR );
	
	CvarCostGuild = register_cvar("bail_guild_cost", "500");
	CvarMysqlPersistent = register_cvar("bail_guild_mysql_persistent", "0");
		
	// Guild Message
	register_clcmd("say", "HookSay")
	register_clcmd("say_team", "HookSayTeam")	
	
	register_clcmd("NomeGuild", "ChangeGuildNome");
	register_clcmd("TagGuild", "ChangeGuildTag");
	
	RegisterSay("guild", "CheckGuildMenu");
	RegisterSay("guilds", "ShowMenuGuildsOnline");
	RegisterSay("cm", "count_members");
	
	// Fechar Guild
	register_clcmd("fechar_guild", "Fechar_Guild")
	
	// Guild Voice
	register_forward( FM_Voice_SetClientListening, "voice_listening");
	
	register_clcmd("+guildvoice", "VoiceOn")
	register_clcmd("-guildvoice", "VoiceOff")	
	
	// Registrando o menu da guilda
	register_menu("Guilda Menu", KEYSMENU, "GuildaHandle")
	register_menu("Opcoes Menu", KEYSMENU, "OpcoesHandle")
	register_menu("Banco Menu", KEYSMENU, "BancoHandle")
	register_menu("Admin Menu", KEYSMENU, "AdminHandle")
	register_menu("Excluir Menu", KEYSMENU, "ExcluirHandle")
	register_menu("Criar Menu", KEYSMENU, "CriarHandle")
	register_menu("Convidar",KEYSINVITE,"ConvidarHandle")
	register_menu("Saque",KEYSINVITE,"SaqueHandle")
	
	xMaxPlayers = get_maxplayers()
	g_msgid_SayText = get_user_msgid("SayText")
	
	gDbTuple = StartConnect();
}

public count_members( id ){
	client_print( id, print_chat, "Sua Guild tem: %d Membros", xGuildMembers[ id ]);
}

public plugin_natives(){	
	register_native("UserHasGuild", "NativeUserHasGuild", true );
	register_native("SerMemberPoints", "NativeSetMemberPoints");
	register_native("GetGuildName", "NativeGetGuildName");
	register_native("GetGuildID", "NativeGetGuildID", true );
	
	register_native("GetGuildSlots", "NativeGetGuildSlots", true );
	register_native("GetGuildItem", "NativeGetGuildItem", true );
	register_native("SetGuildItem", "NativeSetGuildItem", true );
	register_native("GetGuildItens", "NativeGetGuildItens", true );
	register_native("ReloadGuildItens", "NativeGuildLoadInventario", true );
	
	register_native("ShowMenuGuild", "NativeShowMenuGuild", true );
}

public NativeShowMenuGuild( id )
	CheckGuildMenu( id );

public NativeGetGuildID( id ){
	return xGuildID[ id ];
}

public NativeGetGuildSlots( id ){
	return xGuildMaxSlots[ id ];
}

public NativeGetGuildItens( id ){
	if(!id)
		return PLUGIN_HANDLED;
	
	if(!is_user_connected( id ) )
		return PLUGIN_HANDLED
	
	return xGuildItens[ id ]
}

/** PEGAMO O ITEM DA GUILD **
public NativeGetGuildItem( id, item_index ){
	
	if( !id )
		return PLUGIN_HANDLED
	
	if( !is_user_connected( id ))
		return PLUGIN_HANDLED;
	
	new bool:has = false;
	
	for( new i = 0; i < xGuildMaxSlots[ id ]; i++){
		if( xGuildItem[ id ][ i ] == item_index )
			has = true
	}
	
	return has
}
**/

public NativeGetGuildItem( id, item_index )
	return xGuildItem[ id ][ item_index ];

/*
public NativeCheckGuildHasItem( id, rid_item ){
	if( !is_user_connected( id ))
		return PLUGIN_HANDLED;
	
	new bool:has = false
	
	for( new i = 0; i < xCountItens[ id ][ TEMPORARIO_PERMANENTE ]; i++){
		if( xGuildItem[ id ][ i ] == rid_item )
			has = true
	}
	
	return has
}
*/

/** SET INVENTARIO GUILD **/
public NativeSetGuildItem( id, item_id ){	
	if(!is_user_connected( id ))
		return PLUGIN_HANDLED
	
	static auth[ 64 ];
	GetUserKey( id, auth, charsmax( auth ));
	
	new szQuery[ 512 ];
	formatex(szQuery, 511, "UPDATE bail_inventario SET ID_GUILD = '%d' WHERE ID = '%d' AND MEMBRO_KEY = '%s'", xGuildID[ id ], item_id, auth )
	SQL_ThreadQuery(gDbTuple, "QuerySetData", szQuery) 
	
	NativeGuildLoadInventario( id );
	
	return true
}

public NativeGuildLoadInventario( id ){	
	new iData[ 1 ];
	iData[ 0 ] = id;	
	
	/** VAMOS CARREGAR O INVENTARIO DA GUILD **/
	static sql[ 212 ];
	formatex( sql, charsmax( sql ), "SELECT RID_ITEM, ID_GUILD FROM bail_inventario WHERE ID_GUILD = '%d'", xGuildID[ id ]);	
	SQL_ThreadQuery( gDbTuple, "GuildQueryReload", sql, iData, 2 );	
}

public GuildQueryReload( failstate, Handle: iQuery, error[], errnum, data[], datalen, Float:queuetime ){
	new id = data[0]
	
	if( failstate ){
		SetLog( LOG_GUILD, "(GuildQueryLoad4) Error Querying MySQL - %d: %s", errnum, error )	
		return PLUGIN_HANDLED;
	}
	
	for( new i = 0; i < xGuildMaxSlots[ id ]; i++ )
		xGuildItem[ id ][ i ] = 0;
	
	xGuildItens[ id ] = 0;
	
	while( SQL_MoreResults( iQuery )){
		new iGuildID;
		iGuildID = SQL_ReadResult( iQuery, SQL_FieldNameToNum( iQuery, "ID_GUILD" ));
		
		if( xGuildItens[ id ] < xGuildMaxSlots[ id ] && iGuildID > 0 ){
			xGuildItem[ id ][ xGuildItens[ id ] ] = SQL_ReadResult( iQuery, SQL_FieldNameToNum( iQuery, "RID_ITEM" ));
			xGuildItens[ id ]++
		}
		
		SQL_NextRow( iQuery );
	}
	
	for( new x = 1; x <= xMaxPlayers; x++ ){
		xGuildItens[ x ] = xGuildItens[ id ];
		
		if( xPlayerConnected[ x ] && xPlayerGuildMember[ x ] && xGuildID[ x ] == xGuildID[ id ]){
			for( new i = 0; i <= xGuildItens[ id ]; i++ )
				xGuildItem[ x ][ i ] = xGuildItem[ id ][ i ];
		}
	}	
	
	return PLUGIN_HANDLED;
}

public NativeUserHasGuild( index )
	return xPlayerGuildMember[ index ];

public NativeGetGuildName( plugin_id, param_nums ){
	if( param_nums != 3 )
		return -1;
    
	static id; id = get_param(1);
    
	if( !xPlayerConnected[ id ] || !xPlayerGuildMember[ id ])
		return 0;
    
	set_string( 2, xGuildName[ id ], get_param( 3 ))
	
	return 1
}

public NativeSetMemberPoints( id, params ){
	new id = get_param(1);
	new newpontos = get_param(2);
	new newbankpontos = get_param(3);
	
	if( !xPlayerConnected[ id ] || !xPlayerGuildMember[ id ])
		return true;
	
	if( newpontos <= 0 )
		return true;
	
	static auth[ 64 ];
	GetUserKey( id, auth, charsmax( auth ));
	
	static sql[ 212 ];
	formatex( sql, charsmax( sql ), "UPDATE bail_registro SET PONTOS = PONTOS + '%i' WHERE MEMBRO_KEY = '%s'", newpontos, auth );
	SQL_ThreadQuery( gDbTuple, "QuerySetData", sql)	
	
	if( newbankpontos <= 0 )
		return true;	
	
	formatex( sql, charsmax( sql ), "UPDATE bail_guilds SET ZMXP_AMMOPACKS = ZMXP_AMMOPACKS + '%i' WHERE ID = '%i'", newbankpontos, xGuildID[ id ]);
	SQL_ThreadQuery( gDbTuple, "QuerySetData", sql )
	
	return true;
}

public QuerySetData( failstate, Handle:query, error[], errnum, data[], datalen, Float:queuetime ){
	if( failstate == TQUERY_CONNECT_FAILED || failstate == TQUERY_QUERY_FAILED )
		SetLog( LOG_GUILD, "(QuerySetData) Error Querying MySQL - %d: %s", errnum, error )
	
	return PLUGIN_HANDLED;
}

public RegisterAuthenticated( id )
	CarregarGuild( id );

public CarregarGuild( id ){
	new iData[ 1 ];
	iData[ 0 ] = id;
		
	static iAuth[ 64 ];
	GetUserKey( id, iAuth, charsmax( iAuth ));
	
	static sql[ 212 ];
	formatex( sql, charsmax( sql ), "SELECT ID_GUILD, LIDER_GUILD FROM bail_registro WHERE MEMBRO_KEY = '%s'", iAuth );
	SQL_ThreadQuery( gDbTuple, "GuildQueryLoad1", sql, iData, 2 );
	
	return PLUGIN_HANDLED;
}

public GuildQueryLoad1( failstate, Handle:query, error[], errnum, data[], datalen, Float:queuetime ){
	new id = data[0];
	
	if( failstate ){
		SetLog( LOG_GUILD, "(GuildQueryLoad1) Error Querying MySQL - %d: %s", errnum, error )
		
		xPlayerGuildMember[ id ] = false;
		xGuildLider[ id ] = false;
		
		xGuildID[ id ] = 0;
		xGuildMembers[ id ] = 0;
		xGuildPoints[ id ] = 0;
		xGuildaRank[ id ] = 0;
		xTryingToInvite[ id ] = 0;
		xPlayerInviter[ id ] = 0;
		
		return PLUGIN_HANDLED;
	}
		
	if( !SQL_NumResults( query )){
		xPlayerGuildMember[ id ] = false;
		xGuildLider[ id ] = false;
		
		xGuildID[ id ] = 0;
		xGuildMembers[ id ] = 0;
		xGuildPoints[ id ] = 0;
		xGuildaRank[ id ] = 0;
		xTryingToInvite[ id ] = 0;
		xPlayerInviter[ id ] = 0;
		
		return PLUGIN_HANDLED;
	}
	
	static sGuildID[ 63 ], sGuildLider[ 63 ];
	SQL_ReadResult( query, SQL_FieldNameToNum( query, "ID_GUILD"), sGuildID, charsmax( sGuildID ));
	SQL_ReadResult( query, SQL_FieldNameToNum( query, "LIDER_GUILD"), sGuildLider, charsmax( sGuildLider ));
	
	xGuildID[ id ] = str_to_num( sGuildID );
	
	if( str_to_num( sGuildLider ) == 1 )
		xGuildLider[ id ] = true;
	
	else
		xGuildLider[ id ] = false;
		
	if( xGuildID[ id ] > 0 ){
		static sql[ 212 ];
		formatex( sql, charsmax( sql ), "SELECT GUILD_NAME, GUILD_TAG, SLOTS_INVENTARIO, PONTOS FROM bail_guilds WHERE ID = '%i'", xGuildID[ id ])	
		SQL_ThreadQuery( gDbTuple, "GuildQueryLoad2", sql, data, 2 );
	}
	
	return PLUGIN_HANDLED;
}

public GuildQueryLoad2( failstate, Handle:query, error[], errnum, data[], datalen, Float:queuetime ){
	new id = data[0]
	
	if( failstate ){
		SetLog( LOG_GUILD, "(GuildQueryLoad2) Error Querying MySQL - %d: %s", errnum, error )	
		return PLUGIN_HANDLED;
	}
	
	static sSlots[ 64 ], sPontos[ 64 ];
	SQL_ReadResult( query, SQL_FieldNameToNum( query, "GUILD_NAME"), xGuildName[ id ], charsmax( xGuildName ));
	SQL_ReadResult( query, SQL_FieldNameToNum( query, "GUILD_TAG"), xGuildTag[ id ], charsmax( xGuildTag ));
	SQL_ReadResult( query, SQL_FieldNameToNum( query, "SLOTS_INVENTARIO"), sSlots, charsmax( sSlots ));
	SQL_ReadResult( query, SQL_FieldNameToNum( query, "PONTOS"), sPontos, charsmax( sPontos ));
	
	xGuildMaxSlots[ id ] = str_to_num( sSlots );
	xGuildPoints[ id ] = str_to_num( sPontos );
	xPlayerGuildMember[ id ] = true;
	
	static sName[ 32 ];
	get_user_name( id, sName, charsmax( sName ));
	ColorChat( id, GREEN, "^x01 Ola^x03 %s^x01 sua guild^x03 %s^x01 foi carregada com sucesso!", sName, xGuildName[ id ]);
	
	/** CARREGAMOS A QUANTIDADE DE MEMBROS DA GUILD **/
	static sql[ 212 ];
	formatex( sql, charsmax( sql ), "SELECT MEMBRO_KEY FROM bail_registro WHERE ID_GUILD = '%i'", xGuildID[ id ]);	
	SQL_ThreadQuery( gDbTuple, "GuildQueryLoad3", sql, data, 2 );
	
	return PLUGIN_HANDLED;
}

public GuildQueryLoad3( failstate, Handle:query, error[], errnum, data[], datalen, Float:queuetime ){
	new id = data[0]
	
	if( failstate ){
		SetLog( LOG_GUILD, "(GuildQueryLoad3) Error Querying MySQL - %d: %s", errnum, error )	
		return PLUGIN_HANDLED;
	}
	
	xGuildMembers[ id ] = SQL_NumResults( query );
	
	/** VAMOS CARREGAR O INVENTARIO DA GUILD **/
	static sql[ 212 ];
	formatex( sql, charsmax( sql ), "SELECT RID_ITEM, ID_GUILD FROM bail_inventario WHERE ID_GUILD = '%d'", xGuildID[ id ]);	
	SQL_ThreadQuery( gDbTuple, "GuildQueryLoad4", sql, data, 2 );
	
	return PLUGIN_HANDLED;
}

public GuildQueryLoad4( failstate, Handle: iQuery, error[], errnum, data[], datalen, Float:queuetime ){
	new id = data[0]
	
	if( failstate ){
		SetLog( LOG_GUILD, "(GuildQueryLoad4) Error Querying MySQL - %d: %s", errnum, error )	
		return PLUGIN_HANDLED;
	}
	
	
	xGuildItens[ id ] = 0;
	
	while( SQL_MoreResults( iQuery )){
		new iGuildID;
		iGuildID = SQL_ReadResult( iQuery, SQL_FieldNameToNum( iQuery, "ID_GUILD" ));
		
		if( xGuildItens[ id ] < xGuildMaxSlots[ id ] && iGuildID > 0 ){
			xGuildItem[ id ][ xGuildItens[ id ] ] = SQL_ReadResult( iQuery, SQL_FieldNameToNum( iQuery, "RID_ITEM" ));
			xGuildItens[ id ]++
		}
		
		SQL_NextRow( iQuery );
	}
	
	return PLUGIN_HANDLED;
}

public Kitar_Guild( tempid ){
	if( !xPlayerGuildMember[ tempid ]){
		console_print( tempid, "[GUILD] Voce nao faz parte de nenhuma guild!");
		return PLUGIN_HANDLED;
	}
	
	if( xGuildLider[ tempid ]){
		console_print( tempid, "[GUILD] Voce eh o lider de uma guild, nao pode sair assim!");
		return PLUGIN_HANDLED;
	}
	
	if( !AccessReleased( tempid )){
		PrintGuild( tempid, "^1 Voce nao tem autorizacao para fazer isso.")
		return PLUGIN_HANDLED;
	}
	
	console_print( tempid, "[GUILD] Removendo voce da Guild %s. Aguarde...", xGuildName[ tempid ])
	
	mySQLConnect();
	
	if( gDbConnect == Empty_Handle )
		return false;
	
	static sql[180]
	new Handle:query, errcode
	
	static sName[ 32 ];
	get_user_name( tempid, sName, charsmax( sName ));
	
	static sAuth[ 64 ];
	GetUserKey( tempid, sAuth, charsmax( sAuth ));

	formatex( sql, charsmax( sql ), "UPDATE bail_registro SET ID_GUILD = '0' WHERE MEMBRO_KEY = '%s'", sAuth );
	query = SQL_PrepareQuery( gDbConnect, "%s", sql );
	
	if( !SQL_Execute( query )){
		errcode = SQL_QueryError( query, error, charsmax( error ))
		
		SetLog( LOG_GUILD, "Erro ao remover membro %s: da Guild %s [%d] '%s' - '%s'", sName, xGuildName[ tempid ], errcode, error, sql );
		console_print( tempid, "[GUILD] Houve um erro no banco de dados... nao foi possivel remover voce da guild.");
		
		SQL_FreeHandle( query );
		
		return PLUGIN_HANDLED;
	}
	
	SQL_FreeHandle( query );
	close_mysql();
	
	for( new x = 1; x <= xMaxPlayers; x++ ){
		if( xPlayerConnected[ x ] && xPlayerGuildMember[ x ] && xGuildID[ x ] == xGuildID[ tempid ])
			xGuildMembers[ x ]--;
	}
	
	xPlayerGuildMember[ tempid ] = false;
	xGuildID[ tempid ] = 0;
	xGuildLider[ tempid ] = false;
 	xGuildMembers[ tempid ] = 0;
 	xGuildPoints[ tempid ] = 0;
 	xGuildaRank[ tempid ] = 0;
	xTryingToInvite[ tempid ] = 0;
	xPlayerInviter[ tempid ] = 0;
	
	ColorChat( 0, RED, "^x01 O Player^x03 %s^x01 saiu da Guild^x03 %s", sName, xGuildName[ tempid ]);
	
	return PLUGIN_HANDLED;
}

public Fechar_Guild( id ){
	if( !xPlayerGuildMember[ id ]){
		ColorChat( id, GREEN, "^x03 Voce nao faz parte de nenhuma guild!")
		return PLUGIN_HANDLED;
	}
	
	if( !xGuildLider[ id ]){
		ColorChat( id, GREEN, "^x03 Voce nao e o lider desta guild!")
		return PLUGIN_HANDLED;
	}
	
	if( !AccessReleased( id )){
		ColorChat( id, GREEN, "^x03 Voce nao tem autorizacao para fazer isso.")
		return PLUGIN_HANDLED;
	}
	
	ColorChat( id, GREEN, "^x03 Fechando a Guild %s. Aguarde...", xGuildName[ id ])
	
	mySQLConnect();
	
	if( gDbConnect == Empty_Handle )
		return false;
	
	static sql[180];
	new Handle:query
	new errcode
	
	static sAuth[ 64 ];
	GetUserKey( id, sAuth, charsmax( sAuth ));
	
	static sName[ 32 ];
	get_user_name( id, sName, charsmax( sName ));	

	/** REMOVENDO TODOS OS MEMBROS DA GUILD **/
	formatex( sql, charsmax( sql ), "UPDATE bail_registro SET ID_GUILD = '0', LIDER_GUILD = '0', PONTOS_GUILD = '0' WHERE ID_GUILD = '%d'", xGuildID[ id ]);
	query = SQL_PrepareQuery( gDbConnect, "%s", sql );
	
	if( !SQL_Execute( query )){
		errcode = SQL_QueryError( query, error, charsmax( error ))
		SetLog( LOG_GUILD, "Erro ao fechar a guild. KEY_LIDER: %s. Guild: %s [%d] '%s' - '%s'", sAuth, xGuildName[id], errcode, error, sql)
		
		console_print( id, "[GUILD] Houve um erro no banco de dados... nao foi possivel fechar a guild.")
		
		SQL_FreeHandle( query );
		return PLUGIN_HANDLED;
	}
	
	SQL_FreeHandle( query );
	
	/** EXCLUINDO A GUILD DO BANCO DE DADOS **/
	formatex( sql, charsmax( sql ), "DELETE FROM bail_guilds WHERE ID = '%d'", xGuildID[ id ])
	query = SQL_PrepareQuery( gDbConnect, "%s", sql );
	
	if( !SQL_Execute( query )){
		errcode = SQL_QueryError( query, error, charsmax( error ))
		
		SetLog( LOG_GUILD, "(2) Erro ao fechar a guild. KEY_LIDER: %s. Guild: %s [%d] '%s' - '%s'", sAuth, xGuildName[ id ], errcode, error, sql );
		console_print( id, "[GUILD] Houve um erro no banco de dados... nao foi possivel fechar a guild corretamente.")
		
		SQL_FreeHandle( query );
		return PLUGIN_HANDLED;
	}
		
	SQL_FreeHandle( query );
	close_mysql();
	
	// LIMPAMOS AS VARIAVEIS DOS MEMBROS ONLINE
	for( new x = 1; x <= xMaxPlayers; x++ ){
		if( xPlayerConnected[ x ] && xPlayerGuildMember[ x ] && xGuildID[ x ] == xGuildID[ id ] && !xGuildLider[ x ]){
			xPlayerGuildMember[ x ] = false;
			xGuildID[ x ] = 0;
			xGuildLider[ x ] = false;
			xGuildMembers[ x ] = 0;
			xGuildPoints[ x ] = 0;
			xGuildaRank[ x ] = 0;
			xTryingToInvite[ x ] = 0;
			xPlayerInviter[ x ] = 0;
		}
	}
	
	xPlayerGuildMember[ id ] = false;
	xGuildID[ id ] = 0;
	xGuildLider[ id ] = false;
	xGuildMembers[ id ] = 0;
	xGuildPoints[ id ] = 0;
	xGuildaRank[ id ] = 0;
	xTryingToInvite[ id ] = 0;
	xPlayerInviter[ id ] = 0;
	
	ColorChat( 0, GREEN, "^x01 O Lider^x03 %s^x01 fechou a Guild^x03 %s", sName, xGuildName[ id ])

	return PLUGIN_HANDLED;
}

public LiderTransferMenu( id ){
	static title[128];
	formatex(title, sizeof(title) - 1, "\y[ %s ]  \wTransferir Lider:^n", xGuildName[id])
	new menu_ = menu_create(title, "acao2_menu")
	new name[33], k[4]
	
	for(new i = 1 ; i <= xMaxPlayers ; i++)
	{
		if(!xPlayerConnected[i] || id == i || !xPlayerGuildMember[i] || xGuildID[i] != xGuildID[id])
		continue
		
		get_user_name(i, name, 32)
		num_to_str(i, k, 3)
		menu_additem(menu_, name, k)
	}
	
	menu_setprop(menu_, MPROP_EXITNAME, "\rSair")
	menu_display(id, menu_)
}

public acao2_menu( id, menu, item ){
	if( item == MENU_EXIT ){
		 menu_destroy(menu)
		 return PLUGIN_HANDLED;
	}
	
	if( !AccessReleased( id )){
		PrintGuild(id, "^1 Voce nao tem autorizacao para fazer isso.")
		return PLUGIN_HANDLED;
	}
	
	if( !xGuildLider[ id ]){
		PrintGuild(id, "^1 Voce nao eh o dono dessa guild!")
		return PLUGIN_HANDLED;
	}	
	
	new data[6], iName[64]
	new access, callback
	
	menu_item_getinfo(menu, item, access, data,5, iName, 63, callback)
	new tempid = str_to_num(data)
	
	if( !xPlayerConnected[ tempid ])
		return PLUGIN_HANDLED;
	
	if( xGuildLider[ tempid ]){
		PrintGuild( id, "^1 Erro na acao!")
		return PLUGIN_HANDLED;
	}
	
	if( xGuildID[ tempid ] != xGuildID[ id ]){
		PrintGuild(id, "^1 Erro na acao!")
		return PLUGIN_HANDLED;
	}
			
	static sTempAuth[ 64 ];
	GetUserKey( tempid, sTempAuth, charsmax( sTempAuth ));
	
	static sTempName[ 32 ];
	get_user_name( tempid, sTempName, charsmax( sTempName ));
	
	mySQLConnect();
	
	if( gDbConnect == Empty_Handle )
		return PLUGIN_HANDLED;
	
	static sql[180]
	new Handle:query, errcode	
	
	formatex( sql, charsmax( sql ), "UPDATE bail_guilds SET KEY_LIDER = '%s' WHERE ID = '%d'", sTempAuth, xGuildID[ id ]);
	query = SQL_PrepareQuery( gDbConnect, "%s", sql );
	
	if( !SQL_Execute( query )){
		errcode = SQL_QueryError( query, error, charsmax( error ));
		SetLog( LOG_GUILD, "Erro ao transferir lider de Guild (1) [%d] '%s' - '%s'", errcode, error, sql );
		PrintGuild(id, "^1 Houve um erro no banco de dados...");
		
		SQL_FreeHandle( query );
		return PLUGIN_HANDLED;
	}
	
	SQL_FreeHandle( query );	
	
	close_mysql();
	
	xGuildLider[ id ] = false;
	xGuildLider[ tempid ] = true;
	
	PrintGuild( 0, "^1 A Guild^3 %s^1 foi transferida com sucesso para o Lider^3 %s", xGuildName[ id ], sTempName );
	return PLUGIN_HANDLED;
}

public ShowMenuGuildsOnline( id ){
	if(!AccessReleased(id))
	{
		PrintGuild(id, "^1 Voce nao tem autorizacao para fazer isso.")
		return PLUGIN_HANDLED;
	}
	
	// criando nossa lista
	new OnlineGuilds[33][3], n = 0, flag = 0

	for(new i = 1; i <= xMaxPlayers; i++) 
	{
		if(xPlayerConnected[i] && xPlayerGuildMember[i])
		{
			flag = 0
			
			for(new x = 1; x < 33; x++) 
			{
				if(OnlineGuilds[x][0] == xGuildID[i]) // Ja ta no sistema
				{
					OnlineGuilds[x][2]++ // aumentando a quantidade de membros online!
					flag = 1
					break;
				}
			}
			
			if(flag == 0) // n�o ta no sistema ainda
			{
				OnlineGuilds[n][0] = xGuildID[i] // colocando a guild no topo da lista
				OnlineGuilds[n][1] = i // so pra pegar um id de refer�ncia, assim nao preciso criar uma string
				OnlineGuilds[n][2]++ // aumentando a quantidade de membros online!
				n++ // atualiza o topo
			}
		}
	}
	// lista criada!
	
	new iTemp[ 128 ];
	formatex( iTemp, charsmax( iTemp ), "\d%s - Guilds Online:", xPrefix );
	new menu = menu_create( iTemp, "ation_menu")
	static szTempid[10], message[50]
	
	for(new j = 0; j < n; j++)
	{
		num_to_str(OnlineGuilds[j][1], szTempid, 9);
		formatex(message, charsmax(message), "\w%s \y(%d online)", xGuildName[OnlineGuilds[j][1]], OnlineGuilds[j][2])
		menu_additem(menu, message, szTempid, 0)
	}
	
	menu_setprop(menu, MPROP_EXITNAME, "Sair")
	menu_display(id, menu, 0)	
	
	return PLUGIN_CONTINUE;
}

public ation_menu(id, menu, item)
{
	if( item == MENU_EXIT )
	{
		 menu_destroy(menu)
		 return
	}
	
	static data[6], iName[64]
	new access, callback
	menu_item_getinfo(menu, item, access, data,5, iName, 63, callback)
	new tempid = str_to_num(data)
	
	if(xPlayerConnected[tempid] && xPlayerGuildMember[tempid])
	{
		MostrarMotdMembros(tempid, id)
	}
}

public CheckGuildMenu( id ){
	if( !AccessReleased( id )){
		ColorChat( id, GREEN, "^x01 Voce nao tem autorizacao para fazer isso!")
		return PLUGIN_HANDLED;
	}
	
	if( !xPlayerGuildMember[ id ]){
		CreateGuildMenu( id );
		ColorChat( id, GREEN, "^x01 Voce nao faz parte de nenhuma guilda!")
		return PLUGIN_HANDLED;
	}
	
	MainGuildMenu( id );
	return PLUGIN_CONTINUE;
}

public CreateGuildMenu( id ){
	static menu[512], len
	len = 0
	
	len += formatex(menu[len], charsmax(menu) - len, "\d[ %s ] Sistema de Guild:^n\r %s^n^n", xPrefix, xWebSite );
	
	len += formatex(menu[len], charsmax(menu) - len, "\d1.\r Criar uma Guild^n");
	len += formatex(menu[len], charsmax(menu) - len, "\d(Crie uma guild por %d AP)^n^n", get_pcvar_num( CvarCostGuild ));
	
	len += formatex(menu[len], charsmax(menu) - len, "\d2.\r Lista de Guilds^n");
	len += formatex(menu[len], charsmax(menu) - len, "\d(Lista de todas as guilds)^n^n");
	
	len += formatex(menu[len], charsmax(menu) - len, "\d3.\r Top Guilds^n");
	len += formatex(menu[len], charsmax(menu) - len, "\d(Ranking das guilds)^n^n");
	
	len += formatex(menu[len], charsmax(menu) - len, "\d4.\r Vantagens^n");
	len += formatex(menu[len], charsmax(menu) - len, "\d(Veja as vantagens de ter uma guild)^n^n");
	
	len += formatex(menu[len], charsmax(menu) - len, "^n\r0.\r Sair");
	
	show_menu( id, KEYSMENU, menu, -1, "Criar Menu");
}

public CriarHandle( id, key ){
	if( xPlayerGuildMember[ id ])
		return PLUGIN_HANDLED;
	
	switch( key ){
		case 0: {			
			if( zp_get_user_ammo_packs( id ) < get_pcvar_num( CvarCostGuild )){
				ColorChat( id, RED, "^1 Voce nao tem %d AmmoPacks para criar sua guilg!", get_pcvar_num( CvarCostGuild ))
				return PLUGIN_HANDLED;
			}
			
			static sAuth[ 64 ];
			GetUserKey( id, sAuth, charsmax( sAuth ));
		
			static sName[ 64 ];
			get_user_name( id, sName, charsmax( sName ))
			replace_all( sName, charsmax( sName ), "'", "\'")
			
			mySQLConnect();
			
			if( gDbConnect == Empty_Handle )
				return false;
	
			static sql[ 440 ];
			new Handle:query, errcode
	
			formatex( sql, charsmax( sql ), "INSERT INTO bail_guilds ( GUILD_NAME, GUILD_TAG, KEY_LIDER, PONTOS, ZMXP_AMMOPACKS ) VALUES ('Nova Guild', '[NovaGuild]', '%s', '0', '0')", sAuth );
			query = SQL_PrepareQuery( gDbConnect, "%s", sql );
										
			if( SQL_Execute( query )){
				xGuildID[ id ] = SQL_GetInsertId( query );

				SQL_FreeHandle( query );
								
				formatex( sql, charsmax( sql ), "UPDATE bail_registro SET ID_GUILD = '%d', LIDER_GUILD = '1' WHERE MEMBRO_KEY = '%s'", xGuildID[ id ], sAuth );
				query = SQL_PrepareQuery( gDbConnect, "%s", sql );
				
				if( SQL_Execute( query )){
					zp_set_user_ammo_packs( id, zp_get_user_ammo_packs( id ) - get_pcvar_num( CvarCostGuild ));
					
					zmxp_save_user( id );
					
					xGuildMembers[ id ] = 1;
					xGuildPoints[ id ] = 0;
					xGuildaRank[ id ] = 0;
					
					xPlayerGuildMember[ id ] = true;
					xGuildLider[ id ] = true;
					
					copy( xGuildName[ id ], charsmax( xGuildName[]), "Nova Guild");
					copy( xGuildTag[ id ], charsmax( xGuildTag[]), "[NovaGuild]");				
					
					ColorChat( id, RED, "^x01 Sua Guild foi criada com sucesso! Voce ja pode alterar o Nome e a TAG dela!");
					ColorChat( id, RED, "^x01 E PROIBIDO COLOCAR NOME / TAG OFENSIVA OU COM PUBLICIDADE!");
					ColorChat( 0, RED, "^x01 Jogador^x03 %s^x01 criou uma nova Guild!", sName );
					
					CheckGuildMenu( id );
				}
				
				else {
					errcode = SQL_QueryError(query, error, charsmax(error))
					SetLog( LOG_GUILD, "[GUILDs] (4) Erro ao criar a Guild para o: %s: [%d] '%s' - '%s'", sAuth, errcode, error, sql );
					ColorChat( id, RED, " Houve um erro no banco de dados e sua Guild nao foi criada!");
					
					SQL_FreeHandle( query );
					
					return PLUGIN_HANDLED;
				}
			}
			
			else {
				errcode = SQL_QueryError( query, error, charsmax( error ))
				SetLog( LOG_GUILD, "[GUILD] (3) Erro ao criar a Guild para o: %s: [%d] '%s' - '%s'", sAuth, errcode, error, sql )
				ColorChat( id, RED, " Houve um erro no banco de dados e sua Guild nao foi criada!");
				
				SQL_FreeHandle( query );
				
				return PLUGIN_HANDLED;
			}
			
			return PLUGIN_HANDLED;
		}
		
		case 1: ShowMenuGuildsOnline( id );
		
		case 2: {
			// ranking guilds
		}
		
		case 3:{
			show_motd(id, "vantagemguild.html")
		}		
	}
	
	return PLUGIN_HANDLED;
}

public MainGuildMenu( id ){	
	static sql[320];
	new data[1]
	
	data[0] = id
	
	formatex( sql, charsmax( sql ), "SELECT NICK, LIDER_GUILD FROM bail_registro WHERE ID_GUILD = '%i'", xGuildID[ id ]);
	SQL_ThreadQuery( gDbTuple, "GuildQueryMenu", sql, data, 2 );
	
	return PLUGIN_HANDLED;
}

public GuildQueryMenu( failstate, Handle:query, error[], errnum, data[], datalen, Float:queuetime ){
	if( failstate ){
		SetLog( LOG_GUILD, "(GuildQueryMenu) Error Querying MySQL - %d: %s", errnum, error)
		return PLUGIN_HANDLED
	}
	
	new id = data[0]
	static menu[1024], len
	len = 0
	
	// T�tulo
	len += formatex(menu[len], charsmax(menu) - len, "\d[ %s ] Sistema de Guild:^n", xPrefix );
	len += formatex(menu[len], charsmax(menu) - len, "\rGuild: %s | Pontos: %d/10^n^n", xGuildName[ id ], PegarLevelGuild( xGuildPoints[ id ]));
	len += formatex(menu[len], charsmax(menu) - len, "\dMembros:^n");
	
	if( SQL_NumResults( query )){
		static sNameResult[ 32 ], sName[ 26 ];
		static sHasLiderResult[ 2 ], sHasLider;
		static sMemberOnline
		
		while( SQL_MoreResults( query )){
			sMemberOnline = 0;
			
			SQL_ReadResult( query, SQL_FieldNameToNum( query, "NICK"), sNameResult, charsmax( sNameResult ));
			SQL_ReadResult( query, SQL_FieldNameToNum( query, "LIDER_GUILD"), sHasLiderResult, charsmax( sHasLiderResult ));
			
			sHasLider = str_to_num( sHasLiderResult );
			
			for( new x = 1; x <= xMaxPlayers; x++ ){
				if( xPlayerConnected[ x ] && xPlayerGuildMember[ x ] && xGuildID[ x ] == xGuildID[ id ]){	
					get_user_name( x, sName, charsmax( sName ))
					
					if( equal( sName, sNameResult )){
						sMemberOnline = 1;
						break
					}
				}
			}
			
			if( sHasLider == 1 )
				len += formatex(menu[len], charsmax(menu) - len, "\%s    » %s \y[LIDER] %s^n", sMemberOnline ? "r": "d", sNameResult, sMemberOnline ? "\d(ONLINE)" : "(OFFLINE)");

			else
				len += formatex(menu[len], charsmax(menu) - len, "\%s    » %s %s^n", sMemberOnline ? "r" : "d", sNameResult, sMemberOnline ? "\d(ONLINE)" : "(OFFLINE)");
			
			SQL_NextRow( query );
		}
	}
	
	len += formatex(menu[len], charsmax(menu) - len, "^n\d1.\r Menu da Guild^n");
	len += formatex(menu[len], charsmax(menu) - len, "\d(Veja as informacoes da sua guild)^n^n");
	
	if( xGuildLider[ id ]){
		len += formatex(menu[len], charsmax(menu) - len, "\d2.\r Administrar Guild^n");
		len += formatex(menu[len], charsmax(menu) - len, "\d(Expulsar/Convidar jogador, alterar nome e tag)^n^n");
	}
	
	len += formatex(menu[len], charsmax(menu) - len, "\d0.\r Sair")
	
	show_menu( id, KEYSMENU, menu, -1, "Guilda Menu")
	return PLUGIN_HANDLED;
}

public GuildaHandle( id, key ){
	if( !xPlayerGuildMember[ id ])
		return PLUGIN_HANDLED;
	
	switch( key ){
		case 0: OpcoesMenu( id );
		
		case 1: {
			if( xGuildLider[ id ])
				AdminMenu( id );
				
			else
				ColorChat( id, RED, "^1 Voce nao e o lider da %s!", xGuildName[ id ])
		}
	}
	
	return PLUGIN_HANDLED;
}

public OpcoesMenu( id ){	
	static menu[512], len
	len = 0
	
	// T�tulo
	len += formatex(menu[len], charsmax(menu) - len, "\d[ %s ] Menu da Guild:^n", xPrefix );
	len += formatex(menu[len], charsmax(menu) - len, "\rGuild: %s | Pontos: %d/10^n^n", xGuildName[ id ], PegarLevelGuild( xGuildPoints[ id ]));
	
	// Op��es
	len += formatex(menu[len], charsmax(menu) - len, "\d1.\r Rank da Guild^n");
	len += formatex(menu[len], charsmax(menu) - len, "\d(Veja a posicao da sua guild no ranking)^n^n");
	
	len += formatex(menu[len], charsmax(menu) - len, "\d2.\r Banco da Guild^n");
	len += formatex(menu[len], charsmax(menu) - len, "\d(Visualize/Solicite Ammopacks)^n^n");
	
	len += formatex(menu[len], charsmax(menu) - len, "\d3.\r Inventario da Guild %d/%d^n", xGuildItens[ id ], xGuildMaxSlots[ id ]);
	len += formatex(menu[len], charsmax(menu) - len, "\d(Veja os itens da guild)^n^n");
	
	len += formatex(menu[len], charsmax(menu) - len, "\d4.\r Stats dos Membros^n");
	len += formatex(menu[len], charsmax(menu) - len, "\d(Estatisticas dos Membros da Guild)^n^n");
	
	len += formatex(menu[len], charsmax(menu) - len, "\d5.\r Comandos e Ajuda^n");
	len += formatex(menu[len], charsmax(menu) - len, "\d(Comandos especiais e Ajuda)^n^n");
	
	if( !xGuildLider[ id ]){
		len += formatex(menu[len], charsmax(menu) - len, "\d5.\y Sair da Guild^n");
		len += formatex(menu[len], charsmax(menu) - len, "\d(Sair da Guild atual)^n^n");
	}
	
	len += formatex(menu[len], charsmax(menu) - len, "^n\d0.\r Sair")
	
	show_menu(id, KEYSMENU, menu, -1, "Opcoes Menu")
}

public OpcoesHandle( id, key ){
	if( !xPlayerGuildMember[ id ])
		return PLUGIN_HANDLED;
	
	switch( key ){
		case 0:{
			mySQLConnect()
			
			if( gDbConnect == Empty_Handle )
				return false;		
		
			static sql[180], Points[64]
			new Handle:query
			new errcode

			formatex( sql, charsmax( sql ), "SELECT PONTOS_GUILD FROM bail_registro WHERE ID_GUILD = '%i'", xGuildID[ id ])
			query = SQL_PrepareQuery( gDbConnect, "%s", sql)
		
			if( !SQL_Execute( query )){
				errcode = SQL_QueryError(query, error, charsmax(error))
				SetLog( LOG_GUILD, "Erro ao criar query do rank para Guilda ID: %i [%d] '%s' - '%s'", xGuildID[id], errcode, error, sql)
				
				SQL_FreeHandle(query)
				
				return PLUGIN_HANDLED;
			}
			
			xGuildPoints[id] = 0

			if( SQL_NumResults( query )){
				while( SQL_MoreResults( query )){
					Points[0] = '^0'
					SQL_ReadResult(query, 0, Points, charsmax(Points))
				
					xGuildPoints[id] += str_to_num(Points)

					SQL_NextRow(query)
				}
			}
		
			SQL_FreeHandle( query );
				
			formatex( sql, charsmax( sql ), "UPDATE bail_guilds SET PONTOS = '%i' WHERE ID = '%i'", xGuildPoints[ id ], xGuildID[ id ])
			query = SQL_PrepareQuery( gDbConnect, "%s", sql );
		
			if( !SQL_Execute( query )){
				errcode = SQL_QueryError(query, error, charsmax(error))
				SetLog( LOG_GUILD, "Erro ao atualizar pontos da Guilda ID: %i [%d] '%s' - '%s'", xGuildID[id], errcode, error, sql)
				SQL_FreeHandle(query)
				return PLUGIN_HANDLED;
			}
		
			SQL_FreeHandle( query );
				
			formatex(sql, charsmax(sql), "SELECT ID, PONTOS FROM bail_guilds ORDER BY PONTOS DESC", xGuildPoints[ id ], xGuildID[ id ])
			query = SQL_PrepareQuery(gDbConnect, "%s", sql)
			new rank, dbkey[32]
		
			if( !SQL_Execute( query )){
				errcode = SQL_QueryError(query, error, charsmax(error))
				SetLog( LOG_GUILD, "Erro ao criar o rank da Guilda ID: %i [%d] '%s' - '%s'", xGuildID[id], errcode, error, sql)
				
				SQL_FreeHandle( query );
				
				return PLUGIN_HANDLED;
			}
		
			totalrank = SQL_NumResults( query );

			while( SQL_MoreResults( query )){
				rank++

				SQL_ReadResult( query, 0, dbkey, 31)
			
				if( xGuildID[id] == str_to_num( dbkey ))
					break;

				SQL_NextRow( query );
			}
		
			xGuildaRank[ id ] = rank
			
			for( new x = 1; x <= xMaxPlayers; x++ ){
				if( xPlayerConnected[ x ] && xPlayerGuildMember[ x ] && xGuildID[ x ] == xGuildID[ id ])
					xGuildaRank[x] = xGuildaRank[ id ];
			}			
		
			PrintGuild(id, "^3 %s^1 esta na no rank^3 #%i^1 de^3 %i^1 guilds com^4 %i^1 pontos!", xGuildName[ id ], xGuildaRank[ id ], totalrank, xGuildPoints[ id ])
		
			SQL_FreeHandle( query );
			close_mysql();
			
			OpcoesMenu( id );
		}
		
		case 1: BancoMenu( id );
		
		/** INVENTARIO DA GUILD **/
		case 2: client_cmd( id, "guilditens");
		
		/** MOTD DE MEMBROS **/
		case 3: {
			MostrarMotdMembros( id, id );
			OpcoesMenu( id );
		}
		
		/** AJUDA GUILD **/
		case 4: {
			show_motd( id, "ajudaguild.html");
			OpcoesMenu( id );
		}
		
		case 5: Kitar_Guild( id );
	}
	
	return PLUGIN_HANDLED;
}

public BancoMenu( id ){	
	mySQLConnect();

	if( gDbConnect == Empty_Handle )
		return PLUGIN_HANDLED;
	
	static sql[212], thebankquery[63]
	new Handle:query
	new errcode, GuildaBank
	
	sql[0] = '^0'
	formatex( sql, charsmax( sql ), "SELECT ZMXP_AMMOPACKS FROM bail_guilds WHERE ID = '%i'", xGuildID[id])
	query = SQL_PrepareQuery( gDbConnect, "%s", sql );
	
	if( !SQL_Execute( query )){
		errcode = SQL_QueryError( query, error, charsmax( error ))
		SetLog( LOG_GUILD, "Erro ao criar query de saque para Guilda: %i [%d] '%s' - '%s'", xGuildID[id], errcode, error, sql)
		SQL_FreeHandle( query );
		return PLUGIN_HANDLED;
	}	
	
	SQL_ReadResult( query, 0, thebankquery, charsmax( thebankquery ))
	GuildaBank = str_to_num( thebankquery );
	
	SQL_FreeHandle( query );
	close_mysql();
	
	static menu[512], len
	len = 0
	
	// T�tulo
	len += formatex(menu[len], charsmax(menu) - len, "\r[ %s ] \w- Level: \r%i\w/10^n\yBanco da Guild - \dSaldo:\r %i \dAPs^n", xGuildName[id], PegarLevelGuild(xGuildPoints[id]), GuildaBank)
	
	// Op��es
	len += formatex(menu[len], charsmax(menu) - len, "^n\r1.\y +10 \wSaque^n")
	
	len += formatex(menu[len], charsmax(menu) - len, "\r2.\y -10 \wSaque^n^n")
	
	len += formatex(menu[len], charsmax(menu) - len, "\r3.\w Solicitar saque de \r[%i] \wdo Banco^n^n",  g_GuildaBankSaque[id])
	
	len += formatex(menu[len], charsmax(menu) - len, "^n\r0.\w Sair")
	
	show_menu(id, KEYSMENU, menu, -1, "Banco Menu")
	
	return PLUGIN_HANDLED;
}

public BancoHandle( id, key ){
	if( !xPlayerGuildMember[ id ])
		return PLUGIN_HANDLED;
	
	switch( key ){
		/** ++ SAQUE **/
		case 0:{
			g_GuildaBankSaque[ id ] += 10
			
			if( g_GuildaBankSaque[ id ] > 150 ){
				g_GuildaBankSaque[ id ] = 150
				PrintGuild( id, "^1 O limite de^3 150^1 para o saque foi atingido!")
			}
			
			BancoMenu(id)
			
		}
		case 1: // -- Saque
		{
			g_GuildaBankSaque[id] -= 10
			
			if( g_GuildaBankSaque[id] < 0 )
			{
				g_GuildaBankSaque[id] = 0
			}
			
			BancoMenu(id)
		}
		case 2: // Solicitar Saque...
		{
			if( g_GuildaBankSaque[id] == 0 )
			{
				PrintGuild(id, "^1 Voce nao pode sacar 0 ammo packs do banco!")
				return PLUGIN_HANDLED;
			}
			
			if( xGuildLider[id] )
			{
				SolicitarSaqueGuild(id, g_GuildaBankSaque[id], 1)
				// Solicita o saque... id... quantidade de ap... 1 = lider 0 = membro
			}
			else SolicitarSaqueGuild(id, g_GuildaBankSaque[id], 0)
		}
	}
	
	return PLUGIN_HANDLED;
}

public AdminMenu( id ){	
	static menu[512], len
	len = 0
		
	// T�tulo
	len += formatex(menu[len], charsmax(menu) - len, "\d[ %s ] Administrar Guild:^n", xPrefix );
	len += formatex(menu[len], charsmax(menu) - len, "\rGuild: %s | Pontos: %d/10^n^n", xGuildName[ id ], PegarLevelGuild( xGuildPoints[ id ]));
	
	// Op��es
	if( xGuildMembers[ id ] >= GUILD_LIMIT )
		len += formatex(menu[len], charsmax(menu) - len, "\d1. Convidar novo jogador (CHEIO)^n")

	else len += formatex(menu[len], charsmax(menu) - len, "\d1.\r Convidar novo jogador^n")
	
	len += formatex(menu[len], charsmax(menu) - len, "\d2.\r Expulsar jogador^n^n");
	
	len += formatex(menu[len], charsmax(menu) - len, "\d3.\y Alterar Nome da Guild^n");
	len += formatex(menu[len], charsmax(menu) - len, "\d4.\y Alterar TAG da Guild^n^n");
	
	len += formatex(menu[len], charsmax(menu) - len, "\d5.\r Transferir Lider^n");
	len += formatex(menu[len], charsmax(menu) - len, "\d6.\r Fechar Guild^n");
	
	len += formatex(menu[len], charsmax(menu) - len, "^n\d0. Sair")
	
	show_menu(id, KEYSMENU, menu, -1, "Admin Menu")
}

public AdminHandle( id, key ){
	if( !xPlayerGuildMember[ id ])
		return PLUGIN_HANDLED;
	
	switch( key ){
		/** CONVIDAR JOGADOR **/
		case 0:{
			if( xGuildLider[ id ])
				ShowMenuPlayers( id );
		
			else ColorChat( id, GREEN, "^x04 Voce nao e o lider da %s!", xGuildName[ id ]);
		}
		
		/** EXPULSAR JOGADOR **/
		case 1:{
			if( xGuildLider[ id ])
				ExcluirMenu( id );
	
			else ColorChat( id, GREEN, "^x04 Voce nao e o lider da %s!", xGuildName[ id ]);
		}
		
		/** ALTERAR NOME DA GUILD **/
		case 2:{
			if( xGuildLider[ id ]){
				client_cmd( id, "messagemode NomeGuild");
				AdminMenu( id );
			}
			
			else ColorChat( id, GREEN, "^x04 Voce nao e o lider da %s!", xGuildName[ id ]);
		}
		
		/** ALTERAR TAG DA GUILD **/
		case 3:{
			if( xGuildLider[ id ]){
				client_cmd( id, "messagemode TagGuild");
				AdminMenu( id );
			}
			
			else ColorChat( id, GREEN, "^x04 Voce nao e o lider da %s!", xGuildName[ id ]);
		}
		
		/** TRANSFERIR LIDER DA GUILD **/
		case 4:{
			if( xGuildLider[ id ])
				LiderTransferMenu( id );
	
			else ColorChat( id, GREEN, "^x04 Voce nao e o lider da %s!", xGuildName[ id ]);
		}

		case 5:{
			if( xGuildLider[ id ])
				Fechar_Guild( id );
			
			else ColorChat( id, GREEN, "^x04 Voce nao e o lider da %s!", xGuildName[ id ]);
		}
	}
	
	return PLUGIN_HANDLED;
}

public ShowMenuPlayers( id ){
	static iTitle[ 128 ];
	formatex( iTitle, charsmax( iTitle ), "\r[ %s ]\w Convidar jogador para Guild^n", xGuildName[ id ])
	new iMenu = menu_create( iTitle, "handle_player");
	
	new iName[ 33 ], iNum[ 4 ];
	
	for( new i = 1 ; i <= xMaxPlayers; i++ ){
		if( !xPlayerConnected[ i ] || id == i || xPlayerGuildMember[ i ] || !AccessReleased( i ) || is_user_bot( i ))
			continue;
		
		get_user_name( i, iName, charsmax( iName ));
		num_to_str( i, iNum, charsmax( iNum ));
		menu_additem( iMenu, iName, iNum );
	}
	
	menu_setprop( iMenu, MPROP_EXITNAME, "\rSair")
	menu_display( id,  iMenu );
}

public handle_player( id, menu, item ){
	if( item == MENU_EXIT ){
		menu_destroy( menu );
		return PLUGIN_HANDLED;
	}
	
	new data[6], iName[64]
	new access, callback
	menu_item_getinfo(menu, item, access, data,5, iName, 63, callback)
	
	new tempid = str_to_num(data)
	
	if( !AccessReleased( tempid ) || is_user_bot( tempid )){
		PrintGuild( id, "^1 Ops, ocorreu um erro!");
		return PLUGIN_HANDLED;
	}	
	
	if( !xPlayerConnected[ tempid ] || xPlayerGuildMember[ tempid ]){
		ShowMenuPlayers( id );
		return PLUGIN_HANDLED;
	}
	
	new szBuffer[32]
	get_user_name(id, szBuffer,31)
	
	new szTempidName[32]
	get_user_name(tempid, szTempidName, 31)
	
	xTryingToInvite[id] = tempid
	EnviarConviteGuild(id, xTryingToInvite[id])
		
	PrintGuild(xTryingToInvite[id],"^3 %s^1 convidou voce para entrar na Guild^3 %s^1 !", szBuffer, xGuildName[id])
	PrintGuild(id,"^1 Voce convidou o jogador^3 %s^1 para entrar na %s", szTempidName, xGuildName[id])
	
	return PLUGIN_HANDLED;
}
	
EnviarConviteGuild(inviter, target)
{
	static szMenu[128],iLen
	static szBuffer[32]
	get_user_name(inviter, szBuffer, charsmax(szBuffer))
	
	iLen = formatex(szMenu,charsmax(szMenu), "\y[ CONVITE DE GUILD ]^n\wAceita entrar na Guild \y%s \wde %s\w?^n^n",xGuildName[inviter], szBuffer)
	
	iLen += formatex(szMenu[iLen],charsmax(szMenu) - iLen, "\r1. \wAceito^n")
	iLen += formatex(szMenu[iLen],charsmax(szMenu) - iLen, "\r2. \wNao aceito^n")
	
	show_menu(target,KEYSINVITE,szMenu, -1,"Convidar")
	xPlayerInviter[target] = inviter
}

public ConvidarHandle( tempid, key ){
	new inviter = xPlayerInviter[ tempid ];
	
	if( xGuildMembers[ inviter ] >= GUILD_LIMIT ){
		PrintGuild( tempid, "^1 Ops, ocorreu um erro e voce nao entrou na guild!")
		return PLUGIN_HANDLED
	}
	
	if( !AccessReleased( tempid )){
		PrintGuild( tempid, "^1 Ops, ocorreu um erro e voce nao entrou na guild!")
		return PLUGIN_HANDLED;
	}	
	
	static sTempName[ 32 ];
	get_user_name( tempid, sTempName, charsmax( sTempName ));
	replace_all( sTempName, charsmax( sTempName ), "'", "\'");
	
	static sTempAuth[ 64 ];
	GetUserKey( tempid, sTempAuth, charsmax( sTempAuth ));
	
	switch( key ){
		case 0:{
			if( xGuildLider[ inviter ]){
				if( xGuildMembers[ inviter ] < GUILD_LIMIT ){
					mySQLConnect();
	
					if( gDbConnect == Empty_Handle )
						return PLUGIN_HANDLED;
	
					static error[128], sql[542]
					new Handle:query, errcode
					
					formatex( sql, charsmax( sql ), "UPDATE bail_registro SET ID_GUILD = '%d', LIDER_GUILD = '0', PONTOS_GUILD = '0' WHERE MEMBRO_KEY = '%s'", xGuildID[ inviter ], sTempAuth );
					query = SQL_PrepareQuery( gDbConnect, "%s", sql );
		
					if( SQL_Execute( query )){
						xGuildMembers[ inviter ]++;
						
						xGuildID[ tempid ] = xGuildID[ inviter ];
						xGuildMembers[ tempid ] = xGuildMembers[ inviter ];
						xGuildPoints[ tempid ] = xGuildPoints[ inviter ];
						xGuildaRank[ tempid ] = xGuildaRank[ inviter ];
						
						copy( xGuildName[ tempid ], charsmax( xGuildName[]), xGuildName[ inviter ]);
						copy( xGuildTag[ tempid ], charsmax( xGuildTag[]), xGuildTag[ inviter ]);
						
						xPlayerGuildMember[ tempid ] = true;
						xGuildLider[ tempid ] = false;
						
						/** ATUALIZANDO ITENS **/
						xGuildMaxSlots[ tempid ] = xGuildMaxSlots[ inviter ];
						xGuildItens[ tempid ] = xGuildItens[ inviter ];
						
						for( new i = 0; i <= xGuildItens[ tempid ]; i++ )
							xGuildItem[ tempid ][ i ] = xGuildItem[ inviter ][ i ];
						
						ColorChat( 0, RED, "^x01 O Player^x03 %s^x01 entrou na Guild^x04 %s", sTempName, xGuildName[ inviter ]);
						ColorChat( tempid, RED, "^x01 Bem-vindo^x03 %s^x01 na nossa guild,^x03 %s^x01", sTempName, xGuildName[ inviter ]);
						ColorChat( tempid, RED, "^x01 Para falar no chat apenas para Guild comece a escrita com #");
						ColorChat( tempid, RED, "^x01 Para falar no microfone apenas para Guild use a bind letra +guildvoice");
					}
					
					else {						
						errcode = SQL_QueryError( query, error, charsmax( error ))
						SetLog( LOG_GUILD, "[GUILDs] Erro ao colocar Membro: %s na Guilda %s [%d] '%s' - '%s'", sTempName, xGuildName[ inviter ], errcode, error, sql );
					}
	
					SQL_FreeHandle( query );
					close_mysql();
				}
			}
		}
		
		case 1:{
			ColorChat( inviter, RED, "^x01 O Player^x03 %s^x01 nao aceitou seu convite de Guild.", sTempName );
			xPlayerGuildMember[ tempid ] = false;
			xPlayerInviter[ tempid ] = 0;
		}
	}
	
	return PLUGIN_HANDLED;
}

public ExcluirMenu( id ){
	if( !xGuildLider[ id ])
		return PLUGIN_HANDLED;
	
	if( !AccessReleased( id ))
		return PLUGIN_HANDLED;	
	
	static menu[512], len
	len = 0
	
	// T�tulo
	len += formatex(menu[len], charsmax(menu) - len, "\r[ %s ] \w- Remover jogador da Gangue^n\dATENCAO: O JOGADOR TERA TODOS OS PONTOS DE CONTRIBUICAO REMOVIDOS!^n^n", xGuildName[id])
	
	mySQLConnect();
	
	if( gDbConnect == Empty_Handle )
		return false;
	
	gPersistentTemp = true
	
	static sql[320]
	new Handle:query
	new errcode
	new total_guild = 0
	
	formatex(sql, charsmax(sql), "SELECT NICK, MEMBRO_KEY FROM bail_registro WHERE ID_GUILD = '%d' AND LIDER_GUILD = 0", xGuildID[id])
	query = SQL_PrepareQuery(gDbConnect, "%s", sql)
	
	if ( !SQL_Execute(query) ) {
		errcode = SQL_QueryError(query, error, charsmax(error))
		SetLog( LOG_GUILD, "Erro ao criar query do menu de excluir para Guilda ID: %i [%d] '%s' - '%s'", xGuildID[id], errcode, error, sql)
		SQL_FreeHandle(query)
		return PLUGIN_HANDLED;
	}
	
	if( SQL_NumResults( query )){
		static membroGuild[ 64 ], membrokey[ 64 ];
				
		while( SQL_MoreResults( query )){
			SQL_ReadResult(query, SQL_FieldNameToNum(query, "NICK"), membroGuild, sizeof(membroGuild) - 1)
			SQL_ReadResult(query, SQL_FieldNameToNum(query, "MEMBRO_KEY"), membrokey, sizeof(membrokey) - 1)

			total_guild++
			
			len += formatex(menu[len], charsmax(menu) - len, "\d%i.\r %s (%s)^n", total_guild, membroGuild, membrokey)
			
			SQL_NextRow(query)
		}
	}
	
	gPersistentTemp = false
	
	SQL_FreeHandle(query)
	close_mysql()
	
	xGuildMembers[id] = total_guild
	
	len += formatex(menu[len], charsmax(menu) - len, "^n\r0.\w Sair")
	
	show_menu( id, KEYSMENU, menu, -1, "Excluir Menu");
	
	return PLUGIN_HANDLED // Possivel erro, verificar depois....
}

public ExcluirHandle( id, key ){
	if( !xGuildLider[ id ])
		return PLUGIN_HANDLED;

	if( !AccessReleased( id ))
		return PLUGIN_HANDLED;
	
	mySQLConnect();
	
	if( gDbConnect == Empty_Handle )
		return PLUGIN_HANDLED;
	
	gPersistentTemp = true
	
	static sql[ 320 ];
	new Handle: query, errcode
	new total_guild = 0
	
	formatex( sql, charsmax( sql ), "SELECT NICK, MEMBRO_KEY, LIDER_GUILD FROM bail_registro WHERE ID_GUILD = '%d' AND LIDER_GUILD = 0", xGuildID[ id ])
	query = SQL_PrepareQuery( gDbConnect, "%s", sql )
	
	if( !SQL_Execute( query )){
		errcode = SQL_QueryError( query, error, charsmax( error ))
		
		SetLog( LOG_GUILD, "Erro ao criar query do handler de excluir para Guild ID: %i [%d] '%s' - '%s'", xGuildID[id], errcode, error, sql)
		
		SQL_FreeHandle( query );
		return PLUGIN_HANDLED;
	}
	
	if( SQL_NumResults( query )){
		static sMembroNick[ 64 ], sMembroKey[ 64 ];
		
		while( SQL_MoreResults( query )){
			SQL_ReadResult( query, SQL_FieldNameToNum( query, "NICK"), sMembroNick, charsmax( sMembroNick ));
			SQL_ReadResult( query, SQL_FieldNameToNum( query, "MEMBRO_KEY"), sMembroKey, charsmax( sMembroKey ));
			
			total_guild++
			
			if( total_guild == (key+1)){
				gPersistentTemp = false
								
				SQL_FreeHandle( query );
				
				formatex( sql, charsmax( sql ), "UPDATE bail_registro SET ID_GUILD = 0, LIDER_GUILD = 0, PONTOS_GUILD = 0 WHERE MEMBRO_KEY = '%s'", sMembroKey )
				query = SQL_PrepareQuery( gDbConnect, "%s", sql )
				
				if( SQL_Execute( query )){
					for( new x = 1; x <= xMaxPlayers; x++ ){
						if( xPlayerConnected[ x ] && xPlayerGuildMember[ x ] && xGuildID[ x ] == xGuildID[ id ]){
							static sAuth[ 64 ];
							GetUserKey( x, sAuth, charsmax( sAuth ));
														
							if( equal( sMembroKey, sAuth )){
								xPlayerGuildMember[ x ] = false;
								xGuildID[ x ] = 0;
								xGuildLider[ x ] = false;
								xGuildMembers[ x ] = 0;
								xGuildPoints[ x ] = 0;
								xGuildaRank[ x ] = 0;
								xTryingToInvite[ x ] = 0;
								xPlayerInviter[ x ] = 0;
								
								//NativeGuildLoadInventario( x );
								
								/** ATUALIZANDO ITENS **/
								xGuildMaxSlots[ x ] = 0;
								xGuildItens[ x ] = 0;
								
								for( new i = 0; i <= xGuildItens[ id ]; i++ )
									xGuildItem[ x ][ i ] = 0;
								
								ColorChat( x, RED, "^x01 Voce foi expulso da Guild^x04 %s", xGuildName[ id ]);
								
								break;
							}
							
							else 
								xGuildMembers[ x ]--;
						}
					}
					
					ColorChat( 0, RED, "^x01 O Membro^x03 %s^x01 foi expulso da Guild^x04 %s", sMembroNick, xGuildName[ id ])
					
					SQL_FreeHandle( query );
					close_mysql();
				}
				
				else {
					errcode = SQL_QueryError( query, error, charsmax( error ))
					
					SetLog( LOG_GUILD, "Erro ao remover membro (2) %s: da Guild %s [%d] '%s' - '%s'", sMembroKey, xGuildName[ id ], errcode, error, sql)
					PrintGuild( id, "^1 Houve um erro no banco de dados... nao foi possivel remover %s da guild", sMembroKey )
					
					SQL_FreeHandle( query );
					return PLUGIN_HANDLED;
				}
			}
			
			//SQL_NextRow( query );	
		}
	}
	
	gPersistentTemp = false
	
	SQL_FreeHandle( query );
	close_mysql();
	
	return PLUGIN_HANDLED;
}

public client_putinserver( id ){
	if( 1 < id > xMaxPlayers )
		return
	
	xPlayerConnected[id] = true
	xPlayerGuildMember[id] = false
	xGuildID[id] = 0
	xGuildLider[id] = false
 	xGuildMembers[id] = 0
 	xGuildPoints[id] = 0
 	xGuildaRank[id] = 0
	xTryingToInvite[id] = 0
	xPlayerInviter[id] = 0
	g_GuildaBankSaque[id] = 0
	g_BancoSaqueLider[id] = 0
	g_BancoSaqueLiderQuantia[id] = 0
}

public client_disconnected( id ){
	if( 1 < id > xMaxPlayers )
		return;
	
	xPlayerConnected[id] = false
	xPlayerGuildMember[id] = false
	xGuildID[id] = 0
	xGuildLider[id] = false
 	xGuildMembers[id] = 0
 	xGuildPoints[id] = 0
 	xGuildaRank[id] = 0
	xTryingToInvite[id] = 0
	xPlayerInviter[id] = 0
	g_BancoSaqueLider[id] = 0
	g_BancoSaqueLiderQuantia[id] = 0	
}

public ChangeGuildNome( id ){	
	if( read_argc() > 2 ){
		client_cmd( id, "messagemode NomeGuild");
		AdminMenu( id );
		ColorChat( id, GREEN, "^x04 Argumentos errado. Escreva o nome da guild ENTRE ASPAS.")
		return PLUGIN_HANDLED
	}
	
	if( !xGuildLider[ id ]){
		client_cmd( id, "messagemode NomeGuild");
		AdminMenu( id );
		ColorChat( id, GREEN, "^x04 Voce nao eh o lider dessa guild.")
		return PLUGIN_HANDLED
	}
	
	if( !AccessReleased( id )){
		client_cmd( id, "messagemode NomeGuild");
		AdminMenu( id );
		ColorChat( id, GREEN, "^x04 Voce nao tem autorizacao para fazer isso.")
		return PLUGIN_HANDLED;
	}	
	
	/** NOVO NOME DA GUILD **/
	new arg[32];
	read_argv(1, arg, charsmax( arg ))
	
	new len = strlen( arg );
	if( len > 16 ){
		client_cmd( id, "messagemode NomeGuild");
		AdminMenu( id );
		ColorChat( id, GREEN, "^x04 Limite de 16 caracteres para o nome da guild.")
		return PLUGIN_HANDLED
	}
	
	if( len < 5 ){
		client_cmd( id, "messagemode NomeGuild");
		AdminMenu( id );
		ColorChat( id, GREEN, "^x04 Minimo de 6 caracteres para o nome da guild.")
		return PLUGIN_HANDLED
	}
	
	replace_all(arg, charsmax(arg), "'", "\'") // Evitar bug no query
	replace_all(arg, charsmax(arg), "%", "i") // Evitar bug no query
	
	mySQLConnect();

	if( gDbConnect == Empty_Handle )
		return false
	
	static sql[212]
	new Handle:query
	new errcode
	
	formatex( sql, charsmax( sql ), "SELECT ID FROM bail_guilds WHERE GUILD_NAME = '%s'", arg )
	query = SQL_PrepareQuery(gDbConnect, "%s", sql)
	
	if( !SQL_Execute( query )){
		errcode = SQL_QueryError(query, error, charsmax(error))
		SetLog( LOG_GUILD, "Erro ao trocar o nome da Guild (2) %s: [%d] '%s' - '%s'", xGuildName[id], errcode, error, sql)
		SQL_FreeHandle(query)
		ColorChat( id, GREEN, "^x04 Houve um erro no banco de dados, nao foi possivel fazer a alteracao.")
		return PLUGIN_HANDLED
	}
	
	/** ESSE NOME DA GUILD JA EXISTE **/
	if( SQL_NumResults( query )){	
		client_cmd( id, "messagemode NomeGuild");
		ColorChat( id, GREEN, "^x04 Esse nome de Guild ja esta em uso.")
		AdminMenu( id );
		
		SQL_FreeHandle(query)
		close_mysql()
		return PLUGIN_HANDLED
	}	
	
	SQL_FreeHandle(query)
	
	formatex(sql, charsmax(sql), "UPDATE bail_guilds SET GUILD_NAME = '%s' WHERE ID = '%d'", arg, xGuildID[id])
	query = SQL_PrepareQuery(gDbConnect, "%s", sql)	
	
	if( !SQL_Execute( query )){
		errcode = SQL_QueryError(query, error, charsmax(error))
		SetLog( LOG_GUILD, "Erro ao trocar o nome da Guild %s: [%d] '%s' - '%s'", xGuildName[id], errcode, error, sql)
		SQL_FreeHandle(query)
		ColorChat( id, GREEN, "^x04 Houve um erro no banco de dados, nao foi possivel fazer a alteracao.")
		return PLUGIN_HANDLED
	}
	
	SQL_FreeHandle(query)
	close_mysql()
	
	replace_all(arg, charsmax(arg), "\'", "'") // Consertando o nome denovo...
	
	new GuildID = xGuildID[id]
	
	for( new x = 1; x <= xMaxPlayers; x++){
		if(xPlayerConnected[x] && xPlayerGuildMember[x] && xGuildID[x] == GuildID)
			copy(xGuildName[x], charsmax(xGuildName[]), arg)
	}
	
	ColorChat( id, GREEN, "^x04 Alterou com sucesso o nome da guild para %s !", arg)
	AdminMenu( id );
	
	return PLUGIN_HANDLED
}

public ChangeGuildTag( id ){
	AdminMenu( id );
	
	if( read_argc() > 2 ){
		client_cmd( id, "messagemode TagGuild");
		AdminMenu( id );
		ColorChat( id, GREEN, "^x04 Argumentos errado. Escreva a TAG entre aspas.")
		return PLUGIN_HANDLED
	}
	
	if( !xGuildLider[ id ]){
		client_cmd( id, "messagemode TagGuild");
		AdminMenu( id );
		ColorChat( id, GREEN, "^x04 Voce nao eh o lider dessa guild.")
		return PLUGIN_HANDLED
	}
	
	if( !AccessReleased( id )){
		client_cmd( id, "messagemode TagGuild");
		AdminMenu( id );
		ColorChat( id, GREEN, "^x04 Voce nao tem autorizacao para fazer isso.")
		return PLUGIN_HANDLED;
	}	
	
	/** NOVA TAG DA GUILD **/
	new arg[32]
	read_argv(1, arg, charsmax( arg ))
	
	new len = strlen(arg)
	if( len > 15 ){
		client_cmd( id, "messagemode TagGuild");
		AdminMenu( id );
		ColorChat( id, GREEN, "^x04 Limite de 15 caracteres para a tag da guild.")
		return PLUGIN_HANDLED
	}
	
	if( len < 3 ){
		client_cmd( id, "messagemode TagGuild");
		AdminMenu( id );
		ColorChat( id, GREEN, "^x04 Minimo de 4 caracteres para a tag da guild.")
		return PLUGIN_HANDLED
	}
	
	replace_all(arg, charsmax(arg), "'", "\'") // Evitar bug no query
	replace_all(arg, charsmax(arg), "%", "i") // Evitar bug no query
	
	mySQLConnect()

	if( gDbConnect == Empty_Handle )
		return false
	
	static sql[212]
	new Handle:query
	new errcode
	
	formatex(sql, charsmax(sql), "SELECT ID FROM bail_guilds WHERE GUILD_TAG = '%s'", arg)
	query = SQL_PrepareQuery(gDbConnect, "%s", sql)
	
	if( !SQL_Execute( query )) {
		errcode = SQL_QueryError(query, error, charsmax(error))
		SetLog( LOG_GUILD, "Erro ao trocar a tag da Guild (2) %s: [%d] '%s' - '%s'", xGuildName[id], errcode, error, sql)
		SQL_FreeHandle(query)
		ColorChat( id, GREEN, "^x04 Houve um erro no banco de dados, nao foi possivel fazer a alteracao.")
		return PLUGIN_HANDLED
	}
	
	/** ESSA TAG JA ESTA EM USO **/
	if( SQL_NumResults( query )){
		client_cmd( id, "messagemode TagGuild");
		ColorChat( id, GREEN, "^x04 Essa tag de Guild ja esta em uso.")
		AdminMenu( id );
		
		SQL_FreeHandle(query)
		close_mysql()
		return PLUGIN_HANDLED
	}	
	
	SQL_FreeHandle(query)	
	
	formatex(sql, charsmax(sql), "UPDATE bail_guilds SET GUILD_TAG = '%s' WHERE ID = '%d'", arg, xGuildID[id])
	query = SQL_PrepareQuery(gDbConnect, "%s", sql)	
	
	if( !SQL_Execute( query )){
		errcode = SQL_QueryError(query, error, charsmax(error))
		SetLog( LOG_GUILD, "Erro ao trocar a Tag da Guild %s: [%d] '%s' - '%s'", xGuildName[id], errcode, error, sql)
		SQL_FreeHandle(query)
		ColorChat( id, GREEN, "^x04 Houve um erro no banco de dados, nao foi possivel fazer a alteracao.")
		return PLUGIN_HANDLED
	}
	
	SQL_FreeHandle(query)
	close_mysql()
	
	replace_all(arg, charsmax(arg), "\'", "'") // Consertando o nome denovo...	
	
	new GuildID = xGuildID[id]
	
	for( new x = 1; x <= xMaxPlayers; x++ ){
		if(xPlayerConnected[x] && xPlayerGuildMember[x] && xGuildID[x] == GuildID)
			copy(xGuildTag[x], charsmax(xGuildTag[]), arg)
	}
	
	ColorChat( id, GREEN, "^x04 Alterou com sucesso a tag da guild para %s !", arg)
	AdminMenu( id );
	
	return PLUGIN_HANDLED
}

SolicitarSaqueGuild(id, saque, lider)
{
	if(lider == 0) // Vamos verificar se o l�der est� online
	{
		new LiderOnline = 666
		
		for (new x = 1; x <= xMaxPlayers; x++) 
		{
			if(xPlayerConnected[x] && xPlayerGuildMember[x] && xGuildID[x] == xGuildID[id] && xGuildLider[x])
			{	
				LiderOnline = x // Sim, est� online
				break;
			}
		}
		
		if( LiderOnline == 666 ) // N�o esta online
		{
			PrintGuild(id,"^1 O master da sua Guild nao esta online!")
			return PLUGIN_HANDLED;
		}
		
		if(!AccessReleased(LiderOnline))
		{
			PrintGuild(LiderOnline, "^1 Voce nao tem autorizacao para fazer isso.")
			return PLUGIN_HANDLED;
		}		
		
		// Enviar pedido para o L�der...
		new szMenu[128],iLen
		new szBuffer[32]
		get_user_name(id, szBuffer, charsmax(szBuffer))
	
		iLen = formatex(szMenu,charsmax(szMenu), "\y[ PEDIDO DE SAQUE ]^n\r%s \wquer sacar \r%i \wAPs do Banco da Guild!^n^n", szBuffer, saque)
	
		iLen += formatex(szMenu[iLen],charsmax(szMenu) - iLen, "\r1. \wPermitir^n")
		iLen += formatex(szMenu[iLen],charsmax(szMenu) - iLen, "\r2. \wNao permitir^n")
	
		show_menu(LiderOnline, KEYSINVITE, szMenu, -1, "Saque")
	
		g_BancoSaqueLider[LiderOnline] = id
		g_BancoSaqueLiderQuantia[LiderOnline] = saque
		
		return PLUGIN_HANDLED;
		
	}
	else // � o lider ent�o n�o precisa de verifica��o nenhuma, go!
	{
		//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		// PEGAR O N�MERO DE PACKS DO BANCO NOVAMENTE
		/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		
		mySQLConnect()

		if ( gDbConnect == Empty_Handle ) return PLUGIN_HANDLED;
	
		static sql[212], error[128], thebankquery[63]
		new Handle:query
		new errcode
		new bank
	
		sql[0] = '^0'
		formatex(sql, charsmax(sql), "SELECT `ZMXP_AMMOPACKS` FROM `bail_guilds` WHERE `ID` = '%i'", xGuildID[id])
		query = SQL_PrepareQuery(gDbConnect, "%s", sql)
	
		if ( !SQL_Execute(query) ) {
			errcode = SQL_QueryError(query, error, charsmax(error))
			SetLog( LOG_GUILD, "Erro ao criar query do Banco Menu 2 para Guilda: %i [%d] '%s' - '%s'", xGuildID[id], errcode, error, sql)
			SQL_FreeHandle(query)
			return PLUGIN_HANDLED;
		}	
	
		SQL_ReadResult(query, 0, thebankquery, charsmax(thebankquery))
		bank = str_to_num(thebankquery)
	
		SQL_FreeHandle(query)
		
		/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		
		// Checks de seguran�a...
		if(saque <= 0)
		{
			PrintGuild(id,"^1 Houve um erro ao fazer o saque!")
			close_mysql()
			return PLUGIN_HANDLED;
		}
		
		if(saque > bank)
		{
			PrintGuild(id,"^1 O banco tem apenas %i APs, nao da pra sacar %i!", bank, saque)
			close_mysql()
			return PLUGIN_HANDLED;
		}
		
		// OK... o saque nao � negativo nem maior que a quantidade do banco.
		
		new quantia = (bank -= saque)
		
		sql[0] = '^0'
		formatex(sql, charsmax(sql), "UPDATE `bail_guilds` SET `ZMXP_AMMOPACKS`='%i' WHERE `ID`='%i'", quantia, xGuildID[id])
		query = SQL_PrepareQuery(gDbConnect, "%s", sql)
	
		if ( !SQL_Execute(query) ) {
			errcode = SQL_QueryError(query, error, charsmax(error))
			SetLog( LOG_GUILD, "Erro no saque de %i para a Guilda: %i [%d] '%s' - '%s'", saque, xGuildID[id], errcode, error, sql)
			PrintGuild(id,"^1 Houve um erro no banco de dados... Desculpe.")
			SQL_FreeHandle(query)
			return PLUGIN_HANDLED;
		}
		
		SQL_FreeHandle(query)
		close_mysql()
		
		new ammopackz = zp_get_user_ammo_packs(id)
		zp_set_user_ammo_packs(id, ammopackz + saque)
		
		PrintGuild(id,"^1 Voce recebeu^3 %i^1 APs do Banco da Guild com sucesso!", saque)
		
		new namex[32]
		get_user_name(id, namex, 31)
		
		PrintGuild(0,"^1 Master^3 %s^1 retirou^3 %i^1 APs do Banco da Guild^3 %s", namex, saque, xGuildName[id])
		
		SetLog( LOG_GUILD, "Master %s retirou %i APs do Banco da Guild %s", namex, saque, xGuildName[id])
	}
	
	return PLUGIN_HANDLED;
}

public SaqueHandle(id, key)
{	
	new pedinte = g_BancoSaqueLider[id]
	new saque = g_BancoSaqueLiderQuantia[id]
	new NomeLider[32], NomePedinte[32]
	
	if(saque <= 0)
	{
		PrintGuild(id,"^1 Houve um erro ao fazer o saque!")
		return PLUGIN_HANDLED;
	}	
	
	if(!xGuildLider[id])
	{
		PrintGuild(id, "^1 Ops, voce nao eh o lider de uma guild!")
		return PLUGIN_HANDLED
	}
	
	if(!AccessReleased(id)) // Security Check
	{
		return PLUGIN_HANDLED;
	}
	
	get_user_name(pedinte, NomePedinte, charsmax(NomePedinte))
	get_user_name(id, NomeLider, charsmax(NomeLider))
	
	switch(key+1)
	{
		case 1: // Aceitou o pedido
		{
			//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// PEGAR O N�MERO DE PACKS DO BANCO NOVAMENTE
			/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		
			mySQLConnect()

			if ( gDbConnect == Empty_Handle ) return PLUGIN_HANDLED;
	
			static sql[212], error[128], thebankquery[63]
			new Handle:query
			new errcode
			new bank
	
			sql[0] = '^0'
			formatex(sql, charsmax(sql), "SELECT `ZMXP_AMMOPACKS` FROM `bail_guilds` WHERE `ID` = '%i'", xGuildID[id])
			query = SQL_PrepareQuery(gDbConnect, "%s", sql)
	
			if ( !SQL_Execute(query) ) {
				errcode = SQL_QueryError(query, error, charsmax(error))
				SetLog( LOG_GUILD, "Erro ao criar query de saque para Guilda: %i [%d] '%s' - '%s'", xGuildID[id], errcode, error, sql)
				SQL_FreeHandle(query)
				return PLUGIN_HANDLED;
			}	
	
			SQL_ReadResult(query, 0, thebankquery, charsmax(thebankquery))
			bank = str_to_num(thebankquery)
	
			SQL_FreeHandle(query)
			
			/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
			/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		
			// Checks de seguran�a...
		
			if(saque > bank)
			{
				PrintGuild(id,"^1 O banco tem apenas %i APs, nao da pra sacar %i!", bank, saque)
				PrintGuild(pedinte,"^1 O banco tem apenas %i APs, nao da pra sacar %i!", bank, saque)
				close_mysql()
				return PLUGIN_HANDLED;
			}
		
			// OK... o saque nao � negativo nem maior que a quantidade do banco.
		
			new quantia = (bank -= saque)
		
			sql[0] = '^0'
			formatex(sql, charsmax(sql), "UPDATE `bail_guilds` SET `ZMXP_AMMOPACKS`='%i' WHERE `ID`='%i'", quantia, xGuildID[id])
			query = SQL_PrepareQuery(gDbConnect, "%s", sql)
	
			if ( !SQL_Execute(query) ) {
				errcode = SQL_QueryError(query, error, charsmax(error))
				SetLog( LOG_GUILD, "Erro no saque de %i para a Guilda: %i [%d] '%s' - '%s'", saque, xGuildID[id], errcode, error, sql)
				PrintGuild(id,"^1 Houve um erro no banco de dados... Desculpe.")
				SQL_FreeHandle(query)
				return PLUGIN_HANDLED;
			}
		
			SQL_FreeHandle(query)
			close_mysql()
		
			new ammopackz = zp_get_user_ammo_packs(pedinte)
			zp_set_user_ammo_packs(pedinte, ammopackz + saque)
			
			PrintGuild(pedinte, "^1 O Master^3 %s^1 aceitou seu pedido de saque!", NomeLider)
			PrintGuild(pedinte,"^1 Voce recebeu^3 %i^1 APs do Banco da Guild com sucesso!", saque)
			PrintGuild(0,"^1 Membro^3 %s^1 retirou^3 %i^1 APs do Banco da Guild^3 %s", NomePedinte, saque, xGuildName[pedinte])
			SetLog( LOG_GUILD, "Membro %s retirou %i APs do Banco da Guild %s", NomePedinte, saque, xGuildName[pedinte])
		}
		case 2: // Recusou o pedido
		{
			PrintGuild(pedinte, "^3 %s^1 nao aceitou seu pedido de saque.",NomeLider)
			PrintGuild(id, "^1 Voce recusou o pedido de saque de^3 %s", NomePedinte)
			g_BancoSaqueLider[id] = 0  // talvez bugfix
			g_BancoSaqueLiderQuantia[id] = 0  // talvez bugfix
		}
	}
	
	return PLUGIN_HANDLED
}		

public VoiceOn(id)
{
	g_GuildaVoice[id] = true
	client_cmd(id, "+voicerecord")
	return PLUGIN_HANDLED;
}
public VoiceOff(id)
{
	g_GuildaVoice[id] = false
	client_cmd(id, "-voicerecord")
	return PLUGIN_HANDLED;
}

// ========================================
// Guild Party by hx7r
// ========================================

public voice_listening(receiver, sender, bool:listen)
{
	if(!is_user_connected(receiver) || !is_user_connected(sender) || receiver == sender)
		return FMRES_IGNORED

	if(g_GuildaVoice[sender])
	{
		if(xGuildID[sender] == xGuildID[receiver])
		{
			engfunc(EngFunc_SetClientListening, receiver, sender, true)
			return FMRES_SUPERCEDE
		}
		else
		{
			engfunc(EngFunc_SetClientListening, receiver, sender, false)
			forward_return(FMV_CELL, false);
			return FMRES_SUPERCEDE;
		}
		
	}
	return FMRES_IGNORED
}

public HookSay(id)
{	
	read_args(g_typed, charsmax(g_typed))
	remove_quotes(g_typed)
	
	if(containi(g_typed, "%") != -1)
		return PLUGIN_HANDLED
	
	if(!xPlayerGuildMember[id]) return PLUGIN_CONTINUE

	if(equal(g_typed, "") || !xPlayerConnected[id])
		return PLUGIN_CONTINUE	
	
	if(g_typed[0] == '#')
	{
		TeamGuildMSG(id, g_typed)
		return PLUGIN_HANDLED
	}	
	
	get_user_name(id, g_name, charsmax(g_name))
	g_team = get_user_team(id)		
	
	new const team_info[2][][] = {
		{"*SPEC* ", "*DEAD* ", "*DEAD* ", "*SPEC* "},
		{"", "", "", ""}
	}
	
	formatex(g_message, charsmax(g_message), "^1%s^4%s^3 %s :^1 %s", team_info[is_user_alive(id)][g_team], xGuildTag[id], g_name, g_typed)

	for(new i = 1; i <= xMaxPlayers; i++)
	{
		if(!is_user_connected(i) || !xPlayerConnected[i]) // Check duplo anti-crash
			continue

		if(is_user_alive(id) && is_user_alive(i) || !is_user_alive(id) && !is_user_alive(i))
		{
			send_message(g_message, id, i)
		}
	}	
		
	return PLUGIN_HANDLED_MAIN
}

public HookSayTeam(id)
{
	read_args(g_typed, charsmax(g_typed))
	remove_quotes(g_typed)
	
	if(containi(g_typed, "%") != -1)
		return PLUGIN_HANDLED
	
	if(!xPlayerGuildMember[id]) return PLUGIN_CONTINUE

	if(equal(g_typed, "") || !xPlayerConnected[id])
		return PLUGIN_CONTINUE	

	get_user_name(id, g_name, charsmax(g_name))
	g_team = get_user_team(id)
	
	new const team_info[2][][] = {
		{"(Spectator) ", "*DEAD*(Terrorist) ", "*DEAD*(Counter-Terrorist) ", "(Spectator) "},
		{"(Spectator) ", "(Terrorist) ", "(Counter-Terrorist) ", "(Spectator) "}
	}
	
	formatex(g_message, charsmax(g_message), "^1%s^4%s^3 %s :^1 %s", team_info[is_user_alive(id)][g_team], xGuildTag[id], g_name, g_typed)

	for(new i = 1; i <= xMaxPlayers; i++)
	{
		if(!is_user_connected(i) || !xPlayerConnected[i]) // Check duplo anti-crash
			continue

		if(get_user_team(id) == get_user_team(i))
		{
			if(is_user_alive(id) && is_user_alive(i) || !is_user_alive(id) && !is_user_alive(i))
			{
				send_message(g_message, id, i)
			}
		}
	}

	return PLUGIN_HANDLED_MAIN
}

public TeamGuildMSG(id, msg[])
{
	new szName[33]
	get_user_name (id, szName, sizeof szName -1)
	
	replace(msg, 190, "#", "")
	static i
	
	if( is_user_alive(id) )
	{
		for(i = 1 ; i <= xMaxPlayers ; i++)
		if(xPlayerConnected[i] && xPlayerGuildMember[i] && xGuildID[i] == xGuildID[id])
		{
			if(xGuildLider[id])
			{
				PrintGuildChat(i,"^3 (Master) %s^4:  %s", szName, msg)
			}
			else PrintGuildChat(i,"^3 %s^1:  %s", szName, msg)
			
			client_cmd(i, "speak events/enemy_died.wav")
		}
	}
	else 
	{
		for(i = 1 ; i <= xMaxPlayers ; i++)
		if(xPlayerConnected[i] && xPlayerGuildMember[i] && xGuildID[i] == xGuildID[id])
		{
			if(xGuildLider[id])
			{
				PrintGuildChat(i,"^1 *DEAD*^3 (Master) %s^4:  %s", szName, msg)
			}
			else PrintGuildChat(i,"^1 *DEAD*^3 %s^1:  %s", szName, msg)
			
			client_cmd(i, "speak events/enemy_died.wav")
		}
	}
}

mySQLConnect(){
	if( gDbConnect ){
		if( !get_pcvar_num( CvarMysqlPersistent ) && !gPersistentTemp )
			close_mysql();
		
		else return;
	}

	if( !gDbTuple ){
		SQL_SetAffinity("mysql");
		gDbTuple = StartConnect();
	}

	new errcode
	if( gDbTuple )
		gDbConnect = SQL_Connect( gDbTuple, errcode, error, charsmax( error ))

	if( gDbConnect == Empty_Handle ){
		SetLog( LOG_GUILD, "MySQL connect error: [%d] '%s'", errcode, error )
		SQL_FreeHandle( gDbTuple );
		gDbTuple = Empty_Handle
		return;
	}
}

close_mysql(){
	if( gDbConnect == Empty_Handle || get_pcvar_num( CvarMysqlPersistent ) || gPersistentTemp )
		return

	SQL_FreeHandle( gDbConnect );
	gDbConnect = Empty_Handle;
}

PrintGuild(id, const message_format[], any:...)
{
	static message[192], len;
	len = formatex(message, sizeof(message) - 1, "^4%s", MESSAGE_TAG_GUILD);
	vformat(message[len], sizeof(message) - len - 1, message_format, 3);
	
	static players[32], pnum;
	if( id )
	{
		players[0] = id;
		pnum = 1;
	}
	else
	{
		get_players(players, pnum);
	}
	
	for( new i = 0, player; i < pnum; i++ )
	{
		player = players[i];
		if( xPlayerConnected[player] && is_user_connected(player) ) // In�til mas acho que evita crash.
		{
			message_begin(MSG_ONE_UNRELIABLE, g_msgid_SayText, _, player);
			write_byte(player);
			write_string(message);
			message_end();
		}
	}
}

PrintGuildChat(id, const message_format[], any:...)
{
	static message[192], len;
	len = formatex(message, sizeof(message) - 1, "^4%s [Chat]", xGuildTag[id]);
	vformat(message[len], sizeof(message) - len - 1, message_format, 3);
	
	static players[32], pnum;
	if( id )
	{
		players[0] = id;
		pnum = 1;
	}
	else
	{
		get_players(players, pnum);
	}
	
	for( new i = 0, player; i < pnum; i++ )
	{
		player = players[i];
		if( xPlayerConnected[player] && is_user_connected(player) ) // In�til mas acho que evita crash.
		{
			message_begin(MSG_ONE_UNRELIABLE, g_msgid_SayText, _, player);
			write_byte(player);
			write_string(message);
			message_end();
		}
	}
}

stock send_message(const message[], const id, const i){
	message_begin(MSG_ONE, g_msgid_SayText, {0, 0, 0}, i)
	write_byte(id)
	write_string(message)
	message_end()
}

public PegarLevelGuild( pontos ){
	if( pontos <= 1000 )
		return 0;
	
	if( pontos <= 5000 )
		return 1;
	
	if( pontos <= 15000 )
		return 2;
	
	if( pontos <= 25000 )
		return 3
	
	if( pontos <= 45000 )
		return 4
	
	if( pontos <= 80000 )
		return 5
	
	if( pontos <= 120000 )
		return 6
	
	if( pontos <= 190000 )
		return 7
	
	if( pontos <= 250000 )
		return 8
	
	if( pontos <= 320000 )
		return 9
	
	if( pontos <= 400000 )
		return 10
	
	if( pontos > 400000 )
		return 10
	
	return 0
}

public MostrarMotdMembros( id, paraquem ){
	static motd[2048]
	new len = formatex(motd, sizeof(motd) - 1, "<body style=^"background-color:#030303; color:#FF8F00^">")
	len += format(motd[len], sizeof(motd) - len - 1,	"<font face=^"Verdana^" size=^"4^">NOME DA GUILD: <b>%s </b><br>", xGuildName[id])
	len += format(motd[len], sizeof(motd) - len - 1,	"RANK DA GUILD: <b>%i</b></font><br>", xGuildaRank[id])
	len += format(motd[len], sizeof(motd) - len - 1,	"<br>")
	len += format(motd[len], sizeof(motd) - len - 1,	"<br><font face=^"Verdana^" size=^"2^">")
	
	mySQLConnect();
	
	if( gDbConnect == Empty_Handle )
		return false;
	
	static sql[320]
	new Handle:query
	new errcode, member_points
	new total_guild = 0
	new total_points = 0

	formatex( sql, charsmax( sql ), "SELECT NICK, MEMBRO_KEY, PONTOS_GUILD FROM bail_registro WHERE ID_GUILD = '%d' ORDER BY LIDER_GUILD DESC", xGuildID[id])
	query = SQL_PrepareQuery( gDbConnect, "%s", sql )
	
	if( !SQL_Execute( query )){
		errcode = SQL_QueryError(query, error, charsmax( error ))
		SetLog( LOG_GUILD, "Erro ao criar query do motd para Guild ID: %i [%d] '%s' - '%s'", xGuildID[id], errcode, error, sql)
		SQL_FreeHandle(query)
		return PLUGIN_HANDLED;
	}

	if( SQL_NumResults( query )){
		static membroGuild[ 64 ], memberkey[ 64 ], memberpoints[ 32 ];

		while( SQL_MoreResults( query )){
			membroGuild[0] = '^0'
			memberkey[0] = '^0'
			memberpoints[0] = '^0'
			
			SQL_ReadResult(query, SQL_FieldNameToNum(query, "NICK"), membroGuild, sizeof(membroGuild) - 1)
			SQL_ReadResult(query, SQL_FieldNameToNum(query, "MEMBRO_KEY"), memberkey, sizeof(memberkey) - 1)
			SQL_ReadResult(query, SQL_FieldNameToNum(query, "PONTOS_GUILD"), memberpoints, sizeof(memberpoints) - 1)
			
			member_points = str_to_num(memberpoints)
			total_points += member_points
			total_guild++
			
			if( total_guild == 1 )
				len += format(motd[len], sizeof(motd) - len - 1, "[%i] NICK: <b>%s</b> || KEY: <b>%s</b> || Pontos: <b>%i</b>  <b>(MASTER)</b><br>", total_guild, membroGuild, memberkey, member_points)
	
			else len += format(motd[len], sizeof(motd) - len - 1, "[%i] NICK: <b>%s</b> || KEY: <b>%s</b> || Pontos: <b>%i</b><br>", total_guild, membroGuild, memberkey, member_points)

			SQL_NextRow( query );
		}
	}

	SQL_FreeHandle(query)
	close_mysql()
	
	len += format(motd[len], sizeof(motd) - len - 1,	"<br>")
	len += format(motd[len], sizeof(motd) - len - 1,	"Total de Pontos da Guild: <b>%i</b></font>", total_points)
	
	new iTemp[ 128 ]
	formatex( iTemp, charsmax( iTemp ), "%s Guilds", xPrefix );
	show_motd(paraquem, motd, iTemp );
	
	return PLUGIN_HANDLED;
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1046\\ f0\\ fs16 \n\\ par }
*/
