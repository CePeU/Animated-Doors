extends Reference

static func filename(label):
	var result = ""
	for i in range(label.length()):
		var character = label.substr(i, 1)
		result += "_" if label.ord_at(i) < 32 or character in '<>:"/\\|?*' else character
	result = result.strip_edges()
	while result.ends_with(".") or result.ends_with(" "):
		result = result.substr(0, result.length() - 1)
	if result.empty():
		result = "Level"
	var stem = result.split(".")[0].to_upper()
	if stem in ["CON", "PRN", "AUX", "NUL", "CONIN$", "CONOUT$"] or (stem.length() == 4 and (stem.begins_with("COM") or stem.begins_with("LPT")) and stem[3] in "123456789¹²³"):
		result = "_" + result
	# Stay below NTFS's UTF-16 and ext4's UTF-8 component limits, including suffixes.
	while result.to_utf8().size() > 180:
		result = result.substr(0, result.length() - 1)
	return result

static func paths(directory, labels, extension, prefix = ""):
	var used = {}
	var result = []
	for label in labels:
		var base = filename(prefix + str(label))
		var candidate = base
		var suffix = 2
		while used.has(candidate.to_lower()):
			candidate = base + " (" + str(suffix) + ")"
			suffix += 1
		used[candidate.to_lower()] = true
		result.append(directory.plus_file(candidate + "." + extension))
	return result

static func metadata(multi_file, map_name):
	var now = OS.get_datetime(true)
	return {"multi_file": multi_file, "map_name": map_name, "export_timestamp": "%04d-%02d-%02dT%02d:%02d:%02dZ" % [now.year, now.month, now.day, now.hour, now.minute, now.second]}
