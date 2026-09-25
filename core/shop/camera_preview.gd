class_name CameraPreview
extends RefCounted

static func apply(session: RunSession, scenario: String) -> void:
	var state:=session._day.state;var visit: CustomerVisit=state.visits[0]
	if not CameraEconomy.handles(state,visit.item) or scenario=="natural":return
	if scenario=="guide":
		state.phase=&"pre_open";state.current_night_index=2;state.visits.clear();state.shop_growth.knowledge.clear();return
	var identity: String="imitation" if scenario.begins_with("imitation") else "rebuilt" if scenario=="rebuilt" else "original"
	var lens: String=scenario if scenario in ["haze","scratched"] else "clear"
	var mechanism: String=scenario if scenario in ["sticky","stuck"] else "sticky" if scenario in ["partial","firm"] else "smooth"
	visit.item.goods.camera_value={"identity":identity,"lens":lens,"mechanism":mechanism,"fault_at":"both","actual":CameraEconomy.valuation(identity,lens,mechanism,visit.item.goods.precision.damage)}
	visit.item.goods.camera_value["engraving"] = {"imitation-legacy":"legacy","imitation-letters":"letter_swap","imitation-extra":"extra_letter","imitation-city":"city_swap"}.get(scenario,VarietyService.pick(CameraEconomy.ENGRAVINGS,state.run_seed,visit.item.instance_id+"/camera43/engraving") if identity=="imitation" else "standard")
	visit.transaction_modes.assign(["sell"]);WealthyCustomers.trade(state,visit).funding=0
	CameraEconomy.prepare(state,visit)
	if scenario=="no-tools":
		state.shop_growth.bench=false;state.shop_growth.appraisal.bench_due=0;state.shop_growth.precision.due=0;return
	var o:=CameraEconomy.owner(state,visit);o.belief={"identity":"original","lens":"clear","mechanism":"smooth"};o.rate=100;o.urgent=false
	CameraEconomy.reprice_initial(state,visit);CameraNegotiation.prepare(state,visit)
	var n:=CameraNegotiation.data(state,visit);n.personality="careful" if scenario=="partial" else "firm" if scenario=="firm" else "easy"
	for part in CameraNegotiation.PARTS:n.rolls[part]=99 if scenario=="exposed" else 0
