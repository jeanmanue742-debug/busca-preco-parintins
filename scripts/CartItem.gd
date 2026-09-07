extends PanelContainer

var item_index: int = -1
var item_data: Dictionary = {}

@onready var lbl_name: Label = $HBox/Info/Name
@onready var lbl_store: Label = $HBox/Info/Store
@onready var lbl_unit_price: Label = $HBox/Info/UnitPrice
@onready var lbl_qty: Label = $HBox/QtyControls/QtyLabel
@onready var lbl_total: Label = $HBox/Total
@onready var btn_minus: Button = $HBox/QtyControls/BtnMinus
@onready var btn_plus: Button = $HBox/QtyControls/BtnPlus
@onready var btn_remove: Button = $HBox/BtnRemove

func setup(index: int, data: Dictionary) -> void:
	item_index = index
	item_data = data
	
	lbl_name.text = data.get("nome", "Item")
	lbl_store.text = data.get("estabelecimento", "Mercado")
	
	var price = float(data.get("preco", 0.0))
	var qty = int(data.get("quantidade", 1))
	var total = price * qty
	
	lbl_unit_price.text = "%s un." % Global.format_currency(price)
	lbl_qty.text = str(qty)
	lbl_total.text = Global.format_currency(total)
	
	btn_minus.pressed.connect(_on_minus_pressed)
	btn_plus.pressed.connect(_on_plus_pressed)
	btn_remove.pressed.connect(_on_remove_pressed)

func _on_minus_pressed() -> void:
	var current_qty = int(item_data.get("quantidade", 1))
	Global.update_cart_quantity(item_index, current_qty - 1)

func _on_plus_pressed() -> void:
	var current_qty = int(item_data.get("quantidade", 1))
	Global.update_cart_quantity(item_index, current_qty + 1)

func _on_remove_pressed() -> void:
	Global.remove_from_cart(item_index)
