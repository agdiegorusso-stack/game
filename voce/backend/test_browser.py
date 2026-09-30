import json
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from server import Service, Problem
from browser.support import identity, score_post

OWN='https://www.linkedin.com/in/test-owner'
P='urn:li:activity:123456789012345'
F='urn:li:share:123456789012346'

class BrowserTest(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.s=Service({'VOCE_DB':str(Path(self.tmp.name)/'db.sqlite3'),'LINKEDIN_MODE':'browser','LINKEDIN_PROFILE_URL':OWN})
        self.posts=[{'id':P,'author_url':OWN,'text':'Un post sul software sanitario.','comments_complete':True}]
        self.comments=[{'id':'comment-42','post_id':P,'author':'Autore test','author_url':'https://www.linkedin.com/in/test-reader','text':'Come controlli i dati?','parent_comment':''}]
        self.feed=[{'id':F,'author':'Autore feed','author_url':'https://www.linkedin.com/in/test-author','text':'Sanità, software e intelligenza artificiale: '+ 'una discussione concreta. '*10,'comments_count':3,'published_at':'2026-09-30T14:00:00Z'}]
    def tearDown(self): self.tmp.cleanup()
    def ingest(self,comments=None,warnings=None):
        self.s.ingest_browser(self.posts,self.comments if comments is None else comments,self.feed,OWN,warnings or [])
    def test_reads_both_queues_and_filters_own_comments(self):
        self.ingest(self.comments+[dict(self.comments[0],id='own',author_url=OWN)])
        self.assertEqual(len(self.s.inbox()['items']),1)
        self.assertEqual(self.s.radar()['items'][0]['source'],'linkedin_browser')
        self.assertTrue(self.s.status()['feed_access'])
        self.assertTrue(self.s.status()['comment_access'])
    def test_duplicate_preserves_done_edit_invalidates_draft(self):
        self.ingest()
        cid=self.s.inbox()['items'][0]['id']
        self.s.dispatch('POST','/v1/inbox/update',{'id':cid,'done':True})
        with self.s.store.db() as db: db.execute('UPDATE comments SET draft=?',(json.dumps({'text':'vecchia'}),))
        self.ingest()
        self.assertTrue(self.s.inbox()['items'][0]['done'])
        self.comments[0]['text']='Una domanda diversa'
        self.ingest()
        item=self.s.inbox()['items'][0]
        self.assertFalse(item['done']); self.assertIsNone(item['draft'])
    def test_partial_snapshot_does_not_delete_unseen_comments(self):
        self.ingest()
        self.ingest([],['Lettura parziale'])
        self.assertEqual(len(self.s.inbox()['items']),1)
        self.assertEqual(self.s.status()['browser']['state'],'partial')
    def test_expired_comments_do_not_reappear_as_new(self):
        self.ingest()
        with self.s.store.db() as db: db.execute('UPDATE comments SET fetched=?',(time.time()-172801,))
        self.ingest()
        self.assertEqual(self.s.inbox()['items'],[])
        self.comments[0]['text']='Modifica dopo la scadenza'
        self.ingest()
        self.assertEqual(len(self.s.inbox()['items']),1)
    def test_stale_and_paused_are_not_connected(self):
        self.ingest()
        b=self.s.store.get('browser_state'); b['at']=time.time()-3000; self.s.store.set('browser_state',b)
        self.assertFalse(self.s.status()['linkedin_connected'])
        self.ingest()
        self.s.dispatch('POST','/v1/browser/control',{'enabled':False})
        self.assertFalse(self.s.status()['feed_access'])
        with self.assertRaises(Problem): self.s.sync(manual=True)
    def test_block_does_not_schedule_automatic_retry(self):
        self.s.store.set('browser_state',{'state':'blocked','message':'Verifica richiesta','at':time.time()})
        with self.assertRaises(Problem): self.s.sync(manual=True)
        self.assertIsNone(self.s.store.get('browser_control'))
    def test_wrong_identity_and_url_rejected(self):
        for url in ('https://linkedin.com.evil.test/in/test','https://x@linkedin.com/in/test','http://linkedin.com/in/test','https://linkedin.com:bad/in/test'):
            self.assertEqual(identity(url),'')
        with self.assertRaises(Problem): self.s.ingest_browser(self.posts,self.comments,self.feed,'https://www.linkedin.com/in/other',[])
        with self.assertRaises(ValueError):
            self.s.ingest_browser(self.posts,self.comments,[dict(self.feed[0],id='file:/etc/passwd')],OWN,[])
        self.assertEqual(self.s.inbox()['items'],[])
    def test_radar_auto_draft_once_uses_actual_content(self):
        self.ingest()
        self.s.store.set('profile',{'profile':'Autore test','voice':'Italiano diretto'})
        with patch.object(self.s,'generate',return_value={'text':'Un commento concreto.'}) as generate, patch.object(self.s.stop_event,'wait',return_value=False):
            self.s.auto_radar();self.s.auto_radar()
            generate.assert_called_once()
            self.assertEqual(generate.call_args.args[0]['text'],self.feed[0]['text'].strip())
        self.assertEqual(self.s.radar()['items'][0]['draft']['text'],'Un commento concreto.')
    def test_own_reply_marks_handled_and_low_relevance_not_generated(self):
        self.comments[0]['already_replied']=True
        self.feed[0]['text']='Una fotografia del mare.'
        self.ingest()
        self.assertTrue(self.s.inbox()['items'][0]['done'])
        with patch.object(self.s,'generate') as generate:
            self.s.auto_radar()
            generate.assert_not_called()
    def test_no_public_ingestion_or_publish_routes(self):
        for path in ('/v1/browser/ingest','/v1/publish','/v1/browser/cookies'):
            with self.assertRaises(Problem): self.s.dispatch('POST',path,{})

if __name__=='__main__': unittest.main()
