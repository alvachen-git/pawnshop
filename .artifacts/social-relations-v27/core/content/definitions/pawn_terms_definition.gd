class_name PawnTermsDefinition
extends RefCounted

var _transfer_ratio := 0.8
var transfer_ratio: float:
	get: return _transfer_ratio
var _id: String
var id: String:
	get: return _id
var _display_name: String
var display_name: String:
	get: return _display_name
var _loan_ratio: float
var loan_ratio: float:
	get: return _loan_ratio
var _term_nights: int
var term_nights: int:
	get: return _term_nights
var _redemption_fee_ratio: float
var redemption_fee_ratio: float:
	get: return _redemption_fee_ratio
var _return_mode: String
var return_mode: String:
	get: return _return_mode
var _window_start: int
var window_start: int:
	get: return _window_start
var _window_end: int
var window_end: int:
	get: return _window_end
var _redeem_minutes: int
var redeem_minutes: int:
	get: return _redeem_minutes
var _extension_nights: int
var extension_nights: int:
	get: return _extension_nights
var _extension_fee_ratio: float
var extension_fee_ratio: float:
	get: return _extension_fee_ratio
var _extend_minutes: int
var extend_minutes: int:
	get: return _extend_minutes

static func from_dto(dto: PawnTermsDTO) -> PawnTermsDefinition:
	var result := PawnTermsDefinition.new()
	result._id = dto.id
	result._transfer_ratio = dto.transfer_ratio
	result._display_name = dto.display_name
	result._loan_ratio = dto.loan_ratio
	result._term_nights = dto.term_nights
	result._redemption_fee_ratio = dto.redemption_fee_ratio
	result._return_mode = dto.return_mode
	result._window_start = dto.window_start
	result._window_end = dto.window_end
	result._redeem_minutes = dto.redeem_minutes
	result._extension_nights = dto.extension_nights
	result._extension_fee_ratio = dto.extension_fee_ratio
	result._extend_minutes = dto.extend_minutes
	return result

