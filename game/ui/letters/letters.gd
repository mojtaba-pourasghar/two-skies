## نامه‌ها — سه نامهٔ از پیش نصب‌شده (سند ۰۵)
extends Screen

func build() -> VBoxContainer:
	var box := UIKit.make_root("ui_letters")
	for i in range(1, 4):
		box.add_child(UIKit.make_label(Fa.t("letter_%d_title" % i), 11, UIKit.ACCENT))
		var body := UIKit.make_label(Fa.t("letter_%d_body" % i), 9)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(300, 0)
		box.add_child(body)
		box.add_child(UIKit.make_spacer(4))
	add_back_button(box)
	return box
