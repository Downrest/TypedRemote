local Types = {}

export type DefaultSignature = () -> ()

type function AppendParameters(append: type, signature: type): type
	if signature.tag == "unknown" then
		signature = DefaultSignature
	end
	if signature.tag ~= "function" then
		print(`Argument signature must be a function`)
	end

	local signatureParameters = signature:parameters(); do
        local head = signatureParameters.head:: {type}
        if not head then
            head = {}
            signatureParameters.head = head
        end
        
        for index = #head, 1, -1 do
            local value = head[index]
            head[index+1] = value
        end
        head[1] = append
    end
	local signatureReturns = signature:returns()

	return types.newfunction(signatureParameters, signatureReturns)
end
type function ExtractParameters(signature: type): type
	if signature.tag == "unknown" then
		signature = DefaultSignature
	end
	if signature.tag ~= "function" then
		print(`Argument signature must be a function`)
	end

	return types.newfunction(
		signature:parameters()
	)
end

--[[
 	REMOTE EVENTS
]]

export type ClientFire<
	self = any,
	toClientSignature = DefaultSignature,
	toServerSignature = DefaultSignature
> = {
	FireServer: AppendParameters<
		self,
		toServerSignature
	>;
}
export type ClientListener<
	self = any,
	toClientSignature = DefaultSignature,
	toServerSignature = DefaultSignature
> = {
	Connect: (
		self: self, 
		callback: toClientSignature
	) -> RBXScriptConnection;
	ConnectParallel: (
		self: self, 
		callback: toClientSignature
	) -> RBXScriptConnection;
	Once: (
		self: self, 
		callback: toClientSignature
	) -> RBXScriptConnection;
}
export type ServerFire<
	self = any,
	toClientSignature = DefaultSignature,
	toServerSignature = DefaultSignature
> = {
	FireClient: AppendParameters<
		self, 
		AppendParameters<Player, toClientSignature>
	>;
	FireAllClients: AppendParameters<
		self, 
		toClientSignature
	>;
}
export type ServerListener<
	self = any,
	toClientSignature = DefaultSignature,
	toServerSignature = DefaultSignature
> = {
	Connect: (
		self: self, 
		callback: AppendParameters<Player, toServerSignature>
	) -> RBXScriptConnection;
	ConnectParallel: (
		self: self, 
		callback: AppendParameters<Player, toServerSignature>
	) -> RBXScriptConnection;
	Once: (
		self: self, 
		callback: AppendParameters<Player, toServerSignature>
	) -> RBXScriptConnection;
}

--[=[
	@class Event
]=]

--[=[
	@interface Event
	@within Event

	@field client { FireServer: () -> (), OnClientEvent: { Connect: (self: any, callback: (...any) -> ()) -> (), ConnectParallel: (self: any, callback: (...any) -> ()) -> (), Once: (self: any, callback: (...any) -> ()) -> () } } }
	@field server { FireClient: () -> (), OnServerEvent: { Connect: (self: any, callback: (...any) -> ()) -> (), ConnectParallel: (self: any, callback: (...any) -> ()) -> (), Once: (self: any, callback: (...any) -> ()) -> () } } }
]=]

export type Event<
	toClientSignature = DefaultSignature,
	toServerSignature = DefaultSignature
> = {
	client:
		ClientFire<any, toClientSignature, toServerSignature>
		& {
			OnClientEvent: ClientListener<any, toClientSignature, toServerSignature>;
		};
	server: 
		ServerFire<any, toClientSignature, toServerSignature>
		& {
			OnServerEvent: ServerListener<any, toClientSignature, toServerSignature>;
		};
}

export type ToClientEvent<signature = DefaultSignature> = Event<signature, DefaultSignature>
export type ToServerEvent<signature = DefaultSignature> = Event<DefaultSignature, signature>

--[[
	REMOTE FUNCTIONS
]]

export type ClientInvoke<
	self = any,
	fromClientSignature = DefaultSignature,
	fromServerSignature = DefaultSignature
> = {
	OnClientInvoke: fromClientSignature;
	InvokeServer: AppendParameters<
		self,
		fromServerSignature
	>
}
export type ServerInvoke<
	self = any,
	fromClientSignature = DefaultSignature,
	fromServerSignature = DefaultSignature
> = {
	OnServerInvoke: AppendParameters<
		Player,
		fromServerSignature
	>;
	InvokeClient: AppendParameters<
		self,
		AppendParameters<
			Player,
			fromClientSignature
		>
	>
}

--[=[
	@class Function
]=]

--[=[
	@interface Function
	@within Function

	@field client { InvokeServer: (...any) -> (...any), OnClientInvoke: (...any) -> (...any) }
	@field server { InvokeClient: (Player, ...any) -> (...any), OnServerInvoke: (Player, ...any) -> (...any) }
]=]

export type Function<
	fromClientSignature = DefaultSignature,
	fromServerSignature = DefaultSignature
> = {
	client: ClientInvoke<any, fromClientSignature, fromServerSignature>;
	server: ServerInvoke<any, fromClientSignature, fromServerSignature>;
}

export type FromClientFunction<signature = DefaultSignature> = Function<signature, DefaultSignature>
export type FromServerFunction<signature = DefaultSignature> = Function<DefaultSignature, signature>

return Types
