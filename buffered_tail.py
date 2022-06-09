from aiohttp import web
import asyncio
from io import BytesIO
from pathlib import Path
import subprocess
import sys
import typing as t


class ProcessReader:
    def __init__(self, outbox: asyncio.Queue, proc: asyncio.subprocess.Process):
        self._outbox = outbox
        self._proc = proc

    @classmethod
    async def create(cls, outbox: asyncio.Queue, program: t.Union[str, Path], *argv: str):
        proc = await asyncio.create_subprocess_exec(str(program), *argv, stdout=subprocess.PIPE)
        return cls(outbox, proc)

    async def watch(self):
        while True:
            line = await self._proc.stdout.readline()
            await self._outbox.put(line)
        await self._proc.wait()


class HttpHandler:
    def __init__(self, inbox: asyncio.Queue):
        self._inbox = inbox

    def _read_all(self) -> bytes:
        out = BytesIO()
        while not self._inbox.empty():
            try:
                out.write(self._inbox.get_nowait())
            except asyncio.QueueEmpty:
                continue
            self._inbox.task_done()
        return out.getvalue()

    async def read_next(self, request):
        message = await self._inbox.get()
        self._inbox.task_done()
        return web.Response(body=message)

    async def read_all(self, request):
        message = self._read_all()
        return web.Response(body=message)

    async def size(self, request):
        size = self._inbox.qsize()
        return web.Response(text=str(size))


async def init(loop: asyncio.BaseEventLoop, program: Path, argv: t.List[str]) -> web.Application:
    queue = asyncio.Queue()

    print("Launching", program, ' '.join(argv))
    reader = await ProcessReader.create(queue, program, *argv)
    print("Watching output")
    loop.create_task(reader.watch())

    handler = HttpHandler(queue)
    app = web.Application()
    app.add_routes([
        web.get('/flush', handler.read_all),
        web.get('/wait', handler.read_next),
        web.get('/size', handler.size),
    ])
    return app

import logging
logging.getLogger('aiohttp').setLevel(logging.DEBUG)

loop = asyncio.new_event_loop()
loop.set_debug(True)
pyright = Path() / "node_modules" / ".bin" / "pyright"
web.run_app(init(loop, pyright, sys.argv), loop=loop, path='aio_socket')
