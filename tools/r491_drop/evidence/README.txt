0.49.1 DROP reproduction receipts (tools/r491_drop/repro.sh, seed 12345,
15 % netem loss on the private loopback, 20 waves of six drops at the
Bannerbreak Warhold waystone). The full logs (server, client, probe and
client scan) are in the coordinator's folder r49.1/shots/drop/.

before/  main acfd84d4 code (no fix): 18 of 117 matched drops slid.
after/   this lane's code (resend at rest + punched-drop pickup): 0 sliders.

In before/ the probe's per-step travel was still read wrongly (the engine
moves an entity before its on_step runs), so its "landing step" values and
the LEAD lines' path and rest times read 0; the probe was corrected for
after/. The SRV lines (server positions once a second) and the client scan
were right in both runs, and they are what the slider count is made of.
