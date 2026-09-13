import os, subprocess, time
from pathlib import Path
output=Path(os.environ['WP40_PROFILE_OUTPUT'])
proc=subprocess.Popen(['chrt','--idle','0','ionice','-c3','bash','tools/wp40/profile/run.sh','/tmp/grug-throughput-flatpak.sh'])
peaks={}
while proc.poll() is None:
 for p in Path('/proc').glob('[0-9]*/comm'):
  try:
   if p.read_text().strip()!='luanti.bin': continue
   args=(p.parent/'cmdline').read_bytes()
   if b'--server\x00' not in args or b'grudgelands-wp40-profile-run.' not in args: continue
   fields=dict(l.split(':',1) for l in (p.parent/'status').read_text().splitlines() if ':' in l)
   value=int(fields['VmHWM'].split()[0])
   peaks[p.parent.name]=max(value,peaks.get(p.parent.name,0))
  except (OSError,KeyError,ValueError): pass
 time.sleep(.2)
if output.exists():
 (output/'engine-rss.tsv').write_text('pid\tpeak_rss_kib\n'+''.join(f'{pid}\t{value}\n' for pid,value in peaks.items()))
raise SystemExit(proc.returncode)
