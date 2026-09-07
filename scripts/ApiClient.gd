extends Node
class_name ApiClient

# Cliente HTTP para consultar o Busca Preço Parintins

var http_request: HTTPRequest

func _ready() -> void:
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

func search(query: String, dias: String = "168", municipio: String = "Parintins", page: int = 1) -> void:
	if query.strip_edges().is_empty():
		Global.search_error.emit("Digite o nome de um produto para pesquisar.")
		return
	
	var clean_q = query.strip_edges().uri_encode()
	var clean_mun = municipio.strip_edges().uri_encode()
	var url = "%s?q=%s&municipio=%s&dias=%s&page=%d" % [Global.api_base_url, clean_q, clean_mun, dias, page]
	
	# Cancela requisição anterior se ainda estiver em andamento
	if http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		http_request.cancel_request()
	
	var headers: PackedStringArray = PackedStringArray([
		"User-Agent: BuscaPrecoParintins/1.0",
		"Accept: application/json"
	])
	
	var err = http_request.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		Global.search_error.emit("Erro ao iniciar requisição: Código %d" % err)

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		Global.search_error.emit("Erro de conexão (Resultado %d). Verifique sua internet." % result)
		return
	
	if response_code != 200:
		Global.search_error.emit("Falha ao buscar preços na SEFAZ (Código HTTP %d)" % response_code)
		return
	
	var text = body.get_string_from_utf8()
	var json = JSON.new()
	var parse_err = json.parse(text)
	
	if parse_err != OK:
		Global.search_error.emit("Erro ao processar dados da SEFAZ.")
		return
	
	var data = json.data
	if data is Dictionary and data.has("items"):
		var items = data["items"]
		var has_more = bool(data.get("hasMore", false))
		var next_page = int(data.get("nextPage")) if data.get("nextPage") != null else 0
		Global.search_completed.emit(items, has_more, next_page)
	else:
		Global.search_completed.emit([], false, 0)
