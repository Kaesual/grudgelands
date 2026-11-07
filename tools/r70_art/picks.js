/* SPDX-License-Identifier: GPL-3.0-or-later */
'use strict';
(() => {
  const groups = {thread:'Thread', grinder:'Grinder', furnace:'Smelting furnace', iron:'Iron', steel:'Steel', silversteel:'Silversteel', embersteel:'Embersteel', abyssal_steel:'Abyssal Steel'};
  const key = 'grudgelands-r70-art-v1';
  let state = {theme:'system', picks:{}};
  try {
    const saved = JSON.parse(localStorage.getItem(key));
    if (saved && ['system','light','dark'].includes(saved.theme)) state.theme = saved.theme;
    for (const name of Object.keys(groups)) {
      if (saved && saved.picks && ['A','B','C'].includes(saved.picks[name])) state.picks[name] = saved.picks[name];
    }
  } catch (_) { /* The page also works when local storage is unavailable. */ }
  const theme = document.getElementById('theme');
  const summary = document.getElementById('pick-summary');
  const feedback = document.getElementById('feedback');
  function save() {
    try { localStorage.setItem(key, JSON.stringify(state)); } catch (_) { /* Keep in-memory choices. */ }
  }
  function render() {
    const list = document.getElementById('selection-list');
    list.replaceChildren();
    for (const [name, label] of Object.entries(groups)) {
      const item = document.createElement('div'); item.className = 'selection-item';
      const text = document.createElement('span'); text.textContent = label;
      const value = document.createElement('b'); value.textContent = state.picks[name] || '—';
      item.append(text, value); list.append(item);
    }
    summary.value = 'Grudgelands — Round 70 art picks\n' + Object.entries(groups).map(([name,label]) => label + ': ' + (state.picks[name] || '—')).join('\n');
    document.querySelectorAll('input[type=radio]').forEach(input => { input.checked = state.picks[input.name] === input.value; });
    document.documentElement.dataset.theme = state.theme;
    theme.value = state.theme;
  }
  theme.addEventListener('change', () => { state.theme = theme.value; save(); render(); });
  document.querySelectorAll('input[type=radio]').forEach(input => input.addEventListener('change', () => {
    state.picks[input.name] = input.value; feedback.textContent = ''; save(); render();
  }));
  document.getElementById('copy').addEventListener('click', async () => {
    try {
      if (!navigator.clipboard) throw new Error('clipboard unavailable');
      await navigator.clipboard.writeText(summary.value); feedback.textContent = 'Choices copied.';
    } catch (_) {
      summary.focus(); summary.select(); feedback.textContent = 'Text selected. Use your browser’s Copy command.';
    }
  });
  document.getElementById('reset').addEventListener('click', () => {
    state.picks = {}; feedback.textContent = 'Choices cleared.'; save(); render();
  });
  render();
})();
