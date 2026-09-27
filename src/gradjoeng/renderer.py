import math
import random

import pygame

from .fx import Color, Comet, Echo, Ripple, Spark, Vec, cpu_color, state_color
from .orbit import Electron
from .scene import Build, Cache, Evaluation, Scene, Worker

TITLE = "Gradjöng Live View"
SUBTITLE = ("Modern Nix CI System", "Github: wavelens/gradient")
BANNER = ("Want to see your Nix Flake building?", "Matrix: @derdennisop:matrix.org   Dect: 1234")
BACKGROUND = (0, 0, 0)
HALO_COLOR = (120, 70, 200)
PHOTON_RING = (255, 225, 180)
DISK_PARTICLES = 360
DISK_BANDS = (1.5, 1.9, 2.4, 2.9, 3.3)
DISK_TILT = -0.22
DISK_SEGMENTS = 96
ORBIT_SEGMENTS = 160
DISK_ASPECT = 0.26
WORKER_COLOR = (60, 220, 255)
CACHE_COLOR = (90, 130, 255)
LINK_COLOR = (22, 30, 55)
LINK_PACKET_COLOR = (120, 200, 255)
LINK_LANE = 3
LINK_PACKETS = 24
LINK_DASH = 14
LINK_SPEED = 0.35
TONE_COLORS: dict[str, Color] = {"good": (60, 240, 130), "bad": (255, 70, 90), "info": (170, 180, 220)}
STAR_COUNT = 220
GLOW_CACHE_LIMIT = 768


def scale(color: Color, factor: float) -> Color:
    return tuple(max(0, min(255, int(channel * factor))) for channel in color)


def ipos(pos: Vec) -> tuple[int, int]:
    return int(pos[0]), int(pos[1])


class Renderer:
    def __init__(self, size: tuple[int, int]):
        pygame.init()
        pygame.display.set_caption(TITLE)
        self.screen = pygame.display.set_mode(size, pygame.RESIZABLE)
        self.canvas = pygame.Surface(self.screen.get_size())
        self.font = pygame.font.SysFont("dejavusansmono,monospace", 13)
        self.title_font = pygame.font.SysFont("dejavusansmono,monospace", 48, bold=True)
        self.subtitle_font = pygame.font.SysFont("dejavusansmono,monospace", 24)
        self.stars = [(random.random(), random.random(), random.uniform(0.2, 1.0)) for _ in range(STAR_COUNT)]
        self.glows: dict[tuple[int, Color], pygame.Surface] = {}
        self.disk = [(random.uniform(1.4, 3.4) ** 1.0, random.uniform(0, math.tau), random.uniform(2.0, 5.0)) for _ in range(DISK_PARTICLES)]

    def resize(self) -> tuple[int, int]:
        self.screen = pygame.display.get_surface()
        self.canvas = pygame.Surface(self.screen.get_size())
        return self.screen.get_size()

    def draw(self, scene: Scene) -> None:
        self.canvas.fill(BACKGROUND)
        self._starfield(scene)
        self._links(scene)
        self._orbits(scene, front=False)
        self._ripples(scene)
        self._comets(scene)
        self._echoes(scene)
        self._evaluations(scene, front=False)
        self._server(scene)
        self._orbits(scene, front=True)
        self._caches(scene)
        self._workers(scene)
        self._evaluations(scene, front=True)
        self._sparks(scene)
        self._hud(scene)
        self._present(scene)

    def glow(self, radius: float, color: Color) -> pygame.Surface:
        key = (max(2, int(radius)), tuple(c & ~7 for c in color))
        if key not in self.glows:
            if len(self.glows) > GLOW_CACHE_LIMIT:
                self.glows.clear()
            self.glows[key] = self._render_glow(*key)
        return self.glows[key]

    @staticmethod
    def _render_glow(radius: int, color: Color) -> pygame.Surface:
        surface = pygame.Surface((radius * 2, radius * 2))
        for r in range(radius, 0, -1):
            pygame.draw.circle(surface, scale(color, (1 - r / radius) ** 1.6), (radius, radius), r)
        return surface

    def _add_glow(self, pos: Vec, radius: float, color: Color) -> None:
        surface = self.glow(radius, color)
        half = surface.get_width() // 2
        self.canvas.blit(surface, (int(pos[0]) - half, int(pos[1]) - half), special_flags=pygame.BLEND_RGB_ADD)

    def _starfield(self, scene: Scene) -> None:
        width, height = self.canvas.get_size()
        for x, y, depth in self.stars:
            px = ((x + scene.time * 0.006 * depth) % 1.0) * width
            twinkle = 0.6 + 0.4 * math.sin(scene.time * 2 * depth + x * 40)
            self.canvas.set_at((int(px), int(y * height)), scale((150, 160, 255), depth * twinkle * 0.7))

    def _links(self, scene: Scene) -> None:
        for worker in scene.workers.values():
            self._link(scene, scene.server_pos(), worker.pos, 0.5 + worker.heat)

    def _link(self, scene: Scene, start: Vec, end: Vec, energy: float) -> None:
        dx, dy = end[0] - start[0], end[1] - start[1]
        length = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / length * LINK_LANE, dx / length * LINK_LANE
        pygame.draw.line(self.canvas, scale(LINK_COLOR, 1.2 * energy), start, end, int(LINK_LANE * 3))
        for side in (-1, 1):
            lane = lambda t, side=side: (start[0] + dx * t + nx * side, start[1] + dy * t + ny * side)
            pygame.draw.aaline(self.canvas, scale(LINK_COLOR, 2.5 * energy), lane(0), lane(1))
            for i in range(LINK_PACKETS):
                flow = (i / LINK_PACKETS + scene.time * LINK_SPEED * side * 1000 / length) % 1.0
                (x0, y0), (x1, y1) = lane(flow), lane(min(flow + LINK_DASH / length, 1.0))
                pygame.draw.aaline(self.canvas, scale(LINK_PACKET_COLOR, 0.5 + 0.5 * energy), (x0, y0), (x1, y1))

    def _ripples(self, scene: Scene) -> None:
        for ripple in (f for f in scene.fx if isinstance(f, Ripple)):
            radius = int(ripple.current_radius)
            if radius > ripple.width:
                pygame.draw.aacircle(self.canvas, scale(ripple.color, ripple.fade), ripple.anchor(), radius, ripple.width)

    def _orbits(self, scene: Scene, front: bool) -> None:
        for evaluation in scene.evaluations.values():
            color = scale(state_color(evaluation.phase), evaluation.alpha * (0.22 + evaluation.flash * 0.4))
            self._orbit_line(evaluation.electron, color, evaluation.electron.orbit.arc(front, ORBIT_SEGMENTS // 2), closed=False)
            if not front:
                continue
            for build in evaluation.visible_builds:
                if not build.electron.host.startswith("evaluation:"):
                    color = scale(state_color(build.state), evaluation.alpha * 0.3)
                    self._orbit_line(build.electron, color, build.electron.orbit.path(ORBIT_SEGMENTS), closed=True)

    def _orbit_line(self, electron: Electron, color: Color, points: list[Vec], closed: bool) -> None:
        cx, cy = electron.anchor()
        pygame.draw.aalines(self.canvas, color, closed, [(cx + x, cy + y) for x, y in points])

    def _trail(self, trail: list[Vec], color: Color, width: float) -> None:
        for i in range(1, len(trail)):
            fade = i / len(trail)
            pygame.draw.line(self.canvas, scale(color, fade * 0.9), trail[i - 1], trail[i], max(1, int(width * fade)))

    def _comets(self, scene: Scene) -> None:
        for comet in (f for f in scene.fx if isinstance(f, Comet)):
            trail = comet.trail
            self._trail(trail, comet.color, comet.size)
            if trail:
                self._add_glow(trail[-1], comet.size * 4, scale(comet.color, 0.8))
                pygame.draw.circle(self.canvas, (255, 255, 255), ipos(trail[-1]), max(1, int(comet.size * 0.7)))

    def _echoes(self, scene: Scene) -> None:
        for echo in (f for f in scene.fx if isinstance(f, Echo)):
            pos, swell = echo.pos, math.sin(math.pi * echo.progress)
            self._add_glow(pos, 10 + 20 * echo.strength, scale(echo.color, echo.strength * 0.9))
            for ring in range(3):
                radius = 4 + ring * 7 + swell * 10
                fade = echo.strength * (1 - ring / 3) * (0.4 + 0.6 * swell)
                pygame.draw.aacircle(self.canvas, scale(echo.color, fade), pos, radius, 1 + int(echo.strength * 2))

    def _server(self, scene: Scene) -> None:
        center = scene.server_pos()
        horizon = scene.unit * 0.045
        energy = 0.8 + scene.core_flash * 0.6
        self._add_glow(center, horizon * 5 + scene.core_flash * 30, scale(HALO_COLOR, 0.5 * energy))
        self._add_glow(center, horizon * 2.2, scale((255, 170, 90), 0.55 * energy))
        self._accretion_disk(scene, center, horizon, energy, front=False)
        pygame.draw.circle(self.canvas, BACKGROUND, ipos(center), int(horizon))
        pygame.draw.aacircle(self.canvas, scale((255, 150, 70), energy * 0.8), center, horizon * 1.25, 3)
        pygame.draw.aacircle(self.canvas, scale(PHOTON_RING, energy), center, horizon * 1.06, 2)
        self._accretion_disk(scene, center, horizon, energy, front=True)
        self._label("GRADIENT", (center[0], center[1] + horizon * 3.6), (210, 180, 150))

    def _accretion_disk(self, scene: Scene, center: Vec, horizon: float, energy: float, front: bool) -> None:
        def project(reach: float, angle: float) -> Vec:
            x, y = math.cos(angle) * reach * horizon, math.sin(angle) * reach * horizon * DISK_ASPECT
            return (center[0] + x * math.cos(DISK_TILT) - y * math.sin(DISK_TILT), center[1] + x * math.sin(DISK_TILT) + y * math.cos(DISK_TILT))

        def disk_color(reach: float, angle: float) -> Color:
            heat = max(0.0, min((3.4 - reach) / 2.0, 1.0))
            doppler = 0.5 + 0.5 * math.cos(angle + math.pi / 2)
            return scale((255, int(110 + 130 * heat), int(30 + 190 * heat**2)), energy * (0.3 + 0.7 * doppler) * (0.4 + 0.6 * heat))

        start = 0.0 if front else math.pi
        for reach in DISK_BANDS:
            arc = [start + math.pi * i / DISK_SEGMENTS for i in range(DISK_SEGMENTS + 1)]
            for a, b in zip(arc, arc[1:]):
                color = scale(disk_color(reach, (a + b) / 2), 0.7)
                (x0, y0), (x1, y1) = project(reach, a), project(reach, b)
                pygame.draw.aaline(self.canvas, color, (x0, y0), (x1, y1))
                pygame.draw.aaline(self.canvas, color, (x0, y0 + 1), (x1, y1 + 1))
        for reach, phase, size in self.disk:
            angle = phase + scene.time * 2.4 / reach**1.5
            if (math.sin(angle) > 0) == front:
                self._add_glow(project(reach, angle), size * 2.2, disk_color(reach, angle))

    def _caches(self, scene: Scene) -> None:
        for cache in scene.caches.values():
            pygame.draw.aaline(self.canvas, scale(CACHE_COLOR, 0.25 + cache.flash * 0.5), scene.server_pos(), cache.pos)
            self._cache(cache)

    def _cache(self, cache: Cache) -> None:
        x, y = cache.pos
        radius = 18 + cache.flash * 4
        hexagon = [(x + math.cos(i * math.tau / 6) * radius, y + math.sin(i * math.tau / 6) * radius) for i in range(6)]
        self._add_glow(cache.pos, 45 + cache.flash * 30, scale(CACHE_COLOR, 0.6 + cache.flash * 0.8))
        pygame.draw.polygon(self.canvas, scale(CACHE_COLOR, 0.9 + cache.flash * 0.4), hexagon)
        pygame.draw.polygon(self.canvas, scale((220, 230, 255), 0.7 + cache.flash * 0.3), hexagon, 2)
        self._label(f"cache {cache.id[:8]}", (x, y + 32), scale(CACHE_COLOR, 1.3))
        stats = f"hit {cache.hits}  miss {cache.misses}  {cache.served / 1e6:.1f} MB"
        self._label(stats, (x, y + 48), (140, 150, 190))

    def _workers(self, scene: Scene) -> None:
        for worker in scene.workers.values():
            color = WORKER_COLOR if worker.cpu is None else cpu_color(worker.cpu)
            self._worker(scene, worker, color)
            label = f"worker {worker.id[:8]}" if worker.cpu is None else f"worker {worker.id[:8]}  {worker.cpu:.0f}%"
            self._label(label, (worker.pos[0], worker.pos[1] - 42), scale(color, 0.9))

    def _worker(self, scene: Scene, worker: Worker, color: Color) -> None:
        pos, heat = worker.pos, worker.heat
        pulse = 0.5 + 0.5 * math.sin(scene.time * 3 + pos[0] * 0.01)
        if worker.unstable:
            pos = (pos[0] + random.uniform(-3, 3), pos[1] + random.uniform(-3, 3))
            heat = max(heat, random.random())
        self._add_glow(pos, 60 + heat * 40 + pulse * 6, scale(color, 0.7 + heat * 0.6))
        pygame.draw.circle(self.canvas, scale(color, 0.9 + heat * 0.3), ipos(pos), 24)
        pygame.draw.circle(self.canvas, scale((210, 245, 255), 0.85 + heat * 0.15), ipos(pos), 15)

    def _evaluations(self, scene: Scene, front: bool) -> None:
        for evaluation in scene.evaluations.values():
            if evaluation.behind != front:
                self._evaluation(evaluation)

    def _evaluation(self, evaluation: Evaluation) -> None:
        color = state_color(evaluation.phase)
        alpha = evaluation.alpha
        self._trail(evaluation.electron.trail, scale(color, alpha), 5)
        self._add_glow(evaluation.pos, 22 + evaluation.flash * 30, scale(color, alpha * (0.6 + evaluation.flash * 0.8)))
        pygame.draw.circle(self.canvas, scale(color, alpha * 1.2), ipos(evaluation.pos), 7)
        pygame.draw.circle(self.canvas, scale((255, 255, 255), alpha), ipos(evaluation.pos), 3)
        for build in evaluation.visible_builds:
            self._build(build, alpha)
        self._label(evaluation.label, (evaluation.pos[0], evaluation.pos[1] - 20), scale((230, 230, 245), alpha))
        self._label(evaluation.phase, (evaluation.pos[0], evaluation.pos[1] + 20), scale(color, alpha))

    def _build(self, build: Build, alpha: float) -> None:
        color = state_color(build.state)
        self._trail(build.electron.trail[-10:], scale(color, alpha * 0.8), 2)
        self._add_glow(build.pos, 16 + build.flash * 20, scale(color, alpha * (1.1 + build.flash)))
        pygame.draw.circle(self.canvas, scale(color, alpha * 1.6), ipos(build.pos), 4)
        pygame.draw.circle(self.canvas, scale((255, 255, 255), alpha), ipos(build.pos), 2)

    def _sparks(self, scene: Scene) -> None:
        for spark in (f for f in scene.fx if isinstance(f, Spark)):
            color = scale(spark.color, spark.fade)
            self._add_glow(spark.pos, spark.size * 3, color)
            pygame.draw.circle(self.canvas, scale((255, 255, 255), spark.fade), ipos(spark.pos), max(1, int(spark.size * 0.5)))

    def _hud(self, scene: Scene) -> None:
        self.canvas.blit(self.title_font.render("GRADIENT CI // LIVE", True, (200, 190, 255)), (24, 18))
        top = 24 + self.title_font.get_linesize()
        for row, text in enumerate(SUBTITLE):
            self.canvas.blit(self.subtitle_font.render(text, True, (140, 150, 190)), (24, top + row * self.subtitle_font.get_linesize()))
        if scene.banner > 0:
            self._banner(scene.banner)
        bottom = self.canvas.get_height() - 22
        for row, line in enumerate(scene.headlines):
            fade = max(1 - (scene.time - line.born) / 20, 0.15) * (1 - row * 0.08)
            self.canvas.blit(self.font.render(line.text, True, scale(TONE_COLORS.get(line.tone, TONE_COLORS["info"]), fade)), (18, bottom - row * 16))

    def _banner(self, alpha: float) -> None:
        width, height = self.canvas.get_size()
        middle = (width // 2, int(height * 0.82))
        headline = self.title_font.render(BANNER[0], True, scale((230, 220, 255), alpha))
        contact = self.subtitle_font.render(BANNER[1], True, scale((140, 150, 190), alpha))
        self.canvas.blit(headline, headline.get_rect(midbottom=middle))
        self.canvas.blit(contact, contact.get_rect(midtop=(middle[0], middle[1] + 8)))

    def _label(self, text: str, pos: Vec, color: Color) -> None:
        surface = self.font.render(text, True, color)
        self.canvas.blit(surface, surface.get_rect(center=ipos(pos)))

    def _present(self, scene: Scene) -> None:
        amount = scene.shake * 10
        offset = (random.uniform(-amount, amount), random.uniform(-amount, amount))
        self.screen.fill(BACKGROUND)
        self.screen.blit(self.canvas, offset)
        pygame.display.flip()
