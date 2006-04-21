require 'mkmf'

if find_library('wcat', 'cat_open') and have_header('watchcat.h')
  create_makefile('watchcat')
end
