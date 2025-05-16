extends Node

enum Pants {
	JEANS_1
}

enum Shirt {
	RED_TSHIRT,
	GREEN_TSHIRT
}


var worn_pants: Texture2D
var worn_shirt: Texture2D


func get_pants_texture(pants: Pants) -> Texture2D:
	match pants:
		Pants.JEANS_1:
			return load("uid://cfh5pa5rxwjby")
	return


func get_shirt_texture(shirt: Shirt) -> Texture2D:
	match shirt:
		Shirt.RED_TSHIRT:
			return load("uid://dnqp034fknmk1")
		Shirt.GREEN_TSHIRT:
			return load("uid://clobkvbcpe0yw")
	return
