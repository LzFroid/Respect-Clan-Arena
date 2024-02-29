class rcaChat
{
	Vsays vsayList;
	int soundIndex=0;
	String  modelName="male";
	
	void initVsays()
	{
		this.vsayList.addVsay(Vsay("burp", 'Burrrp!', true));
		this.vsayList.addVsay(Vsay("bruh", 'Bruh!', true));
		this.vsayList.addVsay(Vsay("caseclosed", 'Case closed!', true));
		this.vsayList.addVsay(Vsay("cough", 'Cough! Cough!', true));
		this.vsayList.addVsay(Vsay("ehhh", 'Ehhh?!', true));
		this.vsayList.addVsay(Vsay("ohmygod", 'Oh my god!', true));
		this.vsayList.addVsay(Vsay("ohyeah", 'Oh yeah!', true));
		this.vsayList.addVsay(Vsay("wohoohoo", 'Woo hoo hoo!', true));
		this.vsayList.addVsay(Vsay("araara", 'Ara Ara!', true));
		this.vsayList.addVsay(Vsay("niceshot", 'Nice shot!', true));
		this.vsayList.addVsay(Vsay("zzz", 'Zzzzzz!', true));
		this.vsayList.addVsay(Vsay("youcandoit", 'You can do it!', true));
		this.vsayList.addVsay(Vsay("well", 'Well!', true));
		this.vsayList.addVsay(Vsay("unbelievable", 'Unbelievable!', true));
		this.vsayList.addVsay(Vsay("sigh", 'Sigh!', true));
		this.vsayList.addVsay(Vsay("please", 'Please!', true));
		this.vsayList.addVsay(Vsay("nicework", 'Nice work!', true));
		this.vsayList.addVsay(Vsay("nexttime", 'Maybe next time, uh?!', true));
		this.vsayList.addVsay(Vsay("imsoready", 'Im so ready!', true));
		this.vsayList.addVsay(Vsay("mmm", 'Mmmmmm!', true));
		this.vsayList.addVsay(Vsay("hahaha", 'Hahaha!', true));
		this.vsayList.addVsay(Vsay("comeon", 'Come on!', true));
		this.vsayList.addVsay(Vsay("goodboy", 'You have been a very good boy!', true));
		
		this.vsayList.addVsay(Vsay("needhealth", "Need health!", false));
		this.vsayList.addVsay(Vsay("needweapon", "Need weapon!", false));
		this.vsayList.addVsay(Vsay("needarmor", "Need armor!", false));
		this.vsayList.addVsay(Vsay("affirmative", "Affirmative!", false));
		this.vsayList.addVsay(Vsay("negative", "Negative!", false));
		this.vsayList.addVsay(Vsay("yes", "Yes!", false));
		this.vsayList.addVsay(Vsay("no", "No!", false));
		this.vsayList.addVsay(Vsay("ondefense", "I'm on defense!", false));
		this.vsayList.addVsay(Vsay("onoffense", "I'm on offense!", false));
		this.vsayList.addVsay(Vsay("oops", "Oops!", false));
		this.vsayList.addVsay(Vsay("sorry", "Sorry!", false));
		this.vsayList.addVsay(Vsay("thanks", "Thanks!", false));
		this.vsayList.addVsay(Vsay("noproblem", "No problem!", false));
		this.vsayList.addVsay(Vsay("yeehaa", "Yeehaa!", false));
		this.vsayList.addVsay(Vsay("goodgame", "Good game!", false));
		this.vsayList.addVsay(Vsay("defend", "Defend!", false));
		this.vsayList.addVsay(Vsay("attack", "Attack!", false));
		this.vsayList.addVsay(Vsay("needbackup", "Need backup!", false));
		this.vsayList.addVsay(Vsay("booo", "Booo!", false));
		this.vsayList.addVsay(Vsay("needdefense", "Need defense!", false));
		this.vsayList.addVsay(Vsay("needoffense", "Need offense!", false));
		this.vsayList.addVsay(Vsay("needhelp", "Need help!", false));
		this.vsayList.addVsay(Vsay("roger", "Roger!", false));
		this.vsayList.addVsay(Vsay("armorfree", "Armor free!", false));
		this.vsayList.addVsay(Vsay("areasecured", "Area secured!", false));
		this.vsayList.addVsay(Vsay("shutup", "Shut up!", false));
		this.vsayList.addVsay(Vsay("boomstick", "Need boomstick!", false));
		this.vsayList.addVsay(Vsay("gotowarshell", "Go to warshell!", false));
		this.vsayList.addVsay(Vsay("gotoquad", "Go to quad!", false));
		this.vsayList.addVsay(Vsay("ok", "Ok!", false));
		this.vsayList.addVsay(Vsay("defend_a", "Defend A!", false));
		this.vsayList.addVsay(Vsay("attack_a", "Attack A!", false));
		this.vsayList.addVsay(Vsay("defend_b", "Defend B!", false));
		this.vsayList.addVsay(Vsay("attack_b", "Attack B!", false));

	}
	
	String vsayListString()
	{
		String response="^2standard vsays:^7\n";
		for( uint i = 0; i < this.vsayList.vsayList.length; i++ ) 
		{
			if(this.vsayList.vsayList[i].isSpecial==false)
				response+=(this.vsayList.vsayList[i].name+" ");
		}
		response+="\n^8rca vsays:^7\n";
		for( uint i = 0; i < this.vsayList.vsayList.length; i++ ) 
		{
			if(this.vsayList.vsayList[i].isSpecial)
				response+=(this.vsayList.vsayList[i].name+" ");
		}
		return response+"\n";
	}
	
	void doPublicChat(Client @client, String msg)
	{
		if(this.allowedToChat(client))
		{
			if (playerStats[client.playerNum].isMuted == false) 
			{
				Entity @ent;
				Team @team;

				for (int i = 0; i < GS_MAX_TEAMS; i++) {
					@team = @G_GetTeam(i);
					for (int j = 0; @team.ent(j) != null; j++) {
						@ent = @team.ent(j);
						if(playerStats[ent.client.playerNum].mutedPlayers[client.playerNum]==false)
							ent.client.execGameCommand("ch " + G_GetClient(client.playerNum).getEnt().entNum + " \"" + msg + "\"");
					}
				}
			} 
			else 
			{
				client.printMessage("^1You are muted / Cant talk yet!\n");
			}
		}
	}


	void doTeamChat(Client @client, String msg)
	{
		if(playerStats[client.playerNum].isMuted==false)
		{
			if(this.allowedToChat(client))
			{
				Entity @ent;
				Team @team = @G_GetTeam(client.team);
				for(int i = 0; @team.ent(i) != null; i++)
				{
					@ent = @team.ent(i);
					if(playerStats[ent.client.playerNum].mutedPlayers[client.playerNum]==false)
						ent.client.execGameCommand("tch " + G_GetClient(client.playerNum).getEnt().entNum + " \"" + msg + "\"");	
				}
			}
		}
		else
		{
			client.printMessage("^1You are muted / Cant talk yet!\n");
		}
	}
	
	void doPublicVsay(Client @client,String vsayName, String msg)
	{
		if(this.allowedToChat(client))
		{
			if(vsayList.isVsay(vsayName))
			{
				if(playerStats[client.playerNum].isMuted==false)
				{
					Entity @ent;
					Team @team;
					soundIndex=0;
					if(msg.length()==0)
						msg=vsayList.getVsay(vsayName).text;
					if((levelTime-playerStats[client.playerNum].lastVsay)>2500)
					{
						if(vsayList.getVsay(vsayName).isSpecial)
							soundIndex= G_SoundIndex( "sounds/rca/"+vsayName);
						else
						{
							modelName = client.getUserInfoKey("model");
							soundIndex =G_SoundIndex( "sounds/players/"+modelToFolder(modelName)+"/"+vsayName);
						}
					}
					for (int i = 0; i < GS_MAX_TEAMS; i++) 
					{
						@team = @G_GetTeam(i);
						for (int j = 0; @team.ent(j) != null; j++) 
						{
							@ent = @team.ent(j);
							if(playerStats[ent.client.playerNum].mutedPlayers[client.playerNum]==false)
							{
								ent.client.execGameCommand("ch " + G_GetClient(client.playerNum).getEnt().entNum + " \"(v) " + msg + "\"");
								if(playerStats[ent.client.playerNum].vmutedPlayers[client.playerNum]==false && playerStats[ent.client.playerNum].cg_voiceChats==true)
									G_LocalSound( ent.client, 2, soundIndex);
							}
						}
					}					
				}
				else
				{
					client.printMessage("^1You are muted / Cant talk yet!\n");
				}
			}
			else
			{
				client.printMessage("^1There is no vsay called: "+vsayName+"\n");
			}
	
		}
	}
	
	void doTeamVsay(Client @client,String vsayName, String msg)
	{
		if(this.allowedToChat(client))
		{
			if(vsayList.isVsay(vsayName))
			{
				if(playerStats[client.playerNum].isMuted==false)
				{
					if(msg.length()==0)
						msg=vsayList.getVsay(vsayName).text;
					if((levelTime-playerStats[client.playerNum].lastVsay)>2500)
					{
						if(vsayList.getVsay(vsayName).isSpecial)
							soundIndex=G_SoundIndex( "sounds/rca/"+vsayName);
						else
						{
							modelName = client.getUserInfoKey("model");
							soundIndex=G_SoundIndex( "sounds/players/"+modelToFolder(modelName)+"/"+vsayName);
						}
					}
					Entity @ent;
					Team @team = @G_GetTeam(client.team);
					for(int i = 0; @team.ent(i) != null; i++)
					{
						@ent = @team.ent(i);
						if(playerStats[ent.client.playerNum].mutedPlayers[client.playerNum]==false)
						{
							ent.client.execGameCommand("tch " + G_GetClient(client.playerNum).getEnt().entNum + " \"(v) " + msg + "\"");
							if(playerStats[ent.client.playerNum].vmutedPlayers[client.playerNum]==false && playerStats[ent.client.playerNum].cg_voiceChats==true)
								G_LocalSound( ent.client, 2, soundIndex);
						}
					}		
				}
				else
				{
					client.printMessage("^1You are muted / Cant talk yet!\n");
				}
			}
			else
			{
				client.printMessage("^1There is no vsay called: "+vsayName+"\n");
			}
	
		}
	}

	bool allowedToChat(Client @client)
	{
		if(client.muted == 1 || client.muted == 3)
		{
			G_PrintMsg(client.getEnt(), "^1You're muted.\n");
			return false;
		}

		if(playerStats[client.playerNum].msgCounter < 5)
		{
			if((playerStats[client.playerNum].lastMsg + 1) < localTime)
				playerStats[client.playerNum].msgCounter = 0;
			playerStats[client.playerNum].lastMsg = localTime;
			playerStats[client.playerNum].msgCounter++;

			if(playerStats[client.playerNum].msgCounter > 4)
			{
				playerStats[client.playerNum].chatFloodTime = localTime;
				G_PrintMsg(client.getEnt(), "^1Chat flood protection, please wait " + ((playerStats[client.playerNum].chatFloodTime + 10) - localTime) + " ^1seconds\n");
				return false;
			}
			return true;
		}
		else
		{
			if((playerStats[client.playerNum].chatFloodTime + 10) < localTime)
			{
				playerStats[client.playerNum].msgCounter = 1;
				return true;
			}
			G_PrintMsg(client.getEnt(), "^1Chat flood protection, please wait " + ((playerStats[client.playerNum].chatFloodTime + 10) - localTime) + " ^1seconds\n");
			return false;
		}
	}
}

class Vsay
{
	String name;
	String text;
	bool isSpecial;
	
	Vsay(String name, String text, bool isSpecial)
	{
		this.name=name;
		this.text=text;
		this.isSpecial=isSpecial;
	}
	
}

class Vsays
{
	Vsay@[] vsayList;
	
	Vsays(){}
	~Vsays(){}
	
	void addVsay(Vsay@ vsay)
	{
		this.vsayList.push_back(@vsay);
	}
	
	bool isVsay(const String &in vsayName)
	{
		for (uint i = 0; i < this.vsayList.length(); ++i) {
			if (vsayName == this.vsayList[i].name) {
				return true; 
			}
		}
		return false; 
	}
	
	
	Vsay@ getVsay(const String &in vsayName)
	{
		for (uint i = 0; i < this.vsayList.length(); ++i) {
			if (vsayName == this.vsayList[i].name) {
				return this.vsayList[i]; 
			}
		}
		return null;
	}
	
}

String modelToFolder(String modelName)
{
	if(modelName=="bigvic")
		return "male";
	if(modelName=="monada")
		return "female";
	return modelName;
}