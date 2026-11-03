# Tracy

[Tracy](https://github.com/wolfpld/tracy) is a real-time, nanosecond-resolution frame and sampling profiler. We can't know how good or bad our performance is until we measure it, so we build its client into the server and you look at the results with Tracy's own tools.

![image](https://user-images.githubusercontent.com/1389729/97106613-832f0100-16cb-11eb-8452-267e406bceb9.png)

Tracy has two parts:

- The client, compiled into `xi_map` and `xi_test`. It sends profiling data over the network.
- The server tools, which receive it: `tracy-profiler` (the GUI), `tracy-capture` (records to a file without a GUI) and `tracy-csvexport` (turns a recording into a CSV).

## Build

Use the `tracy` preset. It builds `RelWithDebInfo` with Tracy compiled in, into its own `build-tracy/` directory, so your normal build is untouched:

```sh
python3 ./tools/build.py -p tracy
```

Windows: `py -3 .\tools\build.py -p tracy`. To run CMake yourself, use `cmake --preset tracy` then `cmake --build --preset tracy`.

The build produces `xi_map_tracy` and `xi_test_tracy`, so they can sit beside your normal binaries. It also puts the server tools in the repo root:

- On Windows, CMake downloads Tracy's release zip, with `tracy-profiler.exe`, `tracy-capture.exe`, `tracy-csvexport.exe` and the rest.
- On Linux and macOS, CMake builds `tracy-capture` and `tracy-csvexport` from source. To use the GUI, build `tracy-profiler` yourself from the [Tracy repo](https://github.com/wolfpld/tracy), or copy the trace to a Windows machine.

CMake fetches the Tracy client at the version pinned by `TRACY_VERSION` in `cmake/tools/Tracy.cmake`, currently 0.14.1. The GUI has to be the same version as the client, or it won't connect. Check for `TRACY_ENABLE: ON` in the configure output.

Always profile `RelWithDebInfo`. A `Debug` build is many times slower, and you'll spend a week optimising code the compiler would have fixed for free.

### Visual Studio

Pick `Tracy profiling` in the configure preset dropdown and `Tracy profiling (RelWithDebInfo)` in the build preset dropdown, then build as normal.

<img width="395" alt="image" src="https://github.com/user-attachments/assets/aab0f2f8-b693-4112-9523-17005a6f20e8">

### Other configurations

To add Tracy to any other configuration, pass `-DTRACY_ENABLE=ON` when you configure.

## Connect the profiler

Start the server as normal, but run `xi_map_tracy` in place of `xi_map`. In a multi-process setup, swap only the one process you want to profile.

On Windows, run `xi_map_tracy.exe` as Administrator. Without it, Tracy can't sample call stacks and says so loudly.

Then start `tracy-profiler`, enter the address of the machine running `xi_map_tracy` (`127.0.0.1` for your own machine) and press `Connect`. The server doesn't broadcast itself, so it won't appear in the profiler's list. Type the address in. Tracy listens on port `8086`, so open it if you connect from another machine.

![image](https://github.com/LandSandBoat/server/assets/1389729/89b7bffe-a170-4398-b08c-d04e8c392fa3)

The client runs on demand. It collects nothing until a profiler connects, so attach and detach whenever you like. Wait until startup has finished, unless startup is what you're after. It spews a huge amount of data and tells you very little about runtime performance.

Once connected, you'll see something like this:

![image](https://user-images.githubusercontent.com/1389729/184949465-373513d3-5af2-4737-8734-3bf12e14a24f.png)

To save the trace, click the Wi-Fi icon. **Traces can be very large!** Plan accordingly.

![image](https://user-images.githubusercontent.com/1389729/184949741-25c5c6a9-fa5e-4beb-80b2-3d0202058aa2.png)

### More than one process

Each Tracy-enabled process needs its own port. Set `TRACY_PORT` before you start each one:

```sh
TRACY_PORT=8087 ./xi_map_tracy --ip 127.0.0.1 --port 54231
```

Don't use `8088`. The HTTP API lives there by default.

## Capture without the GUI

On a headless server, a remote VM or anywhere the GUI is awkward, record a trace with the capture script:

```sh
python3 ./tools/capture.py
```

It runs `tracy-capture` for 60 seconds on port `8086`, writes a timestamped `.tracy` file, then writes the zone statistics to a CSV of the same name with `tracy-csvexport`. Options:

| Option | Default | What it does |
| --- | --- | --- |
| `-s`, `--seconds` | `60` | How long to capture |
| `--port` | `8086` | The port of the process to capture (its `TRACY_PORT`) |
| `-o`, `--out-dir` | current directory | Where to write the trace and CSV |
| `--self` | off | Export self times instead of inclusive times |

Open the `.tracy` file in `tracy-profiler` later, on any machine.

## Profile the tests

`xi_test_tracy` runs the test suite with Tracy compiled in. Connect the profiler to it like `xi_map_tracy`.

The benchmarks in `scripts/tests/benchmarks` are off by default. Set `XI_RUN_BENCHMARKS=1` to run them:

```sh
XI_RUN_BENCHMARKS=1 ./xi_test_tracy --file benchmarks
```

Each benchmark file lists the environment variables that set its workload size.

## Add your own zones

The macros are in `src/common/tracy.h`. They compile to nothing when Tracy is off, so leave them in.

- `TracyZoneScoped;` at the top of a function times that function. Leave a blank line after it.
- `TracyZoneScopedN("name");` times a scope under a name you choose.
- `TracyZoneString(str);` and `TracyZoneCString(cstr);` attach text, such as a mob or zone name, to the current zone.
- `TracyMessageStr(str);` puts a message on the timeline.
- `TracyReportGraphNumber(name, num);` plots a value over time.

The map server marks a frame on each time-server tick, and reports Lua memory use as a graph.

## Finding problems

Searchable statistics are under `Statistics`, and log messages under `Messages`. Click, drag and zoom around the timeline to see what's happening. To jump back to the busiest frames, use the options under `Pause/Resume`.

![image](https://user-images.githubusercontent.com/1389729/184949889-ac577f3b-8124-42e2-8954-493289a86683.png)

![image](https://user-images.githubusercontent.com/1389729/184949998-5cade8da-af6c-49a5-8115-e37f2014655d.png)

Click an entry in `Statistics` to drill into that function.

![image](https://user-images.githubusercontent.com/1389729/184950126-3e32ad0c-3f30-48ac-945d-6a6efd120633.png)

## Gotchas

Lots of things affect performance:

- Platform (Windows, Linux, macOS)
- Type of build (Debug, RelWithDebInfo, Release)
- Compiler (MSVC, Clang, GCC)
- Your hardware: CPU, memory, disk
- Other programs running
- Virtualisation and containers (VMware, WSL, Docker)

For before-and-after comparisons, keep everything else the same between runs and change one thing at a time. Take several readings, each with many samples. On a laptop, alternate the two builds rather than running one after the other, so thermal throttling hits both equally.

Don't chase a child call just because it takes most of its parent's time. If the parent costs nanoseconds overall, 80% of that is still nothing.
