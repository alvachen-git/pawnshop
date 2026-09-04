class_name PawnTermsDTO
extends RefCounted

var id: String
var display_name: String
var loan_ratio: float
var term_nights: int
var redemption_fee_ratio: float
var return_mode: String
var window_start: int
var window_end: int
var redeem_minutes: int
var extension_nights: int
var extension_fee_ratio: float
var extend_minutes: int

static func from_source(source: Dictionary) -> PawnTermsDTO:
	var dto := PawnTermsDTO.new()
	dto.id = source.id
	dto.display_name = source.display_name
	dto.loan_ratio = float(source.loan_ratio)
	dto.term_nights = int(source.term_nights)
	dto.redemption_fee_ratio = float(source.redemption_fee_ratio)
	dto.return_mode = source.return_mode
	dto.window_start = int(source.window_start)
	dto.window_end = int(source.window_end)
	dto.redeem_minutes = int(source.redeem_minutes)
	dto.extension_nights = int(source.extension_nights)
	dto.extension_fee_ratio = float(source.extension_fee_ratio)
	dto.extend_minutes = int(source.extend_minutes)
	return dto

