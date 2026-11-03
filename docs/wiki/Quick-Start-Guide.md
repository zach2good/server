# Quick Start Guide

Follow this _to the letter_ the first time. Swap pieces out (WAMP, Strawberry Perl's Python, a different compiler) only once you've got a working server.

We support **Windows 10/11** and **Ubuntu 26.04**, and publish **Docker** images. Other platforms are on [Experimental Platforms](Experimental-Platforms).

_(click a section to expand it)_

<details>
<summary><b>Windows 10/11</b></summary>

## 1. Install the tools

* [Git for Windows](https://gitforwindows.org/). Defaults are fine.
* [Visual Studio 2026](https://visualstudio.microsoft.com/vs/community/). **YOU MUST** tick the `Desktop development with C++` workload, or nothing will build.
* [MariaDB Server](https://mariadb.org/download/?t=mariadb&p=mariadb&r=10.11.18&os=windows&cpu=x86_64&pkg=msi&m=xtom_ams), latest `10.11.x`.
  * Set a root password.
  * ⚠️ Tick `Use UTF8 as server's character set` on the `Default instance properties` page. Skip it and you'll get crashes that are miserable to diagnose.
* [Python 3.14](https://www.python.org/downloads/). Tick `Add python.exe to PATH`. CI uses 3.14.

## 2. Get the code

In PowerShell, from the folder you want the server in:

```ps
git clone --recursive https://github.com/LandSandBoat/server.git
cd server
py -3 -m pip install -r tools/requirements.txt
cp settings/default/network.lua settings/
```

Edit `settings\network.lua` and set `SQL_PASSWORD` to your MariaDB root password. Keep the quotes. Leave `SQL_LOGIN` as `'root'` and `SQL_DATABASE` as `'xidb'`.

## 3. Create the database

```ps
py -3 ./tools/dbtool.py
```

Press enter if MariaDB's `bin` folder is on your `PATH`, otherwise paste its path (e.g. `C:\Program Files\MariaDB 10.11\bin\`). Say `y` when it offers to create `xidb`. Once you see the main menu, quit with `q`.

## 4. Build

From the command line:

```ps
py -3 .\tools\build.py
```

`build.py` finds Visual Studio on its own, then configures and builds the `default` preset (`RelWithDebInfo`).

Or in Visual Studio: `Open a local folder`, pick `server`, wait for `CMake generation finished`, set the configuration dropdown to `Default (RelWithDebInfo)`, then `Build > Build All`.

⚠️ Visual Studio likes to pick `Debug`. Check the dropdown. A `Debug` map server is many times slower, so only use it to chase a crash.

Now go to [Start the server](#start-the-server).

</details>

<details>
<summary><b>Linux (Ubuntu 26.04)</b></summary>

We build and test on the latest Ubuntu LTS. Older releases may not work.

## 1. Install the tools

```sh
sudo apt update
sudo apt install git python3 python3-venv python3-dev g++-15 cmake ninja-build pkg-config \
    libluajit-5.1-dev libzmq3-dev libssl-dev zlib1g-dev libzstd-dev libdwarf-dev binutils-dev \
    mariadb-server libmariadb-dev-compat
sudo mysql_secure_installation
```

You need C++23 and CMake 3.25 or newer. CI builds with `g++-15` and `clang-22`. Point CMake at GCC 15 (stick this in your shell profile):

```sh
export CC=gcc-15 CXX=g++-15
```

## 2. Create a database user

Pick your own user name and password:

```sh
sudo mysql -e "CREATE USER 'xi'@'localhost' IDENTIFIED BY 'password'; GRANT ALL PRIVILEGES ON xidb.* TO 'xi'@'localhost';"
```

## 3. Get the code

```sh
git clone --recursive https://github.com/LandSandBoat/server.git
cd server
python3 -m venv .venv
source .venv/bin/activate
pip install -r tools/requirements.txt
cp settings/default/network.lua settings/
```

Ubuntu won't let `pip` touch the system Python, so the tools live in `.venv`. Run `source .venv/bin/activate` in every new terminal before you use `dbtool.py` or `build.py`.

Edit `settings/network.lua` and set `SQL_LOGIN` and `SQL_PASSWORD` to the user you created. Keep the quotes.

## 4. Create the database

```sh
python3 ./tools/dbtool.py
```

Say `y` when it offers to create `xidb`. Once you see the main menu, quit with `q`.

## 5. Build

```sh
python3 ./tools/build.py
```

That configures and builds the `default` preset (`RelWithDebInfo`). A `Debug` map server is many times slower, so only pass `--preset debug` to chase a crash.

Now go to [Start the server](#start-the-server).

</details>

<details>
<summary><b>Docker (and macOS)</b></summary>

CI builds our images, runs `xi_test` in them, and publishes them to `ghcr.io/landsandboat/server` for `linux/amd64`. On macOS, use Docker. Apple Silicon runs the `amd64` image under emulation.

Follow [`docker/README.md`](https://github.com/LandSandBoat/server/blob/base/docker/README.md).

</details>

## Start the server

The server is five processes. The easy way to start them all is `dbtool` (`py -3` on Windows, `python3` elsewhere):

```sh
python3 ./tools/dbtool.py
```

Choose `l. Launch Server`. It starts `xi_connect`, `xi_search`, `xi_profile` and `xi_world`, then one `xi_map` per zone port (one by default).

To start them by hand, run each of these from the `server` folder and leave it running. `xi_map` goes last.

* `xi_connect`
* `xi_world`
* `xi_search`
* `xi_profile`
* `xi_map`

If one closes straight away, check its log in `log/`.

## Connect

Set up a client with the [Client Setup Guide](Client-Setup-Windows), create an account and a character, and log in.

Then read the [Post-Install Guide](Post-Install-Guide) for settings, making yourself a GM, and letting other people in.

## Update

1. Stop every server process. _All of them._
2. Pull the latest code. Got local edits? `git stash` first, `git stash pop` after, and fix any conflicts it reports.

   ```sh
   git pull
   git submodule update --init --recursive
   ```

3. Rebuild the same way you built the first time.
4. Update the database:

   ```sh
   python3 ./tools/dbtool.py update
   ```

On Windows, use `py -3` instead of `python3`. On Linux, activate `.venv` first.

Build broke? See [Build Troubleshooting](Build-Troubleshooting).
