# gradjoeng

Live 3D view of Gradient CI events in Godot: a black-hole server, workers on a ring around it, evaluations and builds orbiting as cel-shaded bodies, binary caches above, and proto traffic as comets.

```sh
nix run . -- --file events/1.log --speed 4
nix run .#release -- --file events/1.log
nix run . -- --url https://gradient.example --token "$TOKEN" --poll 5
godot --path . -- --file events/2.log
```

- `--url` streams `api/v1/metrics/events` and polls `api/v1/board/workers` every `--poll` seconds to color workers by CPU (green-blue-red, unstable at 90%+)
- `--url` also polls `api/v1/board/network`; the telemetry readout shows the measured proto traffic rate and `UTIL` as the average worker network throughput
- `nix run .#release` runs a `--export-release` build on the Godot release template instead of the editor binary
- `--url` also lists caches via `api/v1/caches` (so idle caches show too) and resolves worker names every minute via `api/v1/projects/{project}/workers`
- `--banner 1234` shows the "see your Nix Flake building" banner with Matrix and Dect 1234 after 30 s without worker jobs, NAR or log pushes, or after 10 min without a NAR push; `--banner ""` omits the Dect, no flag hides the banner
- `space` pause, `+` / `-` replay speed, `F11` fullscreen, drag to orbit the camera, wheel to zoom, `q` / `esc` quit
- tests: `tests/run.sh` (headless Godot) or `nix flake check`
- layout: `src/model` simulation (no nodes, fully tested), `src/ingest` event sources, `src/view` per-frame 3D rendering, `src/shaders`
