const String badwordsFile = "rca/badwords.txt";

String badwordList;
	
bool isBadwordPresent(String msg)
{
	msg=msg.tolower();
    if (!G_FileExists(badwordsFile))
        G_WriteFile(badwordsFile, "nigga");

    badwordList = G_LoadFile(badwordsFile);

    int badwordsIndex = 0;
    String badwordsToken = " ";

    while (badwordsToken != "")
    {
        badwordsToken = badwordList.getToken(badwordsIndex);
        if (PatternMatch(msg,badwordsToken))
            return true;			
        badwordsIndex++;
    }

    return false;
}
	
	

