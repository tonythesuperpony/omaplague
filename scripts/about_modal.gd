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
	AudioManager.play_about_music()

func close():
	if video_player and video_player.is_playing():
		video_player.stop()
	AudioManager.stop_about_music()
	hide()
	closed.emit()

func _input(event: InputEvent):
	if not visible:
		return
	# Swallow ALL mouse events (including scroll wheel) so they don't zoom the map behind
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.is_action_pressed("ui_cancel"):
			close()
			get_viewport().set_input_as_handled()
