class rcaPlayer 
{
	Client@ client;
	
	bool hasVotedNextmap;
	
	float roundDamage;
	uint[] roundDmgReceived(maxClients);

	bool isMuted;
	uint lastMsg;
	uint lastVsay;
	uint msgCounter;
	uint chatFloodTime;
	bool[] mutedPlayers(maxClients);
	bool[] vmutedPlayers(maxClients);
	bool cg_voiceChats;
	
	bool pendingGhostmove;
	int playerMaxSpeed;
	
	rcaPlayer()
	{
		this.isMuted=true;
		this.lastMsg = levelTime;
		this.msgCounter = 0;
		this.chatFloodTime = 0;
		this.hasVotedNextmap=false;
		this.roundDamage=0.0;
		this.lastVsay = levelTime;
		this.cg_voiceChats=true;
		this.pendingGhostmove=false;
		this.playerMaxSpeed=0;
	}
	
	String printRoundDmgReceived()
	{
		String oout="dmg received: ";
		int totalDmgReceived=0;
		for ( int i = 0; i < maxClients; i++ )
		{
			if(this.roundDmgReceived[i]>0)
			{
				totalDmgReceived+=this.roundDmgReceived[i];
				Client @inflictor=@G_GetClient( i );
				oout+= "^8|^7"+inflictor.name+" ^2- ^7"+this.roundDmgReceived[i]+"^8| ";
			}
		}
		return oout+"\n";
	}
	
	void resetRoundDmgReceived()
	{
		for ( int i = 0; i < maxClients; i++ )
			this.roundDmgReceived[i]=0;
	}
	
}