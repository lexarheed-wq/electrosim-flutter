"""Drive the production student UI; teacher actions run in the Flutter test."""
import json, sys, os, time, shutil
from playwright.sync_api import sync_playwright
url, output = sys.argv[1:3]
wiring = len(sys.argv) > 3 and sys.argv[3] == 'wiring'
os.makedirs(output, exist_ok=True)
sys.stdout = open(output + '/browser.log', 'w', buffering=1)
sys.stderr = sys.stdout

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
    page.get_by_role('textbox').click()
    page.wait_for_timeout(150)
    page.keyboard.insert_text('Élève parcours réel')
    page.wait_for_timeout(150)
    page.get_by_role('button', name='Rejoindre la séance').click()

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
    browser = p.chromium.launch(executable_path=os.environ.get('CHROMIUM_EXECUTABLE') or shutil.which('chromium'), headless=True, args=['--no-sandbox', '--disable-dev-shm-usage'])
    context = browser.new_context(viewport={'width': 1440, 'height': 1000})
    page = context.new_page()
    errors = []
    page.on('pageerror', lambda e: (errors.append(str(e)), print('PAGE ERROR', str(e), flush=True)))
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
            page.locator('flt-semantics-host').evaluate("e => [e, ...e.querySelectorAll('*')].forEach(n => n.style.pointerEvents = 'none')")
            # Connect the physical terminal anchors on the production canvas.
            for start, end in [((672, 727), (506, 769)), ((724, 727), (551, 769))]:
                page.mouse.click(*start)
                page.wait_for_timeout(150)
                page.mouse.click(*end)
                page.wait_for_timeout(200)
            page.locator('flt-semantics-host').evaluate("e => [e, ...e.querySelectorAll('*')].forEach(n => n.style.pointerEvents = '')")
            print('Wired canvas:', page.locator('body').inner_text(), flush=True)
        else:
            diagnostic(page, 'La lampe reste éteinte, contrôle alimentation')
            page.get_by_text('Entrées enregistrées : 1', exact=True).wait_for()
            page.get_by_role('button', name='Ajouter au centre de la platine').last.click()
        page.screenshot(path=output + '/02-progress.png')
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
