ruleset io.picolabs.oauth_client {
  meta {
    use module io.picolabs.pico alias wrangler
    shares __testing, whichPage
  }
  global {
    __testing = { "queries": [ { "name": "__testing" },
                               { "name": "whichPage" } ],
                  "events": [ ] }
    authorizationEndpoint = "http://localhost:9001/authorize"
    tokenEndpoint = "http://localhost:9001/token"
    client_id = "oauth-client-1"
    client_secret = "oauth-client-secret-1"
    redirect_uris = ["http://localhost:9000/callback"]
    protectedResource = "http://localhost:9002/resource"
    whichPage = function() {
      ent:page.defaultsTo("index")
    }
    encodeClientCredentials = function(username,password) {
      "b2F1dGgtY2xpZW50LTE6b2F1dGgtY2xpZW50LXNlY3JldC0x"
    }
  }

  rule oauth_authorize {
    select when oauth authorize
    pre {
      state = engine:newChannel(
        { "name": "oauth", "type": "nonce", "pico_id": wrangler:myself().id })
      authorizeUrl = <<#{authorizationEndpoint}?response_type=code&client_id=#{client_id}&state=#{state.id}&redirect_uri=#{redirect_uris[0]}>>
    }
    send_directive("redirect") with url = authorizeUrl.klog("authorizeUrl")
    fired {
      ent:access_token := null;
      ent:state := state
    }
  }

  rule oauth_callback {
    select when oauth callback code re#(.*)# setting(code)
    pre {
      not_used = code.klog("code")
      state = event:attr("state").klog("state")
      stateMatches = ent:state{"id"} == state
    }
    if stateMatches.klog("stateMatches") then 
      http:post(tokenEndpoint) setting(tokRes) with
        headers = {
          "Authorization": "Basic " + encodeClientCredentials(client_id,client_secret) }
        form = {
          "grant_type": "authorization_code",
          "code": code,
          "redirect_uri": redirect_uris[0] }
    fired {
      raise oauth event "access_token" attributes tokRes.klog("tokRes")
    } else {
      log error "State DOES NOT MATCH: expected "+ent:state{"id"}+" got "+state
    } finally {
      engine:removeChannel({
        "pico_id": wrangler:myself().id,
        "eci": state.klog("eci to be removed")
      });
      ent:state := null
    }
  }

  rule oauth_access_token {
    select when oauth access_token status_code re#200#
    pre {
      //status_code = event:attr("status_code").as("String").klog("status_code")
      content = event:attr("content").klog("content").decode()
      access_token = content{"access_token"}.klog("access_token")
      token_type = content{"token_type"}.klog("token_type")
      scope = content{"scope"}.klog("scope")
    }
    send_directive("OK") with access_token = access_token
    fired {
      ent:access_token := access_token;
      ent:token_type := token_type;
      ent:scope := scope
    }
  }

  rule oauth_fetch_resource {
    select when oauth fetch_resource
    pre {
      access_token = ent:access_token
    }
    if access_token then 
      http:post(protectedResource) setting(resource) with
        headers = { "Authorization": "Bearer " + access_token }
    fired {
      raise oauth event "got_resource" attributes resource.klog("resource")
    }
  }

  rule oauth_got_resource {
    select when oauth got_resource status_code re#200#
    pre {
      content = event:attr("content").klog("content").decode()
    }
    send_directive("OK") with content = content
  }
}