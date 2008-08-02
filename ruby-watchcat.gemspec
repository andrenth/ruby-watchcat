require 'rubygems'

spec = Gem::Specification.new do |s|
  s.name              = 'ruby-watchcat'
  s.version           = '1.0.1'
  s.platform          = Gem::Platform::CURRENT
  s.summary           = 'A Ruby extension for libwatchcat'
  s.requirements      = %q{libwcat and watchcatd.}
  s.files             = Dir.glob('{ext,examples}/**')
  s.extensions        = %q{ext/extconf.rb}
  s.author            = 'Andre Nathan'
  s.email             = 'andre@digirati.com.br'
  s.rubyforge_project = 'ruby-watchcat'
  s.homepage          = 'http://watchcat.rubyforge.org'
  s.description = <<-EOF
    Ruby/Watchcat is an extension for the Ruby programming language for the
    development of watchcatd-aware applications.
  EOF
end

if __FILE__ == $0
  Gem.manage_gems
  Gem::Builder.new(spec).build
else
  spec
end
