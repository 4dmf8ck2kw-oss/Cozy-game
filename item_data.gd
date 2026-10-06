class_name ItemData
extends Resource

enum Kind { FURNITURE, DECOR }
enum ZoneShape { RECT, CIRCLE, OVAL, CAPSULE }
enum ShadowShape { AUTO, ELLIPSE, ROUNDED_RECT }

@export var title := ""
@export var texture: Texture2D
@export var sprite_scale := 0.5

@export_group("Тип")
## FURNITURE: двигается только в стройке, висит, краснеет если стоит не там.
## DECOR: двигается и в режиме жизнь, падает.
@export var kind := Kind.FURNITURE
@export var can_sit := false
@export var can_hold := false

@export_group("Зона сиденья")
@export var seat_shape := ZoneShape.RECT
## Центр зоны: x от -0.5 до 0.5 (от центра видимой части предмета), y от 0 (верх) до 1 (низ)
@export var seat_pos := Vector2(0, 0.55)
## Размер в долях ВИДИМОЙ части предмета (прозрачные поля PNG не учитываются)
@export var seat_size := Vector2(0.8, 0.2)

@export_group("Зона столешницы")
@export var hold_shape := ZoneShape.RECT
## Центр зоны: x от -0.5 до 0.5, y от 0 (верх видимого предмета) до 1 (низ)
@export var hold_pos := Vector2(0, 0.3)
## Размер в долях ВИДИМОЙ части предмета
@export var hold_size := Vector2(0.8, 0.4)
## Где останавливается падающий сверху предмет: 0 = верх зоны, 0.5 = середина, 1 = низ.
## При ручном отпускании внутри зоны предмет остаётся там, где его положили.
@export var hold_rest := 0.5

@export_group("Тень")
@export var has_shadow := true
## AUTO: округлый предмет/декор получает овал, широкая корпусная мебель — скруглённый прямоугольник.
@export var shadow_shape := ShadowShape.AUTO
## Vector2.ZERO = мягкая тень рассчитывается от основания предмета, не от его полной высоты.
@export var shadow_size := Vector2.ZERO
## Только художественная поправка, если конкретному ассету она когда-нибудь понадобится.
@export var shadow_offset := Vector2.ZERO
