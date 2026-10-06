#!/usr/bin/env python3
"""Read-only JetKVM health probe.

Logs in to each JetKVM given on the command line, opens a real WebRTC session
and asks the device for its state over the "rpc" data channel. Nothing is
changed on the device, and no keyboard/mouse input is sent to the host.

Needs aiortc + aiohttp, which are not installed system-wide:

    python3 -m venv /tmp/jetkvm-venv
    /tmp/jetkvm-venv/bin/pip install aiortc aiohttp
    /tmp/jetkvm-venv/bin/python jetkvm-probe.py 192.168.1.151 192.168.1.158 192.168.1.191 192.168.1.198

The password is read from ~/.jetkvm (override with JETKVM_PW_FILE).

Verified against firmware app 0.5.9 / system 0.2.8. Signaling goes over the
websocket endpoint because the legacy HTTP POST /webrtc/session returns 404 on
that firmware.
"""
import asyncio
import base64
import json
import os
import sys

import aiohttp
from aiortc import RTCPeerConnection, RTCSessionDescription

# Read-only JSON-RPC methods; a method the firmware lacks just comes back as an error.
METHODS = ["getDeviceID", "getVideoState", "getUSBState", "getLocalVersion", "getNetworkState"]


async def signal(session, ip, pc):
    """Exchange SDP over the websocket signaling endpoint. The full offer is
    sent after ICE gathering completes, so no trickle candidates are needed."""
    await pc.setLocalDescription(await pc.createOffer())
    while pc.iceGatheringState != "complete":
        await asyncio.sleep(0.1)
    offer = {"type": pc.localDescription.type, "sdp": pc.localDescription.sdp}
    sd = base64.b64encode(json.dumps(offer).encode()).decode()
    async with session.ws_connect(f"http://{ip}/webrtc/signaling/client") as ws:
        await ws.send_json({"type": "offer", "data": {"sd": sd}})
        async for msg in ws:
            if msg.type != aiohttp.WSMsgType.TEXT or msg.data == "pong":
                continue
            data = json.loads(msg.data)
            if data.get("type") == "answer":
                answer = json.loads(base64.b64decode(data["data"]))
                await pc.setRemoteDescription(RTCSessionDescription(answer["sdp"], answer["type"]))
                return True
    print("  signaling websocket closed without an answer")
    return False


async def query(pc, channel):
    """Send each read-only RPC once the data channel opens and print the replies."""
    opened, replies = asyncio.Event(), {}
    channel.on("open", lambda: opened.set())

    def on_message(msg):
        data = json.loads(msg)
        if "id" in data:
            replies[data["id"]] = data

    channel.on("message", on_message)
    await asyncio.wait_for(opened.wait(), 15)
    print(f"  rpc data channel open, ice={pc.iceConnectionState}")
    for i, method in enumerate(METHODS):
        channel.send(json.dumps({"jsonrpc": "2.0", "id": i, "method": method, "params": {}}))
    await asyncio.sleep(3)
    for i, method in enumerate(METHODS):
        reply = replies.get(i)
        out = "no reply" if reply is None else json.dumps(reply.get("result", reply.get("error")))
        print(f"  {method}: {out[:200]}")


async def probe(ip, password):
    """Probe one JetKVM; failures are reported and do not stop the remaining devices."""
    print(f"== {ip}")
    jar = aiohttp.CookieJar(unsafe=True)  # unsafe=True: accept the auth cookie from a bare IP
    async with aiohttp.ClientSession(cookie_jar=jar, timeout=aiohttp.ClientTimeout(total=20)) as session:
        async with session.post(f"http://{ip}/auth/login-local", json={"password": password}) as r:
            print(f"  login http={r.status}")
            if r.status != 200:
                return
        pc = RTCPeerConnection()
        # The device expects a video transceiver in the offer. aiortc does not
        # decode the stream (0 frames arrive), so getVideoState is the device's
        # own report of the HDMI input, not a picture we looked at.
        pc.addTransceiver("video", direction="recvonly")
        channel = pc.createDataChannel("rpc")
        try:
            if await signal(session, ip, pc):
                await query(pc, channel)
        except Exception as e:
            print(f"  failed: {type(e).__name__}: {e}")
        finally:
            await pc.close()


async def main():
    pw_file = os.environ.get("JETKVM_PW_FILE", os.path.expanduser("~/.jetkvm"))
    password = open(pw_file).read().strip()
    for ip in sys.argv[1:]:
        await probe(ip, password)


asyncio.run(main())
