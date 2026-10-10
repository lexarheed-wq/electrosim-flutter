"""Verify playback and rotation in the compiled production ElectroSim workspace."""
import argparse, functools, http.server, json, threading, io
from pathlib import Path
from playwright.sync_api import sync_playwright
from PIL import Image

p = argparse.ArgumentParser()
p.add_argument('--web-root', required=True)
p.add_argument('--output', required=True)
p.add_argument('--chromium', default='/usr/bin/chromium')
p.add_argument('--ignore-https-errors', action='store_true', help='Test environment proxy certificate workaround only')
a = p.parse_args()
out = Path(a.output); out.mkdir(parents=True, exist_ok=True)
class Quiet(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args): pass
server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), functools.partial(Quiet, directory=a.web_root))
threading.Thread(target=server.serve_forever, daemon=True).start()
errors, media, wav, frames = [], [], [], []
try:
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(executable_path=a.chromium,
            args=['--no-sandbox', '--enable-unsafe-swiftshader'])
        page = browser.new_page(viewport={'width':1550, 'height':1050}, device_scale_factor=1, ignore_https_errors=a.ignore_https_errors)
        page.on('pageerror', lambda e: errors.append(str(e)))
        page.on('requestfailed', lambda r: errors.append('REQUEST_FAILED '+r.url+' '+str(r.failure)))
        page.on('console', lambda m: print('BROWSER_CONSOLE',m.type,m.text) if m.type=='error' else None)
        page.on('console', lambda m: errors.append(m.text) if 'ElectroSim audio:' in m.text else None)
        page.on('response', lambda r: wav.append({'url':r.url, 'status':r.status}) if '.wav' in r.url else None)
        cdp = page.context.new_cdp_session(page)
        cdp.send('Media.enable')
        for event in ['playerEventsAdded', 'playerErrorsRaised', 'playersCreated']:
            cdp.on('Media.'+event, lambda value, event=event: media.append({'event':event, 'data':value}))
        page.goto(f'http://127.0.0.1:{server.server_port}/', wait_until='networkidle', timeout=45000)
        page.wait_for_timeout(5000)
        placeholder = page.locator('flt-semantics-placeholder')
        if placeholder.count(): placeholder.first.dispatch_event('click')
        page.wait_for_timeout(1000)
        page.screenshot(path=str(out/'workspace-before-start.png'))
        page.get_by_role('button', name='Lancer').click(timeout=10000)
        page.wait_for_timeout(1000)
        page.screenshot(path=str(out/'workspace-running.png'))
        for i in range(12):
            frame = Image.open(io.BytesIO(page.screenshot())).convert('RGB')
            frames.append(frame.crop((280, 165, 1270, 1000)))
            page.wait_for_timeout(100)
        frames[0].save(out/'rotation-runtime.gif', save_all=True, append_images=frames[1:], duration=150, loop=0)
        page.get_by_role('button', name='Plus d’actions', exact=True).click()
        page.wait_for_timeout(500)
        page.screenshot(path=str(out/'workspace-sound-menu.png'))
        (out/'semantics-menu.html').write_text(page.content())
        page.get_by_role('menuitem', name='Couper les sons des composants').click(timeout=10000)
        page.wait_for_timeout(500)
        page.get_by_role('button', name='Pause').click()
        page.wait_for_timeout(500)
        page.screenshot(path=str(out/'workspace-paused.png'))
        evidence = {'pageErrors':errors, 'wavResponses':wav, 'mediaEvents':media,
            'frames':len(frames), 'differentFrames':sum(f.tobytes()!=frames[0].tobytes() for f in frames[1:])}
        (out/'playback-evidence.json').write_text(json.dumps(evidence, indent=2))
        values = json.dumps(media)
        assert not errors, errors
        assert any(x['status']==200 for x in wav), 'No successful sound asset response'
        assert 'kPlay' in values, 'Chromium did not report media playback'
        assert 'kPause' in values or 'kStop' in values, 'Chromium did not report playback stopping'
        assert evidence['differentFrames'] > 0, 'Runtime animation stayed stationary'
        print('AUDIO_MOTION_PROOF_PASS', 'sound responses',len(wav),'different frames',evidence['differentFrames'])
        browser.close()
finally:
    (out/'diagnostics.json').write_text(json.dumps({'errors':errors,'media':media,'wav':wav},indent=2))
    server.shutdown()
