class_name MedicinePreview
extends RefCounted

static func apply(session: RunSession, stage := "first") -> void:
	SpecialGuestsPreview.apply(session,"one_quote","item_blue_bowl")
	var st := session._day.state
	st.visits.clear(); st.ordinary_selections.clear(); st.ledger_entries.clear(); st.inventory_instances.clear(); st.narrative_flags.clear()
	st.shop_growth.erase("medicine_plans")
	st.current_night_index = 3 if stage == "first" else 9 if stage == "report" else 19 if stage == "final" else 20
	st.game_minutes = 0; st.phase = &"pre_open"; st.pending_event_id = ""; st.risk_pending = ""
	st.social.pending.clear(); st.social.intro_step = -1
	var amount := 0 if stage in ["first","bereaved"] else 160 if stage == "final" else 200
	if amount > 0:
		st.ordinary_selections.append({"visit_id":"medicine-preview/previous","medicine_stage":0,"medicine_funds":0,"night":3,"arrival":90,"customer_id":MedicineStory.CUSTOMER,"context_id":"","item_id":"item_blue_bowl","variant_id":"sound","source":"none","situation":"ordinary","reaction":"admit","terms_id":"","person":{"id":"medicine/huaian","name":MedicineStory.NAME,"portrait":"medicine.huaian"}})
		st.ledger_entries.append({"transaction_id":"purchase/medicine-preview/previous","item_instance_id":"medicine-preview/item","night":3,"minute":95,"kind":"acquisition","amount":-amount,"balance":6000,"realized_profit":0})
	if stage in ["saved","bereaved"]: return
	st.phase = &"open"
	CustomerManager.new().prepare_night(st,session.definition,session._counter.catalog)
	for visit in st.visits:
		visit.status = "rejected"
		if visit.customer_id == MedicineStory.CUSTOMER:
			visit.status = "active"; st.game_minutes = visit.arrival
	session.message = ""
