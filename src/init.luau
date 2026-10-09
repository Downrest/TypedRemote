--[[
	@class TypedRemote

	A typed remote event wrapper, taking advantage of function types `(...) -> (...)` 
	for typechecking parameters with names on both firing and listening.
]]

local RunService = game:GetService("RunService")

local Types = require(script.Types)

local Event = {}

export type Event<
	clientToServerSignature = Types.DefaultSignature,
	serverToClientSignature = Types.DefaultSignature
> = Types.Event<clientToServerSignature, serverToClientSignature>
export type ToClientEvent<signature = Types.DefaultSignature> = Types.ToClientEvent<signature>
export type ToServerEvent<signature = Types.DefaultSignature> = Types.ToServerEvent<signature>

export type Function<
	clientToServerSignature = Types.DefaultSignature,
	serverToClientSignature = Types.DefaultSignature
> = Types.Function<clientToServerSignature, serverToClientSignature>
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
	clientToServerSignature,
	serverToClientSignature
>(
	remoteEvent: any -- typechecker gets angry w/ methods from (RemoteEvent | UnreliableRemoteEvent) union
): Event<clientToServerSignature, serverToClientSignature>
	local self = {
		client = {
			OnClientEvent = {};
		};
		server = {
			OnServerEvent = {};
		};
	}:: Event<clientToServerSignature, serverToClientSignature>

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
	clientToServerSignature,
	serverToClientSignature
>(
	remoteFunction: RemoteFunction
): Function<clientToServerSignature, serverToClientSignature>

	local internal = {
		client = {};
		server = {};
	}
	local self = {
		client = {};
		server = {};
	}:: Function<clientToServerSignature, serverToClientSignature>

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

--[[
	Creates a new reliable event.

	@param remoteName string -- Name for reliable event
	@return Event -- Reliable event object
]]
function Event.newReliable<
	clientToServerSignature,
	serverToClientSignature
>(
	remoteName: string
): Event<clientToServerSignature, serverToClientSignature>

	return wrapEvent<<clientToServerSignature, serverToClientSignature>>(
		getReliableEvent(remoteName)
	)
end

function Event.wrapReliable<
	clientToServerSignature,
	serverToClientSignature
>(
	remoteEvent: RemoteEvent
): Event<clientToServerSignature, serverToClientSignature>

	return wrapEvent<<clientToServerSignature, serverToClientSignature>>(
		remoteEvent
	)
end

--[[
    UNRELIABLE REMOTE EVENTS
]]

function Event.newUnreliable<
	clientToServerSignature,
	serverToClientSignature
>(
	unreliableRemoteName: string
): Event<clientToServerSignature, serverToClientSignature>

	return wrapEvent<<clientToServerSignature, serverToClientSignature>>(
		getUnreliableEvent(unreliableRemoteName)
	)
end

function Event.wrapUnreliable<
	clientToServerSignature,
	serverToClientSignature
>(
	unreliableRemoteEvent: UnreliableRemoteEvent
): Event<clientToServerSignature, serverToClientSignature>

	return wrapEvent<<clientToServerSignature, serverToClientSignature>>(
		unreliableRemoteEvent
	)
end

--[[
	REMOTE FUNCTIONS
]]

function Event.newFunction<
	clientToServerSignature,
	serverToClientSignature
>(
	remoteFunctionName: string
): Function<clientToServerSignature, serverToClientSignature>
	
	return wrapFunction<<clientToServerSignature, serverToClientSignature>>(
		getFunction(remoteFunctionName)
	)
end

function Event.wrapFunction<
	clientToServerSignature,
	serverToClientSignature
>(
	remoteFunction: RemoteFunction
): Function<clientToServerSignature, serverToClientSignature>
	
	return wrapFunction<<clientToServerSignature, serverToClientSignature>>(
		remoteFunction
	)
end

return Event
