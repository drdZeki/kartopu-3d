extends RefCounted
## Oyuncu ayarları (SPEC §17a): grafik kalitesi, joystick, dil. Telefonda user://kayit.cfg içinde saklanır.
## Hazır kalite seçenekleri ayarları topluca değiştirir; tek bir ayar elle değiştirilirse kalite "ozel" olur.
## "otomatik": oyun akıcı değilse kaliteyi kendisi düşürür (main.gd).

const PATH := "user://kayit.cfg"
const SECTION := "ayarlar"

## Hazır seçenekler. render_scale: 3D çizim çözünürlüğü, forest: dış ormanın ne kadarı çizilir.
const PRESETS := {
	"yuksek": { "shadows": true, "outlines": true, "forest": 1.0, "ground_detail": true,
		"effects": true, "footprints": true, "render_scale": 1.0 },
	"orta": { "shadows": true, "outlines": true, "forest": 0.5, "ground_detail": true,
		"effects": true, "footprints": true, "render_scale": 0.75 },
	"dusuk": { "shadows": false, "outlines": false, "forest": 0.25, "ground_detail": false,
		"effects": false, "footprints": false, "render_scale": 0.6 },
}
const LEVELS := ["dusuk", "orta", "yuksek"]

static var quality: String = "otomatik"   # otomatik / yuksek / orta / dusuk / ozel
static var auto_level: String = "orta"    # otomatik moddaki şu anki seviye
static var values: Dictionary = {}        # PRESETS'teki anahtarlar
static var fps30: bool = false            # pil tasarrufu: 30 FPS sınırı
static var joy: String = "sabit"
static var lang: String = ""              # boş = telefonun dili
static var _loaded: bool = false


static func load_all() -> void:
	if _loaded:
		return
	_loaded = true
	# telefonda orta, bilgisayarda yüksek kaliteden başla
	auto_level = "orta" if OS.has_feature("mobile") else "yuksek"
	values = PRESETS[auto_level].duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	quality = cfg.get_value(SECTION, "quality", quality)
	auto_level = cfg.get_value(SECTION, "auto_level", auto_level)
	for k in values:
		values[k] = cfg.get_value(SECTION, k, values[k])
	fps30 = cfg.get_value(SECTION, "fps30", fps30)
	joy = cfg.get_value(SECTION, "joy", joy)
	lang = cfg.get_value(SECTION, "lang", lang)


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)   # başka bölümler (rekor, para...) silinmesin
	cfg.set_value(SECTION, "quality", quality)
	cfg.set_value(SECTION, "auto_level", auto_level)
	for k in values:
		cfg.set_value(SECTION, k, values[k])
	cfg.set_value(SECTION, "fps30", fps30)
	cfg.set_value(SECTION, "joy", joy)
	cfg.set_value(SECTION, "lang", lang)
	cfg.save(PATH)


static func set_quality(q: String) -> void:
	quality = q
	if q == "otomatik":
		values = PRESETS[auto_level].duplicate()
	elif PRESETS.has(q):
		values = PRESETS[q].duplicate()
	save()


## Tek bir ayar elle değişti: kalite "özel" olur.
static func set_value(key: String, v) -> void:
	values[key] = v
	quality = "ozel"
	save()


## Otomatik modda bir seviye düşür. Düşebildiyse true.
static func step_down() -> bool:
	var i := LEVELS.find(auto_level)
	if quality != "otomatik" or i <= 0:
		return false
	auto_level = LEVELS[i - 1]
	values = PRESETS[auto_level].duplicate()
	save()
	return true


static func get_b(key: String) -> bool:
	return bool(values.get(key, true))


static func get_f(key: String) -> float:
	return float(values.get(key, 1.0))
