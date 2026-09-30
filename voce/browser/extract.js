/* Read rendered LinkedIn content only. No cookies, storage, private APIs or writes. */
(arg = {}) => {
  const clean = s => (s || '').replace(/\bhashtag\s*\n/g, '').replace(/…\s*(altro|more)\s*$/i, '').trim();
  const text = e => clean(e?.innerText || '');
  const profile = href => {
    try { const u = new URL(href); return u.origin + u.pathname.replace(/\/$/, ''); } catch { return ''; }
  };
  const count = s => /^\d[\d.,\s]*$/.test((s || '').trim()) ? Number(s.replace(/[.,\s]/g, '')) : null;
  const age = s => {
    const m = (s || '').match(/^(\d+)\s*(minuti?|minutes?|mins?|ore?|hours?|hrs?|giorni?|days?|settimane?|weeks?|mesi|months?|[mhgdws])\b/i);
    if (!m) return null;
    const unit = m[2].toLowerCase();
    const hours = /^(min|m$)/.test(unit) ? 1/60 : /^(or|hour|hr|h$)/.test(unit) ? 1 : /^(gior|day|[gd]$)/.test(unit) ? 24 : /^(sett|week|[ws]$)/.test(unit) ? 168 : 720;
    return new Date(Date.now() - Number(m[1]) * hours * 3600000).toISOString();
  };
  const cards = [...document.querySelectorAll('.feed-shared-update-v2[data-urn], [role="listitem"][componentkey^="update-card-focus"]')];
  return cards.filter(e => !e.parentElement?.closest('.feed-shared-update-v2[data-urn]')).map(e => {
    const legacy = e.hasAttribute('data-urn');
    const menu = [...e.querySelectorAll('button')].find(b => /(?:menu.*post di|control menu.*post by)/i.test(b.getAttribute('aria-label') || ''));
    const title = menu?.getAttribute('aria-label') || '';
    const actor = legacy ? e.querySelector('.update-components-actor__meta-link') : [...e.querySelectorAll('a[href*="/in/"],a[href*="/company/"]')].find(a => text(a) && title.includes(text(a).split('\n')[0]));
    const author = legacy ? text(e.querySelector('.update-components-actor__title')).split('\n')[0] : text(actor).split('\n')[0];
    const paragraph = legacy ? e.querySelector('.update-components-text') : [...e.querySelectorAll('p')].find(p => p.querySelector('[data-testid="expandable-text-button"]'));
    const body = text(paragraph);
    const time = legacy ? text(e.querySelector('.update-components-actor__sub-description')).split('\n')[0] : [...e.querySelectorAll('p')].map(text).find(t => /^\d+\s*(?:min|[hgdws]|ore|giorn|day|hour|week)/i.test(t)) || '';
    const buttons = [...e.querySelectorAll('button')];
    const commentButton = legacy ? buttons.find(b => /\d+ comment[oi]|\d+ comments?/.test(b.getAttribute('aria-label') || '')) : buttons.find(b => /^(Commenta|Comment)$/i.test(b.getAttribute('aria-label') || ''));
    const commentsCount = legacy ? Number((commentButton?.getAttribute('aria-label') || '').match(/\d+/)?.[0] ?? NaN) : count(text(commentButton));
    const articles = [...e.querySelectorAll('article[data-id]')];
    const ownText = (a, selector) => [...a.querySelectorAll(selector)].find(n => n.closest('article[data-id]') === a);
    const comments = articles.map(a => {
      const link = ownText(a, '.comments-comment-meta__description-container');
      const parent = a.parentElement?.closest('article[data-id]');
      const ownUrl = profile(arg.ownProfile || '');
      return {
        id: a.getAttribute('data-id'),
        author: text(link).split('\n')[0], author_url: profile(link?.href),
        text: text(ownText(a, '.comments-comment-item__main-content')),
        parent_comment: parent ? text(ownText(parent, '.comments-comment-item__main-content')) : '',
        already_replied: [...a.querySelectorAll('article[data-id] .comments-comment-meta__description-container')].some(n => ownUrl && profile(n.href) === ownUrl),
      };
    }).filter(c => c.id && c.author && c.text);
    return {
      id: e.getAttribute('data-urn') || '', key: e.getAttribute('componentkey') || '',
      layout: legacy ? 'legacy' : 'sdui', author, author_url: profile(actor?.href), text: body,
      published_at: age(time), age_label: time, date_approximate: true,
      comments_count: Number.isFinite(commentsCount) ? commentsCount : null,
      sponsored: /(?:^|\n)\s*(?:Post sponsorizzato|Promosso da|Promoted|Sponsored)\b/im.test(e.innerText),
      comments,
    };
  }).filter(p => p.text && p.author);
}
