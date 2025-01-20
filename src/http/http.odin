package http

import "core:fmt"
import "core:net"
import "core:os"
import "core:strings"
import "core:unicode/utf8"

create_server :: proc(ip: string, port: int) -> (s: Server) {
	// todo: gérer ipv6
	addr, addr_ok := net.parse_ip4_address(ip)
	if !addr_ok {
		fmt.eprintln("Error parsing address, using IP4_Any")
		addr = net.IP4_Any
	}

	s.endpoint = net.Endpoint {
		address = addr,
		port    = port,
	}

	s.socket, s.error = net.listen_tcp(s.endpoint)
	if check_err("Error listening socket", s.error) do return

	fmt.printfln(
		"Server started on http://%s:%d",
		net.address_to_string(s.endpoint.address),
		s.endpoint.port,
	)

	return
}

start_server :: proc(s: ^Server) {
	for {
		client_sock, _, client_err := net.accept_tcp(s.socket.(net.TCP_Socket))
		if check_err("Error accepting connection", client_err) do break

		// note: you need to receive tcp data before sending back data, or you getting an error (i think it's a tcp thing)
		buffer: [1024]byte
		bytes_read: int

		bytes_read, client_err = net.recv_tcp(client_sock, buffer[:])
		if check_err("Error receiving data", client_err) do break

		response: Response
		request := parse_http_request(buffer[:bytes_read])

		for route in s.routes {
			if route.method == .Get && request.method == .Get {
				res_path := create_resource_path(request.res_path)

				if route.path == request.res_path {
					response = route.callback(&s.ctx)
				}
			}
		}

		_, client_err = net.send_tcp(client_sock, format_http_response(response))
		if check_err("Error sending data", client_err) do break

		net.close(client_sock)
	}

	fmt.println("Stopping server")
}

create_route :: proc(server: ^Server, method: Method, path: string, callback: Route_Callback) {
	for route in server.routes {
		if route.path == path && route.method == method {
			fmt.eprintln("This route already exist")
			os.exit(1)
		}
	}

	route := Route {
		path     = path,
		method   = method,
		callback = callback,
	}

	append(&server.routes, route)
}

respond_file :: proc(ctx: ^Server_Context, path: string) -> Response {
	data, ok := os.read_entire_file_from_filename(strings.concatenate({"./static/", path}))
	res: string

	if !ok {
		fmt.println("Can't find resource: ", os.get_current_directory(), "/static/", path)
		res = resource_not_found()
	} else {
		res = strings.concatenate({res, "HTTP/1.1 200 OK\r\n\r\n\r\n", string(data), "\r\n"})
	}

	return Response{data = res}
}

respond_text :: proc(ctx: ^Server_Context, txt: string) -> Response {
	res := "HTTP/1.1 200 OK\r\n\r\n\r\n"
	res = strings.concatenate({res, txt, "\r\n"})

	return Response{data = res}
}
