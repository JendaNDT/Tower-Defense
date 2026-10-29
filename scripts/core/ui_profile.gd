class_name UiProfile
extends RefCounted
## Profil zařízení. „Telefon“ = malá dotyková obrazovka: dostane kompaktní rozložení rozhraní a větší ovládací prvky.
## „Dotyk“ (touch_mode) = poslední vstup byl prst, ne myš: místo najetí myší se stavba a meteor potvrzují tlačítkem.
## URL parametr ?touch=1 vynutí telefon (pro zkoušení na počítači), ?touch=0 ho zakáže.

const PHONE_VIEW: Vector2i = Vector2i(990, 460)   # základní velikost obsahu na telefonu; rozhraní se přizpůsobí poměru stran
const PHONE_MAX_SIDE_CSS: float = 700.0            # kratší strana okna v CSS pixelech, pod kterou jde o telefon

static var phone: bool = false
static var touch_mode: bool = false


static func detect(args: Dictionary) -> void:
	phone = false
	if args.has("touch"):
		phone = str(args["touch"]) == "1"
	elif OS.has_feature("web") and DisplayServer.is_touchscreen_available():
		var side = JavaScriptBridge.eval("Math.min(window.innerWidth, window.innerHeight)", true)
		phone = side != null and float(side) < PHONE_MAX_SIDE_CSS
	touch_mode = phone


## Nastaví velikost obsahu okna: na telefonu menší (tj. větší rozhraní), jinak výchozí z nastavení projektu.
static func apply(window: Window) -> void:
	if phone:
		window.content_scale_size = PHONE_VIEW
