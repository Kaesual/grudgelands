// Local preview controls only; no network requests or persisted decisions.
const background = document.querySelector('#background');
const scale = document.querySelector('#scale');
const search = document.querySelector('#search');
let group = 'all';
background.addEventListener('change', () => { document.body.dataset.bg = background.value; });
scale.addEventListener('change', () => { document.documentElement.style.setProperty('--native', `${Number(scale.value)}px`); });
function filter() {
  const query = search.value.trim().toLocaleLowerCase('de');
  const visible = new Set();
  document.querySelectorAll('article[data-group]').forEach(card => {
    const show = (group === 'all' || group === card.dataset.group) && (!query || card.dataset.search.includes(query));
    card.hidden = !show;
    if (show) visible.add(card.id);
  });
  document.querySelectorAll('.overview-item').forEach(item => { item.hidden = !visible.has(item.getAttribute('href').slice(1)); });
  document.querySelector('#empty').hidden = visible.size !== 0;
}
search.addEventListener('input', filter);
document.querySelectorAll('[data-filter]').forEach(button => button.addEventListener('click', () => {
  group = button.dataset.filter;
  document.querySelectorAll('[data-filter]').forEach(b => b.classList.toggle('active', b === button));
  filter();
}));
// Deep links must remain reachable after using category/search filters.
function revealHash() {
  if (!location.hash) return;
  const target = document.getElementById(decodeURIComponent(location.hash.slice(1)));
  if (target && target.matches('article') && target.hidden) {
    group = 'all'; search.value = '';
    document.querySelectorAll('[data-filter]').forEach(b => b.classList.toggle('active', b.dataset.filter === 'all'));
    filter(); target.scrollIntoView();
  }
}
window.addEventListener('hashchange', revealHash);
