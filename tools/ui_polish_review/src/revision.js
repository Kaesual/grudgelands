/* Revision 03: one layout per page, explicit state examples, unchanged runtime. */
const demoSelections={};
const DEMOS={
 effects:[['empty','Keine Effekte'],['active','Aktive Effekte · Beispiel']],
 repair:[['camp','Camp-Händler · integrierter Tab'],['standalone','Eigenständiger Reparaturdienst']],
 claim_belongings:[['few','Ein Eintrag'],['many','37 Einträge · Beispiel'],['collected','Alles entnommen · zurück zum Claim Stone']],
 party:[['solo','Solo'],['member','Mitglied · Beispiel'],['leader','Leiter · Beispiel']],
 map:[['idle','Keine Quest gewählt'],['selected','Quest gewählt · Beispiel']],
 map_zones:[['idle','Keine Quest gewählt'],['selected','Quest gewählt · Beispiel']],
 quickbar:[['idle','Nicht aufgesessen'],['riding','Aufgesessen · Beispiel']],
 mail_letters:[['npc','NPC-Brief'],['player','Spielerbrief · Beispiel'],['report','Melden · Beispiel']],
 mail_announcements:[['empty','Keine Ankündigung'],['read','Ankündigung · Beispiel']],
 mail_admin:[['empty','Keine Tickets'],['open','Offenes Ticket · Beispiel'],['answered','Beantwortet · Beispiel']],
 innkeeper:[['home','Bereits Heimat'],['available','Andere Heimat · Beispiel']],
 waystone:[['locked','Nicht besucht'],['available','Besucht · Beispiel']],
 book:[['write','Schreiben'],['read','Lesen']],
 claim:[['fuel','Mit Brennstoff'],['wait','Abholfrist · Beispiel'],['empty','Ohne Brennstoff · Beispiel']],
 preparing:[['progress','Vorbereitung'],['failed','Fehlgeschlagen · Beispiel'],['ready','Vorbereitung abgeschlossen · Beispiel']]
};
function demoState(){return demoSelections[active?.id]||(DEMOS[active?.id]?.[0]?.[0])||'idle'}
function updateDemoControls(p){
 let modes=DEMOS[p.id];if(p.layout==='furnace')modes=[['idle','Stillstand'],['active','Schmelzen · Beispiel'],['blocked','Ausgabe voll · Beispiel']];
 $('#demo-control').hidden=!modes;$('#demo-state').innerHTML=(modes||[]).map(([v,t])=>`<option value="${v}">${t}</option>`).join('');
 if(modes)$('#demo-state').value=demoSelections[p.id]||modes[0][0];
}
function sectionField(label,value='',extra=''){return `<div class="field-group">${tag(label)}${field(value,extra)}</div>`}
function actionSlots(images,active=-1){return `<div class="action-slots">${images.map((name,i)=>`<span class="m-slot action-slot ${i===active?'ridden':''}" role="button" tabindex="0">${icon(name)}</span>`).join('')}</div>`}
function partyView(){
 const state=demoState(),group=state==='solo'?'<div class="m-empty m-grow"><h3>No current party</h3><p>Select an online player below to invite them.</p></div>':`<div class="m-scroll m-grow"><div class="party-member">${icon('grug_class_warrior.png')}<span>${state==='leader'?'* ':''}grugcap · Warrior · Lv 30</span><small>917 / 917 HP</small></div><div class="party-member active">${icon('grug_class_priest.png')}<span>${state==='member'?'* ':''}Companion · Priest · Lv 29</span><small>740 / 810 HP</small></div></div>${footer(B('Leave','danger'),state==='leader'?B('Make leader')+B('Kick','danger'):'')}`;
 return shell(row(check('Allow invitations')+check('Party HUD')+small('Health colors')+field('By class ▾'))+`<div class="m-split party-columns"><div class="m-col">${pane('<h3>Current party</h3>'+group,'Aktuelle Gruppe','party-current')}${pane('<h3>Online same-faction players</h3>'+list([state==='solo'?'Companion [Lv 29]':'Companion [Lv 29] (In party)'],-1)+footer(B('Invite'),B('Refresh')),'Einladen')}${pane('<h3>Pending invitations</h3>'+list(['No invitations.'],-1)+footer(B('Accept'),B('Decline')),'Einladungen')}</div>${pane('<h3>PvP status</h3><h2 class="safe">Safe</h2><p>Enemy players cannot attack you, nor you them.</p><p>Flags you for 60 s; pressing it again restarts the 60 s. PvP needs both players flagged.</p>'+B('Flag me for PvP','danger')+'<h3>Statistics</h3><div class="m-scroll">'+['Player kills','Killing blows','Deaths to players','Enemy guards killed','Enemy captains killed','Enemy generals killed','Enemy kings killed'].map(t=>kv(t,'0')).join('')+'</div>','PvP')}</div>`,{shared:'Party'});
}
function mapView(p){
 const selected=demoState()==='selected',zoom=p.id==='map_zones'?2:1;
 const detail=selected?'<h3>Use a mailbox in one of the cities</h3><div class="m-scroll m-grow"><p>Objective</p><p>Use a mailbox in one of the cities.</p><p class="muted">0 / 1</p></div>'+footer(check('Track on HUD'),B('Abandon','danger')):'<div class="m-empty m-grow"><h3>Select a quest</h3><p>Select a quest to read it and see its targets on the map.</p></div>';
 return shell(`<div class="map-toolbar">${row(B('−')+small(zoom+'×')+B('+'))}<span>Current: Dawnmere</span><label>Layer <select class="mock-select"><option>${zoom===2?'Zones':'Quests'}</option>${['Quests','Bosses','Trainers','Towns','POIs','PvP','Zones','None'].filter(x=>x!==(zoom===2?'Zones':'Quests')).map(x=>`<option>${x}</option>`).join('')}</select></label>${check('Show minimap')}</div><div class="m-split map-columns"><div class="map-viewport ${zoom===2?'zoomed':''}" data-area="Kartenausschnitt">${zoom===2?`<div class="zone-map"><img src="assets/map-base-example.webp" alt="Native Kartenkunst aus einem archivierten Testwelt-Beispiel">${ZONE_LABELS.map(l=>`<span style="left:${l.x}%;top:${l.y}%">${esc(l.text)}</span>`).join('')}</div>`:'<img src="assets/map-world.webp" alt="Kartenkunst aus echter Client-Aufnahme">'}</div><div class="m-col quest-column">${pane(row('<h3>Active quests · 1 / 20</h3>'+check('Quest HUD'),'spread')+list(['Use a mailbox in one of the cities'],selected?0:-1),'Questliste','quest-list-pane')}${pane(detail,'Questdetails','quest-detail-pane')}</div></div>`,{shared:'Map & Quests',cls:'map'});
}
function inventoryPage(){
 const bags=capacity()>3?Array(4).fill('grug_inventory_bag_large.png'):0;
 return shell(`<div class="inventory-page">${pane(row(tag('Inventory')+B('Sort'),'spread')+`<div class="inventory-scroll full-inventory">${grid(capacity()*8,8,3)}</div>`,'Inventar','inventory-main-pane')}<div class="inventory-side">${pane(tag('Bags')+grid(4,4,bags),'Taschen')}${pane(tag('Potion belt')+grid(4,4,0),'Trankgürtel')}${pane('<h3>Money</h3><h2>5g 0s 0c</h2>'+B('Withdraw')+'<div class="money-deposit">'+grid(1,1,0,'grug_money_bag_of_coins.png')+small('Deposit coin bags')+'</div>'+check('Auto deposit')+small('Automatically deposit coin bags on pickup.'),'Geld','money-pane')}</div></div><div class="inventory-page-hotbar">${hotbarView()}</div>`,{shared:'Inventory'});
}
function talentsView(){
 return shell(`<div class="talent-workspace">${pane(tag('Talent tree')+list(['Bulwark (0)','Ruin (0)'])+small('Points 15 / 15'),'Baum wählen','talent-menu')}<div class="talent-body"><div class="m-tree"><img src="assets/native-talents.webp" alt="Originaler Bulwark-Baum mit vollständiger Randkunst"></div>${row(small('Click an available talent to buy one rank.')+small('No ranks spent'),'spread')}<div class="skill-catalog">${row(tag('Skills')+small('Drag to hotbar; back to remove.'),'spread')}${grid(2,2,['skill1.webp','skill2.webp'])}</div></div></div>${inventory(2)}`,{shared:'Talents'});
}
function repairView(){
 const camp=demoState()!=='standalone';
 return shell((camp?tabs(['Buy','Sell','Trade-in','Repair'],'Repair')+row('<div>'+tag('Your money')+'5g 0s 0c</div><div>'+tag('Service')+'Equipment repairs</div>','spread'):'')+pane(row(tag('Item')+tag('Durability / Cost'),'spread')+line('Steel Sword','Durability · 54%',row(small('74c')+B('Repair')),'grug_gear_item_sword_steel.png')+'<div class="m-grow"></div>'+pg(),'Reparaturen')+footer(camp?'':B('Close'),B('Repair all · 74c','gold')),{title:camp?'Camp Vendor':'Equipment repairs',sub:camp?'The Charter of Stone':'Repair service',cls:camp?'service':'compact'});
}
function belongingsView(){
 const n=demoState()==='many'?37:demoState()==='collected'?0:1;
 if(!n)return draw(PAGES.find(p=>p.id==='claim'));
 const entries=Array.from({length:n},(_,i)=>i%3===0?{img:'default_coal_lump.png',n:20}:i%3===1?{img:'default_book.png',n:2}:{img:'native-wood.webp',n:32});
 return shell(tabs(['Claim Stone','Waypoints',`Belongings (${n})`],`Belongings (${n})`)+pane('<h3>Belongings from the old map</h3>'+ (n?`<div class="m-scroll recovered-grid">${grid(n,8,entries)}</div>`:'<div class="m-empty"><p>No belongings to collect.</p></div>')+'<p>Take them into your inventory; place a packed container to unpack it.</p>','Take-only-Inventar')+inventory(3)+footer('',B('Close')),{title:'Claim Stone'});
}
function effectRows(){
 return demoState()==='active'?`<div class="m-scroll m-grow">${line('Swiftness Draught','+10% movement speed',small('under 1 min left'),'effect-swiftness.webp')}${line('Cave Draught','Night vision',small('8 min left'),'effect-cave.webp')}</div>`:'<div class="m-empty m-grow"><h2>No active effects</h2><p>Food, elixirs, skills, talents and hostile attacks show here.</p></div>';
}
function tradeRows(exchange){
 const rows=exchange?[['Cobblestone',48,'1 point per 50','native-cobble.webp',50,1],['Coal Lump',24,'1 point each','default_coal_lump.png',1,1]]:[['Apple Wood Planks',32,'1c per 99','native-wood.webp',99,1],['Cobblestone',48,'1c per 50','native-cobble.webp',50,1],['Coal Lump',24,'1c each','default_coal_lump.png',1,1],['Apple',18,'1c each','default_apple.png',1,1],['Paper',5,'1c each','default_paper.png',1,1],['Book',2,'4c each','default_book.png',1,4],['Steel Sword',1,'8c each','grug_gear_item_sword_steel.png',1,8]];
 return `<div class="trade-heading"><span>Item</span><span>Owned</span><span>${exchange?'Rate':'Value'}</span><span>${exchange?'Trade-in':'Sell'}</span></div><div class="m-scroll m-grow">${rows.map(([name,n,rate,img,lot,value])=>`<div class="trade-row"><div class="trade-item">${icon(img)}<span>${name}</span></div><span>×${n}</span><span>${rate}</span><div class="trade-actions">${n<lot?small(`Need ${lot} to ${exchange?'trade':'sell'}`):[1,5,10].map(q=>B(String(q),q>Math.floor(n/lot)?'dim':'')).join('')+B(`All (${Math.floor(n/lot)*value}${exchange?'':'c'})`)}</div></div>`).join('')}</div>`+pg();
}
function revisedTrade(p){const exchange=p.id==='vendor_exchange';return shell(tabs(exchange?['Buy','Sell','Trade-in','Repair']:['Buy','Sell'],exchange?'Trade-in':'Sell')+row(exchange?'<div>'+tag('Miner’s Guild')+'Balance 2,500</div><div>'+tag('Rank 2 / 10')+'Lifetime 2,500 / 2,700</div>':'<div>'+tag('Your money')+'5g 0s 0c</div><div>'+tag('Kinship discount')+'−10% on purchases</div>','spread')+pane(tradeRows(exchange),'Gegenstand · Besitz · Preis · Menge')+small(exchange?'Whole lots only; the rest stays with you.':'Cheap goods sell in whole lots; the rest stays with you.'),{title:exchange?'Camp Vendor':'Human Quartermaster',sub:exchange?'The Charter of Stone':'Trade',cls:'service'});}
function furnaceView(p){
 const dual=p.id.includes('dual'),personal=p.id.includes('personal'),state=demoState();
 const input=state==='idle'?0:dual?[{img:'default_copper_ingot.png',n:12},{img:'default_tin_ingot.png',n:12}]:[{img:'default_iron_lump.png',n:12}];
 const output=state==='blocked'?Array(dual?2:4).fill({img:dual?'default_bronze_ingot.png':'default_steel_ingot.png',n:99}):0;
 return shell(pane(`<div class="furnace-layout"><div>${tag('Input')}${grid(dual?2:1,dual?2:1,input)}</div><div class="fuel-group">${tag('Fuel')}${grid(1,1,state==='idle'&&personal?0:[{img:'default_coal_lump.png',n:8}])}<img class="fuel-fire" src="assets/default_furnace_fire_bg.png" alt="Brennstofffortschritt"></div><div class="furnace-progress ${state==='active'?'running':''}"><img class="cook-arrow" src="assets/gui_furnace_arrow_bg.png" alt="Schmelzfortschritt">${small(state==='blocked'?'Output full':state==='active'?'Smelting':'Idle')}</div><div>${tag('Output')}${grid(dual?2:4,2,output)}</div></div>`,'Eingabe · Brennstoff · Ausgabe')+inventory(5),{title:dual?'Dual Furnace':'Furnace',sub:personal?'Personal workspace · saved separately for each station':'Shared station',cls:'station'});
}
function mailboxList(player=false){return `<div class="mail-list m-scroll">${[player?['•','Player','A letter from Companion (+1)','Companion']:['•','NPC','The road ahead (+1)','Mariel Waybook'],['•','NPC','A door of your own','Housing Steward'],['•','NPC','You’ve earned a place','Dawnmere'],['•','Admin','Welcome to Grudgelands','Server Admin']].map((v,i)=>`<div class="mail-summary ${i===0?'active':''}"><span>${v[0]}</span>${v[1]==='Player'?'':icon(v[1]==='NPC'?'grug_mail_npc_seal.png':'grug_mail_admin_badge.png')}<div><b>${v[2]}</b><small>${v[1]} · ${v[3]}</small></div></div>`).join('')}</div>`;}
function mailView(p){
 const state=demoState(),ann=p.id==='mail_announcements';let body='';
 if(p.id==='mail_admin'){
 const right=state==='empty'?'<div class="m-empty m-grow"><p>You have not written to the admin.</p></div>':list(['Feedback · A question · 25 Oct'])+pg()+`<h3>A question</h3>${small('You · 25 Oct · Feedback · '+(state==='answered'?'Answered':'Open'))}<div class="m-edit m-grow">Example message sent to the server admin.</div>${state==='answered'?small('The answer is in your Letters.'):''}`+footer('',B('Delete','danger'));
 body=`<div class="m-split">${pane('<h3>Write to the server admin</h3>'+sectionField('Topic','Feedback ▾')+sectionField('Subject')+tag('Message')+'<div class="m-edit m-grow"></div>'+small('Up to 4,000 characters. Sent from Mailbox. Version attached.')+footer(B('Discard'),B('Send (free)','gold')),'Schreiben')}${pane('<h3>Your messages</h3>'+right+(state==='empty'?pg():'')+small((state==='open'?'1':'0')+' of 5 open messages'),'Ticketverlauf')}</div>`;
 }else{
 const empty=ann&&state==='empty';const player=!ann&&(state==='player'||state==='report');
 const title=ann?'Server announcement':player?'A letter from Companion':'The road ahead';
 let contents=empty?'<div class="m-empty m-grow"><h3>No announcements</h3><p>Letters from the admin to all players appear here.</p></div>':`<h2>${title}</h2>${small('From: '+(ann?'Server Admin':player?'Companion':'Mariel Waybook')+' · 25 Oct')}<div class="m-scroll m-grow"><p>${ann?'Example announcement text.':player?'Example player message.':'Your journey leads beyond Dawnmere. Keep these supplies close, and visit the Quartermaster before you leave.'}</p></div>`;
 if(!empty&&!ann)contents+=tag('Attachments')+row(grid(4,4,[{img:'default_torch_on_floor.png',n:12}])+B('Take all'),'spread');
 if(state==='report')contents+=`<div class="report-box"><h3>Report this letter from Companion?</h3>${sectionField('Reason','Other ▾')}${sectionField('Note (optional)')}<p>A copy of the letter goes to the server admin.</p>${footer(B('Cancel'),B('Report','danger'))}</div>`;
 else if(p.id==='mail_delete')contents+='<div class="m-warning">This letter still holds its attachments.<br>Delete it together with them?</div>'+footer(B('Cancel'),B('Delete','danger'));
 else if(!empty)contents+=footer(ann?B('Reply'):player?B('Reply')+B('Report'):small('NPC letters cannot be answered.'),ann?'':B('Delete','danger'));
 const messages=empty?'<div class="m-grow"></div>':ann?list(['• Admin · Server announcement']):mailboxList(player);
 body=`<div class="m-split mail-columns">${pane('<h3>'+ (ann?'Announcements':'Letters')+'</h3>'+messages+'<div class="m-grow"></div>'+pg()+small(ann?'Server announcements':'4 letters · 4 unread'),'Brief auswählen')}${pane(contents,'Lesen und handeln')}</div>`;
 }
 return shell(tabs(['Letters (4)','Announcements','Write','To the admin'],p.id==='mail_admin'?'To the admin':ann?'Announcements':'Letters (4)')+row(small('Mailbox')+small('Purse · 5g 0s 25c'),'spread')+body+small(p.id==='mail_admin'?'Deleting removes a message for good. Messages are deleted after 30 days.':ann?'Announcements are deleted 30 days after they were sent.':'Letters are deleted 30 days after arrival; attachments too.'),{title:'Mailbox'});
}
function drawRevision(p){
 if(p.id==='inventory')return inventoryPage();
 if(p.id==='party')return partyView();
 if(p.id==='talents')return talentsView();
 if(p.id==='repair')return repairView();
 if(p.id==='claim_belongings')return belongingsView();
 if(p.layout==='map')return mapView(p);
 if(p.id==='vendor_sell'||p.id==='vendor_exchange')return revisedTrade(p);
 if(p.layout==='container'){const chest=p.id.includes('chest');return shell(pane(grid(chest?32:16,8,chest?[{img:'native-wood.webp',n:32}]:0,p.id==='bookshelf'?'default_bookshelf_slot.png':p.id==='vessels'?'vessels_shelf_slot.png':''),'Behälter')+inventory(chest?4:6),{title:{chest:'Chest',locked_chest:'Locked Chest',bookshelf:'Bookshelf',vessels:'Vessels Shelf'}[p.id],sub:p.id==='locked_chest'?'Locked container':'',cls:'container'});}
 if(p.layout==='furnace')return furnaceView(p);
 if(p.id==='quickbar')return shell(pane(tag('Mounts and boats')+actionSlots(['grug_mounts_icon_t1_accord.png','grug_mounts_icon_boat.png'],demoState()==='riding'?0:-1)+(demoState()==='riding'?B('Dismount'):''),'Mounts')+pane(tag('Potion belt')+grid(4,4,0),'Potion belt')+pane(tag('Active Hotbar')+row(B('A','gold')+B('B'),'quick-switch'),'Hotbar')+pane(tag('Home · Dawnmere')+B('Return home · Ready'),'Home')+small('Use a mount, potion or Return home to close.<br>A/B switches the hotbar and keeps this open.'),{title:'Quickbar',cls:'quick'});
 if(['mail_letters','mail_delete','mail_announcements','mail_admin'].includes(p.id))return mailView(p);
 if(p.id==='book')return shell(tabs(['Write','Read'],demoState()==='read'?'Read':'Write')+(demoState()==='read'?'<h2>Field notes</h2>'+small('by grugcap')+'<div class="m-edit m-grow">A journey begins in Dawnmere.<br>Follow the road and speak to the people you meet.</div>'+pg():sectionField('Title','Field notes')+'<div class="field-group m-grow">'+tag('Contents')+'<div class="m-edit m-grow">A journey begins in Dawnmere.<br>Follow the road and speak to the people you meet.</div></div>'+footer('',B('Save','gold'))),{title:'Book',cls:'service'});
 if(p.id==='preparing'&&demoState()==='failed')return shell(pane('<h3>World preparation failed</h3><p>Please try again.</p>'+B('Try again','gold'),'Vorhandener Fehlerzustand'),{title:'Preparing your arrival',cls:'compact'});
 if(p.id==='preparing'&&demoState()==='ready')return shell(pane('<h3>Preparing your arrival</h3><p>The world is ready; your arrival is being prepared.</p>','Vorhandener Folgezustand'),{title:'Preparing your arrival',cls:'compact'});
 return null;
}
function revisionNotes(p){
 if(p.id==='repair')return '<h2>Repair bleibt im Händlerkontext</h2><p>Bei Camp-Händlern mit Reparaturangebot ist Repair ein gleichwertiger Tab neben Buy, Sell und Trade-in. Das Fenster behält deren Größe und kann über dieselbe Navigation verlassen werden. Eigenständige Reparaturdienste bleiben separat, im Zustandswähler sichtbar. Das erfordert eine gezielte Änderung der Navigation: Die heutige Reparaturaktion beendet die Händlersitzung. Die spätere Umsetzung muss den Händlerkontext und seine Entfernungs-/Fraktionsprüfungen erhalten; Preisangebote und Reparaturprüfung bleiben beim bestehenden Reparaturdienst. Normale Händler erhalten dadurch keine neue Fähigkeit.</p>';
 if(p.id==='talents')return '<h2>Baum und freigeschaltete Skills</h2><p>Baumauswahl links, vollständige Originalkunst rechts ohne zusätzliche Seitenränder. Die zwei abgebildeten Slots sind die tatsächlich freigeschalteten Skills des aufgenommenen Warriors. Weitere freigeschaltete Skills erweitern dieselbe native Liste; horizontal gescrollt wird erst, wenn ihre Breite nicht reicht. Es gibt keine leeren Auffüllslots und keinen zusätzlichen Kasten um die Skill-Leiste. Respec samt bestehendem Preis und Bestätigung bleibt unter dem Baum, sobald Ränge ausgegeben sind.</p>';
 if(p.id==='claim_belongings')return '<h2>Ein Slot je vorhandenen Eintrag</h2><p>Der Zustandswähler zeigt 1 oder 37 Einträge sowie den Rücksprung nach der letzten Entnahme. Bei null Einträgen verschwindet der Belongings-Tab wie heute. Neu vorgeschlagen ist nur, die letzte sichtbare Reihe nicht auf acht leere Slots aufzufüllen; Liste und Anzeige schrumpfen beim Entnehmen. Ein gepackter Container zählt als ein Eintrag. Das verändert weder Speicherformat noch Inhalt. Die Belastungsprüfung mit sehr vielen Containern steht separat im Backlog; ein unbegrenztes Leistungsversprechen oder eine neue Obergrenze folgt daraus nicht.</p>';
 if(p.id==='effects')return '<h2>Leer und aktiv an derselben Position</h2><p>Im Zustandswähler sind aktive Effekte mit den vorhandenen Status-Icons sichtbar. Leermeldung und Effektliste beginnen oben. Restzeit und Detail kommen weiterhin aus der vorhandenen Statusanzeige; keine neuen Aktualisierungstakte.</p>';
 if(['vendor_sell','vendor_exchange'].includes(p.id))return '<h2>Bewusste Funktionserweiterung</h2><p>1 / 5 / 10 / All ist dein neuer Vorschlag, keine bereits vorhandene Bedienung. Die Zahlen beziehen sich auf verkaufbare Einheiten bzw. ganze Lose; Preis und Losgröße bleiben sichtbar. Bei unzureichendem Bestand sind Mengen inaktiv. All behält die bisherige Gesamtsumme. Umsetzung: zusätzliche validierte Mengenaktionen, unveränderte Los-/Restregeln; weniger einzelne Klicks und Formspec-Sendungen. Im aktuellen Trade-in gibt es bisher nur All.</p>';
 if(p.layout==='furnace')return '<h2>Prozessanzeigen bleiben getrennt</h2><p>Flamme: Brennstoff. Pfeil: Schmelzfortschritt. Beide bleiben die bestehenden clientseitigen Animationen; keine neuen Sekunden, Prozentwerte oder Aktualisierungstakte. Der Zustandswähler zeigt Platz und Beschriftung, keine echte Luanti-Animation.</p>';
 if(p.layout==='map')return '<h2>Kartenausschnitt statt zusätzlicher Ränder</h2><p>Die einzelne Layer-Auswahl enthält alle acht Ebenen. Ab 2× ist der gesamte linke Ausschnitt scrollbar; nur bei 1× bleibt die komplette Karte in ihrem Seitenverhältnis sichtbar. Die Questkarte ist ein Client-Ausschnitt. Für Zonen liegt native Kartenkunst aus einer archivierten Testwelt unter separaten HTML-Labels: Namen und Anordnung stammen aus dem korrigierten 1×-Formspec-Beleg. Das illustriert Flächennutzung und unabhängige Schriftgröße, nicht eine neue Client-Aufnahme oder einen exakten Weltstand. „Show minimap“ sitzt im Kopf, Questliste und Questdetails bleiben sichtbar getrennt. Der redundante Back-to-inventory-Button entfällt wie von dir vorgeschlagen.</p>';
 if(p.id==='party')return '<h2>Alle Rollen im gleichen Layout</h2><p>Oben über dem Vergleich sind Solo, Mitglied und Leiter umschaltbar. Die eigentliche Mitgliederliste behält Klassen-Icon, Level, HP / Offline und die Leitermarkierung. Nur der Leiter kann einen anderen Spieler entfernen oder zum Leiter machen; Leave bleibt für Mitglieder sichtbar. Die Beispieldaten sind ausdrücklich keine neue Spielaufnahme.</p>';
 return '';
}
function questMarkerExamples(){
 const marks=[['available','Available quest','Available'],['ready','Quest ready to complete','Ready to complete'],['active','Quest in progress','In progress'],['locked','Locked quest','Locked']];
 return `<div class="state-card"><h3>Quest-Zustände und Story · Markierungsbeispiele</h3><div class="state-schematic quest-marker-examples">${tag('Story')}${line('Held in Our Name','Story · Available · Brodd Deeppeg','','grug_map_quest_story_available.png')}${tag('Side quests')}${marks.map(([id,title,status])=>line(title,status,'',`grug_map_quest_${id}.png`)).join('')}</div><p>Vorhandene Kartenmarker: ! für Angebote, ? für aktive oder fertige Quests; helle bzw. gedämpfte Varianten und Klartext unterscheiden den Zustand. Story verwendet den vorhandenen besonderen Rahmen und die eigene Kategorie. Die Titel bleiben neutral statt zeilenweise eingefärbt. Story ist kein fünfter Zustand: Auch eine Story-Quest kann angeboten, aktiv, fertig oder gesperrt sein. Dies sind unabhängige Markierungsbeispiele, keine zusätzliche Questliste bei Elian.</p></div>`;
}
