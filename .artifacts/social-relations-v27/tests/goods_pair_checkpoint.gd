extends "res://tests/goods_checkpoint.gd"
func run() -> void:
	catalog = JsonContentProvider.new("res://data/goods_expertise_manifest.json").load_catalog().catalog
	run_def = catalog.get_definition("runs", catalog.default_run_id)
	for size in [1280, 1600]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(QA + "goods_%d_pair.json" % size))
		var codec := SaveCodec.new()
		check(codec.decode(data, run_def, 21, catalog, true) != null, "actual UI pair checkpoint " + codec.error_message)
		check(data.sale_batches.size() == 1 and data.sale_batches[0].pairs.size() == 1, "UI fixture really includes paid original pair")
		var bad := data.duplicate(true); bad.sale_batches[0].pairs.append(bad.sale_batches[0].pairs[0].duplicate()); reject(bad, "duplicate pair bonus")
		bad = data.duplicate(true); bad.sale_batches[0].pairs = []; reject(bad, "missing pair basis")
		bad = data.duplicate(true); bad.expertise_history[1].result = "different"; reject(bad, "forged pair conclusion")
		bad = data.duplicate(true); bad.expertise_history[1].start = bad.sale_batches[0].minute; bad.expertise_history[1].minute = bad.expertise_history[1].start + 10; reject(bad, "certificate after sale")
		bad = data.duplicate(true); bad.sale_records[0].price += 1; reject(bad, "forged odd bonus share")
		bad = data.duplicate(true); bad.sale_batches[0].pairs = [["missing", "missing"]]; reject(bad, "invalid pair objects")
	print("GOODS PAIR CHECKPOINT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
