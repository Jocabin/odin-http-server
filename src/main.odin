package ohttp

import "core:fmt"
import "core:mem"
import "core:net"
import "core:unicode/utf8"

main :: proc() {
	// track for memory leaks
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			if len(track.bad_free_array) > 0 {
				fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
				for entry in track.bad_free_array {
					fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	err: net.Network_Error
	socket: net.Any_Socket
	endpoint := net.Endpoint {
		address = net.IP4_Any,
		port    = 1234,
	}

	socket, err = net.listen_tcp(endpoint, 5)
	if check_err("Error listening socket", err) do return
	fmt.printfln("Server started on %s:%d", net.address_to_string(endpoint.address), endpoint.port)

	for {
		client_sock, _, client_err := net.accept_tcp(socket.(net.TCP_Socket))
		if check_err("Error accepting connection", client_err) do break
		fmt.println("Client connected")

		buffer: [1024]byte
		bytes_read: int

		bytes_read, client_err = net.recv_tcp(client_sock, buffer[:])
		if check_err("Error receiving data", client_err) do break
		fmt.println("received:", string(buffer[:bytes_read]))

		res_buf := "HTTP/1.1 200 OK\r\n\r\n\r\n<h1>Hello, World</h1>\r\n"

		_, client_err = net.send_tcp(client_sock, transmute([]u8)res_buf[:])
		if check_err("Error sending data", client_err) do break
		fmt.println("Data sent:", res_buf)

		net.close(client_sock)
		fmt.println("Client disconnected")
	}

	fmt.println("Closing the server")
}

check_err :: proc(msg: string, err: net.Network_Error) -> bool {
	if err != nil {
		fmt.println(msg, err)
		return true
	}
	return false
}
