extends Node

var mod_name: String
var author: String
var description: String

@onready var mod_name_label: Label = %mod_name
@onready var author_label: Label = %author
@onready var description_label: Label = %description

func _ready() -> void:
	print("set up")
	mod_name_label.text = mod_name
	author_label.text = author
	description_label.text = description
