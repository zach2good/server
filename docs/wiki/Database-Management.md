# Making Persistent Changes
When updates happen to our SQL files, the import process will overwrite any changes you've made to those tables in your database. To keep your database up to date with the latest changes, as well as maintain your own custom changes, it is recommended that you save your changes as SQL queries in a `.sql` file in `server\sql\backups\`, then import that file after an update using either the dbtool **Restore/Import** function or another method of importing, such as:
```
mysql -u server -ppassword xidb < server/sql/backups/custom.sql
```

# dbtool
The database update, backup, and restore tool is called dbtool and is located in the `server\tools\` folder. Run it from the repo root: `py -3 .\tools\dbtool.py` on Windows, or `python3 ./tools/dbtool.py` on Linux with the `.venv` from the Quick Start Guide activated. The first time you run it, it creates `tools/config.yaml` to hold its settings.

- Backup
  - Using the default interface, select "3. Backup" and press `y` to create a full database backup in `server\sql\backups\`.

  **OR**

  - Use the command `dbtool.py backup` to create a full database backup in `server\sql\backups\`.

    - Use the command `dbtool.py backup lite` to create a partial database backup in `server\sql\backups\`. This will contain only the protected tables described below.

- Restore/Import
  - Using the default interface, select "4. Restore/Import", press `y` to create a full database backup or anything else to continue without a backup, then enter the number of the desired backup to import. Read the prompt carefully and confirm the import. 

- Update
  - Using the default interface, select "1. Update DB", press `y` to create a database backup or anything else to continue without a backup, review the changes then press `y` to import all files in `server\sql\` except the protected tables. It will then run any needed migrations, and finally check whether the release changed the client version and offer to update `CLIENT_VER` in `settings/login.lua`.
  - When your database is behind the checked-out commit, the menu also offers "e. Express Update". This imports only the `.sql` files that changed since that commit, then runs migrations.

  **OR**

  - Use the command `dbtool.py update`. This does an express update when it can and a full one when it can't, then runs any needed migrations and updates `CLIENT_VER` in `settings/login.lua` if the release changed it.
    - It only backs up first if you turn on automatic backups in the "s. Settings" menu (`auto_backup` in `config.yaml`).
    - Use the command `dbtool.py update full` to skip the express update and import all files in `server\sql\` except the protected tables.
  - Use the command `dbtool.py migrate` to run migrations without importing anything.

## ⚠Protected Tables⚠
  dbtool leaves the player data tables untouched during updates, unless a table is missing from the database. The same list is used for `dbtool.py backup lite`. It is the `player_data` list near the top of [`tools/dbtool.py`](https://github.com/LandSandBoat/server/blob/base/tools/dbtool.py), and includes `accounts`, `chars`, nearly every `char_*` table, `auction_house`, `delivery_box`, `linkshells` and `server_variables`. It isn't in `config.yaml`. To change it, edit `dbtool.py`.
