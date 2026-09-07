extends Node

signal cart_updated
signal search_completed(results)
signal search_error(message)

# URL da API do Busca Preço Parintins (Vercel ou local)
var api_base_url: String = "https://busca-preco-parintins.vercel.app/api/search"
var local_api_url: String = "/api/search" # Para quando rodar na Web

# Bairros conhecidos de Parintins
var parintins_bairros: Array[String] = [
	"Todos os Bairros",
	"Centro",
	"Palmares",
	"Itaúna",
	"Paulo Corrêa",
	"Santa Clara",
	"São Vicente",
	"São José",
	"Francesa",
	"Djard Vieira",
	"Castanheira",
	"Emílio Moreira",
	"Santa Rita",
	"Macurany",
	"União"
]

# Carrinho de Compras Inteligente
# Cada item: { "id": String, "nome": String, "quantidade": int, "preco": float, "estabelecimento": String, "bairro": String }
var cart_items: Array[Dictionary] = []

# Histórico das últimas pesquisas
var search_history: Array[String] = []

func _ready() -> void:
	# Se estiver rodando na Web, usa URL relativa para evitar CORS
	if OS.has_feature("web"):
		api_base_url = "/api/search"

func add_to_cart(item: Dictionary, qty: int = 1) -> void:
	# Verifica se já existe produto com o mesmo nome e estabelecimento no carrinho
	for i in range(cart_items.size()):
		if cart_items[i].get("nome", "") == item.get("nome", "") and cart_items[i].get("estabelecimento", "") == item.get("estabelecimento", ""):
			cart_items[i]["quantidade"] += qty
			cart_updated.emit()
			return
	
	var new_entry = item.duplicate()
	new_entry["quantidade"] = max(1, qty)
	cart_items.append(new_entry)
	cart_updated.emit()

func remove_from_cart(index: int) -> void:
	if index >= 0 and index < cart_items.size():
		cart_items.remove_at(index)
		cart_updated.emit()

func update_cart_quantity(index: int, new_qty: int) -> void:
	if index >= 0 and index < cart_items.size():
		if new_qty <= 0:
			remove_from_cart(index)
		else:
			cart_items[index]["quantidade"] = new_qty
			cart_updated.emit()

func clear_cart() -> void:
	cart_items.clear()
	cart_updated.emit()

func get_cart_total() -> float:
	var total: float = 0.0
	for item in cart_items:
		var price: float = float(item.get("preco", 0.0))
		var qty: int = int(item.get("quantidade", 1))
		total += price * qty
	return total

func format_currency(value: float) -> String:
	var str_val: String = "%.2f" % value
	return "R$ " + str_val.replace(".", ",")
