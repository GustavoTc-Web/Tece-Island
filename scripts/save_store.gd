class_name SaveStore
extends RefCounted
const VERSION := 4
var path := "user://solo-progress.json"
var error := ""

func read() -> Dictionary:
	error = ""
	if not FileAccess.file_exists(path): return {}
	var parser := JSON.new()
	var parsed := parser.parse(FileAccess.get_file_as_string(path))
	var data = parser.data
	if parsed != OK or not data is Dictionary or not data.get("inventory") is Dictionary or int(data.get("version", -1)) < 0 or int(data.get("version", -1)) > VERSION:
		error = "Não foi possível carregar o progresso. O arquivo original foi preservado."
		return {}
	if int(data.version) < VERSION:
		# Keep the exact pre-migration bytes before changing any in-memory fields.
		var backup := path + ".before-v%d.json" % VERSION
		if not FileAccess.file_exists(backup) and DirAccess.copy_absolute(path, backup) != OK:
			error = "Não foi possível criar o backup. A conversão do progresso foi cancelada."
			return {}
		data.version = VERSION
	return data

func write(data: Dictionary) -> bool:
	error = ""
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		error = "Não foi possível salvar o progresso. Tente novamente."
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var result := file.get_error()
	file.close()
	if result != OK or not JSON.parse_string(FileAccess.get_file_as_string(temporary)) is Dictionary:
		error = "Falha ao gravar o progresso; o save anterior foi preservado."
		return false
	if FileAccess.file_exists(path) and DirAccess.copy_absolute(path, path + ".backup.json") != OK:
		error = "Falha ao criar backup; o save anterior foi preservado."
		return false
	if DirAccess.rename_absolute(temporary, path) != OK:
		error = "Não foi possível substituir o save; o progresso anterior foi preservado."
		return false
	return true

static func point(value: Vector2) -> Array:
	return [value.x, value.y]

static func vector(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if not value is Array or value.size() != 2: return fallback
	if not (value[0] is float or value[0] is int) or not (value[1] is float or value[1] is int): return fallback
	var result := Vector2(value[0], value[1])
	return result if result.is_finite() else fallback

static func key(value: Vector2) -> String:
	return "%d,%d" % [roundi(value.x), roundi(value.y)]
