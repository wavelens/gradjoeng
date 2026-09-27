# gradjoeng

Live view of Gradient CI events: server core, orbiting workers, evaluations with their builds, binary caches, and proto traffic as comets.

```sh
nix run . -- --file events/1.log --speed 4
nix develop -c python -m gradjoeng --file events/2.log
nix run . -- --url https://gradient.example --token "$TOKEN" --poll 5
```

- `--url` streams `api/v1/metrics/events` and polls `api/v1/board/workers` every `--poll` seconds to color workers by CPU (green-blue-red, unstable at 90%+)

- `space` pause, `+` / `-` replay speed, `q` / `esc` quit
- tests: `nix develop -c pytest` or `nix flake check`
