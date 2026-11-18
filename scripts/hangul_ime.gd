class_name HangulIME
extends RefCounted

# 2-Beolsik Key -> Jamo mapping
const CONSONANT_MAP: Dictionary = {
	"r": "ㄱ", "R": "ㄲ", "s": "ㄴ", "e": "ㄷ", "E": "ㄸ",
	"f": "ㄹ", "a": "ㅁ", "q": "ㅂ", "Q": "ㅃ", "t": "ㅅ",
	"T": "ㅆ", "d": "ㅇ", "w": "ㅈ", "W": "ㅉ", "c": "ㅊ",
	"z": "ㅋ", "x": "ㅌ", "v": "ㅍ", "g": "ㅎ"
}

const VOWEL_MAP: Dictionary = {
	"k": "ㅏ", "o": "ㅐ", "i": "ㅑ", "O": "ㅒ", "j": "ㅓ",
	"p": "ㅔ", "u": "ㅕ", "P": "ㅖ", "h": "ㅗ", "y": "ㅛ",
	"n": "ㅜ", "b": "ㅠ", "m": "ㅡ", "l": "ㅣ"
}

const CHOSEONG: Array = ["ㄱ","ㄲ","ㄴ","ㄷ","ㄸ","ㄹ","ㅁ","ㅂ","ㅃ","ㅅ","ㅆ","ㅇ","ㅈ","ㅉ","ㅊ","ㅋ","ㅌ","ㅍ","ㅎ"]
const JUNGSEONG: Array = ["ㅏ","ㅐ","ㅑ","ㅒ","ㅓ","ㅔ","ㅕ","ㅖ","ㅗ","ㅘ","ㅙ","ㅚ","ㅛ","ㅜ","ㅝ","ㅞ","ㅟ","ㅠ","ㅡ","ㅢ","ㅣ"]
const JONGSEONG: Array = ["","ㄱ","ㄲ","ㄳ","ㄴ","ㄵ","ㄶ","ㄷ","ㄹ","ㄺ","ㄻ","ㄼ","ㄽ","ㄾ","ㄿ","ㅀ","ㅁ","ㅂ","ㅄ","ㅅ","ㅆ","ㅇ","ㅈ","ㅊ","ㅋ","ㅌ","ㅍ","ㅎ"]

const COMPOUND_VOWELS: Dictionary = {
	"ㅗㅏ": "ㅘ", "ㅗㅐ": "ㅙ", "ㅗㅣ": "ㅚ",
	"ㅜㅓ": "ㅝ", "ㅜㅔ": "ㅞ", "ㅜㅣ": "ㅟ",
	"ㅡㅣ": "ㅢ"
}

const SPLIT_VOWELS: Dictionary = {
	"ㅘ": ["ㅗ", "ㅏ"], "ㅙ": ["ㅗ", "ㅐ"], "ㅚ": ["ㅗ", "ㅣ"],
	"ㅝ": ["ㅜ", "ㅓ"], "ㅞ": ["ㅜ", "ㅔ"], "ㅟ": ["ㅜ", "ㅣ"],
	"ㅢ": ["ㅡ", "ㅣ"]
}

const COMPOUND_JONGS: Dictionary = {
	"ㄱㅅ": "ㄳ", "ㄴㅈ": "ㄵ", "ㄴㅎ": "ㄶ",
	"ㄹㄱ": "ㄺ", "ㄹㅁ": "ㄻ", "ㄹㅂ": "ㄼ", "ㄹㅅ": "ㄽ", "ㄹㅌ": "ㄾ", "ㄹㅍ": "ㄿ", "ㄹㅎ": "ㅀ",
	"ㅂㅅ": "ㅄ"
}

const SPLIT_JONGS: Dictionary = {
	"ㄳ": ["ㄱ", "ㅅ"], "ㄵ": ["ㄴ", "ㅈ"], "ㄶ": ["ㄴ", "ㅎ"],
	"ㄺ": ["ㄹ", "ㄱ"], "ㄻ": ["ㄹ", "ㅁ"], "ㄼ": ["ㄹ", "ㅂ"], "ㄽ": ["ㄹ", "ㅅ"],
	"ㄾ": ["ㄹ", "ㅌ"], "ㄿ": ["ㄹ", "ㅍ"], "ㅀ": ["ㄹ", "ㅎ"], "ㅄ": ["ㅂ", "ㅅ"]
}

var committed: String = ""
var cho: String = ""
var jung: String = ""
var jong: String = ""

func reset():
	committed = ""
	cho = ""
	jung = ""
	jong = ""

func flush():
	if cho != "" or jung != "":
		committed += _compose_current()
		cho = ""
		jung = ""
		jong = ""

func get_full_text() -> String:
	return committed + _compose_current()

func _compose_current() -> String:
	if cho == "" and jung == "":
		return ""
	if cho != "" and jung == "":
		return cho
	if cho == "" and jung != "":
		return jung
	var ci = CHOSEONG.find(cho)
	var ji = JUNGSEONG.find(jung)
	var ki = JONGSEONG.find(jong)
	if ci < 0 or ji < 0 or ki < 0:
		return cho + jung + jong
	return char(0xAC00 + (ci * 21 + ji) * 28 + ki)

func feed_key(ch: String) -> String:
	if CONSONANT_MAP.has(ch):
		_push_consonant(CONSONANT_MAP[ch])
	elif VOWEL_MAP.has(ch):
		_push_vowel(VOWEL_MAP[ch])
	else:
		flush()
		committed += ch
	return get_full_text()

func backspace() -> String:
	if jong != "":
		if SPLIT_JONGS.has(jong):
			jong = SPLIT_JONGS[jong][0]
		else:
			jong = ""
	elif jung != "":
		if SPLIT_VOWELS.has(jung):
			jung = SPLIT_VOWELS[jung][0]
		else:
			jung = ""
	elif cho != "":
		cho = ""
	elif committed.length() > 0:
		committed = committed.substr(0, committed.length() - 1)
	return get_full_text()

func _push_consonant(c: String):
	if cho == "" and jung == "":
		cho = c
	elif cho != "" and jung == "":
		flush()
		cho = c
	elif cho == "" and jung != "":
		flush()
		cho = c
	elif jong == "":
		if JONGSEONG.has(c):
			jong = c
		else:
			flush()
			cho = c
	else:
		var comb = jong + c
		if COMPOUND_JONGS.has(comb):
			jong = COMPOUND_JONGS[comb]
		else:
			flush()
			cho = c

func _push_vowel(v: String):
	if cho == "" and jung == "":
		jung = v
	elif cho != "" and jung == "":
		jung = v
	elif jong == "":
		var comb = jung + v
		if COMPOUND_VOWELS.has(comb):
			jung = COMPOUND_VOWELS[comb]
		else:
			flush()
			jung = v
	else:
		# Split jongseong into previous syllable + new choseong!
		if SPLIT_JONGS.has(jong):
			var parts = SPLIT_JONGS[jong]
			jong = parts[0]
			flush()
			cho = parts[1]
			jung = v
		else:
			var next_cho = jong
			jong = ""
			flush()
			cho = next_cho
			jung = v
