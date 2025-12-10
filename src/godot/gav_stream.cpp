//
// Created by phwhitfield on 05.08.25.
//

#include "gav_stream.h"

using namespace godot;

void GAVStream::_bind_methods() {
	ADD_SIGNAL(MethodInfo("finished"));
	ADD_SIGNAL(MethodInfo("first_frame"));
	ClassDB::bind_method(D_METHOD("set_loop", "loop"), &GAVStream::set_loop);
	ClassDB::bind_method(D_METHOD("get_loop"), &GAVStream::get_loop);
	ADD_PROPERTY(PropertyInfo(Variant::BOOL, "loop"), "set_loop", "get_loop");
}
godot::Ref<VideoStreamPlayback> GAVStream::_instantiate_playback() {
	// UtilityFunctions::print("GAVStream::instantiate_playback()");
	auto playback = memnew(GAVPlayback);
	playback->load(get_file());
	playback->set_loop(loop);
	playback->set_stream_ref(this); // Pass stream reference for dynamic loop checking
	playback->callbacks = {
		[&] {
			emit_signal("finished");
		},
		[&] {

		},
		[&] {
			emit_signal("first_frame");
		}
	};
	return playback;
}