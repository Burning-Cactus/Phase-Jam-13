#+build !wasm32
#+build !wasm64p32

package game

import "base:runtime"
import "core:os"
import "core:path/filepath"

_read_entire_file :: proc(name: string, allocator := context.allocator, loc := #caller_location) -> (data: []byte, success: bool) {
	err: os.Error
	data, err = os.read_entire_file(name, allocator, loc)
	return data, err == nil
}

_write_entire_file :: proc(name: string, data: []byte, truncate := true) -> (err: bool) {
	return os.write_entire_file(name, data, truncate = truncate) == nil
}

_join_file_path :: proc(elems: []string, allocator := context.allocator) -> (path: string, err: runtime.Allocator_Error) {
	return filepath.join(elems, allocator)
}
