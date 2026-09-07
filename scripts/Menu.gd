extends Control

# Scripts e nós
const ApiClientClass = preload("res://scripts/ApiClient.gd")
var api_client: Node

# Referências da Interface
@onready var tab_container: TabContainer = %TabContainer
@onready var nav_btn_search: Button = %NavBtnSearch
@onready var nav_btn_cart: Button = %NavBtnCart
@onready var nav_btn_markets: Button = %NavBtnMarkets

@onready var input_search: LineEdit = %InputSearch
@onready var opt_dias: OptionButton = %OptDias
@onready var opt_bairros: OptionButton = %OptBairros
@onready var btn_search: Button = %BtnSearch
@onready var lbl_status: Label = %LblStatus
@onready var cart_badge_btn: Button = %BtnCartBadge
@onready var chips_container: HBoxContainer = %ChipsContainer

# Aba 1 - Pesquisa
@onready var results_container: GridContainer = %GridResults
@onready var empty_search_panel: PanelContainer = %EmptySearch
@onready var btn_load_more: Button = %BtnLoadMore

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

# Estilos de Navegação
var style_tab_active: StyleBoxFlat
var style_tab_inactive: StyleBoxFlat

# Dados em cache e paginação
var all_current_results: Array = []
var known_stores: Dictionary = {}
var current_query: String = ""
var current_dias: String = "168"
var next_page_to_load: int = 0
var has_more_pages: bool = false
var is_loading_more: bool = false

func _ready() -> void:
	api_client = ApiClientClass.new()
	add_child(api_client)
	
	_create_tab_styles()
	
	Global.search_completed.connect(_on_search_completed)
	Global.search_error.connect(_on_search_error)
	Global.cart_updated.connect(_on_cart_updated)
	
	_setup_filters()
	_setup_chips()
	_setup_events()
	_update_cart_ui()
	_switch_tab(0)
	
	# Realiza uma busca inicial automática por arroz para já carregar itens de Parintins
	_do_search("arroz")

func _create_tab_styles() -> void:
	style_tab_active = StyleBoxFlat.new()
	style_tab_active.bg_color = Color(0.15, 0.42, 0.92, 1)
	style_tab_active.border_width_bottom = 3
	style_tab_active.border_color = Color(0.08, 0.28, 0.72, 1)
	style_tab_active.set_corner_radius_all(14)
	style_tab_active.content_margin_left = 20
	style_tab_active.content_margin_top = 12
	style_tab_active.content_margin_right = 20
	style_tab_active.content_margin_bottom = 12
	style_tab_active.shadow_color = Color(0.15, 0.42, 0.92, 0.3)
	style_tab_active.shadow_size = 8
	style_tab_active.shadow_offset = Vector2(0, 3)
	
	style_tab_inactive = StyleBoxFlat.new()
	style_tab_inactive.bg_color = Color(1, 1, 1, 1)
	style_tab_inactive.border_width_left = 1
	style_tab_inactive.border_width_top = 1
	style_tab_inactive.border_width_right = 1
	style_tab_inactive.border_width_bottom = 2
	style_tab_inactive.border_color = Color(0.86, 0.9, 0.95, 1)
	style_tab_inactive.set_corner_radius_all(14)
	style_tab_inactive.content_margin_left = 20
	style_tab_inactive.content_margin_top = 12
	style_tab_inactive.content_margin_right = 20
	style_tab_inactive.content_margin_bottom = 12

func _switch_tab(idx: int) -> void:
	tab_container.current_tab = idx
	
	var btns = [nav_btn_search, nav_btn_cart, nav_btn_markets]
	for i in range(btns.size()):
		var b = btns[i]
		if i == idx:
			b.add_theme_stylebox_override("normal", style_tab_active)
			b.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		else:
			b.add_theme_stylebox_override("normal", style_tab_inactive)
			b.add_theme_color_override("font_color", Color(0.25, 0.32, 0.42, 1))

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

func _setup_chips() -> void:
	var suggestions = ["Arroz", "Feijão", "Açúcar", "Café", "Leite", "Óleo", "Frango", "Carne", "Pão"]
	for s in suggestions:
		var chip = Button.new()
		chip.text = s
		chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		var chip_style = StyleBoxFlat.new()
		chip_style.bg_color = Color(0.94, 0.96, 0.99, 1)
		chip_style.border_width_left = 1
		chip_style.border_width_top = 1
		chip_style.border_width_right = 1
		chip_style.border_width_bottom = 1
		chip_style.border_color = Color(0.82, 0.88, 0.96, 1)
		chip_style.set_corner_radius_all(12)
		chip_style.content_margin_left = 12
		chip_style.content_margin_top = 4
		chip_style.content_margin_right = 12
		chip_style.content_margin_bottom = 4
		
		var chip_hover = chip_style.duplicate()
		chip_hover.bg_color = Color(0.88, 0.93, 1, 1)
		chip_hover.border_color = Color(0.6, 0.75, 0.95, 1)
		
		chip.add_theme_stylebox_override("normal", chip_style)
		chip.add_theme_stylebox_override("hover", chip_hover)
		chip.add_theme_color_override("font_color", Color(0.12, 0.35, 0.8, 1))
		chip.add_theme_font_size_override("font_size", 12)
		
		chip.pressed.connect(func():
			input_search.text = s
			_do_search(s)
		)
		chips_container.add_child(chip)

func _setup_events() -> void:
	nav_btn_search.pressed.connect(func(): _switch_tab(0))
	nav_btn_cart.pressed.connect(func(): _switch_tab(1))
	nav_btn_markets.pressed.connect(func(): _switch_tab(2))
	
	btn_search.pressed.connect(func(): _do_search(input_search.text))
	input_search.text_submitted.connect(func(_text): _do_search(input_search.text))
	cart_badge_btn.pressed.connect(func(): _switch_tab(1))
	btn_clear_cart.pressed.connect(_on_clear_cart_pressed)
	btn_copy_whatsapp.pressed.connect(_on_copy_whatsapp_pressed)
	opt_bairros.item_selected.connect(func(_idx): _filter_and_render_results())
	btn_load_more.pressed.connect(_on_load_more_pressed)

func _do_search(query: String, is_load_more_call: bool = false) -> void:
	if query.strip_edges().is_empty():
		lbl_status.text = "Digite o nome de um produto."
		return
	
	is_loading_more = is_load_more_call
	current_query = query.strip_edges()
	
	var dias = "168"
	var selected_id = opt_dias.get_selected_id()
	if selected_id > 0:
		dias = str(selected_id)
	current_dias = dias
	
	if not is_loading_more:
		lbl_status.text = "Buscando todos os preços de '%s' na SEFAZ (Parintins - AM)..." % current_query
		btn_search.disabled = true
		btn_load_more.visible = false
		api_client.search(current_query, current_dias, "Parintins", 1)
	else:
		lbl_status.text = "Carregando mais preços da SEFAZ (Página %d+)..." % next_page_to_load
		btn_load_more.disabled = true
		btn_load_more.text = "Carregando mais preços..."
		api_client.search(current_query, current_dias, "Parintins", next_page_to_load)

func _on_load_more_pressed() -> void:
	if next_page_to_load > 0 and not current_query.is_empty():
		_do_search(current_query, true)

func _on_search_completed(items: Array, has_more: bool = false, next_page: int = 0) -> void:
	btn_search.disabled = false
	has_more_pages = has_more
	next_page_to_load = next_page
	
	if is_loading_more:
		var existing_ids: Dictionary = {}
		for existing in all_current_results:
			existing_ids[existing.get("id", "")] = true
		
		for it in items:
			if not existing_ids.has(it.get("id", "")):
				all_current_results.append(it)
		
		all_current_results.sort_custom(func(a, b): return float(a.get("preco", 0)) < float(b.get("preco", 0)))
		is_loading_more = false
	else:
		all_current_results = items
	
	if all_current_results.is_empty():
		lbl_status.text = "Nenhum produto encontrado em Parintins para este termo."
		empty_search_panel.visible = true
		btn_load_more.visible = false
		_clear_results_grid()
		return
	
	lbl_status.text = "Encontrados %d preços registrados em Parintins - AM." % all_current_results.size()
	empty_search_panel.visible = false
	
	if has_more_pages and next_page_to_load > 0:
		btn_load_more.visible = true
		btn_load_more.disabled = false
		btn_load_more.text = "🔄 Carregar Mais Preços da SEFAZ (Página %d+)" % next_page_to_load
	else:
		btn_load_more.visible = false
	
	# Registra estabelecimentos descobertos
	for item in all_current_results:
		var store = item.get("estabelecimento", "")
		var bairro = item.get("bairro", "")
		var endereco = item.get("endereco", "")
		if not store.is_empty() and not known_stores.has(store):
			known_stores[store] = { "nome": store, "bairro": bairro, "endereco": endereco }
	
	_render_markets_tab()
	_filter_and_render_results()

func _on_search_error(msg: String) -> void:
	btn_search.disabled = false
	btn_load_more.disabled = false
	if is_loading_more:
		btn_load_more.text = "🔄 Tentar Carregar Novamente"
		is_loading_more = false
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
	var total_items = 0
	for it in Global.cart_items:
		total_items += int(it.get("quantidade", 1))
	
	var cart_total = Global.get_cart_total()
	cart_badge_btn.text = "🛒 Carrinho (%d itens • %s)" % [total_items, Global.format_currency(cart_total)]
	
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
	
	for i in range(Global.cart_items.size()):
		var item_ui = cart_item_scene.instantiate()
		cart_items_container.add_child(item_ui)
		item_ui.setup(i, Global.cart_items[i])
	
	_calculate_store_comparisons()

func _calculate_store_comparisons() -> void:
	_clear_store_comparisons()
	
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
	
	var stores_arr = []
	for s_name in store_totals.keys():
		stores_arr.append({
			"nome": s_name,
			"total": store_totals[s_name]["total"],
			"count": store_totals[s_name]["count"],
			"bairro": store_totals[s_name]["bairro"]
		})
	
	stores_arr.sort_custom(func(a, b): return a["total"] < b["total"])
	
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
	
	# Lista comparativa completa com acabamento AAA
	for i in range(stores_arr.size()):
		var s = stores_arr[i]
		var row = PanelContainer.new()
		row.custom_minimum_size = Vector2(0, 48)
		
		var row_style = StyleBoxFlat.new()
		row_style.bg_color = Color(0.96, 0.975, 0.99, 1)
		row_style.border_width_left = 1
		row_style.border_width_top = 1
		row_style.border_width_right = 1
		row_style.border_width_bottom = 2
		row_style.border_color = Color(0.86, 0.9, 0.95, 1)
		row_style.set_corner_radius_all(12)
		row_style.content_margin_left = 14
		row_style.content_margin_top = 10
		row_style.content_margin_right = 14
		row_style.content_margin_bottom = 10
		
		if i == 0:
			row_style.bg_color = Color(0.92, 0.98, 0.94, 1)
			row_style.border_color = Color(0.5, 0.85, 0.65, 1)
		
		row.add_theme_stylebox_override("panel", row_style)
		
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		
		var rank_lbl = Label.new()
		rank_lbl.text = "#%d" % (i + 1)
		rank_lbl.add_theme_font_size_override("font_size", 13)
		rank_lbl.add_theme_color_override("font_color", Color(0.45, 0.52, 0.62, 1) if i > 0 else Color(0.0, 0.6, 0.4, 1))
		
		var name_lbl = Label.new()
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.text = "%s (%s)" % [s["nome"], s["bairro"]]
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", Color(0.09, 0.14, 0.22, 1))
		
		var price_lbl = Label.new()
		price_lbl.text = Global.format_currency(s["total"])
		price_lbl.add_theme_font_size_override("font_size", 15)
		price_lbl.add_theme_color_override("font_color", Color(0.0, 0.65, 0.45, 1) if i == 0 else Color(0.2, 0.3, 0.45, 1))
		
		hbox.add_child(rank_lbl)
		hbox.add_child(name_lbl)
		hbox.add_child(price_lbl)
		row.add_child(hbox)
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
		empty_lbl.add_theme_color_override("font_color", Color(0.45, 0.52, 0.62, 1))
		markets_list_container.add_child(empty_lbl)
		return
	
	for s_name in known_stores.keys():
		var data = known_stores[s_name]
		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(0, 78)
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 1)
		style.set_corner_radius_all(16)
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 2
		style.border_color = Color(0.86, 0.9, 0.95, 1)
		style.shadow_color = Color(0.08, 0.15, 0.25, 0.06)
		style.shadow_size = 12
		style.shadow_offset = Vector2(0, 3)
		style.content_margin_left = 18
		style.content_margin_top = 14
		style.content_margin_right = 18
		style.content_margin_bottom = 14
		panel.add_theme_stylebox_override("panel", style)
		
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 16)
		
		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_theme_constant_override("separation", 3)
		
		var store_lbl = Label.new()
		store_lbl.text = "🏪 " + s_name
		store_lbl.add_theme_font_size_override("font_size", 16)
		store_lbl.add_theme_color_override("font_color", Color(0.09, 0.14, 0.22, 1))
		
		var addr_lbl = Label.new()
		addr_lbl.text = data.get("endereco", "Parintins - AM")
		addr_lbl.add_theme_font_size_override("font_size", 12)
		addr_lbl.add_theme_color_override("font_color", Color(0.45, 0.52, 0.62, 1))
		
		vbox.add_child(store_lbl)
		vbox.add_child(addr_lbl)
		
		var btn_view = Button.new()
		btn_view.text = "Ver Preços"
		btn_view.custom_minimum_size = Vector2(120, 38)
		btn_view.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0, 0.75, 0.55, 1)
		btn_style.border_width_bottom = 3
		btn_style.border_color = Color(0, 0.58, 0.42, 1)
		btn_style.set_corner_radius_all(12)
		btn_style.content_margin_left = 14
		btn_style.content_margin_right = 14
		
		var btn_hover = btn_style.duplicate()
		btn_hover.bg_color = Color(0.08, 0.82, 0.62, 1)
		
		btn_view.add_theme_stylebox_override("normal", btn_style)
		btn_view.add_theme_stylebox_override("hover", btn_hover)
		btn_view.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		btn_view.add_theme_font_size_override("font_size", 13)
		
		btn_view.pressed.connect(func():
			_switch_tab(0)
			var bairro = data.get("bairro", "")
			for i in range(opt_bairros.item_count):
				if opt_bairros.get_item_text(i).to_upper() == bairro.to_upper():
					opt_bairros.select(i)
					_filter_and_render_results()
					break
		)
		
		hbox.add_child(vbox)
		hbox.add_child(btn_view)
		panel.add_child(hbox)
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
		btn_copy_whatsapp.text = "📲 Copiar Lista Formatada para WhatsApp"
