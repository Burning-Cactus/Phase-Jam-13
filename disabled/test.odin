package test

import "core:fmt"
import "core:encoding/json"
import "core:os"
import "core:strings"

import game "../src"


main :: proc() {
	game.register_entities()
	defer game.unregister_entities()
	for type in game.Entity_Type {
		info := game.entity_definitions[type]
		bytes, json_err := json.marshal(info)
		defer delete(bytes)

		json_data := string(bytes)
		fmt.println(json_data)

		file_path := fmt.tprintf("../assets/data/entities/%s.json", info.name)
		file_handle, file_err := os.open(file_path, {.Create, .Write})
		if file_err == nil {
			defer os.close(file_handle)
			fmt.fprint(file_handle, json_data)
		} else {
			fmt.eprintln("Error: ", file_err)
		}
	}

	game.create_tile_map(&game.tile_map)
	defer game.unload_tile_map(game.tile_map)

	{
		bytes, json_err := json.marshal(game.tile_map.tile_set)
		defer delete(bytes)

		json_data := string(bytes)
		fmt.println(json_data)
		file_path := fmt.tprintf("../assets/data/tile_sets/%s.json", "warehouse")
		file_handle, file_err := os.open(file_path, {.Create, .Write})
		if file_err == nil {
			defer os.close(file_handle)
			fmt.fprint(file_handle, json_data)
		} else {
			fmt.eprintln("Error: ", file_err)
		}
	}

	free_all(context.temp_allocator)
}
