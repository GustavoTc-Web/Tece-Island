class_name IslandJournal
extends Node
signal changed
var discovered: Array[String] = []
var unread := {}
var world: Node2D
const RECORDS := {
	"arrival": {"title": "1 · A expedição", "text": "Dia 7. O rádio deixou de alcançar o continente. Nossa expedição veio estudar a ilha, mas os coelhos agora fogem antes de nos ver, como se ouvissem outro chamado. Levamos os aparelhos para a fazenda do Pântano. Saia desta casa pela trilha ao norte, siga para leste até o poço do Pântano e procure a fazenda a sudeste dele. — Lia"},
	"trail": {"title": "2 · Frequência no silêncio", "text": "Dia 12. Na fazenda, o receptor desligado estalou quando escureceu. As aranhas se reuniram voltadas para oeste. Anotei a mesma frequência três vezes, sempre perto das Ruínas Escuras. Volte para oeste pela passagem dos poços, cruze a Floresta e a região aquática. Nas ruínas além da água, procure o templo ao norte da passagem central. Raul levou o último receptor. — Lia"},
	"signal": {"title": "3 · O Último Sinal", "text": "Dia 16. No templo, a frequência não veio do rádio: veio debaixo das pedras. Quando desliguei o receptor, a luz continuou pulsando no intervalo da nossa chamada de socorro. Os animais pararam ao mesmo tempo. Algo aqui aprendeu a responder, mas repetiu uma voz que ainda não tínhamos transmitido. Deixei o aparelho lacrado. Se encontrarem Lia, avisem: o próximo sinal pode vir de nós. — Raul"}
}
func initialize(source: Node2D) -> void:
	world = source
	var locations := [Vector2(550, 1305), Vector2(3250, 1175), source.ruins.temples[0].global_position + Vector2(-90, 80)]
	var ids := ["arrival", "trail", "signal"]
	for i in range(ids.size()):
		var note := ExpeditionRecord.new()
		note.record_id = ids[i]
		note.journal = self
		note.position = locations[i]
		source.get_node("WorldObjects").add_child(note)
func collect(id: String) -> bool:
	if not RECORDS.has(id) or id in discovered: return false
	discovered.append(id)
	unread[id] = true
	changed.emit()
	return true
func read_page(id: String) -> void:
	if id not in discovered: return
	unread.erase(id)
	changed.emit()
func capture() -> Dictionary:
	return {"discovered": discovered.duplicate(), "unread": unread.duplicate()}
func restore(data: Dictionary) -> bool:
	if not data.get("discovered", []) is Array or not data.get("unread", {}) is Dictionary: return false
	var pages: Array[String] = []
	for id in data.get("discovered", []):
		if not id is String or not RECORDS.has(id) or id in pages: return false
		pages.append(id)
	discovered = pages
	unread = {}
	for id in data.get("unread", {}):
		if id in discovered and bool(data.unread[id]): unread[id] = true
	if is_inside_tree():
		for note in get_tree().get_nodes_in_group("expedition_records"):
			if note.journal == self and note.record_id in discovered: note.queue_free()
	changed.emit()
	return true
