extends Node3D

const TITLE := "Gradjöng Live View"
const MAX_STEP := 0.1

var world := World.new()
var transmission := Transmission.new()
var paused := false
var clock: ReplayClock
var sources: Array[Node] = []
var rig: CameraRig
var view: WorldView
var hud: Hud
var directory: NameDirectory


func _ready() -> void:
	var options := Cli.parse(OS.get_cmdline_user_args())
	if options.error:
		_fail("%s\n%s" % [options.error, Cli.USAGE])
		return
	get_window().title = TITLE
	get_window().size = options.size
	rig = CameraRig.new()
	view = WorldView.new()
	hud = Hud.new(options.banner, options.dect)
	for child in [rig, view, hud]:
		add_child(child)
	if options.file:
		_open_file(options)
	else:
		_listen(WebSource.new(options.url, options.token))
		_listen(MetricsPoll.new(options.url, options.token, options.poll))
		directory = NameDirectory.new(options.url, options.token)
		_listen(directory)


func _process(delta: float) -> void:
	if not paused:
		world.update(minf(delta, MAX_STEP))
	transmission.update(delta)
	rig.follow(world.shake, delta)
	view.draw(world, rig.global_position)
	view.transmit(transmission)
	hud.draw(world, transmission, rig)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	match event.keycode:
		KEY_SPACE:
			paused = not paused
			for source in sources:
				source.set_process(not paused)
		KEY_PLUS, KEY_EQUAL, KEY_KP_ADD:
			if clock:
				clock.shift_speed(1)
		KEY_MINUS, KEY_KP_SUBTRACT:
			if clock:
				clock.shift_speed(-1)
		KEY_F11:
			var fullscreen := get_window().mode == Window.MODE_FULLSCREEN
			get_window().mode = Window.MODE_WINDOWED if fullscreen else Window.MODE_FULLSCREEN
		KEY_Q, KEY_ESCAPE:
			get_tree().quit()


func _open_file(options: Cli) -> void:
	var path := options.file if options.file.is_absolute_path() else OS.get_environment("PWD").path_join(options.file)
	if not FileAccess.file_exists(path):
		_fail("cannot read %s" % path)
		return
	var source := FileSource.new(path, options.speed)
	clock = source.clock
	_listen(source)


func _fail(message: String) -> void:
	printerr(message)
	set_process(false)
	get_tree().quit(2)


func _listen(source: Node) -> void:
	source.event_received.connect(_on_event)
	sources.append(source)
	add_child(source)


func _on_event(event: Dictionary) -> void:
	if directory:
		directory.observe(event)
	for effect in EventParser.parse(event):
		world.apply(effect)
		if effect is Effects.WorkerMessage:
			transmission.receive(effect.size)
