import json
import tempfile
import threading
import time
import unittest
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import parse_qs, urlparse
from urllib.request import Request, urlopen
from http.server import ThreadingHTTPServer
from server import Service, Problem, handler_for, linkedin_url

URN = 'urn:li:ugcPost:1234567890123'

class BackendTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.env = {'VOCE_DB': str(Path(self.tmp.name) / 'db.sqlite3')}
        self.calls = []
        self.responses = []
        def transport(url, **kwargs):
            self.calls.append((url, kwargs))
            value = self.responses.pop(0)
            if isinstance(value, Exception):
                raise value
            return value
        self.service = Service(self.env, transport)

    def tearDown(self):
        self.tmp.cleanup()

    def enable_linkedin(self):
        self.service.env.update(LINKEDIN_ACCESS_TOKEN='dummy', LINKEDIN_SCOPES='r_member_social_feed')
        self.service.register_post({'urn': URN, 'text': 'Il mio post originale', 'url': 'https://www.linkedin.com/feed/update/urn:li:activity:1234567890123/'})

    def comment(self, text='Una domanda?', cid='1'):
        return {'id': cid, 'commentUrn': f'urn:li:comment:(urn:li:activity:12345,{cid})', 'actor': 'urn:li:person:test', 'message': {'text': text}}

    def test_no_credentials_is_explicit(self):
        self.assertFalse(self.service.status()['comment_access'])
        self.assertFalse(self.service.status()['feed_access'])
        with self.assertRaises(Problem): self.service.sync()
        with self.assertRaises(Problem): self.service.generate({'kind': 'post'})

    def test_url_and_urn_validation(self):
        for bad in ['https://linkedin.com.evil.test/x', 'http://linkedin.com/x', 'https://user@linkedin.com/x']:
            self.assertFalse(linkedin_url(bad))
        self.assertTrue(linkedin_url('https://it.linkedin.com/posts/abc'))
        with self.assertRaises(Problem):
            self.service.register_post({'urn': 'urn:li:activity:123456', 'text': 'test', 'url': 'https://linkedin.com/x'})

    def test_sync_deduplicates_preserves_handled_and_invalidates_edited(self):
        self.enable_linkedin()
        self.responses.append({'elements': [self.comment()]})
        self.assertEqual(self.service.sync()['added'], 1)
        item = self.service.inbox()['items'][0]
        cid = item['id']
        self.service.dispatch('POST', '/v1/inbox/update', {'id': cid, 'done': True})
        with self.service.store.db() as db:
            db.execute('UPDATE comments SET draft=? WHERE id=?', (json.dumps({'text': 'Bozza vecchia'}), cid))
        self.responses.append({'elements': [self.comment()]})
        self.assertEqual(self.service.sync()['added'], 0)
        updated = self.service.inbox()['items'][0]
        self.assertTrue(updated['done'])
        self.assertEqual(updated['fetched_at'], item['fetched_at'])
        self.responses.append({'elements': [self.comment('Domanda modificata')]})
        self.service.sync()
        edited = self.service.inbox()['items'][0]
        self.assertFalse(edited['done'])
        self.assertIsNone(edited['draft'])

    def test_pagination_and_nested_comments(self):
        self.enable_linkedin()
        first = self.comment(cid='1')
        first['commentsSummary'] = {'totalFirstLevelComments': 1}
        self.responses.extend([
            {'elements': [first], 'paging': {'links': [{'rel': 'next'}]}},
            {'elements': [self.comment(cid='2')]},
            {'elements': [self.comment('Replica', '3')]},
        ])
        self.assertEqual(self.service.sync()['added'], 3)
        self.assertIn('start=1', self.calls[1][0])
        nested = [i for i in self.service.inbox()['items'] if i['text'] == 'Replica'][0]
        self.assertEqual(nested['parent_comment'], 'Una domanda?')
        self.assertIn('urn%3Ali%3Acomment', self.calls[2][0])

    def test_expired_content_and_post_removal(self):
        self.enable_linkedin()
        self.responses.append({'elements': [self.comment()]})
        self.service.sync()
        with self.service.store.db() as db:
            db.execute('UPDATE comments SET fetched=?', (time.time() - 172801,))
        self.assertEqual(self.service.inbox()['items'], [])
        self.service.dispatch('POST', '/v1/posts/remove', {'urn': URN})
        self.assertEqual(self.service.status()['posts'], [])

    def test_rate_limit_is_visible(self):
        self.enable_linkedin()
        self.responses.append(Problem('Limite del servizio raggiunto', 429))
        result = self.service.sync()
        self.assertEqual(len(result['errors']), 1)
        self.assertIn('Limite', self.service.status()['posts'][0]['error'])
        self.assertEqual(self.service.inbox()['items'], [])

    def test_oauth_state_once_expiry_and_actual_scope(self):
        s = self.service
        s.env.update(LINKEDIN_CLIENT_ID='id', LINKEDIN_CLIENT_SECRET='secret', LINKEDIN_REDIRECT_URI='https://voce.example/oauth/linkedin/callback', LINKEDIN_SCOPES='r_member_social_feed')
        state = parse_qs(urlparse(s.oauth_start()['url']).query)['state'][0]
        self.responses.append({'access_token': 'returned-token', 'expires_in': 100, 'scope': 'openid'})
        s.oauth_callback({'state': [state], 'code': ['code']})
        self.assertEqual(s.token(), 'returned-token')
        self.assertFalse(s.status()['comment_access'])
        with self.assertRaises(Problem): s.oauth_callback({'state': [state], 'code': ['code']})
        s.store.set('linkedin', {'access_token': 'expired', 'expires_at': time.time() - 1})
        self.assertEqual(s.token(), '')

    def test_oauth_rejects_expired_state(self):
        s = self.service
        s.env.update(LINKEDIN_CLIENT_ID='id', LINKEDIN_CLIENT_SECRET='secret', LINKEDIN_REDIRECT_URI='https://voce.example/oauth/linkedin/callback', LINKEDIN_SCOPES='r_member_social_feed')
        state = parse_qs(urlparse(s.oauth_start()['url']).query)['state'][0]
        with s.store.db() as db: db.execute('UPDATE oauth SET created=?', (time.time() - 601,))
        with self.assertRaises(Problem): s.oauth_callback({'state': [state], 'code': ['code']})
        self.assertEqual(self.calls, [])

    def test_model_validates_output_and_preserves_context(self):
        self.service.env.update(OPENAI_API_KEY='dummy', OPENAI_MODEL='test-model')
        self.responses.append({'choices': [{'message': {'content': json.dumps({'text': 'Una proposta concreta.', 'checks': ['Verifica il dato.']})}}]})
        result = self.service.generate({'kind': 'reply', 'profile': 'Infermiere', 'voice': 'Diretto', 'text': 'Domanda', 'parent_post': 'Post originale'})
        self.assertEqual(result['text'], 'Una proposta concreta.')
        submitted = self.calls[0][1]['data']
        self.assertFalse(submitted['store'])
        self.assertEqual(json.loads(submitted['messages'][1]['content'])['parent_post'], 'Post originale')
        self.service.last_ai = 0
        self.responses.append({'choices': [{'message': {'content': 'Non è JSON'}}]})
        with self.assertRaises(Problem):
            self.service.generate({'kind': 'post', 'profile': 'x', 'voice': 'y', 'text': 'z'})

    def test_http_auth_limits_and_no_publish_endpoint(self):
        server = ThreadingHTTPServer(('127.0.0.1', 0), handler_for(self.service, 'x' * 40))
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        base = f'http://127.0.0.1:{server.server_port}'
        try:
            with self.assertRaises(HTTPError) as caught: urlopen(base + '/v1/status')
            self.assertEqual(caught.exception.code, 401)
            headers = {'Authorization': 'Bearer ' + 'x' * 40}
            with urlopen(Request(base + '/v1/status', headers=headers)) as response:
                self.assertFalse(json.load(response)['feed_access'])
            with self.assertRaises(HTTPError) as caught:
                urlopen(Request(base + '/v1/publish', data=b'{}', headers=headers))
            self.assertEqual(caught.exception.code, 404)
            with self.assertRaises(HTTPError) as caught:
                urlopen(Request(base + '/v1/generate', data=b'x' * 100001, headers=headers))
            self.assertEqual(caught.exception.code, 413)
        finally:
            server.shutdown(); server.server_close(); thread.join()

    def test_automatic_reply_is_prepared_once_and_delivered_in_inbox(self):
        self.enable_linkedin()
        self.service.env.update(OPENAI_API_KEY='dummy', OPENAI_MODEL='test-model', AUTO_DRAFT='true')
        self.service.store.set('profile', {'profile': 'Infermiere sviluppatore', 'voice': 'Italiano diretto'})
        self.responses.extend([
            {'elements': [self.comment()]},
            {'choices': [{'message': {'content': json.dumps({'text': 'Inizierei osservando il passaggio concreto.', 'checks': []})}}]},
        ])
        self.service.sync()
        self.assertIn('osservando', self.service.inbox()['items'][0]['draft']['text'])
        self.responses.append({'elements': [self.comment()]})
        self.service.sync()
        self.assertEqual(len(self.calls), 3)


if __name__ == '__main__': unittest.main(verbosity=2)
