<h1 align="center">Gradjöng</h1>

<p align="center"><b>Gradient CI, live in 3D.</b> Every evaluation, build and cache push as a body in orbit.</p>

<p align="center">
  <a href="https://github.com/wavelens/gradient">⚙️ Gradient</a>
  •
  <a href="https://wavelens.github.io/gradient">📖 Documentation</a>
  •
  <a href="https://matrix.to/#/#gradient-ci:matrix.org">💬 Matrix Chat</a>
</p>

https://github.com/user-attachments/assets/bd733d97-fd8b-4439-b880-04387ba1e073

A Godot view of a [Gradient](https://github.com/wavelens/gradient) instance: the server as a black hole, workers on a ring around the server, evaluations and builds orbiting as cel-shaded bodies, binary caches above and proto traffic as comets.

## Usage

```sh
# Replay a recorded event log at 4x speed
nix run . -- --file events/1.log --speed 4

# Live view of a Gradient instance
nix run . -- --url https://gradient.example.com --token "$TOKEN" --poll 5

# Release build instead of the Godot editor binary
nix run .#release -- --file events/1.log
```

## Options

| Flag | Default | Description |
|---|---|---|
| `--file FILE` | | Event log to replay; exclusive with `--url` |
| `--url URL` | | Gradient instance to stream events from |
| `--token TOKEN` | | API token, only with `--url` |
| `--token-file FILE` | | File containing the API token, exclusive with `--token` |
| `--poll SECONDS` | `5` | Interval for worker load and network polling |
| `--speed SPEED` | `1` | Replay speed of `--file` |
| `--size WxH` | `1280x800` | Window size |
| `--fullscreen` | off | Start in fullscreen |
| `--banner DECT` | hidden | "See your Nix Flake building" banner with Matrix and Dect number after idle time; `""` omits the Dect |

## Live Data

With `--url`, Gradjöng reads:

- `api/v1/metrics/events`: event stream
- `api/v1/board/workers`: worker color by CPU load (green-blue-red, unstable at 90%+)
- `api/v1/board/network`: proto traffic rate and average worker throughput (`UTIL`)
- `api/v1/caches`: all caches, idle ones included
- `api/v1/projects/{project}/workers` and `api/v1/evals/{evaluation}`: worker and evaluation names
- `api/v1/board/jobs/dispatched`: evaluation of build jobs whose dispatch the stream did not show

## Controls

| Key | Action |
|---|---|
| `space` | Pause |
| `+` / `-` | Replay speed |
| `F11` | Fullscreen |
| Drag / wheel | Orbit / zoom camera |
| `q` / `esc` | Quit |

## Development

```sh
nix develop
godot --path . -- --file events/2.log
tests/run.sh        # headless Godot tests
nix flake check
```

| Directory | Content |
|---|---|
| `src/model` | Simulation, no nodes, fully tested |
| `src/ingest` | Event sources |
| `src/view` | Per-frame 3D rendering |
| `src/shaders` | Shaders |

## Contributing

Contributions are welcome: see the [Contributing Guidelines](CONTRIBUTING.md).

## License

[MIT](./LICENSE), with license notices following the [REUSE guidelines](https://reuse.software/). Developed by [Wavelens GmbH](https://wavelens.io).
