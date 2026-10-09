--[=[
	@class TypedRemote

	A typed wrapper for `RemoteEvent` and `RemoteFunction` instances, taking advantage of function types `() -> ()` 
	for typechecking on firing, listening, and invoking.
]=]

local RunService = game:GetService("RunService")

local Types = require(script.Types)

local TypedRemote = {}

export type Event<
	toClientSignature = Types.DefaultSignature,
	toServerSignature = Types.DefaultSignature
> = Types.Event<toClientSignature, toServerSignature>

export type ToClientEvent<signature = Types.DefaultSignature> = Types.ToClientEvent<signature>
export type ToServerEvent<signature = Types.DefaultSignature> = Types.ToServerEvent<signature>

export type Function<
	fromClientSignature = Types.DefaultSignature,
	fromServerSignature = Types.DefaultSignature
> = Types.Function<fromClientSignature, fromServerSignature>

export type FromClientFunction<signature = Types.DefaultSignature> = Types.FromClientFunction<signature>
export type FromServerFunction<signature = Types.DefaultSignature> = Types.FromServerFunction<signature>

local IS_SERVER = RunService:IsServer()

local function assertClient()
	assert(RunService:IsClient(), "Attempted to run client-only function!")
end

local function assertServer()
	assert(RunService:IsServer(), "Attempted to run server-only function!")
end

local function getReliableEvent(name: string): RemoteEvent
	local event = script:FindFirstChild(name)
	if not event then -- allowing client/server boundary to access the same instance
		event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = script
	end

	return (event:: RemoteEvent)
end

local function getUnreliableEvent(name: string): UnreliableRemoteEvent
	local event = script:FindFirstChild(name)
	if not event then -- allowing client/server boundary to access the same instance
		event = Instance.new("UnreliableRemoteEvent")
		event.Name = name
		event.Parent = script
	end

	return (event:: UnreliableRemoteEvent)
end

local function getFunction(name: string): RemoteFunction
	local func = script:FindFirstChild(name)
	if not func then
		func = Instance.new("RemoteFunction")
		func.Name = name
		func.Parent = script
	end

	return (func:: RemoteFunction)
end

local function wrapEvent<
	toClientSignature,
	toServerSignature
>(
	remoteEvent: any -- typechecker gets angry w/ methods from (RemoteEvent | UnreliableRemoteEvent) union
): Event<toClientSignature, toServerSignature>
	local self = {
		client = {
			OnClientEvent = {};
		};
		server = {
			OnServerEvent = {};
		};
	}:: Event<toClientSignature, toServerSignature>

	if IS_SERVER then
		-- server

		function self.server.FireClient(self: Types.ServerFire, player: Player, ...)
			assertServer()

			remoteEvent:FireClient(player, ...)
		end
		function self.server.FireAllClients(self: Types.ServerListener, ...)
			assertServer()

			remoteEvent:FireAllClients(...)
		end

		function self.server.OnServerEvent.Connect(self: Event, callback)
			assertServer()

			return remoteEvent.OnServerEvent:Connect(callback)
		end
		function self.server.OnServerEvent.ConnectParallel(self: Event, callback)
			assertServer()

			return remoteEvent.OnServerEvent:ConnectParallel(callback)
		end
		function self.server.OnServerEvent.Once(self: Event, callback)
			assertServer()

			return remoteEvent.OnServerEvent:Once(callback)
		end
	else
		-- client
		
		function self.client.FireServer(self: Types.ClientFire, ...)
			assertClient()

			remoteEvent:FireServer(...)
		end

		function self.client.OnClientEvent.Connect(self: Types.ClientListener, callback)
			assertClient()

			return remoteEvent.OnClientEvent:Connect(callback)
		end
		function self.client.OnClientEvent.ConnectParallel(self: Types.ClientListener, callback)
			assertClient()

			return remoteEvent.OnClientEvent:ConnectParallel(callback)
		end
		function self.client.OnClientEvent.Once(self: Types.ClientListener, callback)
			assertClient()

			return remoteEvent.OnClientEvent:Once(callback)
		end
	end

	return self
end

local function wrapFunction<
	fromClientSignature,
	fromServerSignature
>(
	remoteFunction: RemoteFunction
): Function<fromClientSignature, fromServerSignature>

	local internal = {
		client = {};
		server = {};
	}
	local self = {
		client = {};
		server = {};
	}:: Function<fromClientSignature, fromServerSignature>

	if IS_SERVER then
		-- server

		setmetatable(self.server, {
			__index = function(table, key)
				return internal.server[key]
			end;
			__newindex = function(table, key, value)
				if key ~= "OnServerInvoke" then
					return
				end
				assertServer()

				internal.server[key] = value
				remoteFunction.OnServerInvoke = value
			end;
		});

		do
			function internal.server.InvokeClient(self, player, ...)
				assertServer()
	
				return remoteFunction:InvokeClient(player, ...)
			end
		end
	else
		-- client

		setmetatable(self.client, {
			__index = function(table, key)
				return internal.client[key]
			end;
			__newindex = function(table, key, value)
				if key ~= "OnClientInvoke" then
					return
				end
				assertClient()

				internal.client[key] = value
				remoteFunction.OnClientInvoke = value
			end;
		})

		do
			function internal.client.InvokeServer(self, ...)
				assertClient()
	
				return remoteFunction:InvokeServer(...)
			end
		end
	end

	return self
end

--[[
    RELIABLE REMOTE EVENTS
]]

--[=[
	Creates an Event (reliable) object, automatically creating a RemoteEvent instance named  `remoteName`.

	```lua
	-- server

	local ReliableEvent = 
		TypedRemote.newReliableEvent("ReliableEvent")
		:: TypedRemote.ToServerEvent<(text: string) -> ()>

	ReliableEvent.server.OnServerEvent:Connect(function(player: Player, text: string)
		foo(text)
	end)
	```
	```lua
	-- client

	ReliableEvent.client:FireServer("foo")
	```

	@within TypedRemote
	@param remoteName string -- Name for Event (reliable)
	@return Event<toClientSignature, toServerSignature> -- Event (reliable) object
]=]
function TypedRemote.newReliableEvent<
	toClientSignature,
	toServerSignature
>(
	remoteName: string
): Event<toClientSignature, toServerSignature>

	return wrapEvent<<toClientSignature, toServerSignature>>(
		getReliableEvent(remoteName)
	)
end

--[=[
	Creates an Event (reliable) object, using a passed RemoteEvent instance, `remoteEvent`.

	```lua
	-- server

	local ReliableEvent = 
		TypedRemote.wrapReliableEvent(Instance.new("RemoteEvent"))
		:: TypedRemote.ToServerEvent<(text: string) -> ()>

	ReliableEvent.server.OnServerEvent:Connect(function(player: Player, text: string)
		foo(text)
	end)
	```
	```lua
	-- client

	ReliableEvent.client:FireServer("foo")
	```

	@within TypedRemote
	@param remoteEvent RemoteEvent -- RemoteEvent instance for Event (reliable) object
	@return Event<toClientSignature, toServerSignature> -- Event (reliable) object
]=]
function TypedRemote.wrapReliableEvent<
	toClientSignature,
	toServerSignature
>(
	remoteEvent: RemoteEvent
): Event<toClientSignature, toServerSignature>

	return wrapEvent<<toClientSignature, toServerSignature>>(
		remoteEvent
	)
end

--[[
    UNRELIABLE REMOTE EVENTS
]]

--[=[
	Creates an Event (unreliable) object, automatically creating an UnreliableRemoteEvent instance named  `unreliableRemoteName`.

	```lua
	-- server

	local UnreliableEvent = 
		TypedRemote.newUnreliableEvent("UnreliableEvent")
		:: TypedRemote.ToServerEvent<(text: string) -> ()>

	UnreliableEvent.server.OnServerEvent:Connect(function(player: Player, text: string)
		foo(text)
	end)
	```
	```lua
	-- client

	UnreliableEvent.client:FireServer("foo")
	```

	@within TypedRemote
	@param unreliableRemoteName string -- Name for Event (unreliable)
	@return Event<toClientSignature, toServerSignature> -- Event (unreliable) object
]=]
function TypedRemote.newUnreliableEvent<
	toClientSignature,
	toServerSignature
>(
	unreliableRemoteName: string
): Event<toClientSignature, toServerSignature>

	return wrapEvent<<toClientSignature, toServerSignature>>(
		getUnreliableEvent(unreliableRemoteName)
	)
end

--[=[
	Creates an Event (unreliable) object, using a passed UnreliableRemoteEvent instance, `remoteEvent`.

	```lua
	-- server

	local UnreliableEvent = 
		TypedRemote.wrapUnreliableEvent(Instance.new("UnreliableRemoteEvent"))
		:: TypedRemote.ToServerEvent<(text: string) -> ()>

	UnreliableEvent.server.OnServerEvent:Connect(function(player: Player, text: string)
		foo(text)
	end)
	```
	```lua
	-- client

	UnreliableEvent.client:FireServer("foo")
	```

	@within TypedRemote
	@param unreliableRemoteEvent UnreliableRemoteEvent -- UnreliableRemoteEvent instance for Event (unreliable) object
	@return Event<toClientSignature, toServerSignature> -- Event (unreliable) object
]=]
function TypedRemote.wrapUnreliableEvent<
	toClientSignature,
	toServerSignature
>(
	unreliableRemoteEvent: UnreliableRemoteEvent
): Event<toClientSignature, toServerSignature>

	return wrapEvent<<toClientSignature, toServerSignature>>(
		unreliableRemoteEvent
	)
end

--[[
	REMOTE FUNCTIONS
]]

--[=[
	Creates an Function object, automatically creating a RemoteFunction instance named  `remoteFunctionName`.

	```lua
	-- server

	local Function = 
		TypedRemote.newFunction("Function")
		:: TypedRemote.FromServerFunction<(text: string) -> (string)>

	Function.server.OnServerInvoke = function(player: Player, text: string): string
		return text
	end
	```
	```lua
	-- client

	local text: string = Function.client:InvokeServer("foo")
	```

	@within TypedRemote
	@param remoteFunctionName string -- Name for Function object
	@return Event<fromClientSignature, fromServerSignature> -- Function object
]=]
function TypedRemote.newFunction<
	fromClientSignature,
	fromServerSignature
>(
	remoteFunctionName: string
): Function<fromClientSignature, fromServerSignature>
	
	return wrapFunction<<fromClientSignature, fromServerSignature>>(
		getFunction(remoteFunctionName)
	)
end

--[=[
	Creates an Function object, using a passed RemoteFunction instance, `remoteFunction`.

	```lua
	-- server

	local Function = 
		TypedRemote.wrapFunction(Instance.new("RemoteFunction"))
		:: TypedRemote.FromServerFunction<(text: string) -> (string)>

	Function.server.OnServerInvoke = function(player: Player, text: string): string
		return text
	end
	```
	```lua
	-- client
	
	local text: string = Function.client:InvokeServer("foo")
	```

	@within TypedRemote
	@param remoteFunction RemoteFunction -- RemoteFunction instance for Function object
	@return Event<fromClientSignature, fromServerSignature> -- Function object
]=]
function TypedRemote.wrapFunction<
	fromClientSignature,
	fromServerSignature
>(
	remoteFunction: RemoteFunction
): Function<fromClientSignature, fromServerSignature>
	
	return wrapFunction<<fromClientSignature, fromServerSignature>>(
		remoteFunction
	)
end

return TypedRemote
