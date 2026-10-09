---
sidebar_position: 1
---

# Rationale: The Why

Remote events (and sometimes functions) are a crucial piece of Roblox game architecture. However, managing remote event instances adds extra considerations:
* "Where do I put these remote instances?"
* "How do I organize these remote instances?"
* "How should different scripts access the same remote instance?"


A common pattern to resolve this is by creating a shared `Event.luau`, with it's most rawest library-agnostic form being:
```lua
local Event = {}

Event.Event1 = Instance.new("RemoteEvent")
Event.Event2 = Instance.new("RemoteEvent")

Event.UnreliableEvent1 = Instance.new("UnreliableRemoteEvent")

return Event
```

This may seem like extra work when one could just use instances, but the merits show themselves as you scale the project:

## No more manual management of remote instances
This means you don't have to manually manage remote instances anymore. Yes, you have now displaced the work from managing remotes in Explorer to defining remotes through code. 

You may already find this convenient to manage (no more worrying about how to organize remotes in Explorer), but in case you don't, it's a "worthy sacrifice" for the further benefits that it brings (keep reading).

## Single access point for remotes
With manual remotes, it's each script's job to both know the remote's path and directly access said remote.
```lua
local Event1 = ReplicatedStorage...
```
If you wanted to merely change where this remote instance would be placed, you'd have to update every single line accessing that remote. With an shared `Event.luau`, all point to that same module, meaning you can just modify the path without having to change lines from scripts.
```lua
-- want to change what Event1 points to? go ahead, no need to change me :3
local Event1 = Event.Event1
```

## Easy onboarding for networking libraries
Shared `Event.luau` modules are standard practice when using networking libraries. 

Why? Because it's a single access point for managing remotes. Most networking libraries (including TypedRemote, wink wink) either support or force typechecking, and you'd just store the type into that single access point.
```lua
export type EventType = (param1: string, param2: boolean) -> ()

-- best experienced in --!strict
Event.Event1 = 
    TypedRemote.newReliableEvent("Event1")
    :: TypedRemote.ToServerEvent<EventType>
```