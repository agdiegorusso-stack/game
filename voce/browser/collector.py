"""Dedicated browser process. Reads rendered posts/comments; never publishes.
Run from the project root: python3 -m browser.collector login | run | once
Credentials are entered by the user in the browser, never in this program.
"""
import argparse
import json
import os
from pathlib import Path
import re
import sys
import time
from urllib.parse import parse_qs, urlparse

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'backend'))
from server import Service
from browser.support import identity, post_url, score_post, URN

EXTRACT = (Path(__file__).parent / 'extract.js').read_text()
CARDS = '.feed-shared-update-v2[data-urn], [role="listitem"][componentkey^="update-card-focus"]'

class NeedsUser(Exception):
    def __init__(self, state, message):
        self.state = state
        super().__init__(message)

class Collector:
    def __init__(self, service, context):
        self.service = service
        self.context = context
        self.own = identity(service.env.get('LINKEDIN_PROFILE_URL', ''))
        if not self.own:
            raise ValueError('Imposta LINKEDIN_PROFILE_URL con il tuo profilo LinkedIn.')
        self.page = context.new_page()
        self.page.set_default_timeout(12000)
        self.warnings = []

    def check(self, check_pause=True):
        u = urlparse(self.page.url)
        # Read page body, not scripts, cookies or browser storage. Challenge iframes
        # alone are not a block: LinkedIn may load these on normal pages too.
        body = self.page.locator('body').inner_text(timeout=10000)[:14000].lower()
        if re.search(r'verify you are human|verifica di essere una persona|unusual activity|attività insolita|temporarily restricted|account.*(?:restricted|limitato)|security verification|verifica di sicurezza', body) or '/checkpoint/' in u.path:
            raise NeedsUser('blocked', 'LinkedIn richiede una verifica. Raccolta sospesa: apri il browser sul computer e verifica l’account.')
        if u.path.startswith(('/login', '/uas/login', '/authwall')) or ('accedi' in body and 'password' in body and not self.page.locator(CARDS).count()):
            raise NeedsUser('login_required', 'Sessione scaduta: apri il browser dedicato sul computer e accedi di nuovo.')
        if u.hostname not in ('www.linkedin.com', 'linkedin.com'):
            raise NeedsUser('login_required', 'Completa l’accesso nel browser dedicato.')
        if check_pause and self.service.store.get('browser_control', {}).get('enabled', True) is False:
            raise NeedsUser('paused', 'Raccolta sospesa dall’app.')

    def navigate(self, url):
        if urlparse(url).hostname not in ('www.linkedin.com', 'linkedin.com'):
            raise ValueError('La raccolta naviga soltanto LinkedIn.')
        response = self.page.goto(url, wait_until='domcontentloaded', timeout=45000)
        if response and response.status in (403, 429):
            raise NeedsUser('blocked', 'LinkedIn ha rifiutato la richiesta. Raccolta sospesa; nessun tentativo di aggiramento.')
        self.check()
        try:
            self.page.locator(CARDS).first.wait_for(state='attached', timeout=20000)
        except Exception:
            self.check()
            raise NeedsUser('layout_changed', 'Post non riconosciuti. Controlla la pagina nel browser; nessuna sincronizzazione dichiarata riuscita.') from None
        self.check()

    def card(self, item):
        if item['layout'] == 'legacy':
            return self.page.locator('[data-urn=' + json.dumps(item['id']) + ']').first
        return self.page.locator('[componentkey=' + json.dumps(item['key']) + ']').first

    def read_cards(self, limit):
        result = {}
        # Limited visible scrolling, no hidden endpoints and no request replay.
        for _ in range(4):
            self.check()
            for item in self.page.evaluate(EXTRACT, {'ownProfile': self.own}):
                result[item['id'] or item['key']] = item
            if len(result) >= limit:
                break
            before = len(result)
            self.page.mouse.wheel(0, 900)
            self.page.wait_for_timeout(900)
            self.check()
            for item in self.page.evaluate(EXTRACT, {'ownProfile': self.own}):
                result[item['id'] or item['key']] = item
            if len(result) == before:
                break
        return list(result.values())[:limit]

    def resolve(self, item):
        if URN.fullmatch(item.get('id', '')):
            item['url'] = post_url(item['id'])
            return True
        card = self.card(item)
        trigger = card.get_by_role('button', name=re.compile(r'(Apri il menu dei controlli per il post di|Open control menu for post by)'))
        if trigger.count() != 1:
            return False
        trigger.click()
        self.check()
        try:
            # The regular Embed menu link exposes the content URN. No clipboard access.
            link = self.page.locator('a[href*="/embed-modal/"]').filter(visible=True).first
            link.wait_for(state='visible', timeout=5000)
            urn = parse_qs(urlparse(link.get_attribute('href')).query).get('targetUrn', [''])[0]
            if not URN.fullmatch(urn):
                return False
            item['id'] = urn
            item['url'] = post_url(urn)
            return True
        except Exception:
            self.check()
            return False
        finally:
            self.page.keyboard.press('Escape')

    def read_comments(self, item):
        card = self.card(item)
        button = card.get_by_role('button', name=re.compile(r'^\d+ comment[oi](?: al post|$)|^\d+ comments?'))
        if button.count():
            button.first.click()
        else:
            button = card.get_by_role('button', name=re.compile(r'^(Commenta|Comment)$'))
            if button.count(): button.first.click()
        self.page.wait_for_timeout(800)
        self.check()
        sort = card.get_by_role('button', name=re.compile(r'ordinamento attualmente|Current selected sort order'))
        sorted_all = False
        if sort.count():
            sort.first.click()
            self.check()
            option = self.page.get_by_role('option', name=re.compile(r'^(Più recenti|Most recent)'))
            if not option.count():
                option = self.page.get_by_text(re.compile(r'^(Più recenti|Most recent)$'))
            if option.count():
                option.first.click()
                sorted_all = True
            else:
                self.page.keyboard.press('Escape')
        # Bounded expansion. A partial thread remains explicitly partial.
        for _ in range(12):
            self.check()
            more = card.get_by_role('button', name=re.compile(r'^(Carica altri commenti|Mostra altri commenti|Load more comments|Show more comments|Visualizza .*rispost|Mostra .*rispost|View .*repl|Show .*repl)', re.I))
            visible = [b for b in more.all() if b.is_visible()]
            if not visible: break
            visible[0].click()
            self.page.wait_for_timeout(600)
        current = self.page.evaluate(EXTRACT, {'ownProfile': self.own})
        updated = next((p for p in current if p['id'] == item['id'] or (p['key'] and p['key'] == item.get('key'))), None)
        comments = updated['comments'] if updated else []
        expected = item.get('comments_count')
        complete = sorted_all and isinstance(expected, int) and len(comments) >= expected
        if expected == 0: complete = True
        if not complete:
            self.warnings.append('Commenti letti parzialmente su almeno un post; LinkedIn può nascondere altre risposte.')
        return comments, complete

    def cycle(self):
        self.warnings = []
        started = time.time()
        self.service.store.set('browser_state', {**self.service.store.get('browser_state', {}), 'state':'collecting', 'at':started})
        own_posts, feed, comments = [], [], []
        self.navigate(self.own + '/recent-activity/all/?skipRedirect=true')
        candidates = self.read_cards(10)
        if not any(identity(p['author_url']) == self.own for p in candidates):
            raise NeedsUser('wrong_profile', 'Il profilo aperto non corrisponde al profilo configurato.')
        for item in candidates:
            if identity(item['author_url']) != self.own or not self.resolve(item):
                continue
            own_posts.append(item)
            try:
                rows, complete = self.read_comments(item)
                item['comments_complete'] = complete
                comments.extend({**c, 'post_id':item['id'], 'url':item['url'], 'parent_post':item['text']} for c in rows)
            except NeedsUser:
                raise
            except Exception:
                self.check()
                item['comments_complete'] = False
                self.warnings.append('Un thread non è stato letto: riproverò al prossimo ciclo.')
        self.navigate('https://www.linkedin.com/feed/')
        profile = self.service.store.get('profile', {})
        interests = profile.get('interests', ['sanità', 'infermier', 'healthtech', 'intelligenza artificiale', 'ai', 'nutrizione', 'software'])
        candidates = self.read_cards(20)
        candidates.sort(key=lambda p:score_post(p, interests), reverse=True)
        for item in candidates:
            if item['sponsored'] or identity(item['author_url']) == self.own:
                continue
            if not self.resolve(item):
                self.warnings.append('Un post del feed non ha un collegamento riconoscibile ed è stato saltato.')
                continue
            item['editorial_score'] = score_post(item, interests)
            feed.append(item)
            if len(feed) >= 10: break
        if not own_posts or not feed:
            raise NeedsUser('layout_changed', 'Raccolta incompleta: manca la lettura dei post personali o del feed.')
        self.service.ingest_browser(own_posts, comments, feed, self.own, list(dict.fromkeys(self.warnings)))
        return {'posts':len(own_posts), 'comments':len(comments), 'feed':len(feed)}


def load_config():
    config = ROOT / '.env'
    if config.exists():
        for line in config.read_text().splitlines():
            key, sep, value = line.strip().partition('=')
            if sep and key.replace('_','').isalnum(): os.environ.setdefault(key, value)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['login', 'run', 'once'])
    args = parser.parse_args()
    load_config()
    if os.environ.get('LINKEDIN_MODE') != 'browser':
        raise SystemExit('Imposta LINKEDIN_MODE=browser in .env.')
    from playwright.sync_api import sync_playwright
    service = Service()
    directory = Path(os.environ.get('VOCE_BROWSER_PROFILE', str(ROOT / 'browser' / 'private-profile'))).resolve()
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(directory, 0o700)
    with sync_playwright() as pw:
        context = pw.chromium.launch_persistent_context(str(directory), headless=False if args.command == 'login' else os.environ.get('VOCE_BROWSER_HEADLESS', 'false').lower() == 'true', chromium_sandbox=True, accept_downloads=False, viewport={'width':1280,'height':900}, locale='it-IT')
        try:
            if args.command == 'login':
                page = context.pages[0] if context.pages else context.new_page()
                page.goto('https://www.linkedin.com/feed/', wait_until='domcontentloaded')
                print('Accedi a LinkedIn nel browser, con Google se lo preferisci. Completa eventuali verifiche direttamente nel browser.')
                input('Quando vedi il tuo feed, premi Invio qui. ')
                collector = Collector(service, context)
                collector.page = page
                collector.check(check_pause=False)
                if not page.locator('a[href*="/in/"]').count():
                    raise NeedsUser('login_required', 'Accesso non verificato.')
                service.store.set('browser_state', {'state':'idle','at':time.time(),'message':'Sessione pronta; avvia la raccolta.'})
                print('Sessione conservata nel profilo browser privato. Avvia il comando run.')
                return
            collector = Collector(service, context)
            interval = max(900, int(os.environ.get('POLL_SECONDS','900')))
            next_run = 0
            last_request = None
            while True:
                control = service.store.get('browser_control', {})
                if control.get('enabled', True) is False:
                    service.store.set('browser_state', {'state':'paused','at':time.time(),'message':'Raccolta sospesa dall’app.'})
                elif time.time() >= next_run or control.get('request') != last_request:
                    previous = service.store.get('browser_state', {})
                    if previous.get('state') in ('blocked','login_required','wrong_profile'):
                        print('Serve un intervento nel browser: esegui il comando login. Nessun nuovo tentativo automatico.')
                        return
                    try:
                        result = collector.cycle()
                        print('Lettura completata:', result)
                    except NeedsUser as exc:
                        service.store.set('browser_state', {'state':exc.state,'at':time.time(),'message':str(exc)})
                        print(str(exc))
                        if exc.state == 'paused' and args.command == 'run':
                            next_run = 0
                            continue
                        return
                    except Exception:
                        service.store.set('browser_state', {'state':'error','at':time.time(),'message':'Raccolta interrotta. Controlla il browser e riavvia il servizio.'})
                        print('Raccolta interrotta. Nessuna sincronizzazione dichiarata riuscita.')
                        return
                    last_request = control.get('request')
                    next_run = time.time() + interval
                    if args.command == 'once': return
                time.sleep(5)
        finally:
            context.close()

if __name__ == '__main__': main()
