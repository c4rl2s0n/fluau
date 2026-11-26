-- Hand-maintained plugin lifecycle / intent type stubs for luau-lsp.
-- Mirrors the session contract used by assets/plugins/*/main.lua.
--
-- Lifecycle entry points (init, render, flush_state, on_event, on_host_result,
-- dispatch) are implemented by each plugin — annotate them in main.lua, e.g.:
--   function render(): Widget
--   function on_event(event: PluginEvent): { HostIntent }
-- Host-injected globals (`ui`, `host`) live in ui.d.luau / host.d.luau.

export type FieldFlushMap = { [string]: string }

-- Runtime-owned / host-sent event types. Do not emit `action` by hand in
-- payload tables — pass a Lua function (or ui.action) on callback props instead.
export type ReservedEventType = "action" | "bootstrap"

export type PluginEvent = {
	-- Prefer custom types for on_event; "action" is intercepted by the runtime.
	type: string,
	[string]: any,
}

export type DbGetIntent = {
	type: "db.get",
	requestId: string,
	key: string,
}

export type DbSetIntent = {
	type: "db.set",
	requestId: string,
	key: string,
	value: string,
}

export type HttpIntent = {
	type: "http",
	requestId: string,
	method: string?,
	url: string,
	body: any?,
	headers: { [string]: string }?,
}

export type ProvideResultIntent = {
	type: "app.provideResult",
	requestId: string,
	value: string,
}

export type HostIntent = DbGetIntent | DbSetIntent | HttpIntent | ProvideResultIntent | {
	type: string,
	requestId: string?,
	[string]: any,
}

export type HostResult = {
	type: string,
	requestId: string?,
	ok: boolean?,
	error: string?,
	key: string?,
	value: string?,
	[string]: any,
}

export type DispatchResult = {
	ok: boolean,
	error: string?,
	[string]: any,
}

-- Expected plugin module shape (for documentation / cast helpers).
export type PluginModule = {
	init: (() -> ())?,
	render: () -> Widget,
	flush_state: ((fields: FieldFlushMap) -> ())?,
	on_event: ((event: PluginEvent) -> { HostIntent }?)?,
	on_host_result: ((result: HostResult) -> { HostIntent }?)?,
	dispatch: ((method: string, args: any) -> DispatchResult)?,
}
