import veb
import db.pg
import time
import net.websocket

const libs  = veb.RawHtml('<script src="https://unpkg.com/htmx.org@2.0.3" integrity="sha384-0895/pl2MU10Hqc6jd4RvrthNlDiE9U1tWmX7WRESftEDRosgxNsQG/Ze9YMRzHq" crossorigin="anonymous"></script>')

pub struct Context {
    veb.Context
}

pub struct Data{
	id int @[primary; sql: serial]
	aturi string
	historical_html []HtmlInstance @[fkey: 'id']
}

pub struct HtmlInstance{
	id int @[primary; sql: serial]
	create_time time.Time   @[default: 'CURRENT_TIME']
	html string
}

pub struct LabelInstance {
	id int @[primary; sql: serial]
	label Label  @[fkey: 'id']
	add_time time.Time
	data Data @[fkey: 'id']
}

pub struct Label{
	id int @[primary; sql: serial]
	publisher string
	name string
	fqlabel string
}

pub struct App {
	db pg.DB
}


@["/"]
pub fn (app &App) aboutredirect(mut ctx Context, tab string) veb.Result {
	return ctx.redirect("/about")
}

pub fn (app &App) about(mut ctx Context, tab string) veb.Result {
	active := "about"
	return $veb.html()
}

pub fn (app &App) labels(mut ctx Context, tab string) veb.Result {
	active := "labels"
	return $veb.html()
}

pub fn (app &App) labelers(mut ctx Context, tab string) veb.Result {
	active := "labelers"
	mut finished_labelers := veb.RawHtml("")
	labels := sql app.db{
		select from Label
	} or {
		return ctx.server_error(err.str())
	}
	println(labels)
	return $veb.html()
}
fn main(){
	mut db := pg.connect(pg.Config{
        host: 'localhost'
        port: 5432
        user: 'postgres'
        password: 'password'
        dbname: 'yabi'
    })!
	mut app := App{
		db: db
	}
	sql db {
		create table Data
		create table LabelInstance
		create table Label
		create table HtmlInstance
	}!
	label_handle := fn [mut db] (mut c websocket.Client, msg &websocket.Message) !{
		data := msg.payload.bytestr()
		vals := data.split(" ")
		label := vals[0]
		println(data)
		sql db {
			select from Label where id == 1
		}!
		instance := LabelInstance{}
	}
	spawn start_client(label_handle,"ws://127.0.0.1:6969/labels")
	veb.run[App, Context](mut app, 8080)
}

fn start_client(on_msg_fn fn (mut websocket.Client, &websocket.Message)!, address string) {
		for{
			mut labels_client := websocket.new_client(address) or {println(err);continue}
			labels_client.on_message(on_msg_fn)
			labels_client.connect() or {println(err);continue}
			labels_client.listen() or {println(err);continue}
		}
	}