# TypedRemote

TypedRemote is a simple library for declaratively handling remote instances. Similar to libraries like 
[Net](https://sleitnick.github.io/RbxUtil/api/Net/), but with the additional support for type functions. Hooray for verbose parameters / returns!

> ### Info
> This is by no means, an "all-in-one" networking library. It manages remotes, but doesn't do extra work like compression, type validation, and batching.

```lua
-- server

local Event = 
    TypedRemote.newReliableEvent("Event")
    :: TypedRemote.ToServerEvent<(fah: string, foo: boolean) -> ()>

Event.server.OnServerEvent:Connect(function(player: Player, fah: string, foo: boolean)
    -- do something
end)
```
```lua
-- client

-- TypeError: Expected this [3.14] to be 'boolean', but got 'number'
Event.client:FireServer("foo", 3.14) 
```

For more information, read the [docs (https://downrest.github.io/TypedRemote/)](https://downrest.github.io/TypedRemote/).