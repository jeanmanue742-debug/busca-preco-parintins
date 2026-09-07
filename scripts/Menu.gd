extends Control

# Scripts e nós
const ApiClientClass = preload("res://scripts/ApiClient.gd")
var api_client: Node

# Referências da Interface
@onready var tab_container: TabContainer = %TabContainer
@onready var input_search: LineEdit = %InputSearch
@onready var opt_dias: OptionButton = %OptDias
@onready var opt_bairros: OptionButton = %OptBairros
@onready var btn_search: Button = %BtnSearch
@onready var lbl_status: Label = %LblStatus
@onready var cart_badge_btn: Button = %BtnCartBadge

# Aba 1 - Pesquisa
@onready var results_container: GridContainer = %GridResults
@onready var empty_search_panel: PanelContainer = %EmptySearch

# Aba 2 - Carrinho & Comparador
@onready var cart_items_container: VBoxContainer = %ItemsList
@onready var empty_cart_label: Label = %EmptyCartLabel
@onready var lbl_cart_total: Label = %LblTotalVal
@onready var lbl_winner_store: Label = %LblWinnerName
@onready var lbl_winner_val: Label = %LblWinnerPrice
@onready var lbl_winner_economy: Label = %LblWinnerEconomy
@onready var store_comparison_container: VBoxContainer = %StoreList
@onready var btn_clear_cart: Button = %BtnClearCart
@onready var btn_copy_whatsapp: Button = %BtnCopyWhatsApp

# Aba 3 - Mercados
@onready var markets_list_container: VBoxContainer = %MarketsList

# Cenas
var product_card_scene = preload("res://scenes/ProductCard.tscn")
var cart_item_scene = preload("res://scenes/CartItem.tscn")

# Dados em cache
var all_current_results: Array = []
var known_stores: Dictionary = {}

func _ready() -> void:
	api_client = ApiClientClass.new()
	add_child(api_client)
	
	Global.search_completed.connect(_on_search_completed)
	Global.search_error.connect(_on_search_error)
	Global.cart_updated.connect(_on_cart_updated)
	
	_setup_filters()
	_setup_events()
	_update_cart_ui()
	
	# Realiza uma busca inicial automática por arroz para já carregar itens de Parintins
	_do_search("arroz")

func _setup_filters() -> void:
	opt_dias.clear()
	opt_dias.add_item("Últimos 7 dias", 168)
	opt_dias.add_item("Últimas 48 horas", 48)
	opt_dias.add_item("Últimas 24 horas", 24)
	opt_dias.select(0)
	
	opt_bairros.clear()
	for b in Global.parintins_bairros:
		opt_bairros.add_item(b)
	opt_bairros.select(0)

func _setup_events() -> void:
	btn_search.pressed.connect(func(): _do_search(input_search.text))
	input_search.text_submitted.connect(func(_text): _do_search(input_search.text))
	cart_badge_btn.pressed.connect(func(): tab_container.current_tab = 1)
	btn_clear_cart.pressed.connect(_on_clear_cart_pressed)
	btn_copy_whatsapp.pressed.connect(_on_copy_whatsapp_pressed)
	opt_bairros.item_selected.connect(func(_idx): _filter_and_render_results())

func _do_search(query: String) -> void:
	if query.strip_edges().is_empty():
		lbl_status.text = "Digite o nome de um produto."
		return
	
	lbl_status.text = "Buscando preços de '%s' na SEFAZ (Parintins - AM)..." % query.strip_edges()
	btn_search.disabled = true
	
	var dias = "168"
	var selected_id = opt_dias.get_selected_id()
	if selected_id > 0:
		dias = str(selected_id)
	
	api_client.search(query, dias, "Parintins")

func _on_search_completed(items: Array) -> void:
	btn_search.disabled = false
	all_current_results = items
	
	if items.is_empty():
		lbl_status.text = "Nenhum produto encontrado em Parintins para este termo."
		empty_search_panel.visible = true
		_clear_results_grid()
		return
	
	lbl_status.text = "Encontrados %d preços em Parintins - AM." % items.size()
	empty_search_panel.visible = false
	
	# Registra estabelecimentos descobertos
	for item in items:
		var store = item.get("estabelecimento", "")
		var bairro = item.get("bairro", "")
		var endereco = item.get("endereco", "")
		if not store.is_empty() and not known_stores.has(store):
			known_stores[store] = { "nome": store, "bairro": bairro, "endereco": endereco }
	
	_render_markets_tab()
	_filter_and_render_results()

func _on_search_error(msg: String) -> void:
	btn_search.disabled = false
	lbl_status.text = "Aviso: " + msg

func _clear_results_grid() -> void:
	for child in results_container.get_children():
		child.queue_free()

func _filter_and_render_results() -> void:
	_clear_results_grid()
	
	var selected_bairro = opt_bairros.get_item_text(opt_bairros.selected)
	var filtered = []
	
	for item in all_current_results:
		if selected_bairro == "Todos os Bairros":
			filtered.append(item)
		else:
			var item_bairro = item.get("bairro", "").to_upper()
			if item_bairro.contains(selected_bairro.to_upper()):
				filtered.append(item)
	
	if filtered.is_empty():
		empty_search_panel.visible = true
		return
	
	empty_search_panel.visible = false
	
	# Primeiro item é o mais barato
	for i in range(filtered.size()):
		var card = product_card_scene.instantiate()
		results_container.add_child(card)
		card.setup(filtered[i], i == 0)

# Atualização do Carrinho e Comparador de Supermercados
func _on_cart_updated() -> void:
	_update_cart_ui()

func _update_cart_ui() -> void:
	# Atualiza o badge do topo
	var total_items = 0
	for it in Global.cart_items:
		total_items += int(it.get("quantidade", 1))
	
	var cart_total = Global.get_cart_total()
	cart_badge_btn.text = "🛒 Carrinho (%d itens • %s)" % [total_items, Global.format_currency(cart_total)]
	
	# Limpa lista do carrinho
	for child in cart_items_container.get_children():
		child.queue_free()
	
	if Global.cart_items.is_empty():
		empty_cart_label.visible = true
		lbl_cart_total.text = "R$ 0,00"
		lbl_winner_store.text = "Adicione itens à lista"
		lbl_winner_val.text = "R$ 0,00"
		lbl_winner_economy.text = "Adicione produtos para comparar supermercados."
		_clear_store_comparisons()
		return
	
	empty_cart_label.visible = false
	lbl_cart_total.text = Global.format_currency(cart_total)
	
	# Renderiza itens do carrinho
	for i in range(Global.cart_items.size()):
		var item_ui = cart_item_scene.instantiate()
		cart_items_container.add_child(item_ui)
		item_ui.setup(i, Global.cart_items[i])
	
	_calculate_store_comparisons()

func _calculate_store_comparisons() -> void:
	_clear_store_comparisons()
	
	# Agrupa preços por supermercado
	# store_totals: { "CASA SANTOS": { "total": float, "count": int } }
	var store_totals: Dictionary = {}
	
	for item in Global.cart_items:
		var store = item.get("estabelecimento", "Outro")
		var price = float(item.get("preco", 0.0))
		var qty = int(item.get("quantidade", 1))
		var subtotal = price * qty
		
		if not store_totals.has(store):
			store_totals[store] = { "total": 0.0, "count": 0, "bairro": item.get("bairro", "") }
		
		store_totals[store]["total"] += subtotal
		store_totals[store]["count"] += qty
	
	if store_totals.is_empty():
		return
	
	# Ordena estabelecimentos por valor total
	var stores_arr = []
	for s_name in store_totals.keys():
		stores_arr.append({
			"nome": s_name,
			"total": store_totals[s_name]["total"],
			"count": store_totals[s_name]["count"],
			"bairro": store_totals[s_name]["bairro"]
		})
	
	stores_arr.sort_custom(func(a, b): return a["total"] < b["total"])
	
	# Destaque do vencedor
	var winner = stores_arr[0]
	lbl_winner_store.text = "🏆 " + winner["nome"]
	lbl_winner_val.text = Global.format_currency(winner["total"])
	
	if stores_arr.size() > 1:
		var most_expensive = stores_arr[stores_arr.size() - 1]
		var diff = most_expensive["total"] - winner["total"]
		if diff > 0.01:
			lbl_winner_economy.text = "Economia de até %s comprando no %s!" % [Global.format_currency(diff), winner["nome"]]
		else:
			lbl_winner_economy.text = "Preços equivalentes entre os estabelecimentos."
	else:
		lbl_winner_economy.text = "Supermercado mais vantajoso para esta compra."
	
	# Lista comparativa completa
	for s in stores_arr:
		var row = HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 36)
		
		var name_lbl = Label.new()
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.text = "%s (%s)" % [s["nome"], s["bairro"]]
		name_lbl.add_theme_font_size_override("font_size", 13)
		
		var price_lbl = Label.new()
		price_lbl.text = Global.format_currency(s["total"])
		price_lbl.add_theme_font_size_override("font_size", 14)
		price_lbl.add_theme_color_override("font_color", Color(0.15, 0.95, 0.55, 1))
		
		row.add_child(name_lbl)
		row.add_child(price_lbl)
		store_comparison_container.add_child(row)

func _clear_store_comparisons() -> void:
	for child in store_comparison_container.get_children():
		child.queue_free()

func _render_markets_tab() -> void:
	for child in markets_list_container.get_children():
		child.queue_free()
	
	if known_stores.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "Realize pesquisas de produtos para listar os supermercados ativos em Parintins."
		markets_list_container.add_child(empty_lbl)
		return
	
	for s_name in known_stores.keys():
		var data = known_stores[s_name]
		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(0, 70)
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.13, 0.1, 0.85)
		style.set_corner_radius_all(10)
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.12, 0.38, 0.25, 0.4)
		panel.add_theme_stylebox_override("panel", style)
		
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 14)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_right", 14)
		margin.add_theme_constant_override("margin_bottom", 10)
		
		var hbox = HBoxContainer.new()
		
		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var store_lbl = Label.new()
		store_lbl.text = "🏪 " + s_name
		store_lbl.add_theme_font_size_override("font_size", 15)
		store_lbl.add_theme_color_override("font_color", Color(0.95, 0.75, 0.25, 1))
		
		var addr_lbl = Label.new()
		addr_lbl.text = data.get("endereco", "Parintins - AM")
		addr_lbl.add_theme_font_size_override("font_size", 12)
		addr_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.75, 1))
		
		vbox.add_child(store_lbl)
		vbox.add_child(addr_lbl)
		
		var btn_view = Button.new()
		btn_view.text = "Ver Preços"
		btn_view.custom_minimum_size = Vector2(100, 32)
		btn_view.pressed.connect(func():
			tab_container.current_tab = 0
			# Seleciona bairro correspondente se possível
			var bairro = data.get("bairro", "")
			for i in range(opt_bairros.item_count):
				if opt_bairros.get_item_text(i).to_upper() == bairro.to_upper():
					opt_bairros.select(i)
					_filter_and_render_results()
					break
		)
		
		hbox.add_child(vbox)
		hbox.add_child(btn_view)
		margin.add_child(hbox)
		panel.add_child(margin)
		markets_list_container.add_child(panel)

func _on_clear_cart_pressed() -> void:
	Global.clear_cart()

func _on_copy_whatsapp_pressed() -> void:
	if Global.cart_items.is_empty():
		return
	
	var text = "*🛒 LISTA DE COMPRAS - BUSCA PREÇO PARINTINS*\n\n"
	for item in Global.cart_items:
		var name = item.get("nome", "")
		var qty = item.get("quantidade", 1)
		var store = item.get("estabelecimento", "")
		var price = Global.format_currency(float(item.get("preco", 0.0)) * qty)
		text += "• %dx %s - %s (%s)\n" % [qty, name, price, store]
	
	text += "\n*TOTAL ESTIMADO:* %s\n" % Global.format_currency(Global.get_cart_total())
	text += "\n_Gerado pelo Busca Preço Parintins_"
	
	DisplayServer.clipboard_set(text)
	btn_copy_whatsapp.text = "✓ Lista Copiada!"
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(btn_copy_whatsapp):
		btn_copy_whatsapp.text = "Copiar para WhatsApp"
