module main

import veb
import time
import net.http
import net.websocket
import json

const libs  = veb.RawHtml('<script src="https://unpkg.com/htmx.org@2.0.3" integrity="sha384-0895/pl2MU10Hqc6jd4RvrthNlDiE9U1tWmX7WRESftEDRosgxNsQG/Ze9YMRzHq" crossorigin="anonymous"></script>\n<script src="https://unpkg.com/htmx-ext-ws@2.0.1/ws.js"></script>')

pub struct Context {
    veb.Context
}
/*
pub struct Post{
	aturi string
	ts time.Time
	labels []&LabelClass
}

pub struct Labeler{
	did string
shared:
	labels map[string]LabelClass
}

pub struct LabelClass{
	name string
	last_ten []&Post
	parent &Labeler
}
*/
pub struct App {
mut:
	posts map[string]string
	labels map[string][]string
	updates map[string]time.Time
}

pub fn at_to_html(uri string, fqlabel string)string{
	embed := http.get_text("https://embed.bsky.app/oembed?url=${uri}")
	if embed.contains("not publicly accessible"){
		return "${uri}:${fqlabel}" //TODO: make link, im tired.
	}
	mut post := json.decode(map[string]string,embed) or {/*println("${err} ${embed} ${values[1]} err1");*/ map[string]string}
	if post == map[string]string{}{
		link := if uri.contains("at://") {"https://bsky.app/profile/" + uri.split("/")[2]} else {"https://bsky.app/profile/" + uri}
		post["html"] = "<a href=\"${link}\">${fqlabel}</a>"
	} else {
		post["html"] = "${fqlabel}<br>${post["html"]}" 
	}
	return post["html"]
}

@["/api/start"]
pub fn (app &App) start(mut ctx Context) veb.Result {
	mut accept := ""
	e := ""
	c := false
	println(ctx.query)
	match ctx.query["ra"]{
		"filter" {accept = app.posts.keys().filter(!(it in ctx.query["accounts"].split("\n"))&&!(it.split(":")[0] in ctx.query["accounts"].split("\n"))).join(",")}
		"accept" {accept = app.posts.keys().filter((it in ctx.query["accounts"].split("\n"))||(it.split(":")[0] in ctx.query["accounts"].split("\n"))).join(",")}
		else {}
	}
	posts := {"":""}
	println(accept)
	return ctx.text('<div hx-get="/api/label?accept=$accept&state=0&current=$e"hx-trigger="load delay:1s"hx-swap="outerHTML"></div>${if c {"<div>"+posts[e]+"</div>"} else {""}}')
}

@["/api/label"]
pub fn (app &App) label(mut ctx Context) veb.Result {
	mut s := time.unix(ctx.query["state"].i64())
	mut x := time.now()
	mut e := ctx.query["current"]
	mut updates := app.updates.clone()
	mut posts := app.posts.clone()
	println(updates)
	println(ctx.query)
	accept := ctx.query["accept"]
	mut c := false
	for l in ctx.query["accept"].split(","){
		t := updates[l]
		//println(s)
		//println(updates[l])
		if t.unix() < x.unix() && s.unix() < t.unix(){
			println("s < t < x")
			println(s)
			println(t)
			println(x)
			c = true
			x = t
			e = l
		}
	}
	if c{
		ctx.set_custom_header("HX-Reswap","beforebegin") or {panic("jank")}
		s = x
	}
	return ctx.text('<div hx-get="/api/label?accept=$accept&state=${s.unix()}&current=$e"hx-trigger="load delay:1s"hx-swap="outerHTML"></div>${if c {"<div>"+posts[e]+"</div>"} else {""}}')
}

@["/:tab"]
pub fn (app &App) index(mut ctx Context, tab string) veb.Result {
	mut include := tab
	if !(tab.replace(".html","") in ["labels","about"]){
		include = "error"
	}
	labelsactive := if include == "labels" {"active"} else {""}
	aboutactive := if include == "about" {"active"} else {""}
    return $veb.html()
}
const app_port = 8080
fn main() {
	shared posts := map[string]string{}
	shared labels := map[string][]string{}
	shared updates := map[string]time.Time{}
	mut z := map[string]string{}
	mut y := map[string][]string{}
	mut j := map[string]time.Time{}
	rlock posts, labels{
		z = posts
		y = labels
	}
    mut app := &App{
		posts: &z
		labels: &y
		updates: &j
	}
	x:= fn [shared posts, shared labels, shared updates] (mut c websocket.Client, msg &websocket.Message)!{
		data := msg.payload.bytestr()
		vals := data.split(" ")
		label := vals[0].split(":")
		//println(data)
		name := label[0]
		html :=at_to_html(vals[1], vals[0])
		//println("waiting for lock")
		lock labels, posts, updates{
			posts[vals[0]] = html
			if !(label[1] in labels[name]){
				labels[name].prepend(name)
			}
			updates[vals[0]] = time.now()
		}
		//println("done with lock")
	}
	spawn fn [x] () {
		for{
			mut labels_client := websocket.new_client("ws://127.0.0.1:6969/labels") or {println(err);continue}
			labels_client.on_message(x)
			labels_client.connect() or {println(err);continue}
			labels_client.listen() or {println(err);continue}
		}
	}()
    // Pass the App and context type and start the web server on port 8080
    spawn veb.run[App, Context](mut app, app_port)
	for {
		rlock posts, labels, updates {
			app.posts = posts.clone()
			app.labels = labels.clone()
			app.updates = updates.clone()
		}
		time.sleep(50000000)
	}
}
