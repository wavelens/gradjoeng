import argparse
from queue import Empty, Queue

import pygame

from .ingest import Ingest, IngestFile, IngestWeb, MetricsPoll, Replay, pump
from .parser import parse
from .renderer import Renderer
from .scene import Scene

FPS = 60
MAX_EVENTS_PER_FRAME = 400
SPEED_STEPS = (0.25, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0, 32.0)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Gradjöng: live view of Gradient CI events")
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--file", help="replay a recorded JSONL event log")
    source.add_argument("--url", help="Gradient base URL, e.g. https://gradient.example")
    parser.add_argument("--token", help="bearer token for --url")
    parser.add_argument("--poll", type=float, default=5.0, help="seconds between worker metric polls for --url")
    parser.add_argument("--speed", type=float, default=1.0, help="replay speed for --file")
    parser.add_argument("--size", default="1280x800", help="window size WIDTHxHEIGHT")
    args = parser.parse_args(argv)
    if args.token and not args.url:
        parser.error("--token requires --url")
    args.size = tuple(int(part) for part in args.size.lower().split("x"))
    return args


def open_ingest(args: argparse.Namespace) -> Ingest:
    if args.url:
        return IngestWeb(args.url, args.token)
    return Replay(IngestFile(args.file), args.speed)


def drain(events: Queue, scene: Scene) -> None:
    for _ in range(MAX_EVENTS_PER_FRAME):
        try:
            event = events.get_nowait()
        except Empty:
            return
        for effect in parse(event):
            scene.apply(effect)


def shift_speed(ingest: Ingest, direction: int) -> None:
    if isinstance(ingest, Replay):
        index = min(range(len(SPEED_STEPS)), key=lambda i: abs(SPEED_STEPS[i] - ingest.speed))
        ingest.speed = SPEED_STEPS[max(0, min(len(SPEED_STEPS) - 1, index + direction))]


def run(ingest: Ingest, events: Queue, renderer: Renderer, scene: Scene) -> None:
    clock = pygame.time.Clock()
    paused = False
    while True:
        dt = min(clock.tick(FPS) / 1000, 0.1)
        for event in pygame.event.get():
            if event.type == pygame.QUIT or (event.type == pygame.KEYDOWN and event.key in (pygame.K_ESCAPE, pygame.K_q)):
                return
            if event.type == pygame.WINDOWSIZECHANGED:
                scene.resize(renderer.resize())
            if event.type == pygame.KEYDOWN and event.key == pygame.K_SPACE:
                paused = not paused
            if event.type == pygame.KEYDOWN and event.key in (pygame.K_PLUS, pygame.K_EQUALS, pygame.K_KP_PLUS):
                shift_speed(ingest, 1)
            if event.type == pygame.KEYDOWN and event.key in (pygame.K_MINUS, pygame.K_KP_MINUS):
                shift_speed(ingest, -1)
        if not paused:
            drain(events, scene)
            scene.update(dt)
        renderer.draw(scene)


def main(argv: list[str] | None = None) -> None:
    args = parse_args(argv)
    ingest = open_ingest(args)
    events: Queue = Queue()
    pump(ingest, events)
    if args.url:
        pump(MetricsPoll(args.url, args.token, args.poll), events)
    try:
        renderer = Renderer(args.size)
        run(ingest, events, renderer, Scene(renderer.screen.get_size()))
    finally:
        pygame.quit()
