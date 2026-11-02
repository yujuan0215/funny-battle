extends SceneTree
## Native-rendered engine monitor capture; never loaded by the normal game.

const CASES := ["res://scenes/start.tscn", "res://scenes/levels.tscn", "res://scenes/spikes.tscn"]
var index := -1
var scene: Node
var started := 0
var previous := 0
var transition := false
var samples: Array[Dictionary] = []
var results: Array[Dictionary] = []


func _initialize() -> void:
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	_next.call_deferred()


func _next() -> void:
	if is_instance_valid(scene):
		scene.free()
	index += 1
	if index >= CASES.size():
		var path := "/tmp/funny-battle-profile.json"
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--profile-report="):
				path = argument.get_slice("=", 1)
		var report := {"window": str(DisplayServer.window_get_size()), "viewport": str(root.get_texture().get_size()), "renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus"), "cases": results}
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "  "))
		file.close()
		print("PROFILE: ", JSON.stringify(report))
		quit()
		return
	scene = load(CASES[index]).instantiate()
	if index == 2:
		scene.progress_path = "/tmp/funny-battle-profiler-progress.json"
	root.add_child(scene)
	current_scene = scene
	if index == 2:
		scene._start_round()
	samples.clear()
	started = Time.get_ticks_usec()
	previous = started
	transition = false


func _process(_delta: float) -> bool:
	if index < 0 or transition:
		return false
	var now := Time.get_ticks_usec()
	var elapsed := (now - started) / 1000000.0
	var frame_ms := (now - previous) / 1000.0
	previous = now
	if elapsed > 2.0:
		samples.append({"frame_ms": frame_ms, "process_monitor_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000, "render_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()), "gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
	if elapsed >= 5.0:
		transition = true
		var stats: Dictionary = {"scene": CASES[index], "frames": samples.size()}
		for key in ["frame_ms", "process_monitor_ms", "render_cpu_ms", "gpu_ms", "draw_calls"]:
			var values: Array[float] = []
			var sum := 0.0
			for sample in samples:
				var value := float(sample[key])
				values.append(value)
				sum += value
			values.sort()
			stats[key + "_mean"] = snappedf(sum / maxf(values.size(), 1), 0.001)
			stats[key + "_p95"] = snappedf(values[int((values.size() - 1) * 0.95)], 0.001)
		stats["fps_mean"] = snappedf(1000 / maxf(stats["frame_ms_mean"], 0.001), 0.1)
		results.append(stats)
		_next.call_deferred()
	return false
