import atproto_identity
import atproto_identity.did
import atproto_identity.did.resolver
from websocket_server import WebsocketServer # type: ignore
import inspect

def message_received(client, server, message):
    x = atproto_identity.did.resolver.DidResolver
    
    server.send_message(client, x.resolve(atproto_identity.did.resolver.DidResolver().resolve(message)))

if __name__ == "__main__":
  server = WebsocketServer(host='127.0.0.1', port=6968)
  server.set_fn_message_received(message_received)
  server.run_forever()
    