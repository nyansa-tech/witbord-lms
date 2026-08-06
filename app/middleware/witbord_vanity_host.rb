# frozen_string_literal: true

# Resolves knust.witbord.com → school sub-account and stashes it for login branding.
class WitbordVanityHost
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    account = Witbord::VanityHost.find_account(request.host)
    env["witbord.vanity_account"] = account
    env["witbord.vanity_subdomain"] = Witbord::VanityHost.subdomain_for(request.host)

    RequestStore.store[:witbord_vanity_account] = account
    @app.call(env)
  ensure
    RequestStore.store[:witbord_vanity_account] = nil
  end
end
