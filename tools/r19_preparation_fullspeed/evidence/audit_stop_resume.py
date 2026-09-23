#!/usr/bin/env python3
"""Read-only audit of already completed stop/resume boots; never starts an engine."""
import json
import pathlib

ROOT=pathlib.Path(__file__).resolve().parent/'stop-resume'
receipt=[]
cursor=561
previous_selection=None
for label in ('A','B'):
    stage=ROOT/label
    result=json.loads((stage/'result.json').read_text())
    assert result['exit']==0 and not result['forced'] and not result['survivors']
    text=(stage/'engine.log').read_text()
    assert 'ERROR[' not in text
    es=[json.loads(line.split('[pregen_diag] ',1)[1]) for line in text.splitlines() if '[pregen_diag] ' in line]
    boots=[e for e in es if e['kind']=='boot'];assert len(boots)==1
    assert boots[0]['data']['status']['completed']==cursor
    requests=[e for e in es if e['kind']=='dispatch']
    completions=[e for e in es if e['kind']=='complete']
    stops=[e for e in es if e['kind']=='stop_request'];assert len(stops)==1
    shutdowns=[e for e in es if e['kind']=='shutdown'];assert len(shutdowns)==1
    stop=stops[0];shutdown=shutdowns[0]['data']
    assert len(requests)==len(completions)==2
    assert sorted(e['data']['id'] for e in requests)==sorted(e['data']['id'] for e in completions)==[1,2]
    assert max(e['data']['inflight'] for e in requests)==2
    assert not any(e['kind']=='dispatch' and e['us']>stop['us'] for e in es)
    settled=max([cursor]+[e['data']['cursor'] for e in completions])
    assert shutdown['status']['completed']==settled and shutdown['inflight']==0
    assert shutdown['queue_depth']<=2
    rows=shutdown.get('queue_rows')
    if rows is None:
        assert shutdown['queue_depth']==0
        rows=[]
    assert len(rows)==shutdown['queue_depth']
    assert all(row['status']!='pending' for row in rows)
    if label=='A':
        assert stop['data']['inflight']==2 and stop['data']['queue_depth']==2
        assert cursor<=settled<=cursor+2
    else:
        assert stop['data']['inflight']==0 and stop['data']['queue_depth']==0
        assert settled==cursor+2 and shutdown['queue_depth']==0
        if previous_selection is not None:
            assert requests[0]['data']['selection']==previous_selection
    receipt.append(dict(boot=label,start_cursor=cursor,settled_cursor=settled,
        stop=stop['data'],shutdown=shutdown,result=result,
        terminal_requests=[e['data'] for e in completions]))
    cursor=settled
    previous_selection=shutdown.get('selection')
print(json.dumps(receipt,sort_keys=True,indent=2))
