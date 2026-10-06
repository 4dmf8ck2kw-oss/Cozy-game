extends Button

func _ready():
	pressed.connect(_on_pressed)

func _on_pressed():
	GameMode.toggle_mode()
	if GameMode.is_life_mode:
		text = "Режим: Жизнь"
	else:
		text = "Режим: Стройка"
