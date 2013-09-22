# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "kitchen-scribe/version"

Gem::Specification.new do |s|
  s.name        = "kitchen-scribe"
  s.version     = KitchenScribe::VERSION
  s.has_rdoc = true
  s.authors     = ["Pawel Kozlowski"]
  s.email       = ["pawel.kozlowski@u2i.com"]
  s.homepage = "https://github.com/khozlov/kitchen-scribe"
  s.summary = "Knife plugin for tracking your chef configuration changes"
  s.description = s.summary
  s.extra_rdoc_files = ["README.md", "LICENSE" ]
  s.license = "Apache License (2.0)"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.add_dependency "chef", ">= 0.10.10"
  %w(rspec-core rspec-expectations rspec-mocks).each { |gem| s.add_development_dependency gem }

  s.require_paths = ["lib"]
end
