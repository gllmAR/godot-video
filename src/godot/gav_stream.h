//
// Created by phwhitfield on 05.08.25.
//
#pragma once

#include "gav_playback.h"

#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/classes/video_stream.hpp>

class GAVStream : public godot::VideoStream {
	GDCLASS(GAVStream, VideoStream)
	static void _bind_methods();
	
	bool loop = false;

 public:
	godot::Ref<godot::VideoStreamPlayback>  _instantiate_playback() override;
	
	void set_loop(bool p_loop) { loop = p_loop; }
	bool get_loop() const { return loop; }
};
