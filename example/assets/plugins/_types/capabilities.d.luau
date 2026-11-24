-- GENERATED capability stubs (LSP / docs only).
-- Do NOT treat this as a runnable dispatch implementation.
-- Plugin packages must hand-write dispatch(method, args).

-- DTO: VpnStatus
export type VpnStatus = {
  ok: boolean,
  screen: string?,
  selected: string?,
  lastServer: string?,
  loggedIn: boolean?,
  serverCount: number?,
  error: string?,
}

-- DTO: VpnConfigResult
export type VpnConfigResult = {
  ok: boolean,
  config: string?,
  serverId: string?,
  serverName: string?,
  error: string?,
}

-- DTO: VpnOkResult
export type VpnOkResult = {
  ok: boolean,
  error: string?,
}

-- Capability: vpn.provider (VpnProvider)
-- Advertise in plugin.yaml: capabilities: ["vpn.provider"]

-- dispatch("get_status", args) -> VpnStatus
-- function dispatch_get_status(args: {}): VpnStatus
-- dispatch("get_selected_config", args) -> VpnConfigResult
-- function dispatch_get_selected_config(args: {}): VpnConfigResult
-- dispatch("logout", args) -> VpnOkResult
-- function dispatch_logout(args: {}): VpnOkResult

-- Combined dispatch shape (illustrative):
export type VpnProviderDispatch = {
  -- ["get_status"]: ({}) -> VpnStatus
  -- ["get_selected_config"]: ({}) -> VpnConfigResult
  -- ["logout"]: ({}) -> VpnOkResult
}

