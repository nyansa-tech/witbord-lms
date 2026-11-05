# frozen_string_literal: true

# Witbord production / local branding setup.
# Run: bundle exec rake witbord:setup
#      bundle exec rake witbord:seed_ghana

namespace :witbord do
  GHANA_REGIONS = [
    "Ahafo Region",
    "Ashanti Region",
    "Bono East Region",
    "Bono Region",
    "Central Region",
    "Eastern Region",
    "Greater Accra Region",
    "North East Region",
    "Northern Region",
    "Oti Region",
    "Savannah Region",
    "Upper East Region",
    "Upper West Region",
    "Volta Region",
    "Western North Region",
    "Western Region"
  ].freeze

  # name => vanity subdomain
  PILOT_UNIVERSITIES = {
    "KNUST" => "knust",
    "University of Ghana" => "ug",
    "University of Cape Coast" => "ucc",
    "Ashesi University" => "ashesi",
    "University of Education, Winneba" => "uew"
  }.freeze

  SECTOR_UNIVERSITIES = "Universities"
  SECTOR_SHS = "Senior High Schools"
  SECTOR_PRIVATE = "Private Schools"

  desc "Configure Witbord branding, then seed the Ghana account tree"
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

    puts ""
    puts "Witbord branding complete."
    puts "  Account:  Witbord"
    puts "  Timezone: Africa/Accra"
    puts "  Company:  https://nyansa.tech"

    Rake::Task["witbord:seed_ghana"].invoke
  end

  desc "Seed Ghana hierarchy: Universities (pilot + vanity), SHS regions, Private Schools container"
  task seed_ghana: :environment do
    root = Account.default
    raise "No root account found. Run db:initial_setup first." unless root

    root.settings[:sub_account_includes] = true
    root.save! if root.settings_changed?

    puts "Seeding Ghana account tree under Witbord (id=#{root.id})..."

    universities = find_or_create_child!(root, SECTOR_UNIVERSITIES)
    shs = find_or_create_child!(root, SECTOR_SHS)
    private_schools = find_or_create_child!(root, SECTOR_PRIVATE)
    puts "  Sector: #{universities.name} (id=#{universities.id})"
    puts "  Sector: #{shs.name} (id=#{shs.id})"
    puts "  Sector: #{private_schools.name} (id=#{private_schools.id})"

    base = Witbord::VanityHost.base_domain || "witbord.com"
    puts ""
    puts "Pilot universities:"
    PILOT_UNIVERSITIES.each do |name, subdomain|
      school = find_or_create_child!(universities, name)
      Witbord::VanityHost.assign!(school, subdomain)
      puts "  #{name} (id=#{school.id}) → https://#{subdomain}.#{base}/login"
    end

    puts ""
    puts "SHS region folders (empty — add schools later with witbord:add_school):"
    created_regions = 0
    GHANA_REGIONS.each do |region_name|
      region = shs.sub_accounts.find_by(name: region_name)
      if region
        puts "  exists: #{region_name} (id=#{region.id})"
      else
        region = shs.sub_accounts.create!(name: region_name)
        created_regions += 1
        puts "  created: #{region_name} (id=#{region.id})"
      end
    end

    legacy = root.sub_accounts.active.select do |a|
      GHANA_REGIONS.include?(a.name) && a.parent_account_id == root.id
    end
    unless legacy.empty?
      puts ""
      puts "Note: legacy region folders still hang directly under the root (from early setup)."
      puts "      They were not deleted. Prefer schools under '#{SECTOR_SHS}' / '#{SECTOR_UNIVERSITIES}'."
      legacy.each { |a| puts "        - #{a.name} (id=#{a.id})" }
    end

    puts ""
    puts "seed_ghana complete."
    puts "  Universities: #{PILOT_UNIVERSITIES.size} (vanity mapped)"
    puts "  SHS regions:  #{GHANA_REGIONS.size} (#{created_regions} newly created)"
    puts "  Private:      empty container '#{SECTOR_PRIVATE}'"
    puts "  Docs:         deploy/GHANA_ROLLOUT.md"
  end

  desc "Create a school sub-account. SCHOOL_NAME='Name' [REGION_NAME='Greater Accra Region' or PARENT='Universities']"
  task add_school: :environment do
    name = ENV["SCHOOL_NAME"].to_s.strip
    raise "Set SCHOOL_NAME='School Name'" if name.blank?

    root = Account.default
    parent_name = ENV["PARENT"].to_s.strip.presence || ENV["REGION_NAME"].to_s.strip
    parent = if parent_name.present?
               candidates = root.all_accounts.active.select { |a| a.name.casecmp?(parent_name) }
               raise "Parent not found: #{parent_name}" if candidates.empty?

               # Prefer folder under Senior High Schools / Universities if duplicates exist
               found = candidates.find { |a| [SECTOR_SHS, SECTOR_UNIVERSITIES].include?(a.parent_account&.name) } ||
                       candidates.first
               found
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
    puts "Optional vanity: SCHOOL_NAME=#{name.inspect} SUBDOMAIN=slug rake witbord:set_vanity"
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

# Helper for witbord rake tasks (loaded with this file)
def find_or_create_child!(parent, name)
  parent.sub_accounts.find_by(name: name) || parent.sub_accounts.create!(name: name)
end
