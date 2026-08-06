# frozen_string_literal: true

# Maps vanity hosts like knust.witbord.com → school sub-accounts for login branding.
module Witbord
  module VanityHost
    RESERVED_SUBDOMAINS = %w[
      www
      learn
      app
      api
      files
      mail
      smtp
      admin
      status
      static
      assets
      cdn
    ].freeze

    CACHE_PREFIX = "witbord/vanity_subdomain"

    module_function

    # "knust.witbord.com" → "knust"; "learn.witbord.com" → nil; "localhost" → nil
    def subdomain_for(host)
      host = host.to_s.downcase.split(":").first
      return nil if host.blank?

      base = base_domain
      return nil if base.blank?
      return nil if host == base || host == "www.#{base}"

      suffix = ".#{base}"
      return nil unless host.end_with?(suffix)

      sub = host.delete_suffix(suffix)
      return nil if sub.blank? || sub.include?(".")
      return nil if RESERVED_SUBDOMAINS.include?(sub)

      sub
    end

    def base_domain
      default = HostUrl.default_host.to_s.downcase.split(":").first
      return nil if default.blank?

      # learn.witbord.com → witbord.com
      parts = default.split(".")
      return default if parts.length < 2

      parts[-2..].join(".")
    end

    def vanity_host?(host)
      subdomain_for(host).present?
    end

    def find_account(host)
      sub = subdomain_for(host)
      return nil unless sub

      account_id = Rails.cache.read(cache_key(sub))
      if account_id
        account = Account.active.find_by(id: account_id)
        return account if account
      end

      account = lookup_account_by_subdomain(sub)
      Rails.cache.write(cache_key(sub), account.id, expires_in: 1.day) if account
      account
    end

    def lookup_account_by_subdomain(sub)
      root = Account.default
      return nil unless root

      # Prefer explicit setting; fall back to slugified account name
      match = root.all_accounts.active.detect do |account|
        account.settings[:vanity_subdomain].to_s.casecmp?(sub) ||
          slugify(account.name) == sub
      end
      match
    end

    def slugify(name)
      name.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
    end

    def cache_key(sub)
      "#{CACHE_PREFIX}/#{sub}"
    end

    def clear_cache!(sub = nil)
      if sub
        Rails.cache.delete(cache_key(sub))
      else
        # Best-effort: callers should pass the subdomain when known
        true
      end
    end

    def assign!(account, subdomain)
      subdomain = subdomain.to_s.downcase.strip
      raise ArgumentError, "blank subdomain" if subdomain.blank?
      raise ArgumentError, "reserved subdomain: #{subdomain}" if RESERVED_SUBDOMAINS.include?(subdomain)
      raise ArgumentError, "invalid subdomain" unless subdomain.match?(/\A[a-z0-9]([a-z0-9-]*[a-z0-9])?\z/)

      taken = Account.default&.all_accounts&.active&.detect do |other|
        other.id != account.id && other.settings[:vanity_subdomain].to_s.casecmp?(subdomain)
      end
      raise ArgumentError, "subdomain already used by #{taken.name}" if taken

      old = account.settings[:vanity_subdomain]
      clear_cache!(old) if old.present?

      account.settings[:vanity_subdomain] = subdomain
      account.save!
      Rails.cache.write(cache_key(subdomain), account.id, expires_in: 1.day)
      account
    end
  end
end
