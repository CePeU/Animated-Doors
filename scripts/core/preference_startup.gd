extends Reference

const KEY = "export_dialog_compatibility"

static func build(builder, current_version):
	# Standalone Config.build owns its ConfigFile defaults. _Lib's existing
	# agent owns its JSON backend; inspect it before load/save to distinguish
	# absent from explicitly empty. Never substitute another preference file.
	var agent = builder.get_agent() if builder.has_method("get_agent") else null
	var path = agent.get("_config_file") if agent != null else null
	var absent = false
	var file = File.new()
	if path is String:
		absent = not file.file_exists(path)
		if file.open(path,File.READ)==OK:
			var parsed = JSON.parse(file.get_as_text())
			file.close()
			absent = parsed.error==OK and parsed.result is Dictionary and not parsed.result.has(KEY)
	var preferences = builder.build()
	if agent != null and absent:
		if not current_version.empty():
			agent.save_cfg(true)
		else:
			# _Lib creates a new file on first build, including empty widget
			# defaults. An unqueryable host version must remain ABSENT, rather
			# than becoming a deliberate empty opt-out on the next startup.
			if file.open(path,File.READ)==OK:
				var parsed = JSON.parse(file.get_as_text())
				file.close()
				if parsed.error==OK and parsed.result is Dictionary and parsed.result.get(KEY)=="":
					parsed.result.erase(KEY)
					if file.open(path,File.WRITE)==OK:
						file.store_string(JSON.print(parsed.result,"\t"))
						file.close()
	return preferences
