project('texExpToPng', 'c',
  version: '0.1',
  default_options: ['c_std=gnu11']
)


# Source files
source_files = files(
  'src/tex_exp_to_png.c',
)

# Platform-specific libraries
if host_machine.system() == 'windows'
else
  link_libraries = [
    meson.get_compiler('c').find_library('m')
  ]
endif

# Executable
texExpToPng_exe = executable('texExpToPng',
  source_files,
  dependencies: link_libraries,
  install: true
)
