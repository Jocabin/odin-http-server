package http

import "core:fmt"
import "core:net"
import "core:os"
import "core:strings"

Method :: enum {
	Get,
	Head,
	Options,
	Trace,
	Delete,
	Put,
	Post,
	Patch,
	Connect,
}

Request :: struct {
	method:     Method,
	res_path:   string,
	user_agent: string,
}

Response :: struct {
	// todo: create a proper struct and use procedure to transform it to string
	data: string,
}

Route :: struct {
	path:     string,
	method:   Method,
	callback: Route_Callback,
}

Server_Context :: struct {}

Server :: struct {
	error:    net.Network_Error,
	socket:   net.Any_Socket,
	endpoint: net.Endpoint,
	ctx:      Server_Context,
	routes:   [dynamic]Route,
}

Route_Callback :: proc(ctx: ^Server_Context) -> Response

parse_http_request :: proc(data: []byte) -> (req: Request) {
	assert(len(string(data)) > 0)

	lines, _ := strings.split_lines(string(data))

	for line in lines {
		words, _ := strings.split(line, " ")

		if strings.starts_with(line, "User-Agent: ") {
			user_agent, _ := strings.replace(line, "User-Agent: ", "", 1)
			req.user_agent = user_agent
		}

		for word in words {
			if word == "GET" do req.method = .Get
			else if strings.starts_with(word, "/") {
				req.res_path = word
			}
		}
	}

	return
}

format_http_response :: proc(res: Response) -> (res_buffer: []byte) {
	return transmute([]u8)res.data
}

create_resource_path :: proc(path: string) -> (res_path: string) {
	if path == "/" do res_path = "/index.html"

	if !strings.ends_with(res_path, ".html") {
		res_path = strings.concatenate({path, ".html"})
	}

	return strings.concatenate({"./static", res_path})
}

// ERRORS
resource_not_found :: proc() -> string {
	html: string
	html_data, ok := os.read_entire_file_from_filename("./static/not_found.html")

	if !ok do html = "Not Found"
	else do html = string(html_data)

	return strings.concatenate({"HTTP/1.1 404 Not Found\r\n\r\n\r\n", html, "\r\n"})
}

check_err :: proc(msg: string, err: net.Network_Error) -> bool {
	if err != nil {
		fmt.println(msg, err)
		return true
	}
	return false
}
