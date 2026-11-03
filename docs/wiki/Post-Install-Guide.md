# Post-Install Guide

Read this once the [Quick Start Guide](Quick-Start-Guide) has you logged in.

## Change settings

The defaults live in `settings/default/`. Don't edit them. To change a setting, copy its file into `settings/` and edit the copy. The server loads the defaults first, then your files over the top, key by key, so your copy only needs the keys you change.

You can also set any setting with an environment variable named `XI_<FILE>_<SETTING>`, e.g. `XI_MAIN_SERVER_NAME`.

Restart the server after any change.

## Make yourself a GM

Run this query, with your character's name, then zone or log in again:

```sql
UPDATE chars SET gmlevel = 4 WHERE charname = 'Name';
```

If you started `xi_map` by hand, you can type `gm Name 4` into its console instead. It applies at once. `dbtool`'s `Launch Server` runs the processes without a console, so use the query there.

GM commands are the scripts in [`scripts/commands/`](https://github.com/LandSandBoat/server/tree/base/scripts/commands). Each script's header describes it. In game, type `!` and the script name, e.g. `!promote` for `promote.lua`. Some to start with:

* `!godmode`: makes you invincible, among other things.
* `!givegil`: gives gil to you or your target.
* `!givexp`: gives experience points to you or your target.
* `!togglegm`: toggles your GM icon.
* `!speed`: sets your movement speed.
* `!zone`: moves you to a zone. It takes auto-translate, e.g. `!zone {Port Bastok}`.
* `!promote`: makes another player a GM.

## Open the server to other players

Every zone's `zoneip` in the `zone_settings` table must hold the address clients connect to. `dbtool` sets it. Run `python3 ./tools/dbtool.py` (Windows: `py -3 ./tools/dbtool.py`), choose `t. Maintenance Tasks`, then `2. Set zone IP addresses`, and pick one:

* **Local only** (`127.0.0.1`): you play on the machine that runs the server.
* **Local network**: players are on your LAN. `dbtool` finds the host's LAN address.
* **Public IP**: players connect over the internet. `dbtool` looks your address up through `ident.me`.
* **Manual entry**: anything else.

⚠️ `zone_settings` is not a protected table. Every database update or reset overwrites `zoneip`, and nobody can connect until you set it again. Set it from a [module](Module-Guide) so it survives updates.

For a public server, forward these ports on your router and open them in your firewall:

```txt
TCP: 54001, 54002, 54230, 54231, 51220, 51240
UDP: 54230
```

Add TCP 8088 only if you set `ENABLE_HTTP` in `network.lua`.

## Back up the database

`dbtool` offers a backup before each update. Backups, restores and the rest of `dbtool` are covered in [Database Management](Database-Management).

## Customise the server

Editing the repo's files is fine while you learn. Once you pull updates regularly, your edits will conflict with ours. Move them into [modules](Module-Guide).

## Run a public server

* [Common Tasks, Issues & Tweaks](Miscellaneous-Server): running several map processes, auction house bots and more.
* `tools/install-systemd-service.sh` installs the server as systemd services on Linux.
* [LetsEncrypt](LetsEncrypt): certificates for `xi_connect`.
* [Cloud Guide (GCP)](Cloud-Guide-GCP): hosting on Google Cloud.
* [Useful SQL Queries](Useful-SQL-queries)
