extends CanvasLayer

signal closed()

@onready var video_player: VideoStreamPlayer = $Backdrop/PanelContainer/Margin/VBox/ContentHBox/VideoBox/VideoFrame/VideoStreamPlayer
@onready var btn_close: Button = $Backdrop/PanelContainer/Margin/VBox/BottomHBox/BtnClose
@onready var btn_close_header: Button = $Backdrop/PanelContainer/Margin/VBox/HeaderHBox/BtnCloseHeader
@onready var backdrop: ColorRect = $Backdrop
@onready var panel_container: PanelContainer = $Backdrop/PanelContainer

var video_stream: VideoStreamTheora

func _ready():
	hide()
	btn_close.pressed.connect(close)
	if btn_close_header:
		btn_close_header.pressed.connect(close)
		
	# Pre-load video stream
	video_stream = VideoStreamTheora.new()
	video_stream.file = "res://assets/about.ogv"
	video_player.stream = video_stream
	video_player.loop = true

func open():
	show()
	if video_player:
		video_player.play()

func close():
	if video_player and video_player.is_playing():
		video_player.stop()
	hide()
	closed.emit()

func _unhandled_input(event: InputEvent):
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		close()
		get_viewport().set_input_as_handled()
