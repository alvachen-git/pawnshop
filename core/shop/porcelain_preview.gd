class_name PorcelainPreview
extends RefCounted

static func apply(session: RunSession, args: Dictionary) -> void:
	var state := session._day.state; var visit: CustomerVisit = state.visits[0]
	if not PorcelainEconomy.handles(state,visit.item): return
	var scenario: String=args.get("--precision-porcelain-case","natural")
	if scenario=="guide":
		state.phase=&"pre_open"; state.current_night_index=2; state.visits.clear(); state.shop_growth.knowledge.clear(); return
	var age: String=args.get("--precision-era","ming");var quality: String=args.get("--precision-craft","standard")
	if age not in PorcelainEconomy.BASE: age="ming"
	if quality not in PorcelainEconomy.CRAFT: quality="standard"
	if scenario=="bargain": age="yuan";quality="fine"
	if scenario=="overpriced": age="republic";quality="standard"
	visit.item.selected_variant_id="sound" if age in ["yuan","ming"] else "mended" if age=="qing" else "flawed"
	var damage: String=args.get("--precision-damage","intact")
	if damage not in TieredAppraisal.RETAIN: damage="intact"
	var hidden: bool=args.get("--precision-difficulty","ordinary")=="hidden"
	visit.item.goods.precision={"damage":damage,"hidden":hidden}
	visit.item.goods.porcelain_value={"era":age,"craft":quality,"sample":clampi(int(args.get("--precision-sample","1"))-1,0,1),"hidden":hidden,"actual":PorcelainEconomy.valuation(age,quality,damage)}
	if scenario!="natural": visit.transaction_modes.assign(["sell"])
	PorcelainEconomy.prepare(state,visit)
	if scenario=="no-tools":
		state.shop_growth.bench=false;state.shop_growth.appraisal.bench_due=0;state.shop_growth.precision.due=0;return
	if scenario=="natural": return
	var o:=PorcelainEconomy.owner(state,visit)
	o.belief={"era":"republic" if scenario=="bargain" else "yuan","craft":"standard" if scenario=="bargain" else "fine"};o.rate=100;o.urgent=false
	PorcelainEconomy.reprice_initial(state,visit);PorcelainNegotiation.prepare(state,visit)
	var n:=PorcelainNegotiation.data(state,visit);n.personality="careful" if scenario=="partial" else "firm" if scenario=="firm" else "easy"
	for part in PorcelainNegotiation.PARTS:n.rolls[part]=99 if scenario=="exposed" else 0
	visit.voice.introduction="这只旧瓶在家搁了多年，只当近年的摆设，您给些现钱就成。" if scenario=="bargain" else "这是按老窑好工收来的瓶子，请您掌眼。"
