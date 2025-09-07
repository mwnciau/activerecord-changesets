Gem::Specification.new do |s|
  s.name = "activerecord-changesets"
  s.version = "1.0.0"
  s.summary = ""
  s.description = ""
  s.authors = ["Simon J"]
  s.email = "2857218+mwnciau@users.noreply.github.com"
  s.files = [
    "lib/rails_changesets.rb",
    "lib/changeset.rb",
    "CHANGELOG.md",
    "LICENSE.md",
    "README.md",
  ]
  s.require_paths = ["lib"]
  s.homepage = "https://rubygems.org/gems/dotkey"
  s.metadata = {
    "source_code_uri" => "https://github.com/mwnciau/dotkey",
    "changelog_uri" => "https://github.com/mwnciau/dotkey/blob/main/CHANGELOG.md",
    "documentation_uri" => "https://github.com/mwnciau/dotkey",
    "bug_tracker_uri" => "https://github.com/mwnciau/dotkey/issues",
  }

  s.license = "MIT"
  s.required_ruby_version = ">= 2.0.0"

  s.add_dependency "activerecord", ">= 8.0"

  s.add_development_dependency "temping", "~> 4.0"
  s.add_development_dependency "sqlite3", "~> 2.0"
  s.add_development_dependency "actionpack", ">= 8.0"

  s.add_development_dependency "minitest", "~> 5.0"
  s.add_development_dependency "minitest-reporters", "~> 1.1"
  s.add_development_dependency "standard", "~> 1.49"
  s.add_development_dependency "rubocop", "~> 1.75"
  s.add_development_dependency "benchmark-ips", "~> 2.14"
end
