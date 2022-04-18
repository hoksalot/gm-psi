
# Player Status Icons

[![GLua Linter](https://github.com/hoksalot/gm-psi/actions/workflows/glualint.yml/badge.svg)](https://github.com/hoksalot/gm-psi/actions/workflows/glualint.yml)
[![Steam Views](https://img.shields.io/steam/views/2002082140?logo=steam)](https://steamcommunity.com/sharedfiles/filedetails/?id=2002082140)
[![Steam Subscribers](https://img.shields.io/endpoint.svg?url=https://shieldsio-steam-workshop.jross.me/2002082140/subscriptions&label=subscriptions)](https://steamcommunity.com/sharedfiles/filedetails/?id=2002082140)
[![Steam Update Date](https://img.shields.io/steam/update-date/2002082140?label=update%20date&logo=steam)](https://steamcommunity.com/sharedfiles/filedetails/?id=2002082140)

## Welcome

This is the official repository for the Garry's Mod addon Player Status Icons.
A more detailed description of the features can be found on the [Garry's Mod workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=2002082140) page of the addon.

## Developers

If you're looking to interface with this addon, I have added a server-side hook:

`PlyStatusIcons_Hook_StatusUpdate(ply_source, new_statusfield, new_last_active, ply_target):`<br/>
`ent ply_source:` Player where the status update came from<br/>
`unsigned int new_statusfield:` The new status... (also check out helper functions for handling this (init file))<br/>
`float new_last_active:` The last time there was input from the player (curtime). Only used when afk, otherwise 0<br/>
`ent ply_target:` Only a player entity if there is a specific player to send the update to, otherwise it is `nil`, and the update is sent to everyone<br/>

You can use this by calling `hook.Add(...)` (See [Garry's Mod wiki](https://wiki.facepunch.com/gmod/hook.Add))<br/>
Just like any other hook.


Statuses are sent from the client in the form of a [bit field](https://en.wikipedia.org/wiki/Bit_field):
| Flag Name    | Flag Value (decimal)    | Description                                  |
| -------------| ----------------------- | -------------------------------------------- |
| ACTIVE       | 0                       |                                              |
| AFK          | 1                       |                                              |
| CURSOR       | 2                       | In VGUI                                      |
| TYPING       | 4                       |                                              |
| SPAWNMENU    | 8                       |                                              |
| MAINMENU     | 16                      |                                              |
| ALTTAB       | 32                      | Game not in focus                            |
| TIMEOUT      | 64                      | Detected server side, player lost connection |

Status detection on the client is polling-based, (every 80ms, 1 sec when AFK) but the client only sends an update to the server if there really is a change in its status. The server then distributes this information to the other clients. There is a maximum number of updates a player can send in a given time window.

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

Mark running environment in the top of the file.<br/>
For everything else, follow Lua style guidelines.
