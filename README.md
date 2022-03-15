
# Player Status Icons

## Welcome!

This is the official repository for the Garry's Mod addon Player Status Icons.
A more detailed description can be found on the [Garry's Mod workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=2002082140) page of the addon.

## Developers

If you're looking to interface with this addon, I have added a server-side hook:
```
PlyStatusIcons_Hook_StatusUpdate(ply_source, new_statusfield, new_last_active, ply_target):
ent ply_source: Player where the status update came from
unsigned int new_statusfield: The new status... (also check out helper functions for handling this (init file))
float new_last_active: The last time there was input from the player (curtime) only used when afk, otherwise 0
ent ply_target: Only a player entity if there is a specific player to send the update to, otherwise it is sent to everyone

You can use this by calling hook.Add(.....) (See Garry's Mod wiki)
Just like any other hook.
```

Statuses are sent from the client in the form of a [bit field](https://en.wikipedia.org/wiki/Bit_field):
```
ACTIVE = 0
AFK = 1
CURSOR = 2 -- Cursor is active (in vgui)
TYPING = 4,
SPAWNMENU = 8
MAINMENU = 16
ALTTAB = 32 -- Game not in focus
TIMEOUT = 64 -- The player is timing out, detected server side
```
Status detection on the client is polling-based, (every 40ms, though I'm planning to optimize this) but the client only sends an update to the server if there really is a change in its status. The server then distributes this information to the other clients. There is a maximum number of updates a player can send in a given time window.

### Coding style info

**Function names:**<br/>
Helper functions / methods: ``camelCase``<br/>
Event functions (hooks, net, etc): ``PascalCase``

**Var names:**
``snake_case (camelCase if it gets too long)``

**Constants:**
``UPPER_SNAKE_CASE``

**Tables:**
``PascalCase``

Mark running environment in the top of the file.
For everything else, follow Lua style guidelines.