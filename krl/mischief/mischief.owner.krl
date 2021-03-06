ruleset mischief.owner {
  meta {
    name "mischief owner"
    description <<
      A bit of whimsy,
      inspired by Dr. Seuss's
      "The Cat in the Hat"
    >>
    author "Picolabs"
    use module io.picolabs.pico alias wrangler
    shares __testing
  }
  global {
    __testing = { "queries": [ { "name": "__testing" } ],
                  "events": [ { "domain": "mischief", "type": "subscriptions"} ] }
  }
  rule mischief_who {
    select when mischief who
    pre {
      mischief = event:attr("eci")
      things = wrangler:children().map(function(v){v.eci})
                                  .filter(function(v){v != mischief})
    }
    always {
      ent:mischief := mischief;
      ent:things := things
    }
  }
  rule mischief_subscriptions {
    select when mischief subscriptions
    pre {
      mischief = ent:mischief
      thing1 = ent:things[0]
      thing2 = ent:things[1]
    }
    if mischief && thing1 && thing2 then every {
      event:send(
        { "eci": mischief, "eid": "subscription",
          "domain": "wrangler", "type": "subscription",
          "attrs": { "name": "thing1",
                     "name_space": "mischief",
                     "my_role": "controller",
                     "subscriber_role": "thing",
                     "channel_type": "subscription",
                     "subscriber_eci": thing1 } } )
      event:send(
        { "eci": mischief, "eid": "subscription",
          "domain": "wrangler", "type": "subscription",
          "attrs": { "name": "thing2",
                     "name_space": "mischief",
                     "my_role": "controller",
                     "subscriber_role": "thing",
                     "channel_type": "subscription",
                     "subscriber_eci": thing2 } } )
    }
  }
}
