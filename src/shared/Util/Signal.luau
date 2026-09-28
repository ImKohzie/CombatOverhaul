--!strict
-- Minimal synchronous signal.

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal = {
	Connect: (self: Signal, handler: (...any) -> ()) -> Connection,
	Fire: (self: Signal, ...any) -> (),
	DisconnectAll: (self: Signal) -> (),
}

local Signal = {}

function Signal.new(): Signal
	local handlers: { [Connection]: (...any) -> () } = {}
	local self = {} :: Signal

	function self.Connect(_: Signal, handler: (...any) -> ()): Connection
		local connection = { Connected = true } :: Connection
		function connection.Disconnect(conn: Connection)
			conn.Connected = false
			handlers[conn] = nil
		end
		handlers[connection] = handler
		return connection
	end

	function self.Fire(_: Signal, ...: any)
		for connection, handler in table.clone(handlers) do
			if connection.Connected then
				task.spawn(handler, ...)
			end
		end
	end

	function self.DisconnectAll(_: Signal)
		for connection in handlers do
			connection.Connected = false
		end
		table.clear(handlers)
	end

	return self
end

return Signal
