/* SPDX-License-Identifier: GPL-3.0-or-later */
'use strict';
(() => {
  const theme = document.getElementById('theme');
  const summary = document.getElementById('pick-summary');
  const feedback = document.getElementById('feedback');
  const key = 'grudgelands-r70-art-v1';
  try {
    const saved = JSON.parse(localStorage.getItem(key));
    if (saved && ['system','light','dark'].includes(saved.theme)) theme.value = saved.theme;
  } catch (_) { /* Optional storage; old trial picks never override confirmed picks. */ }
  function setTheme() {
    document.documentElement.dataset.theme = theme.value;
    try { localStorage.setItem(key, JSON.stringify({theme:theme.value})); } catch (_) { /* In-memory theme. */ }
  }
  theme.addEventListener('change', setTheme);
  setTheme();
  document.getElementById('copy').addEventListener('click', async () => {
    try {
      if (!navigator.clipboard) throw new Error('clipboard unavailable');
      await navigator.clipboard.writeText(summary.value); feedback.textContent = 'Confirmed choices copied.';
    } catch (_) {
      summary.focus(); summary.select(); feedback.textContent = 'Text selected. Use your browser’s Copy command.';
    }
  });
  const scenes = Array.from(document.querySelectorAll('.animation img'));
  const toggle = document.getElementById('fire-toggle');
  const status = document.getElementById('fire-status');
  const reduced = window.matchMedia('(prefers-reduced-motion: reduce)');
  let paused = false, timer = null, start = 0, lastFrame = -1;
  function paint(frame) {
    if (frame === lastFrame) return;
    scenes.forEach(img => { img.style.transform = `translateY(${-frame * 12.5}%)`; });
    lastFrame = frame;
  }
  function step(now) {
    paint(Math.floor((now - start) / 187.5) % 8);
    timer = requestAnimationFrame(step);
  }
  function update() {
    if (timer !== null) cancelAnimationFrame(timer);
    timer = null;
    const stopped = paused || reduced.matches;
    toggle.disabled = reduced.matches;
    toggle.textContent = reduced.matches ? 'Fire still (reduced motion)' : paused ? 'Play fire' : 'Pause fire';
    toggle.setAttribute('aria-pressed', String(stopped));
    status.textContent = stopped ? 'Still frame · 8 frames, 0.1875 s each · light 8.' : 'Playing · 8 frames, 0.1875 s each · light 8.';
    if (stopped) paint(0);
    if (!stopped && !document.hidden) { start = performance.now(); timer = requestAnimationFrame(step); }
  }
  toggle.addEventListener('click', () => { paused = !paused; update(); });
  reduced.addEventListener('change', update);
  document.addEventListener('visibilitychange', update);
  update();
})();
