# frozen_string_literal: true

# Witbord production / local branding setup.
# Run: bundle exec rake witbord:setup

namespace :witbord do
  desc "Configure Witbord branding, account settings, and sample Ghana school sub-accounts"
  task setup: :environment do
    account = Account.default
    raise "No root account found. Run db:initial_setup first." unless account

    puts "Configuring Witbord on root account (id=#{account.id})..."

    account.name = "Witbord"
    account.default_time_zone = "Africa/Accra"
    account.settings[:product_name] = "Witbord"
    account.settings[:outgoing_email_default_name] = "Witbord"
    account.settings[:help_link_name] = "Witbord Help"
    account.settings[:login_handle_name] = "Witbord ID"
    account.settings[:support_url] = "https://nyansa.tech/contact"
    account.settings[:enable_offline_web_export] = { value: true }
    # Allow school sub-accounts to have their own Themes (needed for vanity host branding)
    account.settings[:sub_account_includes] = true
    account.save!

    brand_variables = {
      "ic-brand-primary" => "#006B3F",
      "ic-brand-global-nav-bgd" => "#1A3A2F",
      "ic-brand-global-nav-logo-bgd" => "#1A3A2F",
      "ic-link-color" => "#004D2E",
      "ic-brand-button--primary-bgd" => "#006B3F",
      "ic-brand-button--secondary-bgd" => "#1A3A2F",
      "ic-brand-Login-body-bgd-color" => "#1A3A2F",
      "ic-brand-Login-body-bgd-shadow-color" => "#0F2419",
      "ic-brand-msapplication-tile-color" => "#006B3F"
    }

    brand_config = BrandConfig.for(variables: brand_variables)
    brand_config.save_unless_dup!
    brand_config.save_all_files!
    account.brand_config = brand_config
    account.save!

    HostUrl.reset_cache! if defined?(HostUrl)

    regions = {
      "Greater Accra Region" => ["Achimota School", "Wesley Girls High School"],
      "Ashanti Region" => ["Prempeh College", "Opoku Ware School"]
    }

    school_count = 0
    regions.each do |region_name, schools|
      region = account.sub_accounts.find_by(name: region_name) ||
               account.sub_accounts.create!(name: region_name)

      schools.each do |school_name|
        next if region.sub_accounts.exists?(name: school_name)

        region.sub_accounts.create!(name: school_name)
        school_count += 1
        puts "  Created school: #{school_name} (#{region_name})"
      end
    end

    puts ""
    puts "Witbord setup complete."
    puts "  Account:  Witbord"
    puts "  Timezone: Africa/Accra"
    puts "  Schools:  #{school_count} new sample schools under #{regions.size} regions"
    puts "  Company:  https://nyansa.tech"
  end

  desc "Create a school sub-account. SCHOOL_NAME='Name' [REGION_NAME='Greater Accra Region']"
  task add_school: :environment do
    name = ENV["SCHOOL_NAME"].to_s.strip
    raise "Set SCHOOL_NAME='School Name'" if name.blank?

    root = Account.default
    region_name = ENV["REGION_NAME"].to_s.strip
    parent = if region_name.present?
               root.sub_accounts.find_or_create_by!(name: region_name)
             else
               root
             end

    school = parent.sub_accounts.find_by(name: name)
    if school
      puts "School already exists: #{school.name} (id=#{school.id})"
    else
      school = parent.sub_accounts.create!(name: name)
      puts "Created school: #{school.name} (id=#{school.id}) under #{parent.name}"
    end
    puts "Admins API: /api/v1/accounts/#{school.id}/admins"
  end

  desc "Map a school to a vanity subdomain. SCHOOL_NAME='KNUST' SUBDOMAIN=knust → knust.witbord.com"
  task set_vanity: :environment do
    name = ENV["SCHOOL_NAME"].to_s.strip
    subdomain = ENV["SUBDOMAIN"].to_s.strip.downcase
    raise "Set SCHOOL_NAME='School Name'" if name.blank?
    raise "Set SUBDOMAIN=knust" if subdomain.blank?

    root = Account.default
    root.settings[:sub_account_includes] = true
    root.save! if root.settings_changed?

    school = root.all_accounts.active.find { |a| a.name.casecmp?(name) }
    raise "School not found: #{name}" unless school

    Witbord::VanityHost.assign!(school, subdomain)
    base = Witbord::VanityHost.base_domain || "witbord.com"
    puts "Mapped #{school.name} (id=#{school.id}) → https://#{subdomain}.#{base}"
    puts "Set a Theme under Admin → #{school.name} → Themes so the login page is branded."
  end

  desc "List vanity subdomain mappings"
  task list_vanity: :environment do
    root = Account.default
    base = Witbord::VanityHost.base_domain || "witbord.com"
    rows = root.all_accounts.active.filter_map do |a|
      sub = a.settings[:vanity_subdomain].presence
      next unless sub

      "#{sub}.#{base}  →  #{a.name} (id=#{a.id})"
    end
    if rows.empty?
      puts "No vanity subdomains configured. Use: SCHOOL_NAME='KNUST' SUBDOMAIN=knust rake witbord:set_vanity"
    else
      puts rows.sort
    end
  end
end
