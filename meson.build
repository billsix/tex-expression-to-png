project('texExpToPng', 'c',
  version: '0.1',
  default_options: ['c_std=gnu11']
)

glib_dep = dependency('glib-2.0')
math_dep = meson.get_compiler('c').find_library('m')

# Source files
source_files = files(
  'src/tex_exp_to_png.c',
)

# Executable
texExpToPng_exe = executable('texExpToPng',
  source_files,
  dependencies: [glib_dep, math_dep],
  install: true
)

# Tests — the harness the ASan/UBSan gate runs. `smoke` renders a real PNG
# (needs latex + dvipng); `usage-error` is TeX-free and gates the pure-C
# option-parsing/validation paths. meson runs each as a separate test() and
# reports every failure, so the "run all, report all red" job lives here, not
# in the shell scripts.
smoke_test = find_program('tests/smoke.sh')
test('smoke', smoke_test,
  env: {'TEXEXP_BIN': texExpToPng_exe.full_path()},
  depends: texExpToPng_exe,
  timeout: 120
)

usage_error_test = find_program('tests/usage_error.sh')
test('usage-error', usage_error_test,
  env: {'TEXEXP_BIN': texExpToPng_exe.full_path()},
  depends: texExpToPng_exe
)
