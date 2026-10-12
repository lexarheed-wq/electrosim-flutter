"""Drive the production student UI; teacher actions run in the Flutter test."""
import faulthandler
import json
import os
import shutil
import sys
import time
url, output = sys.argv[1:3]
wiring = len(sys.argv) > 3 and sys.argv[3] == 'wiring'
os.makedirs(output, exist_ok=True)
sys.stdout = open(output + '/browser.log', 'w', buffering=1)
sys.stderr = sys.stdout
# Startup must fail or expose its blocked Python stack before the teacher's
# 45-second join deadline; no student action is retried.
faulthandler.dump_traceback_later(25, file=sys.stderr)
print('Importing Playwright driver', flush=True)
from playwright.sync_api import sync_playwright
print('Starting Playwright driver', flush=True)

def signal(phase):
    with open(output + '/' + phase + '.json', 'w') as f:
        json.dump({'phase': phase}, f)

def enable_accessibility(page):
    page.locator('flt-semantics-placeholder').evaluate('(element) => element.click()')

def join(page):
    print('Opening QR URL', url, flush=True)
    page.goto(url, wait_until='domcontentloaded')
    print('Loaded student document', flush=True)
    enable_accessibility(page)
    print('Accessibility enabled', flush=True)
    page.get_by_role('textbox').click()
    print('Student name field focused', flush=True)
    page.wait_for_timeout(150)
    page.keyboard.insert_text('Élève parcours réel')
    page.wait_for_timeout(150)
    page.get_by_role('button', name='Rejoindre la séance').click()
    print('Join submitted', flush=True)

def open_tp(page):
    page.get_by_text('Espace élève', exact=True).wait_for(timeout=30000)
    page.get_by_role('button', name='Ouvrir', exact=True).last.click()
    page.mouse.move(700, 1)
    page.get_by_role('button', name='Gérer la session').wait_for(timeout=30000)

def diagnostic(page, answer):
    page.get_by_role('tab', name='Diagnostic').click()
    page.get_by_role('textbox', name='Symptôme observé').click()
    page.wait_for_timeout(150)
    page.keyboard.insert_text(answer)
    page.wait_for_timeout(150)
    page.get_by_role('button', name='Enregistrer dans le TP').click()

with sync_playwright() as p:
    executable = os.environ.get('CHROMIUM_EXECUTABLE') or shutil.which('chromium')
    print('Launching Chromium', executable or 'Playwright-managed', flush=True)
    browser = p.chromium.launch(
        timeout=20000,
        executable_path=executable,
        headless=True,
        args=['--no-sandbox', '--disable-dev-shm-usage'],
    )
    print('Chromium launched; creating browser context', flush=True)
    context = browser.new_context(viewport={'width': 1440, 'height': 1000})
    print('Browser context created; blocking external HTTPS', flush=True)
    context.route('https://**/*', lambda route: route.abort())
    print('Creating student page', flush=True)
    page = context.new_page()
    print('Student page created', flush=True)
    faulthandler.cancel_dump_traceback_later()
    errors = []
    page.on('pageerror', lambda e: (errors.append(str(e)), print('PAGE ERROR', str(e), flush=True)))
    page.on('request', lambda r: print('EXTERNAL REQUEST', r.url, flush=True) if r.url.startswith('https://') else None)
    page.on('requestfailed', lambda r: print('REQUEST FAILED', r.url, r.failure, flush=True))
    try:
        join(page)
        page.get_by_text('Vous êtes connecté', exact=False).wait_for(timeout=15000)
        page.screenshot(path=output + '/01-waiting.png')
        signal('joined')
        open_tp(page)
        if wiring:
            page.get_by_role('button', name='Ajouter au centre de la platine').nth(0).click()
            page.get_by_role('button', name='Ajouter au centre de la platine').nth(2).click()
            page.wait_for_timeout(500)
            # Let pointer events reach the rendered canvas while accessibility
            # remains enabled for the surrounding form controls.
            page.locator('flt-semantics-host').evaluate("""host => {
                host.__electrosimPointerStyles = [host, ...host.querySelectorAll('*')].map(node =>
                    [node, node.style.getPropertyValue('pointer-events'), node.style.getPropertyPriority('pointer-events')]);
                for (const [node] of host.__electrosimPointerStyles) node.style.setProperty('pointer-events', 'none');
            }""")
            # Connect the physical terminal anchors on the production canvas.
            for start, end in [((672, 727), (506, 769)), ((724, 727), (551, 769))]:
                page.mouse.click(*start)
                page.wait_for_timeout(150)
                page.mouse.click(*end)
                page.wait_for_timeout(200)
            page.mouse.move(528, 670)
            page.mouse.down()
            page.mouse.move(480, 460, steps=10)
            page.mouse.up()
            page.wait_for_timeout(500)
            # Restore Flutter's actual style values. Removing every inline
            # pointer-events value makes noninteractive semantics containers
            # intercept the toolbar on some browser/rendering schedules.
            page.locator('flt-semantics-host').evaluate("""host => {
                for (const [node, value, priority] of host.__electrosimPointerStyles) {
                    if (value) node.style.setProperty('pointer-events', value, priority);
                    else node.style.removeProperty('pointer-events');
                }
                delete host.__electrosimPointerStyles;
            }""")
            page.get_by_role('button', name='Rotation 90°').click()
            page.wait_for_timeout(500)
            print('Wired canvas:', page.locator('body').inner_text(), flush=True)
        else:
            diagnostic(page, 'La lampe reste éteinte, contrôle alimentation')
            page.get_by_text('Entrées enregistrées : 1', exact=True).wait_for()
            page.get_by_role('button', name='Ajouter au centre de la platine').last.click()
        page.screenshot(path=output + '/02-progress.png')
        saved_layouts = page.evaluate("Object.entries(localStorage).filter(([k]) => k.includes('.visual.')).map(([k,v]) => JSON.parse(v))")
        assert len(saved_layouts) == 1, 'Student visual layout was not persisted before rescan'
        original_layout = saved_layouts[0]
        if wiring:
            assert any(original_layout['layout']['quarterTurns'].values()), 'Rotation was not saved'
            assert len(original_layout['layout']['routes']) == 2, 'Wire routes were not saved'
        signal('progress')
        # Wait until the teacher has observed the synchronized work before rescanning.
        deadline = time.monotonic() + 40
        while not os.path.exists(output + '/rescan.json'):
            if time.monotonic() > deadline: raise AssertionError('Teacher did not confirm progress')
            page.wait_for_timeout(100)
        # A new page models opening the QR URL again (not just a live socket retry).
        original_page = page
        page = context.new_page()
        page.on('pageerror', lambda e: errors.append(str(e)))
        join(page)
        open_tp(page)
        if not wiring:
            page.get_by_role('tab', name='Diagnostic').click()
            page.get_by_text('Entrées enregistrées : 1', exact=True).wait_for()
            diagnostic(page, 'Reprise : vérification du câblage')
            page.get_by_text('Entrées enregistrées : 2', exact=True).wait_for()
        page.wait_for_timeout(500)
        resumed_layouts = page.evaluate("Object.entries(localStorage).filter(([k]) => k.includes('.visual.')).map(([k,v]) => JSON.parse(v))")
        assert resumed_layouts == [original_layout], 'Visual layout changed after rescan'
        with open(output + '/visual-resume.json', 'w') as f:
            json.dump({'before': original_layout, 'after': resumed_layouts[0]}, f)
        page.screenshot(path=output + '/03-resumed.png')
        original_page.bring_to_front()
        original_page.screenshot(path=output + '/old-tab.png')
        print('Old tab:', original_page.locator('body').inner_text(), flush=True)
        original_page.get_by_text('Travail repris dans un autre onglet', exact=False).wait_for(timeout=12000)
        page.bring_to_front()
        page.wait_for_timeout(2500)
        if not wiring: page.get_by_text('Entrées enregistrées : 2', exact=True).wait_for()
        signal('resumed')
        page.mouse.move(700, 1)
        page.get_by_role('button', name='Gérer la session').click()
        page.get_by_role('button', name='Remettre le TP').click()
        page.get_by_text('Le TP a été remis. Le montage est désormais en lecture seule.', exact=False).wait_for()
        page.get_by_role('button', name='Fermer', exact=True).click()
        # Attempt a real UI mutation after submission: it must be rejected.
        page.get_by_role('button', name='Ajouter au centre de la platine').last.click()
        page.get_by_text('TP remis : montage en lecture seule.', exact=False).first.wait_for()
        if not wiring:
            assert page.get_by_role('tab', name='Diagnostic').count() == 0
        signal('submitted')
        # The grade must arrive on the real open student page.
        deadline = time.monotonic() + 40
        while not os.path.exists(output + '/graded.json'):
            if time.monotonic() > deadline: raise AssertionError('Teacher did not grade')
            page.wait_for_timeout(100)
        page.mouse.move(700, 1)
        page.get_by_role('button', name='Gérer la session').click()
        page.get_by_text('Score : 81/100', exact=False).wait_for()
        page.screenshot(path=output + '/04-graded.png')
        page.get_by_role('button', name='Fermer', exact=True).click()
        signal('grade_seen')
        page.get_by_text('Séance terminée', exact=False).wait_for(timeout=40000)
        page.screenshot(path=output + '/05-closed.png')
        assert not errors, errors
        signal('closed')
        print(json.dumps({'result': 'PASS', 'errors': errors}), flush=True)
    except Exception:
        page.screenshot(path=output + '/failure.png')
        print(page.locator('body').inner_text(), flush=True)
        print(json.dumps({'errors': errors}), flush=True)
        raise
    finally:
        browser.close()
