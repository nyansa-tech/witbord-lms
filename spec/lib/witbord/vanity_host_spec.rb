# frozen_string_literal: true

require_relative "../../lib/witbord/vanity_host"

RSpec.describe Witbord::VanityHost do
  before do
    allow(HostUrl).to receive(:default_host).and_return("learn.witbord.com")
  end

  describe ".subdomain_for" do
    it "extracts school subdomain" do
      expect(described_class.subdomain_for("knust.witbord.com")).to eq("knust")
    end

    it "returns nil for reserved learn host" do
      expect(described_class.subdomain_for("learn.witbord.com")).to be_nil
    end

    it "returns nil for www and apex" do
      expect(described_class.subdomain_for("www.witbord.com")).to be_nil
      expect(described_class.subdomain_for("witbord.com")).to be_nil
    end

    it "strips port" do
      expect(described_class.subdomain_for("knust.witbord.com:443")).to eq("knust")
    end
  end

  describe ".base_domain" do
    it "derives apex from learn host" do
      expect(described_class.base_domain).to eq("witbord.com")
    end
  end

  describe ".slugify" do
    it "slugifies school names" do
      expect(described_class.slugify("Achimota School")).to eq("achimota-school")
    end
  end
end
