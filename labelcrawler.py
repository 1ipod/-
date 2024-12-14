import atproto, threading
from atproto_identity.resolver import DidResolver
from websocket_server import WebsocketServer # type: ignore
from atproto import FirehoseSubscribeLabelsClient, firehose_models, models, parse_subscribe_labels_message
from config import *


def crawler(include_mod):
  client = atproto.Client()
  client.login(user,password)
  did = DidResolver()
  if include_mod:
    yield ["moderation.bsky.app","mod.bsky.app"]
  working = ['moderation.bsky.app', "1ipod.bsky.social"]
  seen = ['moderation.bsky.app','handle.invalid',"1ipod.bsky.social"]
  while (len(working) != 0):
    x = working
    working = []
    for i, acc in enumerate(x):
      if i % 100 == 0:
        print(i)
      try:
        for follow in client.get_followers(acc).followers:
          if not(follow.handle in seen):
            seen.append(follow.handle)
            working.append(follow.handle)
            if follow.associated != None:
              if (follow.associated.labeler != None):
                x = list(filter(lambda x: x.id == "#atproto_labeler",did.resolve(follow.did).service))[0].service_endpoint
                x = x.replace("https://","")
                yield [follow.handle,x]
                
        for follow in client.get_follows(acc).follows:
            #if (follow.associated.labeler != None) | (follow.associated.lists != None) | (follow.associated.feedgens != None)
          if not(follow.handle in seen):
            seen.append(follow.handle)
            working.append(follow.handle)
            if follow.associated != None:
              if (follow.associated.labeler != None):
                x = list(filter(lambda x: x.id == "#atproto_labeler",did.resolve(follow.did).service))[0].service_endpoint
                x = x.replace("https://","")
                yield [follow.handle,x]
            #print(follow)
      except Exception as e:
        print(e)
        #print(follow)
  print("BROKEN")

connections = set()

def get_handler(name,s):
  def on_message_handler(message: firehose_models.MessageFrame) -> None:
    labels_message = parse_subscribe_labels_message(message)
    if not isinstance(labels_message, models.ComAtprotoLabelSubscribeLabels.Labels):
      return

    for label in labels_message.labels:
      if label.neg:
        continue
      msg = f'{name}:{label.val} {label.uri}'
      s.send_message_to_all(msg)
      #print(msg)
  return on_message_handler


if __name__ == "__main__":
#  x = FirehoseSubscribeLabelsClient()
  server = WebsocketServer(host='127.0.0.1', port=6969)
  threading.Thread(target=server.run_forever).start()
  g = crawler(True)   
  while True:
    t = next(g)
    uri = "wss://"+t[1]+"/xrpc"
    print(t)
    x = FirehoseSubscribeLabelsClient(base_uri=uri)
    threading.Thread(target=x.start,args=(get_handler(t[0],server),)).start()
    
