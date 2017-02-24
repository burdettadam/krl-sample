ruleset app_registration_owner {
  meta {
    use module io.picolabs.pico alias wrangler
    shares __testing
  }
  global {
    __testing =
      { "queries": [ { "name": "__testing" } ],
        "events": [ { "domain": "registration", "type": "channel_needed",
                      "attrs": [ "student_id" ] } ] }
    newRegistrationChannel = function(student_id){
      ent:reg_pico => engine:newChannel(
                        { "name": student_id,
                          "type": "anon",
                          "pico_id": ent:reg_pico.id } )
                    | null
    }
  }

  rule registration_channel_needed {
    select when registration channel_needed
    pre {
      student_id = event:attr("student_id")
      anon_channel = newRegistrationChannel(student_id)
    }
    if anon_channel then
      send_directive("registration")
        with eci = anon_channel.id.klog("anon_eci issued:")
  }

  rule initialization {
    select when pico ruleset_added
    pre {
      regPico = ent:reg_pico
      regBase = meta:rulesetURI
      regURL = "app_registration.krl"
    }
    noop()
    always {
      engine:registerRuleset( { "base": regBase, "url": regURL } ).klog("registered ruleset rid:");
      raise pico event "new_child_request"
        attributes { "dname": "Registration Pico",
                     "color": "#7FFFD4" }
    }
  }

  rule new_registration_pico {
    select when pico child_initialized
    pre {
      regPico = event:attr("new_child")
      regRID = "app_registration"
    }
    event:send(
      { "eci": regPico.eci, "eid": "ruleset-install",
        "domain": "pico", "type": "new_ruleset",
        "attrs": { "rid": regRID } } )
    fired {
      ent:reg_pico := regPico
    }
  }
}
