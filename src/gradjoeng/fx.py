import math
import random
from dataclasses import dataclass, field
from typing import Callable

Vec = tuple[float, float]
Color = tuple[int, int, int]
Anchor = Callable[[], Vec]

TRAIL = 14

STATE_COLORS: dict[str, Color] = {
    "created": (90, 100, 130),
    "queued": (120, 130, 180),
    "waiting": (120, 130, 180),
    "evaluating": (255, 200, 70),
    "fetching": (255, 160, 60),
    "building": (60, 150, 255),
    "retrying": (255, 130, 40),
    "completed": (50, 240, 120),
    "substituted": (60, 225, 235),
    "failed": (255, 50, 80),
    "dependency_failed": (220, 50, 140),
    "timeout": (255, 90, 30),
    "aborted": (140, 140, 150),
}

MESSAGE_COLORS: tuple[tuple[str, Color], ...] = (
    ("log", (70, 255, 140)),
    ("cache", (80, 150, 255)),
    ("known", (80, 150, 255)),
    ("nar", (235, 80, 255)),
    ("job", (255, 170, 50)),
    ("credential", (255, 235, 80)),
    ("metrics", (150, 150, 210)),
)

CPU_GRADIENT: tuple[Color, ...] = ((50, 240, 120), (60, 150, 255), (255, 50, 80))

PULSE_COLORS: dict[str, Color] = {"graph": (170, 90, 255), "cache": (80, 150, 255)}


def state_color(state: str | None) -> Color:
    return STATE_COLORS.get(state or "", (200, 200, 210))


def message_color(kind: str) -> Color:
    return next((color for key, color in MESSAGE_COLORS if key in kind), (220, 220, 255))


def ease_in_out(t: float) -> float:
    return t * t * (3 - 2 * t)


def ease_out(t: float) -> float:
    return 1 - (1 - t) ** 3


@dataclass
class Comet:
    source: Anchor
    target: Anchor
    color: Color
    size: float
    duration: float
    bend: float
    on_arrive: Callable[[], None] | None = None
    age: float = 0.0
    trail: list[Vec] = field(default_factory=list)

    @property
    def progress(self) -> float:
        return min(self.age / self.duration, 1.0)

    @property
    def pos(self) -> Vec:
        (x0, y0), (x1, y1) = self.source(), self.target()
        cx = (x0 + x1) / 2 - (y1 - y0) * self.bend
        cy = (y0 + y1) / 2 + (x1 - x0) * self.bend
        t = ease_in_out(self.progress)
        u = 1 - t
        return (u * u * x0 + 2 * u * t * cx + t * t * x1, u * u * y0 + 2 * u * t * cy + t * t * y1)

    def update(self, dt: float) -> bool:
        self.age += dt
        self.trail.append(self.pos)
        del self.trail[:-TRAIL]
        if self.age < self.duration:
            return True
        if self.on_arrive:
            self.on_arrive()
        return False


@dataclass
class Echo:
    source: Anchor
    target: Anchor
    color: Color
    strength: float
    duration: float
    on_arrive: Callable[[], None] | None = None
    age: float = 0.0

    @property
    def progress(self) -> float:
        return min(self.age / self.duration, 1.0)

    @property
    def pos(self) -> Vec:
        (x0, y0), (x1, y1) = self.source(), self.target()
        t = ease_in_out(self.progress)
        return (x0 + (x1 - x0) * t, y0 + (y1 - y0) * t)

    def update(self, dt: float) -> bool:
        self.age += dt
        if self.age < self.duration:
            return True
        if self.on_arrive:
            self.on_arrive()
        return False


@dataclass
class Spark:
    pos: Vec
    velocity: Vec
    color: Color
    life: float
    size: float = 2.0
    age: float = 0.0

    @property
    def fade(self) -> float:
        return max(1 - self.age / self.life, 0.0)

    def update(self, dt: float) -> bool:
        self.age += dt
        drag = 0.12 ** dt
        vx, vy = self.velocity[0] * drag, self.velocity[1] * drag + 40 * dt
        self.velocity = (vx, vy)
        self.pos = (self.pos[0] + vx * dt, self.pos[1] + vy * dt)
        return self.age < self.life


@dataclass
class Ripple:
    anchor: Anchor
    color: Color
    radius: float
    life: float
    width: int = 2
    age: float = 0.0

    @property
    def fade(self) -> float:
        return max(1 - self.age / self.life, 0.0)

    @property
    def current_radius(self) -> float:
        return self.radius * ease_out(min(self.age / self.life, 1.0))

    def update(self, dt: float) -> bool:
        self.age += dt
        return self.age < self.life


def burst(pos: Vec, color: Color, count: int, speed: float, life: float = 1.2) -> list[Spark]:
    sparks = []
    for _ in range(count):
        angle = random.uniform(0, math.tau)
        velocity = random.uniform(0.3, 1.0) * speed
        sparks.append(Spark(pos, (math.cos(angle) * velocity, math.sin(angle) * velocity), color, random.uniform(0.5, 1.0) * life, random.uniform(1.5, 3.5)))
    return sparks


def cpu_color(percent: float) -> Color:
    position = min(max(percent, 0.0), 100.0) / 100 * (len(CPU_GRADIENT) - 1)
    index = min(int(position), len(CPU_GRADIENT) - 2)
    t = position - index
    start, end = CPU_GRADIENT[index], CPU_GRADIENT[index + 1]
    return tuple(int(a + (b - a) * t) for a, b in zip(start, end))
