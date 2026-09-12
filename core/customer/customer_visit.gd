class_name CustomerVisit
extends RefCounted

var night_policy := ""
var night_aftermath := ""
var transaction_modes: Array = []
var person: Dictionary = {}
var pawn_terms_id := ""
var voice: Dictionary = {}
# Immediate departure feedback; never serialized separately from action history.
var departure_reply := ""
var visit_id: String
var customer_id: String
var arrival: int
var expires_at: int
var status := "scheduled"
var item: ItemInstance
var trade := TradeSession.new()
var asked_question_ids: Array = []

var scenario_id := ""
var situation_id := ""
var reaction_id := ""
var concession_used := false
