class_name TradeSession
extends RefCounted

var opening_price: int
var asking_price: int
var reserve_price: int
var rounds_left: int
var patience: int
var offers: Array[int] = []
var used_clue_ids: Array = []
