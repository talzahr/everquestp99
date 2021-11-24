# EQParse
Just some shell scripts and various things to run alongside EQ Project1999

Modify the variables in the script as shown with examples already in place.
Run it in any environment with a BASH shell interpreter while EQ is running.
Requires AWK/gAWK

Does some basic things so far. I mostly work on this during gaming downtime in EQ.
Don't expect it to be better than other EQ parsers out there. It's made for my purposes really. 

For best results run in an terminal emulator (or desktop environment) that allows for 'always on top' and transparency. 

![EQParsev1 0](https://user-images.githubusercontent.com/54084333/140630900-3f91b72e-db70-48cb-92da-e9f904adac2e.png)

Features:
- Tracks user-defined spell effects by showing expiration timer. 
- Timer color turns yellow when expiring in <=15 seconds.
- Spells such as invis, IVU, mez, fear etc. can be monitored every 0.3 seconds and a sound file played when dropped/dropping.
- Keeps a counter of user-defined items that are looted.
- Keeps track of coins looted. 

TO DO:
- A function to calculate zoning time and add that to all spell effect timers.
- Detect deaths and remove said effects
- ~~Accept keystrokes to reset counters, etc.~~ **Basic functionality completed
- ~~Config file that can be modified while script is running~~ **eqparse.conf, populated every 30 seconds
- Order active effects by timer ascending.
- Auction mode to extract patterns from /auc messages **This is next
