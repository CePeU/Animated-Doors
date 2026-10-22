extends Reference

const Geometry = preload("door_geometry.gd")
const Contract = preload("export_contract.gd")
var failure_stage = "" # Deterministic fault injection for the test harness only.

func write(path, data, transaction_id):
	var valid = Contract.validate(data)
	if not valid.ok:
		return valid
	return _write(path, JSON.print(data).to_utf8(), transaction_id, true)

func write_image(path, bytes, transaction_id, format):
	if bytes.size() < 12:
		return Geometry.failure("IMAGE", "Rendered image is incomplete.")
	var image = Image.new()
	var error = ERR_INVALID_DATA
	if format == "png":
		error = image.load_png_from_buffer(bytes)
	elif format == "webp":
		error = image.load_webp_from_buffer(bytes)
	elif format == "jpg":
		error = image.load_jpg_from_buffer(bytes)
	if error != OK:
		return Geometry.failure("IMAGE", "Rendered image cannot be decoded as " + format)
	return _write(path, bytes, transaction_id, false)

func write_native(path, data, transaction_id, mime):
	var valid = Contract.validate_native(data, mime)
	if not valid.ok:
		return valid
	return _write(path, JSON.print(data).to_utf8(), transaction_id, true, mime)

func _write(path, bytes, transaction_id, is_json, native_mime = ""):
	var stage = path + ".animated-doors-" + str(transaction_id) + ".tmp"
	var backup = stage + ".backup"
	var dir = Directory.new()
	if dir.file_exists(stage) or dir.file_exists(backup):
		return Geometry.failure("STAGING_EXISTS", "Refusing to reuse staging paths: " + stage)
	var file = File.new()
	if failure_stage == "open" or file.open(stage, File.WRITE) != OK:
		return Geometry.failure("WRITE_OPEN", "Cannot open staged export: " + stage)
	file.store_buffer(bytes)
	file.flush()
	var error = file.get_error()
	file.close()
	if error != OK or failure_stage == "write":
		return _failed_stage(dir, stage, "WRITE", "Writing the staged export failed.")
	if file.open(stage, File.READ) != OK:
		return _failed_stage(dir, stage, "READ_BACK", "Cannot reopen the staged export.")
	var stored = file.get_buffer(file.get_len())
	file.close()
	if stored != bytes or failure_stage == "validate":
		return _failed_stage(dir, stage, "READ_BACK", "Staged export failed verification.")
	if is_json:
		var parsed = JSON.parse(stored.get_string_from_utf8())
		if parsed.error != OK:
			return _failed_stage(dir, stage, "READ_BACK", "Staged JSON is invalid.")
		var valid = Contract.validate(parsed.result, false) if native_mime.empty() else Contract.validate_native(parsed.result, native_mime, false)
		if not valid.ok:
			return _failed_stage(dir, stage, "READ_BACK", valid.message)
	var had_original = dir.file_exists(path)
	if had_original and (failure_stage == "backup" or dir.rename(path, backup) != OK):
		return _failed_stage(dir, stage, "BACKUP", "Cannot preserve the existing export.")
	if failure_stage in ["commit", "rollback"] or dir.rename(stage, path) != OK:
		if had_original:
			if failure_stage == "rollback" or dir.rename(backup, path) != OK:
				return Geometry.failure("RECOVERY_REQUIRED", "The original export is preserved at %s. Restore it to %s. The new staged file is %s." % [backup, path, stage])
		return _failed_stage(dir, stage, "COMMIT", "Cannot replace the destination; the original export was preserved.")
	if had_original and dir.remove(backup) != OK:
		return Geometry.success({"path": path, "notice": "Export saved; old backup could not be removed: " + backup})
	return Geometry.success({"path": path, "notice": ""})

func _failed_stage(dir, stage, code, message):
	if dir.file_exists(stage) and dir.remove(stage) != OK:
		message += " Staged file retained: " + stage
	return Geometry.failure(code, message)
