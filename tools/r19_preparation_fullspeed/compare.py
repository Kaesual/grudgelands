#!/usr/bin/env python3
"""Offline comparison of identical preparation prefixes; no engine execution."""
import datetime
import hashlib
import json
import pathlib
import statistics
import sys
from zoneinfo import ZoneInfo

HERE = pathlib.Path(__file__).resolve().parent
BASELINES = {'4ms':HERE.parent / 'r19_preparation_diagnosis/evidence',
             '40ms':HERE.parent / 'r19_preparation_budget/evidence'}


def events(path):
    result = []
    for line in (path/'engine.log').read_text().splitlines():
        if '[pregen_diag] ' in line:
            row = json.loads(line.split('[pregen_diag] ',1)[1])
            row['wall_second'] = datetime.datetime.strptime(line[:19], '%Y-%m-%d %H:%M:%S').replace(tzinfo=ZoneInfo('Europe/Berlin')).timestamp()
            result.append(row)
    return result


def digest(value):
    return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':')).encode()).hexdigest()


def analyze(path):
    es = events(path)
    ds = {e['data']['id']: e for e in es if e['kind']=='dispatch'}
    cs = {e['data']['id']: e for e in es if e['kind']=='complete'}
    samples = [e['data'] for e in es if e['kind']=='sample']
    os_rows = [json.loads(s) for s in (path/'engine-os.jsonl').read_text().splitlines()]
    assert sorted(ds)==sorted(cs)==list(range(1,562))
    emerge_names=sorted({t['name'] for r in os_rows for t in r['threads'] if t['name'].startswith('Emerge-')})
    assert emerge_names==['Emerge-0'],emerge_names
    assert max(e['data']['cursor'] for e in cs.values())==561
    prefix = [{k:ds[i]['data'][k] for k in ('id','lo','hi','selection')} for i in sorted(ds)]
    def committed(high):
        return min((e for e in cs.values() if e['data']['cursor']>=high),key=lambda e:e['us'])
    by_id = {}
    previous = {}
    for e in (e for e in es if e['kind']=='complete'):
        values = e['data']['actions']
        by_id[e['data']['id']]=e['data'].get('request_actions', {k:v-previous.get(k,0) for k,v in values.items()})
        previous=values
    actions=[by_id[i] for i in sorted(by_id)]
    active=0;empty_since=None;empty_intervals=[];max_active=0;completion_order=[]
    for e in es:
        if e['kind']=='dispatch':
            if active==0 and empty_since is not None:empty_intervals.append((empty_since,e['us']))
            active+=1;max_active=max(max_active,active)
        elif e['kind']=='complete':
            active-=1;assert active>=0
            completion_order.append(e['data']['id'])
            if active==0:empty_since=e['us']
    assert active==0
    settled_ids=set();contiguous=0
    for e in (e for e in es if e['kind']=='complete'):
        settled_ids.add(e['data']['id'])
        while contiguous+1 in settled_ids:contiguous+=1
        assert e['data']['cursor']==contiguous, ('noncontiguous durable cursor',e)
    assert contiguous==561
    def empty_us(lo,hi):
        return sum(max(0,min(b,hi)-max(a,lo)) for a,b in empty_intervals)
    ranges=[]
    for low,high in [(1,100),(101,200),(201,300),(301,400),(401,500),(501,561),(101,561)]:
        start,end=ds[low],committed(high)
        # Log time is second-resolution. +1 at the start and the floored end
        # conservatively admit only sample intervals wholly inside this range.
        lo_wall,hi_wall=start['wall_second']+1,end['wall_second']
        intervals=[]
        for a,b in zip(os_rows,os_rows[1:]):
            wa=datetime.datetime.fromisoformat(a['utc']).timestamp()
            wb=datetime.datetime.fromisoformat(b['utc']).timestamp()
            if wa>=lo_wall and wb<=hi_wall:
                intervals.append((a,b,wb-wa))
        duration=sum(t for _,_,t in intervals)
        cpu_seconds=sum((b['process']['ticks']-a['process']['ticks'])/100 for a,b,_ in intervals)
        thread_cpu={}
        for a,b,_ in intervals:
            old={x['tid']:x for x in a['threads']}
            for thread in b['threads']:
                if thread['tid'] in old:
                    name=thread['name']
                    thread_cpu[name]=thread_cpu.get(name,0)+(thread['ticks']-old[thread['tid']]['ticks'])/100
        ids=range(low,high+1)
        ranges.append(dict(first=low,last=high,seconds=(end['us']-start['us'])/1e6,
            completed=high-low+1,request_mean_ms=statistics.mean(cs[i]['data']['duration_us']/1000 for i in ids),
            queue_empty_seconds=empty_us(start['us'],end['us'])/1e6,
            queue_empty_pct=empty_us(start['us'],end['us'])/(end['us']-start['us'])*100,
            dispatch_after_previous_complete_mean_ms=statistics.mean(max(0,ds[i]['us']-cs[i-1]['us'])/1000 for i in ids if i>1),
            cpu_sample_seconds=duration,cpu_one_core_pct=cpu_seconds/duration*100 if duration else None,
            thread_cpu_pct={k:v/duration*100 for k,v in thread_cpu.items()} if duration else {}))
    hist={}
    for row in samples:
        for k,v in row.get('step_hist',{}).items():hist[int(k)]=hist.get(int(k),0)+v
    def percentile(q):
        total=sum(hist.values());running=0
        for k,v in sorted(hist.items()):
            running+=v
            if running>=q*total:return [k,k+1]
    steps=sum(x['steps'] for x in samples if 'step_us' in x)
    return dict(settings=es[0]['data'],prefix_sha256=digest(prefix),actions_sha256=digest(actions),
        completed=len(cs),emerge_thread_names=emerge_names,committed_prefix_verified=True,final=committed(561)['data'],last_dispatch=ds[561]['data'],
        max_inflight=max_active,completion_order=completion_order,
        completions_out_of_dispatch_order=completion_order!=sorted(completion_order),
        queue_empty_seconds=empty_us(ds[1]['us'],committed(561)['us'])/1e6,
        prefix_after_mods_loaded_seconds=(committed(561)['us']-es[0]['us'])/1e6,
        prefix_after_first_dispatch_seconds=(committed(561)['us']-ds[1]['us'])/1e6,
        first_request_seconds=cs[1]['data']['duration_us']/1e6,ranges=ranges,
        step_mean_ms=sum(x.get('step_us',0) for x in samples)/steps/1000,
        step_max_ms=max(x.get('step_max_us',0) for x in samples)/1000,
        step_p95_ms_bucket=percentile(.95),step_p99_ms_bucket=percentile(.99),
        scan_max_ms=max(x.get('scan_max_us',0) for x in samples)/1000 if hist else None,
        sampled_rss_max=max(x['process']['rss'] for x in os_rows),
        error_lines=[line for line in (path/'engine.log').read_text().splitlines() if 'ERROR[' in line])


def main():
    candidate=pathlib.Path(sys.argv[1]) if len(sys.argv)>1 else HERE/'evidence'
    b=analyze(candidate)
    assert b['max_inflight']==2
    identity=json.loads((candidate/'engine-identity.json').read_text())
    assert identity['clock_ticks_per_second']==100
    comparisons={}
    for label,path in BASELINES.items():
        original=json.loads((path/'engine-identity.json').read_text())
        assert original['engine_sha256']==identity['engine_sha256']
        assert original['affinity']==identity['affinity']
        a=analyze(path)
        assert a['settings']==b['settings']
        assert a['prefix_sha256']==b['prefix_sha256']
        assert a['actions_sha256']==b['actions_sha256']
        snapshots=[json.loads((p/'snapshot.json').read_text()) for p in (path,candidate)]
        changed=sorted(k for k in set(snapshots[0])|set(snapshots[1]) if snapshots[0].get(k)!=snapshots[1].get(k))
        assert changed==['mods/CORE/grug_core/starts_preload.lua'],changed
        comparisons[label]=dict(baseline=a,snapshot_differences=changed,
            prefix_speedup=a['prefix_after_mods_loaded_seconds']/b['prefix_after_mods_loaded_seconds'],
            time_reduction_pct=(1-b['prefix_after_mods_loaded_seconds']/a['prefix_after_mods_loaded_seconds'])*100)
    result=dict(candidate=b,comparisons=comparisons,
        prefix_schema='ordered id/lo/hi/selection; observed durable cursor excluded because it may trail lookahead, but verified independently after every completion',
        cpu_method='100 Hz /proc tick deltas; five-second intervals wholly inside matched tile ranges; conservative log-second boundaries exclude boundary intervals',
        timing_note='request duration is enqueue-to-completion residence, including queue wait; queue_empty_seconds means no outstanding request, not every possible native worker wait')
    print(json.dumps(result,sort_keys=True,indent=2))


if __name__=='__main__':main()
