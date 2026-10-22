extends Reference

const Geometry = preload("door_geometry.gd")

# Exact full-record matches take precedence. Tolerant matches must be unique.
# One consumed native index per snapshot preserves identical stacked instances.
static func equivalent(a, b, epsilon = 0.0):
	if Geometry.number(a) and Geometry.number(b):
		return abs(float(a) - float(b)) <= epsilon
	if typeof(a) != typeof(b):
		return false
	if a is Dictionary:
		if a.size() != b.size():
			return false
		for key in a:
			if not b.has(key) or not equivalent(a[key], b[key], epsilon):
				return false
		return true
	if a is Array:
		if a.size() != b.size():
			return false
		for i in range(a.size()):
			if not equivalent(a[i], b[i], epsilon):
				return false
		return true
	return a == b

static func same_portal(a, b, epsilon):
	if equivalent(a, b, epsilon):
		return true
	if not (b.get("bounds") is Array) or b.bounds.size() != 2:
		return false
	var reversed = b.duplicate(true)
	reversed.bounds.invert()
	return equivalent(a, reversed, epsilon)

static func associate(snapshots, portals):
	var used = {}
	var matches = []
	# Reserve all exact matches before any tolerant match can consume them.
	for snapshot in snapshots:
		var exact = []
		for i in range(portals.size()):
			if used.has(i):
				continue
			if same_portal(snapshot.native, portals[i], 0.0):
				exact.append(i)
		var index = -1
		if not exact.empty():
			index = exact[0]
			used[index] = true
		matches.append(index)
	var pending = {}
	var claimed = {}
	for s in range(snapshots.size()):
		if matches[s] != -1:
			continue
		var candidates = []
		for i in range(portals.size()):
			if not used.has(i) and same_portal(snapshots[s].native, portals[i], Geometry.EPSILON):
				candidates.append(i)
		if candidates.size() != 1 or claimed.has(candidates[0]):
			return Geometry.failure("PORTAL_MATCH", "Door %s cannot be uniquely associated with a native portal." % snapshots[s].id)
		pending[s] = candidates[0]
		claimed[candidates[0]] = true
	for s in pending:
		matches[s] = pending[s]
	return Geometry.success(matches)
