extends PanelContainer

# Dados do produto exibido no card
var product_data: Dictionary = {}

@onready var lbl_price: Label = $Margin/VBox/Header/Price
@onready var lbl_badge: Label = $Margin/VBox/Header/Badge
@onready var lbl_title: Label = $Margin/VBox/Title
@onready var lbl_store: Label = $Margin/VBox/StoreInfo/Store
@onready var lbl_bairro: Label = $Margin/VBox/StoreInfo/Bairro
@onready var lbl_time: Label = $Margin/VBox/Footer/Time
@onready var btn_add: Button = $Margin/VBox/Footer/BtnAdd

func setup(data: Dictionary, is_cheapest: bool = false) -> void:
	product_data = data
	
	lbl_price.text = data.get("precoFormatado", "R$ 0,00")
	lbl_title.text = data.get("nome", "Produto sem nome")
	lbl_store.text = data.get("estabelecimento", "Mercado")
	
	var bairro = data.get("bairro", "")
	if bairro.is_empty() or bairro == "Parintins":
		lbl_bairro.text = "Parintins - AM"
	else:
		lbl_bairro.text = "Bairro: " + bairro
	
	lbl_time.text = data.get("tempo", "")
	lbl_badge.visible = is_cheapest
	
	btn_add.pressed.connect(_on_btn_add_pressed)

func _on_btn_add_pressed() -> void:
	Global.add_to_cart(product_data, 1)
	btn_add.text = "✓ Adicionado!"
	btn_add.disabled = true
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(btn_add):
		btn_add.text = "+ Adicionar à Lista"
		btn_add.disabled = false
