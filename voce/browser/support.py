"""Validation, ranking and browser snapshots; independent from browser runtime."""
import hashlib
import re
from datetime import datetime, timezone
from urllib.parse import urlparse

URN = re.compile(r'^urn:li:(?:activity|share|ugcPost):[0-9]{5,30}$')

def identity(url):
    try:
        parsed = urlparse(url or '')
        port = parsed.port
    except ValueError:
        return ''
    if parsed.scheme != 'https' or parsed.hostname not in ('www.linkedin.com', 'linkedin.com') or parsed.username or port:
        return ''
    if not re.fullmatch(r'/in/[^/]+/?', parsed.path):
        return ''
    return 'https://www.linkedin.com' + parsed.path.rstrip('/')

def post_url(urn):
    if not URN.fullmatch(urn or ''):
        raise ValueError('Identificatore del post non valido.')
    return 'https://www.linkedin.com/feed/update/' + urn + '/'

def fingerprint(item):
    return hashlib.sha256(('\0'.join(str(item.get(k, '')) for k in ('text', 'parent_post', 'parent_comment'))).encode()).hexdigest()

def score_post(post, interests, now=None):
    text = post['text'].lower()
    matches = []
    for term in dict.fromkeys(t.strip().lower() for t in interests if isinstance(t, str)):
        if term and (re.search(r'(?<!\w)' + re.escape(term) + r'(?!\w)', text) if len(term) <= 2 else term in text):
            matches.append(term)
    relevance = min(55, 18 * len(matches))
    fresh = 0
    try:
        date = datetime.fromisoformat(post.get('published_at', '').replace('Z', '+00:00'))
        hours = ((now or datetime.now(timezone.utc)) - date).total_seconds()/3600
        fresh = 20 if 0 <= hours <= 6 else 14 if 6 < hours <= 24 else 6 if 24 < hours <= 72 else 0
    except (ValueError, TypeError, AttributeError):
        pass
    count = post.get('comments_count')
    room = 0 if not isinstance(count, (int, float)) or count < 0 else 15 if count < 10 else 10 if count < 50 else 5 if count < 200 else 0
    return min(100, relevance + fresh + room + (10 if len(text) >= 180 else 0))
