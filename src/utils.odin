// Wraps os.read_entire_file and os.write_entire_file, but they also work with emscripten.

package game

import "base:runtime"

@(require_results)
read_entire_file :: proc(name: string, allocator := context.allocator, loc := #caller_location) -> (data: []byte, success: bool) {
	return _read_entire_file(name, allocator, loc)
}

write_entire_file :: proc(name: string, data: []byte, truncate := true) -> (success: bool) {
	return _write_entire_file(name, data, truncate)
}

join_file_path :: proc(elems: []string, allocator := context.allocator) -> (path: string, err: runtime.Allocator_Error) {
	return _join_file_path(elems, allocator)
}
