import pathlib,json,statistics,collections
r=pathlib.Path(__file__).resolve().parent;ev=[json.loads(l.split('[pregen_diag] ',1)[1]) for l in (r/'engine.log').read_text().splitlines() if '[pregen_diag] ' in l];base=ev[0]['us'];groups=collections.defaultdict(list)
for e in ev:groups[int((e['us']-base)/60000000)].append(e)
for minute,es in groups.items():
 samples=[e['data'] for e in es if e['kind']=='sample'];ds=[e['data'] for e in es if e['kind']=='dispatch'];cs=[e['data'] for e in es if e['kind']=='complete'];dur=[d['duration_us']/1e6 for d in cs];gaps=[d['gap_us']/1e6 for d in ds if 'gap_us' in d];t=sum(s.get('step_us',0) for s in samples);steps=sum(s['steps'] for s in samples if 'step_us' in s)
 print(json.dumps({'minute_after_mods_loaded':minute,'completed_requests':len(cs),'last_cursor':cs[-1]['cursor'] if cs else None,'request_sec_mean':statistics.mean(dur) if dur else None,'request_sec_max':max(dur) if dur else None,'gap_sec_mean':statistics.mean(gaps) if gaps else None,'scan_sec':sum(s['scan_us'] for s in samples)/1e6,'scan_steps':sum(s['scan_steps'] for s in samples),'step_mean_ms':t/steps/1000 if steps else None,'step_max_ms':max([s.get('step_max_us',0) for s in samples],default=0)/1000,'persist_ms':sum(s['persist_us'] for s in samples)/1000,'last_lo':ds[-1]['lo'] if ds else None}))
print('latest sample',samples[-1] if samples else None)
