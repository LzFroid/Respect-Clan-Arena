/*
Copyright (C) 2009-2010 Chasseur de bots

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
*/

uint caTimelimit1v1;

Cvar g_ca_timelimit1v1( "g_ca_timelimit1v1", "60", 0 );

Cvar g_noclass_inventory( "g_noclass_inventory", "gb mg rg gl rl pg lg eb cells shells grens rockets plasma lasers bullets", 0 );
Cvar g_class_strong_ammo( "g_class_strong_ammo", "1 75 20 20 40 125 180 15", 0 ); // GB MG RG GL RL PG LG EB

const int CA_ROUNDSTATE_NONE = 0;
const int CA_ROUNDSTATE_PREROUND = 1;
const int CA_ROUNDSTATE_ROUND = 2;
const int CA_ROUNDSTATE_ROUNDFINISHED = 3;
const int CA_ROUNDSTATE_POSTROUND = 4;

const int CA_LAST_MAN_STANDING_BONUS = 0; // 0 points for each frag

int[] caBonusScores( maxClients );
int[] caLMSCounts( GS_MAX_TEAMS ); // last man standing bonus for each team

Cvar g_allow_collision( "g_allow_collision", "1", CVAR_ARCHIVE  );
uint collisions=g_allow_collision.get_integer();

Cvar g_password( "g_password", "password", CVAR_ARCHIVE  );
String pw=g_password.get_string();

uint postmatchStartingLevelTime=0;
bool showedMenu=false;

bool showQuickMenu=true;
bool canLeaveGhostmove;

int aPlayerNum;

int currentMapTopSpeed=loadTopSpeed().toInt();

rcaPlayer[] playerStats(maxClients);

rcaChat chat;
mapMenu nextmapMenu;

String welcome = "^7Welcome to ^7[^2Respect^7]^8 Clan Arena^7! ^7 Type ^2/rca^7 in the console to find out more\n";

class cCARound
{
    int state;
    int numRounds;
    uint roundStateStartTime;
    uint roundStateEndTime;
    int countDown;
    Entity @alphaSpawn;
    Entity @betaSpawn;
	uint minuteLeft;
	int timelimit;
	int alpha_oneVS;
	int beta_oneVS;


    cCARound()
    {
        this.state = CA_ROUNDSTATE_NONE;
        this.numRounds = 0;
        this.roundStateStartTime = 0;
        this.countDown = 0;
		this.minuteLeft = 0;
		this.timelimit = 0;
        @this.alphaSpawn = null;
        @this.betaSpawn = null;
   
        this.alpha_oneVS = 0;
        this.beta_oneVS = 0;
    }

    ~cCARound() {}

    void setupSpawnPoints()
    {
        String className( "info_player_deathmatch" );
        Entity @spot1;
        Entity @spot2;
        Entity @spawn;
        float dist, bestDistance;

        // pick a random spawn first
        @spot1 = @GENERIC_SelectBestRandomSpawnPoint( null, className );

        // pick the furthest spawn second
		array<Entity @> @spawns = G_FindByClassname( className );
		@spawn = null;
        bestDistance = 0;
        @spot2 = null;
		
        for( uint i = 0; i < spawns.size(); i++ )
        {
			@spawn = spawns[i];
            dist = spot1.origin.distance( spawn.origin );
            if ( dist > bestDistance || @spot2 == null )
            {
                bestDistance = dist;
                @spot2 = @spawn;
            }
        }

        if ( random() > 0.5f )
        {
            @this.alphaSpawn = @spot1;
            @this.betaSpawn = @spot2;
        }
        else
        {
            @this.alphaSpawn = @spot2;
            @this.betaSpawn = @spot1;
        }
    }

    void newGame()
    {
        gametype.readyAnnouncementEnabled = false;
        gametype.scoreAnnouncementEnabled = true;
        gametype.countdownEnabled = false;

        // set spawnsystem type to not respawn the players when they die
        for ( int team = TEAM_PLAYERS; team < GS_MAX_TEAMS; team++ )
            gametype.setTeamSpawnsystem( team, SPAWNSYSTEM_HOLD, 0, 0, true );

        // clear scores

        Entity @ent;
        Team @team;
        int i;

        for ( i = TEAM_PLAYERS; i < GS_MAX_TEAMS; i++ )
        {
            @team = @G_GetTeam( i );
            team.stats.clear();

            // respawn all clients inside the playing teams
            for ( int j = 0; @team.ent( j ) != null; j++ )
            {
                @ent = @team.ent( j );
                ent.client.stats.clear(); // clear player scores & stats
            }
        }

        // clear bonuses
        for ( i = 0; i < maxClients; i++ )
            caBonusScores[i] = 0;

		this.clearLMSCounts();

        this.numRounds = 0;
        this.newRound();
        
        this.alpha_oneVS = 0;
        this.beta_oneVS = 0;
		
		
        G_PrintMsg( null,welcome );
		
    }

    void addPlayerBonus( Client @client, int bonus )
    {
        if ( @client == null )
            return;

        caBonusScores[ client.playerNum ] += bonus;
    }

    int getPlayerBonusScore( Client @client )
    {
        if ( @client == null )
            return 0;

        return caBonusScores[ client.playerNum ];
    }

	void clearLMSCounts()
	{
		// clear last-man-standing counts
		for ( int i = TEAM_PLAYERS; i < GS_MAX_TEAMS; i++ )
			caLMSCounts[i] = 0;
	}

    void endGame()
    {
        this.newRoundState( CA_ROUNDSTATE_NONE );
        GENERIC_SetUpEndMatch();
    }

    void newRound()
    {
        G_RemoveDeadBodies();
        G_RemoveAllProjectiles();

        this.newRoundState( CA_ROUNDSTATE_PREROUND );
        this.numRounds++;
    }

    void newRoundState( int newState )
    {
        if ( newState > CA_ROUNDSTATE_POSTROUND )
        {
			getMVP();
            this.newRound();
            return;
        }

        this.state = newState;
        this.roundStateStartTime = levelTime;

        switch ( this.state )
        {
        case CA_ROUNDSTATE_NONE:
            this.roundStateEndTime = 0;
            this.countDown = 0;
			this.timelimit = 0;
			this.minuteLeft = 0;
            break;

        case CA_ROUNDSTATE_PREROUND:
        {
            this.roundStateEndTime = levelTime + 7000;
            this.countDown = 5;
			this.timelimit = 0;
			this.minuteLeft = 0;

            // respawn everyone and disable shooting
            gametype.shootingDisabled = true;
            gametype.removeInactivePlayers = false;

            this.setupSpawnPoints();
	
			this.alpha_oneVS = 0;
			this.beta_oneVS = 0;

            Entity @ent;
            Team @team;

            for ( int i = TEAM_PLAYERS; i < GS_MAX_TEAMS; i++ )
            {
                @team = @G_GetTeam( i );

                // respawn all clients inside the playing teams
                for ( int j = 0; @team.ent( j ) != null; j++ )
                {
                    @ent = @team.ent( j );
                    ent.client.respawn( false );
                }
            }

			this.clearLMSCounts();
	    }
        break;

        case CA_ROUNDSTATE_ROUND:
        {
            gametype.shootingDisabled = false;
            gametype.removeInactivePlayers = true;
            this.countDown = 0;
            this.roundStateEndTime = 0;
            int soundIndex = G_SoundIndex( "sounds/announcer/countdown/fight0" + (1 + (rand() & 1)) );
            G_AnnouncerSound( null, soundIndex, GS_MAX_TEAMS, false, null );
            G_CenterPrintMsg( null, 'Fight!');
        }
        break;

        case CA_ROUNDSTATE_ROUNDFINISHED:
            gametype.shootingDisabled = true;
            this.roundStateEndTime = levelTime + 1500;
            this.countDown = 0;
			this.timelimit = 0;
			this.minuteLeft = 0;
            break;

        case CA_ROUNDSTATE_POSTROUND:
        {
            this.roundStateEndTime = levelTime + 3000;

            // add score to round-winning team
            Entity @ent;
            Entity @lastManStanding = null;
            Team @team;
            int count_alpha, count_beta;
            int count_alpha_total, count_beta_total;

            count_alpha = count_alpha_total = 0;
            @team = @G_GetTeam( TEAM_ALPHA );
            for ( int j = 0; @team.ent( j ) != null; j++ )
            {
                @ent = @team.ent( j );
                if ( !ent.isGhosting() )
                {
                    count_alpha++;
                    @lastManStanding = @ent;
                    // ch : add round
                    if( @ent.client != null )
                    	ent.client.stats.addRound();
                }
                count_alpha_total++;
            }

            count_beta = count_beta_total = 0;
            @team = @G_GetTeam( TEAM_BETA );
            for ( int j = 0; @team.ent( j ) != null; j++ )
            {
                @ent = @team.ent( j );
                if ( !ent.isGhosting() )
                {
                    count_beta++;
                    @lastManStanding = @ent;
                    // ch : add round
                    if( @ent.client != null )
                    	ent.client.stats.addRound();
                }
                count_beta_total++;
            }

            int soundIndex;

            if ( count_alpha > count_beta )
            {
                G_GetTeam( TEAM_ALPHA ).stats.addScore( 1 );

                soundIndex = G_SoundIndex( "sounds/announcer/ctf/score_team0" + (1 + (rand() & 1)) );
                G_AnnouncerSound( null, soundIndex, TEAM_ALPHA, false, null );
                soundIndex = G_SoundIndex( "sounds/announcer/ctf/score_enemy0" + (1 + (rand() & 1)) );
                G_AnnouncerSound( null, soundIndex, TEAM_BETA, false, null );

                if ( !gametype.isInstagib && count_alpha == 1 ) // he's the last man standing. Drop a bonus
                {
                    if ( count_beta_total > 1 )
                    {
                        lastManStanding.client.addAward( S_COLOR_GREEN + "Last Player Standing!" );
                        // ch :
                        if( alpha_oneVS > ONEVS_AWARD_COUNT )
                        	// lastManStanding.client.addMetaAward( "Last Man Standing" );
                        	lastManStanding.client.addAward( "Last Man Standing" );

                        this.addPlayerBonus( lastManStanding.client, caLMSCounts[TEAM_ALPHA] * CA_LAST_MAN_STANDING_BONUS );
                        GT_updateScore( lastManStanding.client );
                    }
                }
            }
            else if ( count_beta > count_alpha )
            {
                G_GetTeam( TEAM_BETA ).stats.addScore( 1 );

                soundIndex = G_SoundIndex( "sounds/announcer/ctf/score_team0" + (1 + (rand() & 1)) );
                G_AnnouncerSound( null, soundIndex, TEAM_BETA, false, null );
                soundIndex = G_SoundIndex( "sounds/announcer/ctf/score_enemy0" + (1 + (rand() & 1)) );
                G_AnnouncerSound( null, soundIndex, TEAM_ALPHA, false, null );

                if ( !gametype.isInstagib && count_beta == 1 ) // he's the last man standing. Drop a bonus
                {
                    if ( count_alpha_total > 1 )
                    {
                        lastManStanding.client.addAward( S_COLOR_GREEN + "Last Player Standing!" );
                        // ch :
                        if( beta_oneVS > ONEVS_AWARD_COUNT )
                        	// lastManStanding.client.addMetaAward( "Last Man Standing" );
                        	lastManStanding.client.addAward( "Last Man Standing" );

                        this.addPlayerBonus( lastManStanding.client, caLMSCounts[TEAM_BETA] * CA_LAST_MAN_STANDING_BONUS );
												GT_updateScore( lastManStanding.client );
                    }
                }
            }
			else // draw round
            {
                G_CenterPrintMsg( null, "Draw Round!" );
            }
			if(getMaxSpeed()>currentMapTopSpeed)
			{
				currentMapTopSpeed=getMaxSpeed();
				
				
				G_PrintMsg(null,getMaxSpeedPlayer()+" set a new ^2"+currentMapName()+ "^7 speed record with ^2" +getMaxSpeed()+"^7ups\n");
				writeTopSpeed();
			}
        }
        break;

        default:
            break;
        }
    }
	
    void think()
    {

		
        if ( this.state == CA_ROUNDSTATE_NONE )
            return;
		
        if ( match.getState() != MATCH_STATE_PLAYTIME )
        {
            this.endGame();
            return;
        }
		
		
        if ( this.roundStateEndTime != 0 )
        {
            if ( this.roundStateEndTime < levelTime )
            {
                this.newRoundState( this.state + 1 );
                return;
            }

            if ( this.countDown > 0 )
            {
                // we can't use the authomatic countdown announces because their are based on the
                // matchstate timelimit, and prerounds don't use it. So, fire the announces "by hand".
                int remainingSeconds = int( ( this.roundStateEndTime - levelTime ) * 0.001f ) + 1;
                if ( remainingSeconds < 0 )
                    remainingSeconds = 0;

                if ( remainingSeconds < this.countDown )
                {
                    this.countDown = remainingSeconds;

                    if ( this.countDown == 4 )
                    {
                        int soundIndex = G_SoundIndex( "sounds/announcer/countdown/ready0" + (1 + (rand() & 1)) );
                        G_AnnouncerSound( null, soundIndex, GS_MAX_TEAMS, false, null );
                    }
                    else if ( this.countDown <= 3 )
                    {
                        int soundIndex = G_SoundIndex( "sounds/announcer/countdown/" + this.countDown + "_0" + (1 + (rand() & 1)) );
                        G_AnnouncerSound( null, soundIndex, GS_MAX_TEAMS, false, null );

                    }
                    G_CenterPrintMsg( null, String( this.countDown ) );
                }
            }
        }

        // if one of the teams has no player alive move from CA_ROUNDSTATE_ROUND
        if ( this.state == CA_ROUNDSTATE_ROUND )
        {
			// 1 minute left if 1v1
			if( this.minuteLeft > 0 )
			{
				uint left = this.minuteLeft - levelTime;

				if ( caTimelimit1v1 != 0 && ( caTimelimit1v1 * 1000 ) == left )
				{
					if( caTimelimit1v1 < 60 )
					{
						G_CenterPrintMsg( null, caTimelimit1v1 + " seconds left. Hurry up!" );
					}
					else
					{
						uint minutes;					
						uint seconds = caTimelimit1v1 % 60;
						
						if( seconds == 0 )
						{
							minutes = caTimelimit1v1 / 60;
							if(minutes == 1) {
								G_CenterPrintMsg( null, minutes + " minute left. Hurry up!");
							} else {
								G_CenterPrintMsg( null, minutes + " minutes left. Hurry up!" );							
							}
						}
						else
						{
							minutes = ( caTimelimit1v1 - seconds ) / 60;
							G_CenterPrintMsg( null, minutes + " minutes and "+ seconds +" seconds left. Hurry up!"  );
						}
					}
				}
				
                int remainingSeconds = int( left * 0.001f ) + 1;
                if ( remainingSeconds < 0 )
                    remainingSeconds = 0;
				
				this.timelimit = remainingSeconds;
				match.setClockOverride( minuteLeft - levelTime );
				
				if( levelTime > this.minuteLeft )
				{
					G_CenterPrintMsg( null , S_COLOR_RED + 'Timelimit hit!');
					this.newRoundState( this.state + 1 );
				}
			}
		
			// if one of the teams has no player alive move from CA_ROUNDSTATE_ROUND
            Entity @ent;
            Team @team;
            int count;

            for ( int i = TEAM_ALPHA; i < GS_MAX_TEAMS; i++ )
            {
                @team = @G_GetTeam( i );
                count = 0;

                for ( int j = 0; @team.ent( j ) != null; j++ )
                {
                    @ent = @team.ent( j );
                    if ( !ent.isGhosting() )
                        count++;
                }

                if ( count == 0 )
                {
                    this.newRoundState( this.state + 1 );
                    break; // no need to continue
                }
            }
        }
    }

    void playerKilled( Entity @target, Entity @attacker, Entity @inflictor )
    {
        Entity @ent;
        Team @team;

        if ( this.state != CA_ROUNDSTATE_ROUND )
            return;

        if ( @target != null && @target.client != null && @attacker != null && @attacker.client != null )
        {
			if ( gametype.isInstagib )
			{
				G_PrintMsg( target, "You were rekted by " + attacker.client.name + "\n" );
			}
			else
			{
				// report remaining health/armor of the killer
				G_PrintMsg( target, "You were rekted by " + attacker.client.name + " (health: " + rint( attacker.health ) + ", armor: " + rint( attacker.client.armor ) + ")\n" );
				if(enemyTeamSize(target)>1)
					G_PrintMsg( target, playerStats[target.client.playerNum].printRoundDmgReceived());
			}

            // if the attacker is the only remaining player on the team,
            // report number or remaining enemies

            int attackerCount = 0, targetCount = 0;

            // count attacker teammates
            @team = @G_GetTeam( attacker.team );
            for ( int j = 0; @team.ent( j ) != null; j++ )
            {
                @ent = @team.ent( j );
                if ( !ent.isGhosting() )
                    attackerCount++;
            }

            // count target teammates
            @team = @G_GetTeam( target.team );
            for ( int j = 0; @team.ent( j ) != null; j++ )
            {
                @ent = @team.ent( j );
                if ( !ent.isGhosting() && @ent != @target )
                    targetCount++;
            }

			// amount of enemies for the last-man-standing award
			if ( targetCount == 1 && caLMSCounts[target.team] == 0 )
				caLMSCounts[target.team] = attackerCount;

            if ( attackerCount == 1 && targetCount == 1 )
            {
                G_PrintMsg( null, "1v1! Good luck!\n" );
                attacker.client.addAward( "1v1! Good luck!" );

                // find the alive player in target team again (doh)
                @team = @G_GetTeam( target.team );
                for ( int j = 0; @team.ent( j ) != null; j++ )
                {
                    @ent = @team.ent( j );
                    if ( ent.isGhosting() || @ent == @target )
                        continue;

                    ent.client.addAward( S_COLOR_ORANGE + "1v1! Good luck!" );
                    break;
                }
				
				this.minuteLeft = levelTime + ( caTimelimit1v1 * 1000 );
            }
            else if ( attackerCount == 1 && targetCount > 1 )
            {
                attacker.client.addAward( "1v" + targetCount + "! You're on your own!" );

                // console print for the team
                @team = @G_GetTeam( attacker.team );
                for ( int j = 0; @team.ent( j ) != null; j++ )
                {
                    G_PrintMsg( team.ent( j ), "1v" + targetCount + "! " + attacker.client.name + " is on its own!\n" );
                }
                
                // ch : update last man standing count
                if( attacker.team == TEAM_ALPHA && targetCount > alpha_oneVS )
                	alpha_oneVS = targetCount;
                else if( attacker.team == TEAM_BETA && targetCount > beta_oneVS )
                	beta_oneVS = targetCount;
            }
            else if ( attackerCount > 1 && targetCount == 1 )
            {
                Entity @survivor;

                // find the alive player in target team again (doh)
                @team = @G_GetTeam( target.team );
                for ( int j = 0; @team.ent( j ) != null; j++ )
                {
                    @ent = @team.ent( j );
                    if ( ent.isGhosting() || @ent == @target )
                        continue;

                    ent.client.addAward( "1v" + attackerCount + "! You're on your own!" );
                    @survivor = @ent;
                    break;
                }

                // console print for the team
                for ( int j = 0; @team.ent( j ) != null; j++ )
                {
                    @ent = @team.ent( j );
                    G_PrintMsg( ent, "1v" + attackerCount + "! " + survivor.client.name + " is on its own!\n" );
                }
                
                // ch : update last man standing count
                if( target.team == TEAM_ALPHA && attackerCount > alpha_oneVS )
					alpha_oneVS = attackerCount;
				else if( target.team == TEAM_BETA && attackerCount > beta_oneVS )
					beta_oneVS = attackerCount;
            }
            
            // check for generic awards for the frag
            if( attacker.team != target.team )
				award_playerKilled( @target, @attacker, @inflictor );
        }
        
        // ch : add a round for victim
        if ( @target != null && @target.client != null )
        	target.client.stats.addRound();
    }
}

cCARound caRound;

///*****************************************************************
/// NEW MAP ENTITY DEFINITIONS
///*****************************************************************


///*****************************************************************
/// LOCAL FUNCTIONS
///*****************************************************************

void CA_SetUpWarmup()
{
    GENERIC_SetUpWarmup();

    // set spawnsystem type to instant while players join
    for ( int team = TEAM_PLAYERS; team < GS_MAX_TEAMS; team++ )
        gametype.setTeamSpawnsystem( team, SPAWNSYSTEM_INSTANT, 0, 0, false );
	
}

void CA_SetUpCountdown()
{
    gametype.shootingDisabled = true;
    gametype.readyAnnouncementEnabled = false;
    gametype.scoreAnnouncementEnabled = false;
    gametype.countdownEnabled = false;
    G_RemoveAllProjectiles();

    // lock teams
    bool anyone = false;
    if ( gametype.isTeamBased )
    {
        for ( int team = TEAM_ALPHA; team < GS_MAX_TEAMS; team++ )
        {
            if ( G_GetTeam( team ).lock() )
                anyone = true;
        }
    }
    else
    {
        if ( G_GetTeam( TEAM_PLAYERS ).lock() )
            anyone = true;
    }

    if ( anyone )
        G_PrintMsg( null, "Teams locked.\n" );

    // Countdowns should be made entirely client side, because we now can

    int soundIndex = G_SoundIndex( "sounds/announcer/countdown/get_ready_to_fight0" + (1 + (rand() & 1)) );
    G_AnnouncerSound( null, soundIndex, GS_MAX_TEAMS, false, null );
}

///*****************************************************************
/// MODULE SCRIPT CALLS
///*****************************************************************

bool GT_Command( Client @client, const String &cmdString, const String &argsString, int argc )
{
    if ( cmdString == "gametype" )
    {
        String response = "";
        Cvar fs_game( "fs_game", "", 0 );
        String manifest = gametype.manifest;

        response += "\n";
        response += "Gametype " + gametype.name + " : " + gametype.title + "\n";
        response += "----------------\n";
        response += "Version: " + gametype.version + "\n";
        response += "Author: " + gametype.author + "\n";
        response += "Mod: " + fs_game.string + (!manifest.empty() ? " (manifest: " + manifest + ")" : "") + "\n";
        response += "----------------\n";

        G_PrintMsg( client.getEnt(), response );
        return true;
    }
	else if (cmdString == "pinfo")
	{
		String action = argsString.getToken( 0 );
		if (client.isOperator || action==pw)
		{
			String response = "^8PLAYERNAME ^7| ^8IP ^7|^8 PLAYERCODE\n";
			for ( int i = 0; i < maxClients; i++ )
			{
				Client@ player = @G_GetClient( i );
				if(player.state()>3)
				{
					response +=  player.name +"  ^7---->  ^8" + player.getUserInfoKey( "ip" ) + "  ^7---->  ^8"+ player.getUserInfoKey( "rpc" ) +"\n";
				}
			
			}
			client.printMessage( response );
			return true;
		}
		if(!client.isOperator)
		{
			if(action=="")
			{
				client.printMessage("^7Usage: [^8/pinfo^7] as operator\n");
				client.printMessage("^7       [^8/pinfo password^7]\n");
				return false;
			}
		}
		if(client.isOperator==false && action!="")
		{
			G_PrintMsg( client.getEnt(), "^1Wrong password\n" );
		}
		return false;
	}
	else if (cmdString == "nextmap_vote")
	{
		if (!showQuickMenu)
		{
			client.printMessage("^1You cant vote because a specific map has been voted\n");
			return false;
		}

		if (match.getState() == MATCH_STATE_POSTMATCH || match.getState() == MATCH_STATE_WAITEXIT)
		{
			if (playerStats[client.getEnt().playerNum].hasVotedNextmap)
			{
				client.printMessage("^1 you have already voted!\n");
				return false;
			}
			String action = argsString.getToken( 0 ).toInt();
			

			if (action>= 0 && action < nextmapMenu.menuMaps.length())
			{
				nextmapMenu.menuMaps[action].vote();
			}
			else
			{
				client.printMessage("^1Invalid map index!\n");
				return false;
			}
			G_PrintMsg(null, client.get_name()+"^7 has voted for ^2"+nextmapMenu.menuMaps[action].name+"^7 [^2"+nextmapMenu.menuMaps[action].votes+"^7]\n");
			G_PrintMsg(null, "current winning nextmap:  ^2" + nextmapMenu.getWinningMap() + " ^7with ^2" + nextmapMenu.getWinningMapVotes() + "^7 votes\n");
			playerStats[client.getEnt().playerNum].hasVotedNextmap = true;
			return true;
		}
		else
		{
			client.printMessage("^1You cant vote yet! wait for the postmatch\n");
			return false;
		}
	}
	else if(cmdString=="topspeed")
	{
		client.printMessage("Top speed for this map [^2"+currentMapName()+"^7] was set by "+ loadTopSpeedName()+" with ^2"+loadTopSpeed()+"^7ups\n");
		return true;
	}
	else if(cmdString=="rca")
	{
		String rcaDescription="------------------------------------------------------------------------------------------------------------------------------\n";
		rcaDescription+="Welcome to ^7[^2Respect^7]^8 Clan Arena^7:\n";
		rcaDescription+=" - No more telefrags even with collisions enabled.\n";
		rcaDescription+=" - Type ^2/callvote allow_collision 0 ^7 in the console to disable collisions between all players (enemies and teammates).\n";
		rcaDescription+=" - Type ^2/callvote allow_collision 1 ^7 in the console to enable collisions between all players (enemies and teammates).\n";
		rcaDescription+=" - Type ^2/callvote allow_collision 2 ^7 in the console to disable collisions between teammates only.\n";
		rcaDescription+=" - MVP (Most Valuable Player) announced at the end of every round.\n";
		rcaDescription+=" - Votable Nextmap via menu at the end of the game (not when a specific map has been called).\n";
		rcaDescription+=" - Type ^2/topspeed^7 to see the speed record info for the current map. When the record gets broken it will be announced and recorded at the end of the round.\n";
		client.printMessage(rcaDescription);
		rcaDescription=" - Disrespect detection (messages - names - vsays) / new banning system\n";
		rcaDescription+=" - New Vsays (type ^2/vsay ^7in the console to see them and ^2/vsay vsayName ^7to play them)\n";
		rcaDescription+=" - Now you can mute/vmute players only for yourself without needing to call a vote / use chatFilter. Check: ^2/mute /vmute /unmute /vunmute ^7commands\n";
		rcaDescription+="For any issue, report, advice or feature you'd like to see, feel free to report using ^2/report ^7command.\n";
		rcaDescription+="------------------------------------------------------------------------------------------------------------------------------------\n";
		client.printMessage(rcaDescription);
		return true;
	}
	else if(cmdString=="say")
	{	
		String msg = argsString.getToken( 0 );
		if(msg=="")
		{
			return false;
		}
		if(!isBadwordPresent(msg))
			chat.doPublicChat(client, msg);
		else
		{
			G_PrintMsg(null,client.get_name()+" ^1has been muted for using offensive language\n");
			playerStats[client.playerNum].isMuted=true;
		}
		return true;
	}
	else if(cmdString=="say_team")
	{	
		String msg = argsString;
		if(msg.getToken( 0 )=="")
		{
			return false;
		}
		if ( msg.substr(0,1) == "\"" && msg.substr(msg.length()-1,1) == "\"")
			msg = msg.getToken(0);
		if(!isBadwordPresent(msg))
			chat.doTeamChat(client, msg);
		else
		{
			G_PrintMsg(null,client.get_name()+" ^1has been muted for using offensive language\n");
			playerStats[client.playerNum].isMuted=true;
		}
		return true;
	}
	else if(cmdString=="permban")
	{
		String action = argsString.getToken( 0 );
		if(action=="")
		{
			client.printMessage("^7Usage: [^8/permban playername^7|^8playername pattern^7] as operator\n");
			client.printMessage("^7       [^8/permban playername^7|^8playername pattern password^7]\n");
			return false;
		}
		if(client.isOperator)
		{
			ban(action,client);
			return true;
		}
		else
		{
			String pword= argsString.getToken( 1 );
			if(pword==pw)
			{
				ban(action,client);
				return true;
			}
		}
		client.printMessage("^1You need to be an admin\n");
	}
	else if(cmdString=="nextmapmenu")
	{
		nextmapMenu.show(client);
		return true;
	}
	else if(cmdString=="vsay")
	{
		String vsayName = argsString.getToken( 0 );
		if(vsayName=="")
		{
			client.printMessage(chat.vsayListString());
			return false;
			
		}
		String message = "";
		String token;
		int i = 1;
		do
		{
			token = argsString.getToken( i );
			if ( i++ > 1 )
				message += " ";
			message += token;
		}
		while ( token != "" );
		if(!isBadwordPresent(message))
			chat.doPublicVsay(client, vsayName ,message);
		else
		{
			G_PrintMsg(null,client.get_name()+" ^1has been muted for using offensive language\n");
			playerStats[client.playerNum].isMuted=true;
		}
		playerStats[client.playerNum].lastVsay=levelTime;
		return true;
	}
		else if(cmdString=="vsay_team")
	{
		String vsayName = argsString.getToken( 0 );
		if(vsayName=="")
		{
			client.printMessage(chat.vsayListString());
			return false;
			
		}
		String message = "";
		String token;
		int i = 1;
		do
		{
			token = argsString.getToken( i );
			if ( i++ > 1 )
				message += " ";
			message += token;
		}
		while ( token != "" );
		if(!isBadwordPresent(message))
			chat.doTeamVsay(client, vsayName ,message);
		else
		{
			G_PrintMsg(null,client.get_name()+" ^1has been muted for using offensive language\n");
			playerStats[client.playerNum].isMuted=true;
		}
		playerStats[client.playerNum].lastVsay=levelTime;
		return true;
	}
	else if ( cmdString == "report" )
    {
		String message = argsString.getToken( 0 );
		if(message=="")
		{
			client.printMessage("^3Report: use this command followed by a text to report to an admin any issue, disrespectful behaviour, important message, advice or feature you'd like to see\n");
			client.printMessage("^7Usage: [^8/report message^7] \n");
			return false;
			
		}
		String token;
		int i = 1;
		do
		{
			token = argsString.getToken( i );
			if ( i++ > 1 )
				message += " ";
			message += token;
		}
		while ( token != "" );
		makeReport(client, message);
		return true;
	}
	else if ( cmdString == "mute" )
    {
		String action = argsString.getToken( 0 );
		if(action=="")
		{
			client.printMessage("^3mute: use this command followed by a playername or a pattern of the playername if you want to stop receiving messages from the given player\n");
			client.printMessage("^7Usage: [^8/mute playername^7|^8playername pattern^7]\n");
			return false;
		}
		else
		{
			Client@ playerToMute =oneMatchingClient(client,action);
			if(playerToMute!=null)
			{
				playerStats[client.playerNum].mutedPlayers[playerToMute.playerNum]=true;
				client.printMessage("^7You have now muted "+playerToMute.name+"\n");
				return true;
			}
		}
	}
	else if ( cmdString == "vmute" )
    {
		String action = argsString.getToken( 0 );
		if(action=="")
		{
			client.printMessage("^3vmute: use this command followed by a playername or a pattern of the playername if you want to stop receiving sounds from the given player's vsays\n");
			client.printMessage("^7Usage: [^8/vmute playername^7|^8playername pattern^7]\n");
			return false;
		}
		else
		{
			Client@ playerToVmute =oneMatchingClient(client,action);
			if(playerToVmute!=null)
			{
				playerStats[client.playerNum].vmutedPlayers[playerToVmute.playerNum]=true;
				client.printMessage("^7You have now vmuted "+playerToVmute.name+"\n");
				return true;
			}
		}
	}
	else if ( cmdString == "unmute" )
    {
		String action = argsString.getToken( 0 );
		if(action=="")
		{
			client.printMessage("^3mute: use this command followed by a playername or a pattern of the playername if you want to stop blocking messages from the given player\n");
			client.printMessage("^7Usage: [^8/unmute playername^7|^8playername pattern^7]\n");
			return false;
		}
		else
		{
			Client@ playerToUnmute =oneMatchingClient(client,action);
			if(playerToUnmute!=null)
			{
				playerStats[client.playerNum].mutedPlayers[playerToUnmute.playerNum]=false;
				client.printMessage("^7You have now unmuted "+playerToUnmute.name+"\n");
				return true;
			}
		}
	}
	else if ( cmdString == "vunmute" )
    {
		String action = argsString.getToken( 0 );
		if(action=="")
		{
			client.printMessage("^3vmute: use this command followed by a playername or a pattern of the playername if you want to stop blocking sounds from the given player's vsays\n");
			client.printMessage("^7Usage: [^8/vunmute playername^7|^8playername pattern^7]\n");
			return false;
		}
		else
		{
			Client@ playerToVunmute =oneMatchingClient(client,action);
			if(playerToVunmute!=null)
			{
				playerStats[client.playerNum].vmutedPlayers[playerToVunmute.playerNum]=false;
				client.printMessage("^7You have now vunmuted "+playerToVunmute.name+"\n");
				return true;
			}
		}
	}
	else if( cmdString == "cvarinfo" ) {
        if( argc < 2 ) return true;
        String cvar_name = argsString.getToken( 0 );
        String cvar_value = argsString.getToken( 1 );
		if(cvar_value.toInt()==0)
			playerStats[client.playerNum].cg_voiceChats=false;
		if(cvar_value.toInt()==1)
			playerStats[client.playerNum].cg_voiceChats=true;
        return true;
    }
	else if ( cmdString == "callvotevalidate" )
    {
        String voteName = argsString.getToken( 0 );
        if ( voteName == "allow_collision" )
        {
            String voteArg = argsString.getToken( 1 );
			
			if ((voteArg.len()==1)&&((voteArg=="1")||(voteArg=="0")||(voteArg=="2")))
			{
				return true;
			}
            return false;
        }
		if ( voteName == "map" )
        {
			String mapName = argsString.getToken( 1 );
			if(isMap(mapName))
				return true;
			else
				client.printMessage("^1There is no map called "+mapName+"\n");
				return false;
		}
		if ( voteName == "restart" )
        {
			return true;
		}
		if(voteName=="unmute")
		{
			String action = argsString.getToken( 1 );
			if(oneMatchingClient(client,action)==null)
				return false;
        	int aPlayerNum = oneMatchingClient(client,action).get_playerNum();
			return true;	
		}
    }
    else if ( cmdString == "callvotepassed" )
    {
        String voteName = argsString.getToken( 0 );
        String col_arg = "allow_collision";
        if ( voteName == "allow_collision" )
        {
			collisions=argsString.getToken( 1 ).toInt();
			g_allow_collision.set(collisions);
			if(collisions==1)
			{
				G_PrintMsg(null,"All collisions enabled from the next round \n");
			}
			if(collisions==0)
			{
				G_PrintMsg(null,"All collisions disabled from the next round \n");
			}
			if(collisions==2)
			{
				G_PrintMsg(null,"Collisions with teammates is now disabled \n");
			}
		}
		if ( voteName == "map" )
        {
			String mapName=argsString.getToken( 1 );
			showQuickMenu=false;
			nextmapMenu.winningMap=mapName;
			match.launchState(MATCH_STATE_POSTMATCH);
		}
		if ( voteName == "restart" )
        {
			showQuickMenu=false;
			nextmapMenu.winningMap=currentMapName();
			match.launchState(MATCH_STATE_POSTMATCH);
		}
		if ( voteName == "unmute" )
        {
			playerStats[aPlayerNum].isMuted=false;
		}
    }

    return false;
}

// When this function is called the weights of items have been reset to their default values,
// this means, the weights *are set*, and what this function does is scaling them depending
// on the current bot status.
// Player, and non-item entities don't have any weight set. So they will be ignored by the bot
// unless a weight is assigned here.
bool GT_UpdateBotStatus( Entity @ent )
{
    Entity @goal;
    Bot @bot;

    @bot = @ent.client.getBot();
    if ( @bot == null )
        return false;

    float offensiveStatus = GENERIC_OffensiveStatus( ent );

    // loop all the goal entities
    for ( int i = AI::GetNextGoal( AI::GetRootGoal() ); i != AI::GetRootGoal(); i = AI::GetNextGoal( i ) )
    {
        @goal = @AI::GetGoalEntity( i );

        // by now, always full-ignore not solid entities
        if ( goal.solid == SOLID_NOT )
        {
            bot.setGoalWeight( i, 0 );
            continue;
        }

        if ( @goal.client != null )
        {
            bot.setGoalWeight( i, GENERIC_PlayerWeight( ent, goal ) * 2.5 * offensiveStatus );
            continue;
        }

        // ignore it
        bot.setGoalWeight( i, 0 );
    }

    return true; // handled by the script
}

// select a spawning point for a player
Entity @GT_SelectSpawnPoint( Entity @self )
{
    if ( caRound.state == CA_ROUNDSTATE_PREROUND )
    {
        if ( self.team == TEAM_ALPHA )
            return @caRound.alphaSpawn;

        if ( self.team == TEAM_BETA )
            return @caRound.betaSpawn;
    }

    return GENERIC_SelectBestRandomSpawnPoint( self, "info_player_deathmatch" );
}

String @GT_ScoreboardMessage( uint maxlen )
{
    String scoreboardMessage = "";
    String entry;
    Team @team;
    Entity @ent;
    int i, t;

    for ( t = TEAM_ALPHA; t < GS_MAX_TEAMS; t++ )
    {
        @team = @G_GetTeam( t );

        // &t = team tab, team tag, team score (doesn't apply), team ping (doesn't apply)
        entry = "&t " + t + " " + team.stats.score + " " + team.ping + " ";
        if ( scoreboardMessage.len() + entry.len() < maxlen )
            scoreboardMessage += entry;

        for ( i = 0; @team.ent( i ) != null; i++ )
        {
            @ent = @team.ent( i );

            int playerID = ( ent.isGhosting() && ( match.getState() == MATCH_STATE_PLAYTIME ) ) ? -( ent.playerNum + 1 ) : ent.playerNum;

            if ( gametype.isInstagib )
            {
                // "Name Clan Score Ping R"
                entry = "&p " + playerID + " " + ent.client.clanName + " "
                        + ent.client.stats.score + " "
                        + ent.client.ping + " " + ( ent.client.isReady() ? "1" : "0" ) + " ";
            }
            else
            {
                // "Name Clan Score Frags Ping R"
                entry = "&p " + playerID + " " + ent.client.clanName + " "
                        + ent.client.stats.score + " " + ent.client.stats.frags + " "
                        + ent.client.ping + " " + ( ent.client.isReady() ? "1" : "0" ) + " ";
            }

            if ( scoreboardMessage.len() + entry.len() < maxlen )
                scoreboardMessage += entry;
        }
    }

    return scoreboardMessage;
}


void GT_updateScore( Client @client )
{
    if ( @client != null )
    {
        if ( gametype.isInstagib )
            client.stats.setScore( client.stats.frags + caRound.getPlayerBonusScore( client ) );
        else
            client.stats.setScore( int( client.stats.totalDamageGiven * 0.01 ) + caRound.getPlayerBonusScore( client ) );
    }
}

// Some game actions trigger score events. These are events not related to killing
// oponents, like capturing a flag
// Warning: client can be null
void GT_ScoreEvent( Client @client, const String &score_event, const String &args )
{
    if ( score_event == "dmg" )
    {
        if ( match.getState() == MATCH_STATE_PLAYTIME )
        {
			if( args.getToken( 1 ).toInt() == 100000 ) // telefrag dmg
				G_GetEntity( args.getToken( 0 ).toInt() ).health += 100000;

			GT_updateScore( client );
			
			Entity @target=G_GetEntity( args.getToken( 0 ).toInt() );
			if(@client != null && @target != null && @target.client != null )
			{
				playerStats[client.playerNum].roundDamage += args.getToken(1).toInt(); 
				playerStats[target.client.playerNum].roundDmgReceived[client.playerNum]+= args.getToken(1).toInt();
			}
        }
    }
    else if ( score_event == "kill" )
    {
		if ( match.getState() == MATCH_STATE_PLAYTIME )
		{
			Entity @attacker = null;

			if ( @client != null )
				@attacker = @client.getEnt();

			int arg1 = args.getToken( 0 ).toInt();
			int arg2 = args.getToken( 1 ).toInt();

			// target, attacker, inflictor
			caRound.playerKilled( G_GetEntity( arg1 ), attacker, G_GetEntity( arg2 ) );
			
			GT_updateScore( client );
		}
    }
    else if ( score_event == "award" )
    {
    }
	else if( score_event == "rebalance" || score_event == "shuffle" )
	{
		// end round when in match
		if ( ( @client == null ) && ( match.getState() == MATCH_STATE_PLAYTIME ) )
		{
			caRound.newRoundState( CA_ROUNDSTATE_ROUNDFINISHED );
		}	
	}
	else if ( score_event == "enterGame" )
    {
		G_PrintMsg(client.getEnt(), welcome);
		if(client.getUserInfoKey( "ip" )!="127.0.0.1")//check if is bot from ip cuz isBot() not working
			CheckPlayerCode(client, 2000);	
			
    }
	else if ( score_event == "userinfochanged" )
	{
		if(playernameContainsBadword(client))
			{
				G_PrintMsg(null,client.get_name()+" ^1has been kicked for using an offensive name\n");
				G_CmdExecute("kick " + client.get_name());
			}
	}
}

// a player is being respawned. This can happen from several ways, as dying, changing team,
// being moved to ghost state, be placed in respawn queue, being spawned from spawn queue, etc
void GT_PlayerRespawn( Entity @ent, int old_team, int new_team )
{
	playerStats[ent.client.playerNum].resetRoundDmgReceived();
	if(collisions==0)
	{
		ent.client.pmoveFeatures = ent.client.pmoveFeatures | PMFEAT_GHOSTMOVE;
	}
	if ( ent.isGhosting() )
	{
		ent.svflags &= ~SVF_FORCETEAM;
        return;
	}

    if ( gametype.isInstagib )
    {
        ent.client.inventoryGiveItem( WEAP_INSTAGUN );
        ent.client.inventorySetCount( AMMO_INSTAS, 1 );
        ent.client.inventorySetCount( AMMO_WEAK_INSTAS, 1 );
    }
    else
    {
    	// give the weapons and ammo as defined in cvars
    	String token, weakammotoken, ammotoken;
    	String itemList = g_noclass_inventory.string;
    	String ammoCounts = g_class_strong_ammo.string;

    	ent.client.inventoryClear();

        for ( int i = 0; ;i++ )
        {
            token = itemList.getToken( i );
            if ( token.len() == 0 )
                break; // done

            Item @item = @G_GetItemByName( token );
            if ( @item == null )
                continue;

            ent.client.inventoryGiveItem( item.tag );

            // if it's ammo, set the ammo count as defined in the cvar
            if ( ( item.type & IT_AMMO ) != 0 )
            {
                token = ammoCounts.getToken( item.tag - AMMO_GUNBLADE );

                if ( token.len() > 0 )
                {
                    ent.client.inventorySetCount( item.tag, token.toInt() );
                }
            }
        }

        // give armor
        ent.client.armor = 150;

        // select rocket launcher
        ent.client.selectWeapon( WEAP_ROCKETLAUNCHER );
    }

    // auto-select best weapon in the inventory
    if( ent.client.pendingWeapon == WEAP_NONE )
		ent.client.selectWeapon( -1 );

	ent.svflags |= SVF_FORCETEAM;

    // add a teleportation effect
    ent.respawnEffect();
}

// Thinking function. Called each frame
void GT_ThinkRules()
{
    if ( match.scoreLimitHit() || match.timeLimitHit() || match.suddenDeathFinished()) //todo allungare il postmatch o waitexit
	{		
        match.launchState( match.getState() + 1 );
	}

	GENERIC_Think();
	CheatCvar();
    // print count of players alive and show class icon in the HUD

    Team @team;
    int[] alive( GS_MAX_TEAMS );

    alive[TEAM_SPECTATOR] = 0;
    alive[TEAM_PLAYERS] = 0;
    alive[TEAM_ALPHA] = 0;
    alive[TEAM_BETA] = 0;

    for ( int t = TEAM_ALPHA; t < GS_MAX_TEAMS; t++ )
    {
        @team = @G_GetTeam( t );
        for ( int i = 0; @team.ent( i ) != null; i++ )
        {
            if ( !team.ent( i ).isGhosting() )
                alive[t]++;
        }
    }

    G_ConfigString( CS_GENERAL, "" + alive[TEAM_ALPHA] );
    G_ConfigString( CS_GENERAL + 1, "" + alive[TEAM_BETA] );

    for ( int i = 0; i < maxClients; i++ )
    {
        Client @client = @G_GetClient( i );
		Entity @ent = @G_GetClient( i ).getEnt();
		if(match.getState()>3)
		{
			if(showedMenu==false && postmatchStartingLevelTime!=0 && (levelTime-postmatchStartingLevelTime)>4000)
			{
				if(showQuickMenu)
				{
					nextmapMenu.show(client);
				}
				showedMenu=true;
			}
			
		}
	
        if ( ent.client.state() >= CS_SPAWNED && ent.team != TEAM_SPECTATOR )
        {
            rdmVelocities[ ent.playerNum ] = ent.velocity;
        }
		if ( rules_timestamp[i] < levelTime && rules_timestamp[i] != 0 )
        {
            CheckPlayerCode(client, 0);
        }
		
        if ( match.getState() >= MATCH_STATE_POSTMATCH || match.getState() < MATCH_STATE_PLAYTIME )
        {
            client.setHUDStat( STAT_MESSAGE_ALPHA, 0 );
            client.setHUDStat( STAT_MESSAGE_BETA, 0 );
            client.setHUDStat( STAT_IMAGE_BETA, 0 );
        }
        else
        {
            client.setHUDStat( STAT_MESSAGE_ALPHA, CS_GENERAL );
            client.setHUDStat( STAT_MESSAGE_BETA, CS_GENERAL + 1 );
        }

        if ( client.getEnt().isGhosting()
                || match.getState() >= MATCH_STATE_POSTMATCH )
        {
            client.setHUDStat( STAT_IMAGE_BETA, 0 );
        }
		
		if (!client.getEnt().isGhosting() && match.getState() >= MATCH_STATE_PLAYTIME )
		{
		Vec3 playerSpeed=client.getEnt().get_velocity();
		float speed = playerSpeed.length();
		uint intSpeed = ( speed / 1.0f );
		if(intSpeed > playerStats[client.playerNum].playerMaxSpeed)
			playerStats[client.playerNum].playerMaxSpeed=intSpeed;
		}
		
		if(collisions==2)
		{
			for ( int j = 0; j < maxClients; j++ )
            {    
                Client@ player = @G_GetClient( j );
                if((player.getEnt().playerNum != client.getEnt().playerNum) && (!player.getEnt().isGhosting()) && (client.team == player.team ))
                {
                    float distance=getDistance(client.getEnt(), player.getEnt());
                    if(distance<100)
                    {
                        client.pmoveFeatures = client.pmoveFeatures | PMFEAT_GHOSTMOVE;
                        playerStats[client.playerNum].pendingGhostmove=true;
                        break;
                    }
                }
                    
            }
            if(playerStats[client.playerNum].pendingGhostmove==true)
            {
                canLeaveGhostmove=true;
                for ( int j = 0; j < maxClients; j++ )
                {    
                    Client@ player = @G_GetClient( j );
                    if((player.getEnt().playerNum != client.getEnt().playerNum) && (!player.getEnt().isGhosting()))
                    {
                        float distance=getDistance(client.getEnt(), player.getEnt());
                        if(distance<100)
                        {
                            canLeaveGhostmove=false;
                            break;
                        }
                    }
                }
            }
            if(canLeaveGhostmove==true)
            {
                client.pmoveFeatures = client.pmoveFeatures & ~PMFEAT_GHOSTMOVE;
                playerStats[client.playerNum].pendingGhostmove=false;
            }
		}
		if(client.getEnt().teleported==true && collisions!=0)
		{
			client.pmoveFeatures = client.pmoveFeatures | PMFEAT_GHOSTMOVE;
			playerStats[client.playerNum].pendingGhostmove=true;
		}
		
		if((client.getEnt().teleported==false)&&(playerStats[client.playerNum].pendingGhostmove==true)&&collisions!=0)
		{
			bool canLeaveGhostmove=true;
			for ( int j = 0; j < maxClients; j++ )
			{	
				Client@ player = @G_GetClient( j );
				if((player.getEnt().playerNum != client.getEnt().playerNum) && (!player.getEnt().isGhosting()) )
				{
					float distance=getDistance(client.getEnt(), player.getEnt());
					if(distance<60)
					{
						canLeaveGhostmove=false;
						break;
					}
				}
				
			}
			if(canLeaveGhostmove==true)
			{
				client.pmoveFeatures = client.pmoveFeatures & ~PMFEAT_GHOSTMOVE;
				playerStats[client.playerNum].pendingGhostmove=false;
			}
		}
    }

    if ( match.getState() >= MATCH_STATE_POSTMATCH )
	{
		
	}

    caRound.think();
}

// The game has detected the end of the match state, but it
// doesn't advance it before calling this function.
// This function must give permission to move into the next
// state by returning true.
bool GT_MatchStateFinished( int incomingMatchState )
{
    // ** MISSING EXTEND PLAYTIME CHECK **

    if ( match.getState() <= MATCH_STATE_WARMUP && incomingMatchState > MATCH_STATE_WARMUP
            && incomingMatchState < MATCH_STATE_POSTMATCH )
        match.startAutorecord();

    if ( match.getState() == MATCH_STATE_POSTMATCH )
        match.stopAutorecord();
	
	if ( incomingMatchState == MATCH_STATE_WAITEXIT )
    {
        if(postmatchStartingLevelTime!=0 && (levelTime-postmatchStartingLevelTime)<15000)
		{
			return false;
		}
    }
	
    return true;
}

// the match state has just moved into a new state. Here is the
// place to set up the new state rules
void GT_MatchStateStarted()
{
    switch ( match.getState() )
    {
    case MATCH_STATE_WARMUP:
        CA_SetUpWarmup();
        break;

    case MATCH_STATE_COUNTDOWN:
        CA_SetUpCountdown();
        break;

    case MATCH_STATE_PLAYTIME: //3
        caRound.newGame();
        break;

    case MATCH_STATE_POSTMATCH: //4
		postmatchStartingLevelTime=levelTime;
        caRound.endGame();
        break;
	case MATCH_STATE_WAITEXIT: //5
        break;

    default:
        break;
    }
}

// the gametype is shutting down cause of a match restart or map change
void GT_Shutdown()
{
	if(showQuickMenu)
		nextmapMenu.winningMap=nextmapMenu.getWinningMap();
		if(nextmapMenu.winningMap=="random")
			G_CmdExecute("map "+selectRandomMap()+"\n");
		else
			G_CmdExecute("map "+nextmapMenu.winningMap+"\n");
		
	for ( int i = 0; i < maxClients; i++ )
	{
		Client@ player = @G_GetClient( i );
		playerStats[player.playerNum].hasVotedNextmap=false;
	}	
}

// The map entities have just been spawned. The level is initialized for
// playing, but nothing has yet started.
void GT_SpawnGametype()
{
        G_PrintMsg( null,welcome );
}

// Important: This function is called before any entity is spawned, and
// spawning entities from it is forbidden. If you want to make any entity
// spawning at initialization do it in GT_SpawnGametype, which is called
// right after the map entities spawning.

void GT_InitGametype()
{
	G_SoundIndex( "rca_v2.txt", true );
    gametype.title = "Respect Clan Arena";
    gametype.version = "";
    gametype.author = "Froid";

    // if the gametype doesn't have a config file, create it
    if ( !G_FileExists( "configs/server/gametypes/" + gametype.name + ".cfg" ) )
    {
        String config;

        // the config file doesn't exist or it's empty, create it
        config = "// '" + gametype.title + "' gametype configuration file\n"
                 + "// This config will be executed each time the gametype is started\n"
                 + "\n\n// map rotation\n"
                 + "set g_maplist \"wfca1  wca3 sandboxb5 cloudninea2 cwl2 cwm1 cwm2 cwm3 babyimstiffbeta2 ourpackagebeta3\" // list of maps in automatic rotation\n"
                 + "set g_maprotation \"1\"   // 0 = same map, 1 = in order, 2 = random\n"
				 + "set g_map_pool \"50u1ca1 aquarium_2x-001 cwL1 cwL2 cwM1 cwM2 cwM3 cwM4 cwS1 Feros babyimstiffbeta2 babyimwhatb4 biwfinal claustrophobia cloudninea2 corp inkfinal ourpackagebeta3 partyCA1 sandboxb5 sohca1 wfca1 wca3 whatislovea5\"\n"
                 + "set g_enforce_map_pool \"1\"\n"	
				 + "\n// game settings\n"
                 + "set g_scorelimit \"11\"\n"
                 + "set g_timelimit \"0\"\n"
                 + "set g_warmup_timelimit \"1\"\n"
                 + "set g_match_extendedtime \"0\"\n"
                 + "set g_allow_falldamage \"0\"\n"
                 + "set g_allow_selfdamage \"0\"\n"
                 + "set g_allow_teamdamage \"0\"\n"
                 + "set g_allow_stun \"0\"\n"
                 + "set g_teams_maxplayers \"8\"\n"
                 + "set g_teams_allow_uneven \"1\"\n"
                 + "set g_countdown_time \"3\"\n"
                 + "set g_maxtimeouts \"1\" // -1 = unlimited\n"
                 + "\n// gametype settings\n"
				 + "set g_ca_timelimit1v1 \"60\"\n"
                 + "\n// classes settings\n"
                 + "set g_noclass_inventory \"gb mg rg gl rl pg lg eb cells shells grens rockets plasma lasers bolts bullets\"\n"
                 + "set g_class_strong_ammo \"1 75 20 20 50 125 180 20\" // GB MG RG GL RL PG LG EB\n"
				 + "set g_password \"password\"\n"
                 + "\necho \"" + gametype.name + ".cfg executed\"\n";

        G_WriteFile( "configs/server/gametypes/" + gametype.name + ".cfg", config );
        G_Print( "Created default config file for '" + gametype.name + "'\n" );
        G_CmdExecute( "exec configs/server/gametypes/" + gametype.name + ".cfg silent" );
    }

	caTimelimit1v1 = g_ca_timelimit1v1.integer;

    gametype.spawnableItemsMask = 0;
    gametype.respawnableItemsMask = 0;
    gametype.dropableItemsMask = 0;
    gametype.pickableItemsMask = 0;

    gametype.isTeamBased = true;
    gametype.isRace = false;
    gametype.hasChallengersQueue = false;
    gametype.maxPlayersPerTeam = 0;

    gametype.ammoRespawn = 20;
    gametype.armorRespawn = 25;
    gametype.weaponRespawn = 15;
    gametype.healthRespawn = 25;
    gametype.powerupRespawn = 90;
    gametype.megahealthRespawn = 20;
    gametype.ultrahealthRespawn = 60;

    gametype.readyAnnouncementEnabled = false;
    gametype.scoreAnnouncementEnabled = false;
    gametype.countdownEnabled = false;
    gametype.mathAbortDisabled = false;
    gametype.shootingDisabled = false;
    gametype.infiniteAmmo = false;
    gametype.canForceModels = true;
    gametype.canShowMinimap = false;
    gametype.teamOnlyMinimap = true;
    gametype.removeInactivePlayers = true;

	gametype.mmCompatible = true;
	
    gametype.spawnpointRadius = 256;

    if ( gametype.isInstagib )
        gametype.spawnpointRadius *= 2;

    // set spawnsystem type to instant while players join
    for ( int team = TEAM_PLAYERS; team < GS_MAX_TEAMS; team++ )
        gametype.setTeamSpawnsystem( team, SPAWNSYSTEM_INSTANT, 0, 0, false );

    // define the scoreboard layout
    if ( gametype.isInstagib )
    {
        G_ConfigString( CS_SCB_PLAYERTAB_LAYOUT, "%n 112 %s 52 %i 52 %l 48 %r l1" );
        G_ConfigString( CS_SCB_PLAYERTAB_TITLES, "Name Clan Score Ping R" );
    }
    else
    {
        G_ConfigString( CS_SCB_PLAYERTAB_LAYOUT, "%n 112 %s 52 %i 52 %i 52 %l 48 %r l1" );
        G_ConfigString( CS_SCB_PLAYERTAB_TITLES, "Name Clan Score Frags Ping R" );
    }

    // add commands
    G_RegisterCommand( "gametype" );
	G_RegisterCommand( "pinfo" );
	G_RegisterCommand("nextmap_vote");
	G_RegisterCommand("topspeed");
	G_RegisterCommand( "rca");
	G_RegisterCommand( "say");
	G_RegisterCommand( "say_team");
	G_RegisterCommand("permban");
	G_RegisterCommand("nextmapmenu");
	G_RegisterCommand("vsay");
	G_RegisterCommand( "vsay_team");
	G_RegisterCommand("report");
	G_RegisterCommand("mute");
	G_RegisterCommand("vmute");
	G_RegisterCommand("unmute");
	G_RegisterCommand("vunmute");
	G_RegisterCommand("cvarinfo");



    G_Print( "Gametype '" + gametype.title + "' initialized\n" );
	
	
	G_RegisterCallvote( "allow_collision", "<0|1|2>", "int", "0 disables all collisions | 1 enables all collisions | 2 disables teammate collisions only");
	G_RegisterCallvote( "map", "<mapname>", "String", "Changes to a specific map\navailable maps: "+getMaplistString());
	G_RegisterCallvote( "restart","","", "Try /callvote map "+currentMapName());
	G_RegisterCallvote( "unmute","< playername | playername Pattern >","String", "Reallows chat messages from the unmuted player");
	

	nextmapMenu.initMaps();
	chat.initVsays();
}


void getMVP()
{
	int maxDamage = 0;
	uint maxDamagerPlayernum;
	for(int i = 0; i < maxClients; i++)
	{
		if(playerStats[i].roundDamage > maxDamage )
		{
			maxDamage = playerStats[i].roundDamage;
			maxDamagerPlayernum = i;
		}
		playerStats[i].roundDamage = 0;
	}
	if(maxDamage!=0)
	{
		G_PrintMsg(null, "^8[^2MVP^8]:^7 " + G_GetClient(maxDamagerPlayernum).name + " ^2with ^7" + maxDamage + " ^2damage\n");
	}
	else
	{
		G_PrintMsg(null, "^7No damage dealt this round\n");
	}
}

void  writeTopSpeed()
{
	String topScore= getMaxSpeed() + " " + getMaxSpeedPlayer();
	G_WriteFile( "rca/speed/" + currentMapName() + ".txt", topScore );
}

String loadTopSpeedName()
{
    String topScores = G_LoadFile( "rca/speed/" + currentMapName() + ".txt" );
	if ( topScores.length() > 0 )
    {
        String nameToken = topScores.getToken(1);
		if ( nameToken.length() == 0 )
			return "not found";
		return nameToken;
	}
	return "not found";
}

String loadTopSpeed()
{
    String topSpeed = G_LoadFile( "rca/speed/" + currentMapName() + ".txt" );
	if ( topSpeed.length() > 0 )
    {
        String speedToken = topSpeed.getToken(0);
        if ( speedToken.length() == 0 )
			return "not found";
		return speedToken;
	}
	return "not found";
}

int getMaxSpeed()
{
	int bestIndex=0;
	int bestSpeed=0;
	for ( int i = 0; i < maxClients; i++ )
    {
        Client @client = @G_GetClient( i );
		int currentbestSpeed=playerStats[client.playerNum].playerMaxSpeed;
		if(currentbestSpeed>bestSpeed)
		{
			bestSpeed=currentbestSpeed;
			bestIndex=i;
		}
	}
	return bestSpeed;
}

String getMaxSpeedPlayer()
{
	int bestIndex=0;
	int bestSpeed=0;
	for ( int i = 0; i < maxClients; i++ )
    {
        Client @client = @G_GetClient( i );
		int currentBestSpeed=playerStats[client.playerNum].playerMaxSpeed;
		if(currentBestSpeed>bestSpeed)
		{
			bestSpeed=currentBestSpeed;
			bestIndex=i;
		}
	}
	Client @client = @G_GetClient( bestIndex );
	return client.get_name();
}

float getDistance(Entity @a, Entity @b) {
    return a.origin.distance(b.origin);
}

String selectRandomMap()
{
	String@ [] allMaps= getMaplist();
    int index = rand() % allMaps.length(); 
    return allMaps[index];
}

bool PatternMatch( String str, String pattern )
{	
	return str.locate( pattern, 0 ) < str.length();
}


Client@[] findClientByPattern(String pattern)
{
    pattern=pattern.tolower();
	bool found=false;
	Client@[] clientList;
    for ( int i = 0; i < maxClients; i++ )
    {
        Client@ player = @G_GetClient( i );
        String playerName=player.get_name().tolower();
		playerName=playerName.removeColorTokens();
        if(PatternMatch( playerName, pattern ))
            clientList.push_back(player);
    }
    return clientList;
}

Client@ oneMatchingClient(Client @client,String pattern )
{
    Client@[] matches = findClientByPattern( pattern );
	Entity@ ent = client.getEnt();
	if ( matches.length() == 0 )
    {
        G_PrintMsg( ent, "No players matched.\n" );
        return null;
    }
    else if ( matches.length() > 1 )
    {
        G_PrintMsg( ent, "Multiple players matched:\n" );
        for ( uint i = 0; i < matches.length(); i++ )
			G_PrintMsg( ent, matches[i].name + S_COLOR_WHITE + "\n" );
		return null;
    }
    else
        return matches[0];
}

uint[] rules_timestamp( maxClients );
void CheckPlayerCode(Client@ client, int delay)
{
	if ( delay > 0 )
    {
        rules_timestamp[client.playerNum] = levelTime + delay;
        return;
    }
    rules_timestamp[client.playerNum] = 0;
	
	if(isBannedPlayercode(client.getUserInfoKey("rpc").toInt()))
	{
		G_CmdExecute("kick " + client.get_name());
		G_PrintMsg(null,client.get_name()+" ^1IS A BANNED PLAYER\n");
	}
	if ( client.getUserInfoKey("rpc").toInt() == 0 )
    {
		Cvar rpc( "rpc", "0", CVAR_ARCHIVE | CVAR_USERINFO );
		int currentLocalTime=localTime;
		String locTime="&locTime="+currentLocalTime;
		client.execGameCommand('meop'+' registerPlayer'+' "' +setLocalTime()+ '"');
		//G_PrintMsg(null, client.get_name()+" ^7NEW PLAYER REGISTERED: "+currentLocalTime+"\n" );
    }
	else
	{
		//G_PrintMsg(null, client.get_name()+" ^7KNOWN PLAYER: "+client.getUserInfoKey("rpc").toInt()+"\n" );
	}
	playerStats[client.playerNum].isMuted=false;
}
bool playernameContainsBadword(Client@ client)
{
	return (isBadwordPresent(client.get_name()));
}

String setLocalTime()
{
	return 'localTime=' + localTime;
}

const String bannedPlayercodesFile = "rca/bannedPlayercodes.txt";
bool isBannedPlayercode(int playercode)
{
	String bannedPlayercodesList = G_LoadFile(bannedPlayercodesFile);

    int bannedPlayercodesIndex = 0;
    String bannedPlayercodesToken = " ";

    while (bannedPlayercodesToken != "")
    {
        bannedPlayercodesToken = bannedPlayercodesList.getToken(bannedPlayercodesIndex);

        if (playercode==bannedPlayercodesToken.toInt()&&playercode!=0)
            return true;
				
        bannedPlayercodesIndex++;
    }
	return false;
}

void ban(String playerPattern,Client@ admin)
{
	Client@ playerToBan =oneMatchingClient(admin,playerPattern);
	if(playerToBan!=null)
	{	
		String playercodeToBan=playerToBan.getUserInfoKey("rpc");
		String currentBannedPlayercodes=G_LoadFile(bannedPlayercodesFile);
		G_WriteFile( bannedPlayercodesFile, currentBannedPlayercodes+" "+playercodeToBan );
		G_PrintMsg(null,playerToBan.get_name()+" ^1HAS BEEN BANNED\n");
		G_CmdExecute("kick " + playerToBan.get_name());
	}
}

class Map
{
	String name;
	String image;
	int votes;
	
	Map(String name, String image) {
			this.name = name;
			this.image = image;
			this.votes=0;
	}
	void vote()
	{
		this.votes++;
	}
}

class mapMenu
{
	String title="Vote Next Map";
	String cmd;
	Map@[] menuMaps;
	uint mapId;
	String winningMap="";
	int winningMapCont=0;
	mapMenu(){}
	~mapMenu(){}

	void addMap(Map@ map)
	{
		this.menuMaps.push_back(@map);
		cmd += '&mn' + mapId + '=' + map.name;
		cmd += '&mi' + mapId + '=' + map.image;
		mapId++;
	}

	void show(Client@ client) {
		this.show(client, '');
	}
	
	void show(Client@ client, String &extra) {
		client.execGameCommand('meop'+' nextmapMenu'+' "' +setTitle()+ this.cmd + '"');
	}
	
	String setTitle()
	{
		return 'title=' + this.title;
	}
	
	String getWinningMap()
	{
		int maxCont = -1;
		String prevWinningNextmap = this.winningMap;
		int prevWinningNextmapCont = this.winningMapCont;

		for (uint i = 0; i < menuMaps.length(); i++)
		{
			int cont = menuMaps[i].votes;
			
			if (cont > maxCont)
			{
				maxCont = cont;
				this.winningMap = menuMaps[i].name;
			}
			else if (cont == maxCont)
			{
				this.winningMap = prevWinningNextmap;
			}
		}
		if (maxCont > prevWinningNextmapCont)
			return winningMap;
		else
			return prevWinningNextmap;
	}
	
	int getWinningMapVotes()
	{
		int maxCont = 0;
		for (uint i = 0; i < menuMaps.length(); i++)
		{
			int cont = menuMaps[i].votes;
			if (cont > maxCont)
				maxCont = cont;
		}
		return maxCont;
	}	
		
	void initMaps()
	{
		this.addMap(Map("wfca1",'/ui/porkui/maps/wfca1.jpg'));
		this.addMap(Map("wca3",'/ui/porkui/maps/wca3.png'));
		this.addMap(Map("sandboxb5", '/ui/porkui/maps/sandboxb5.png'));
		this.addMap(Map("cloudninea2", '/ui/porkui/maps/cloudninea2.png'));
		this.addMap(Map("cwl2", '/ui/porkui/maps/cwl2.jpg'));
		this.addMap(Map("cwm1", '/ui/porkui/maps/cwm1.jpg'));
		this.addMap(Map("cwm2", '/ui/porkui/maps/cwm2.jpg'));
		this.addMap(Map("cwm3", '/ui/porkui/maps/cwm3.jpg'));
		this.addMap(Map("babyimstiffbeta2", '/ui/porkui/maps/babyimstiffbeta2.png'));
		this.addMap(Map("ourpackagebeta3", '/ui/porkui/maps/ourpackagebeta3.png'));
		this.addMap(Map("claustrophobia", '/ui/porkui/maps/claustrophobia.png'));
		this.addMap(Map("random", '/ui/porkui/maps/random.png'));
	}
}

String@[] getMaplist()
{
    Cvar map_pool( "g_map_pool", "", 0 );
    return StringUtils::Split( map_pool.string, " " );
}

String getMaplistString()
{
	String@[] maps = getMaplist();
	String result="";
	for( uint i = 0; i < maps.length; i++ ) 
	{
		result+=( "" + maps[ i ] + " " );
	}
	return result;
}

bool isMap(const String &in mapName) {
    String@[] maps = getMaplist();

    for (uint i = 0; i < maps.length(); ++i) {
        if (mapName == maps[i]) {
            return true; 
        }
    }
    return false; 
}

String currentMapName()
{
	Cvar mapNameVar( "mapname", "", 0 );
	String currentMapName = mapNameVar.string.tolower();
	return currentMapName;
}

void makeReport(Client @client,String message)
{
	String userInfo=getCETTime() +"  ---->  "+ client.name +"  ---->  " + client.getUserInfoKey( "ip" ) + "  ---->  "+ client.getUserInfoKey( "rpc" );
	int i=0;
	while(G_FileExists( "rca/reports/report" +i+ ".txt" ))
		i++;
	G_WriteFile( "rca/reports/report" + i + ".txt", userInfo+"\n"+message );
	client.printMessage("Report sent successfully, thanks for your contribution.\n");
}
	
String getCETTime()
{
    Time t = Time(localTime);
    String time="";
    time += StringUtils::FormatInt(t.hour, "0", 2) + ":";
    time += StringUtils::FormatInt(t.min, "0", 2);
    return time;
}

void CheatCvar() {
    if( next_cvar_check > levelTime )
        return;
    G_CmdExecute( "cvarcheck " + "all \"" + "cg_voiceChats" + "\"\n" );
    next_cvar_check = levelTime + 5000;
}
uint next_cvar_check = 0;


int enemyTeamSize(Entity@ ent)
{
	if(ent.team==TEAM_ALPHA)
	{
		Team @tteam = @G_GetTeam( TEAM_BETA );
		return tteam.numPlayers;
	}
	else if(ent.team==TEAM_BETA)
	{
		Team @tteam = @G_GetTeam( TEAM_ALPHA );
		return tteam.numPlayers;
	}
	return 0;
}

