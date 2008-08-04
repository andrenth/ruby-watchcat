require 'mkmf'

if find_library('wcat', 'cat_open') and have_header('watchcat.h')
  CFLAGS += " -Wall #{ENV['CFLAGS']}"
  create_makefile('watchcat')
end
