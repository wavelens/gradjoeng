import math
from dataclasses import dataclass, field

from .fx import Anchor, Vec, ease_in_out

HOP_TIME = 0.9
TRAIL = 22


@dataclass
class Orbit:
    radius: float
    aspect: float
    tilt: float
    speed: float
    phase: float = 0.0

    def advance(self, dt: float) -> None:
        self.phase += self.speed * dt

    def rescale(self, factor: float) -> None:
        self.radius *= factor

    def offset(self, phase: float | None = None) -> Vec:
        angle = self.phase if phase is None else phase
        x, y = math.cos(angle) * self.radius, math.sin(angle) * self.radius * self.aspect
        cos_tilt, sin_tilt = math.cos(self.tilt), math.sin(self.tilt)
        return (x * cos_tilt - y * sin_tilt, x * sin_tilt + y * cos_tilt)

    def path(self, points: int = 64) -> list[Vec]:
        return [self.offset(i * math.tau / points) for i in range(points)]

    def in_front(self, phase: float | None = None) -> bool:
        return math.sin(self.phase if phase is None else phase) >= 0

    def arc(self, front: bool, points: int = 32) -> list[Vec]:
        start = 0.0 if front else math.pi
        return [self.offset(start + i * math.pi / points) for i in range(points + 1)]


def kepler_speed(radius: float, direction: int) -> float:
    return direction * 9.0 / math.sqrt(max(radius, 1.0))


@dataclass
class Electron:
    host: str
    anchor: Anchor
    orbit: Orbit
    pos: Vec
    hop: float = 1.0
    origin: Vec = (0.0, 0.0)
    trail: list[Vec] = field(default_factory=list)

    def __post_init__(self) -> None:
        self.origin = self.pos

    def jump(self, host: str, anchor: Anchor, orbit: Orbit, hold: float = 0.0) -> None:
        self.host, self.anchor, self.orbit = host, anchor, orbit
        self.origin = self.pos
        self.hop = -hold / HOP_TIME

    def update(self, dt: float) -> None:
        self.orbit.advance(dt)
        (cx, cy), (ox, oy) = self.anchor(), self.orbit.offset()
        target = (cx + ox, cy + oy)
        self.hop = min(self.hop + dt / HOP_TIME, 1.0)
        t = ease_in_out(max(self.hop, 0.0))
        self.pos = (self.origin[0] + (target[0] - self.origin[0]) * t, self.origin[1] + (target[1] - self.origin[1]) * t)
        self.trail.append(self.pos)
        del self.trail[:-TRAIL]
