// Round 51 lane WRECK: the verdict and note per element (the storage
// contract of the Round 51 pages). Collection `notes`, document id = the
// element's key (characters outside letters, digits and `_ - . ~ : @ +` become
// `_`; no key here has one), fields {key, verdict, text, updatedAt}. One
// subscription on the collection; a write on blur, on a verdict click, only
// when something changed and one at a time per document; a document with no
// text and no verdict is deleted. Without `db` (opened locally, or refused)
// the notes are read-only. Stored text is untrusted: textContent / .value only.
/* exported WreckNotes */
var WreckNotes = (function () {
	'use strict';

	var VERDICTS = [['pick', 'Pick'], ['rework', 'Rework'], ['drop', 'Drop']];
	var items = {};          // key -> {verdict, text, saved: {verdict, text}, ui, busy, again}
	var db = null, writable = false, ready = false;

	function docId(key) { return key.replace(/[^A-Za-z0-9_.~:@+-]/g, '_'); }

	function banner(text) { document.getElementById('notes-banner').textContent = text; }

	function setStatus(it, text, err) {
		it.ui.status.textContent = text;
		it.ui.status.classList.toggle('err', !!err);
	}

	function paint(it) {
		it.ui.buttons.forEach(function (b) {
			b.setAttribute('aria-pressed', b.dataset.v === it.verdict ? 'true' : 'false');
			b.disabled = !writable;
		});
		if (document.activeElement !== it.ui.text) { it.ui.text.value = it.text; }
		it.ui.text.readOnly = !writable;
	}

	function save(key) {
		var it = items[key];
		if (!db || !writable) { return; }
		if (it.busy) { it.again = true; return; }
		var verdict = it.verdict, text = it.text;
		if (verdict === it.saved.verdict && text === it.saved.text) { return; }
		it.busy = true;
		setStatus(it, 'Saving…');
		var ref = db.collection('notes').doc(docId(key));
		var op = (!verdict && !text.trim()) ? ref.delete() :
			ref.set({key: key, verdict: verdict, text: text, updatedAt: new Date().toISOString()});
		op.then(function () {
			it.saved = {verdict: verdict, text: text};
			setStatus(it, 'Saved');
		}, function (e) {
			var code = e && e.code ? e.code : 'error';
			if (code === 'invalid_argument' || code === 'not_granted' || code === 'revoked') {
				writable = false;
				Object.keys(items).forEach(function (k) { paint(items[k]); });
				banner('Notes are read-only here: this view may not write them.');
			}
			setStatus(it, 'Not saved (' + code + (e && e.message ? ': ' + e.message : '') + ').', true);
		}).then(function () {
			it.busy = false;
			if (it.again) { it.again = false; save(key); }
		});
	}

	// One element's verdict buttons, note field and status line, appended to el.
	function attach(el, key, withVerdict) {
		var box = document.createElement('div');
		var ui = {buttons: [], text: null, status: null};
		if (withVerdict !== false) {
			var row = document.createElement('div');
			row.className = 'wk-verdicts';
			row.setAttribute('role', 'group');
			row.setAttribute('aria-label', 'Verdict for ' + key);
			VERDICTS.forEach(function (v) {
				var b = document.createElement('button');
				b.type = 'button';
				b.id = 'verdict-' + docId(key) + '-' + v[0];
				b.dataset.v = v[0];
				b.textContent = v[1];
				b.onclick = function () {
					var it = items[key];
					it.verdict = it.verdict === v[0] ? '' : v[0];
					paint(it);
					save(key);
				};
				ui.buttons.push(b);
				row.appendChild(b);
			});
			box.appendChild(row);
		}
		var ta = document.createElement('textarea');
		ta.id = 'note-' + docId(key);
		ta.setAttribute('aria-label', 'Note for ' + key);
		ta.placeholder = 'Note';
		ta.addEventListener('input', function () { items[key].text = ta.value; });
		ta.addEventListener('blur', function () { items[key].text = ta.value; save(key); });
		ui.text = ta;
		box.appendChild(ta);
		var st = document.createElement('div');
		st.className = 'wk-status';
		st.setAttribute('role', 'status');
		ui.status = st;
		box.appendChild(st);
		el.appendChild(box);
		var it = items[key];
		if (!it) {
			it = items[key] = {verdict: '', text: '', saved: {verdict: '', text: ''}, busy: false, again: false};
		}
		it.ui = ui;
		paint(it);
	}

	function apply(snap) {
		snap.docChanges().forEach(function (ch) {
			var d = ch.type === 'removed' ? null : ch.doc.data();
			var key = d && typeof d.key === 'string' ? d.key : ch.doc.id;
			var it = items[key];
			if (!it) {
				it = items[key] = {verdict: '', text: '', saved: {verdict: '', text: ''}, busy: false, again: false};
			}
			var verdict = d && typeof d.verdict === 'string' ? d.verdict : '';
			var text = d && typeof d.text === 'string' ? d.text : '';
			// keep what the viewer is typing; take everything else
			var typing = it.ui && document.activeElement === it.ui.text && it.text !== it.saved.text;
			it.saved = {verdict: verdict, text: text};
			it.verdict = verdict;
			if (!typing) { it.text = text; }
			if (it.ui) { paint(it); }
		});
	}

	// Rendered first, lit up when db resolves (or stays read-only).
	function start() {
		banner('Connecting the notes…');
		var use = window.claude && typeof window.claude.use === 'function' ? window.claude.use('db') : null;
		if (!use) {
			banner('Opened locally: notes are read-only. On the published page you can leave a verdict and a note per shape and detail.');
			return;
		}
		Promise.resolve(use).then(function (handle) {
			if (!handle) {
				banner('Notes are read-only in this view. They can be left on the published page.');
				return;
			}
			db = handle;
			writable = true;
			ready = true;
			banner('');
			Object.keys(items).forEach(function (k) { if (items[k].ui) { paint(items[k]); } });
			db.collection('notes').onSnapshot(apply, function (e) {
				banner('Notes stopped updating (' + (e && e.code ? e.code : 'error') + '). Reload the page to see new ones.');
			});
		}, function () {
			banner('Notes are read-only in this view. They can be left on the published page.');
		});
	}

	return {attach: attach, start: start, ready: function () { return ready; }};
})();
