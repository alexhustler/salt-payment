$:.push File.expand_path("../lib", __FILE__)
require "salt_payment/version"

Gem::Specification.new do |s|
  s.name        = "salt_payment"
  s.version     = SaltPayment::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Roman Lupiychuk"]
  s.email       = ["roman@slatestudio.com"]
  s.homepage    = "https://github.com/slate-studio/salt-payment"
  s.summary     = ""

  s.files = %w(README.md LICENSE) + Dir["lib/**/*", "app/**/*"]
  s.license = 'MIT'

  s.require_paths = ["lib"]

  s.add_dependency "railties",  [">= 3.1"]
  s.add_dependency "sprockets-rails"

  s.add_development_dependency "uglifier"
end
