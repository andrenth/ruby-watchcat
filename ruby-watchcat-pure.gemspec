require 'rubygems'

spec = Gem::Specification.new do |s|
  s.name              = 'ruby-watchcat-pure'
  s.version           = '1.0.0'
  s.platform          = Gem::Platform::RUBY
  s.summary           = 'A pure-ruby implementation of libwatchcat'
  s.requirements      = %q{watchcatd}
  s.files             = Dir.glob('{lib,examples}/**')
  s.has_rdoc          = false
  s.author            = 'Andre Nathan'
  s.email             = 'andre@digirati.com.br'
  s.rubyforge_project = 'ruby-watchcat'
  s.homepage          = 'http://watchcat.rubyforge.org'
  s.description = <<-EOF
    Ruby/Watchcat-Pure is a pure-ruby implementation of libwatchcat for the
    development of watchcatd-aware applications.
  EOF
end

if __FILE__ == $0
  Gem.manage_gems
  Gem::Builder.new(spec).build
else
  spec
end