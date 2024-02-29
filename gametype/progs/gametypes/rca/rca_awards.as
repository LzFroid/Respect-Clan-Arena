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

// global constants
const uint ONEVS_AWARD_COUNT = 1;	// how many enemies you have to win in 1vsX situation

const uint SPEEDFRAG_SPEED = 1000;	// for gametypes with 'normal' speed
const uint SPEEDFRAG_SPEED2 = 1000;	// for gametypes that have higher speed cause of no selfdamage

Vec3[] rdmVelocities( maxClients );
const float pi = 3.14159265f;
bool rdmDebug=false;

void award_playerKilled( Entity @victim, Entity @attacker, Entity @inflictor )
{
	if( @victim == null || @attacker == null || @attacker.client == null )
		return;
		
	/********** speedfrag ************/
	
	if( @attacker != @victim )
	{
		Cvar g_allow_selfdamage( "g_allow_selfdamage", "", 0 );
		Vec3 avel = attacker.velocity;
		Vec3 vvel = victim.velocity;
		float speed, compSpeed;
		uint intSpeed;
		
		// CA and other modes without selfdamage require higher speed
		compSpeed = g_allow_selfdamage.integer == 0 ? SPEEDFRAG_SPEED2 : SPEEDFRAG_SPEED;
		
		// clear vertical velocity
		avel.z = 0.0;
		speed = avel.length();
		intSpeed = ( speed / 1.0f );
		if( speed >= compSpeed )
		{
			if ( attacker.client.weapon == WEAP_ELECTROBOLT )
				attacker.client.addAward( S_COLOR_CYAN + "Meep Meep! "+intSpeed);
			// victim.client.addAward( S_COLOR_CYAN + "You got Meep Meeped!" );
			// from headhunt.as
			if ( attacker.client.weapon == WEAP_GUNBLADE )
				attacker.client.addAward( S_COLOR_CYAN + "Gunblade Rush!" );
		}
	
		vvel.z = 0.0;
		speed = vvel.length();
		if( speed >= compSpeed )
		{
			attacker.client.addAward( S_COLOR_CYAN + "Coyote wins!" );
			// victim.client.addAward( S_COLOR_CYAN + "Meep Meep fail!" );
		}
		
		switch ( attacker.client.weapon )
		{
		case WEAP_ELECTROBOLT:
			RDM_playerKilled( victim, attacker, inflictor );
			break;
		/*
		case WEAP_ROCKETLAUNCHER:
			rocket_playerKilled( victim ,attacker, inflictor );
			break;

		case WEAP_GRENADELAUNCHER: 
			grenade_playerKilled( victim ,attacker, inflictor  );
			break;
		*/
		default:
			break;
		}
		

	}

}


float RDM_getDistance( Entity @a, Entity @b )
{
    return a.origin.distance( b.origin );
}

float RDM_min( float a, float b )
{
    return ( a >= b ) ? b : a;
}

float RDM_getAngle( Vec3 a, Vec3 b )
{   
    Vec3 my_a = a;
    Vec3 my_b = b;

    if ( my_a.length() == 0 || my_b.length() == 0 )
        return 0;
  
    my_a.normalize();
    my_b.normalize();

    return abs( acos( my_a.x * my_b.x + my_a.y * my_b.y + my_a.z * my_b.z ) );
}

float RDM_getAngleFactor ( float angle )
{
    const float minAcuteFactor = 0.15f;
    const float minObtuseFactor = 0.30f;

    return ( angle < pi / 2.0f ) ?
        minAcuteFactor + ( 1.0f - minAcuteFactor ) * sin( angle ) :
        minObtuseFactor + ( 1.0f - minObtuseFactor ) * sin( angle );
}

Vec3 RDM_getVector( Entity @a, Entity @b )
{
    Vec3 ao;
    Vec3 bo;

    ao = a.origin;
    bo = b.origin;
    bo.x -= ao.x;
    bo.y -= ao.y;
    bo.z -= ao.z;

    return bo;
}

float RDM_getAnticampFactor ( float normalizedVelocity )
{
    // How fast does the factor grow?
    const float scale = 12.0f;

    return ( atan( scale * ( normalizedVelocity - 1.0f ) ) + pi / 2.0f ) / pi;
}

int RDM_calculateScore( Entity @target, Entity @attacker )
{
    // Default score for a "normal" shot
    const float defScore = 100.0f;
    // Normal speed
    const float normVelocity = 600.0f;
    // Normal distance
    const float normDist = 800.0f;

    Vec3 directionAt = RDM_getVector( attacker, target );
    Vec3 directionTa = RDM_getVector( target, attacker );

    /* Projection of the attacker's velocity relative to ground to the flat
     * surface that is perpendicular to the vector from the attacker
     * to the target */
    Vec3 velocityA = attacker.velocity;
    float angleA = RDM_getAngle( velocityA, directionAt );
    float projectionA = RDM_getAngleFactor( angleA ) * velocityA.length();

    /* Anti-camping dumping - we significantly decrease projection if the
     * attacker's velocity is lower than the normVelocity */
    float anticampFactor = RDM_getAnticampFactor( velocityA.length() / normVelocity );

    /* Projection of the target's velocity relative to the ground to the flat
     * surface that is perpendicular to the vector from the target
     * to the attacker */
    Vec3 velocityTg = rdmVelocities[ target.playerNum ];
    float angleTg = RDM_getAngle( velocityTg, directionTa );
    float projectionTg = RDM_getAngleFactor( angleTg ) * velocityTg.length();

    /* Projection of the target's velocity relative to the attacker to the flat
     * surface that is perpendicular to the vector from the target
     * to the attacker */
    Vec3 velocityTa = velocityTg - attacker.velocity;
    float angleTa = RDM_getAngle( velocityTa, directionTa );
    float projectionTa = RDM_getAngleFactor( angleTa ) * velocityTa.length();

    /* Choose minimal projection */
    float projectionT = RDM_min( projectionTg, projectionTa );

    float score = defScore
                * anticampFactor
                * pow( projectionA / normVelocity, 2.0f )
                * ( 1.0f + projectionT / normVelocity )
                * ( RDM_getDistance( attacker, target ) / normDist );

    if ( rdmDebug )
        G_Print( S_COLOR_BLUE + "DEBUG:" +
                 " ACF = " + anticampFactor +
                 " Va = " + velocityA.length() +
                 " Aa = " + int( angleA * 180.0f / pi ) +
                 " Vtg = " + velocityTg.length() +
                 " Atg = " + int( angleTg * 180.0f / pi ) +
                 " Vta = " + velocityTa.length() +
                 " Ata = " + int( angleTa * 180.0f / pi ) +
                 " Distance = " + RDM_getDistance( attacker, target ) +
                 " Score = " + score +
                 "\n" );
	//G_PrintMsg( null, "score: "+score+"\n");
    return int( score );
}

// a player has just died. The script is warned about it so it can account scores
void RDM_playerKilled( Entity @target, Entity @attacker, Entity @inflicter )
{
    if ( match.getState() != MATCH_STATE_PLAYTIME )
        return;

    if ( @target.client == null )
        return;

    // punishment for suicide
    if ( @attacker == null || attacker.playerNum == target.playerNum )
        target.client.stats.addScore( -500 );

    // update player score
    if ( @attacker != null && @attacker.client != null )
    {
       int score = RDM_calculateScore( target, attacker );
       attacker.client.stats.addScore( score );
       if ( score >= 500 && score < 1000 )
       {
           attacker.client.addAward("Nice shot");
           G_PrintMsg( null, attacker.client.name + "^7 made a ^5nice shot\n" );
       }
       if ( score >= 1000 )
       {
           attacker.client.addAward(S_COLOR_RED + "!!! A W E S O M E !!!");
           G_PrintMsg( null, attacker.client.name + "^7 made an ^1AWESOME SHOT\n" );
       }
    }
}

void rocket_playerKilled( Entity @target, Entity @attacker, Entity @inflicter )
{
	if( wasInAir(target))
        G_PrintMsg( null, attacker.client.name + "^7 made an ^8air rocket\n" );
}

void grenade_playerKilled( Entity @target, Entity @attacker, Entity @inflicter )
{
	if( wasInAir(target))
        G_PrintMsg( null, attacker.client.name + "^7 made an ^4air nade\n" );
}

bool wasInAir(Entity @player)
{
	Vec3 mins, maxs;
    player.getSize( mins, maxs );
    Vec3 down = player.origin;
    down.z -= 50;
    Trace tr;
	if( !tr.doTrace( player.origin, mins, maxs, down, player.entNum, MASK_DEADSOLID ) )
    {
		return true;
    }
	return false;
}

Vec3 playerMins( -16.0, -16.0, -24.0 );
Vec3 playerMaxs( 16.0, 16.0, 40.0 );